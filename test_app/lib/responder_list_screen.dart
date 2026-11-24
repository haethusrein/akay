import 'package:flutter/material.dart';
import 'main.dart';
import 'responder_widgets.dart';
import 'respond_ping_screen.dart';

// StatefulWidget, because this screen must remember whether the
// "List" or the "Map" tab is selected.
class ResponderListScreen extends StatefulWidget {
  const ResponderListScreen({super.key});

  @override
  State<ResponderListScreen> createState() => _ResponderListScreenState();
}

class _ResponderListScreenState extends State<ResponderListScreen> {
  bool _showList = true; // true = List tab, false = Map tab

  void _comingSoon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what - coming soon')),
    );
  }

  // Opens the "Respond to a ping" screen on top of this one.
  void _openPing() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RespondPingScreen()),
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
                icon: Icons.wifi_off,
                text: 'OFFLINE COPY - UPDATED 10:38 AM',
                bg: kLightGreen,
                border: kBorder,
                fg: kGreen,
              ),
              const SizedBox(height: 20),

              const Text(
                'Households needing help',
                style: TextStyle(fontSize: 26, color: kTextDark),
              ),
              const SizedBox(height: 16),

              // ----- List / Map switch -----
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: kBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _Tab(
                      text: 'List - 6',
                      selected: _showList,
                      onTap: () => setState(() => _showList = true),
                    ),
                    _Tab(
                      text: 'Map',
                      selected: !_showList,
                      onTap: () => setState(() => _showList = false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ----- Filters (display only for now) -----
              const Row(
                children: [
                  Expanded(child: _FilterChip(label: 'Priority')),
                  SizedBox(width: 8),
                  Expanded(child: _FilterChip(label: 'Needs')),
                  SizedBox(width: 8),
                  Expanded(child: _FilterChip(label: 'Status')),
                ],
              ),
              const SizedBox(height: 14),

              // ----- Show the list OR the map placeholder -----
              if (_showList) ...[
                _HouseholdCard(
                  tag: 'CRITICAL - 12 MIN',
                  tagColor: kRed,
                  accent: kRed,
                  name: 'Reyes Household',
                  line1: 'Purok 2 - Still here',
                  line2: 'Bedridden - Oxygen tank - 3 people',
                  buttonText: 'Open request',
                  onPressed: () => _comingSoon('Reyes request'),
                ),
                const SizedBox(height: 10),
                _HouseholdCard(
                  tag: 'HIGH - 8 MIN',
                  tagColor: const Color(0xFFB07A00),
                  name: 'Santos Household',
                  line1: 'Purok 4 - Request waiting',
                  line2: 'Wheelchair - 2 seniors - 4 people',
                  buttonText: 'Open request',
                  onPressed: _openPing,
                ),
                const SizedBox(height: 10),
                _HouseholdCard(
                  tag: 'LOCAL UPDATE',
                  tagColor: kTextGrey,
                  muted: true,
                  name: 'Cruz Household',
                  line1: 'Purok 1 - In transit',
                  line2: 'Status waiting to sync',
                  buttonText: 'Open household',
                  onPressed: () => _comingSoon('Cruz household'),
                ),
              ] else
                Container(
                  height: 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EEE9),
                    border: Border.all(color: kBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Map view coming soon',
                    style: TextStyle(color: kTextGrey),
                  ),
                ),
              const SizedBox(height: 16),

              const Center(
                child: Text(
                  'Data may be outdated. Confirm by radio when possible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: kTextGrey),
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

// One half of the List/Map switch.
class _Tab extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? kGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : kTextDark,
            ),
          ),
        ),
      ),
    );
  }
}

// A small filter box with a dropdown arrow.
class _FilterChip extends StatelessWidget {
  final String label;
  const _FilterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: kTextDark)),
          const Icon(Icons.arrow_drop_down, size: 18, color: kTextGrey),
        ],
      ),
    );
  }
}

// One household in the list. Used 3 times with different words.
class _HouseholdCard extends StatelessWidget {
  final String tag; // e.g. "CRITICAL - 12 MIN"
  final Color tagColor;
  final Color? accent; // colored strip on the left (optional)
  final bool muted; // true = greyed-out look (for "local update")
  final String name;
  final String line1;
  final String line2;
  final String buttonText;
  final VoidCallback onPressed;

  const _HouseholdCard({
    required this.tag,
    required this.tagColor,
    required this.name,
    required this.line1,
    required this.line2,
    required this.buttonText,
    required this.onPressed,
    this.accent,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // clipBehavior cuts the colored strip to the rounded corners.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF2F4F2) : Colors.white,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      // IntrinsicHeight lets the strip stretch to the card's full height.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accent != null) Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: tagColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: kTextDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(line1,
                              style: const TextStyle(
                                  fontSize: 12, color: kTextGrey)),
                          Text(line2,
                              style: const TextStyle(
                                  fontSize: 12, color: kTextGrey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: onPressed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kGreen,
                        side: const BorderSide(color: kGreen),
                        backgroundColor: kLightGreen,
                        textStyle: const TextStyle(fontSize: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(buttonText),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}