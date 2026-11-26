import 'package:flutter/material.dart';

import '../ble/ble_sos_service.dart';
import '../main.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Nearby SOS (Bluetooth) screens
//
//   NearbySosScreen   the resident's phone, 2 states:
//                       Bluetooth off / SOS not started   (wireframe 07)
//                       Shared Nearby                     (wireframe 06)
//   RelayPhoneScreen  a neighbour's phone holding someone's SOS (wireframe 08)
//
// Real Bluetooth now. All the BLE work lives in ../ble/ble_sos_service.dart.
// ============================================================

class NearbySosScreen extends StatefulWidget {
  final String type; // 'flood' | 'medical' | 'fire' | 'other'
  const NearbySosScreen({super.key, this.type = 'flood'});

  @override
  State<NearbySosScreen> createState() => _NearbySosScreenState();
}

class _NearbySosScreenState extends State<NearbySosScreen> {
  final _ble = BleSosService.instance;
  bool _starting = false;

  Future<void> _start() async {
    setState(() => _starting = true);
    await _ble.startMySos(type: widget.type);
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AkayScreen(
      child: ListenableBuilder(
        listenable: _ble,
        builder: (context, _) =>
            _ble.sosActive ? _shared(context) : _off(context),
      ),
    );
  }

  // ----- Wireframe 07: Bluetooth is off / SOS not started -----
  Widget _off(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ScreenTitle(label: 'NEARBY SOS', title: 'Turn on Bluetooth'),
        const SizedBox(height: 16),
        StatusBanner(
          tone: _ble.error == null ? BannerTone.warning : BannerTone.danger,
          icon: Icons.bluetooth_disabled,
          message: _ble.error ??
              'Share your ${requestTypeLabel(widget.type).toLowerCase()} SOS with nearby AKAY phones. They will pass it to responders when they get a connection.',
        ),
        const SizedBox(height: 16),
        SolidAction(
          label: 'Turn on Bluetooth and share SOS',
          loading: _starting,
          onPressed: _starting ? null : _start,
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
    final n = _ble.ackCount;
    final confirmed = n > 0;
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
              color: confirmed ? kLightGreen : Colors.white,
              border: Border.all(color: confirmed ? kGreen : kBorder, width: 3),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                confirmed
                    ? '$n AKAY phone${n == 1 ? '' : 's'} holding your SOS'
                    : 'Broadcasting your SOS…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: confirmed ? kGreen : kTextGrey,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        StatusBanner(
          tone: confirmed ? BannerTone.success : BannerTone.warning,
          icon: confirmed ? Icons.bluetooth_connected : Icons.bluetooth_searching,
          message: confirmed
              ? 'Your SOS is held by $n nearby phone${n == 1 ? '' : 's'}. It will reach responders when one of them gets a connection.'
              : 'No phone has confirmed holding your SOS yet. Stay where you are, keep Bluetooth on, and ask neighbours to open AKAY.',
        ),
        const SizedBox(height: 20),
        const StepRow(
          number: 1,
          title: 'Locally Saved',
          state: StepStatus.done,
        ),
        StepRow(
          number: 2,
          title: 'Shared Nearby',
          caption: confirmed
              ? 'Not yet confirmed by responders'
              : 'Waiting for a nearby phone to pick it up',
          state: confirmed ? StepStatus.done : StepStatus.current,
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
        TextLinkButton(
          label: 'Stop sharing my SOS',
          onPressed: _ble.stopMySos,
        ),
      ],
    );
  }
}

// ============================================================
// Wireframe 08: a neighbour's phone is holding someone else's SOS
// ============================================================
class RelayPhoneScreen extends StatefulWidget {
  const RelayPhoneScreen({super.key});

  @override
  State<RelayPhoneScreen> createState() => _RelayPhoneScreenState();
}

class _RelayPhoneScreenState extends State<RelayPhoneScreen> {
  final _ble = BleSosService.instance;

  @override
  void initState() {
    super.initState();
    _ble.startListening(); // starts scanning; held SOS are loaded from disk
  }

  @override
  Widget build(BuildContext context) {
    return AkayScreen(
      child: ListenableBuilder(
        listenable: _ble,
        builder: (context, _) {
          final held = _ble.held;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenTitle(
                label: 'SOS RECEIVED NEARBY',
                title: held.isEmpty ? 'Listening for SOS' : 'Help request nearby',
              ),
              const SizedBox(height: 16),
              if (_ble.error != null) ...[
                StatusBanner(
                  tone: BannerTone.danger,
                  icon: Icons.bluetooth_disabled,
                  message: _ble.error!,
                ),
                const SizedBox(height: 14),
              ],
              if (held.isEmpty)
                const StatusBanner(
                  tone: BannerTone.warning,
                  icon: Icons.bluetooth_searching,
                  message:
                      'No SOS heard yet. Keep this screen open or AKAY running. Anything nearby will be held here and uploaded when you have a connection.',
                ),
              for (final h in held) ...[
                _HeldCard(h: h),
                const SizedBox(height: 14),
                StepRow(
                  number: 1,
                  title: 'Held on this phone',
                  state: StepStatus.done,
                ),
                StepRow(
                  number: 2,
                  title: 'Uploaded to responders',
                  caption: h.uploaded ? null : 'Waiting for a connection',
                  state: h.uploaded ? StepStatus.done : StepStatus.current,
                  isLast: true,
                ),
                const SizedBox(height: 20),
              ],
              if (held.isNotEmpty)
                const StatusBanner(
                  tone: BannerTone.success,
                  icon: Icons.bluetooth_connected,
                  message:
                      'Your phone is holding these SOS. It uploads them to responders as soon as you have a connection.',
                ),
              const SizedBox(height: 20),
              SolidAction(
                label: 'Call hotline for this household',
                onPressed: () => callHotline(context),
              ),
              const SizedBox(height: 12),
              OutlineAction(
                label: 'Keep relaying in the background',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              TextLinkButton(
                label: 'Stop relaying',
                onPressed: () async {
                  await _ble.stopListening();
                  if (context.mounted) Navigator.of(context).maybePop();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeldCard extends StatelessWidget {
  final HeldSos h;
  const _HeldCard({required this.h});

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(
      DateTime.fromMillisecondsSinceEpoch(h.heardAtMs),
    ).format(context);
    final needs = [
      '${requestTypeLabel(h.type)}',
      '${h.members} ${h.members == 1 ? 'person' : 'people'}',
      if (h.mobilityNeed != 'None') h.mobilityNeed.toLowerCase(),
    ].join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kTextDark, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Household #${h.tag.substring(0, 4)} · ${h.proximity}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(needs, style: kGreyText),
          const SizedBox(height: 2),
          Text('Received $time', style: kGreyText),
        ],
      ),
    );
  }
}
