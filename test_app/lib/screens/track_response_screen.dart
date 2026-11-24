import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'; // showComingSoon
import '../main.dart';
import 'screen_widgets.dart';

typedef RequestMap = Map<String, dynamic>;

// ============================================================
// AKAY - Live response tracker (shared by Resident & Responder)
//
// Backend used:
//   AkayBackend.watchRequest(id)         live status (pending/matched/resolved/cancelled)
//   AkayBackend.watchRequestDetails(id)  household name, address & mobility needs
//   AkayBackend.resolveRequest(id)       mark household safe / resolved
//   AkayBackend.releaseRequest(id)       responder hands matched job back to queue
//   AkayBackend.cancelRequest(id)        resident cancels pending request
//   AkayBackend.reopenRequest(id)        reopen resolved/cancelled request
// ============================================================
class TrackResponseScreen extends StatefulWidget {
  final String requestId;
  const TrackResponseScreen({super.key, required this.requestId});

  @override
  State<TrackResponseScreen> createState() => _TrackResponseScreenState();
}

class _TrackResponseScreenState extends State<TrackResponseScreen> {
  bool _busy = false;

  Future<void> _run(
    Future<void> Function() action, {
    bool popOnSuccess = false,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (popOnSuccess) {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (!mounted) return;
      showComingSoon(context, AkayBackend.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _relativeTime(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final diff = DateTime.now().difference(timestamp.toDate());
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      return '${diff.inHours} hr ago';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return AkayScreen(
      child: StreamBuilder<DocumentSnapshot<RequestMap>>(
        stream: AkayBackend.watchRequest(widget.requestId),
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
              child: Center(child: CircularProgressIndicator(color: kGreen)),
            );
          }

          final r = snapshot.data!.data();
          if (r == null) {
            return const AppCard(
              child: Text('This request could not be found.', style: kGreyText),
            );
          }

          final status = (r['status'] ?? 'pending').toString();
          final type = (r['type'] ?? 'other').toString();
          final responderId = (r['responderId'] ?? '').toString();
          final isAssignedResponder =
              responderId.isNotEmpty && responderId == AkayBackend.uid;

          if (isAssignedResponder) {
            return StreamBuilder<DocumentSnapshot<RequestMap>>(
              stream: AkayBackend.watchRequestDetails(widget.requestId),
              builder: (context, detailSnap) {
                final detail = detailSnap.data?.data();
                return _buildResponderView(context, r, detail, status, type);
              },
            );
          }

          return _buildResidentView(context, r, status, type);
        },
      ),
    );
  }

  Widget _buildResponderView(
    BuildContext context,
    RequestMap r,
    RequestMap? detail,
    String status,
    String type,
  ) {
    final isMatched = status == 'matched';
    final isResolved = status == 'resolved';
    final isCancelled = status == 'cancelled';

    final household = (detail?['household'] is Map)
        ? detail!['household'] as Map
        : const {};
    final name = (household['name'] ?? 'Household').toString();
    final address =
        (detail?['address'] ?? r['barangay'] ?? 'Address not shared')
            .toString();
    final mobility = (household['mobilityNeed'] ?? '').toString().trim();
    final hasMobility = mobility.isNotEmpty && mobility.toLowerCase() != 'none';
    final notes = household['notes'];
    final description = (detail?['description'] ?? '').toString().trim();

    final needsParts = <String>[
      if (hasMobility) mobility,
      if (notes is List && notes.isNotEmpty)
        notes.map((e) => e.toString()).join(' · '),
      if (household['members'] != null) '${household['members']} people',
      if (description.isNotEmpty) description,
    ];

    final bannerTone = isResolved
        ? BannerTone.success
        : isCancelled
        ? BannerTone.warning
        : BannerTone.success;
    final bannerTitle = isResolved
        ? 'RESOLVED'
        : isCancelled
        ? 'CANCELLED'
        : 'ACTIVE RESPONSE · ${requestTypeLabel(type).toUpperCase()}';
    final bannerMessage = isResolved
        ? 'This household has been marked safe.'
        : isCancelled
        ? 'The resident cancelled this request.'
        : 'You are assigned to this household. Confirm arrival or resolve once safe.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusBanner(
          tone: bannerTone,
          icon: isResolved ? Icons.check_circle_outline : Icons.directions_run,
          title: bannerTitle,
          message: bannerMessage,
        ),
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
            const Icon(Icons.location_on_outlined, size: 16, color: kTextGrey),
            const SizedBox(width: 4),
            Expanded(child: Text(address, style: kGreyText)),
          ],
        ),
        const SizedBox(height: 16),

        // Household needs card
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
                      hasMobility ? mobility : 'Household details',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      needsParts.isEmpty
                          ? 'No special mobility notes'
                          : needsParts.join(' · '),
                      style: kGreyText,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Response timeline card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RESPONSE PROGRESS', style: kSmallLabel),
              const SizedBox(height: 12),
              _StepRow(
                done: true,
                title: 'Ping received',
                subtitle: _relativeTime(r['createdAt']),
              ),
              const SizedBox(height: 10),
              _StepRow(
                done: isMatched || isResolved,
                title: 'Accepted by you',
                subtitle: _relativeTime(r['matchedAt']),
              ),
              const SizedBox(height: 10),
              _StepRow(
                done: isResolved,
                title: 'Household safe / resolved',
                subtitle: _relativeTime(r['resolvedAt']),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (isMatched) ...[
          SolidAction(
            label: 'Mark as resolved',
            loading: _busy,
            onPressed: () =>
                _run(() => AkayBackend.resolveRequest(widget.requestId)),
          ),
          const SizedBox(height: 12),
          OutlineAction(
            label: 'Release request — return to queue',
            icon: Icons.undo,
            onPressed: _busy
                ? null
                : () => _run(
                    () => AkayBackend.releaseRequest(widget.requestId),
                    popOnSuccess: true,
                  ),
          ),
        ] else if (isResolved) ...[
          OutlineAction(
            label: 'Reopen request',
            onPressed: _busy
                ? null
                : () => _run(() => AkayBackend.reopenRequest(widget.requestId)),
          ),
        ],

        const SizedBox(height: 12),
        OutlineAction(
          label: 'Call emergency hotline',
          icon: Icons.phone_in_talk_outlined,
          onPressed: () => callHotline(context),
        ),
      ],
    );
  }

  Widget _buildResidentView(
    BuildContext context,
    RequestMap r,
    String status,
    String type,
  ) {
    final isMatched = status == 'matched';
    final isResolved = status == 'resolved';
    final isCancelled = status == 'cancelled';
    final responderName = (r['responderName'] ?? 'A responder').toString();

    final tone = isResolved
        ? BannerTone.success
        : isCancelled
        ? BannerTone.warning
        : isMatched
        ? BannerTone.success
        : BannerTone.warning;

    final title = isResolved
        ? 'HELP COMPLETED'
        : isCancelled
        ? 'REQUEST CANCELLED'
        : isMatched
        ? 'RESPONDER ON THE WAY'
        : 'WAITING FOR RESPONDER';

    final message = isResolved
        ? 'This help request has been marked resolved.'
        : isCancelled
        ? 'You cancelled this help request.'
        : isMatched
        ? '$responderName accepted your request and is heading to you.'
        : 'Your ping is visible to nearby verified responders.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusBanner(
          tone: tone,
          icon: isMatched || isResolved
              ? Icons.check_circle_outline
              : Icons.hourglass_top_rounded,
          title: title,
          message: message,
        ),
        const SizedBox(height: 16),
        Text(
          requestTypeLabel(type),
          style: const TextStyle(
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w500,
            color: kTextDark,
          ),
        ),
        if ((r['barangay'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(r['barangay'].toString(), style: kGreyText),
        ],
        const SizedBox(height: 16),

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('STATUS UPDATES', style: kSmallLabel),
              const SizedBox(height: 12),
              _StepRow(
                done: true,
                title: 'Request sent',
                subtitle: _relativeTime(r['createdAt']),
              ),
              const SizedBox(height: 10),
              _StepRow(
                done: isMatched || isResolved,
                title: isMatched || isResolved
                    ? '$responderName matched'
                    : 'Matching with a responder',
                subtitle: _relativeTime(r['matchedAt']),
              ),
              const SizedBox(height: 10),
              _StepRow(
                done: isResolved,
                title: 'Safe / resolved',
                subtitle: _relativeTime(r['resolvedAt']),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (!isResolved && !isCancelled) ...[
          SolidAction(
            label: 'Mark as resolved',
            loading: _busy,
            onPressed: () =>
                _run(() => AkayBackend.resolveRequest(widget.requestId)),
          ),
          const SizedBox(height: 12),
          OutlineAction(
            label: 'Cancel request',
            onPressed: _busy
                ? null
                : () => _run(() => AkayBackend.cancelRequest(widget.requestId)),
          ),
        ] else ...[
          OutlineAction(
            label: 'Reopen request',
            onPressed: _busy
                ? null
                : () => _run(() => AkayBackend.reopenRequest(widget.requestId)),
          ),
        ],

        TextLinkButton(
          label: 'Call 911 instead',
          onPressed: () => callHotline(context),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final bool done;
  final String title;
  final String subtitle;

  const _StepRow({
    required this.done,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 20,
          color: done ? kGreen : kTextGrey,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: done ? FontWeight.w700 : FontWeight.w500,
              color: done ? kTextDark : kTextGrey,
            ),
          ),
        ),
        if (subtitle.isNotEmpty) Text(subtitle, style: kGreyText),
      ],
    );
  }
}
