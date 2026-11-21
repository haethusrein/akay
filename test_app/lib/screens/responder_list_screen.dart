import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'; // showComingSoon
import '../main.dart';
import 'checkin_screen.dart';
import 'respond_ping_screen.dart';
import 'screen_widgets.dart';
import 'track_response_screen.dart';

// ============================================================
// AKAY - Responder: "Households needing help" (wireframe 10)
//
// Backend used:
//   AkayBackend.setOnline(bool)        online switch (needs GPS)
//   AkayBackend.pendingRequests()      live list of households waiting
//   AkayBackend.myAcceptedRequests()   requests this responder accepted
//
// Priority is a simple rule for now: medical and fire = CRITICAL, others = HIGH.
// TODO(backend): real priority, needs and status filters, and the Map tab pins.
// ============================================================
class ResponderListScreen extends StatefulWidget {
  const ResponderListScreen({super.key});

  @override
  State<ResponderListScreen> createState() => _ResponderListScreenState();
}

class _ResponderListScreenState extends State<ResponderListScreen> {
  bool _online = false;
  bool _showMap = false;
  bool _criticalOnly = false;

  // Figma-style sample households, shown only while kShowSampleData is true
  // and no real requests exist. They have no 'id', so nothing is sent.
  static final _sample = <Map<String, dynamic>>[
    {
      'type': 'medical',
      'address': 'Purok 2',
      'minutes': 12,
      'household': {
        'name': 'Reyes Household',
        'members': 3,
        'mobilityNeed': 'Bedridden',
        'notes': ['Oxygen tank'],
      },
    },
    {
      'type': 'flood',
      'address': 'Purok 4',
      'minutes': 8,
      'household': {
        'name': 'Santos Household',
        'members': 4,
        'mobilityNeed': 'Wheelchair',
        'notes': ['2 seniors'],
      },
    },
  ];

  Future<void> _toggleOnline(bool value) async {
    try {
      await AkayBackend.setOnline(value);
      if (mounted) setState(() => _online = value);
    } catch (e) {
      if (mounted) showComingSoon(context, AkayBackend.friendlyError(e));
    }
  }

  bool _isCritical(Map<String, dynamic> r) =>
      r['type'] == 'medical' || r['type'] == 'fire';

  int _minutes(Map<String, dynamic> r) {
    if (r['minutes'] is int) return r['minutes'] as int;
    try {
      return DateTime.now().difference(r['createdAt'].toDate()).inMinutes;
    } catch (_) {
      return 0;
    }
  }

  String _details(Map<String, dynamic> r) {
    final h = (r['household'] is Map) ? r['household'] as Map : const {};
    final parts = <String>[];
    if ((r['address'] ?? '').toString().isNotEmpty) parts.add('${r['address']}');
    final mobility = (h['mobilityNeed'] ?? '').toString();
    if (mobility.isNotEmpty && mobility.toLowerCase() != 'none') parts.add(mobility);
    final notes = h['notes'];
    if (notes is List && notes.isNotEmpty) parts.add(notes.join(', '));
    if (h['members'] != null) parts.add('${h['members']} people');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return AkayScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatusBanner(
            tone: BannerTone.success,
            icon: Icons.wifi,
            title: 'LIVE LIST',
            message: 'Data may be outdated if your connection drops. Confirm by radio when possible.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Households needing help',
            style: TextStyle(fontSize: 26, height: 1.15, color: kTextDark),
          ),
          const SizedBox(height: 12),

          // online switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _online ? 'You are online to responders' : 'You are offline',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: kTextDark),
                  ),
                ),
                Switch(value: _online, onChanged: _toggleOnline),
              ],
            ),
          ),
          const SizedBox(height: 14),

          StreamBuilder(
            stream: AkayBackend.pendingRequests(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return StatusBanner(
                  tone: BannerTone.danger,
                  icon: Icons.error_outline,
                  message: AkayBackend.friendlyError(snapshot.error!),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              var items = List<Map<String, dynamic>>.from(snapshot.data!);
              final usingSample = items.isEmpty && kShowSampleData;
              if (usingSample) items = List.of(_sample);
              if (_criticalOnly) items = items.where(_isCritical).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // List / Map switch
                  Row(
                    children: [
                      Expanded(
                        child: _Seg(
                          label: 'List · ${items.length}',
                          selected: !_showMap,
                          onTap: () => setState(() => _showMap = false),
                        ),
                      ),
                      Expanded(
                        child: _Seg(
                          label: 'Map',
                          selected: _showMap,
                          onTap: () => setState(() => _showMap = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilterChip(
                    label: const Text('Critical only'),
                    selected: _criticalOnly,
                    onSelected: (v) => setState(() => _criticalOnly = v),
                  ),
                  const SizedBox(height: 10),

                  if (_showMap)
                    // TODO(backend): put real pins from the requests' locations.
                    const MiniMap()
                  else if (items.isEmpty)
                    const AppCard(
                      child: Text('No households need help right now.', style: kGreyText),
                    )
                  else
                    for (final r in items) _card(context, r),

                  if (usingSample)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Sample data. Nothing real is shown yet.', style: kGreyText),
                    ),
                ],
              );
            },
          ),

          // Requests this responder already accepted
          StreamBuilder(
            stream: AkayBackend.myAcceptedRequests(),
            builder: (context, snapshot) {
              final mine = snapshot.data ?? const <Map<String, dynamic>>[];
              if (mine.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ACCEPTED BY YOU', style: kSmallLabel),
                    const SizedBox(height: 8),
                    for (final r in mine)
                      ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: kBorder),
                        ),
                        title: Text(
                          (r['household'] is Map ? r['household']['name'] : null)
                                  ?.toString() ??
                              'Household',
                        ),
                        subtitle: Text(
                          '${requestTypeLabel((r['type'] ?? 'other').toString())} · ${r['status']}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                TrackResponseScreen(requestId: r['id'].toString()),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 20),
          OutlineAction(
            label: 'Evacuation-center check-in',
            icon: Icons.fact_check_outlined,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CheckInScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> r) {
    final critical = _isCritical(r);
    final color = critical ? kRed : kAmberDot;
    final name = (r['household'] is Map ? r['household']['name'] : null)?.toString() ??
        'Household';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: color, width: 4),
            top: const BorderSide(color: kBorder),
            right: const BorderSide(color: kBorder),
            bottom: const BorderSide(color: kBorder),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${critical ? 'CRITICAL' : 'HIGH'} · ${_minutes(r)} MIN',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(_details(r), style: kGreyText),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RespondPingScreen(request: r)),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: kGreen,
                backgroundColor: kLightGreen,
                side: const BorderSide(color: Color(0xFFCFE5DA)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Open request', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Seg({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kGreen : Colors.white,
          border: Border.all(color: kGreen),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : kGreen,
          ),
        ),
      ),
    );
  }
}
