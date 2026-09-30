import 'package:shared_preferences/shared_preferences.dart';

class GoogleCalendarPrefs {
  static const _key = 'google_sync_calendar_ids';

  static Future<List<String>> loadSelectedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? ['primary'];
  }

  static Future<void> saveSelectedIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids);
  }
}
