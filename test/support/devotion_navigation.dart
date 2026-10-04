import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/main.dart';

Future<void> returnToMain(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  Navigator.of(
    tester.element(find.byType(MainScreen, skipOffstage: false)),
  ).popUntil((route) => route.isFirst);
  await tester.pump(const Duration(milliseconds: 500));
  // Native IME animation/insets can outlive the route transition.
  for (
    var i = 0;
    i < 50 &&
        find
            .byKey(const Key('glass_navigation_bar'))
            .hitTestable()
            .evaluate()
            .isEmpty;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    find.byKey(const Key('glass_navigation_bar')).hitTestable(),
    findsOneWidget,
  );
}

Future<void> tapAppTab(WidgetTester tester, int index) async {
  await returnToMain(tester);
  await tester.tap(find.byKey(Key('glass_tab_$index')));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> openVrat(WidgetTester tester) async {
  await tapAppTab(tester, 2);
  await tester.tap(find.byKey(const Key('practice_vrat')));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> openSearch(WidgetTester tester) async {
  await returnToMain(tester);
  await tester.tap(find.byKey(const Key('global_search')));
  await tester.pump(const Duration(milliseconds: 500));
}
