import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/widgets/app_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Both apps show the same icon in every place (docs/ICONS.md): the roles in
/// test/fixtures/app_icons.json name an SF Symbol for iOS (AppSymbol, checked
/// by AppSymbolTests) and its CupertinoIcons twin for Android (AppIcons).
/// Screens never pick an icon outside the table.
void main() {
  final fixture =
      jsonDecode(File('test/fixtures/app_icons.json').readAsStringSync())
          as Map<String, dynamic>;
  final roles = (fixture['roles'] as Map).cast<String, String>();
  final symbols = (fixture['symbols'] as Map).cast<String, String>();

  test('every role shows the twin of its iOS symbol', () {
    expect(AppIcons.all.keys.toSet(), roles.keys.toSet());
    for (final MapEntry(key: role, value: sf) in roles.entries) {
      final twin = symbols[sf];
      expect(twin, isNotNull, reason: '$sf has an Android twin');
      expect(AppIcons.all[role], _byName[twin], reason: '$role ($sf → $twin)');
    }
  });

  test('the tab bar: house, calendar, rosette, sparkles, gear', () {
    expect(roles['tab_home'], 'house.fill');
    expect(roles['tab_calendar'], 'calendar');
    // Journey shows progress and achievements: an award rosette, not a leaf.
    expect(roles['tab_journey'], 'rosette');
    expect(roles['tab_panchang'], 'sparkles');
    expect(roles['tab_settings'], 'gearshape.fill');
  });

  test('screens take every icon from AppIcons', () {
    final offenders = <String>[];
    final direct = RegExp(r'\b(Icons|CupertinoIcons)\.[a-z_0-9]+');
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('app_icons.dart') ||
          file.path.contains('/generated/')) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (final (index, line) in lines.indexed) {
        if (line.trimLeft().startsWith('//')) continue;
        for (final match in direct.allMatches(line)) {
          offenders.add('${file.path}:${index + 1} ${match[0]}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}

/// The Android twins named in the fixture.
const _byName = <String, IconData>{
  'arrow_2_circlepath': CupertinoIcons.arrow_2_circlepath,
  'arrow_2_circlepath_circle': CupertinoIcons.arrow_2_circlepath_circle,
  'arrow_clockwise_circle': CupertinoIcons.arrow_clockwise_circle,
  'arrow_up_right_square': CupertinoIcons.arrow_up_right_square,
  'bell': CupertinoIcons.bell,
  'bolt_fill': CupertinoIcons.bolt_fill,
  'calendar': CupertinoIcons.calendar,
  'calendar_badge_minus': CupertinoIcons.calendar_badge_minus,
  'calendar_badge_plus': CupertinoIcons.calendar_badge_plus,
  'calendar_circle': CupertinoIcons.calendar_circle,
  'chart_pie': CupertinoIcons.chart_pie,
  'checkmark': CupertinoIcons.checkmark,
  'checkmark_circle': CupertinoIcons.checkmark_circle,
  'checkmark_circle_fill': CupertinoIcons.checkmark_circle_fill,
  'checkmark_seal_fill': CupertinoIcons.checkmark_seal_fill,
  'chevron_back': CupertinoIcons.chevron_back,
  'chevron_down': CupertinoIcons.chevron_down,
  'chevron_left': CupertinoIcons.chevron_left,
  'chevron_right': CupertinoIcons.chevron_right,
  'circle_fill': CupertinoIcons.circle_fill,
  'circle_grid_3x3': CupertinoIcons.circle_grid_3x3,
  'circle_grid_hex': CupertinoIcons.circle_grid_hex,
  'circle_lefthalf_fill': CupertinoIcons.circle_lefthalf_fill,
  'clock': CupertinoIcons.clock,
  'exclamationmark_circle': CupertinoIcons.exclamationmark_circle,
  'exclamationmark_triangle': CupertinoIcons.exclamationmark_triangle,
  'flag': CupertinoIcons.flag,
  'flame': CupertinoIcons.flame,
  'gear_alt': CupertinoIcons.gear_alt,
  'gear_alt_fill': CupertinoIcons.gear_alt_fill,
  'globe': CupertinoIcons.globe,
  'hexagon': CupertinoIcons.hexagon,
  'hourglass': CupertinoIcons.hourglass,
  'house_fill': CupertinoIcons.house_fill,
  'info_circle': CupertinoIcons.info_circle,
  'list_bullet_below_rectangle': CupertinoIcons.list_bullet_below_rectangle,
  'location': CupertinoIcons.location,
  'location_fill': CupertinoIcons.location_fill,
  'lock': CupertinoIcons.lock,
  'lock_fill': CupertinoIcons.lock_fill,
  'map_pin_ellipse': CupertinoIcons.map_pin_ellipse,
  'material:eco': Icons.eco,
  'moon': CupertinoIcons.moon,
  'moon_fill': CupertinoIcons.moon_fill,
  'moon_stars': CupertinoIcons.moon_stars,
  'pencil': CupertinoIcons.pencil,
  'person_crop_circle': CupertinoIcons.person_crop_circle,
  'person_crop_circle_badge_minus':
      CupertinoIcons.person_crop_circle_badge_minus,
  'plus': CupertinoIcons.plus,
  'plus_circle_fill': CupertinoIcons.plus_circle_fill,
  'question_circle': CupertinoIcons.question_circle,
  'rosette': CupertinoIcons.rosette,
  'search': CupertinoIcons.search,
  'sparkles': CupertinoIcons.sparkles,
  'square_arrow_down': CupertinoIcons.square_arrow_down,
  'square_arrow_up': CupertinoIcons.square_arrow_up,
  'square_grid_2x2': CupertinoIcons.square_grid_2x2,
  'square_on_circle': CupertinoIcons.square_on_circle,
  'star': CupertinoIcons.star,
  'star_circle_fill': CupertinoIcons.star_circle_fill,
  'star_fill': CupertinoIcons.star_fill,
  'sun_max': CupertinoIcons.sun_max,
  'sun_max_fill': CupertinoIcons.sun_max_fill,
  'sunrise': CupertinoIcons.sunrise,
  'sunrise_fill': CupertinoIcons.sunrise_fill,
  'sunset': CupertinoIcons.sunset,
  'sunset_fill': CupertinoIcons.sunset_fill,
  'trash': CupertinoIcons.trash,
  'xmark': CupertinoIcons.xmark,
  'xmark_circle': CupertinoIcons.xmark_circle,
  'xmark_circle_fill': CupertinoIcons.xmark_circle_fill,
};
