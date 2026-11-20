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
  static const Duration reopenAfter = Duration(minutes: 15);

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
      ts is Timestamp ? ts.millisecondsSinceEpoch : 0;

  static double _round3(double n) => (n * 1000).round() / 1000; // ~110 m

  static double _round2(double n) => (n * 100).round() / 100; // ~1 km

  static CollectionReference<Map<String, dynamic>> _notifsOf(String userId) =>
      _db.collection('notifications').doc(userId).collection('items');

  static Map<String, dynamic> _notif(
    String type,
    String title, {
    String? body,
    String? requestId,
  }) => {
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
          return 'We could not create this account. Check your details, or sign in if you already registered.';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-email':
          return 'Wrong mobile number or password.';
        case 'weak-password':
        case 'password-does-not-meet-requirements':
          return 'Use at least 8 characters.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
        case 'network-request-failed':
          return 'No internet connection.';
        default:
          return 'Something went wrong. Please try again.';
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
      email: _emailFor(mobile),
      password: password,
    );
    try {
      await _db.doc('users/${cred.user!.uid}').set({
        'mobile': '+${_digits(mobile)}',
        'role': role.name, // 'resident' | 'respondent'
        'verified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      await cred.user?.delete().catchError((_) {});
      rethrow;
    }
  }

  /// "I already have an account"
  static Future<void> signIn({
    required String mobile,
    required String password,
  }) => _auth.signInWithEmailAndPassword(
    email: _emailFor(mobile),
    password: password,
  );

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
    List<String>? notes,
  }) async {
    final ref = _db.doc('households/$uid');
    final existing = await ref.get();
    await ref.set({
      'name': name,
      'barangay': barangay,
      'address': address,
      'location': GeoPoint(lat, lng),
      'members': members,
      'mobilityNeed': mobilityNeed,
      if (notes != null || !existing.exists) 'notes': notes ?? <String>[],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Verify Code screen -> Verify.
  /// Codes are created by hand in the console: verificationCodes/<16-char code> { role, used: false, expiresAt }
  static Future<void> verifyCode(String raw) async {
    final code = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (code.length != 16) throw 'Invalid or already used code.';
    final batch = _db.batch();
    batch.update(_db.doc('verificationCodes/$code'), {
      'used': true,
      'usedBy': uid,
    });
    batch.update(_db.doc('users/$uid'), {
      'verified': true,
      'verifiedWith': code,
    });
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        throw 'Invalid or already used code.';
      }
      rethrow;
    }
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
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw 'Location permission is needed so responders can find you.';
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  // ---------- emergency requests ----------

  /// "Request help now" -> returns the new request id.
  /// type: 'flood' | 'medical' | 'fire' | 'other'
  static Future<String> sendRequest({
    required String type,
    String? description,
  }) async {
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
      'barangay': h['barangay'],
      'location': GeoPoint(_round3(pos.latitude), _round3(pos.longitude)),
      'status': 'pending',
      'responderId': null,
      'responderMobile': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.doc('requestDetails/${ref.id}'), {
      'userId': me,
      'address': h['address'],
      'location': GeoPoint(pos.latitude, pos.longitude),
      'description': description,
      'household': {
        'name': h['name'],
        'members': h['members'],
        'mobilityNeed': h['mobilityNeed'],
        'notes': h['notes'] ?? [],
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.doc('publicMarkers/${ref.id}'), {
      'type': type,
      'status': 'pending',
      'lat': _round2(pos.latitude),
      'lng': _round2(pos.longitude),
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
    });
    batch.set(_db.doc('activeRequests/$me'), {'requestId': ref.id});
    batch.set(
      _notifsOf(me).doc(),
      _notif(
        'request_created',
        'Request sent',
        body: 'Finding a verified responder near you.',
        requestId: ref.id,
      ),
    );
    await batch.commit();
    return ref.id;
  }

  /// Requester cancels.
    /// Requester cancels.
  static Future<void> cancelRequest(String id) async {
    final ref = _db.doc('requests/$id');
    final r = (await ref.get()).data();
    if (r == null) throw 'Request not found.';
    final batch = _db.batch();
    batch.delete(_db.doc('activeRequests/${r['userId']}'));
    if (r['responderId'] != null) {
      batch.delete(_db.doc('responderActive/${r['responderId']}'));
    }
    batch.update(ref, {
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (r['status'] == 'pending') batch.delete(_db.doc('publicMarkers/$id'));
    batch.set(
      _notifsOf(uid!).doc(),
      _notif('request_cancelled', 'Request cancelled', requestId: id),
    );
    if (r['responderId'] != null) {
      batch.set(
        _notifsOf(r['responderId']).doc(),
        _notif('request_cancelled', 'Request was cancelled', requestId: id),
      );
    }
    await batch.commit();
  }

  /// Verified responder accepts. If two try at once, the second fails (rules only allow pending -> matched).
    /// Verified responder accepts. If two try at once, the second fails (rules only allow pending -> matched).
  /// A responder can hold one active job at a time.
  static Future<void> acceptRequest(String id) async {
    final ref = _db.doc('requests/$id');
    final r = (await ref.get()).data();
    if (r == null || r['status'] != 'pending') {
      throw 'Request already taken or unavailable.';
    }
    final me = await _db.doc('users/$uid').get();

    final batch = _db.batch();
    batch.update(ref, {
      'status': 'matched',
      'responderId': uid,
      'responderMobile': me.data()?['mobile'],
      'matchedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.doc('responderActive/$uid'), {'requestId': id});
    batch.delete(_db.doc('publicMarkers/$id'));
    batch.set(
      _notifsOf(r['userId']).doc(),
      _notif(
        'request_matched',
        'A responder is on the way',
        body: 'A verified responder accepted your request.',
        requestId: id,
      ),
    );
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw 'Could not accept. It may already be taken, or you already have an active job.';
      }
      rethrow;
    }
  }

  /// Requester or the assigned responder marks it resolved.
    /// Requester or the assigned responder marks it resolved.
  static Future<void> resolveRequest(String id) async {
    final ref = _db.doc('requests/$id');
    final r = (await ref.get()).data();
    if (r == null) throw 'Request not found.';
    final other = (r['userId'] == uid) ? r['responderId'] : r['userId'];
    final batch = _db.batch();
    batch.delete(_db.doc('activeRequests/${r['userId']}'));
    if (r['responderId'] != null) {
      batch.delete(_db.doc('responderActive/${r['responderId']}'));
    }
    batch.update(ref, {
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _notifsOf(uid!).doc(),
      _notif('request_resolved', 'Request resolved', requestId: id),
    );
    if (other != null) {
      batch.set(
        _notifsOf(other).doc(),
        _notif('request_resolved', 'Request resolved', requestId: id),
      );
    }
    await batch.commit();
  }
    /// Assigned responder hands the request back so another responder can take it.
  static Future<void> releaseRequest(String id) async {
    final ref = _db.doc('requests/$id');
    final r = (await ref.get()).data();
    if (r == null || r['responderId'] != uid || r['status'] != 'matched') {
      throw 'This request is not assigned to you.';
    }
    final loc = r['location'] as GeoPoint;
    final batch = _db.batch();
    batch.update(ref, {
      'status': 'pending',
      'responderId': null,
      'responderMobile': null,
      'matchedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(_db.doc('responderActive/$uid'));
    batch.set(_db.doc('publicMarkers/$id'), {
      'type': r['type'],
      'status': 'pending',
      'lat': _round2(loc.latitude),
      'lng': _round2(loc.longitude),
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
    });
    batch.set(
      _notifsOf(r['userId']).doc(),
      _notif(
        'request_released',
        'Your responder had to step away',
        body: 'Finding another verified responder near you.',
        requestId: id,
      ),
    );
    await batch.commit();
  }

  /// Requester re-opens a request whose responder has not resolved it after [reopenAfter].
  static Future<void> reopenRequest(String id) async {
    final ref = _db.doc('requests/$id');
    final r = (await ref.get()).data();
    if (r == null || r['userId'] != uid || r['status'] != 'matched') {
      throw 'This request cannot be re-opened.';
    }
    final matchedAt = r['matchedAt'];
    if (matchedAt is! Timestamp ||
        DateTime.now().difference(matchedAt.toDate()) < reopenAfter) {
      throw 'You can re-open this request 15 minutes after a responder accepts it.';
    }
    final loc = r['location'] as GeoPoint;
    final batch = _db.batch();
    batch.update(ref, {
      'status': 'pending',
      'responderId': null,
      'responderMobile': null,
      'matchedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(_db.doc('responderActive/${r['responderId']}'));
    batch.set(_db.doc('publicMarkers/$id'), {
      'type': r['type'],
      'status': 'pending',
      'lat': _round2(loc.latitude),
      'lng': _round2(loc.longitude),
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
    });
    await batch.commit();
  }

  /// Request status screen (live: pending -> matched -> resolved)
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchRequest(
    String id,
  ) => _db.doc('requests/$id').snapshots();

  /// Exact location, address, description and household of a request.
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchRequestDetails(
    String id,
  ) => _db.doc('requestDetails/$id').snapshots();

  static List<Map<String, dynamic>> _sorted(
    QuerySnapshot<Map<String, dynamic>> s,
  ) {
    final list = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    list.sort(
      (a, b) => _millis(b['createdAt']).compareTo(_millis(a['createdAt'])),
    );
    return list;
  }

  /// Requests / history screen (newest first). Each item has an 'id' field.
  static Stream<List<Map<String, dynamic>>> myRequests() => _db
      .collection('requests')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map(_sorted);

  // ---------- responder side ----------

  /// Responder: go online/offline (shares a coarse ~1 km position for the "Responders online" count).
  static Future<void> setOnline(bool online) async {
    final data = <String, dynamic>{
      'online': online,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (online) {
      final p = await currentPosition();
      data['lat'] = _round2(p.latitude);
      data['lng'] = _round2(p.longitude);
    }
    await _db.doc('presence/$uid').set(data, SetOptions(merge: true));
  }

  /// Responder: live list of requests waiting for help (newest first). Each item has an 'id'.
  static Stream<List<Map<String, dynamic>>> pendingRequests() => _db
      .collection('requests')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map(_sorted);

  /// Responder: requests I accepted.
  static Stream<List<Map<String, dynamic>>> myAcceptedRequests() => _db
      .collection('requests')
      .where('responderId', isEqualTo: uid)
      .snapshots()
      .map(_sorted);

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
  static Future<Map<String, dynamic>> communityStatus(
    double lat,
    double lng,
  ) async {
    double km(double a, double b) =>
        Geolocator.distanceBetween(lat, lng, a, b) / 1000;

    double? asNum(dynamic v) => v is num ? v.toDouble() : null;

    // Presence is readable by verified users only; unverified users see 0.
    Future<QuerySnapshot<Map<String, dynamic>>?> presenceGet() async {
      try {
        return await _db
            .collection('presence')
            .where('online', isEqualTo: true)
            .get();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') return null;
        rethrow;
      }
    }

    final results = await Future.wait([
      presenceGet(),
      _db.collection('publicMarkers').get(),
      _db.collection('evacuationCenters').get(),
    ]);

    final presenceSnap = results[0];
    final markerSnap = results[1]!;
    final centerSnap = results[2]!;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cutoff = DateTime.now()
        .subtract(const Duration(minutes: 30))
        .millisecondsSinceEpoch;
    var online = 0;
    for (final d in presenceSnap?.docs ?? const []) {
      final x = d.data();
      final pLat = asNum(x['lat']);
      final pLng = asNum(x['lng']);
      if (pLat == null || pLng == null) continue;
      if (km(pLat, pLng) <= nearbyKm && _millis(x['updatedAt']) >= cutoff) {
        online++;
      }
    }
    var active = 0;
    for (final d in markerSnap.docs) {
      final x = d.data();
      final mLat = asNum(x['lat']);
      final mLng = asNum(x['lng']);
      if (mLat == null || mLng == null) continue;
      final exp = x['expiresAt'];
      if (exp is Timestamp && exp.millisecondsSinceEpoch < nowMs) continue;
      if (km(mLat, mLng) <= nearbyKm) active++;
    }

    Map<String, dynamic>? nearest;
    for (final c in centerSnap.docs) {
      final loc = c.data()['location'];
      if (loc is! GeoPoint) continue;
      final d = km(loc.latitude, loc.longitude);
      if (nearest == null || d < (nearest['distanceKm'] as double)) {
        nearest = {
          'id': c.id,
          'name': c.data()['name'],
          'distanceKm': (d * 10).round() / 10,
        };
      }
    }
    return {
      'respondersOnline': online,
      'activeRequests': active,
      'nearestCenter': nearest,
    };
  }

  /// Map pins for the Community screen (each doc has lat, lng, type, status)
  static Stream<QuerySnapshot<Map<String, dynamic>>> mapMarkers() =>
      _db.collection('publicMarkers').snapshots();

  // ---------- notifications (live inside the app) ----------

  /// Notifications screen list
  static Stream<QuerySnapshot<Map<String, dynamic>>> notifications() {
    final me = uid;
    if (me == null) return const Stream.empty();
    return _notifsOf(
      me,
    ).orderBy('createdAt', descending: true).limit(50).snapshots();
  }

  /// Bell badge number
  static Stream<int> unreadCount() {
    final me = uid;
    if (me == null) return Stream.value(0);
    return _notifsOf(
      me,
    ).where('isRead', isEqualTo: false).snapshots().map((s) => s.size);
  }

  static Future<void> markRead(String id) async {
    final me = uid;
    if (me == null) return;
    await _notifsOf(me).doc(id).update({'isRead': true});
  }

  static Future<void> deleteNotification(String id) async {
    final me = uid;
    if (me == null) return;
    await _notifsOf(me).doc(id).delete();
  }

  static Future<void> markAllRead() async {
    final me = uid;
    if (me == null) return;
    final snap = await _notifsOf(
      me,
    ).where('isRead', isEqualTo: false).limit(400).get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'isRead': true});
    }
    await batch.commit();
  }
}