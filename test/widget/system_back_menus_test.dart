import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// System Back closes a menu or sheet opened in a tab and never closes the
/// app (android_app_test: the app was destroyed on API 33 and 35 after the
/// Journey year menu or Panchang city sheet, 14 October 2026).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;
  final exits = <MethodCall>[];
  setUp(() async {
    harness = AppHarness();
    await harness.install();
    exits.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemNavigator.pop') exits.add(call);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    harness.uninstall();
  });

  Future<void> tab(WidgetTester tester, int index) async {
    await tester.tap(find.byKey(Key('glass_tab_$index')));
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'ta', 'hi']) {
    testWidgets('Back closes the Journey year menu and the Panchang city '
        'sheet after switching to $language', (tester) async {
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      if (language != 'en') {
        await tester.tap(find.byKey(const Key('language_menu')));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .byType(PopupMenuItem<String>)
              .at(['en', 'hi', 'ta'].indexOf(language)),
        );
        await tester.pumpAndSettle();
      }
      await tab(tester, 4);
      await tab(tester, 2);
      await tester.tap(find.byKey(const Key('journey_tab_history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('journey_history_year_menu')));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is PopupMenuItem), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is PopupMenuItem), findsNothing);
      expect(exits, isEmpty, reason: 'Back must not close the app');

      await tab(tester, 3);
      await tester.tap(find.byKey(const Key('panchang_city_selector')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('city_picker_list')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('city_picker_list')), findsNothing);
      expect(exits, isEmpty, reason: 'Back must not close the app');
    });
  }

  // On a device, Back can come in the frame after a menu or sheet first
  // appears, before a later frame rebuilds the shell: Android 13+ then closed
  // the app (android_app_test, API 33 and 35, 14 October 2026).
  testWidgets('Back in the first frame of a menu or sheet closes it, not '
      'the app', (tester) async {
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tab(tester, 2);
    await tester.tap(find.byKey(const Key('journey_tab_history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('journey_history_year_menu')));
    await tester.pump();
    expect(find.byWidgetPredicate((w) => w is PopupMenuItem), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is PopupMenuItem), findsNothing);
    expect(exits, isEmpty, reason: 'Back must not close the app');

    await tab(tester, 3);
    await tester.tap(find.byKey(const Key('panchang_city_selector')));
    await tester.pump();
    expect(find.byKey(const Key('city_picker_list')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('city_picker_list')), findsNothing);
    expect(exits, isEmpty, reason: 'Back must not close the app');
  });
}
