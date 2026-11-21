import 'package:flutter/material.dart';

import '../create_account_screens.dart'; // showComingSoon
import '../main.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Emergency information (wireframe 09) - the OFFLINE screen
//
// This screen needs NO internet and NO login: everything it shows is
// written right here in the app, so it still opens when the signal is gone.
//
// Opened from:  Sign in -> "Open offline information"
//               Community -> "View advisory" / "View safe route"
//
// To change the instructions, edit the constants below.
// TODO(backend): later, save the latest advisory from AkayBackend on the
// phone (shared_preferences) and show it here instead of these defaults.
// ============================================================

const _alertTitle = 'FLOOD ALERT · LEVEL 2';

const _steps = [
  (
    '01',
    'Prepare to evacuate',
    'Bring medicine, IDs, water, and your emergency bag.',
  ),
  (
    '02',
    'Use the safe route',
    'Avoid Pulangi River Road. Use the Purok 3 access.',
  ),
  (
    '03',
    'Nearest evacuation center',
    'Lumbo Elementary School · 1.2 km',
  ),
];

class EmergencyInfoScreen extends StatelessWidget {
  const EmergencyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AkayScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatusBanner(
            tone: BannerTone.warning,
            icon: Icons.warning_amber_rounded,
            title: _alertTitle,
            message: 'Follow the steps below and stay alert.',
          ),
          const SizedBox(height: 20),
          const ScreenTitle(
            label: 'SAVED ON THIS PHONE',
            title: 'Emergency information',
            subtitle: 'Saved for offline use. This page works without internet.',
          ),
          const SizedBox(height: 20),

          for (final s in _steps) _StepCard(number: s.$1, title: s.$2, body: s.$3),

          const SizedBox(height: 8),
          SolidAction(
            label: 'View evacuation route',
            // TODO: open the map with the route to the evacuation center.
            onPressed: () =>
                showComingSoon(context, 'Evacuation route map is coming soon.'),
          ),
          const SizedBox(height: 12),
          OutlineAction(
            label: 'Call emergency hotline',
            icon: Icons.phone_outlined,
            onPressed: () => callHotline(context),
          ),
          const SizedBox(height: 16),
          const StatusBanner(
            tone: BannerTone.success,
            icon: Icons.wifi_off,
            message:
                'Information may be outdated while offline. Follow official radio and barangay instructions.',
          ),
        ],
      ),
    );
  }
}

// One numbered instruction card ("01  Prepare to evacuate ...").
class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _StepCard({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kLightGreen,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCFE5DA)),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kGreen,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: kTextGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
