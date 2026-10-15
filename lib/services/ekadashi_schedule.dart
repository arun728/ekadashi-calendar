import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'time_zone_data.dart';

import 'panchang/calculated_ekadashi.dart';
import 'panchang/panchang_city.dart';

/// The years the app shows Ekadashis for (assets/calendar/ekadashi_years.json).
/// Adding a year there is all a release needs: the engine supplies its dates
/// and times, and the texts come from the year packs by Ekadashi.
class EkadashiYears {
  static const fallback = [2026, 2027];

  static List<int> parse(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      if (map['schema_version'] != 1) return fallback;
      final years = (map['enabled_years'] as List).cast<int>().toList()..sort();
      return years.isEmpty ? fallback : years;
    } catch (_) {
      return fallback;
    }
  }

  /// Reads the enabled years once; later calls reuse them.
  static Future<List<int>> load() async {
    final known = _loaded;
    if (known != null) return known;
    List<int> years;
    try {
      years = parse(
        await rootBundle.loadString('assets/calendar/ekadashi_years.json'),
      );
    } catch (_) {
      years = fallback;
    }
    return _loaded = years;
  }

  static List<int>? _loaded;

  /// The year to open: this year when enabled, else the nearest enabled one.
  static int defaultYear(DateTime today, List<int> enabled) {
    if (enabled.contains(today.year)) return today.year;
    final sorted = [
      ...enabled,
    ]..sort((a, b) => (a - today.year).abs().compareTo((b - today.year).abs()));
    return sorted.isEmpty ? today.year : sorted.first;
  }
}

/// One calculated Ekadashi for a city and tradition, before any language:
/// the part that is cached.
class ScheduledEkadashi {
  const ScheduledEkadashi({
    required this.occurrenceUid,
    required this.notificationId,
    required this.legacyId,
    required this.contentId,
    required this.publishedUid,
    required this.date,
    required this.fastingStart,
    required this.paranaStart,
    required this.paranaEnd,
    required this.paksha,
    required this.month,
    required this.rule,
    this.contextExpiresAt,
  });

  final String occurrenceUid;
  final int notificationId;
  final int legacyId;
  final String contentId;

  /// The published row this fast keeps the identity and texts of, if any.
  final String? publishedUid;
  final String date;
  final String fastingStart;
  final String paranaStart;
  final String paranaEnd;
  final String paksha;
  final String month;
  final String rule;

  /// Widget context expiry, separate from an unknown religious Parana end.
  final String? contextExpiresAt;

  Map<String, dynamic> toJson() => {
    'occurrenceUid': occurrenceUid,
    'notificationId': notificationId,
    'legacyId': legacyId,
    'contentId': contentId,
    'publishedUid': publishedUid,
    'date': date,
    'fastingStart': fastingStart,
    'paranaStart': paranaStart,
    'paranaEnd': paranaEnd,
    'paksha': paksha,
    'month': month,
    'rule': rule,
    'contextExpiresAt': contextExpiresAt,
  };

