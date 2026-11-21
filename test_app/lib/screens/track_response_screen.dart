import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'; // showComingSoon
import '../main.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Track response (wireframe 07)
//
// Live status of one help request: pending -> matched -> resolved.
//
// Backend used:
//   AkayBackend.watchRequest(id)    live request document
//   AkayBackend.cancelRequest(id)
//   AkayBackend.resolveRequest(id)
// ============================================================
class TrackResponseScreen extends StatefulWidget {
  final String requestId;
  const TrackResponseScreen({super.key, required this.requestId});

  @override
  State<TrackResponseScreen> createState() => _TrackResponseScreenState();
}

class _TrackResponseScreenState extends State<TrackResponseScreen> {
  bool _busy = false;

  Future<void> _cancel() async {
    final sure = await confirmDialog(
      context,
      title: 'Cancel this request?',
      message: 'Responders will be told you no longer need help.',
      confirmLabel: 'Cancel request',
      cancelLabel: 'Keep request',
    );
    if (!sure || !mounted) return;
    await _run(() => AkayBackend.cancelRequest(widget.requestId));
  }

  Future<void> _resolve() async {
    final sure = await confirmDialog(
      context,
      title: 'Mark as resolved?',
      message: 'Only do this if help has arrived and you are safe.',
      confirmLabel: 'Yes, resolved',
      cancelLabel: 'Not yet',
    );
    if (!sure || !mounted) return;
    await _run(() => AkayBackend.resolveRequest(widget.requestId));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showComingSoon(context, AkayBackend.friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AkayScreen(
      child: StreamBuilder(
        stream: AkayBackend.watchRequest(widget.requestId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StatusBanner(
              tone: BannerTone.danger,
              icon: Icons.error_outline,
              message: AkayBackend.friendlyError(snapshot.error!),
            );
          }
          final r = snapshot.data?.data();
          if (r == null) {
            return const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final status = (r['status'] ?? 'pending').toString();
          final type = (r['type'] ?? 'other').toString();
          final responder = r['responderMobile']?.toString();
          final matched = status == 'matched' || status == 'resolved';
          final resolved = status == 'resolved';
          final cancelled = status == 'cancelled';

          final title = cancelled
              ? 'Request cancelled'
              : resolved
                  ? 'You are safe'
                  : matched
                      ? 'Help is on the way'
                      : 'Finding a responder';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!cancelled)
                StatusBanner(
                  tone: BannerTone.success,
                  icon: Icons.check_circle_outline,
                  title: 'Request sent',
                  message: matched
                      ? 'A verified responder accepted your request.'
                      : 'Nearby verified responders were notified.',
                ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Request #${widget.requestId.substring(0, widget.requestId.length < 6 ? widget.requestId.length : 6).toUpperCase()} · ${requestTypeLabel(type)}',
                style: kGreyText,
              ),
              const SizedBox(height: 24),

              if (cancelled)
                const StatusBanner(
                  tone: BannerTone.warning,
                  icon: Icons.info_outline,
                  message:
                      'This request was cancelled. If you still need help, send a new request.',
                )
              else ...[
                const StepRow(
                  number: 1,
                  title: 'Request received',
                  state: StepStatus.done,
                ),
                StepRow(
                  number: 2,
                  title: 'Responder assigned',
                  caption: matched
                      ? (responder == null ? 'A responder is coming' : 'Contact: $responder')
                      : 'Waiting for a responder to accept',
                  state: matched
                      ? StepStatus.done
                      : StepStatus.current,
                ),
                StepRow(
                  number: 3,
                  title: 'Help arrives',
                  caption: resolved ? 'Marked resolved' : 'Waiting',
                  state: resolved
                      ? StepStatus.done
                      : (matched ? StepStatus.current : StepStatus.waiting),
                  isLast: true,
                ),
              ],

              const SizedBox(height: 28),
              if (!cancelled && !resolved) ...[
                if (matched) ...[
                  SolidAction(
                    label: 'View responder on map',
                    // TODO: open the map with the responder's position.
                    onPressed: () =>
                        showComingSoon(context, 'Responder map is coming soon.'),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlineAction(
                  label: 'Call 911 instead',
                  icon: Icons.phone_outlined,
                  // TODO: open the phone dialer (needs the url_launcher package).
                  onPressed: () =>
                      showComingSoon(context, 'Calling 911 comes later.'),
                ),
                if (matched) ...[
                  const SizedBox(height: 12),
                  OutlineAction(
                    label: 'Mark as resolved',
                    icon: Icons.check,
                    onPressed: _busy ? null : _resolve,
                  ),
                ],
                TextLinkButton(
                  label: 'Cancel request',
                  onPressed: _busy ? null : _cancel,
                ),
              ] else
                SolidAction(
                  label: 'Back to home',
                  onPressed: () => Navigator.of(context)
                      .popUntil((route) => route.isFirst),
                ),
            ],
          );
        },
      ),
    );
  }
}
