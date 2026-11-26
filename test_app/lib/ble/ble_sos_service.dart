import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// AKAY - Bluetooth (BLE) SOS relay
//
// Idea: when a phone has NO internet, it shouts its SOS over Bluetooth.
// Any AKAY phone nearby hears it, HOLDS it, and uploads it to Firestore
// as soon as THAT phone gets a connection.
//
// Three kinds of tiny messages are broadcast (BLE adverts are ~31 bytes):
//   SOS  [A K 01 type mobility members tag(4) lat(4) lng(4)]  = 18 bytes
//   ACK  [A K 02 senderTag(4) relayTag(4)]                    = 11 bytes
//        "I am holding the SOS with this tag" -> the sender counts these
//        to show "Shared Nearby".
//
// Privacy: no name, no address, no uid is ever broadcast. Only the emergency
// type, mobility need, member count, a random tag and a ~11 m rounded location.
// Anyone with a BLE scanner can read it, which is the trade-off of an offline SOS.
// ============================================================

const int _kManufacturerId = 0xFFFF; // reserved for testing / private use
const int _kMagic0 = 0x41; // 'A'
const int _kMagic1 = 0x4B; // 'K'
const int _kKindSos = 1;
const int _kKindAck = 2;
const double _kCoordScale = 10000; // 4 decimals ~ 11 m

// Order matters: the index is what goes over the air. Matches firestore.rules.
const List<String> kMobilityNeeds = [
  'None',
  'Wheelchair required',
  'Bedridden',
  'Oxygen tank',
  'Needs carrying / stretcher',
  'Infant or young child',
  'Other',
];
const List<String> kSosTypes = ['flood', 'medical', 'fire', 'other'];

/// An SOS this phone heard from somebody else and is holding for them.
class HeldSos {
  final String tag; // 8 hex chars, random per SOS
  final String type;
  final String mobilityNeed;
  final int members;
  final double lat;
  final double lng;
  final int heardAtMs;
  int rssi;
  int lastSeenMs;
  bool uploaded;

  HeldSos({
    required this.tag,
    required this.type,
    required this.mobilityNeed,
    required this.members,
    required this.lat,
    required this.lng,
    required this.heardAtMs,
    required this.rssi,
    required this.lastSeenMs,
    this.uploaded = false,
  });

  /// Rough only. Walls and water change signal strength a lot.
  String get proximity {
    if (rssi >= -60) return 'very close';
    if (rssi >= -75) return 'nearby';
    return 'far';
  }

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'type': type,
        'mobilityNeed': mobilityNeed,
        'members': members,
        'lat': lat,
        'lng': lng,
        'heardAtMs': heardAtMs,
        'rssi': rssi,
        'lastSeenMs': lastSeenMs,
        'uploaded': uploaded,
      };

  factory HeldSos.fromJson(Map<String, dynamic> j) => HeldSos(
        tag: j['tag'] as String,
        type: j['type'] as String,
        mobilityNeed: j['mobilityNeed'] as String,
        members: j['members'] as int,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        heardAtMs: j['heardAtMs'] as int,
        rssi: j['rssi'] as int,
        lastSeenMs: j['lastSeenMs'] as int,
        uploaded: j['uploaded'] as bool? ?? false,
      );
}

class BleSosService extends ChangeNotifier {
  BleSosService._();
  static final BleSosService instance = BleSosService._();

  static const _prefsKey = 'akay_held_sos_v1';
  static const _maxHeld = 20;
  static const _maxAcks = 8;

  final FlutterBlePeripheral _adv = FlutterBlePeripheral();
  final Map<String, HeldSos> _held = {};
  final Set<String> _ackedBy = {}; // relay tags that confirmed holding MY sos

  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _rotateTimer;
  Timer? _uploadTimer;
  List<Uint8List> _rotation = [];
  int _rotIndex = 0;

  Uint8List? _mySosPayload;
  Uint8List? _myTag;
  bool _listening = false;
  bool _loaded = false;
  String? _error;

  // ---------- what the screens read ----------
  bool get sosActive => _mySosPayload != null;
  bool get listening => _listening;
  int get ackCount => _ackedBy.length;
  String? get error => _error;
  List<HeldSos> get held {
    final l = _held.values.toList()
      ..sort((a, b) => b.lastSeenMs.compareTo(a.lastSeenMs));
    return l;
  }

  String get _myTagHex => _myTag == null ? '' : _hex(_myTag!);

  // ---------- small helpers ----------
  static String _hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

  void _fail(String msg) {
    _error = msg;
    notifyListeners();
  }

  static void _putInt32(BytesBuilder b, int v) {
    final d = ByteData(4)..setInt32(0, v, Endian.big);
    b.add(d.buffer.asUint8List());
  }

