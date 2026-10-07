import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_location_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'loading complete city zones preserves notification scheduling timezone',
    () {
      data.initializeTimeZones();
      final zone = tz.getLocation('America/New_York');
      tz.setLocalLocation(zone);
      PanchangCity.newDelhi.zone;
      expect(tz.local, same(zone));
    },
  );
  test(
    'offline city catalog has valid coordinates and usable IANA zones',
    () async {
      final cities = await PanchangLocationStore.cities();
      expect(cities.length, greaterThan(30000));
      for (final city in cities) {
        expect(
          city.validate,
          returnsNormally,
          reason: '${city.label} ${city.timeZoneId}',
        );
      }
      expect(cities.any((c) => c.label.contains('Kathmandu')), isTrue);
    },
  );
  test(
    'custom location survives reload; corrupt storage falls back safely',
    () async {
      final store = PanchangLocationStore();
      await store.save(PanchangCity.newYork);
      expect(await store.load(), PanchangCity.newYork);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PanchangLocationStore.key, '{broken');
      expect(await store.load(), isNull);
    },
  );
}
