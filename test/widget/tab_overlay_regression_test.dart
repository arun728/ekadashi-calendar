import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:ekadashi_calendar/widgets/tab_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets(
    'Replacing and removing a pushed page updates the shell toolbar',
    (tester) async {
      final harness = AppHarness();
      await tester.runAsync(harness.install);
      addTearDown(harness.uninstall);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('view_details')).first);
      await tester.pumpAndSettle();
      final navigator = Navigator.of(
        tester.element(find.byType(DetailsScreen)),
      );
      navigator.pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(key: Key('replacement_page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShellTopBar), findsNothing);
      final replacement = tester.element(
        find.byKey(const Key('replacement_page')),
      );
      navigator.removeRoute(ModalRoute.of(replacement)!);
      await tester.pumpAndSettle();
      expect(find.byType(ShellTopBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final tab in [2, 3]) {
    testWidgets(
      'Tab $tab keeps toolbar and layout while its local menu is open',
      (tester) async {
        final harness = AppHarness();
        await tester.runAsync(harness.install);
        addTearDown(harness.uninstall);
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('glass_tab_$tab')));
        await tester.pumpAndSettle();
        if (tab == 2) {
          await tester.tap(find.byKey(const Key('journey_tab_history')));
          await tester.pumpAndSettle();
        }
        final anchor = find.byKey(
          Key(tab == 2 ? 'vrat_tabs_tube' : 'panchang_sections_tube'),
        );
        final position = tester.getTopLeft(anchor);
        final menu = tab == 2
            ? find.byType(PopupMenuButton<int>).hitTestable()
            : find.byKey(const Key('panchang_city_selector'));
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(find.byType(ShellTopBar), findsOneWidget);
        expect(tester.getTopLeft(anchor), position);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ShellTopBar), findsOneWidget);
        expect(tester.getTopLeft(anchor), position);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('An overlay over Details preserves its pushed-page toolbar', (
    tester,
  ) async {
    final harness = AppHarness();
    await tester.runAsync(harness.install);
    addTearDown(harness.uninstall);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('view_details')).first);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(DetailsScreen));
    final menu = showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(20, 100, 20, 20),
      items: [const PopupMenuItem(value: 'value', child: Text('Option'))],
    );
    await tester.pumpAndSettle();
    expect(find.byType(ShellTopBar), findsNothing);
    expect(find.byType(DetailsScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await menu;
    expect(find.byType(ShellTopBar), findsNothing);
    await tester.tap(find.byKey(const Key('glass_tab_0')));
    await tester.pumpAndSettle();
    expect(find.byType(ShellTopBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
