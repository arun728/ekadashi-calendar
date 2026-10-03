import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/localized_lookup.dart';

class LanguageService extends ChangeNotifier {
  Locale _currentLocale = const Locale('en');
  Map<String, String>? _strings;
  Locale get currentLocale => _currentLocale;
  LanguageService() {
    // Date symbols are registered synchronously by the local-data loader.
    initializeDateFormatting();
    _loadLanguage();
  }
  Map<String, String> get localizedStrings =>
      _strings ??= localizedLookup(lookupAppLocalizations(_currentLocale));
  String translate(String key) => localizedStrings[key] ?? key;
  String translateWithArgs(String key, List<String> args) {
    var text = translate(key);
    for (final arg in args) {
      text = text.replaceFirst('{}', arg);
    }
    return text;
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('language_code');
    if (code != null &&
        AppLocalizations.supportedLocales.contains(Locale(code))) {
      _currentLocale = Locale(code);
      _strings = null;
      notifyListeners();
    }
  }

  Future<void> changeLanguage(String code) async {
    if (!AppLocalizations.supportedLocales.contains(Locale(code))) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
    _currentLocale = Locale(code);
    _strings = null;
    notifyListeners();
  }
}