  static int _getInt32(List<int> bytes, int offset) =>
      ByteData.sublistView(Uint8List.fromList(bytes.sublist(offset, offset + 4)))
          .getInt32(0, Endian.big);

  Uint8List _sosPayload({
    required int typeIdx,
    required int mobilityIdx,
    required int members,
    required Uint8List tag,
    required double lat,
    required double lng,
  }) {
    final b = BytesBuilder()
      ..add([_kMagic0, _kMagic1, _kKindSos, typeIdx, mobilityIdx])
      ..add([members.clamp(1, 255)])
      ..add(tag);
    _putInt32(b, (lat * _kCoordScale).round());
    _putInt32(b, (lng * _kCoordScale).round());
    return b.toBytes();
  }

  Uint8List _ackPayload(HeldSos h) {
    final myRelayTag = _relayTag();
    final b = BytesBuilder()
      ..add([_kMagic0, _kMagic1, _kKindAck])
      ..add(_unhex(h.tag))
      ..add(myRelayTag);
    return b.toBytes();
  }

  static Uint8List _unhex(String s) => Uint8List.fromList([
        for (var i = 0; i < s.length; i += 2)
          int.parse(s.substring(i, i + 2), radix: 16),
      ]);

  Uint8List? _relayTagCache;
  Uint8List _relayTag() => _relayTagCache ??= _randomTag();

