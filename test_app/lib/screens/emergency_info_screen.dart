import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'; // showComingSoon
import '../main.dart';
import 'screen_widgets.dart';

// Emergency details stay readable offline. The most recent Firestore advisory
// and evacuation center are copied to local preferences after a signed-in sync.
const _defaultAlertTitle = 'EMERGENCY INFORMATION';
const _defaultAlertMessage =
    'No saved advisory is available. Follow current instructions from local emergency officials.';
const _advisoryTitleKey = 'akay.emergency.advisory.title';
const _advisoryBodyKey = 'akay.emergency.advisory.body';
const _advisoryUpdatedKey = 'akay.emergency.advisory.updatedAtMs';
const _centerNameKey = 'akay.emergency.center.name';
const _centerLatitudeKey = 'akay.emergency.center.latitude';
const _centerLongitudeKey = 'akay.emergency.center.longitude';
const _centerDistanceKey = 'akay.emergency.center.distanceKm';

class EmergencyInfoScreen extends StatefulWidget {
  const EmergencyInfoScreen({super.key});

  @override
  State<EmergencyInfoScreen> createState() => _EmergencyInfoScreenState();
}

class _EmergencyInfoScreenState extends State<EmergencyInfoScreen> {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _updatesSubscription;

  String _alertTitle = _defaultAlertTitle;
  String _alertMessage = _defaultAlertMessage;
  DateTime? _advisoryUpdatedAt;
  Map<String, dynamic>? _center;
  bool _loadingCenter = true;
  bool _openingRoute = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _loadCachedInformation();
    if (!mounted) return;
    if (AkayBackend.isSignedIn) {
      _watchLatestAdvisory();
      await _loadAndCacheCenter();
    } else {
      setState(() => _loadingCenter = false);
    }
  }

  Future<void> _loadCachedInformation() async {
    try {
      final title = await _preferences.getString(_advisoryTitleKey);
      final body = await _preferences.getString(_advisoryBodyKey);
      final updatedAtMs = await _preferences.getInt(_advisoryUpdatedKey);
      final centerName = await _preferences.getString(_centerNameKey);
      final centerLatitude = await _preferences.getDouble(_centerLatitudeKey);
      final centerLongitude = await _preferences.getDouble(_centerLongitudeKey);
      final centerDistance = await _preferences.getDouble(_centerDistanceKey);

      if (!mounted) return;
      setState(() {
        if (title != null && title.trim().isNotEmpty) _alertTitle = title;
        if (body != null && body.trim().isNotEmpty) _alertMessage = body;
        if (updatedAtMs != null) {
          _advisoryUpdatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
        }
        if (centerName != null &&
            centerLatitude != null &&
            centerLongitude != null) {
          _center = {
            'name': centerName,
            'latitude': centerLatitude,
            'longitude': centerLongitude,
            if (centerDistance != null) 'distanceKm': ?centerDistance,
          };
        }
      });
    } catch (_) {
      // Keep the built-in safety guidance available if local storage fails.
    }
  }

  void _watchLatestAdvisory() {
    _updatesSubscription = AkayBackend.communityUpdates().listen(
      (snapshot) {
        if (snapshot.docs.isEmpty) return;
        final advisory = snapshot.docs.first.data();
        final title = advisory['title']?.toString().trim() ?? '';
        final body = advisory['body']?.toString().trim() ?? '';
        if (title.isEmpty && body.isEmpty) return;

        final createdAt = advisory['createdAt'];
        final updatedAt = createdAt is Timestamp ? createdAt.toDate() : null;
        if (mounted) {
          setState(() {
            if (title.isNotEmpty) _alertTitle = title;
            if (body.isNotEmpty) _alertMessage = body;
            _advisoryUpdatedAt = updatedAt ?? DateTime.now();
          });
        }
        _saveAdvisory(title, body, updatedAt ?? DateTime.now());
      },
      onError: (Object _) {
        // Use the last cached advisory when Firestore is unavailable.
      },
    );
  }

  Future<void> _saveAdvisory(
    String title,
    String body,
    DateTime updatedAt,
  ) async {
    try {
      if (title.isNotEmpty) await _preferences.setString(_advisoryTitleKey, title);
      if (body.isNotEmpty) await _preferences.setString(_advisoryBodyKey, body);
      await _preferences.setInt(
        _advisoryUpdatedKey,
        updatedAt.millisecondsSinceEpoch,
      );
    } catch (_) {
      // A failed cache write must not hide the live advisory.
    }
  }

  Future<void> _loadAndCacheCenter() async {
    try {
      final center = await AkayBackend.nearestEvacuationCenter();
      if (center != null) {
        await _preferences.setString(
          _centerNameKey,
          center['name'].toString(),
        );
        await _preferences.setDouble(
          _centerLatitudeKey,
          (center['latitude'] as num).toDouble(),
        );
        await _preferences.setDouble(
          _centerLongitudeKey,
          (center['longitude'] as num).toDouble(),
        );
        final distance = center['distanceKm'];
        if (distance is num) {
          await _preferences.setDouble(_centerDistanceKey, distance.toDouble());
        }
        if (mounted) setState(() => _center = center);
      }
    } catch (_) {
      // Reuse the saved center if Firestore is offline or unavailable.
    } finally {
      if (mounted) setState(() => _loadingCenter = false);
    }
  }

  Future<void> _openEvacuationRoute() async {
    final center = _center;
    final latitude = center?['latitude'];
    final longitude = center?['longitude'];
    if (latitude is! num || longitude is! num) {
      showComingSoon(
        context,
        'No evacuation center is saved yet. Connect while signed in to load the center list.',
      );
      return;
    }

    setState(() => _openingRoute = true);
    try {
      final uri = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '${latitude.toDouble()},${longitude.toDouble()}',
        'travelmode': 'walking',
      });
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        showComingSoon(context, 'Could not open a map application.');
      }
    } catch (error) {
      if (mounted) showComingSoon(context, AkayBackend.friendlyError(error));
    } finally {
      if (mounted) setState(() => _openingRoute = false);
    }
  }

  String get _advisorySavedLabel {
    final updatedAt = _advisoryUpdatedAt;
    if (updatedAt == null) return 'Built-in guidance is available offline.';
    return 'Latest advisory saved on this phone · '
        '${TimeOfDay.fromDateTime(updatedAt).format(context)}';
  }

  String get _centerDescription {
    final center = _center;
    if (center == null) {
      return _loadingCenter
          ? 'Loading the nearest evacuation center…'
          : 'Center details will appear after they sync to this phone.';
    }
    final distance = center['distanceKm'];
    if (distance is num) return 'About ${distance.toStringAsFixed(1)} km away.';
    return 'Saved evacuation-center location.';
  }

  @override
  void dispose() {
    _updatesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final centerName = (_center?['name'] ?? 'Nearest evacuation center')
        .toString();
    final steps = [
      (
        '01',
        'Prepare to evacuate',
        'Bring medicine, IDs, water, and your emergency bag.',
      ),
      (
        '02',
        'Follow the official evacuation route',
        'Use the latest route provided by emergency responders and barangay officials. Avoid flooded or closed roads.',
      ),
      ('03', centerName, _centerDescription),
    ];

    return AkayScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusBanner(
            tone: BannerTone.warning,
            icon: Icons.warning_amber_rounded,
            title: _alertTitle,
            message: _alertMessage,
          ),
          const SizedBox(height: 20),
          ScreenTitle(
            label: 'SAVED ON THIS PHONE',
            title: 'Emergency information',
            subtitle: _advisorySavedLabel,
          ),
          const SizedBox(height: 20),
          for (final step in steps)
            _StepCard(number: step.$1, title: step.$2, body: step.$3),
          const SizedBox(height: 8),
          SolidAction(
            label: _openingRoute ? 'Opening map…' : 'View route to evacuation center',
            loading: _openingRoute,
            onPressed: _openingRoute ? null : _openEvacuationRoute,
          ),
          const SizedBox(height: 12),
          OutlineAction(
            label: 'Call emergency hotline',
            icon: Icons.phone_outlined,
            onPressed: () => callHotline(context),
          ),
          const SizedBox(height: 16),
          const StatusBanner(
            tone: BannerTone.success,
            icon: Icons.wifi_off,
            message:
                'Saved information may be out of date while offline. Follow the latest official radio and barangay instructions.',
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _StepCard({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kLightGreen,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCFE5DA)),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kGreen,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: kTextGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
