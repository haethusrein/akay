import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'; // showComingSoon
import '../main.dart';
import 'screen_widgets.dart';
import 'track_response_screen.dart';

typedef RequestMap = Map<String, dynamic>;

// ============================================================
// AKAY - Responder: respond to a ping (wireframe 11)
//
// Opened from the responder list with one request (a Map from
// AkayBackend.pendingRequests()).
//
// Backend used:
//   AkayBackend.watchRequest(id)         live request status & timestamps
//   AkayBackend.watchRequestDetails(id)  exact address, GPS & household needs
//   AkayBackend.acceptRequest(id)        claim active response job
//   AkayBackend.declineRequest(id)       hide request for this responder
//   AkayBackend.reportRequest(id)        flag suspicious ping for admins
// ============================================================
class RespondPingScreen extends StatefulWidget {
  final RequestMap request;
  const RespondPingScreen({super.key, required this.request});

  @override
  State<RespondPingScreen> createState() => _RespondPingScreenState();
}

class _RespondPingScreenState extends State<RespondPingScreen> {
  int _selectedModeIndex = 0;
  bool _busy = false;
  double? _myLat;
  double? _myLng;

  @override
  void initState() {
    super.initState();
    _loadResponderPosition();
  }

  Future<void> _loadResponderPosition() async {
    try {
      final pos = await AkayBackend.currentPosition();
      if (!mounted) return;
      setState(() {
        _myLat = pos.latitude;
        _myLng = pos.longitude;
      });
    } catch (_) {
      // GPS unavailable or denied; screen falls back to default ETA labels.
    }
  }

