import 'package:flutter/material.dart';
import 'main.dart'; // colors
import 'shared_widgets.dart'; // AkayHeader and ConnectedBanner

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  // Temporary: shows a small message at the bottom until the real
  // screens for these buttons exist.
  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what - coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold = the page frame (background, body, etc.)
    return Scaffold(
      backgroundColor: kBackground,
      // SafeArea keeps content away from the phone notch / status bar.
      body: SafeArea(
        // SingleChildScrollView lets the page scroll if it's too tall.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          // Column = stack children top to bottom.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AkayHeader(),
              const SizedBox(height: 14),
              const ConnectedBanner(),
              const SizedBox(height: 22),

              // ----- Title row: text on the left, button on the right -----
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Expanded = take all the space the button doesn't need.
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIVE BARANGAY OVERVIEW',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: kGreen,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Community',
                          style: TextStyle(fontSize: 32, color: kTextDark),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Monitor local alerts, responders, and safe evacuation routes.',
                          style: TextStyle(fontSize: 13, color: kTextGrey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _comingSoon(context, 'Find my location'),
                    icon: const Icon(Icons.location_on_outlined, size: 16),
                    label: const Text('Find my location'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kGreen,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ----- The map card -----
              const _MapCard(),
              const SizedBox(height: 14),

              // ----- The three info cards -----
              _InfoCard(
                icon: Icons.warning_amber_rounded,
                iconBg: const Color(0xFFFFF3DC),
                iconColor: const Color(0xFFE0A100),
                label: 'ACTIVE ADVISORY',
                title: 'Flood alert - Level 2',
                body: 'Residents near Pulangi River should prepare to evacuate.',
                buttonText: 'View advisory',
                onPressed: () => _comingSoon(context, 'Advisory'),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.route_outlined,
                iconBg: const Color(0xFFE3F0FA),
                iconColor: const Color(0xFF3B82C4),
                label: 'RECOMMENDED ROUTE',
                title: 'Lumbo Elementary School',
                body: 'Open and passable. Estimated walk: 14 minutes.',
                buttonText: 'View safe route',
                onPressed: () => _comingSoon(context, 'Safe route'),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.groups_outlined,
                iconBg: kLightGreen,
                iconColor: kGreen,
                label: 'RESPONSE TEAM',
                title: '12 responders available',
                body: '8 barangay responders and 4 verified volunteers online.',
                buttonText: 'Refresh status',
                onPressed: () => _comingSoon(context, 'Refresh'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// The "Live response map" card. The map is a simple drawing made from
// colored boxes and icons, same as the mockup. A real map can replace
// it later.
// ---------------------------------------------------------------
class _MapCard extends StatelessWidget {
  const _MapCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BARANGAY LUMBO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: kGreen,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: Color(0xFF3FA37A)),
                  SizedBox(width: 6),
                  Text(
                    'Updating live',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Live response map',
            style: TextStyle(fontSize: 20, color: kTextDark),
          ),
          const SizedBox(height: 12),

          // ----- The "map" -----
          // ClipRRect cuts anything that sticks out of the rounded corners.
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 210,
              color: const Color(0xFFE8EEE9),
              // Stack = place children ON TOP of each other.
              // Positioned says exactly where each one goes.
              child: Stack(
                children: [
                  // river (left side)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 40,
                    child: Container(color: const Color(0xFFC9DDE3)),
                  ),
                  // roads (white bars, rotated)
                  Positioned(
                    left: -20,
                    top: 60,
                    child: Transform.rotate(
                      angle: -0.15,
                      child: Container(
                          width: 420, height: 16, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    left: 40,
                    top: 120,
                    child: Transform.rotate(
                      angle: 0.4,
                      child: Container(
                          width: 360, height: 16, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    left: 130,
                    top: -40,
                    child: Transform.rotate(
                      angle: 0.2,
                      child: Container(
                          width: 16, height: 300, color: Colors.white),
                    ),
                  ),
                  // labels
                  const Positioned(
                    left: 60,
                    top: 24,
                    child: Text('Purok 3',
                        style: TextStyle(fontSize: 12, color: kTextGrey)),
                  ),
                  const Positioned(
                    right: 40,
                    top: 100,
                    child: Text('Purok 4',
                        style: TextStyle(fontSize: 12, color: kTextGrey)),
                  ),
                  const Positioned(
                    left: 70,
                    bottom: 14,
                    child: Text(
                      'Evacuation center',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kGreen,
                      ),
                    ),
                  ),
                  // pins
                  const Positioned(
                    left: 130,
                    top: 70,
                    child: Icon(Icons.home, size: 32, color: kGreen),
                  ),
                  const Positioned(
                    left: 60,
                    top: 105,
                    child: Icon(Icons.location_on, size: 20, color: kRed),
                  ),
                  const Positioned(
                    right: 20,
                    top: 14,
                    child: Icon(Icons.location_on,
                        size: 20, color: Color(0xFF3FA37A)),
                  ),
                  const Positioned(
                    left: 200,
                    bottom: 10,
                    child: Icon(Icons.location_on,
                        size: 20, color: Color(0xFF3FA37A)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ----- The 3 numbers under the map -----
          const Row(
            children: [
              Expanded(child: _Stat(value: '12', label: 'Responders online')),
              SizedBox(height: 40, child: VerticalDivider(color: kBorder)),
              Expanded(child: _Stat(value: '3', label: 'Active requests')),
              SizedBox(height: 40, child: VerticalDivider(color: kBorder)),
              Expanded(child: _Stat(value: '1.2 km', label: 'Nearest center')),
            ],
          ),
        ],
      ),
    );
  }
}

// One number with a small label under it.
class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: kTextDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: kTextGrey),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// A reusable card: icon, small label, title, text and a button.
// We use it 3 times above, only with different words.
// ---------------------------------------------------------------
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String title;
  final String body;
  final String buttonText;
  final VoidCallback onPressed;

  const _InfoCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.title,
    required this.body,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: kGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, color: kTextDark)),
                    const SizedBox(height: 4),
                    Text(body,
                        style: const TextStyle(
                            fontSize: 12, color: kTextGrey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                backgroundColor: kLightGreen,
                foregroundColor: kGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '$buttonText  >',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}