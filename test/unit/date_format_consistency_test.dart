import 'dart:io';

import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Every tab and sub-tab shows a date the same way, with the weekday, date,
/// month and year ("Thu, 8 Oct 2026"), on Android and iOS alike.
void main() {
  setUpAll(initializeDateFormatting);

  test('the shared full date has the weekday, date, month and year', () {
    expect(AppStrings.fullDate(DateTime(2026, 10, 8), 'en'), 'Thu, 8 Oct 2026');
    expect(
      AppStrings.fullDate(DateTime(2026, 10, 8), 'hi'),
      isNot(contains('Oct')),
    );
  });

  test('no screen formats a date another way', () {
    // Other patterns that drop the weekday or spell it differently.
    final other = RegExp(
      r"""['"](MMM dd, yyyy|EEEE, d MMMM yyyy|EEEE|LLLL yyyy|MMMM yyyy|d MMMM yyyy)['"]|DateFormat\.yMMMM\(|PanchangFormat\.monthTitle\(""",
    );
    final offenders = <String>[];
    for (final dir in [
      'lib/screens',
      'lib/main.dart',
      'ios-native/EkadashiCalendar/Features',
    ]) {
      final entity = FileSystemEntity.typeSync(dir) == FileSystemEntityType.file
          ? [File(dir)]
          : Directory(dir).listSync(recursive: true).whereType<File>();
      for (final file in entity) {
        if (!file.path.endsWith('.dart') && !file.path.endsWith('.swift')) {
          continue;
        }
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (other.hasMatch(lines[i])) offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
