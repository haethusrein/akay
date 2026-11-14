import 'package:flutter/material.dart';

import 'akay_backend.dart';
import 'main.dart';
import 'request_status_screen.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  static const _typeLabels = {
    'flood': 'Flood',
    'medical': 'Medical emergency',
    'fire': 'Fire',
    'other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
        foregroundColor: kTextDark,
        automaticallyImplyLeading: false,
        title: const Text('Request history'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: AkayBackend.myRequests(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(AkayBackend.friendlyError(snap.error!)));
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snap.data!;

          if (list.isEmpty) {
            return const Center(
              child: Text('No requests yet.', style: kGreyText),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = list[i];
              final status = '${r['status']}';
              final active = status == 'pending' || status == 'matched';

              return GestureDetector(
                onTap: () {
                  debugPrint('REQUEST TAPPED: ${r['id']}');

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          RequestStatusScreen(requestId: r['id'] as String),
                    ),
                  );
                },
                child: AppCard(
                  child: Row(
                    children: [
                      IconBox(
                        icon: active ? Icons.hourglass_top : Icons.history,
                        bg: active ? const Color(0xFFFDE9E5) : kLightGreen,
                        color: active ? kRed : kGreen,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _typeLabels[r['type']] ?? '${r['type']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: kTextDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${status[0].toUpperCase()}${status.substring(1)} - ${r['barangay'] ?? ''}',
                              style: kGreyText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: kTextGrey),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}