  (double, double)? _coordsFor(RequestMap r) {
    final loc = r['location'];
    if (loc is GeoPoint) {
      return (loc.latitude, loc.longitude);
    }
    if (r['lat'] is num && r['lng'] is num) {
      return ((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble());
    }
    return null;
  }

  double? _distanceKm(RequestMap r) {
    final target = _coordsFor(r);
    if (target == null || _myLat == null || _myLng == null) return null;
    final meters = Geolocator.distanceBetween(
      _myLat!,
      _myLng!,
      target.$1,
      target.$2,
    );
    return meters / 1000.0;
  }

  List<String> _travelOptions(double? km) {
    if (km == null) {
      return const [
        'Motorcycle · 8 min',
        'On foot · 25 min',
        'Vehicle · 10 min',
      ];
    }
    final motoMin = ((km / 30.0) * 60).round().clamp(1, 240);
    final footMin = ((km / 4.5) * 60).round().clamp(1, 480);
    final carMin = ((km / 25.0) * 60).round().clamp(1, 240);
    return [
      'Motorcycle · $motoMin min',
      'On foot · $footMin min',
      'Vehicle · $carMin min',
    ];
  }

  String _ageLabel(RequestMap r) {
    if (r['minutes'] is int) {
      final m = r['minutes'] as int;
      return m <= 0 ? 'JUST NOW' : '$m MIN AGO';
    }
    final created = r['createdAt'];
    if (created is Timestamp) {
      final diff = DateTime.now().difference(created.toDate());
      if (diff.inMinutes < 1) return 'JUST NOW';
      if (diff.inMinutes < 60) return '${diff.inMinutes} MIN AGO';
      return '${diff.inHours} HR AGO';
    }
    return 'JUST NOW';
  }

  String _fullAddress(RequestMap r) {
    final address = (r['address'] ?? '').toString().trim();
    final barangay = (r['barangay'] ?? '').toString().trim();
    if (address.isNotEmpty && barangay.isNotEmpty) {
      if (address.toLowerCase().contains(barangay.toLowerCase())) {
        return address;
      }
      return '$address, $barangay';
    }
    if (address.isNotEmpty) return address;
    if (barangay.isNotEmpty) return barangay;
    return 'Address not shared';
  }

  Future<void> _accept() async {
    final id = widget.request['id']?.toString();
    if (id == null || id.isEmpty) {
      showComingSoon(context, 'This is sample data. Nothing was accepted.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AkayBackend.acceptRequest(id);
      if (!mounted) return;
      showComingSoon(context, 'You accepted this request. Stay safe.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TrackResponseScreen(requestId: id)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showComingSoon(context, AkayBackend.friendlyError(e));
    }
  }

  Future<void> _decline() async {
    final id = widget.request['id']?.toString();
    if (id != null && id.isNotEmpty) {
      try {
        await AkayBackend.declineRequest(id)
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // Hiding is best-effort; still close the screen.
      }
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _report() async {
    final id = widget.request['id']?.toString();
    if (id == null || id.isEmpty) {
      showComingSoon(context, 'This is sample data. Nothing was reported.');
      return;
    }

    const reasons = [
      'Suspicious or prank ping',
      'Duplicate request for same household',
      'Invalid or unreachable location',
    ];

    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Report suspicious ping',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            for (final reason in reasons)
              ListTile(
                title: Text(reason),
                onTap: () => Navigator.pop(ctx, reason),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await AkayBackend.reportRequest(
        id,
        reason: picked,
      ).timeout(const Duration(seconds: 4));
      if (!mounted) return;
      showComingSoon(context, 'Thanks. Admins will review this ping.');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showComingSoon(context, AkayBackend.friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.request['id']?.toString();
    if (id == null || id.isEmpty) {
      return _buildContent(context, widget.request);
    }

    return StreamBuilder(
      stream: AkayBackend.watchRequest(id),
      builder: (context, reqSnap) {
        final liveReq = reqSnap.data?.data();
        return StreamBuilder(
          stream: AkayBackend.watchRequestDetails(id),
          builder: (context, detailSnap) {
            final detail = detailSnap.data?.data();
            final merged = RequestMap.from(widget.request);
            if (liveReq != null) {
              merged.addAll(liveReq);
            }
            if (detail != null) {
              merged['address'] = detail['address'] ?? merged['address'];
              merged['description'] =
                  detail['description'] ?? merged['description'];
              merged['household'] = detail['household'] ?? merged['household'];
              if (detail['location'] != null) {
                merged['location'] = detail['location'];
              }
            }
            return _buildContent(context, merged);
          },
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, RequestMap r) {
    final type = (r['type'] ?? 'other').toString();
    final status = (r['status'] ?? 'pending').toString();
    final isUnavailable = status != 'pending' && status != 'local';
    final critical = type == 'medical' || type == 'fire';

    final household = (r['household'] is Map)
        ? r['household'] as Map
        : const {};
    final name = (household['name'] ?? 'Household').toString();
    final mobility = (household['mobilityNeed'] ?? '').toString().trim();
    final hasMobility = mobility.isNotEmpty && mobility.toLowerCase() != 'none';
    final notes = household['notes'];
    final description = (r['description'] ?? '').toString().trim();

    final primaryNeedTitle = hasMobility
        ? mobility
        : 'General evacuation assistance';
    final secondaryParts = <String>[
      if (notes is List && notes.isNotEmpty)
        notes.map((e) => e.toString()).join(' · '),
      if (household['members'] != null) '${household['members']} people',
      if (description.isNotEmpty) description,
    ];

    final km = _distanceKm(r);
    final travelOptions = _travelOptions(km);
    final safeModeIndex = _selectedModeIndex
        .clamp(0, travelOptions.length - 1)
        .toInt();

    return AkayScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusBanner(
            tone: critical ? BannerTone.danger : BannerTone.warning,
            icon: Icons.warning_amber_rounded,
            title:
                '${critical ? 'CRITICAL' : 'HIGH'} · ${requestTypeLabel(type).toUpperCase()} · ${_ageLabel(r)}',
            message: 'A household is asking for help.',
          ),
          if (isUnavailable) ...[
            const SizedBox(height: 12),
            StatusBanner(
              tone: BannerTone.warning,
              icon: Icons.info_outline,
              message:
                  'This request is currently "$status" and may already have a responder.',
            ),
          ],
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w500,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: kTextGrey,
              ),
              const SizedBox(width: 4),
              Expanded(child: Text(_fullAddress(r), style: kGreyText)),
            ],
          ),
          const SizedBox(height: 16),

          _PingLocationPreview(
            coords: _coordsFor(r),
            myLat: _myLat,
            myLng: _myLng,
            distanceKm: km,
          ),
          const SizedBox(height: 14),

          // Special assistance requirements card (Wireframe 11)
          Container(
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
                IconBox(
                  icon: hasMobility ? Icons.accessible : Icons.people_outline,
                  bg: hasMobility ? const Color(0xFFFFF3DC) : kLightGreen,
                  color: hasMobility ? kAmberDot : kGreen,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primaryNeedTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        secondaryParts.isEmpty
                            ? 'No additional household notes'
                            : secondaryParts.join(' · '),
                        style: kGreyText,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text('Travel mode', style: kGreyText),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: safeModeIndex,
                isExpanded: true,
                items: [
                  for (int i = 0; i < travelOptions.length; i++)
                    DropdownMenuItem<int>(
                      value: i,
                      child: Text(travelOptions[i]),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedModeIndex = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          SolidAction(
            label: 'Confirm and respond',
            loading: _busy,
            onPressed: isUnavailable ? null : _accept,
          ),
          const SizedBox(height: 12),
          OutlineAction(
            label: 'Decline — show next responder',
            onPressed: _busy ? null : _decline,
          ),
          TextLinkButton(
            label: 'Report suspicious ping',
            onPressed: _busy ? null : _report,
          ),
        ],
      ),
    );
  }
}

class _PingLocationPreview extends StatelessWidget {
  final (double, double)? coords;
  final double? myLat;
  final double? myLng;
  final double? distanceKm;

  const _PingLocationPreview({
    required this.coords,
    required this.myLat,
    required this.myLng,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    double pinX = 0.45;
    double pinY = -0.35;

    if (coords != null && myLat != null && myLng != null) {
      final dx = (coords!.$2 - myLng!) * 160;
      final dy = -(coords!.$1 - myLat!) * 160;
      if (dx.abs() >= 0.08 || dy.abs() >= 0.08) {
        pinX = dx.clamp(-0.75, 0.75).toDouble();
        pinY = dy.clamp(-0.70, 0.70).toDouble();
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 170,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFE9EFEB),
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 36,
              child: ColoredBox(color: Color(0xFFC6DBE3)),
            ),
            Align(
              alignment: const Alignment(-0.30, 0.35),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: kTextDark, width: 1.5),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Align(
              alignment: Alignment(pinX, pinY),
              child: const CircleAvatar(
                radius: 14,
                backgroundColor: kRed,
                child: Text(
                  '!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (distanceKm != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorder),
                  ),
                  child: Text(
                    '~${distanceKm!.toStringAsFixed(1)} km away',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kTextDark,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
