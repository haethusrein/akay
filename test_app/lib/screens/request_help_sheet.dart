import 'dart:async';

import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'; // showComingSoon
import '../main.dart';
import 'akay_nav.dart';
import 'request_sync_status_screen.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - "What's happening?" bottom sheet (Figma)
//
// Opened by: Home -> "Request help now"  and  Requests -> "New help request"
//   showRequestHelpSheet(context);
//
// Backend used:
//   AkayBackend.myHousehold()           -> "Location ready" address
//   AkayBackend.sendRequest(type: ...)  -> sends the request
// After sending, the app opens the Requests tab, where the request shows
// as "Active now". If there is no internet, the "saved on this device"
// screen opens instead.
// ============================================================
Future<void> showRequestHelpSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _RequestHelpSheet(parentContext: context),
  );
}

const _typeHints = {
  'flood': 'Rising water or trapped by flooding',
  'medical': 'Urgent health or mobility support',
  'fire': 'Fire, smoke, or immediate danger',
  'other': 'Another emergency situation',
};

const _typeTitles = {
  'flood': 'Flood',
  'medical': 'Medical',
  'fire': 'Fire',
  'other': 'Other',
};

class _RequestHelpSheet extends StatefulWidget {
  final BuildContext parentContext; // the screen that opened the sheet
  const _RequestHelpSheet({required this.parentContext});

  @override
  State<_RequestHelpSheet> createState() => _RequestHelpSheetState();
}

class _RequestHelpSheetState extends State<_RequestHelpSheet> {
  String _type = 'flood';
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    final parent = widget.parentContext;
    try {
      // Firestore waits quietly when there is no connection, so stop after 10 s.
      await AkayBackend.sendRequest(type: _type)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      Navigator.of(context).pop();
      if (parent.mounted) goToTab(parent, 2); // Requests tab shows "Active now"
    } on TimeoutException {
      _goOffline();
    } catch (e) {
      if (!mounted) return;
      final message = AkayBackend.friendlyError(e);
      if (message == 'No internet connection.') {
        _goOffline();
      } else {
        setState(() => _sending = false);
        showComingSoon(context, message);
      }
    }
  }

  void _goOffline() {
    if (!mounted) return;
    final parent = widget.parentContext;
    Navigator.of(context).pop();
    if (parent.mounted) {
      Navigator.of(parent).push(
        MaterialPageRoute(builder: (_) => RequestSyncStatusScreen(type: _type)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD5DDDA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBox(
                icon: Icons.warning_amber_rounded,
                bg: Color(0xFFFDE9E5),
                color: kRed,
                size: 46,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REQUEST ASSISTANCE', style: kSmallLabel),
                    SizedBox(height: 4),
                    Text(
                      "What's happening?",
                      style: TextStyle(fontSize: 24, color: kTextDark),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEDF1EF),
                ),
                icon: const Icon(Icons.close, size: 18, color: kTextGrey),
                onPressed: _sending ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose the emergency type. Your live location and household needs will be shared.',
            style: TextStyle(fontSize: 13, color: kTextGrey, height: 1.4),
          ),
          const SizedBox(height: 14),

          // the four choices
          for (final t in kRequestTypes)
            _TypeOption(
              title: _typeTitles[t]!,
              hint: _typeHints[t]!,
              selected: _type == t,
              onTap: _sending ? null : () => setState(() => _type = t),
            ),

          const SizedBox(height: 4),

          // location ready
          StreamBuilder(
            stream: AkayBackend.myHousehold(),
            builder: (context, snapshot) {
              final address = snapshot.data?.data()?['address']?.toString();
              final ready = address != null && address.isNotEmpty;
              final shown = ready
                  ? address
                  : (kShowSampleData && snapshot.data == null
                      ? 'Purok 4, Barangay Lumbo'
                      : null);
              if (shown == null) {
                return const StatusBanner(
                  tone: BannerTone.warning,
                  icon: Icons.location_off_outlined,
                  title: 'Location needed',
                  message: 'Add your household address before sending a request.',
                );
              }
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kLightGreen,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCFE5DA)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_on_outlined,
                          size: 20, color: kGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location ready',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kGreen,
                            ),
                          ),
                          Text(shown, style: kGreyText),
                        ],
                      ),
                    ),
                    const Icon(Icons.check, size: 18, color: kGreen),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),
          SolidAction(
            label: 'Send ${_typeTitles[_type]!.toLowerCase()} assistance request',
            color: kRed,
            loading: _sending,
            onPressed: _send,
          ),
          TextLinkButton(
            label: 'Cancel',
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

// One radio card ("Flood / Rising water or trapped by flooding").
class _TypeOption extends StatelessWidget {
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback? onTap;

  const _TypeOption({
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? kLightGreen : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? kGreen : kBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? kGreen : kHintGrey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(hint, style: kGreyText),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
