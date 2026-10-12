import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import '../support/app_harness.dart';

// Actual Flutter offscreen rendering, not an Android emulator. Native channels
// use AppHarness. PNGs are review evidence; assertions check observable UI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'Roboto': ['EkadashiTestFont.ttf'],
      'MaterialIcons': ['MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(
          File(
            'test/fonts/$file',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      }
      await loader.load();
    }
  });
  for (final locale in ['en', 'ta', 'hi', 'te', 'gu', 'bn']) {
    testWidgets(
      '$locale Home, Calendar, Settings and Details render and navigate',
      (tester) async {
        final harness = AppHarness();
        await tester.runAsync(
          () => harness.install(
            preferences: {
              'language_code': locale,
              'vrat_tracker_enabled': true,
            },
          ),
        );
        addTearDown(harness.uninstall);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(key: key, child: harness.app()),
        );
        await tester.pumpAndSettle();
        final language = Provider.of<LanguageService>(
          tester.element(find.byType(MaterialApp)),
          listen: false,
        );
        expect(language.currentLocale.languageCode, locale);
        Future<void> capture(String name) async {
          expect(tester.takeException(), isNull);
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final directory = Directory('build/ui-screenshots/offscreen');
            await directory.create(recursive: true);
            await File(
              '${directory.path}/${locale}_$name.png',
            ).writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('home');
        await tester.tap(find.byIcon(Icons.calendar_month));
        await tester.pumpAndSettle();
        await capture('calendar');
        await tester.tap(find.byKey(const Key('open_global_search')));
        await tester.pumpAndSettle();
        await capture('search');
        await tester.enterText(find.byType(TextField), 'nirjla');
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pumpAndSettle();
        await capture('search_results');
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('glass_tab_3')));
        await tester.pumpAndSettle();
        await capture('panchang_key_days');
        await tester.tap(find.byKey(const Key('panchang_tab_daily')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('panchang_daily_overview')),
          findsOneWidget,
        );
        await capture('panchang_free');

        await tester.tap(find.byKey(const Key('glass_tab_2')));
        await tester.pumpAndSettle();
        await capture('vrat');
        await tester.ensureVisible(
          find.byKey(const Key('journey_tab_history')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('journey_tab_history')));
        await tester.pumpAndSettle();
        await capture('vrat_history');
        await tester.tap(find.byType(Card).first);
        await tester.pumpAndSettle();
        await capture('vrat_record');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('glass_tab_4')));
        await tester.pumpAndSettle();
        expect(find.byType(SwitchListTile), findsWidgets);
        await capture('settings_dark');
        await tester.scrollUntilVisible(
          find.byKey(const Key('settings_about_tube')),
          180,
          scrollable: find
              .descendant(
                of: find.byType(ListView).hitTestable(),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await capture('settings_about');
        await tester.scrollUntilVisible(
          find.byKey(const Key('settings_appearance_tube')),
          -180,
          scrollable: find
              .descendant(
                of: find.byType(ListView).hitTestable(),
                matching: find.byType(Scrollable),
              )
              .first,
        );

        await tester.ensureVisible(
          find.widgetWithText(SwitchListTile, language.translate('dark_mode')),
        );
        await tester.tap(
          find.widgetWithText(SwitchListTile, language.translate('dark_mode')),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SwitchListTile>(
                find.widgetWithText(
                  SwitchListTile,
                  language.translate('dark_mode'),
                ),
              )
              .value,
          isFalse,
        );
        await capture('settings_light');
        await tester.tap(find.byIcon(Icons.home));
        await tester.pumpAndSettle();
        final button = find
            .widgetWithText(ElevatedButton, language.translate('view_details'))
            .first;
        expect(
          button,
          findsOneWidget,
          reason: 'Localized Details control in $locale',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text(language.translate('significance')), findsOneWidget);
        await capture('details');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.calendar_month), findsOneWidget);
      },
    );
  }
}
