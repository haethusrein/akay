import 'package:flutter/material.dart';

import 'akay_backend.dart';
import 'main.dart';

class RequestStatusScreen extends StatelessWidget {
  final String requestId;

  const RequestStatusScreen({super.key, required this.requestId});

  String _label(String value) {
    if (value.isEmpty) return 'Unknown';
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        foregroundColor: kTextDark,
        elevation: 0,
        title: const Text('Request status'),
      ),
      body: StreamBuilder(
        stream: AkayBackend.watchRequest(requestId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(AkayBackend.friendlyError(snapshot.error!)),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();

          if (data == null) {
            return const Center(child: Text('Request not found.'));
          }

          final status = '${data['status'] ?? 'unknown'}';
          final type = '${data['type'] ?? 'other'}';
          final responderMobile = data['responderMobile'];

          final active = status == 'pending' || status == 'matched';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current status', style: kGreyText),
                    const SizedBox(height: 8),
                    Text(
                      _label(status),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status == 'pending'
                          ? 'Your request is waiting for a responder.'
                          : status == 'matched'
                          ? 'A responder has accepted your request.'
                          : status == 'resolved'
                          ? 'This request has been resolved.'
                          : status == 'cancelled'
                          ? 'This request was cancelled.'
                          : 'Check your request details below.',
                      style: kGreyText,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder(
                stream: AkayBackend.watchRequestDetails(requestId),
                builder: (context, detailsSnapshot) {
                  final details = detailsSnapshot.data?.data();
                  final address =
                      '${details?['address'] ?? 'No address provided'}';
                  final description = '${details?['description'] ?? ''}';

                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Request details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: kTextDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _detail('Emergency type', _label(type)),
                        _detail('Address', address),
                        if (description.isNotEmpty)
                          _detail('Description', description),
                        if (responderMobile != null)
                          _detail('Responder mobile', '$responderMobile'),
                      ],
                    ),
                  );
                },
              ),
              if (active) ...[
                const SizedBox(height: 24),
                if (status == 'pending')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _confirmCancel(context),
                      child: const Text('Cancel request'),
                    ),
                  ),
                if (status == 'matched')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _confirmResolve(context),
                      child: const Text('Mark as resolved'),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: kGreyText),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 15, color: kTextDark)),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text(
          'Are you sure you want to cancel this emergency request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep request'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await AkayBackend.cancelRequest(requestId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AkayBackend.friendlyError(e))));
    }
  }

  Future<void> _confirmResolve(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark as resolved?'),
        content: const Text(
          'Only do this if the emergency has actually been resolved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await AkayBackend.resolveRequest(requestId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AkayBackend.friendlyError(e))));
    }
  }
}