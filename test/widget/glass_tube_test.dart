import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/widgets/glass_tube.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('$brightness unselected chip lets the glass show through', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: GlassTube(
              optionCount: 2,
              child: GlassFilterChip(
                label: const Text('Option'),
                selected: false,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      final material = find
          .descendant(
            of: find.byType(FilterChip),
            matching: find.byType(Material),
          )
          .first;
      final widget = tester.widget<Material>(material);
      expect(
        widget.color ?? Theme.of(tester.element(material)).canvasColor,
        Colors.transparent,
      );
    });
    for (final count in [2, 3, 5]) {
      testWidgets(
        '$brightness $count options preserve activation at large text',
        (tester) async {
          var chosen = 0;
          var calls = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 320,
                      child: StatefulBuilder(
                        builder: (context, setState) => GlassTube(
                          optionCount: count,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (var i = 0; i < count; i++)
                                  GlassFilterChip(
                                    label: Text('Option $i'),
                                    selected: chosen == i,
                                    onSelected: i == count - 1
                                        ? null
                                        : (_) {
                                            calls++;
                                            setState(() => chosen = i);
                                          },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final first = tester.widget<FilterChip>(
            find.byType(FilterChip).first,
          );
          expect(first.selectedColor, isNot(Colors.black));
          expect(first.selectedColor!.a, lessThan(.3));
          expect(first.labelStyle!.color, GlassTubeColors.teal);
          final enabled = count > 2 ? 1 : 0;
          await tester.ensureVisible(find.text('Option $enabled'));
          await tester.tap(find.text('Option $enabled'));
          await tester.pumpAndSettle();
          expect(calls, 1);
          expect(
            tester
                .widget<FilterChip>(find.byType(FilterChip).at(enabled))
                .selected,
            isTrue,
          );
          final disabled = find.text('Option ${count - 1}');
          await tester.ensureVisible(disabled);
          await tester.tap(disabled);
          await tester.pumpAndSettle();
          expect(calls, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
