import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/widgets/adaptive_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wide screens (Android foldables and tablets, the iPhone Duo's inner
/// screen) show two panes side by side (docs/FOLDABLES.md). Both apps take
/// the rule from test/fixtures/adaptive_layout.json (AdaptiveLayoutTests on
/// iOS).
void main() {
  final fixture =
      jsonDecode(File('test/fixtures/adaptive_layout.json').readAsStringSync())
          as Map<String, dynamic>;

  test('the rule is the shared table', () {
    expect(AdaptiveLayout.twoPaneMinWidth, fixture['twoPaneMinWidth']);
    expect(AdaptiveLayout.readableMaxWidth, fixture['readableMaxWidth']);
    expect(AdaptiveLayout.paneSpacing, fixture['paneSpacing']);
  });

  test('every width gets the shared panes and readable width', () {
    for (final item in (fixture['cases'] as List).cast<Map>()) {
      final width = (item['width'] as num).toDouble();
      expect(
        AdaptiveLayout.panes(width).columns,
        item['panes'],
        reason: item['name'] as String,
      );
      expect(
        AdaptiveLayout.readableWidth(width),
        (item['readableWidth'] as num).toDouble(),
        reason: item['name'] as String,
      );
    }
  });

  test('phones keep one pane and a foldable inner screen gets two', () {
    expect(AdaptiveLayout.panes(393), PaneLayout.single);
    expect(AdaptiveLayout.panes(466), PaneLayout.single);
    expect(AdaptiveLayout.panes(669), PaneLayout.sideBySide);
    expect(AdaptiveLayout.panes(951), PaneLayout.sideBySide);
    expect(AdaptiveLayout.panes(669).isSideBySide, isTrue);
    expect(AdaptiveLayout.panes(402).isSideBySide, isFalse);
  });

  test('an unmeasured or nonsense width keeps one pane', () {
    for (final width in [-1.0, 0.0, double.nan, double.negativeInfinity]) {
      expect(AdaptiveLayout.panes(width), PaneLayout.single, reason: '$width');
      expect(AdaptiveLayout.readableWidth(width), 0, reason: '$width');
    }
    expect(AdaptiveLayout.panes(double.infinity), PaneLayout.sideBySide);
    expect(
      AdaptiveLayout.readableWidth(double.infinity),
      AdaptiveLayout.readableMaxWidth,
    );
  });

  test('the side margin centres the readable width', () {
    expect(AdaptiveLayout.sideMargin(402), 0);
    expect(AdaptiveLayout.sideMargin(720), 0);
    expect(AdaptiveLayout.sideMargin(951), 115.5);
    expect(AdaptiveLayout.sideMargin(double.nan), 0);
  });

  /// As on iOS (AdaptiveSourceTests): layout comes from the space a screen
  /// is given, never from the orientation.
  test('no screen chooses its layout from the orientation', () {
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('main.dart')) continue; // the phone lock
      final text = file.readAsStringSync();
      expect(text.contains('.orientation'), isFalse, reason: file.path);
      expect(text.contains('Orientation.'), isFalse, reason: file.path);
    }
  });
}