  factory ScheduledEkadashi.fromJson(Map<String, dynamic> json) =>
      ScheduledEkadashi(
        occurrenceUid: json['occurrenceUid'] as String,
        notificationId: json['notificationId'] as int,
        legacyId: json['legacyId'] as int,
        contentId: json['contentId'] as String,
        publishedUid: json['publishedUid'] as String?,
        date: json['date'] as String,
        fastingStart: json['fastingStart'] as String,
        paranaStart: json['paranaStart'] as String,
        paranaEnd: json['paranaEnd'] as String,
        paksha: json['paksha'] as String,
        month: json['month'] as String,
        rule: json['rule'] as String,
        contextExpiresAt: json['contextExpiresAt'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is ScheduledEkadashi &&
      jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// Where the Ekadashi times are calculated.
class EkadashiScheduleKey {
  const EkadashiScheduleKey(this.city, this.tradition, this.year);
  final PanchangCity city;
  final EkadashiTradition tradition;
  final int year;

  /// A stable key, also used for the stored cache.
  String get cacheId =>
      '${EkadashiSchedule.formatVersion}|${CalculatedEkadashi.ruleVersion}|'
      '$timeZoneDataRelease|${tradition.name}|$year|${city.id}_${city.latitude}_'
      '${city.longitude}_${city.timeZoneId}';
}

/// Ekadashi dates and times from the Panchang engine for any city and
/// tradition, with the published identities (EkadashiSchedule.swift).
///
/// - Dates, fasting start and Parana come from [CalculatedEkadashiEngine] at
///   the city's sunrise in its own time zone, cut to the minute exactly as
///   the Panchang tab shows them.
/// - In a year with a published pack, each fast keeps the identity
///   (`occurrence_uid`, notification id) of the published row of the same
///   Ekadashi within three days, so Vrat history and reminders stay
///   attached. A fast the pack lacks (Saphala on 23 Dec 2027) gets the next
///   number of that year; years without a pack are numbered in date order.
class EkadashiSchedule {
  EkadashiSchedule({required this.publishedRows, this.persist = true});

  /// Bumped when the cached form changes, so older caches are recalculated.
  static const formatVersion = 'schedule-3';

  /// The published rows of a year (identities and texts).
  final List<Map<String, dynamic>> Function(int year) publishedRows;
  final bool persist;
  final _memory = <String, List<ScheduledEkadashi>>{};
  final _running = <String, Future<List<ScheduledEkadashi>>>{};

  /// Calculates in the calling isolate (widget tests, where isolates do not
  /// run under fake async).
  static bool calculateInline = false;

  /// The content id of an engine name ("Devutthana" is published as Prabodhini).
  static String contentIdForEngineName(String name) {
    final id = name.toLowerCase().replaceAll(' ', '-');
    return id == 'devutthana-ekadashi' ? 'prabodhini-ekadashi' : id;
  }

  /// The `lunar_month_` key of an engine month ("Ashvina" → ashwin).
  static String monthKey(String month) {
    if (month.startsWith('Adhika')) return 'adhika';
    final key = month.toLowerCase();
    return const {'ashvina': 'ashwin', 'kartika': 'kartik'}[key] ?? key;
  }

  bool isCachedInMemory(EkadashiScheduleKey key) =>
      _memory.containsKey(key.cacheId);

  /// What [scheduled] already calculated, without calculating.
  List<ScheduledEkadashi>? cached(EkadashiScheduleKey key) =>
      _memory[key.cacheId];

  /// The fasts of one year at one place: calculated once off the UI thread,
  /// then cached in memory and on the phone.
  Future<List<ScheduledEkadashi>> scheduled(EkadashiScheduleKey key) {
    final id = key.cacheId;
    final hit = _memory[id];
    if (hit != null) return Future.value(hit);
    // Two screens asking at once share one calculation.
    return _running[id] ??= _load(key).whenComplete(() {
      _running.remove(id);
    });
  }

  Future<List<ScheduledEkadashi>> _load(EkadashiScheduleKey key) async {
    final id = key.cacheId;
    SharedPreferences? prefs;
    if (persist) {
      prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('ekadashi_schedule|$id');
      if (stored != null) {
        try {
          final list = (jsonDecode(stored) as List)
              .map((e) => ScheduledEkadashi.fromJson(e as Map<String, dynamic>))
              .toList();
          return _memory[id] = list;
        } catch (_) {}
      }
    }
    final rows = publishedRows(key.year);
    final list = calculateInline
        ? calculate(key, rows)
        : await Isolate.run(() => calculate(key, rows));
    _memory[id] = list;
    await prefs?.setString(
      'ekadashi_schedule|$id',
      jsonEncode([for (final e in list) e.toJson()]),
    );
    return list;
  }

  /// The calculation itself (pure; tests call it directly).
  static List<ScheduledEkadashi> calculate(
    EkadashiScheduleKey key,
    List<Map<String, dynamic>> published,
  ) {
    final start = DateTime.utc(key.year);
    final days = DateTime.utc(key.year + 1).difference(start).inDays;
    final fasts = const CalculatedEkadashiEngine().calculate(
      start,
      days,
      key.city,
      key.tradition,
    );
    final unused = {for (var i = 0; i < published.length; i++) i};
    var nextNumber = published
        .map(
          (r) =>
              int.tryParse((r['occurrence_uid'] as String).split(':').last) ??
              0,
        )
        .fold(0, (a, b) => a > b ? a : b);
    final result = <ScheduledEkadashi>[];
    for (var ordinal = 0; ordinal < fasts.length; ordinal++) {
      final fast = fasts[ordinal];
      final contentId = contentIdForEngineName(fast.name);
      int? match;
      var best = 4;
      for (final i in unused) {
        if (published[i]['content_id'] != contentId) continue;
        final date = DateTime.tryParse(
          (published[i]['timing']?['IST']?['date'] as String?) ?? '',
        );
        if (date == null) continue;
        final gap = DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).difference(fast.date).inDays.abs();
        if (gap <= 3 && gap < best) {
          best = gap;
          match = i;
        }
      }
      String uid;
      int notificationId, legacyId;
      final paksha = fast.isShukla ? 'shukla' : 'krishna';
      final month = monthKey(fast.month);
      if (match != null) {
        unused.remove(match);
        final row = published[match];
        uid = row['occurrence_uid'] as String;
        notificationId = row['notification_id'] as int;
        legacyId = (row['legacy_id'] as int?) ?? notificationId;
      } else {
        final number = published.isEmpty ? ordinal + 1 : ++nextNumber;
        uid = 'ekadashi:${key.year}:${number.toString().padLeft(2, '0')}';
        notificationId = key.year * 1000 + number;
        legacyId = number;
      }
      final end = fast.paranaEndUtc;
      result.add(
        ScheduledEkadashi(
          occurrenceUid: uid,
          notificationId: notificationId,
          legacyId: legacyId,
          contentId: contentId,
          publishedUid: match == null ? null : uid,
          date: _isoDate(fast.date),
          fastingStart: iso(fast.fastStartsUtc, key.city),
          paranaStart: fast.paranaStartUtc == null
              ? ''
              : iso(fast.paranaStartUtc!, key.city),
          paranaEnd: end == null ? '' : iso(end, key.city, roundUp: false),
          paksha: paksha,
          month: month,
          rule: fast.rule,
          contextExpiresAt: end == null && fast.paranaStartUtc != null
              ? iso(
                  key.city.midnight(
                    key.city.wallClock(fast.paranaStartUtc!),
                    dayOffset: 1,
                  ),
                  key.city,
                  roundUp: false,
                )
              : null,
        ),
      );
    }
    return result;
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  /// Millisecond ISO time. Starts round inward (up), ends down, so saving
  /// a schedule cannot open a window before the calculated boundary.
  static String iso(
    DateTime instant,
    PanchangCity city, {
    bool roundUp = true,
  }) {
    final micros = instant.toUtc().microsecondsSinceEpoch;
    var millis = micros ~/ 1000;
    if (micros < 0 && micros % 1000 != 0) millis--;
    if (roundUp && micros % 1000 != 0) millis++;
    final wall = city.wallClock(
      DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
    );
    final offset = wall.timeZoneOffset;
    final minutes = offset.inMinutes.abs();
    final sign = offset.isNegative ? '-' : '+';
    return '${_isoDate(wall)}T${_two(wall.hour)}:${_two(wall.minute)}:${_two(wall.second)}.${wall.millisecond.toString().padLeft(3, '0')}'
        '$sign${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
  }
}
