import 'package:flutter/material.dart';
import '../akay_backend.dart';
import '../create_account_screens.dart'; // WelcomeScreen, VerifyCodeScreen, showComingSoon
import '../main.dart';
import 'admin_only.dart';
import 'akay_nav.dart';
import 'checkin_screen.dart';
import 'responder_list_screen.dart';
import 'screen_widgets.dart';
import 'edit_household_profile_screen.dart';
import 'settings_screen.dart';
import '../l10n/app_strings.dart';

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
  final sure = await confirmDialog(
    context,
    title: 'Deactivate your account?',
    message:
        'You will be signed out and will not be able to sign in again. '
        'Your Firebase account will remain in the project.',
    confirmLabel: 'Deactivate',
    cancelLabel: 'Keep account',
  );

  if (!sure || !context.mounted) return;

  try {
    await AkayBackend.deactivateAccount();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  } catch (e) {
    if (context.mounted) {
      showComingSoon(context, AkayBackend.friendlyError(e));
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
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(AppStrings.tr('edit_household_profile')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EditHouseholdProfileScreen(
                              currentData: p ?? {},
                            ),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.settings_outlined),
                      title: Text(AppStrings.tr('settings')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
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
                  ToolTile(
                    icon: Icons.groups_outlined,
                    title: 'Responder dashboard',
                    subtitle: 'Households needing help',
                    page: ResponderListScreen(),
                  ),
                  ToolTile(
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
              return const ToolTile(
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