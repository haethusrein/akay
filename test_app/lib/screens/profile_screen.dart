import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../main.dart';
import 'admin_only.dart';
import 'akay_nav.dart';
import 'checkin_screen.dart';
import 'emergency_info_screen.dart';
import 'evacuation_status_screen.dart';
import 'nearby_sos_screens.dart';
import 'responder_list_screen.dart';
import 'screen_widgets.dart';
import 'settings_screen.dart';

// ============================================================
// AKAY - Profile tab
// The account summary and safety tools remain here.
// General account/app settings are accessed through the Settings button.
// ============================================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabScaffold(
      index: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle(
            label: 'ACCOUNT',
            title: 'Profile',
            subtitle: 'View your account and access your safety tools.',
          ),
          const SizedBox(height: 20),
          StreamBuilder(
            stream: AkayBackend.myProfile(),
            builder: (context, snapshot) {
              final profile = snapshot.data?.data();
              final mobile = (profile?['mobile'] ?? '-').toString();
              final role = profile?['role'] == 'respondent'
                  ? 'Respondent'
                  : 'Resident';
              final verified = profile?['verified'] == true;

              return AppCard(
                child: Row(
                  children: [
                    const IconBox(
                      icon: Icons.person_outline,
                      bg: kLightGreen,
                      size: 46,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mobile,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: kTextDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(role, style: kGreyText),
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
                      child: Row(
                        children: [
                          Icon(
                            verified ? Icons.check : Icons.schedule,
                            size: 14,
                            color: verified
                                ? kGreen
                                : const Color(0xFF7A5A12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            verified ? 'Verified' : 'Not verified',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: verified
                                  ? kGreen
                                  : const Color(0xFF7A5A12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          const _ToolTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Household, language, and account settings',
            page: SettingsScreen(),
          ),
          const SizedBox(height: 14),
          const Text('SAFETY TOOLS', style: kSmallLabel),
          const SizedBox(height: 10),
          const _ToolTile(
            icon: Icons.alt_route,
            title: 'Update evacuation status',
            subtitle: 'Still here, in transit, or evacuated',
            page: EvacuationStatusScreen(),
          ),
          const _ToolTile(
            icon: Icons.info_outline,
            title: 'Emergency information',
            subtitle: 'Your personal emergency details',
            page: EmergencyInfoScreen(),
          ),
          const _ToolTile(
            icon: Icons.bluetooth,
            title: 'Nearby SOS (Bluetooth)',
            subtitle: 'Share your request with nearby phones',
            page: NearbySosScreen(),
          ),
          const _ToolTile(
            icon: Icons.sync_alt,
            title: 'Relay phone preview',
            subtitle: 'View SOS requests received nearby',
            page: RelayPhoneScreen(),
          ),
          StreamBuilder(
            stream: AkayBackend.myProfile(),
            builder: (context, snapshot) {
              final isResponder =
                  snapshot.data?.data()?['role'] == 'respondent';
              if (!isResponder && !kShowSampleData) {
                return const SizedBox.shrink();
              }

              return const Column(
                children: [
                  SizedBox(height: 10),
                  _ToolTile(
                    icon: Icons.groups_outlined,
                    title: 'Responder dashboard',
                    subtitle: 'Households needing help',
                    page: ResponderListScreen(),
                  ),
                  _ToolTile(
                    icon: Icons.fact_check_outlined,
                    title: 'Evacuation-center check-in',
                    subtitle: 'Confirm a household arrived',
                    page: CheckInScreen(),
                  ),
                ],
              );
            },
          ),
          StreamBuilder(
            stream: AkayBackend.myProfile(),
            builder: (context, snapshot) {
              if (!AkayBackend.isAdminProfile(snapshot.data?.data())) {
                return const SizedBox.shrink();
              }

              return const _ToolTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin',
                subtitle: 'Pins, accounts, calls, and error log',
                page: AdminOnlyScreen(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// A tappable row that opens another screen.
class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => page),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                IconBox(icon: icon, bg: kLightGreen, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: kGreyText),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: kTextDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}