import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_widget_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  test('refresh saves all required widget keys', () async {
    final saved = <String, String>{};
    final service = EkadashiWidgetService(
      save: (k, v) async => saved[k] = v,
      updateWidget: () async {},
    );

    final list = [
      EkadashiDate(
        id: 14,
        name: 'Kamika Ekadashi',
        date: DateTime(2026, 8, 9),
        fastStartTime: '05:56 AM',
        fastBreakTime: '05:56 AM - 08:00 AM',
        description: 'Fulfills desires during Chaturmas.',
      ),
    ];

    final data = await service.refresh(
      ekadashis: list,
      languageCode: 'en',
      now: DateTime(2026, 8, 9, 12),
    );

    expect(data.name, 'Kamika Ekadashi');
    expect(saved['widget_name'], 'Kamika Ekadashi');
    expect(saved['widget_weekday'], isNotEmpty);
    expect(saved['widget_date'], isNotEmpty);
    expect(saved['widget_start_fasting'], '05:56 AM');
    expect(saved['widget_significance'], contains('Chaturmas'));
    expect(saved['widget_language'], 'en');
  });
}
