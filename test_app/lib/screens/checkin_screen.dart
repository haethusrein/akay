import 'package:flutter/material.dart';

import '../create_account_screens.dart'; // fieldDecoration, FieldLabel, showComingSoon
import '../main.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Evacuation-center check-in (wireframe 12)
// A responder confirms a household arrived, which closes the rescue record.
//
// UI only. TODO(backend): look up the household by ID or QR and save the
// check-in (queue it when offline). The numbers below are sample data.
// ============================================================
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _idController = TextEditingController();
  bool _allArrived = false;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  // The button only works when a household is entered AND the box is ticked.
  bool get _canSubmit => _idController.text.trim().isNotEmpty && _allArrived;

  void _submit() {
    // TODO(backend): save the check-in. If offline, mark it "Waiting to sync".
    showComingSoon(
      context,
      'Check-in saved on this phone. Waiting to sync. (Not sent to the server yet.)',
    );
    Navigator.of(context).maybePop();
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
            label: 'Scan household QR instead',
            icon: Icons.qr_code_scanner,
            // TODO: QR scanning needs a camera package.
            onPressed: () =>
                showComingSoon(context, 'QR scanning is coming soon.'),
          ),
          const SizedBox(height: 16),

          // sample details of the household found
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: const Column(
              children: [
                DetailRow(label: 'Members expected', value: '4 people'),
                Divider(height: 1, color: kBorder),
                DetailRow(label: 'Members present', value: '4 people'),
                Divider(height: 1, color: kBorder),
                DetailRow(label: 'Center', value: 'Lumbo Elementary'),
                Divider(height: 1, color: kBorder),
                DetailRow(label: 'Current status', value: 'In transit'),
              ],
            ),
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
            onPressed: _canSubmit ? _submit : null,
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
