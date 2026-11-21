import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'; // showComingSoon
import '../main.dart';
import 'akay_nav.dart';
import 'emergency_info_screen.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Community tab (Figma "Community")
//
// Backend used:
//   AkayBackend.currentPosition()          "Find my location"
//   AkayBackend.communityStatus(lat, lng)  the 3 numbers under the map
//   AkayBackend.communityUpdates()         the "Active advisory" card
//
// TODO(backend): the map is a drawing for now. Pins should come from
// AkayBackend.mapMarkers(). Recommended route and Response team are sample text.
// ============================================================
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  Map<String, dynamic>? _status; // result of communityStatus()
  bool _locating = false;

  Future<void> _findMe() async {
    setState(() => _locating = true);
    try {
      final p = await AkayBackend.currentPosition();
      final s = await AkayBackend.communityStatus(p.latitude, p.longitude);
      if (mounted) setState(() => _status = s);
    } catch (e) {
      if (mounted) showComingSoon(context, AkayBackend.friendlyError(e));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // Number under the map. Uses sample numbers until the person taps "Find my location".
  String _stat(String key) {
    if (_status == null) return kShowSampleData ? _sample[key]! : '-';
    switch (key) {
      case 'online':
        return '${_status!['respondersOnline']}';
      case 'active':
        return '${_status!['activeRequests']}';
      default:
        final c = _status!['nearestCenter'];
        return c == null ? '-' : '${c['distanceKm']} km';
    }
  }

  static const _sample = {'online': '12', 'active': '3', 'center': '1.2 km'};

  @override
  Widget build(BuildContext context) {
    return TabScaffold(
      index: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: ScreenTitle(
                  label: 'LIVE BARANGAY OVERVIEW',
                  title: 'Community',
                  subtitle: 'Monitor local alerts, responders, and safe evacuation routes.',
                ),
              ),
              const SizedBox(width: 8),
              PillButton(
                label: 'Find my location',
                icon: Icons.location_on_outlined,
                loading: _locating,
                onPressed: _findMe,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ----- Live response map -----
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BARANGAY LUMBO', style: kSmallLabel),
                          SizedBox(height: 6),
                          Text(
                            'Live response map',
                            style: TextStyle(fontSize: 22, color: kTextDark),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: Color(0xFF4DA37F)),
                          SizedBox(width: 6),
                          Text(
                            'Updating live',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _FakeMap(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StatItem(value: _stat('online'), label: 'Responders online'),
                    StatItem(value: _stat('active'), label: 'Active requests'),
                    StatItem(value: _stat('center'), label: 'Nearest center'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ----- Active advisory (first community update, or the Figma sample) -----
          StreamBuilder(
            stream: AkayBackend.communityUpdates(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              String title = 'Flood alert — Level 2';
              String body = 'Residents near Pulangi River should prepare to evacuate.';
              if (docs.isNotEmpty) {
                final d = docs.first.data();
                title = (d['title'] ?? title).toString();
                body = (d['body'] ?? '').toString();
              } else if (!kShowSampleData) {
                return const SizedBox.shrink();
              }
              return _InfoCard(
                icon: Icons.warning_amber_rounded,
                iconBg: const Color(0xFFFFF3DC),
                iconColor: const Color(0xFFE0A030),
                label: 'ACTIVE ADVISORY',
                title: title,
                body: body,
                buttonLabel: 'View advisory',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EmergencyInfoScreen()),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          _InfoCard(
            icon: Icons.alt_route,
            iconBg: const Color(0xFFE8F1FB),
            iconColor: const Color(0xFF3B82C4),
            label: 'RECOMMENDED ROUTE',
            title: 'Lumbo Elementary School',
            body: 'Open and passable. Estimated walk: 14 minutes.',
            buttonLabel: 'View safe route',
            // TODO(backend): real evacuation route.
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmergencyInfoScreen()),
            ),
          ),
          const SizedBox(height: 14),

          _InfoCard(
            icon: Icons.people_outline,
            iconBg: kLightGreen,
            iconColor: kGreen,
            label: 'RESPONSE TEAM',
            title: '${_stat('online')} responders available',
            body: '8 barangay responders and 4 verified volunteers online.',
            buttonLabel: 'Refresh status',
            onPressed: _findMe,
          ),
        ],
      ),
    );
  }
}

// ---------- A card with an icon, text and a soft green button ----------
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _InfoCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBox(icon: icon, bg: iconBg, color: iconColor, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: kSmallLabel),
                    const SizedBox(height: 6),
                    Text(title, style: const TextStyle(fontSize: 16, color: kTextDark)),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(body, style: kGreyText),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: kLightGreen,
                foregroundColor: kGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                '$buttonLabel  >',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Drawn map (same look as Home) ----------
class _FakeMap extends StatelessWidget {
  const _FakeMap();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 240,
        width: double.infinity,
        color: const Color(0xFFE9EFEB),
        child: const Stack(
          children: [
            // river
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 48,
              child: ColoredBox(color: Color(0xFFC6DBE3)),
            ),
            Align(
              alignment: Alignment(-0.4, -0.7),
              child: Text('Purok 3', style: kGreyText),
            ),
            Align(
              alignment: Alignment(0.7, 0.3),
              child: Text('Purok 4', style: kGreyText),
            ),
            Align(
              alignment: Alignment(0.7, -0.75),
              child: Icon(Icons.location_on, color: Color(0xFF4DA37F)),
            ),
            Align(
              alignment: Alignment(-0.6, 0.45),
              child: Icon(Icons.location_on, color: kRed),
            ),
            Align(
              alignment: Alignment(0.55, 0.78),
              child: Icon(Icons.location_on, color: Color(0xFF4DA37F)),
            ),
            Align(
              alignment: Alignment(-0.2, 0.8),
              child: Text(
                'Evacuation center',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kGreen,
                ),
              ),
            ),
            Align(
              alignment: Alignment(-0.05, -0.05),
              child: Icon(Icons.home, size: 34, color: kGreen),
            ),
          ],
        ),
      ),
    );
  }
}
