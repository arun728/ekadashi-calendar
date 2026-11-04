import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pull a sheet down from its close control, then fling at 1200 px/s.
Future<void> flingSheetDown(WidgetTester tester, Finder closeControl) async {
  // The default fling pumps its first frame after only 13 px of movement.
  // A slow live screenshot frame can then let the control's Tooltip claim
  // a long press before the drag crosses touch slop. Establish the drag
  // before pumping, retaining the same total 650 px downward movement.
  const initial = kTouchSlop * 2;
  await tester.fling(
    closeControl,
    const Offset(0, 650 - initial),
    1200,
    initialOffset: const Offset(0, initial),
    initialOffsetDelay: Duration.zero,
  );
}
