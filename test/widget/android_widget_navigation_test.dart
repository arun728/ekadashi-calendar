import 'package:ekadashi_calendar/main.dart';
import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;
  setUp(() async {
    harness = AppHarness();
    await harness.install();
  });
  tearDown(() => harness.uninstall());

  testWidgets(
    'widget occurrence URL selects the exact Home card and year from another tab',
    (tester) async {
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('glass_tab_4')));
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(MainScreen));
      state.handleDeepLink(
        Uri.parse('ekadashi://ekadashi?uid=ekadashi%3A2027%3A25'),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('home_page_indicator'))).data,
        '25 / 25',
      );
      expect(find.byType(DetailsScreen), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('home_year_menu')),
          matching: find.text('2027'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'cold widget occurrence waits for the schedule and survives launch refresh',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.ekadashi.widget'),
            (call) async => call.method == 'getInitialDeepLink'
                ? 'ekadashi://ekadashi?uid=ekadashi%3A2027%3A25'
                : true,
          );
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('home_page_indicator'))).data,
        '25 / 25',
      );
      expect(find.byType(DetailsScreen), findsNothing);
    },
  );
  testWidgets(
    'an occurrence opens Home from Details and manual paging then stays put on language changes',
    (tester) async {
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('view_details')));
      await tester.pumpAndSettle();
      expect(find.byType(DetailsScreen), findsOneWidget);
      final dynamic state = tester.state(find.byType(MainScreen));
      state.handleDeepLink(
        Uri.parse('ekadashi://ekadashi?uid=ekadashi%3A2027%3A25'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DetailsScreen), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('home_page_indicator'))).data,
        '25 / 25',
      );
      await tester.drag(find.byType(PageView).first, const Offset(700, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('home_page_indicator'))).data,
        '24 / 25',
      );
      await tester
          .element(find.byType(MainScreen))
          .read<LanguageService>()
          .changeLanguage('ta');
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('home_page_indicator'))).data,
        '24 / 25',
      );
    },
  );
}
