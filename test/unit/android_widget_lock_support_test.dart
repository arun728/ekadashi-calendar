import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final file in [
    'ekadashi_widget_info',
    'widget_ekadashi_today_info',
    'widget_upcoming_ekadashis_info',
  ]) {
    test('$file supports native Home and Lock Screen hosts', () {
      final source = File(
        'android/app/src/main/res/xml/$file.xml',
      ).readAsStringSync();
      expect(source, contains('android:widgetCategory="home_screen|keyguard"'));
      expect(source, contains('android:initialKeyguardLayout='));
      expect(source, isNot(contains('not_keyguard')));
    });
  }
}
