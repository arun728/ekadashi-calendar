import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/screens/premium_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/panchang/observance_calendar_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../support/app_harness.dart';
import '../support/premium_fixture.dart';

/// Every word on every screen is in the chosen language: no English left in
/// Hindi, Tamil, Telugu, Gujarati or Bengali. Walks the tabs, sub-sections,
/// search, details, dialogs, the paywall and full Premium Panchang, and
/// collects every text, hint, tooltip and accessibility label it renders.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// What may stay in Latin letters: values the user types (time zone ids)
  /// and the user's own data (none in this harness).
  final allowed = RegExp(r'Asia/Kolkata|America/New_York');
  final latin = RegExp(r'[A-Za-z]');

  Iterable<String> texts(WidgetTester tester) sync* {
    for (final widget in tester.allWidgets) {
      if (widget is Text) {
        yield widget.data ?? widget.textSpan?.toPlainText() ?? '';
      } else if (widget is RichText) {
        yield widget.text.toPlainText();
      } else if (widget is Tooltip) {
        yield widget.message ?? '';
      } else if (widget is IconButton) {
        yield widget.tooltip ?? '';
      } else if (widget is TextField) {
        final d = widget.decoration;
        yield d?.hintText ?? '';
        yield d?.labelText ?? '';
        yield d?.helperText ?? '';
      } else if (widget is Semantics) {
        yield widget.properties.label ?? '';
        yield widget.properties.hint ?? '';
      }
    }
  }

  void collect(
    WidgetTester tester,
    String step,
    Map<String, Set<String>> found, {
    String typed = '',
  }) {
    for (final text in texts(tester)) {
      // What the user typed is shown back as typed.
      final cleaned = (typed.isEmpty ? text : text.replaceAll(typed, ''))
          .replaceAll(allowed, '');
      if (latin.hasMatch(cleaned)) found.putIfAbsent(text, () => {}).add(step);
    }
  }

  void report(String language, Map<String, Set<String>> found) {
    final lines = [
      for (final e in found.entries)
        '${e.key.replaceAll('\n', ' ')}  <- ${e.value.join(', ')}',
    ]..sort();
    expect(
      lines,
      isEmpty,
      reason: '$language shows English:\n${lines.join('\n')}',
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  Future<void> tapIfPresent(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) return;
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first, warnIfMissed: false);
    await settle(tester);
  }

  for (final language in AppLanguage.codes.where((c) => c != 'en')) {
    testWidgets('$language: the whole app is in $language', (tester) async {
      final harness = AppHarness();
      await tester.runAsync(
        () => harness.install(preferences: {'language_code': language}),
      );
      addTearDown(harness.uninstall);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness.app());
      await settle(tester);
      final found = <String, Set<String>>{};

      collect(tester, 'home', found);
      await tapIfPresent(tester, find.byType(ElevatedButton));
      collect(tester, 'details', found);
      await tester.binding.handlePopRoute();
      await settle(tester);

      await tester.tap(find.byKey(const Key('glass_tab_1')));
      await settle(tester);
      collect(tester, 'calendar', found);
      await tapIfPresent(tester, find.byKey(const Key('add_calendar_entry')));
      collect(tester, 'add calendar entry', found);
      await back(tester);

      await tester.tap(find.byKey(const Key('glass_tab_2')));
      await settle(tester);
      for (final page in [
        'overview',
        'history',
        'statistics',
        'achievements',
      ]) {
        await tapIfPresent(tester, find.byKey(Key('journey_tab_$page')));
        collect(tester, 'journey $page', found);
      }
      await tapIfPresent(tester, find.byKey(const Key('journey_tab_history')));
      await tapIfPresent(tester, find.byType(Card));
      collect(tester, 'record vrat', found);
      await back(tester);

      await tester.tap(find.byKey(const Key('glass_tab_3')));
      await settle(tester);
      for (final page in PanchangPage.values) {
        await tapIfPresent(tester, find.byKey(Key('panchang_tab_${page.raw}')));
        collect(tester, 'panchang ${page.raw} (free)', found);
      }
      await tapIfPresent(tester, find.byKey(const Key('panchang_notes')));
      collect(tester, 'panchang notes', found);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tapIfPresent(
        tester,
        find.byKey(const Key('panchang_city_selector')),
      );
      collect(tester, 'panchang city menu', found);
      await tapIfPresent(
        tester,
        find.byKey(const Key('panchang_edit_location')),
      );
      collect(tester, 'panchang location dialog', found);
      await back(tester);

      await tester.tap(find.byKey(const Key('glass_tab_4')));
      await settle(tester);
      final scrollable = find
          .descendant(
            of: find.byType(ListView).hitTestable(),
            matching: find.byType(Scrollable),
          )
          .first;
      for (var i = 0; i < 12; i++) {
        collect(tester, 'settings', found);
        await tester.drag(scrollable, const Offset(0, -300));
        await settle(tester);
      }
      await tapIfPresent(
        tester,
        find.byKey(const Key('notifications_add_event')),
      );
      collect(tester, 'reminder editor', found);
      await back(tester);
      await tapIfPresent(
        tester,
        find.byKey(const Key('permission_guide_action')),
      );
      collect(tester, 'permission guide', found);
      await back(tester);

      await tester.tap(find.byKey(const Key('open_global_search')));
      await settle(tester);
      collect(tester, 'search', found);
      for (final query in ['ekadashi', 'settings', 'zzzz']) {
        await tester.enterText(
          find.byKey(const Key('global_search_field')),
          query,
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await settle(tester);
        collect(tester, 'search $query', found, typed: query);
      }
      await tester.enterText(
        find.byKey(const Key('global_search_field')),
        'widget',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      await tapIfPresent(
        tester,
        find.byKey(const Key('search_result_screen:widgets')),
      );
      collect(tester, 'widget preview', found);
      report(language, found);
    });

    testWidgets('$language: Premium Panchang and the paywall', (tester) async {
      SharedPreferences.setMockInitialValues({'language_code': language});
      final service = EkadashiService();
      await service.initializeData();
      ObservanceCalendarService.calculateInline = true;
      ObservanceCalendarService.instance.put(
        2026,
        PanchangCity.newDelhi,
        const PanchangEngine().observanceCalendar(
          2026,
          city: PanchangCity.newDelhi,
        ),
      );
      final premium = PremiumService(entitlements: PremiumFixture());
      await premium.refresh();
      addTearDown(premium.dispose);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      final lang = LanguageService();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PremiumService>.value(value: premium),
            ChangeNotifierProvider<LanguageService>.value(value: lang),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PanchangScreen(
                initialDate: DateTime(2026, 10, 20),
                initialCity: PanchangCity.newDelhi,
                ekadashiList: service.getEkadashis(
                  timezone: 'IST',
                  languageCode: language,
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      final found = <String, Set<String>>{};
      for (final page in PanchangPage.values) {
        await tapIfPresent(tester, find.byKey(Key('panchang_tab_${page.raw}')));
        final scroll = find.byKey(const Key('panchang_scroll_view'));
        for (var i = 0; i < 10 && scroll.evaluate().isNotEmpty; i++) {
          collect(tester, 'premium panchang ${page.raw}', found);
          await tester.drag(scroll.first, const Offset(0, -500));
          await settle(tester);
        }
      }
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PremiumService>.value(
              value: PremiumService(
                entitlements: PremiumFixture()..premium = false,
              ),
            ),
            ChangeNotifierProvider<LanguageService>.value(value: lang),
          ],
          child: const MaterialApp(home: PremiumScreen()),
        ),
      );
      await settle(tester);
      collect(tester, 'paywall', found);
      report(language, found);
    });
  }
}
