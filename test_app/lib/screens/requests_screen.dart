import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'; // showComingSoon
import '../main.dart';
import 'akay_nav.dart';
import 'request_help_sheet.dart';
import 'screen_widgets.dart';
import 'track_response_screen.dart';

// ============================================================
// AKAY - Requests tab (Figma "Requests")
//
// Top card  = your active request ("Finding a verified responder")
// List      = past requests (resolved / cancelled)
//
// Backend used: AkayBackend.myRequests()  (live, newest first)
// ============================================================
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  String _historyTitle(String type) {
    switch (type) {
      case 'flood':
        return 'Flood assistance';
      case 'medical':
        return 'Medical assistance';
      case 'fire':
        return 'Fire assistance';
      default:
        return 'Emergency assistance';
    }
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return TabScaffold(
      index: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title + "New help request" pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: ScreenTitle(
                  label: 'ASSISTANCE HISTORY',
                  title: 'Requests',
                  subtitle: 'Track current help requests and review household history.',
                ),
              ),
              const SizedBox(width: 8),
              PillButton(
                label: 'New help request',
                icon: Icons.warning_amber_rounded,
                color: kRed,
                onPressed: () => showRequestHelpSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          StreamBuilder(
            stream: AkayBackend.myRequests(),
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
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final all = snapshot.data!;
              final active = all.where(
                (r) => r['status'] == 'pending' || r['status'] == 'matched',
              );
              final past = all
                  .where((r) => r['status'] == 'resolved' || r['status'] == 'cancelled')
                  .toList();
              final activeRequest = active.isEmpty ? null : active.first;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (activeRequest != null) ...[
                    _ActiveCard(
                      request: activeRequest,
                      onRefresh: () {
                        // The list is already live; this just confirms it to the user.
                        setState(() {});
                        showComingSoon(context, 'Status is up to date.');
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Text('PREVIOUS ACTIVITY', style: kSmallLabel),
                  const SizedBox(height: 6),
                  const Text(
                    'Request history',
                    style: TextStyle(fontSize: 22, color: kTextDark),
                  ),
                  const SizedBox(height: 12),

                  if (past.isEmpty && !(kShowSampleData && activeRequest == null))
                    const AppCard(
                      child: Text(
                        'No past requests yet.',
                        style: kGreyText,
                      ),
                    )
                  else if (past.isEmpty)
                    // Figma sample rows
                    const AppCard(
                      child: Column(
                        children: [
                          _HistoryRow(
                            title: 'Flood assistance',
                            subtitle: 'Resolved · Santos Household',
                            resolved: true,
                          ),
                          Divider(height: 28, color: kBorder),
                          _HistoryRow(
                            title: 'Medical assistance',
                            subtitle: 'Resolved · Santos Household',
                            resolved: true,
                          ),
                        ],
                      ),
                    )
                  else
                    AppCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < past.length; i++) ...[
                            if (i > 0) const Divider(height: 28, color: kBorder),
                            _HistoryRow(
                              title: _historyTitle((past[i]['type'] ?? '').toString()),
                              subtitle:
                                  '${_cap((past[i]['status'] ?? '').toString())} · ${(past[i]['household'] is Map ? past[i]['household']['name'] : null) ?? 'Household'}',
                              resolved: past[i]['status'] == 'resolved',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TrackResponseScreen(
                                    requestId: past[i]['id'].toString(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------- "Active now" card ----------
class _ActiveCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onRefresh;

  const _ActiveCard({required this.request, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final matched = request['status'] == 'matched';
    final type = (request['type'] ?? 'other').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrackResponseScreen(requestId: request['id'].toString()),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFCFE5DA)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: kGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.check, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVE NOW · ${requestTypeLabel(type).toUpperCase()}',
                        style: kSmallLabel,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        matched
                            ? 'A responder is on the way'
                            : 'Finding a verified responder',
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.2,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        matched
                            ? 'A verified responder accepted your request.'
                            : 'Your location and household needs were shared.',
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SoftButton(
                    label: 'Refresh status',
                    onPressed: onRefresh,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SoftButton(
                    label: 'Call 911',
                    icon: Icons.phone_outlined,
                    danger: true,
                    // TODO: open the phone dialer (needs the url_launcher package).
                    onPressed: () =>
                        showComingSoon(context, 'Calling 911 comes later.'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool danger;
  final VoidCallback onPressed;

  const _SoftButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger ? kRed : kGreen;
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: danger ? const Color(0xFFFDE9E5) : kLightGreen,
          foregroundColor: fg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- One row in "Request history" ----------
class _HistoryRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool resolved;
  final VoidCallback? onTap;

  const _HistoryRow({
    required this.title,
    required this.subtitle,
    required this.resolved,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBox(
          icon: resolved ? Icons.check : Icons.close,
          bg: resolved ? kLightGreen : const Color(0xFFF1F3F2),
          color: resolved ? kGreen : kTextGrey,
          size: 40,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, color: kTextDark)),
              const SizedBox(height: 4),
              Text(subtitle, style: kGreyText),
              const SizedBox(height: 10),
              InkWell(
                onTap: onTap ??
                    () => showComingSoon(context, 'Sample item. No details yet.'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'View details  >',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
