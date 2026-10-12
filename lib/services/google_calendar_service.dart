import '../data/calendar_entry_repository.dart';
import 'notifications/event_reminder_service.dart';
import '../models/calendar_entry.dart';
import 'google_event_mapper.dart';
import 'google_calendar_prefs.dart';

class GoogleCalendarInfo {
  final String id;
  final String summary;
  final bool primary;
  final bool selected;

  const GoogleCalendarInfo({
    required this.id,
    required this.summary,
    this.primary = false,
    this.selected = true,
  });
}

/// Minimal auth + Calendar API surface used by the app.
abstract class GoogleAuthGateway {
  Future<String?> accountId();
  Future<bool> isSignedIn();
  Future<bool> signIn();
  Future<void> signOut();

  /// The signed-in account's Google ID token (for the free-sync registry),
  /// or null when unavailable.
  Future<String?> idToken();

  /// The signed-in account's email, shown so the user knows which Google
  /// account is being imported (null when unknown).
  Future<String?> accountEmail() async => null;
  Future<List<GoogleCalendarInfo>> listCalendars();
  Future<List<Map<String, dynamic>>> fetchEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    required List<String> calendarIds,
  });
}

class GoogleCalendarService {
  GoogleCalendarService({required this.auth, required this.repository});

  final GoogleAuthGateway auth;
  final CalendarEntryRepository repository;
  int _revision = 0;

  Future<bool> isSignedIn() => auth.isSignedIn();
  Future<bool> signIn() => auth.signIn();
  Future<void> signOut() async {
    _revision++;
    final account = await auth.accountId();
    await auth.signOut();
    if (account != null) {
      await repository.clearGoogleEntries(accountId: account);
      await GoogleCalendarPrefs.clear(account);
      EventReminderService.instance.changed();
    }
  }

  Future<List<GoogleCalendarInfo>> listCalendars() => auth.listCalendars();

  /// Import events from [calendarIds] in [timeMin, timeMax).
  Future<int> syncImport({
    required DateTime timeMin,
    required DateTime timeMax,
    required List<String> calendarIds,
  }) async {
    final revision = ++_revision;
    if (!timeMax.isAfter(timeMin)) throw ArgumentError("Invalid import window");
    final signedIn = await auth.isSignedIn() || await auth.signIn();
    if (!signedIn) return 0;
    if (calendarIds.isEmpty) return 0;

    final account = await auth.accountId();
    if (account == null) throw StateError("No Google account");
    final raw = await auth.fetchEvents(
      timeMin: timeMin,
      timeMax: timeMax,
      calendarIds: calendarIds,
    );
    final entries = <CalendarEntry>[];
    for (final e in raw) {
      final mapped = GoogleEventMapper.fromApiEvent({
        ...e,
        'accountId': account,
      });
      if (mapped != null) entries.add(mapped);
    }
    if (revision != _revision || await auth.accountId() != account) {
      throw StateError('Google account or import changed during sync');
    }
    await repository.replaceGoogleWindow(
      accountId: account,
      calendarIds: calendarIds,
      timeMin: timeMin,
      timeMax: timeMax,
      entries: entries,
    );
    EventReminderService.instance.changed();
    return entries.length;
  }
}
