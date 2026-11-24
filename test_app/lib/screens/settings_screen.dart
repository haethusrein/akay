import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppStrings.current,
      builder: (context, selectedLang, _) {
        return Scaffold(
          appBar: AppBar(title: Text(AppStrings.tr('settings'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                AppStrings.tr('language'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...AppLanguage.values.map(
                (lang) => RadioListTile<AppLanguage>(
                  title: Text(lang.label),
                  value: lang,
                  groupValue: selectedLang,
                  onChanged: (value) {
                    if (value != null) {
                      AppStrings.current.value = value;
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}