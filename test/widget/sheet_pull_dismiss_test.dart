import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:ekadashi_calendar/widgets/glass_look.dart';

void main() {
  testWidgets('bouncing scroll content hands its top-edge drag to the sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppSheet<void>(
                context,
                builder: (_) => ListView(
                  key: const Key('bouncing_sheet'),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  children: const [ListTile(title: Text('Bouncing sheet'))],
                ),
              ),
              child: const Text('Open bouncing'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open bouncing'));
    await tester.pumpAndSettle();
    await tester.flingFrom(
      tester.getTopLeft(find.byKey(const Key('bouncing_sheet'))) +
          const Offset(100, 25),
      const Offset(0, 650),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bouncing_sheet')), findsNothing);
    expect(find.text('Open bouncing'), findsOneWidget);
  });
  for (final enabled in [false, true]) {
    for (final nested in [false, true]) {
      for (final fromContent in [false, true]) {
        testWidgets(
          'sheet pulls down glass=$enabled nested=$nested content=$fromContent',
          (tester) async {
            await tester.pumpWidget(
              MaterialApp(
                home: GlassLook(
                  enabled: enabled,
                  child: Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => showAppSheet<void>(
                          context,
                          nested: nested,
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Sheet'),
                              automaticallyImplyLeading: false,
                            ),
                            body: ListView(
                              key: const Key('sheet_scroll'),
                              children: [
                                for (var i = 0; i < 35; i++)
                                  ListTile(title: Text('Row $i')),
                              ],
                            ),
                          ),
                        ),
                        child: const Text('Open sheet'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Open sheet'));
            await tester.pumpAndSettle();
            expect(find.text('Sheet'), findsOneWidget);
            final source = fromContent
                ? find.byKey(const Key('sheet_scroll'))
                : find.text('Sheet');
            await tester.flingFrom(
              tester.getTopLeft(source) + const Offset(100, 25),
              const Offset(0, 650),
              1200,
            );
            await tester.pumpAndSettle();
            expect(find.text('Sheet'), findsNothing);
            expect(find.text('Open sheet'), findsOneWidget);
          },
        );
      }
    }
  }
  testWidgets('upward scrolling and a pull away from the top do not dismiss', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppSheet<void>(
                context,
                builder: (_) => ListView(
                  key: const Key('sheet_scroll'),
                  children: [
                    for (var i = 0; i < 60; i++)
                      ListTile(title: Text('Row $i')),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('sheet_scroll')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Row 0'), findsNothing);
    await tester.drag(
      find.byKey(const Key('sheet_scroll')),
      const Offset(0, 100),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sheet_scroll')), findsOneWidget);
  });
  for (final locked in [false, true]) {
    testWidgets(
      'short pulls cancel and locked sheets never pull-dismiss: locked=$locked',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showAppSheet<void>(
                    context,
                    isDismissible: !locked,
                    builder: (_) => ListView(
                      key: const Key('short_sheet'),
                      children: const [ListTile(title: Text('Short sheet'))],
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final source = find.byKey(const Key('short_sheet'));
        final before = tester.getTopLeft(source);
        await tester.dragFrom(
          before + const Offset(100, 30),
          Offset(0, locked ? 650 : 50),
        );
        await tester.pumpAndSettle();
        expect(find.text('Short sheet'), findsOneWidget);
        expect(tester.getTopLeft(source), before);
      },
    );
  }

  testWidgets('turning a wheel does not dismiss its sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppSheet<void>(
                context,
                builder: (_) => Center(
                  child: SizedBox(
                    height: 200,
                    child: ListWheelScrollView(
                      itemExtent: 40,
                      physics: const FixedExtentScrollPhysics(),
                      children: [for (var i = 0; i < 20; i++) Text('Wheel $i')],
                    ),
                  ),
                ),
              ),
              child: const Text('Open wheel'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open wheel'));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(ListWheelScrollView),
      const Offset(0, 300),
      800,
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
