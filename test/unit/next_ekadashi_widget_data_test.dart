import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ekadashi_calendar/models/next_ekadashi_widget_data.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('hi');
    await initializeDateFormatting('ta');
    await initializeDateFormatting('te');
  });

  final sample = [
    (
      id: 14,
      name: 'Kamika Ekadashi',
      date: DateTime(2026, 8, 9),
      fastStartTime: '05:56 AM',
      description:
          'Fulfills desires during Chaturmas. Worship with Tulsi leaves.',
    ),
    (
      id: 15,
      name: 'Putrada Ekadashi',
      date: DateTime(2026, 8, 23),
      fastStartTime: '06:01 AM',
      description: 'Blessings for progeny and family welfare.',
    ),
  ];

  test('picks today when still on Ekadashi day', () {
    final data = NextEkadashiWidgetBuilder.build(
      entries: sample,
      now: DateTime(2026, 8, 9, 10, 0),
      languageCode: 'en',
    );
    expect(data.name, 'Kamika Ekadashi');
    expect(data.startFastingLabel, '05:56 AM');
    expect(data.weekdayLabel, isNotEmpty);
    expect(data.dateLabel, isNotEmpty);
    expect(data.significance, contains('Chaturmas'));
    expect(data.ekadashiId, 14);
  });

  test('picks next after today passes', () {
    final data = NextEkadashiWidgetBuilder.build(
      entries: sample,
      now: DateTime(2026, 8, 10, 8, 0),
      languageCode: 'en',
    );
    expect(data.name, 'Putrada Ekadashi');
    expect(data.startFastingLabel, '06:01 AM');
  });

  test('empty calendar returns localized fallback', () {
    final data = NextEkadashiWidgetBuilder.build(
      entries: [],
      now: DateTime(2026, 8, 9),
      languageCode: 'te',
    );
    expect(data.ekadashiId, isNull);
    expect(data.name, contains('ఏకాదశి'));
    expect(data.startFastingLabel, '—');
    expect(data.weekdayLabel, '—');
  });

  test('weekday and date labels are required non-empty for real entry', () {
    final data = NextEkadashiWidgetBuilder.build(
      entries: sample,
      now: DateTime(2026, 8, 1),
      languageCode: 'en',
    );
    expect(data.weekdayLabel.toLowerCase(), 'sunday'); // Aug 9 2026 is Sunday
    expect(data.dateLabel, isNot(equals('—')));
    expect(data.startFastingLabel, '05:56 AM');
  });

  test('significance is truncated for long text', () {
    final long = 'x' * 200;
    final t = NextEkadashiWidgetData.truncateSignificance(long, maxChars: 50);
    expect(t.length, lessThanOrEqualTo(50));
    expect(t.endsWith('…'), isTrue);
  });

  test('toWidgetKeys includes all required fields', () {
    final data = NextEkadashiWidgetBuilder.build(
      entries: sample,
      now: DateTime(2026, 8, 9),
      languageCode: 'en',
    );
    final keys = data.toWidgetKeys();
    expect(keys['widget_name'], data.name);
    expect(keys['widget_date'], data.dateLabel);
    expect(keys['widget_weekday'], data.weekdayLabel);
    expect(keys['widget_start_fasting'], data.startFastingLabel);
    expect(keys['widget_significance'], data.significance);
    expect(keys['widget_language'], 'en');
  });

  test('uses provided language labels for name/description from entries', () {
    final te = [
      (
        id: 1,
        name: 'కామిక ఏకాదశి',
        date: DateTime(2026, 8, 9),
        fastStartTime: '05:56 AM',
        description: 'చాతుర్మాసంలో కోరికలు నెరవేరుతాయి.',
      ),
    ];
    final data = NextEkadashiWidgetBuilder.build(
      entries: te,
      now: DateTime(2026, 8, 9),
      languageCode: 'te',
    );
    expect(data.name, 'కామిక ఏకాదశి');
    expect(data.significance, contains('చాతుర్మాసం'));
    expect(data.languageCode, 'te');
  });
}
