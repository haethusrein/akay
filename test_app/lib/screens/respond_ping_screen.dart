import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'; // showComingSoon
import '../main.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Responder: respond to a ping (wireframe 11)
//
// Opened from the responder list with one request (a Map from
// AkayBackend.pendingRequests()).
//
// Backend used: AkayBackend.acceptRequest(id)
// TODO(backend): "Decline" and "Report suspicious ping" have no backend
// methods yet. They only close the screen / show a message.
// ============================================================
class RespondPingScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  const RespondPingScreen({super.key, required this.request});

  @override
  State<RespondPingScreen> createState() => _RespondPingScreenState();
}

const _travelModes = [
  'Motorcycle · 8 min',
  'On foot · 25 min',
  'Vehicle · 10 min',
];

class _RespondPingScreenState extends State<RespondPingScreen> {
  String _travel = _travelModes.first;
  bool _busy = false;

  Map get _household =>
      widget.request['household'] is Map ? widget.request['household'] as Map : {};

  Future<void> _accept() async {
    final id = widget.request['id'];
    if (id == null) {
      // sample request from the list: nothing real to accept
      showComingSoon(context, 'This is sample data. Nothing was accepted.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AkayBackend.acceptRequest(id.toString());
      if (!mounted) return;
      showComingSoon(context, 'You accepted this request. Stay safe.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showComingSoon(context, AkayBackend.friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final type = (r['type'] ?? 'other').toString();
    final critical = type == 'medical' || type == 'fire';
    final name = (_household['name'] ?? 'Household').toString();
    final mobility = (_household['mobilityNeed'] ?? '').toString();
    final notes = _household['notes'];
    final needs = <String>[
      if (mobility.isNotEmpty && mobility.toLowerCase() != 'none') '$mobility required',
      if (notes is List && notes.isNotEmpty) notes.join(', '),
      if (_household['members'] != null) '${_household['members']} people',
    ];

    return AkayScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusBanner(
            tone: critical ? BannerTone.danger : BannerTone.warning,
            icon: Icons.warning_amber_rounded,
            title: '${critical ? 'CRITICAL' : 'HIGH'} · ${requestTypeLabel(type).toUpperCase()}',
            message: 'A household is asking for help.',
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 28, height: 1.15, color: kTextDark),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: kTextGrey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  (r['address'] ?? 'Address not shared').toString(),
                  style: kGreyText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // TODO(backend): real map using request['location'] and the responder's GPS.
          const MiniMap(),
          const SizedBox(height: 14),

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
                const IconBox(
                  icon: Icons.accessible,
                  bg: Color(0xFFFFF3DC),
                  color: Color(0xFFE0A030),
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Household needs',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        needs.isEmpty ? 'No special needs listed' : needs.join(' · '),
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
              child: DropdownButton<String>(
                value: _travel,
                isExpanded: true,
                items: [
                  for (final t in _travelModes)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _travel = v ?? _travel),
              ),
            ),
          ),
          const SizedBox(height: 20),

          SolidAction(
            label: 'Confirm and respond',
            loading: _busy,
            onPressed: _accept,
          ),
          const SizedBox(height: 12),
          OutlineAction(
            label: 'Decline — show next responder',
            // TODO(backend): tell the server this responder declined.
            onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
          ),
          TextLinkButton(
            label: 'Report suspicious ping',
            // TODO(backend): send a report for admins to review.
            onPressed: () =>
                showComingSoon(context, 'Reporting is coming soon.'),
          ),
        ],
      ),
    );
  }
}
