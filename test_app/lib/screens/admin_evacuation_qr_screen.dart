import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../main.dart';
import 'screen_widgets.dart';

/// Demo-only action code. It contains no user ID or secret.
const String evacuationDemoQrPayload = 'akay:evacuated:v1';

class AdminEvacuationQrScreen extends StatelessWidget {
  const AdminEvacuationQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle(
            label: 'DEMONSTRATION',
            title: 'Evacuation QR code',
            subtitle:
                'A signed-in user can scan this code to set their own status to evacuated.',
          ),
          const SizedBox(height: 20),
          const AppCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: QrImageView(
                  data: evacuationDemoQrPayload,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const StatusBanner(
            tone: BannerTone.warning,
            icon: Icons.info_outline,
            message:
                'Demo only: this QR is a public action code, not proof of admin approval. '
                'It can only update the account that scans it.',
          ),
        ],
      ),
    );
  }
}