import 'package:flutter/foundation.dart';

enum AppLanguage {
  english('English'),
  bisaya('Bisaya'),
  filipino('Filipino (Tagalog)');

  final String label;
  const AppLanguage(this.label);
}

class AppStrings {
  // Defaults to English
  static final ValueNotifier<AppLanguage> current =
      ValueNotifier<AppLanguage>(AppLanguage.english);

  static const Map<String, Map<AppLanguage, String>> _values = {
    'settings': {
      AppLanguage.english: 'Settings',
      AppLanguage.bisaya: 'Mga Setting',
      AppLanguage.filipino: 'Mga Setting',
    },
    'language': {
      AppLanguage.english: 'Language',
      AppLanguage.bisaya: 'Pinulongan',
      AppLanguage.filipino: 'Wika',
    },
    'edit_household_profile': {
      AppLanguage.english: 'Edit Household Profile',
      AppLanguage.bisaya: 'Usba ang Profile sa Panimalay',
      AppLanguage.filipino: 'I-edit ang Profile ng Sambahayan',
    },
    'save_changes': {
      AppLanguage.english: 'Save Changes',
      AppLanguage.bisaya: 'I-save ang mga Kausaban',
      AppLanguage.filipino: 'I-save ang mga Pagbabago',
    },
    'community': {
      AppLanguage.english: 'Community',
      AppLanguage.bisaya: 'Komunidad',
      AppLanguage.filipino: 'Komunidad',
    },
    'profile': {
      AppLanguage.english: 'Profile',
      AppLanguage.bisaya: 'Profile',
      AppLanguage.filipino: 'Profile',
    },
    'help_request': {
      AppLanguage.english: 'Request Help',
      AppLanguage.bisaya: 'Mangayo og Tabang',
      AppLanguage.filipino: 'Humingi ng Tulong',
    },
  };

  static String tr(String key) {
    return _values[key]?[current.value] ??
        _values[key]?[AppLanguage.english] ??
        key;
  }
}