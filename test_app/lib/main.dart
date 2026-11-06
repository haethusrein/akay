import 'package:flutter/material.dart';

// ============================================================
// AKAY - Home screen (front end only, no backend yet)
//
// How to read this file:
//   1. main() starts the app.
//   2. AkayApp sets the theme and says "the first screen is HomeScreen".
//   3. HomeScreen stacks the page sections from top to bottom.
//   4. The small widgets at the bottom (AppCard, IconBox, ...) are
//      reusable building blocks, so we don't repeat the same code.
// ============================================================

void main() {
  runApp(const AkayApp());
}

// ---------- Colors (change them here and the whole app updates) ----------
const kGreen = Color(0xFF0F5C4D);
const kLightGreen = Color(0xFFE6F2EC);
const kBackground = Color(0xFFF3F6F4);
const kRed = Color(0xFFDD5148);
const kTextDark = Color(0xFF1C2B27);
const kTextGrey = Color(0xFF6B7A75);
const kBorder = Color(0xFFE3E9E6);

// ---------- Text styles ----------
const kSmallLabel = TextStyle(
  fontSize: 12,
  letterSpacing: 1.2,
  fontWeight: FontWeight.w700,
  color: kGreen,
);
const kGreyText = TextStyle(fontSize: 13, color: kTextGrey);

// ============================================================
// The app
// ============================================================
class AkayApp extends StatelessWidget {
  const AkayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AKAY',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kGreen,
        scaffoldBackgroundColor: kBackground,
      ),
      home: const HomeScreen(),
    );
  }
}

