import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final config = File('ios-native/Config/App.xcconfig').readAsStringSync();
  final spec = File('ios-native/project.yml').readAsStringSync();

  test(
    'app and widget entitlements resolve to the company shared container',
    () {
      final group = RegExp(
        r'^APP_GROUP = (.+)$',
        multiLine: true,
      ).firstMatch(config)!.group(1)!;
      expect(group, 'group.com.apptinel.ekadashi-calendar');
      for (final target in ['EkadashiCalendar', 'EkadashiWidgets']) {
        final entitlements = File(
          'ios-native/$target/$target.entitlements',
        ).readAsStringSync();
        expect(entitlements, contains(r'<string>$(APP_GROUP)</string>'));
        expect(
          entitlements.replaceAll(r'$(APP_GROUP)', group),
          contains('<string>group.com.apptinel.ekadashi-calendar</string>'),
        );
      }
      // Runtime UserDefaults and signing must read the same build setting.
      expect(
        RegExp(r'EkadashiAppGroup: \$\(APP_GROUP\)').allMatches(spec),
        hasLength(2),
      );
      expect(
        RegExp(r'application-groups: \[\$\(APP_GROUP\)\]').allMatches(spec),
        hasLength(2),
      );
    },
  );

  test('regeneration preserves both company bundle identifiers', () {
    expect(spec, contains('bundleIdPrefix: com.apptinel'));
    expect(
      spec,
      contains('PRODUCT_BUNDLE_IDENTIFIER: com.apptinel.ekadashi-calendar\n'),
    );
    expect(
      spec,
      contains(
        'PRODUCT_BUNDLE_IDENTIFIER: com.apptinel.ekadashi-calendar.widgets\n',
      ),
    );
  });

  test('company signing team remains a local configuration override', () {
    expect(config, contains('#include? "Secrets.xcconfig"'));
    expect(
      File('ios-native/.gitignore').readAsStringSync(),
      contains('Config/Secrets.xcconfig'),
    );
    expect(spec, isNot(contains('DEVELOPMENT_TEAM:')));
  });
}
