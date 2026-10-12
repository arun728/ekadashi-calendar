import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:ekadashi_calendar/widgets/tab_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The top bar as on the iPhone (screenshots of 12 October 2026): the
/// search button alone in a glass circle; a tab's actions share one glass
/// capsule with search; "Today" sits in its own glass capsule on the left.
void main() {
  Future<void> pump(WidgetTester tester, Widget bar) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: bar,
        ),
      ),
    ),
  );

  Finder search() => find.byKey(const Key('open_global_search'));
  Finder glassOf(Finder of) =>
      find.ancestor(of: of, matching: find.byType(GlassPanel));

  testWidgets('search alone sits in a glass circle', (tester) async {
    await pump(
      tester,
      ShellTopBar(title: 'Ekadashi Calendar', onSearch: () {}),
    );
    expect(glassOf(search()), findsOneWidget);
    expect(find.text('Ekadashi Calendar'), findsOneWidget);
  });

  testWidgets('tab actions share one glass capsule with search', (
    tester,
  ) async {
    await pump(
      tester,
      ShellTopBar(
        title: 'Ekadashi Calendar',
        onSearch: () {},
        actions: [
          IconButton(
            key: const Key('add'),
            onPressed: () {},
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
    final capsule = glassOf(search());
    expect(capsule, findsOneWidget);
    expect(
      find.descendant(of: capsule, matching: find.byKey(const Key('add'))),
      findsOneWidget,
    );
    // Search comes first, as on iOS.
    expect(
      tester.getCenter(search()).dx,
      lessThan(tester.getCenter(find.byKey(const Key('add'))).dx),
    );
  });

  testWidgets('Today sits in its own glass capsule on the left', (
    tester,
  ) async {
    await pump(
      tester,
      ShellTopBar(
        title: 'Ekadashi Calendar',
        onSearch: () {},
        leading: [BarTextButton(label: 'Today', onPressed: () {})],
      ),
    );
    final today = glassOf(find.text('Today'));
    expect(today, findsOneWidget);
    expect(
      find.descendant(of: today, matching: search()),
      findsNothing,
      reason: 'separate from the search capsule',
    );
    expect(tester.getCenter(find.text('Today')).dx, lessThan(200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long title shrinks to an ellipsis, never overflows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      ShellTopBar(
        title: 'Ekadashi Calendar',
        onSearch: () {},
        leading: [BarTextButton(label: 'Today', onPressed: () {})],
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.sync)),
        ],
      ),
    );
    final title = tester.widget<Text>(find.text('Ekadashi Calendar'));
    expect(title.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}
