import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/ekadashi_lifecycle.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_schedule.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/widget_sync_manager.dart';
import 'package:ekadashi_calendar/l10n/app_language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'same seeded 20 city sample as iOS, both traditions, two years, every language',
    () async {
      tzdata.initializeTimeZones();
      SharedPreferences.setMockInitialValues({});
      EkadashiSchedule.calculateInline = true;
      final rows =
          (jsonDecode(
                    File(
                      'test/fixtures/ekadashi_lifecycle_world_sample.json',
                    ).readAsStringSync(),
                  )
                  as List)
              .cast<Map<String, dynamic>>();
      expect(rows.length, 20);
      expect(rows.map((r) => r['timezone']).toSet().length, 20);
      var total = 0;
      for (final row in rows) {
        final city = PanchangCity(
          id: row['id'],
          label: row['label'],
          latitude: (row['latitude'] as num).toDouble(),
          longitude: (row['longitude'] as num).toDouble(),
          timeZoneId: row['timezone'],
        );
        for (final tradition in EkadashiTradition.values) {
          final events = await EkadashiService().engineEkadashis(
            city: city,
            tradition: tradition,
            languageCode: 'en',
            years: [2026, 2027],
          );
          total += events.length;
          for (final language in AppLanguage.codes) {
            final labels = LanguageService();
            await labels.changeLanguage(language);
            final payload = WidgetSyncManager().buildPayload(
              ekadashiList: events,
              timezone: city.timeZoneId,
              locationName: city.label,
              languageService: labels,
              now: DateTime(2025),
            );
            expect((payload['schedule'] as List).length, 49);
            for (final (index, event) in events.indexed) {
              final start = DateTime.parse(event.fastingStartIso),
                  parana = DateTime.parse(event.paranaStartIso),
                  end = DateTime.parse(event.paranaEndIso);
              final note =
                  '${city.label} ${city.timeZoneId} ${tradition.name} $language ${event.date}';
              expect(
                EkadashiLifecycle.of(
                  event,
                  start.subtract(const Duration(seconds: 1)),
                  city.timeZoneId,
                ).countdown,
                '00:00:01',
                reason: note,
              );
              expect(
                EkadashiLifecycle.of(event, start, city.timeZoneId).percent,
                0,
                reason: note,
              );
              expect(
                EkadashiLifecycle.of(
                  event,
                  start.add(
                    Duration(
                      microseconds:
                          parana.difference(start).inMicroseconds ~/ 2,
                    ),
                  ),
                  city.timeZoneId,
                ).percent,
                50,
                reason: note,
              );
              if (end.isAfter(parana)) {
                final s = EkadashiLifecycle.of(event, parana, city.timeZoneId);
                expect(s.phase, EkadashiPhase.parana, reason: note);
                expect(s.percent, 100, reason: note);
                if (language != 'en') {
                  expect(
                    RegExp('[A-Za-z]').hasMatch(s.label(language)),
                    false,
                    reason: note,
                  );
                }
              }
              expect(
                EkadashiLifecycle.currentIndex(
                  events,
                  end.subtract(const Duration(seconds: 1)),
                  city.timeZoneId,
                ),
                index,
                reason: note,
              );
              expect(
                EkadashiLifecycle.currentIndex(events, end, city.timeZoneId),
                (index + 1).clamp(0, events.length - 1),
                reason: note,
              );
              final date = EkadashiLifecycle.localDay(parana, city.timeZoneId),
                  day = EkadashiCalendarDay(events, date, city.timeZoneId);
              expect(
                day.parana.any((e) => e.occurrenceUid == event.occurrenceUid),
                true,
                reason: note,
              );
              expect(day.showsFastingMarker, false, reason: note);
            }
          }
          debugPrint(
            'WORLD SAMPLE: ${city.label}, ${city.timeZoneId}, ${tradition.name}, ${events.length} occurrences',
          );
        }
      }
      expect(total, 1960);
      debugPrint(
        'WORLD SAMPLE TOTAL: 20 cities, 20 zones, 1960 occurrences, six languages',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
