import 'package:flutter/material.dart';
import 'main.dart';
import 'responder_widgets.dart';

class EmergencyInfoScreen extends StatelessWidget {
  const EmergencyInfoScreen({super.key});

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what - coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AkayBackHeader(),
              const SizedBox(height: 16),

              // Yellow alert strip
              const AlertBanner(
                icon: Icons.warning_amber_rounded,
                text: 'FLOOD ALERT - LEVEL 2',
                bg: Color(0xFFFFF6E0),
                border: Color(0xFFE8B84A),
                fg: Color(0xFF9A6B00),
              ),
              const SizedBox(height: 20),

              const Text(
                'Emergency information',
                style: TextStyle(fontSize: 28, color: kTextDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Saved for offline use - Updated 8 minutes ago',
                style: TextStyle(fontSize: 13, color: kTextGrey),
              ),
              const SizedBox(height: 18),

              // The three numbered instruction cards
              const _StepCard(
                number: '01',
                title: 'Prepare to evacuate',
                body: 'Bring medicine, IDs, water, and your emergency bag.',
              ),
              const SizedBox(height: 10),
              const _StepCard(
                number: '02',
                title: 'Use the safe route',
                body: 'Avoid Pulangi River Road. Use Purok 3 access.',
              ),
              const SizedBox(height: 10),
              const _StepCard(
                number: '03',
                title: 'Nearest evacuation center',
                body: 'Lumbo Elementary School - 1.2 km',
              ),
              const SizedBox(height: 18),

              PrimaryButton(
                text: 'View evacuation route',
                onPressed: () => _comingSoon(context, 'Evacuation route'),
              ),
              const SizedBox(height: 10),
              OutlineActionButton(
                text: 'Call emergency hotline',
                icon: Icons.phone_outlined,
                onPressed: () => _comingSoon(context, 'Calling'),
              ),
              const SizedBox(height: 18),

              // Offline warning (green strip, normal letters)
              const AlertBanner(
                icon: Icons.wifi_off,
                text:
                    'Information may be outdated while offline. Follow official radio and barangay instructions.',
                bg: kLightGreen,
                border: kBorder,
                fg: kGreen,
                caps: false,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// One numbered instruction card: a square with "01", then title and text.
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kLightGreen,
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(fontSize: 12, color: kTextGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
