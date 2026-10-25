import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:ekadashi_calendar/widgets/glass_look.dart';

void main() {
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
}
