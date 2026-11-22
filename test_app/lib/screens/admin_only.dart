// admin tab for various back-end functions
// accessible only to one admin account (admin, 00000000)
// for verification, one-time pin generation, and logging exception errors

import 'dart:math';
import 'package:flutter/material.dart';
import '../akay_backend.dart';  

class AdminOnlyScreen extends StatelessWidget {
  const AdminOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADMIN FUNCTIONS',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                'Admin Only',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text('For admin account only.'),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder(
            stream: AkayBackend.myProfile(),
            builder: (context, snapshot) {
              final p = snapshot.data?.data();
              if (p == null) return const Center(child: CircularProgressIndicator());
              if (p['mobile'] != '00000000') {
                return const Center(child: Text('Access denied. Admin only.'));
              }
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final pin = (Random.secure().nextInt(900000) + 100000).toString();
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('One-Time Pin Generated'),
                          content: Text('Pin: $pin'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Generate One-Time Pin'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        debugPrint('Test exception from admin screen');
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Test exception printed to debug console.')),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error logging exception: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Log Test Exception'),
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