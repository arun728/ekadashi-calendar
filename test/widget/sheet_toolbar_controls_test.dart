import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:ekadashi_calendar/widgets/glass_look.dart';

void main() {
  for (final enabled in [false, true]) {
    testWidgets('sheet Cancel and Save keep glass capsules and 44 point height: $enabled', (tester) async {
      var closed = false;
      await tester.pumpWidget(MaterialApp(home: GlassLook(enabled: enabled, child: Scaffold(body: SheetBar(title: 'Editor', leading: BarTextButton(label: 'Cancel', onPressed: () => closed = true), trailing: BarTextButton(label: 'Save', onPressed: () {}, bold: true))))));
      for (final label in ['Cancel', 'Save']) {
        final button = find.widgetWithText(TextButton, label);
        expect(find.ancestor(of: button, matching: find.byType(GlassPanel)), findsOneWidget);
        expect(tester.getSize(button).height, 44);
      }
      await tester.tap(find.text('Cancel'));
      expect(closed, isTrue);
    });
  }
}
