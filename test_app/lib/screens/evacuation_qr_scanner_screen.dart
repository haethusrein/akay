import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../akay_backend.dart';
import '../main.dart';
import 'admin_evacuation_qr_screen.dart';
import 'screen_widgets.dart';

class EvacuationQrScannerScreen extends StatefulWidget {
  const EvacuationQrScannerScreen({super.key});

  @override
  State<EvacuationQrScannerScreen> createState() =>
      _EvacuationQrScannerScreenState();
}

class _EvacuationQrScannerScreenState
    extends State<EvacuationQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;

    String? value;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        value = rawValue;
        break;
      }
    }

    if (value == null) return;

    setState(() => _processing = true);
    await _controller.stop();
    if (!mounted) return;

    if (value != evacuationDemoQrPayload) {
      final scanAgain = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('QR code not recognized'),
          content: const Text(
            'This is not the AKAY evacuation demonstration code.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Scan again'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (scanAgain == true) {
        setState(() => _processing = false);
        await _controller.start();
      } else {
        Navigator.of(context).pop(false);
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark your account evacuated?'),
        content: const Text(
          'This updates the evacuation status for the account currently signed in on this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed != true) {
      setState(() => _processing = false);
      await _controller.start();
      return;
    }

    try {
      await AkayBackend.setEvacuationStatus('evacuated');
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AkayBackend.friendlyError(error))),
      );
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Scan evacuation QR'),
        backgroundColor: kBackground,
        foregroundColor: kTextDark,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Scan the demonstration QR shown on the admin account. '
              'Only your signed-in account will be updated.',
              textAlign: TextAlign.center,
              style: kGreyText,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: StatusBanner(
              tone: BannerTone.warning,
              icon: Icons.warning_amber_rounded,
              message:
                  'Check that the correct account is signed in before confirming.',
            ),
          ),
        ],
      ),
    );
  }
}