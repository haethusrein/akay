import 'dart:async';
import 'package:flutter/material.dart';
import 'evacuation_qr_scanner_screen.dart';
import '../akay_backend.dart';
import '../create_account_screens.dart'; // fieldDecoration, FieldLabel, showComingSoon
import '../main.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Evacuation-center check-in (wireframe 12)
// A responder confirms a household arrived, which closes the rescue record.
//
// Backend used: AkayBackend.checkInHousehold(...)
// Privacy: a responder cannot look up other households (rules block it), so
// the responder types the household name/ID and how many people arrived.
// ============================================================
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _idController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  bool _allArrived = false;
  bool _busy = false;

  @override
  void dispose() {
    _idController.dispose();
    _countController.dispose();
    super.dispose();
  }

  // The button only works when a household is entered AND the box is ticked.
  int get _count => int.tryParse(_countController.text.trim()) ?? 0;

  bool get _canSubmit =>
      _idController.text.trim().isNotEmpty &&
      _count >= 1 && _count <= 50 &&
      _allArrived;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await AkayBackend.checkInHousehold(
        household: _idController.text,
        membersPresent: _count,
      ).timeout(const Duration(seconds: 4));
      if (!mounted) return;
      showComingSoon(context, 'Check-in saved. Household marked evacuated.');
    } on TimeoutException {
      if (!mounted) return;
      showComingSoon(context, 'No connection. Check-in saved on this phone. Waiting to sync.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showComingSoon(context, AkayBackend.friendlyError(e));
      return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return AkayScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle(
            label: 'EVACUATION CENTER CHECK-IN',
            title: 'Confirm household arrival',
            subtitle: 'Close the active rescue record and avoid duplicate checks.',
          ),
          const SizedBox(height: 20),
          const FieldLabel('Household ID or name'),
          TextField(
            controller: _idController,
            onChanged: (_) => setState(() {}),
            decoration: fieldDecoration('e.g. AKAY-HH-042 · Santos'),
          ),
          const SizedBox(height: 12),
          OutlineAction(
  label: 'Scan evacuation demo QR',
  icon: Icons.qr_code_scanner,
  onPressed: () async {
    final markedEvacuated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const EvacuationQrScannerScreen(),
      ),
    );

    if (!context.mounted || markedEvacuated != true) return;

    showComingSoon(
      context,
      'Your account status is now evacuated.',
    );
  },
),

          const FieldLabel('Members present'),
          TextField(
            controller: _countController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: fieldDecoration('e.g. 4'),
          ),
          const SizedBox(height: 12),

          CheckboxListTile(
            value: _allArrived,
            onChanged: (v) => setState(() => _allArrived = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: kGreen,
            title: const Text(
              'I confirmed all listed household members arrived.',
              style: TextStyle(fontSize: 14, color: kTextDark),
            ),
          ),
          const SizedBox(height: 8),
          SolidAction(
            label: 'Mark household evacuated',
            loading: _busy,
            onPressed: _canSubmit && !_busy ? _submit : null,
          ),
          const SizedBox(height: 12),
          const StatusBanner(
            tone: BannerTone.success,
            icon: Icons.schedule,
            message:
                'If offline, this check-in is saved locally and marked "Waiting to sync."',
          ),
          TextLinkButton(
            label: 'Cancel check-in',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
