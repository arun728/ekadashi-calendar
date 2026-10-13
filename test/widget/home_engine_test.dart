import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Home with Ekadashis from the Panchang engine (docs/EKADASHI_ENGINE_
/// SCHEDULE.md), as the iOS UI tests check it: the four menus line up in a
/// 2×2 grid in every language without leaving the screen, the tradition
/// switch stays on the Ekadashi on screen, the year menu and Calendar stay
/// together, the city search sets the city (not a time zone) and the share
/// card is free.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;
  setUp(() async {
    harness = AppHarness();
    await harness.install();
  });
  tearDown(() => harness.uninstall());

  Rect box(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(Key(key)));

  String? text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data;

  /// The four Home menus line up: location over tradition (same left edge
  /// and width), language over year (same width and right edge), all the
  /// same height, the left column left of the right one, all on screen.
  void expectAligned(WidgetTester tester, String reason) {
    final location = box(tester, 'home_location');
    final tradition = box(tester, 'home_tradition_menu');
    final language = box(tester, 'language_menu');
    final year = box(tester, 'home_year_menu');
    final screen = Offset.zero & tester.view.physicalSize;
    expect(location.left, moreOrLessEquals(tradition.left, epsilon: 1));
    expect(location.width, moreOrLessEquals(tradition.width, epsilon: 1));
    expect(language.width, moreOrLessEquals(year.width, epsilon: 1));
    expect(language.right, moreOrLessEquals(year.right, epsilon: 1));
    expect(location.height, moreOrLessEquals(language.height, epsilon: 1));
    expect(tradition.height, moreOrLessEquals(year.height, epsilon: 1));
    expect(location.height, moreOrLessEquals(tradition.height, epsilon: 1));
    expect(location.right, lessThan(language.left), reason: reason);
    expect(location.top, lessThan(tradition.top), reason: reason);
    for (final rect in [location, tradition, language, year]) {
      expect(
        screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
        isTrue,
        reason: '$reason: $rect inside $screen',
      );
    }
  }

  for (final (width, scale) in [(393.0, 1.0), (320.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'the four Home menus line up in every language, width=$width scale=$scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        for (final language in AppLanguage.all) {
          await tester.tap(find.byKey(const Key('language_menu')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.widgetWithText(PopupMenuItem<String>, language.nativeName),
          );
          await tester.pumpAndSettle();
          expectAligned(tester, language.code);
          expect(tester.takeException(), isNull, reason: language.code);
        }
      },
    );
  }

  testWidgets('switching the tradition stays on the Ekadashi on screen', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final before = text(tester, 'home_page_indicator');
    await tester.tap(find.byKey(const Key('home_tradition_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaishnava').last);
    await tester.pumpAndSettle();
    // Both traditions share the Ekadashi's identity.
    expect(text(tester, 'home_page_indicator'), before);
    expect(
      find.descendant(
        of: find.byKey(const Key('home_tradition_menu')),
        matching: find.text('Vaishnava'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the year menu and Calendar stay on the same year', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_year_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2027').last);
    await tester.pumpAndSettle();
    // 2027 opens on its first Ekadashi.
    expect(text(tester, 'home_page_indicator'), startsWith('1 / '));
    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();
    final calendar = tester.state<CalendarScreenState>(
      find.byType(CalendarScreen),
    );
    expect(calendar.selectedYear, 2027);
    expect(text(tester, 'calendar_ekadashi_source'), 'Smarta • Chennai (IN)');
    // Calendar moving back to this year moves Home too.
    calendar.resetToToday();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('home_year_menu')),
        matching: find.text('${DateTime.now().year}'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the city search sets the city; the share card is free', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(text(tester, 'home_location_name'), isNot(contains('•')));
    await tester.tap(find.byKey(const Key('home_location')));
    await tester.pumpAndSettle();
    // Never empty: popular cities before anything is typed.
    expect(find.text('Popular cities'), findsOneWidget);
    expect(
      find.byKey(const Key('ekadashi_city_geonames-1264527')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('ekadashi_location_search')),
      'Mumbai',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ekadashi_city_geonames-1275339')));
    await tester.pumpAndSettle();
    expect(text(tester, 'home_location_name'), 'Mumbai (IN)');
    // Reminders follow the new city.
    expect(
      harness.notificationCalls.where(
        (c) => c.method == 'scheduleAllNotifications',
      ),
      isNotEmpty,
    );

    await tester.tap(find.byKey(const Key('home_share_card')).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('share_card_preview')), findsOneWidget);
    expect(find.byKey(const Key('share_card_share')), findsOneWidget);
    expect(find.byKey(const Key('share_card_save')), findsOneWidget);
    expect(find.byKey(const Key('premium_close')), findsNothing);
    // No location on the card.
    expect(
      find.descendant(
        of: find.byKey(const Key('share_card_preview')),
        matching: find.textContaining('Mumbai'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
