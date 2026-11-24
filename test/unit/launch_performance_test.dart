import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/l10n/place_names.dart';
import 'package:ekadashi_calendar/services/ekadashi_schedule.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_location_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android launch (24 November 2026): Home waited for every year of a new
/// place to be calculated one after another, and the UI isolate stalled
/// while the 34,152-city catalog (cities.json, 2.6 MB) and the place-name
/// table (place_names.json, 1.1 MB) were decoded at launch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('years of a place are calculated together', () {
    test('every year starts before the first one finishes', () async {
      final started = <int>[];
      final pending = <int, Completer<List<ScheduledEkadashi>>>{};
      final schedule = EkadashiSchedule(
        publishedRows: (_) => const [],
        persist: false,
        calculator: (key, rows) {
          started.add(key.year);
          return (pending[key.year] = Completer()).future;
        },
      );
      const city = testCity;
      final all = schedule.scheduledYears(
        city,
        EkadashiTradition.smarta,
        const [2026, 2027],
      );
      await Future<void>.delayed(Duration.zero);
      expect(started, [2026, 2027], reason: 'both years run at once');

      // Finishing out of order still returns the years in order.
      pending[2027]!.complete(const []);
      pending[2026]!.complete(const []);
      final years = await all;
      expect(years.length, 2);
      expect(
        schedule.isCachedInMemory(
          const EkadashiScheduleKey(city, EkadashiTradition.smarta, 2026),
        ),
        isTrue,
      );
      expect(
        schedule.isCachedInMemory(
          const EkadashiScheduleKey(city, EkadashiTradition.smarta, 2027),
        ),
        isTrue,
      );
    });

    test('a year already calculated is not calculated again', () async {
      var calls = 0;
      final schedule = EkadashiSchedule(
        publishedRows: (_) => const [],
        persist: false,
        calculator: (key, rows) async {
          calls++;
          return const [];
        },
      );
      const city = testCity;
      await schedule.scheduledYears(city, EkadashiTradition.gaudiya, const [
        2026,
      ]);
      await schedule.scheduledYears(city, EkadashiTradition.gaudiya, const [
        2026,
        2027,
      ]);
      expect(calls, 2);
    });
  });

  group('the catalogs are decoded off the UI isolate', () {
    setUpAll(() {
      PanchangLocationStore.buildIndexInline = false;
      PlaceNames.decodeInline = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
            final key = utf8.decode(message!.buffer.asUint8List());
            return ByteData.sublistView(File(key).readAsBytesSync());
          });
    });

    /// The longest the UI isolate went without running a 1 ms timer while
    /// [work] ran.
    Future<int> longestStall(Future<void> Function() work) async {
      final clock = Stopwatch()..start();
      var last = 0, longest = 0;
      final ticker = Timer.periodic(const Duration(milliseconds: 1), (_) {
        final now = clock.elapsedMilliseconds;
        if (now - last > longest) longest = now - last;
        last = now;
      });
      await work();
      final now = clock.elapsedMilliseconds;
      if (now - last > longest) longest = now - last;
      ticker.cancel();
      return longest;
    }

    test('the city catalog', () async {
      final stall = await longestStall(PanchangLocationStore.cities);
      final cities = await PanchangLocationStore.cities();
      expect(cities.length, greaterThan(30000));
      final chennai = cities.firstWhere((c) => c.id == 'geonames-1264527');
      expect(chennai.label, 'Chennai (IN)');
      expect(chennai.timeZoneId, 'Asia/Kolkata');
      expect(chennai.searchTerms, contains('chennai'));
      expect(stall, lessThan(60), reason: 'UI isolate stalled ${stall}ms');
    });

    test('the place-name table', () async {
      final stall = await longestStall(PlaceNames.load);
      expect(PlaceNames.place('Chennai', 'ta'), 'சென்னை');
      expect(PlaceNames.country('IN', 'hi'), isNot('IN'));
      expect(stall, lessThan(60), reason: 'UI isolate stalled ${stall}ms');
    });
  });
}

const testCity = PanchangCity(
  id: 'detected',
  label: 'Chennai (IN)',
  latitude: 13.08,
  longitude: 80.27,
);
