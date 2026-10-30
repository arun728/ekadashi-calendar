import 'package:ekadashi_calendar/widgets/app_icons.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_settings.dart';
import 'package:ekadashi_calendar/widgets/native_widget_preview.dart';
import 'package:ekadashi_calendar/screens/widget_preview_screen.dart';

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 180 && !ready(); i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(ready(), isTrue);
}

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real native widget previews in six languages and exact Home navigation',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_launched', true);
      await prefs.setString('language_code', 'en');
      app.main();
      await tester.pump();
      await waitFor(
        tester,
        () =>
            find.byKey(const Key('home_page_indicator')).evaluate().isNotEmpty,
      );
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      final context = tester.element(find.byType(app.MainScreen));
      final language = context.read<LanguageService>();
      final folder = await getDatabasesPath();
      await Directory(folder).create(recursive: true);
      for (final code in AppLanguage.codes) {
        await language.changeLanguage(code);
        await frames(tester);
        await tester.tap(find.byKey(const Key('glass_tab_4')));
        await frames(tester);
        final entry = find.text(language.translate('widget_preview'));
        await Scrollable.ensureVisible(tester.element(entry), alignment: 0.5);
        await frames(tester);
        await tester.tap(entry);
        await frames(tester);
        await waitFor(
          tester,
          () => find.byType(NativeWidgetPreview).evaluate().isNotEmpty,
        );
        final screen = tester.widget<WidgetPreviewScreen>(
          find.byType(WidgetPreviewScreen),
        );
        expect(
          screen.currentTimezone,
          context.read<EkadashiSettings>().city.timeZoneId,
        );
        var native = tester.widget<NativeWidgetPreview>(
          find.byType(NativeWidgetPreview),
        );
        expect(native.payload['metadata']['locale'], code);
        await File(
          '$folder/widget-fixture-$code.json',
        ).writeAsString(jsonEncode(native.payload));
        await binding.takeScreenshot('android-widget-$code-medium');
        await tester.tap(find.text(language.translate('widget_size_small')));
        await frames(tester);
        await binding.takeScreenshot('android-widget-$code-small');
        await tester.tap(find.text(language.translate('widget_size_lock')));
        await frames(tester);
        await binding.takeScreenshot('android-widget-$code-lock');
        await tester.tap(
          find.text(language.translate('upcoming_ekadashis')).first,
        );
        await frames(tester);
        await tester.tap(find.text(language.translate('widget_size_medium')));
        await frames(tester);
        native = tester.widget<NativeWidgetPreview>(
          find.byType(NativeWidgetPreview),
        );
        expect(native.payload['upcomingEkadashis'].length, 5);
        await binding.takeScreenshot('android-widget-$code-upcoming-medium');
        await tester.tap(find.text(language.translate('widget_size_large')));
        await frames(tester);
        await binding.takeScreenshot('android-widget-$code-upcoming-large');
        await tester.tap(find.byIcon(AppIcons.back));
        await frames(tester);
      }
      await language.changeLanguage('en');
      await frames(tester);
      final entry = find.text('Widget Preview');
      await Scrollable.ensureVisible(tester.element(entry), alignment: 0.5);
      await frames(tester);
      await tester.tap(entry);
      await frames(tester);
      final native = tester.widget<NativeWidgetPreview>(
        find.byType(NativeWidgetPreview),
      );
      final item = native.payload['nextEkadashi'] as Map;
      final year = item['year'];
      final yearItems = (native.payload['schedule'] as List)
          .where((e) => e['year'] == year)
          .toList();
      final index = yearItems.indexWhere(
        (e) => e['occurrenceUid'] == item['occurrenceUid'],
      );
      // Actual pointer events cross the platform-view bridge and call the native card's listener.
      await tester.tapAt(
        tester.getRect(find.byType(NativeWidgetPreview)).center,
      );
      await frames(tester);
      await waitFor(
        tester,
        () =>
            find.byKey(const Key('home_page_indicator')).evaluate().isNotEmpty,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('home_page_indicator'))).data,
        '${index + 1} / ${yearItems.length}',
      );
      expect(find.byType(WidgetPreviewScreen), findsNothing);
      await binding.takeScreenshot('android-widget-preview-tap-home');
    },
  );
}