// ============================================================
// The home screen
// ============================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SafeArea keeps content away from the phone's status bar.
      // SingleChildScrollView lets the page scroll when it is long.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildHeader(),
              const SizedBox(height: 16),
              buildConnectedBanner(),
              const SizedBox(height: 16),
              buildEmergencyCard(),
              const SizedBox(height: 28),
              buildHouseholdSection(),
              const SizedBox(height: 28),
              buildUpdatesSection(),
              const SizedBox(height: 20),
              buildCommunityStatus(),
              const SizedBox(height: 16),
              buildHotlineCard(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),

      // Bottom navigation bar (not clickable yet - selectedIndex is fixed at 0)
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        backgroundColor: Colors.white,
        indicatorColor: kLightGreen,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: kGreen),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            label: 'Community',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ---------- Top bar: logo, name, bell, menu ----------
  Widget buildHeader() {
    return Row(
      children: [
        const IconBox(
          icon: Icons.shield_outlined,
          bg: kGreen,
          color: Colors.white,
          size: 40,
        ),
        const SizedBox(width: 10),
        const Text(
          'AKAY',
          style: TextStyle(
            fontSize: 18,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            color: kTextDark,
          ),
        ),
        const Spacer(), // pushes everything after it to the right
        const IconBox(icon: Icons.notifications_none, size: 40),
        const SizedBox(width: 8),
        const IconBox(icon: Icons.menu, size: 40),
      ],
    );
  }

  // ---------- Green "Connected" strip ----------
  Widget buildConnectedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kLightGreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFE5DA)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi, size: 16, color: kGreen),
          SizedBox(width: 8),
          Text(
            'Connected',
            style: TextStyle(fontWeight: FontWeight.w600, color: kGreen),
          ),
          SizedBox(width: 12),
          Text('Emergency network active', style: kGreyText),
        ],
      ),
    );
  }

  // ---------- Big "Do you need help?" card ----------
  Widget buildEmergencyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF1EE),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF6DDD8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('EMERGENCY ASSISTANCE', style: kSmallLabel),
          const SizedBox(height: 10),
          const Text(
            'Do you need help?',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w500,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Send your location and household needs to nearby verified responders.',
            style: TextStyle(fontSize: 14, color: kTextGrey, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: later, this will send the help request to Firebase
              },
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text(
                'Request help now',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Only use this during an emergency',
              style: TextStyle(fontSize: 12, color: kTextGrey),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- "Your household" section ----------
  Widget buildHouseholdSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          label: 'HOUSEHOLD READINESS',
          title: 'Your household',
          actionText: 'Manage details',
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + address + Verified badge
              Row(
                children: [
                  const IconBox(
                    icon: Icons.home_outlined,
                    bg: kLightGreen,
                    size: 46,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Santos Household',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: kTextDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: kTextGrey,
                            ),
                            SizedBox(width: 4),
                            Text('Purok 4, Barangay Lumbo', style: kGreyText),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kLightGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check, size: 14, color: kGreen),
                        SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32, color: kBorder),

              // Three info rows
              const InfoRow(
                icon: Icons.people_outline,
                bg: Color(0xFFE8F1FB),
                color: Color(0xFF3B82C4),
                value: '4',
                label: 'members',
              ),
              const InfoRow(
                icon: Icons.accessible,
                bg: Color(0xFFFFF3DC),
                color: Color(0xFFE0A030),
                value: '1',
                label: 'mobility need',
              ),
              const InfoRow(
                icon: Icons.shield_outlined,
                bg: kLightGreen,
                color: kGreen,
                value: 'Ready',
                label: 'emergency profile',
              ),
              const Divider(height: 32, color: kBorder),

              // Notes for responders
              const Text(
                'Important responder notes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kTextGrey,
                ),
              ),
              const SizedBox(height: 10),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  NoteChip(text: 'Wheelchair required'),
                  NoteChip(text: 'Ground-floor access'),
                  NoteChip(text: '2 senior residents'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- "Community updates" section ----------
  Widget buildUpdatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          label: 'LATEST ACTIVITY',
          title: 'Community updates',
          actionText: 'View all',
        ),
        const SizedBox(height: 12),
        const AppCard(
          child: Column(
            children: [
              UpdateRow(
                icon: Icons.warning_amber_rounded,
                bg: Color(0xFFFFF3DC),
                color: Color(0xFFE0A030),
                title: 'Flood advisory raised to Level 2',
                body:
                    'Water levels are rising near Pulangi River. Prepare essential items.',
              ),
              Divider(height: 28, color: kBorder),
              UpdateRow(
                icon: Icons.alt_route,
                bg: Color(0xFFE8F1FB),
                color: Color(0xFF3B82C4),
                title: 'Evacuation route is clear',
                body: 'Lumbo Elementary School route is open for residents.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- "Community status" map card ----------
  Widget buildCommunityStatus() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AROUND YOU', style: kSmallLabel),
                    SizedBox(height: 6),
                    Text(
                      'Community status',
                      style: TextStyle(fontSize: 22, color: kTextDark),
                    ),
                  ],
                ),
              ),
              IconBox(icon: Icons.map_outlined, bg: kLightGreen, size: 40),
            ],
          ),
          const SizedBox(height: 16),

          // A fake map: a colored box with labels and pins placed on it.
          // Alignment(x, y): (-1,-1) is top-left, (0,0) is center, (1,1) is bottom-right.
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EFEB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Stack(
              children: [
                Align(
                  alignment: Alignment(-0.4, -0.7),
                  child: Text('Purok 3', style: kGreyText),
                ),
                Align(
                  alignment: Alignment(0.7, 0.3),
                  child: Text('Purok 4', style: kGreyText),
                ),
                Align(
                  alignment: Alignment(0.7, -0.75),
                  child: Icon(Icons.location_on, color: Color(0xFF4DA37F)),
                ),
                Align(
                  alignment: Alignment(0.55, 0.5),
                  child: Icon(Icons.location_on, color: Color(0xFF4DA37F)),
                ),
                Align(
                  alignment: Alignment(-0.6, 0.45),
                  child: Icon(Icons.location_on, color: kRed),
                ),
                Align(
                  alignment: Alignment(-0.2, 0.8),
                  child: Text(
                    'Evacuation center',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kTextDark,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment(-0.05, -0.05),
                  child: Icon(Icons.home, size: 34, color: kGreen),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Three numbers under the map
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              StatItem(value: '12', label: 'Responders online'),
              StatItem(value: '3', label: 'Active requests'),
              StatItem(value: '1.2 km', label: 'Nearest center'),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Hotline card ----------
  Widget buildHotlineCard() {
    return AppCard(
      child: Column(
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBox(
                icon: Icons.phone_outlined,
                bg: Color(0xFFFDE9E5),
                color: kRed,
                size: 46,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EMERGENCY HOTLINE', style: kSmallLabel),
                    SizedBox(height: 6),
                    Text(
                      'Need to speak to someone?',
                      style: TextStyle(fontSize: 16, color: kTextDark),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Call the Valencia City response desk directly.',
                      style: kGreyText,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () {
                // TODO: later, open the phone dialer
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDE9E5),
                foregroundColor: kRed,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Call 911  >',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Small reusable building blocks
// ============================================================

// A white rounded box with a thin border. Every section card uses it.
class AppCard extends StatelessWidget {
  final Widget child;
  const AppCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: child,
    );
  }
}

// A small rounded square with an icon inside.
class IconBox extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color color;
  final double size;

  const IconBox({
    super.key,
    required this.icon,
    this.bg = Colors.white,
    this.color = kGreen,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: bg == Colors.white ? Border.all(color: kBorder) : null,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

// Small green label, big title, and a "link" on the right.
class SectionHeader extends StatelessWidget {
  final String label;
  final String title;
  final String actionText;

  const SectionHeader({
    super.key,
    required this.label,
    required this.title,
    required this.actionText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: kSmallLabel),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 22, color: kTextDark),
              ),
            ],
          ),
        ),
        Text(
          '$actionText  >',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kGreen,
          ),
        ),
      ],
    );
  }
}

// One row in the household card: colored icon, bold value, grey label.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color color;
  final String value;
  final String label;

  const InfoRow({
    super.key,
    required this.icon,
    required this.bg,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          IconBox(icon: icon, bg: bg, color: color, size: 40),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),
              Text(label, style: kGreyText),
            ],
          ),
        ],
      ),
    );
  }
}

// The grey rounded tags ("Wheelchair required", ...).
class NoteChip extends StatelessWidget {
  final String text;
  const NoteChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: kTextGrey,
        ),
      ),
    );
  }
}

// One item in "Community updates".
class UpdateRow extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color color;
  final String title;
  final String body;

  const UpdateRow({
    super.key,
    required this.icon,
    required this.bg,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBox(icon: icon, bg: bg, color: color, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 15, color: kTextDark),
              ),
              const SizedBox(height: 4),
              Text(body, style: kGreyText),
            ],
          ),
        ),
      ],
    );
  }
}

// A number with a small caption, used under the map.
class StatItem extends StatelessWidget {
  final String value;
  final String label;
  const StatItem({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: kTextDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: kTextGrey)),
      ],
    );
  }
}