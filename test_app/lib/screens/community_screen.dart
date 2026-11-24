import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'; // showComingSoon
import '../main.dart';
import '../map/community_map.dart';
import 'akay_nav.dart';
import 'emergency_info_screen.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Community tab (Figma "Community")
//
// Backend used:
//   AkayBackend.currentPosition()          GPS position
//   AkayBackend.communityStatus(lat, lng)  the 3 numbers, nearest center, responders
//   AkayBackend.communityUpdates()         the "Active advisory" card
//   AkayBackend.myHousehold()              the area label above the map
//
// Nothing on this screen is sample data. A number or card appears only when
// the backend returned it; otherwise the screen shows "-" or hides the card.
//
// The map is a real OpenStreetMap map of Valencia City (see lib/map/).
// Its settings are in lib/map/map_config.dart.
// ============================================================
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  Map<String, dynamic>? _status; // result of communityStatus()
  DateTime? _updatedAt;
  bool _locating = true; // the first load starts as soon as the tab opens

  @override
  void initState() {
    super.initState();
    _fetch(quiet: true);
  }

  // quiet = true on the automatic first load, so a denied permission does not
  // pop an error before the person has touched anything.
  Future<void> _fetch({required bool quiet}) async {
    try {
      final p = await AkayBackend.currentPosition();
      final s = await AkayBackend.communityStatus(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() {
        _status = s;
        _updatedAt = DateTime.now();
      });
    } catch (e) {
      if (mounted && !quiet) {
        showComingSoon(context, AkayBackend.friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _refresh() {
    setState(() => _locating = true);
    _fetch(quiet: false);
  }

  // Number under the map. "-" until the backend has answered.
  String _stat(String key) {
    final s = _status;
    if (s == null) return '-';
    switch (key) {
      case 'online':
        return '${s['respondersOnline']}';
      case 'active':
        return '${s['activeRequests']}';
      default:
        final c = s['nearestCenter'];
        return c == null ? '-' : '${c['distanceKm']} km';
    }
  }

  String get _updatedLabel {
    final t = _updatedAt;
    if (t != null) return 'Updated ${TimeOfDay.fromDateTime(t).format(context)}';
    return _locating ? 'Updating...' : 'Not updated';
  }

  void _openInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmergencyInfoScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _status?['nearestCenter'];
    final online = _status?['respondersOnline'];

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
                  label: 'LIVE COMMUNITY OVERVIEW',
                  title: 'Community',
                  subtitle: 'Monitor local alerts, responders, and evacuation centers.',
                ),
              ),
              const SizedBox(width: 8),
              PillButton(
                label: 'Find my location',
                icon: Icons.location_on_outlined,
                loading: _locating,
                onPressed: _refresh,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ----- Response map -----
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Area label: the household's barangay when there is one.
                          StreamBuilder(
                            stream: AkayBackend.myHousehold(),
                            builder: (context, snapshot) {
                              final b = snapshot.data?.data()?['barangay'];
                              return Text(
                                b is String ? b.toUpperCase() : 'AROUND YOU',
                                style: kSmallLabel,
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Response map',
                            style: TextStyle(fontSize: 22, color: kTextDark),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: _updatedAt == null
                                ? kTextGrey
                                : const Color(0xFF4DA37F),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _updatedLabel,
                            style: const TextStyle(
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
                const CommunityMap(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem(value: _stat('online'), label: 'Responders online'),
                    _StatItem(value: _stat('active'), label: 'Active requests'),
                    _StatItem(value: _stat('center'), label: 'Nearest center'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ----- Active advisory: the newest community update, hidden when there is none -----
          StreamBuilder(
            stream: AkayBackend.communityUpdates(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const SizedBox.shrink();
              final d = docs.first.data();
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _InfoCard(
                  icon: Icons.warning_amber_rounded,
                  iconBg: const Color(0xFFFFF3DC),
                  iconColor: const Color(0xFFE0A030),
                  label: 'ACTIVE ADVISORY',
                  title: (d['title'] ?? 'Community update').toString(),
                  body: (d['body'] ?? '').toString(),
                  buttonLabel: 'View advisory',
                  onPressed: _openInfo,
                ),
              );
            },
          ),

          // ----- Nearest evacuation center: only when the backend found one -----
          if (center != null) ...[
            _InfoCard(
              icon: Icons.alt_route,
              iconBg: const Color(0xFFE8F1FB),
              iconColor: const Color(0xFF3B82C4),
              label: 'NEAREST EVACUATION CENTER',
              title: '${center['name'] ?? 'Evacuation center'}',
              body: 'About ${center['distanceKm']} km from you.',
              buttonLabel: 'View evacuation info',
              onPressed: _openInfo,
            ),
            const SizedBox(height: 14),
          ],

          // ----- Response team: real count, no invented breakdown -----
          _InfoCard(
            icon: Icons.people_outline,
            iconBg: kLightGreen,
            iconColor: kGreen,
            label: 'RESPONSE TEAM',
            title: online == null
                ? 'Checking responders...'
                : (online == 1 ? '1 responder online' : '$online responders online'),
            body:
                'Verified responders who shared their location within '
                '${AkayBackend.nearbyKm.toStringAsFixed(0)} km in the last 30 minutes.',
            buttonLabel: 'Refresh status',
            onPressed: _refresh,
          ),
        ],
      ),
    );
  }
}

// ---------- One number with a small label under it ----------
class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: kTextDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: kGreyText),
      ],
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
