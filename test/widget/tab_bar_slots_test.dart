import 'package:ekadashi_calendar/widgets/tab_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A page that owns its TabBarSlots (Panchang pushed from Search) can be
/// disposed while a refresh is still scheduled for the next frame.
void main() {
  testWidgets('a refresh scheduled before dispose does nothing', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final slots = TabBarSlots();
    var notified = 0;
    slots.addListener(() => notified++);
    slots.attach(leading: (_) => const Text('Today'));
    slots.dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(notified, 0);
  });
}
