// ============================================================
// AKAY - FREE backend (Firebase Spark plan: no Cloud Functions, no credit card).
// The screens only call AkayBackend.something(); no Firebase code in the UI.
// The security lives in firestore.rules.
// ============================================================
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'create_account_screens.dart' show UserRole;

/// An expected application error with a safe message intended for the user.
/// Unexpected exception details must go through [AkayBackend.friendlyError].
class AkayException implements Exception {
  const AkayException(this.message);

  final String message;

  @override
  String toString() => message;
}

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

  /// Converts expected errors into safe, user-facing messages.
  /// Unknown SDK or programming errors always receive a generic message.
  static String friendlyError(Object error) {
    if (error is! AkayException &&
        !(error is FirebaseException &&
            (error.code == 'unavailable' ||
                error.code == 'network-request-failed'))) {
      logError(error, null, 'shown to user');
    }

    if (error is AkayException) return error.message;

    if (error is FirebaseAuthException) {
      switch (error.code) {
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
        case 'user-disabled':
          return 'This account is disabled. Contact the AKAY administrator.';
        default:
          return 'We could not complete sign-in. Please try again.';
      }
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You are not allowed to do that.';
        case 'unauthenticated':
          return 'Please sign in again and try once more.';
        case 'unavailable':
        case 'network-request-failed':
          return 'No internet connection. Please try again.';
        case 'deadline-exceeded':
          return 'The request took too long. Please try again.';
        case 'not-found':
          return 'The requested information could not be found.';
        case 'already-exists':
          return 'That item already exists.';
        case 'resource-exhausted':
          return 'The service is busy. Please try again shortly.';
        case 'cancelled':
          return 'The action was cancelled.';
        default:
          return 'Something went wrong. Please try again.';
      }
    }

    return 'Something went wrong. Please try again.';
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
        'accountStatus': 'active',
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
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: _emailFor(mobile),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AkayException('We could not sign in. Please try again.');
      }

      // A user can read only their own profile so this check can reject a
      // deactivated account before the app opens.
      final profile = await _db.doc('users/${user.uid}').get();
      final accountStatus = profile.data()?['accountStatus'];

      if (!profile.exists || accountStatus == 'deleted') {
        await _auth.signOut();
        throw const AkayException('This AKAY account has been deactivated.');
      }
    } catch (_) {
      // Do not leave an Auth session open if the profile check fails.
      await _auth.signOut();
      rethrow;
    }
  }

  /// Marks the signed-in account as deleted and signs it out.
  /// The Firebase Auth account and its Firestore data remain stored.
  static Future<void> deactivateAccount({
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AkayException('Please sign in again and try once more.');
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AkayException('We could not verify this account.');
    }

    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(
        email: email,
        password: password,
      ),
    );

    await _db.doc('users/${user.uid}').update({
      'accountStatus': 'deleted',
      'deletedAt': FieldValue.serverTimestamp(),
    });

    // Firestore rules reject app access once accountStatus is deleted.
    await _auth.signOut();
  }

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
  /// Codes are created by hand in the console: verificationCodes/<6-digit code> { role, used: false, expiresAt }
  static Future<void> verifyCode(String raw) async {
    final code = raw.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      throw const AkayException('Invalid or already used code.');
    }
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
        throw const AkayException('Invalid or already used code.');
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
      throw const AkayException('Turn on your phone location (GPS).');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw const AkayException(
        'Location permission is needed so responders can find you.',
      );
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
    if (active.docs.isNotEmpty) {
      throw const AkayException('You already have an active request.');
    }

    final hh = await _db.doc('households/$me').get();
    if (!hh.exists) {
      throw const AkayException('Complete your household profile first.');
    }
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
  static Future<void> cancelRequest(String id) async {
    final me = uid!;
    final ref = _db.doc('requests/$id');
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final r = snapshot.data();
      if (r == null) {
        throw const AkayException('Request not found.');
      }
      if (r['userId'] != me) {
        throw const AkayException('You can only cancel your own request.');
      }
      if (r['status'] != 'pending' && r['status'] != 'matched') {
        throw const AkayException('This request can no longer be cancelled.');
      }
      final requesterId = r['userId'] as String;
      final responderId = r['responderId'] as String?;
      // All reads are complete before any transaction writes.
      transaction.delete(_db.doc('activeRequests/$requesterId'));
      if (responderId != null) {
        transaction.delete(_db.doc('responderActive/$responderId'));
      }
      transaction.update(ref, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (r['status'] == 'pending') {
        transaction.delete(_db.doc('publicMarkers/$id'));
      }
      transaction.set(
        _notifsOf(me).doc(),
        _notif('request_cancelled', 'Request cancelled', requestId: id),
      );
      if (responderId != null) {
        transaction.set(
          _notifsOf(responderId).doc(),
          _notif('request_cancelled', 'Request was cancelled', requestId: id),
        );
      }
    });
  }

  static Future<void> acceptRequest(String id) async {
    final me = uid!;
    final ref = _db.doc('requests/$id');
    try {
      await _db.runTransaction((transaction) async {
        final requestSnapshot = await transaction.get(ref);
        final r = requestSnapshot.data();
        if (r == null || r['status'] != 'pending') {
          throw const AkayException('Request already taken or unavailable.');
        }
        if (r['userId'] == me) {
          throw const AkayException('You cannot accept your own request.');
        }
        final profileSnapshot = await transaction.get(_db.doc('users/$me'));
        final mobile = profileSnapshot.data()?['mobile'] as String?;
        if (mobile == null || mobile.isEmpty) {
          throw const AkayException('Your account is missing a mobile number.');
        }
        final requesterId = r['userId'] as String;
        // All reads are complete before any transaction writes.
        transaction.update(ref, {
          'status': 'matched',
          'responderId': me,
          'responderMobile': mobile,
          'matchedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(_db.doc('responderActive/$me'), {'requestId': id});
        transaction.delete(_db.doc('publicMarkers/$id'));
        transaction.set(
          _notifsOf(requesterId).doc(),
          _notif(
            'request_matched',
            'A responder is on the way',
            body: 'A verified responder accepted your request.',
            requestId: id,
          ),
        );
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const AkayException(
          'Could not accept. It may already be taken, or you already have an active job.',
        );
      }
      rethrow;
    }
  }

  static Future<void> resolveRequest(String id) async {
    final me = uid!;
    final ref = _db.doc('requests/$id');
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final r = snapshot.data();
      if (r == null) {
        throw const AkayException('Request not found.');
      }
      if (r['status'] != 'matched') {
        throw const AkayException('Only a matched request can be resolved.');
      }
      final requesterId = r['userId'] as String;
      final responderId = r['responderId'] as String?;
      if (me != requesterId && me != responderId) {
        throw const AkayException('You are not part of this request.');
      }
      final otherId = me == requesterId ? responderId : requesterId;
      // All reads are complete before any transaction writes.
      transaction.delete(_db.doc('activeRequests/$requesterId'));
      if (responderId != null) {
        transaction.delete(_db.doc('responderActive/$responderId'));
      }
      transaction.update(ref, {
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        _notifsOf(me).doc(),
        _notif('request_resolved', 'Request resolved', requestId: id),
      );
      if (otherId != null) {
        transaction.set(
          _notifsOf(otherId).doc(),
          _notif('request_resolved', 'Request resolved', requestId: id),
        );
      }
    });
  }

  static Future<void> releaseRequest(String id) async {
    final ref = _db.doc('requests/$id');
    final r = (await ref.get()).data();
    if (r == null || r['responderId'] != uid || r['status'] != 'matched') {
      throw const AkayException('This request is not assigned to you.');
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
      throw const AkayException('This request cannot be re-opened.');
    }
    final matchedAt = r['matchedAt'];
    if (matchedAt is! Timestamp ||
        DateTime.now().difference(matchedAt.toDate()) < reopenAfter) {
      throw const AkayException(
        'You can re-open this request 15 minutes after a responder accepts it.',
      );
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
  /// Requests this responder declined are hidden.
  static Stream<List<Map<String, dynamic>>> pendingRequests() => _db
      .collection('requests')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .asyncMap((snap) async {
        final declined = await _declinedIds();
        return _sorted(snap).where((r) => !declined.contains(r['id'])).toList();
      });

  static Future<Set<String>> _declinedIds() async {
    try {
      final s = await _db.collection('responderDeclines/$uid/items').get();
      return s.docs.map((d) => d.id).toSet();
    } catch (_) {
      return {}; // offline or not allowed: just show everything
    }
  }

  /// Responder: "Decline - show next responder". Hides this request from MY list only.
  static Future<void> declineRequest(String requestId) =>
      _db.doc('responderDeclines/$uid/items/$requestId').set({
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Responder: "Report suspicious ping". Admins read the `reports` collection in the console.
  static Future<void> reportRequest(String requestId, {String? reason}) =>
      _db.collection('reports').add({
        'reporterId': uid,
        'requestId': requestId,
        'reason': (reason ?? 'Suspicious ping').trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Responder: evacuation-center check-in (wireframe 12).
  /// Works offline: Firestore keeps the write on the phone and sends it later.
  /// We do NOT await it for that reason; use [hasPendingWrites] to show "Waiting to sync".
  static Future<void> checkInHousehold({
    required String household,
    required int membersPresent,
  }) {
    final write = _db.collection('checkIns').add({
      'responderId': uid,
      'household': household.trim(),
      'membersPresent': membersPresent,
      'allConfirmed': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return write;
  }

  // ---------- resident: evacuation status (wireframe 08) ----------

  /// 'home' | 'transit' | 'evacuated'
  static Future<void> setEvacuationStatus(String status) =>
      _db.doc('evacuationStatus/$uid').set({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Stream<DocumentSnapshot<Map<String, dynamic>>> myEvacuationStatus() =>
      _db.doc('evacuationStatus/$uid').snapshots();

  /// True while a write is still only on this phone (drives "Waiting to sync").
  static Stream<bool> hasPendingWrites() => _db
      .doc('evacuationStatus/$uid')
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.metadata.hasPendingWrites);

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

  // ============================================================
  // ADMIN (demonstration and testing only)
  // The admin account (admin, 00000000) is created by hand in the Firebase console.
  // firestore.rules -> isAdmin() checks the same mobile value, so these calls fail for everyone else.
  // ============================================================

  static const String adminMobile = '00000000';

  /// How long a normal pin works, and how long a demo pin works.
  static const Duration pinLifetime = Duration(minutes: 30);
  static const Duration demoPinLifetime = Duration(hours: 24);

  static bool isAdminProfile(Map<String, dynamic>? profile) =>
      profile != null && profile['mobile'] == adminMobile;

  // ---------- admin: accounts ----------

  /// Every account (newest first). Each item has 'id' (the uid), mobile, role, verified, createdAt.
  static Stream<List<Map<String, dynamic>>> adminUsers() =>
      _db.collection('users').snapshots().map(_sorted);

  // ---------- admin: one-time pins ----------

  /// Every pin (newest first). Each item has 'id' (the 6 digits), role, used, expiresAt, demo,
  /// and forUid / forMobile when it was made for one account.
  static Stream<List<Map<String, dynamic>>> adminPins() =>
      _db.collection('verificationCodes').snapshots().map(_sorted);

  /// Creates a one-time pin: verificationCodes/pin { role, used: false, expiresAt, ... }.
  /// The same document is what [verifyCode] redeems.
  /// [demo] makes a long-lived "special" pin, and [customPin] lets you choose its 6 digits.
  static Future<String> adminCreatePin({
    required String role,
    String? forUid,
    String? forMobile,
    bool demo = false,
    String? customPin,
  }) async {
    final me = uid;
    if (me == null) {
      throw const AkayException('Sign in first.');
    }
    if (role != 'resident' && role != 'respondent') {
      throw const AkayException('Pins can only be made for residents or responders.');
    }
    final custom = (customPin ?? '').replaceAll(RegExp(r'\D'), '');
    final wantsCustom = custom.isNotEmpty;
    if (wantsCustom && custom.length != 6) {
      throw const AkayException('A pin must be exactly 6 digits.');
    }

    final life = demo ? demoPinLifetime : pinLifetime;
    for (var attempt = 0; attempt < 8; attempt++) {
      final pin = wantsCustom
          ? custom
          : (Random.secure().nextInt(900000) + 100000).toString();
      final ref = _db.doc('verificationCodes/$pin');
      try {
        if ((await ref.get()).exists) {
          if (wantsCustom) {
            throw const AkayException('That pin already exists. Choose another one.');
          }
          continue; // random pin collided with an existing one: try another
        }
        await ref.set({
          'role': role,
          'used': false,
          'expiresAt': Timestamp.fromDate(DateTime.now().add(life)),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': me,
          'demo': demo,
          'forUid': ?forUid,
          'forMobile': ?forMobile,
        });
        return pin;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          throw const AkayException(
            'Could not save the pin. Deploy the latest firestore.rules and sign in as the admin.',
          );
        }
        rethrow;
      }
    }
    throw const AkayException('Could not find a free pin. Try again.');
  }

  /// Pin for one new account (role and mobile are copied from the account).
  /// [replacePins] are older unused pins of that account; they are revoked.
  static Future<String> adminIssuePinForUser(
    Map<String, dynamic> user, {
    List<String> replacePins = const [],
  }) async {
    final pin = await adminCreatePin(
      role: (user['role'] ?? '').toString(),
      forUid: user['id']?.toString(),
      forMobile: user['mobile']?.toString(),
    );
    for (final old in replacePins) {
      try {
        await adminRevokePin(old);
      } catch (_) {
        // an old pin that cannot be removed will simply expire
      }
    }
    return pin;
  }

  /// Deletes a pin nobody has used yet.
  static Future<void> adminRevokePin(String pin) =>
      _db.doc('verificationCodes/$pin').delete();

  // ---------- admin: error log ----------

  static final Map<String, DateTime> _recentErrors = {};

  static String _clip(String text, int max) =>
      text.length <= max ? text : text.substring(0, max);

  static Future<void> _writeErrorLog(
    Object error,
    StackTrace? stack,
    String? source,
  ) async {
    await _db.collection('errorLogs').add({
      'uid': uid,
      'source': source,
      'message': _clip(error.toString(), 500),
      'stack': stack == null ? null : _clip(stack.toString(), 2000),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Saves an exception for the admin (Admin screen -> Error log). Never throws, never waits.
  /// The same error within one minute is saved only once.
  static void logError(Object error, [StackTrace? stack, String? source]) {
    try {
      if (uid == null) return; // the rules only accept signed-in users
      final key = '${source ?? ''}|${error.toString()}';
      final now = DateTime.now();
      final last = _recentErrors[key];
      if (last != null && now.difference(last) < const Duration(minutes: 1)) {
        return;
      }
      if (_recentErrors.length > 50) _recentErrors.clear();
      _recentErrors[key] = now;
      _writeErrorLog(error, stack, source).catchError((_) {});
    } catch (_) {
      // logging must never cause another error
    }
  }

  /// "Log Test Exception": throws a real exception, catches it and saves it.
  /// Unlike [logError] this waits, so the admin sees when saving fails.
  static Future<void> adminLogTestException() async {
    try {
      throw StateError('Test exception from the admin screen');
    } catch (e, st) {
      await _writeErrorLog(e, st, 'admin test').timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw const AkayException(
          'No internet connection. The entry will be saved when you are back online.',
        ),
      );
    }
  }

  /// Newest 100 entries. Each item has 'id', uid, source, message, stack, createdAt.
  static Stream<List<Map<String, dynamic>>> adminErrorLogs() => _db
      .collection('errorLogs')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  static Future<void> adminDeleteErrorLog(String id) =>
      _db.doc('errorLogs/$id').delete();

  static Future<void> adminClearErrorLogs(List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _db.batch();
    for (final id in ids.take(400)) {
      batch.delete(_db.doc('errorLogs/$id'));
    }
    await batch.commit();
  }
}