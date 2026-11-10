import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'akay_backend.dart';
import 'main.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _icon(String type) {
    switch (type) {
      case 'request_matched':
        return Icons.directions_run;
      case 'request_resolved':
        return Icons.check_circle_outline;
      case 'request_cancelled':
        return Icons.cancel_outlined;
      case 'request_created':
        return Icons.send_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  String _ago(dynamic ts) {
    if (ts is! Timestamp) return 'Just now';

    final difference = DateTime.now().difference(ts.toDate());

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }
    return '${difference.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: kBackground,
        foregroundColor: kTextDark,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await AkayBackend.markAllRead();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AkayBackend.friendlyError(e))),
                  );
                }
              }
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AkayBackend.notifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(AkayBackend.friendlyError(snapshot.error!)),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final isRead = data['isRead'] == true;

              return Dismissible(
                key: ValueKey(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: kRed,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) {
                  AkayBackend.deleteNotification(doc.id);
                },
                child: AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconBox(
                      icon: _icon('${data['type'] ?? ''}'),
                      size: 44,
                    ),
                    title: Text(
                      '${data['title'] ?? 'Notification'}',
                      style: TextStyle(
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${data['body'] ?? ''}\n${_ago(data['createdAt'])}',
                    ),
                    isThreeLine: true,
                    trailing: isRead
                        ? null
                        : const Icon(Icons.circle, size: 9, color: kGreen),
                    onTap: () async {
                      if (!isRead) {
                        await AkayBackend.markRead(doc.id);
                      }
                    },
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
