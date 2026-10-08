import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 3 festivals (docs/ROADMAP.md), the same published New Delhi dates
/// as the iOS FestivalRuleTests (sources in docs/PANCHANG_VALIDATION.md).
void main() {
  final engine = PanchangEngine();
  final calendars = <int, List<DatedObservance>>{};
  List<DatedObservance> calendar(int year) => calendars[year] ??= engine
      .observanceCalendar(year, city: PanchangCity.newDelhi);
  List<String> dates(String id, int year) => [
    for (final dated in calendar(year))
      if (dated.observance.id == id)
        dated.date.toIso8601String().substring(0, 10),
  ];

  const newFestivals = [
    'raksha-bandhan',
    'nag-panchami',
    'ratha-yatra',
    'durga-ashtami',
    'varalakshmi-vratam',
    'onam',
    'karthigai-deepam',
  ];

  test('new festivals fall on the published dates', () {
    const expected = [
      ('raksha-bandhan', '2026-08-28'),
      ('raksha-bandhan', '2027-08-17'),
      ('nag-panchami', '2026-08-17'),
      ('nag-panchami', '2027-08-06'),
      ('onam', '2026-08-26'),
      ('onam', '2027-09-12'),
      ('ratha-yatra', '2026-07-16'),
      ('ratha-yatra', '2027-07-05'),
      ('durga-ashtami', '2026-10-19'),
      ('durga-ashtami', '2027-10-07'),
      ('karthigai-deepam', '2026-11-24'),
      ('varalakshmi-vratam', '2026-08-28'),
      ('varalakshmi-vratam', '2027-08-13'),
    ];
    for (final (id, date) in expected) {
      expect(dates(id, int.parse(date.substring(0, 4))), [date], reason: id);
    }
  });

  test('each new festival happens once a year and is major', () {
    for (final id in newFestivals) {
      for (final year in const [2026, 2027]) {
        expect(dates(id, year), hasLength(1), reason: '$id $year');
      }
      expect(
        calendar(
          2026,
        ).firstWhere((d) => d.observance.id == id).observance.isMajor,
        isTrue,
        reason: id,
      );
    }
  });

  test('observancesOn matches calculate() on sample days', () {
    for (final city in [PanchangCity.newDelhi, PanchangCity.chennai]) {
      for (
        var day = DateTime.utc(2026, 8, 10);
        day.isBefore(DateTime.utc(2026, 9, 5));
        day = day.add(const Duration(days: 1))
      ) {
        expect(
          engine.observancesOn(day, city: city).map((o) => o.id).toList(),
          engine
              .calculate(day, city: city)
              .observances
              .map((o) => o.id)
              .toList(),
          reason: '${city.id} $day',
        );
      }
    }
  });
}