  static Uint8List _randomTag() {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(4, (_) => r.nextInt(256)));
  }

  // ---------- permissions / bluetooth ----------

  /// Asks for Bluetooth permissions and makes sure Bluetooth is on.
  Future<bool> ensureReady() async {
    _error = null;
    final res = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // Android 11 and below need it to scan
    ].request();

    final btOk = res[Permission.bluetoothScan]?.isGranted == true &&
        res[Permission.bluetoothAdvertise]?.isGranted == true &&
        res[Permission.bluetoothConnect]?.isGranted == true;
    if (!btOk) {
      _fail('Bluetooth permission was denied. Allow "Nearby devices" for AKAY in Settings.');
      return false;
    }
    if (!await FlutterBluePlus.isSupported) {
      _fail('This phone does not support Bluetooth LE.');
      return false;
    }
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn(); // Android shows a system prompt
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 800));
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        _fail('Bluetooth is off. Please turn it on.');
        return false;
      }
    }
    notifyListeners();
    return true;
  }

  // ---------- 1) I need help: broadcast MY SOS ----------

  Future<void> startMySos({required String type}) async {
    if (!await ensureReady()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _fail('Sign in before sending an SOS.');

    final h = await _household(user.uid);
    if (h == null) {
      return _fail('Household profile not found on this phone. Open it once while online.');
    }
    final pos = await _position();
    if (pos == null) {
      return _fail('Could not get your location. Turn on GPS and try again.');
    }

    final mobilityIdx =
        max(0, kMobilityNeeds.indexOf((h['mobilityNeed'] ?? 'None').toString()));
    final typeIdx = max(0, kSosTypes.indexOf(type));
    final members = (h['members'] is int) ? h['members'] as int : 1;

    _myTag = _randomTag();
    _ackedBy.clear();
    _mySosPayload = _sosPayload(
      typeIdx: typeIdx,
      mobilityIdx: mobilityIdx,
      members: members,
      tag: _myTag!,
      lat: pos.latitude,
      lng: pos.longitude,
    );
    await startListening(); // also listen for ACKs from neighbours
    await _applyAdvertising();
    notifyListeners();
  }

  Future<void> stopMySos() async {
    _mySosPayload = null;
    _myTag = null;
    _ackedBy.clear();
    await _applyAdvertising();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> _household(String uid) async {
    final ref = FirebaseFirestore.instance.doc('households/$uid');
    try {
      final s = await ref.get(const GetOptions(source: Source.cache));
      if (s.exists) return s.data();
    } catch (_) {}
    try {
      return (await ref.get().timeout(const Duration(seconds: 5))).data();
    } catch (_) {
      return null;
    }
  }

  Future<Position?> _position() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  // ---------- 2) I can help: listen, hold, relay ----------

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        for (final j in (jsonDecode(raw) as List)) {
          final h = HeldSos.fromJson(Map<String, dynamic>.from(j as Map));
          _held[h.tag] = h;
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_held.values.map((h) => h.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> startListening() async {
    await load();
    if (_listening) return;
    if (!await ensureReady()) return;

    _scanSub = FlutterBluePlus.scanResults.listen(_onScan);
    try {
      await FlutterBluePlus.startScan(
        withMsd: [MsdFilter(_kManufacturerId)],
        continuousUpdates: true,
        androidScanMode: AndroidScanMode.lowLatency,
      );
      _listening = true;
    } catch (e) {
      _fail('Could not start scanning: $e');
      return;
    }
    _uploadTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => uploadHeld());
    await _applyAdvertising();
    uploadHeld();
    notifyListeners();
  }

  Future<void> stopListening() async {
    _uploadTimer?.cancel();
    _uploadTimer = null;
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    _listening = false;
    notifyListeners();
  }

  void _onScan(List<ScanResult> results) {
    var changed = false;
    var newHeld = false;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final r in results) {
      final raw = r.advertisementData.manufacturerData[_kManufacturerId];
      if (raw == null || raw.length < 11) continue;
      if (raw[0] != _kMagic0 || raw[1] != _kMagic1) continue;

      if (raw[2] == _kKindSos && raw.length >= 18) {
        final tag = _hex(raw.sublist(6, 10));
        if (tag == _myTagHex) continue; // my own SOS
        final existing = _held[tag];
        if (existing != null) {
          existing.rssi = r.rssi;
          existing.lastSeenMs = now;
        } else {
          final typeIdx = raw[3].clamp(0, kSosTypes.length - 1);
          final mobIdx = raw[4].clamp(0, kMobilityNeeds.length - 1);
          _held[tag] = HeldSos(
            tag: tag,
            type: kSosTypes[typeIdx],
            mobilityNeed: kMobilityNeeds[mobIdx],
            members: raw[5],
            lat: _getInt32(raw, 10) / _kCoordScale,
            lng: _getInt32(raw, 14) / _kCoordScale,
            heardAtMs: now,
            rssi: r.rssi,
            lastSeenMs: now,
          );
          newHeld = true;
        }
        changed = true;
      } else if (raw[2] == _kKindAck) {
        final senderTag = _hex(raw.sublist(3, 7));
        if (senderTag == _myTagHex && _myTag != null) {
          if (_ackedBy.add(_hex(raw.sublist(7, 11)))) changed = true;
        }
      }
    }

    if (newHeld) {
      while (_held.length > _maxHeld) {
        final oldest = _held.values.reduce(
          (a, b) => a.lastSeenMs < b.lastSeenMs ? a : b,
        );
        _held.remove(oldest.tag);
      }
      _save();
      _applyAdvertising();
      uploadHeld();
    }
    if (changed) notifyListeners();
  }

  // ---------- advertising (rotates: my SOS + ACKs for SOS I hold) ----------

  Future<void> _applyAdvertising() async {
    _rotateTimer?.cancel();
    _rotateTimer = null;

    final acks = held.take(_maxAcks).map(_ackPayload).toList();
    _rotation = [if (_mySosPayload != null) _mySosPayload!, ...acks];

    if (_rotation.isEmpty) {
      try {
        await _adv.stop();
      } catch (_) {}
      return;
    }
    _rotIndex = 0;
    await _advertise(_rotation[0]);
    if (_rotation.length > 1) {
      _rotateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _rotIndex = (_rotIndex + 1) % _rotation.length;
        _advertise(_rotation[_rotIndex]);
      });
    }
  }

  Future<void> _advertise(Uint8List payload) async {
    try {
      if (await _adv.isAdvertising) await _adv.stop();
      await _adv.start(
        advertiseData: AdvertiseData(
          includeDeviceName: false,
          manufacturerId: _kManufacturerId,
          manufacturerData: payload,
        ),
        advertiseSettings: AdvertiseSettings(
          advertiseMode: AdvertiseMode.advertiseModeLowLatency,
          txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
          connectable: false,
          timeout: 0,
        ),
      );
    } catch (e) {
      _fail('Could not broadcast over Bluetooth: $e');
    }
  }

  // ---------- upload held SOS when THIS phone has internet ----------

  /// Safe to call often. Writes relayedSos/{tag}_{myUid}; repeating is harmless.
  Future<void> uploadHeld() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    var changed = false;

    for (final h in _held.values.where((h) => !h.uploaded).toList()) {
      try {
        await FirebaseFirestore.instance
            .doc('relayedSos/${h.tag}_${user.uid}')
            .set({
          'tag': h.tag,
          'relayedBy': user.uid,
          'type': h.type,
          'mobilityNeed': h.mobilityNeed,
          'members': h.members,
          'lat': h.lat,
          'lng': h.lng,
          'heardAt': Timestamp.fromMillisecondsSinceEpoch(h.heardAtMs),
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));
        h.uploaded = true;
        changed = true;
      } on TimeoutException {
        // No internet yet. Firestore keeps the write queued; we try again later.
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          _error = 'Upload blocked by Firestore rules. Deploy the relayedSos rule.';
          changed = true;
        }
      } catch (_) {}
    }
    if (changed) {
      _save();
      notifyListeners();
    }
  }
}
