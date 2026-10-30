import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/screens/widget_preview_screen.dart';
import 'package:ekadashi_calendar/widgets/native_widget_preview.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting();
    tz.initializeTimeZones();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final now = DateTime.utc(2026, 10, 8, 12);
  final events = List.generate(8, (i) {
    final start = DateTime.utc(2026, 10, 8, 6).add(Duration(days: i * 15));
    return EkadashiDate(
      id: i + 1,
      occurrenceUid: 'ekadashi:${start.year}:${i + 1}',
      name: 'Event ${i + 1}',
      date: DateTime(start.year, start.month, start.day),
      fastBreakTime: '',
      fastStartTime: '',
      description: '',
      fastingStartIso: start.toIso8601String(),
      paranaStartIso: start.add(const Duration(days: 1)).toIso8601String(),
      paranaEndIso: start
          .add(const Duration(days: 1, hours: 3))
          .toIso8601String(),
    );
  });
  String? opened;
  late LanguageService language;
  Future<void> pump(
    WidgetTester tester, {
    String code = 'en',
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    language = LanguageService();
    await language.changeLanguage(code);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: language,
        child: MaterialApp(
          home: WidgetPreviewScreen(
            ekadashiList: events,
            now: now,
            currentTimezone: 'UTC',
            locationName: 'City',
            tradition: 'vaishnava',
            onOpenOccurrence: (uid) => opened = uid,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  NativeWidgetPreview preview(WidgetTester tester) =>
      tester.widget(find.byType(NativeWidgetPreview));

  testWidgets('preview has two tabs and only the supported sizes', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('widget_preview_kind')), findsOneWidget);
    expect(find.text('Small'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Large'), findsNothing);
    expect(find.text('Lock Screen'), findsOneWidget);
    expect(find.byKey(const Key('card_ekadashi')), findsOneWidget);
    await tester.tap(find.text('Upcoming Ekadashis').first);
    await tester.pumpAndSettle();
    expect(find.text('Small'), findsNothing);
    expect(find.text('Large'), findsOneWidget);
    expect(find.byKey(const Key('card_upcoming_ekadashi')), findsOneWidget);
    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    expect(preview(tester).height, 340);
    await tester.tap(find.text('Ekadashi').first);
    await tester.pumpAndSettle();
    expect(preview(tester).height, 170);
  });
  testWidgets(
    'native preview gets the actual schedule, clock, city and tradition',
    (tester) async {
      await pump(tester);
      final view = preview(tester);
      expect(view.now, now);
      expect(view.payload['metadata']['locationName'], 'City');
      expect(view.payload['metadata']['tradition'], 'vaishnava');
      expect(view.payload['today']['isEkadashi'], isTrue);
      expect(
        view.payload['nextEkadashi']['occurrenceUid'],
        events.first.occurrenceUid,
      );
      expect(view.payload['upcomingEkadashis'].length, 5);
      expect(
        view.payload['upcomingEkadashis'].first['occurrenceUid'],
        events[1].occurrenceUid,
      );
      view.onOpenOccurrence(events[5].occurrenceUid);
      expect(opened, events[5].occurrenceUid);
    },
  );
  testWidgets(
    'Lock Screen preview uses an Android host card and explains availability',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('Lock Screen'));
      await tester.pumpAndSettle();
      expect(preview(tester).height, 240);
      expect(
        find.text(AppStrings.translate('widget_lock_support', 'en')),
        findsOneWidget,
      );
    },
  );
  for (final code in AppLanguage.codes) {
    testWidgets(
      '$code controls fit narrow screens with larger text and every size',
      (tester) async {
        await pump(tester, code: code, scale: 2);
        for (final key in [
          'widget_size_small',
          'widget_size_medium',
          'widget_size_lock',
        ]) {
          await tester.tap(find.text(language.translate(key)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(preview(tester).payload['metadata']['locale'], code);
        }
        await tester.tap(
          find.text(language.translate('upcoming_ekadashis')).first,
        );
        await tester.pumpAndSettle();
        for (final key in [
          'widget_size_medium',
          'widget_size_large',
          'widget_size_lock',
        ]) {
          await tester.tap(find.text(language.translate(key)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(preview(tester).payload['upcomingEkadashis'].length, 5);
        }
      },
    );
  }
}
