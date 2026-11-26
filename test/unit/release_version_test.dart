import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Item 10 (25 Nov 2026): the v2 release build must have a version code above
/// every build already on Google Play (internal testing has 12 since 26 Nov
/// 2026; production 4) and the local debug builds (11).
void main() {
  test('v2.0.0 with a version code above every Play upload', () {
    final line = File(
      'pubspec.yaml',
    ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final match = RegExp(r'version: (\d+\.\d+\.\d+)\+(\d+)').firstMatch(line)!;
    expect(match.group(1), '2.0.0');
    expect(int.parse(match.group(2)!), greaterThanOrEqualTo(13));
  });
}
