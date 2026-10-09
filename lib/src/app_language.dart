import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { system, english, spanish }

class LanguageSettings {
  static const _key = 'app_language';
  static final selection = ValueNotifier<AppLanguage>(AppLanguage.system);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    selection.value = AppLanguage.values.firstWhere(
      (value) => value.name == prefs.getString(_key),
      orElse: () => AppLanguage.system,
    );
  }

  static Future<void> set(AppLanguage value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
    selection.value = value;
    try {
      await const MethodChannel(
        'floating_volume/settings',
      ).invokeMethod<void>('refreshLanguage');
    } on MissingPluginException {
      // Native settings are unavailable in widget tests.
    } on PlatformException {
      // The selection is saved even if the service is temporarily unavailable.
    }
  }

  static bool get isSpanish {
    final language = selection.value;
    if (language == AppLanguage.spanish) return true;
    if (language == AppLanguage.english) return false;
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    return locales.isNotEmpty && locales.first.languageCode == 'es';
  }

  static String translate(String english, String spanish) =>
      isSpanish ? spanish : english;
}

String tr(String english, String spanish) =>
    LanguageSettings.translate(english, spanish);
