import 'dart:async';
import '../support/devotion_navigation.dart';
import 'package:flutter/material.dart';
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
  testWidgets('five destinations expose practice, library and global search', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    for (final label in [
      'Today',
      'Calendar',
      'Practice',
      'Library',
      'Settings',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.byKey(const Key('glass_tab_2')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('practice_start')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('practice_vrat')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('glass_tab_3')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('library_search')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('global_search')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('tab navigation waits for native keyboard insets to clear', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await openSearch(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    final close = Timer(
      const Duration(milliseconds: 900),
      tester.view.resetViewInsets,
    );
    addTearDown(close.cancel);
    await tapAppTab(tester, 4);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('glass_tab_4')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
