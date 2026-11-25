import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'create_account_screens.dart';
import 'akay_backend.dart';
import 'firebase_options.dart';
import 'screens/akay_nav.dart';
import 'screens/request_help_sheet.dart';
import 'screens/responder_list_screen.dart';
import 'l10n/app_strings.dart';

// ============================================================
// AKAY - Home screen
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AkayApp());
}

// ---------- Colors ----------

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
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppStrings.current,
      builder: (context, _, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'AKAY',
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: kGreen,
            scaffoldBackgroundColor: kBackground,
          ),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator(color: kGreen)),
                );
              }

              if (snapshot.hasData) {
                return StreamBuilder(
                  stream: AkayBackend.myProfile(),
                  builder: (context, profileSnap) {
                    if (profileSnap.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(
                          child: CircularProgressIndicator(color: kGreen),
                        ),
                      );
                    }
                    final isRespondent =
                        profileSnap.data?.data()?['role'] == 'respondent';
                    return isRespondent
                        ? const ResponderListScreen()
                        : const HomeScreen();
                  },
                );
              }

              return const WelcomeScreen();
            },
          ),
        );
      },
    );
  }
}

// ============================================================
// Home screen
// ============================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabScaffold(
      index: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildEmergencyCard(context),
          const SizedBox(height: 28),
          buildHouseholdSection(),
          const SizedBox(height: 28),
          buildUpdatesSection(),
          const SizedBox(height: 20),
          buildCommunityStatus(),
          const SizedBox(height: 16),
          buildHotlineCard(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

Widget buildEmergencyCard(BuildContext context) {
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
            onPressed: () => showRequestHelpSheet(context),
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

// ---------- Household section ----------

Widget buildHouseholdSection() {
  return StreamBuilder(
    stream: AkayBackend.myHousehold(),
    builder: (context, householdSnapshot) {
      if (householdSnapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      final household = householdSnapshot.data?.data();

      if (household == null) {
        return const AppCard(
          child: Text(
            'No household profile found. Please complete your household setup.',
          ),
        );
      }

      return StreamBuilder(
        stream: AkayBackend.myProfile(),
        builder: (context, profileSnapshot) {
          final verified = profileSnapshot.data?.data()?['verified'] == true;

          final members = household['members'] ?? 0;
          final mobilityNeed = household['mobilityNeed'] ?? 'None';

          final notes = List<String>.from(household['notes'] ?? []);

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
                    Row(
                      children: [
                        const IconBox(
                          icon: Icons.home_outlined,
                          bg: kLightGreen,
                          size: 46,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                household['name'] ?? 'My Household',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: kTextDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: kTextGrey,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      household['address'] ??
                                          household['barangay'] ??
                                          '',
                                      style: kGreyText,
                                    ),
                                  ),
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
                            color: verified
                                ? kLightGreen
                                : const Color(0xFFFFF3DC),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            verified ? 'Verified' : 'Unverified',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: verified
                                  ? kGreen
                                  : const Color(0xFFE0A030),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32, color: kBorder),
                    InfoRow(
                      icon: Icons.people_outline,
                      bg: const Color(0xFFE8F1FB),
                      color: const Color(0xFF3B82C4),
                      value: '$members',
                      label: 'members',
                    ),
                    InfoRow(
                      icon: Icons.accessible,
                      bg: const Color(0xFFFFF3DC),
                      color: const Color(0xFFE0A030),
                      value: '$mobilityNeed',
                      label: 'mobility need',
                    ),
                    const Divider(height: 32, color: kBorder),
                    const Text(
                      'Important responder notes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: kTextGrey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: notes.isEmpty
                          ? [const NoteChip(text: 'No additional notes')]
                          : notes.map((note) => NoteChip(text: note)).toList(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

// ---------- Community updates ----------

Widget buildUpdatesSection() {
  return StreamBuilder(
    stream: AkayBackend.communityUpdates(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (snapshot.hasError) {
        return AppCard(child: Text(AkayBackend.friendlyError(snapshot.error!)));
      }

      final updates = snapshot.data?.docs ?? [];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            label: 'LATEST ACTIVITY',
            title: 'Community updates',
            actionText: 'View all',
          ),
          const SizedBox(height: 12),
          AppCard(
            child: updates.isEmpty
                ? const Text(
                    'No community updates available yet.',
                    style: kGreyText,
                  )
                : Column(
                    children: [
                      for (int i = 0; i < updates.length; i++) ...[
                        UpdateRow(
                          icon: Icons.campaign_outlined,
                          bg: kLightGreen,
                          color: kGreen,
                          title:
                              updates[i].data()['title']?.toString() ??
                              'Community update',
                          body: updates[i].data()['body']?.toString() ?? '',
                        ),
                        if (i != updates.length - 1)
                          const Divider(height: 28, color: kBorder),
                      ],
                    ],
                  ),
          ),
        ],
      );
    },
  );
}

// ---------- Live community status ----------

Widget buildCommunityStatus() {
  return const CommunityStatusCard();
}

// ---------- Hotline ----------

  Widget buildHotlineCard(BuildContext context) {
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
                    Text('EMERGENCY CONTACT', style: kSmallLabel),
                    SizedBox(height: 6),
                    Text(
                      'Need to speak to someone?',
                      style: TextStyle(fontSize: 16, color: kTextDark),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Call your assigned responder, or the AKAY response desk.',
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
              onPressed: () async {
                try {
                  final responderPhone =
                      await AkayBackend.assignedResponderPhone();
                  final phone =
                      responderPhone ?? await AkayBackend.demoAdminPhone();

                  final opened = await launchUrl(
                    Uri(scheme: 'tel', path: phone),
                  );

                  if (!opened && context.mounted) {
                    showComingSoon(
                      context,
                      'Could not open the phone dialer. Please try again.',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showComingSoon(
                      context,
                      AkayBackend.friendlyError(e),
                    );
                  }
                }
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
                'Call responder / desk  >',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ============================================================
// LIVE COMMUNITY STATUS CARD
// ============================================================

class CommunityStatusCard extends StatefulWidget {
  const CommunityStatusCard({super.key});

  @override
  State<CommunityStatusCard> createState() => _CommunityStatusCardState();
}

class _CommunityStatusCardState extends State<CommunityStatusCard> {
  late Future<Map<String, dynamic>> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatus();
  }

  Future<Map<String, dynamic>> _loadStatus() async {
    final position = await AkayBackend.currentPosition();

    return AkayBackend.communityStatus(position.latitude, position.longitude);
  }

  void _retry() {
    setState(() {
      _statusFuture = _loadStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _statusFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Column(
              children: [
                Row(
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
                    IconBox(
                      icon: Icons.map_outlined,
                      bg: kLightGreen,
                      size: 40,
                    ),
                  ],
                ),
                SizedBox(height: 24),
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Loading nearby community data...', style: kGreyText),
              ],
            );
          }

          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AROUND YOU', style: kSmallLabel),
                const SizedBox(height: 6),
                const Text(
                  'Community status',
                  style: TextStyle(fontSize: 22, color: kTextDark),
                ),
                const SizedBox(height: 12),
                Text(
                  AkayBackend.friendlyError(snapshot.error!),
                  style: kGreyText,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ),
              ],
            );
          }

          final data = snapshot.data!;

          final responders = data['respondersOnline'] ?? 0;
          final requests = data['activeRequests'] ?? 0;

          final nearest = data['nearestCenter'] as Map<String, dynamic>?;

          final centerName = nearest?['name']?.toString() ?? 'No center found';

          final distance = nearest?['distanceKm'];

          return Column(
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
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _statusItem(
                      Icons.groups,
                      responders.toString(),
                      'Responders online',
                    ),
                  ),
                  Expanded(
                    child: _statusItem(
                      Icons.warning_amber_rounded,
                      requests.toString(),
                      'Active requests',
                    ),
                  ),
                ],
              ),
              const Divider(height: 32, color: kBorder),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: kRed, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nearest evacuation center',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: kTextDark,
                          ),
                        ),
                        Text(centerName, style: kGreyText),
                      ],
                    ),
                  ),
                  Text(
                    distance is num
                        ? '${distance.toStringAsFixed(1)} km'
                        : '--',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: kGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 28, color: kGreen),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: kTextDark,
          ),
        ),
        Text(label, textAlign: TextAlign.center, style: kGreyText),
      ],
    );
  }
}

// ============================================================
// Reusable building blocks
// ============================================================

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
