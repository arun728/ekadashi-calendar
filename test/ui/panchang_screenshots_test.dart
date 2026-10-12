import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/panchang/observance_calendar_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/widgets/app_background.dart';
import 'package:ekadashi_calendar/widgets/tab_shell.dart';
import '../support/premium_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting();
    ObservanceCalendarService.calculateInline = true;
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          File(
            'test/fonts/${entry.value}',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await loader.load();
    }
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) =>
      tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final directory = Directory('build/ui-screenshots/offscreen');
        await directory.create(recursive: true);
        await File(
          '${directory.path}/panchang_$name.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });

  Widget app(
    GlobalKey key,
    PremiumService premium, {
    DateTime? date,
    PanchangCity? city,
    ThemeMode mode = ThemeMode.dark,
  }) => MultiProvider(
    providers: [
      ChangeNotifierProvider<PremiumService>.value(value: premium),
      ChangeNotifierProvider(create: (_) => LanguageService()),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      // Around the navigator, so the sheets are in the screenshots too.
      builder: (context, child) => RepaintBoundary(key: key, child: child),
      home: Builder(
        builder: (context) {
          // Today and the notes in the top bar, as the app shell shows them.
          final slots = TabBarSlots();
          return AppBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: ListenableBuilder(
                  listenable: slots,
                  builder: (context, _) => AppBar(
                    leadingWidth: 100,
                    leading: slots.leading(context),
                    title: const Text('Ekadashi Calendar'),
                    actions: slots.actions(context),
                  ),
                ),
              ),
              body: PanchangScreen(
                barSlots: slots,
                initialDate: date,
                initialCity: city ?? PanchangCity.newDelhi,
              ),
            ),
          );
        },
      ),
    ),
  );

  testWidgets('Panchang free and premium screens render review screenshots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundaryKey = GlobalKey();
    final backend = PremiumFixture()..premium = false;
    final premium = PremiumService(entitlements: backend);
    addTearDown(premium.dispose);

    await tester.pumpWidget(
      app(boundaryKey, premium, date: DateTime.utc(2026, 2, 15)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unlock full Panchang'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, boundaryKey, 'free');

    backend.premium = true;
    await premium.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Five limbs'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, boundaryKey, 'premium');
    await tester.tap(find.byKey(const Key('panchang_tab_keydays')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panchang_key_days')), findsOneWidget);
    await capture(tester, boundaryKey, 'key_days');
    expect(tester.takeException(), isNull);
  });

  testWidgets('2027 worldwide Panchang subtabs render screenshots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = PremiumFixture()..premium = true;
    final premium = PremiumService(entitlements: backend);
    addTearDown(premium.dispose);
    await premium.refresh();
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      app(
        boundaryKey,
        premium,
        date: DateTime.utc(2027, 1, 3),
        city: PanchangCity.newYork,
        mode: ThemeMode.light,
      ),
    );
    await tester.pumpAndSettle();
    for (final page in ['daily', 'muhurta', 'rashi', 'ekadashi']) {
      await tester.tap(find.byKey(Key('panchang_tab_$page')));
      await tester.pumpAndSettle();
      if (page == 'ekadashi') {
        expect(find.textContaining('Saphala Ekadashi'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await capture(tester, boundaryKey, '2027_$page');
    }
  });

  testWidgets('Panchang sheets and free Key days render screenshots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final premium = PremiumService(
      entitlements: PremiumFixture()..premium = false,
    );
    addTearDown(premium.dispose);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      app(
        boundaryKey,
        premium,
        date: DateTime.utc(2026, 10, 12),
        city: PanchangCity.chennai,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panchang_tab_keydays')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panchang_key_days_unlock')), findsOneWidget);
    await capture(tester, boundaryKey, 'key_days_free_dark');
    await tester.tap(find.byKey(const Key('panchang_notes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panchang_notes_sheet')), findsOneWidget);
    await capture(tester, boundaryKey, 'notes_sheet');
    await tester.tap(find.byKey(const Key('panchang_notes_done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panchang_tab_daily')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panchang_selected_date')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await capture(tester, boundaryKey, 'day_picker');
    await tester.tap(find.byKey(const Key('panchang_day_picker_done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panchang_city_selector')));
    await tester.pumpAndSettle();
    await capture(tester, boundaryKey, 'location_menu');
    await tester.tap(find.byKey(const Key('panchang_edit_location')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panchang_location_sheet')), findsOneWidget);
    await capture(tester, boundaryKey, 'location_sheet');
    expect(tester.takeException(), isNull);
  });
}
