import 'package:flutter/material.dart';
import 'main.dart';
import 'responder_widgets.dart';

class RespondPingScreen extends StatefulWidget {
  const RespondPingScreen({super.key});

  @override
  State<RespondPingScreen> createState() => _RespondPingScreenState();
}

class _RespondPingScreenState extends State<RespondPingScreen> {
  // The choices in the "Travel mode" dropdown.
  final List<String> _modes = const [
    'Motorcycle - 8 min',
    'On foot - 20 min',
    'Boat - 15 min',
  ];
  late String _travel = _modes.first; // the selected choice

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

              const AlertBanner(
                icon: Icons.priority_high,
                text: 'CRITICAL - FLOOD - 2 MIN AGO',
                bg: Color(0xFFFFF6E0),
                border: Color(0xFFE8B84A),
                fg: Color(0xFF9A6B00),
              ),
              const SizedBox(height: 18),

              const Text(
                'Santos Household',
                style: TextStyle(fontSize: 28, color: kTextDark),
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: kTextGrey),
                  SizedBox(width: 4),
                  Text(
                    'Purok 4, Barangay Lumbo',
                    style: TextStyle(fontSize: 13, color: kTextGrey),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const _PingMap(),
              const SizedBox(height: 14),

              // Needs card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E0),
                  border: Border.all(color: const Color(0xFFE8B84A)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.accessible, color: Color(0xFF9A6B00)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wheelchair required',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kTextDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '2 seniors - Ground-floor access',
                            style: TextStyle(fontSize: 12, color: kTextGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Travel mode dropdown
              const Text('Travel mode',
                  style: TextStyle(fontSize: 13, color: kTextDark)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: kBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: _travel,
                  isExpanded: true, // fill the whole box
                  underline: const SizedBox.shrink(), // hide the default line
                  items: _modes
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  // Runs when the user picks a different choice.
                  onChanged: (value) {
                    if (value != null) setState(() => _travel = value);
                  },
                ),
              ),
              const SizedBox(height: 18),

              PrimaryButton(
                text: 'Confirm and respond',
                onPressed: () {
                  _say('Response confirmed - $_travel');
                },
              ),
              const SizedBox(height: 10),
              OutlineActionButton(
                text: 'Decline - show next responder',
                onPressed: () => Navigator.maybePop(context),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: () => _say('Report sent for review'),
                  child: const Text(
                    'Report suspicious ping',
                    style: TextStyle(
                      color: kTextDark,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// The small map: roads, the red "!" pin, and the "You" marker.
class _PingMap extends StatelessWidget {
  const _PingMap();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 180,
        width: double.infinity,
        color: const Color(0xFFE8EEE9),
        child: Stack(
          children: [
            Positioned(
              left: -20,
              top: 90,
              child: Transform.rotate(
                angle: -0.12,
                child: Container(width: 500, height: 14, color: Colors.white),
              ),
            ),
            Positioned(
              left: 190,
              top: -40,
              child: Transform.rotate(
                angle: 0.25,
                child: Container(width: 14, height: 300, color: Colors.white),
              ),
            ),
            // The red "!" pin (the household that needs help)
            Positioned(
              right: 90,
              top: 40,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: kRed,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // The "You" marker
            Positioned(
              left: 120,
              bottom: 40,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: kTextDark, width: 2),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'You',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}