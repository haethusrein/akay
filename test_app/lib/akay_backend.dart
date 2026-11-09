// ============================================================
// AKAY - FREE backend (Firebase Spark plan: no Cloud Functions, no credit card).
// The screens only call AkayBackend.something(); no Firebase code in the UI.
// The security lives in firestore.rules.
// ============================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'create_account_screens.dart' show UserRole;

class AkayBackend {
  AkayBackend._();

  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static const double nearbyKm = 5;

  static String? get uid => _auth.currentUser?.uid;
  static bool get isSignedIn => _auth.currentUser != null;

  // ---------- helpers ----------

  // 0912 345 6789 / +63 912... / 912... -> "639123456789"
  static String _digits(String input) {
    var d = input.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('63')) {
      d = d.substring(2);
    } else if (d.startsWith('0')) {
      d = d.substring(1);
    }
    return '63$d';
  }

  // Firebase has no free phone+password login, so we sign in with a hidden email.
  static String _emailFor(String mobile) => '${_digits(mobile)}@akay.app';

  static int _millis(dynamic ts) =>
      (ts is Timestamp ? ts.millisecondsSinceEpoch : DateTime.now().millisecondsSinceEpoch);

  static double _round3(double n) => (n * 1000).round() / 1000; // ~110 m

  static CollectionReference<Map<String, dynamic>> _notifsOf(String userId) =>
      _db.collection('notifications').doc(userId).collection('items');

  static Map<String, dynamic> _notif(String type, String title, {String? body, String? requestId}) => {
        'type': type,
        'title': title,
        'body': body,
        'requestId': requestId,
        'isRead': false,
        'fromUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Turns any error into a message you can show in a SnackBar.
  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'This mobile number already has an account.';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Wrong mobile number or password.';
        case 'weak-password':
          return 'Use at least 6 characters.';
        case 'network-request-failed':
          return 'No internet connection.';
        default:
          return e.message ?? 'Sign-in error.';
      }
    }
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'Not allowed. (If you tapped Accept, someone else may have taken it already.)';
      }
      if (e.code == 'unavailable') return 'No internet connection.';
      return e.message ?? 'Something went wrong.';
    }
    return e.toString();
  }

  // ---------- accounts ----------

  /// Create Account screen -> Continue
  static Future<void> signUp({
    required String mobile,
    required String password,
    required UserRole role,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailFor(mobile), password: password);
    await _db.doc('users/${cred.user!.uid}').set({
      'mobile': '+${_digits(mobile)}',
      'role': role.name, // 'resident' | 'respondent'
      'verified': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// "I already have an account"
  static Future<void> signIn({required String mobile, required String password}) =>
      _auth.signInWithEmailAndPassword(email: _emailFor(mobile), password: password);

  static Future<void> signOut() => _auth.signOut();

  /// Household Setup screen -> Save
  static Future<void> saveHousehold({
    required String name,
    required String barangay,
    required String address,
    required double lat,
    required double lng,
    required int members,
    required String mobilityNeed,
    List<String> notes = const [],
  }) =>
      _db.doc('households/$uid').set({
        'name': name,
        'barangay': barangay,
        'address': address,
        'location': GeoPoint(lat, lng),
        'members': members,
        'mobilityNeed': mobilityNeed,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Verify Code screen -> Verify.
  /// You create the codes by hand in Firestore: verificationCodes/123456 { role: 'resident', used: false }
  static Future<void> verifyCode(String code) async {
    final codeRef = _db.doc('verificationCodes/$code');
    final userRef = _db.doc('users/$uid');
    final snap = await codeRef.get();
    final data = snap.data();
    if (!snap.exists || data == null || data['used'] == true) {
      throw 'Invalid or already used code.';
    }
    final me = await userRef.get();
    if (data['role'] != me.data()?['role']) throw 'This code is for a different account type.';

    final batch = _db.batch();
    batch.update(codeRef, {'used': true, 'usedBy': uid});
    batch.update(userRef, {'verified': true, 'verifiedWith': code});
    await batch.commit();
  }

  /// Role / verified badge ("Verified" on the Home household card)
  static Stream<DocumentSnapshot<Map<String, dynamic>>> myProfile() =>
      _db.doc('users/$uid').snapshots();

  // ---------- location ----------

  /// Asks for permission and returns the phone's GPS position.
  static Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Turn on your phone location (GPS).';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw 'Location permission is needed so responders can find you.';
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  // ---------- emergency requests ----------

  /// "Request help now" -> returns the new request id.
  /// type: 'flood' | 'medical' | 'fire' | 'other'
  static Future<String> sendRequest({required String type, String? description}) async {
    final me = uid!;
    final active = await _db
        .collection('requests')
        .where('userId', isEqualTo: me)
        .where('status', whereIn: ['pending', 'matched'])
        .limit(1)
        .get();
    if (active.docs.isNotEmpty) throw 'You already have an active request.';

    final hh = await _db.doc('households/$me').get();
    if (!hh.exists) throw 'Complete your household profile first.';
    final h = hh.data()!;
    final pos = await currentPosition();

    final ref = _db.collection('requests').doc();
    final batch = _db.batch();
    batch.set(ref, {
      'userId': me,
      'type': type,
      'description': description,
      'address': h['address'],
      'barangay': h['barangay'],
      'location': GeoPoint(pos.latitude, pos.longitude),
      'status': 'pending',
      'responderId': null,
      'responderMobile': null,
      // snapshot so responders see the "Important responder notes"
      'household': {
        'name': h['name'],
        'members': h['members'],
        'mobilityNeed': h['mobilityNeed'],
        'notes': h['notes'] ?? [],
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.doc('publicMarkers/${ref.id}'), {
      'ownerId': me,
      'type': type,
      'status': 'pending',
      'lat': _round3(pos.latitude),
      'lng': _round3(pos.longitude),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_notifsOf(me).doc(),
        _notif('request_created', 'Request sent', body: 'Finding a verified responder near you.', requestId: ref.id));
    await batch.commit();
    return ref.id;
  }

  /// Requester cancels.
  static Future<void> cancelRequest(String id) async {
    final ref = _db.doc('requests/$id');
    final r = (await ref.get()).data();
    if (r == null) throw 'Request not found.';
    final batch = _db.batch();
    batch.update(ref, {'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});
    if (r['status'] == 'pending') batch.delete(_db.doc('publicMarkers/$id'));
    batch.set(_notifsOf(uid!).doc(), _notif('request_cancelled', 'Request cancelled', requestId: id));
    if (r['responderId'] != null) {
      batch.set(_notifsOf(r['responderId']).doc(),
          _notif('request_cancelled', 'Request was cancelled', requestId: id));
    }
    await batch.commit();
  }

  /// Verified responder accepts. If two try at once, the second fails (rules only allow pending -> matched).
  static Future<void> acceptRequest(String id) async {
    final ref = _db.doc('requests/$id');
    final r = (await ref.get()).data();
    if (r == null || r['status'] != 'pending') throw 'Request already taken or unavailable.';
    final me = await _db.doc('users/$uid').get();

    final batch = _db.batch();
    batch.update(ref, {
      'status': 'matched',
      'responderId': uid,
      'responderMobile': me.data()?['mobile'],
      'matchedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(_db.doc('publicMarkers/$id'));
    batch.set(_notifsOf(r['userId']).doc(),
        _notif('request_matched', 'A responder is on the way',
            body: 'A verified responder accepted your request.', requestId: id));
    await batch.commit();
  }

  /// Requester or the assigned responder marks it resolved.
  static Future<void> resolveRequest(String id) async {
    final ref = _db.doc('requests/$id');
    final r = (await ref.get()).data();
    if (r == null) throw 'Request not found.';
    final other = (r['userId'] == uid) ? r['responderId'] : r['userId'];
    final batch = _db.batch();
    batch.update(ref, {
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_notifsOf(uid!).doc(), _notif('request_resolved', 'Request resolved', requestId: id));
    if (other != null) {
      batch.set(_notifsOf(other).doc(), _notif('request_resolved', 'Request resolved', requestId: id));
    }
    await batch.commit();
  }

  /// Request status screen (live: pending -> matched -> resolved)
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchRequest(String id) =>
      _db.doc('requests/$id').snapshots();

  static List<Map<String, dynamic>> _sorted(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    list.sort((a, b) => _millis(b['createdAt']).compareTo(_millis(a['createdAt'])));
    return list;
  }

  /// Requests / history screen (newest first). Each item has an 'id' field.
  static Stream<List<Map<String, dynamic>>> myRequests() =>
      _db.collection('requests').where('userId', isEqualTo: uid).snapshots().map(_sorted);

  // ---------- responder side ----------

  /// Responder: go online/offline (shares your position for the "Responders online" count).
  static Future<void> setOnline(bool online) async {
    final data = <String, dynamic>{'online': online, 'updatedAt': FieldValue.serverTimestamp()};
    if (online) {
      final p = await currentPosition();
      data['lat'] = p.latitude;
      data['lng'] = p.longitude;
    }
    await _db.doc('presence/$uid').set(data, SetOptions(merge: true));
  }

  /// Responder: live list of requests waiting for help (newest first). Each item has an 'id'.
  static Stream<List<Map<String, dynamic>>> pendingRequests() =>
      _db.collection('requests').where('status', isEqualTo: 'pending').snapshots().map(_sorted);

  /// Responder: requests I accepted.
  static Stream<List<Map<String, dynamic>>> myAcceptedRequests() =>
      _db.collection('requests').where('responderId', isEqualTo: uid).snapshots().map(_sorted);

  // ---------- home / community ----------

  static Stream<DocumentSnapshot<Map<String, dynamic>>> myHousehold() =>
      _db.doc('households/$uid').snapshots();

  /// "Community updates" (you post these by hand in the console: collection `updates`).
  static Stream<QuerySnapshot<Map<String, dynamic>>> communityUpdates() => _db
      .collection('updates')
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots();

  /// Home "Community status": { respondersOnline, activeRequests, nearestCenter: {name, distanceKm} | null }
  static Future<Map<String, dynamic>> communityStatus(double lat, double lng) async {
    double km(num a, num b) =>
        Geolocator.distanceBetween(lat, lng, a.toDouble(), b.toDouble()) / 1000;

    final results = await Future.wait([
      _db.collection('presence').where('online', isEqualTo: true).get(),
      _db.collection('publicMarkers').get(),
      _db.collection('evacuationCenters').get(),
    ]);

    final cutoff = DateTime.now().subtract(const Duration(minutes: 30)).millisecondsSinceEpoch;
    final online = results[0].docs.where((d) {
      final x = d.data();
      return x['lat'] != null && km(x['lat'], x['lng']) <= nearbyKm && _millis(x['updatedAt']) >= cutoff;
    }).length;
    final active = results[1].docs.where((d) {
      final x = d.data();
      return x['lat'] != null && km(x['lat'], x['lng']) <= nearbyKm;
    }).length;

    Map<String, dynamic>? nearest;
    for (final c in results[2].docs) {
      final loc = c.data()['location'] as GeoPoint?;
      if (loc == null) continue;
      final d = km(loc.latitude, loc.longitude);
      if (nearest == null || d < (nearest['distanceKm'] as double)) {
        nearest = {'id': c.id, 'name': c.data()['name'], 'distanceKm': (d * 10).round() / 10};
      }
    }
    return {'respondersOnline': online, 'activeRequests': active, 'nearestCenter': nearest};
  }

  /// Map pins for the Community screen (each doc has lat, lng, type, status)
  static Stream<QuerySnapshot<Map<String, dynamic>>> mapMarkers() =>
      _db.collection('publicMarkers').snapshots();

  // ---------- notifications (live inside the app) ----------

  /// Notifications screen list
  static Stream<QuerySnapshot<Map<String, dynamic>>> notifications() =>
      _notifsOf(uid!).orderBy('createdAt', descending: true).limit(50).snapshots();

  /// Bell badge number
  static Stream<int> unreadCount() =>
      _notifsOf(uid!).where('isRead', isEqualTo: false).snapshots().map((s) => s.size);

  static Future<void> markRead(String id) => _notifsOf(uid!).doc(id).update({'isRead': true});
  static Future<void> deleteNotification(String id) => _notifsOf(uid!).doc(id).delete();

  static Future<void> markAllRead() async {
    final snap = await _notifsOf(uid!).where('isRead', isEqualTo: false).limit(400).get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'isRead': true});
    }
    await batch.commit();
  }
}