import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/main.dart';

Future<void> returnToMain(WidgetTester tester) async {
  Navigator.of(
    tester.element(find.byType(MainScreen, skipOffstage: false)),
  ).popUntil((route) => route.isFirst);
  await tester.pump(const Duration(milliseconds: 500));
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
