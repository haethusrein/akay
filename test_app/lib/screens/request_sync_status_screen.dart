import 'package:flutter/material.dart';

import '../create_account_screens.dart'; // showComingSoon
import '../main.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Request & sync status (wireframe 06)
//
// Shown when a request could NOT reach the server (no internet).
// Important rule from the design doc: "saved" is NOT "received".
// Only "Receipt confirmed" means responders actually got it.
//
// UI only for now. TODO(backend) marks where the real sync state plugs in.
// ============================================================

// The four words the whole app must use for request delivery.
enum SyncState { locallySaved, waitingToSync, sharedNearby, receiptConfirmed }

class RequestSyncStatusScreen extends StatefulWidget {
  final String type; // 'flood' | 'medical' | 'fire' | 'other'
  final SyncState state;

  const RequestSyncStatusScreen({
    super.key,
    this.type = 'flood',
    this.state = SyncState.waitingToSync, // TODO(backend): pass the real state
  });

  @override
  State<RequestSyncStatusScreen> createState() =>
      _RequestSyncStatusScreenState();
}

class _RequestSyncStatusScreenState extends State<RequestSyncStatusScreen> {
  late final TimeOfDay _savedAt = TimeOfDay.now();
  TimeOfDay? _lastRetry;
  late SyncState _state = widget.state;

  void _retry() {
    // TODO(backend): try to send the saved request again.
    setState(() => _lastRetry = TimeOfDay.now());
    showComingSoon(context, 'Still no connection. AKAY will keep trying.');
  }

  // Step states for the 3-step list (Shared Nearby shows as a note, see below).
  StepStatus _stepFor(int step) {
    // step 1 = Saved on this device, 2 = Waiting to sync, 3 = Receipt confirmed
    final reached = switch (_state) {
      SyncState.locallySaved => 1,
      SyncState.waitingToSync => 2,
      SyncState.sharedNearby => 2,
      SyncState.receiptConfirmed => 3,
    };
    if (step < reached) return StepStatus.done;
    if (step == reached) {
      return _state == SyncState.receiptConfirmed ? StepStatus.done : StepStatus.current;
    }
    return StepStatus.waiting;
  }

  @override
  Widget build(BuildContext context) {
    final time = _savedAt.format(context);
    final retryText = _lastRetry == null
        ? 'No retry yet · No duplicate request created'
        : 'Last retry: ${_lastRetry!.format(context)} · No duplicate request created';

    return AkayScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatusBanner(
            tone: BannerTone.warning,
            icon: Icons.wifi_off,
            title: 'NO NETWORK CONNECTION',
            message: 'Responders have NOT received your request yet.',
          ),
          const SizedBox(height: 20),
          Text(
            'Request saved on\nthis device',
            style: const TextStyle(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w500,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${requestTypeLabel(widget.type)} · saved at $time',
            style: kGreyText,
          ),
          const SizedBox(height: 24),

          StepRow(
            number: 1,
            title: 'Saved on this device',
            caption: 'Your request will not be lost if you close AKAY.',
            state: _stepFor(1),
          ),
          StepRow(
            number: 2,
            title: 'Waiting to sync',
            caption: 'AKAY will retry when a connection returns.',
            state: _stepFor(2),
          ),
          StepRow(
            number: 3,
            title: 'Receipt confirmed',
            caption: 'Not yet received by a responder.',
            state: _stepFor(3),
            isLast: true,
          ),

          if (_state == SyncState.sharedNearby) ...[
            const SizedBox(height: 16),
            const StatusBanner(
              tone: BannerTone.success,
              icon: Icons.bluetooth,
              title: 'Shared Nearby',
              message:
                  'Sent to nearby AKAY phones. Not yet confirmed by responders.',
            ),
          ],

          const SizedBox(height: 20),
          const StatusBanner(
            tone: BannerTone.warning,
            icon: Icons.warning_amber_rounded,
            message:
                'This request is not confirmed. If danger is immediate, call 911, use the radio, or contact your purok leader.',
          ),
          const SizedBox(height: 20),
          SolidAction(label: 'Retry sync now', onPressed: _retry),
          const SizedBox(height: 12),
          OutlineAction(
            label: 'Send to nearby phones (Bluetooth)',
            icon: Icons.bluetooth,
            // TODO: open the Nearby SOS screens (Bluetooth wireframes 05-08) when built.
            // TODO(backend): Bluetooth relay. For a quick demo you can set
            // _state = SyncState.sharedNearby here instead.
            onPressed: () =>
                showComingSoon(context, 'Nearby SOS (Bluetooth) is coming soon.'),
          ),
          const SizedBox(height: 12),
          OutlineAction(
            label: 'Call emergency hotline',
            icon: Icons.phone_outlined,
            // TODO: open the phone dialer (needs the url_launcher package).
            onPressed: () =>
                showComingSoon(context, 'Calling the hotline comes later.'),
          ),
          const SizedBox(height: 12),
          Center(child: Text(retryText, style: kGreyText, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
