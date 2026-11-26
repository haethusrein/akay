import 'package:flutter/material.dart';

import '../akay_backend.dart';
import '../create_account_screens.dart'
    show WelcomeScreen, showComingSoon;
import '../l10n/app_strings.dart';
import '../main.dart';
import 'edit_household_profile_screen.dart';
import 'screen_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
    } catch (error) {
      if (context.mounted) {
        showComingSoon(context, AkayBackend.friendlyError(error));
      }
    }
  }

  Future<void> _deactivate(BuildContext context) async {
    final sure = await confirmDialog(
      context,
      title: 'Deactivate this account?',
      message:
          'The account will be marked deleted and signed out. It will no longer be able to sign in.',
      confirmLabel: 'Deactivate account',
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
    } catch (error) {
      if (context.mounted) {
        showComingSoon(context, AkayBackend.friendlyError(error));
      }
    }
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AkayScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle(
            label: 'APP PREFERENCES',
            title: 'Settings',
            subtitle: 'Manage your household, language, and account.',
          ),
          const SizedBox(height: 20),
          _SettingsTile(
            icon: Icons.home_work_outlined,
            title: 'Edit household profile',
            subtitle: 'Update household details and responder notes',
            onTap: () => _openPage(
              context,
              const EditHouseholdProfileScreen(),
            ),
          ),
          _SettingsTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: 'Choose an available language',
            onTap: () => _openPage(
              context,
              const LanguageSettingsScreen(),
            ),
          ),
          _SettingsTile(
            icon: Icons.person_off_outlined,
            title: 'Deactivate account',
            subtitle: 'Mark this account as deleted and sign out',
            isDestructive: true,
            onTap: () => _deactivate(context),
          ),
          const SizedBox(height: 10),
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

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppStrings.current,
      builder: (context, selectedLanguage, _) {
        return AkayScreen(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenTitle(
                label: 'APP PREFERENCES',
                title: AppStrings.tr('language'),
                subtitle: 'Choose an available language.',
              ),
              const SizedBox(height: 16),
              AppCard(
                child: RadioGroup<AppLanguage>(
                  groupValue: selectedLanguage,
                  onChanged: (language) {
                    if (language != null) {
                      AppStrings.current.value = language;
                    }
                  },
                  child: Column(
                    children: [
                      for (final language in AppLanguage.values)
                        RadioListTile<AppLanguage>(
                          title: Text(language.label),
                          value: language,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDestructive ? kRed : kGreen;
    final iconBackground =
        isDestructive ? const Color(0xFFFDE9E5) : kLightGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                IconBox(
                  icon: icon,
                  bg: iconBackground,
                  color: iconColor,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDestructive ? kRed : kTextDark,
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