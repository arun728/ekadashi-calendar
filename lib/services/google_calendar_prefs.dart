import 'package:shared_preferences/shared_preferences.dart';

class GoogleCalendarPrefs {
  static const _key = 'google_sync_calendar_ids';

  static Future<List<String>> loadSelectedIds(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_key:$accountId') ?? ['primary'];
  }

  static Future<void> saveSelectedIds(
    String accountId,
    List<String> ids,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_key:$accountId', ids);
  }

  static Future<void> clear(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_key:$accountId');
  }
}
