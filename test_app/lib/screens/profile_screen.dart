import 'package:flutter/material.dart';
import '../akay_backend.dart';
import '../create_account_screens.dart'; // WelcomeScreen, VerifyCodeScreen, showComingSoon
import '../main.dart';
import 'admin_only.dart';
import 'akay_nav.dart';
import 'checkin_screen.dart';
import 'emergency_info_screen.dart';
import 'evacuation_status_screen.dart';
import 'nearby_sos_screens.dart';
import 'responder_list_screen.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Profile tab
// The Figma export has no Profile design yet, so this is a simple version
// in the same style: account details + verification + Log out.
//
// Backend used: AkayBackend.myProfile(), AkayBackend.signOut()
// ============================================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logOut(BuildContext context) async {
    final sure = await confirmDialog(
      context,
      title: 'Log out of AKAY?',
      message: 'You will need your mobile number and password to log in again.',
      confirmLabel: 'Log out',
      cancelLabel: 'Stay logged in',
    );
    if (!sure || !context.mounted) return;
    try {
      await AkayBackend.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (context.mounted) showComingSoon(context, AkayBackend.friendlyError(e));
    }
  }

    Future<void> _deactivateAccount(BuildContext context) async {
    final passwordController = TextEditingController();

    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate AKAY account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You will no longer be able to sign in to this account. '
              'Your Firebase account and stored data will remain.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm your password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              passwordController.text,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    passwordController.dispose();
    if (password == null || password.isEmpty || !context.mounted) return;

    try {
      await AkayBackend.deactivateAccount(password: password);
      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (error) {
      if (context.mounted) {
        showComingSoon(context, AkayBackend.friendlyError(error));
      }
    }
  }

  void _openVerification(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VerifyCodeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TabScaffold(
      index: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle(
            label: 'YOUR ACCOUNT',
            title: 'Profile',
            subtitle: 'Your details and verification status.',
          ),
          const SizedBox(height: 20),
          StreamBuilder(
            stream: AkayBackend.myProfile(),
            builder: (context, snapshot) {
              final p = snapshot.data?.data();
              final mobile = (p?['mobile'] ?? '-').toString();
              final role = p?['role'] == 'respondent' ? 'Respondent' : 'Resident';
              final verified = p?['verified'] == true;

              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                                  fontWeight: FontWeight.w500,
                                  color: kTextDark,
                                ),
                              ),
                              const SizedBox(height: 2),
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
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder(
            stream: AkayBackend.myProfile(),
            builder: (context, snapshot) {
              final profile = snapshot.data?.data();
              if (profile == null || profile['verified'] == true) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppCard(
                    child: Text(
                      'Some account features require verification. '
                      'Enter your verification code to unlock responder tools.',
                      style: kGreyText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlineAction(
                    label: 'Enter verification code',
                    icon: Icons.verified_user_outlined,
                    onPressed: () => _openVerification(context),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
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
            subtitle: 'Works offline',
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
            subtitle: 'What a neighbour sees when holding an SOS',
            page: RelayPhoneScreen(),
          ),
          // Responder tools require both the responder role and verification.
          StreamBuilder(
            stream: AkayBackend.myProfile(),
            builder: (context, snapshot) {
              final profile = snapshot.data?.data();
              final isVerifiedResponder =
                  profile?['role'] == 'respondent' &&
                  profile?['verified'] == true;

              if (!isVerifiedResponder) return const SizedBox.shrink();

              return const Column(
                children: [
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
          // Admin tools: shown only to the admin account (mobile 00000000).
          StreamBuilder(
            stream: AkayBackend.myProfile(),
            builder: (context, snapshot) {
              if (!AkayBackend.isAdminProfile(snapshot.data?.data())) {
                return const SizedBox.shrink();
              }
              return const _ToolTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin',
                subtitle: 'Pins, accounts, 911 calls, error log',
                page: AdminOnlyScreen(),
              );
            },
          ),
          const SizedBox(height: 20),
          OutlineAction(
            label: 'Log out',
            icon: Icons.logout,
            onPressed: () => _logOut(context),
          ),
                    const SizedBox(height: 10),
          OutlineAction(
            label: 'Deactivate account',
            icon: Icons.person_off_outlined,
            onPressed: () => _deactivateAccount(context),
          ),
        ],
      ),
    );
  }
}

// One tappable row that opens another screen.
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