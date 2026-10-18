import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/journey_rewards.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
import 'package:ekadashi_calendar/l10n/app_language.dart';

final journeyNow = DateTime.utc(2028, 1, 2, 12);
List<EkadashiDate> journeyEvents(int year, {bool extra = false}) => [
  for (var i = 0; i < (extra ? 25 : 24); i++)
    EkadashiDate(
      id: year * 1000 + i + 1,
      occurrenceUid: 'ekadashi:$year:${(i + 1).toString().padLeft(2, '0')}',
      name: 'E',
      date: DateTime(
        year,
        i == 24 ? 12 : i ~/ 2 + 1,
        i == 24
            ? 23
            : i.isEven
            ? 3
            : 18,
      ),
      fastStartTime: '',
      fastBreakTime: '',
      description: '',
    ),
];
VratHistory journeyRecord(
  EkadashiDate e, [
  ObservanceStatus status = ObservanceStatus.observed,
]) => VratHistory(
  id: e.occurrenceUid,
  ekadashiOccurrenceId: e.id,
  occurrenceUid: e.occurrenceUid,
  ekadashiDate: e.date.toIso8601String().substring(0, 10),
  ekadashiName: e.name,
  status: status,
  recordedAtUTC: '2028-01-01T00:00:00Z',
  updatedAtUTC: '2028-01-01T00:00:00Z',
);
JourneySummary summary(
  List<EkadashiDate> es,
  List<VratHistory> rows, {
  Set<int> complete = const {2026, 2027},
  DateTime? now,
}) => JourneyRewards.calculate(
  occurrences: es,
  history: rows,
  completeYears: complete,
  now: now ?? journeyNow,
  timezone: 'Asia/Kolkata',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'status points, future exclusion and derived lifetime points match Swift',
    () {
      final es = journeyEvents(2027);
      final s = summary(es, [
        journeyRecord(es[0]),
        journeyRecord(es[1], ObservanceStatus.partial),
        journeyRecord(es[2], ObservanceStatus.missed),
      ]);
      expect(s.year(2027).points, 150);
      expect(s.lifetimePoints, 150);
      expect(
        summary(
          es,
          es.map(journeyRecord).toList(),
          now: DateTime.utc(2026, 12, 31),
        ).lifetimePoints,
        0,
      );
    },
  );
  test(
    'perfect 2026/2027, quarter bonuses and cross-year streak match Swift',
    () {
      final es = [...journeyEvents(2026), ...journeyEvents(2027, extra: true)];
      final s = summary(es, es.map(journeyRecord).toList());
      expect(s.year(2026).points, 4000);
      expect(s.year(2027).points, 4100);
      expect(s.year(2027).maximumPoints, 4100);
      expect(s.year(2027).segments.length, 25);
      expect(s.year(2027).quarters.map((q) => q.points), [150, 150, 150, 150]);
      expect(s.lifetimePoints, 8100);
      expect(s.currentStreak, 49);
      expect(s.longestStreak, 49);
    },
  );
  test('empty/incomplete schedules never award completion bonuses', () {
    final es = journeyEvents(2026).take(2).toList();
    expect(
      summary(
        es,
        es.map(journeyRecord).toList(),
        complete: {},
      ).year(2026).points,
      200,
    );
    expect(summary([], []).year(2026).points, 0);
    expect(
      summary(es, es.map(journeyRecord).toList()).year(2026).annualBonus,
      0,
    );
  });
  test('partial breaks streak and quarter/year bonus, retains base points', () {
    final es = journeyEvents(2026),
        rows = journeyEvents(2026).map(journeyRecord).toList();
    rows[1] = journeyRecord(es[1], ObservanceStatus.partial);
    final s = summary(es, rows);
    expect(s.year(2026).basePoints, 2350);
    expect(s.year(2026).annualBonus, 0);
    expect(s.year(2026).quarters.map((q) => q.points), [0, 150, 150, 150]);
    expect(s.longestStreak, 22);
  });
  test(
    'UID dedup, newest corrections, deletion and unknown records match Swift',
    () {
      final es = journeyEvents(2026),
          rows = journeyEvents(2026).map(journeyRecord).toList();
      expect(
        summary([...es, ...es], [...rows, ...rows]).year(2026).points,
        4000,
      );
      final edit = journeyRecord(
        es[0],
        ObservanceStatus.missed,
      ).copyWith(updatedAtUTC: '2028-01-02T00:00:00Z');
      expect(summary(es, [edit, ...rows]).year(2026).points, 2750);
      expect(summary(es, rows.skip(1).toList()).year(2026).points, 2750);
      expect(
        summary(es, [
          ...rows.skip(1),
          rows.first.copyWith(occurrenceUid: 'unknown'),
        ]).year(2026).annualBonus,
        0,
      );
    },
  );
  test('Parana instant and Home timezone determine eligibility', () {
    final e = EkadashiDate(
      id: 1,
      name: 'E',
      date: DateTime(2026, 1, 3),
      fastStartTime: '',
      fastBreakTime: '',
      description: '',
      paranaStartIso: '2026-01-04T06:00:00+05:30',
    );
    expect(
      summary(
        [e],
        [journeyRecord(e)],
        now: DateTime.parse('2026-01-04T05:59:59+05:30'),
      ).lifetimePoints,
      0,
    );
    expect(
      summary(
        [e],
        [journeyRecord(e)],
        now: DateTime.parse('2026-01-04T06:00:00+05:30'),
      ).lifetimePoints,
      100,
    );
    final fallback = journeyEvents(2026).first;
    final time = DateTime.utc(2026, 1, 4, 1);
    expect(
      JourneyRewards.calculate(
        occurrences: [fallback],
        history: [journeyRecord(fallback)],
        completeYears: {},
        now: time,
        timezone: 'America/Los_Angeles',
      ).lifetimePoints,
      0,
    );
    expect(
      summary([fallback], [journeyRecord(fallback)], now: time).lifetimePoints,
      100,
    );
  });
  test('catalogue, allowance, correction retention and dates match Swift', () {
    final es = [...journeyEvents(2026), ...journeyEvents(2027, extra: true)];
    final s = summary(es, es.map(journeyRecord).toList());
    expect(JourneyBadgeCatalog.all([2026, 2027]).length, 21);
    final free = JourneyBadgeEvaluator.evaluate(
      summary: s,
      current: {},
      newUnlockLimit: 3,
      now: journeyNow,
    );
    expect(free.updated.values.where((a) => a.isUnlocked).length, 3);
    final paid = JourneyBadgeEvaluator.evaluate(
      summary: s,
      current: free.updated,
      now: journeyNow,
    );
    for (final id in [
      'streak_24',
      'journey_2026_full',
      'journey_2027_full',
      'full_year_observance',
    ]) {
      expect(paid.updated[id]?.isUnlocked, true, reason: id);
    }
    final edited = JourneyBadgeEvaluator.evaluate(
      summary: summary(es, []),
      current: paid.updated,
      newUnlockLimit: 0,
      now: journeyNow,
    );
    expect(
      edited.updated.values.where((a) => a.isUnlocked).length,
      paid.updated.values.where((a) => a.isUnlocked).length,
    );
    expect(
      edited.updated['first_vrat']?.unlockedAtUTC,
      paid.updated['first_vrat']?.unlockedAtUTC,
    );
  });
  test('encouragement adds no points and is never suggested as a goal', () {
    final es = journeyEvents(2026);
    final s = summary(es, [
      journeyRecord(es[0], ObservanceStatus.missed),
      journeyRecord(es[1]),
      for (final e in es.skip(2).take(3))
        journeyRecord(e, ObservanceStatus.partial),
    ]);
    final result = JourneyBadgeEvaluator.evaluate(
      summary: s,
      current: {},
      now: journeyNow,
    );
    expect(result.updated['welcome_back']?.isUnlocked, true);
    expect(result.updated['every_effort']?.isUnlocked, true);
    expect(s.lifetimePoints, 250);
    expect(
      ['welcome_back', 'every_effort'],
      isNot(contains(JourneyBadgeCatalog.nextMilestone(s, result.updated)?.id)),
    );
    final five = summary(
      es,
      es.take(5).map(journeyRecord).toList(),
      now: DateTime.utc(2026, 3, 17),
    );
    final state = JourneyBadgeEvaluator.evaluate(
      summary: five,
      current: {},
      now: journeyNow,
    ).updated;
    expect(JourneyBadgeCatalog.nextMilestone(five, state)?.id, 'streak_6');
    final broken = summary(es, [
      ...es.take(5).map(journeyRecord),
      journeyRecord(es[5], ObservanceStatus.missed),
    ], now: DateTime.utc(2026, 3, 19));
    expect(JourneyBadgeCatalog.nextMilestone(broken, state)?.id, 'vrat_10');
  });
  test(
    'unpresented awards survive restart; presentation prevents repetition',
    () async {
      final es = journeyEvents(2026);
      VratTrackerService make() => VratTrackerService(now: () => journeyNow);
      final a = make();
      await a.init(occurrences: es);
      await a.recordVrat(
        ekadashiOccurrenceId: es[0].id,
        occurrenceUid: es[0].occurrenceUid,
        ekadashiDate: '2026-01-03',
        ekadashiName: 'E',
        status: ObservanceStatus.observed,
        occurrences: es,
      );
      final b = make();
      await b.init(occurrences: es);
      expect((await b.refreshAchievements(es)).map((a) => a.id), [
        'first_vrat',
      ]);
      expect(await b.refreshAchievements(es), isEmpty);
      await b.markAnnouncementsPresented(['first_vrat']);
      final c = make();
      await c.init(occurrences: es);
      expect(await c.refreshAchievements(es), isEmpty);
    },
  );
  for (final key in ['journey_badges_v1', 'vrat_tracker_user_achievements']) {
    test('corrupt $key preserves journal writes and damaged bytes', () async {
      SharedPreferences.setMockInitialValues({key: 'invalid'});
      final s = VratTrackerService(now: () => journeyNow);
      await s.init(occurrences: journeyEvents(2026));
      expect(s.trackerEnabled, true);
      expect(s.rewardsStorageError, true);
      await s.recordVrat(
        ekadashiOccurrenceId: 1,
        occurrenceUid: 'ekadashi:2026:01',
        ekadashiDate: '2026-01-03',
        ekadashiName: 'E',
        status: ObservanceStatus.observed,
      );
      expect(s.getAllRecords().length, 1);
      expect((await SharedPreferences.getInstance()).getString(key), 'invalid');
    });
  }
  test('all 63 Journey translations equal iOS, including placeholder order', () {
    final overrides =
        jsonDecode(
              File(
                'test/fixtures/journey_translations.json',
              ).readAsStringSync(),
            )
            as Map;
    for (final code in AppLanguage.codes) {
      final strings = overrides[code] as Map;
      expect(strings.length,63);
      for (final key in strings.keys.where(
        (k) => k.startsWith('ios_journey_'),
      )) {
        expect(
          AppStrings.translate(key, code),
          strings[key],
          reason: '$code $key',
        );
      }
    }
  });
}
