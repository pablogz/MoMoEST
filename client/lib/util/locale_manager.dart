import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

class LocaleManager {
  static const String langKey = 'lang_override';
  static final List<String> supportedLangs = ['es', 'en', 'pt', 'it'];

  static String _currentLang = _resolveDeviceLang();

  static String get currentLang => _currentLang;

  // Callback registrado por MyApp para aplicar el cambio de locale en caliente.
  static void Function(String?)? _onLocaleChanged;

  static void registerCallback(void Function(String?) callback) {
    _onLocaleChanged = callback;
  }

  static void applyLocale(String? lang) {
    _currentLang = lang ?? _resolveDeviceLang();
    _onLocaleChanged?.call(lang);
  }

  static Future<String?> getSavedLang() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(langKey);
  }

  static Future<void> saveLang(String? lang) async {
    final prefs = await SharedPreferences.getInstance();
    if (lang == null) {
      await prefs.remove(langKey);
    } else {
      await prefs.setString(langKey, lang);
    }
  }

  static Locale? localeFromLang(String? lang) {
    if (lang == null) return null;
    switch (lang) {
      case 'es':
        return const Locale('es', 'ES');
      case 'pt':
        return const Locale('pt', 'PT');
      case 'it':
        return const Locale('it', 'IT');
      default:
        return const Locale('en', 'US');
    }
  }

  // Actualiza currentLang al arrancar, una vez leída la preferencia guardada.
  static void setCurrentLang(String? lang) {
    _currentLang = lang ?? _resolveDeviceLang();
  }

  static String getDeviceLang() => _resolveDeviceLang();

  static String _resolveDeviceLang() {
    String lang = Platform.localeName;
    if (lang.contains("_")) {
      lang = lang.split("_")[0];
    } else if (lang.contains("-")) {
      lang = lang.split("-")[0];
    }
    return supportedLangs.contains(lang) ? lang : 'en';
  }
}
