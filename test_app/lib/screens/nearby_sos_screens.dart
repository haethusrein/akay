import 'package:flutter/material.dart';

import '../main.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Nearby SOS (Bluetooth) screens
//
//   NearbySosScreen   the resident's phone, 2 states:
//                       Bluetooth off / nobody near  (wireframe 07)
//                       Shared Nearby                (wireframe 06)
//   RelayPhoneScreen  a neighbour's phone holding someone's SOS (wireframe 08)
//
// UI ONLY. TODO(backend): real Bluetooth (BLE) sending, scanning and relaying.
// The numbers and names shown here are sample data.
// ============================================================

class NearbySosScreen extends StatefulWidget {
  final bool bluetoothOn;
  const NearbySosScreen({super.key, this.bluetoothOn = false});

  @override
  State<NearbySosScreen> createState() => _NearbySosScreenState();
}

class _NearbySosScreenState extends State<NearbySosScreen> {
  late bool _on = widget.bluetoothOn;

  @override
  Widget build(BuildContext context) {
    return AkayScreen(child: _on ? _shared(context) : _off(context));
  }

  // ----- Wireframe 07: Bluetooth is off -----
  Widget _off(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ScreenTitle(label: 'NEARBY SOS', title: 'Turn on Bluetooth'),
        const SizedBox(height: 16),
        const StatusBanner(
          tone: BannerTone.warning,
          icon: Icons.bluetooth_disabled,
          message:
              'Bluetooth is off. Turn it on to share your SOS with nearby AKAY phones.',
        ),
        const SizedBox(height: 16),
        SolidAction(
          label: 'Turn on Bluetooth',
          // TODO(backend): ask the system to enable Bluetooth. For now it just
          // moves to the "Shared Nearby" screen so you can see the design.
          onPressed: () => setState(() => _on = true),
        ),
        const SizedBox(height: 12),
        OutlineAction(
          label: 'Not now',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No nearby AKAY phone found',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Your request stays Waiting to Sync and AKAY keeps trying.\n\n'
                'Meanwhile: call the hotline, use the radio, or tell your purok leader.',
                style: TextStyle(fontSize: 14, height: 1.4, color: kTextGrey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SolidAction(
          label: 'Call emergency hotline',
          color: kRed,
          onPressed: () => callHotline(context),
        ),
      ],
    );
  }

  // ----- Wireframe 06: Shared Nearby -----
  Widget _shared(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ScreenTitle(label: 'NEARBY SOS', title: 'Shared Nearby'),
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 150,
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kLightGreen,
              border: Border.all(color: kGreen, width: 3),
            ),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                // TODO(backend): real number of phones found by Bluetooth.
                '3 AKAY phones in range',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kGreen,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const StatusBanner(
          tone: BannerTone.success,
          icon: Icons.bluetooth_connected,
          message:
              'Your SOS was sent to 3 nearby phones. It will reach responders when one of them gets a connection.',
        ),
        const SizedBox(height: 20),
        const StepRow(
          number: 1,
          title: 'Locally Saved',
          state: StepStatus.done,
        ),
        const StepRow(
          number: 2,
          title: 'Shared Nearby',
          caption: 'Not yet confirmed by responders',
          state: StepStatus.current,
        ),
        const StepRow(
          number: 3,
          title: 'Receipt Confirmed',
          state: StepStatus.waiting,
          isLast: true,
        ),
        const SizedBox(height: 24),
        OutlineAction(
          label: 'Call emergency hotline',
          icon: Icons.phone_outlined,
          onPressed: () => callHotline(context),
        ),
        TextLinkButton(
          label: 'Keep Bluetooth on',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

// ============================================================
// Wireframe 08: a neighbour's phone is holding someone else's SOS
// ============================================================
class RelayPhoneScreen extends StatelessWidget {
  const RelayPhoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AkayScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle(
            label: 'SOS RECEIVED NEARBY',
            title: 'Help request nearby',
          ),
          const SizedBox(height: 16),

          // TODO(backend): fill this from the SOS received over Bluetooth.
          // Only essential details are shown (privacy).
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kTextDark, width: 1.4),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Santos Household · about 20 m away',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kTextDark,
                  ),
                ),
                SizedBox(height: 6),
                Text('Flood · 2 seniors · wheelchair needed', style: kGreyText),
                SizedBox(height: 2),
                Text('Received 9:42 AM', style: kGreyText),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const StatusBanner(
            tone: BannerTone.success,
            icon: Icons.bluetooth_connected,
            message:
                'Your phone is holding this SOS. It will upload it to responders as soon as you have a connection.',
          ),
          const SizedBox(height: 20),
          const StepRow(
            number: 1,
            title: 'Held on this phone',
            state: StepStatus.done,
          ),
          const StepRow(
            number: 2,
            title: 'Uploaded to responders',
            state: StepStatus.waiting,
            isLast: true,
          ),
          const SizedBox(height: 24),
          SolidAction(
            label: 'Call hotline for this household',
            onPressed: () => callHotline(context),
          ),
          const SizedBox(height: 12),
          OutlineAction(
            label: 'Keep relaying in the background',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
