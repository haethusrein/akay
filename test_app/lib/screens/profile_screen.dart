import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'; // WelcomeScreen, showComingSoon
import '../main.dart';
import 'akay_nav.dart';
import 'screen_widgets.dart';

// ============================================================
// AKAY - Profile tab
// The Figma export has no Profile design yet, so this is a simple version
// in the same style: account details + Log out.
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: verified ? kLightGreen : const Color(0xFFFFF3DC),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                verified ? Icons.check : Icons.schedule,
                                size: 14,
                                color: verified ? kGreen : const Color(0xFF7A5A12),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                verified ? 'Verified' : 'Not verified',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: verified ? kGreen : const Color(0xFF7A5A12),
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
          const SizedBox(height: 20),
          OutlineAction(
            label: 'Log out',
            icon: Icons.logout,
            onPressed: () => _logOut(context),
          ),
        ],
      ),
    );
  }
}
