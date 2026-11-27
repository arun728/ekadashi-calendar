import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/services/ekadashi_settings.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/native_location_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_location_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home's detected city (AppModel.city(from:) on iOS), also when the city
/// catalog cannot be read.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var catalogAvailable = false;

  setUp(() {
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key != 'assets/panchang/cities.json' || !catalogAvailable) {
        return null;
      }
      return ByteData.sublistView(
        File('assets/panchang/cities.json').readAsBytesSync(),
      );
    });
  });
  tearDown(() => messenger.setMockMessageHandler('flutter/assets', null));

  LocationData fix(String city) => LocationData(
    latitude: 13.0827,
    longitude: 80.2707,
    city: city,
    timezone: 'IST',
  );

  test('a detected place without the catalog still becomes a city, and the '
      'catalog is read again later', () async {
    catalogAvailable = false;
    final offline = await EkadashiSettings.cityFromFix(fix('Chennai'));
    expect(offline, isNotNull);
    expect(offline!.label, 'Chennai');
    expect(offline.timeZoneId, 'Asia/Kolkata');
    expect(offline.latitude, 13.08);
    expect(offline.longitude, 80.27);

    // A failed read is not remembered: the next lookup finds the catalog.
    catalogAvailable = true;
    final online = await EkadashiSettings.cityFromFix(fix('Chennai'));
    expect(online!.label, 'Chennai (IN)');
    expect(online.id, EkadashiSettings.detectedCityId);
    expect((await PanchangLocationStore.cities()), isNotEmpty);
  });

  test('Chennai until something is picked or detected; saved settings come '
      'back after a restart', () async {
    SharedPreferences.setMockInitialValues({});
    catalogAvailable = true;
    final first = EkadashiSettings();
    await first.load();
    expect(first.city, EkadashiSettings.defaultCity);
    expect(first.city.label, 'Chennai (IN)');
    expect(first.isManual, isFalse);
    expect(first.tradition, EkadashiTradition.gaudiya);
    expect(first.years, [2026, 2027]);

    await first.setTradition(EkadashiTradition.smarta);
    await first.setYear(2027);
    await first.setYear(2031); // not enabled: ignored
    expect(first.year, 2027);
    expect(first.traditionNameKey, 'tradition_smarta');

    final again = EkadashiSettings();
    await again.load();
    expect(again.tradition, EkadashiTradition.smarta);
    expect(again.year, 2027);
  });

  test('a city picked on Home wins over detection and moves the Panchang '
      'tab; "Use current location" lets detection decide again', () async {
    SharedPreferences.setMockInitialValues({});
    catalogAvailable = true;
    final settings = EkadashiSettings();
    await settings.load();
    const london = PanchangCity(
      id: 'geonames-2643743',
      label: 'London (GB)',
      latitude: 51.50853,
      longitude: -0.12574,
      timeZoneId: 'Europe/London',
    );
    final revision = settings.panchangCityRevision;
    await settings.chooseCity(london);
    expect(settings.city, london);
    expect(settings.isManual, isTrue);
    expect(settings.panchangCityRevision, greaterThan(revision));
    expect(await PanchangLocationStore().load(), london);
    expect((await RecentCities.all()).first, london);

    // Detection does not replace a picked city.
    expect(await settings.useDetected(fix('Chennai')), isFalse);
    expect(settings.city, london);

    await settings.clearManual();
    expect(await settings.useDetected(fix('Chennai')), isTrue);
    expect(settings.city.label, 'Chennai (IN)');
    expect(settings.city.timeZoneId, 'Asia/Kolkata');
    // The Panchang tab keeps the place set there (London).
    expect(await PanchangLocationStore().load(), london);

    final restarted = EkadashiSettings();
    await restarted.load();
    expect(restarted.city.label, 'Chennai (IN)');
    expect(restarted.isManual, isFalse);
  });

  const sanJose = PanchangCity(
    id: 'geonames-5392171',
    label: 'San Jose (US)',
    latitude: 37.33939,
    longitude: -121.89496,
    timeZoneId: 'America/Los_Angeles',
  );

  test('reopening the app detects the place again, even after a city was '
      'picked on Home, and Panchang follows Home', () async {
    SharedPreferences.setMockInitialValues({});
    catalogAvailable = true;
    final settings = EkadashiSettings();
    await settings.load();
    await settings.chooseCity(sanJose);
    expect(settings.isManual, isTrue);

    // A launch: the place found now replaces the picked city.
    final reopened = EkadashiSettings();
    await reopened.load();
    final revision = reopened.panchangCityRevision;
    expect(await reopened.useDetected(fix('Chennai'), atLaunch: true), isTrue);
    expect(reopened.city.label, 'Chennai (IN)');
    expect(reopened.isManual, isFalse);
    // Panchang showed Home's city, so it moves with Home.
    expect((await PanchangLocationStore().load())?.label, 'Chennai (IN)');
    expect(reopened.panchangCityRevision, greaterThan(revision));
  });

  test(
    'a launch keeps a Panchang city that was set on the Panchang tab',
    () async {
      SharedPreferences.setMockInitialValues({});
      catalogAvailable = true;
      final settings = EkadashiSettings();
      await settings.load();
      await settings.chooseCity(sanJose);
      const london = PanchangCity(
        id: 'geonames-2643743',
        label: 'London (GB)',
        latitude: 51.50853,
        longitude: -0.12574,
        timeZoneId: 'Europe/London',
      );
      await PanchangLocationStore().save(london);
      await settings.useDetected(fix('Chennai'), atLaunch: true);
      expect(settings.city.label, 'Chennai (IN)');
      expect(await PanchangLocationStore().load(), london);
    },
  );

  test('the first detected place also starts the Panchang tab', () async {
    SharedPreferences.setMockInitialValues({});
    catalogAvailable = true;
    final settings = EkadashiSettings();
    await settings.load();
    await settings.useDetected(fix('Chennai'));
    expect((await PanchangLocationStore().load())?.label, 'Chennai (IN)');
  });

  // Android launch (24 November 2026): a first v2 launch calculated
  // Chennai, then calculated again for the place the phone already knew.
  LocationData mumbaiFix() => LocationData(
    latitude: 19.0760,
    longitude: 72.8777,
    city: 'Mumbai',
    timezone: 'IST',
  );

  test('without a saved city, Home starts from the phone\'s last fix '
      'instead of Chennai', () async {
    SharedPreferences.setMockInitialValues({});
    catalogAvailable = true;
    final settings = EkadashiSettings();
    await settings.load(lastFix: () async => mumbaiFix());
    expect(settings.city.label, 'Mumbai (IN)');
    expect(settings.city.id, EkadashiSettings.detectedCityId);
    expect(settings.city.latitude, 19.08);
    expect(settings.isManual, isFalse);
    expect(settings.loaded, isTrue);
    // Kept as the last detected city, and it starts the Panchang tab.
    final again = EkadashiSettings();
    await again.load();
    expect(again.city.label, 'Mumbai (IN)');
    expect((await PanchangLocationStore().load())?.label, 'Mumbai (IN)');
  });

  test(
    'a saved city is shown at once; the last fix is not even read',
    () async {
      SharedPreferences.setMockInitialValues({});
      catalogAvailable = true;
      final first = EkadashiSettings();
      await first.load();
      await first.chooseCity(sanJose);
      var asked = false;
      final reopened = EkadashiSettings();
      await reopened.load(
        lastFix: () async {
          asked = true;
          return mumbaiFix();
        },
      );
      expect(reopened.city, sanJose);
      expect(asked, isFalse);
    },
  );

  test('without a saved city or a last fix, Chennai', () async {
    SharedPreferences.setMockInitialValues({});
    catalogAvailable = true;
    final settings = EkadashiSettings();
    await settings.load(lastFix: () async => null);
    expect(settings.city, EkadashiSettings.defaultCity);
    final failing = EkadashiSettings();
    await failing.load(lastFix: () async => throw Exception('no channel'));
    expect(failing.city, EkadashiSettings.defaultCity);
    expect(failing.loaded, isTrue);
  });

  test('city names: country spelled out in the app language, no time zone', () {
    expect(EkadashiSettings.splitCountry('New York City (US)'), (
      'New York City',
      'US',
    ));
    expect(EkadashiSettings.splitCountry('Chennai'), ('Chennai', null));
    expect(
      EkadashiSettings.displayName(EkadashiSettings.defaultCity, 'en'),
      'Chennai (IN)',
    );
  });

  // M52 launch timing (27 November 2026): a fix a kilometre or two from the
  // last one counted as a new place, so Home calculated everything again and
  // Parana moved by a minute.
  test('a fix within 5 km with the same city name keeps Home\'s city; a '
      'farther fix or another name moves it', () async {
    SharedPreferences.setMockInitialValues({});
    catalogAvailable = true;
    final settings = EkadashiSettings();
    await settings.load();
    LocationData at(double lat, double lng, String city) => LocationData(
      latitude: lat,
      longitude: lng,
      city: city,
      timezone: 'IST',
    );

    expect(await settings.useDetected(at(13.0129, 80.1615, 'Chennai')), isTrue);
    final home = settings.city;
    expect(home.latitude, 13.01);

    // About 2.8 km away, same name: the same place.
    expect(
      await settings.useDetected(
        at(13.0300, 80.1800, 'Chennai'),
        atLaunch: true,
      ),
      isFalse,
    );
    expect(settings.city, home);

    // Same name but 13 km away: moved.
    expect(await settings.useDetected(at(13.0827, 80.2707, 'Chennai')), isTrue);
    expect(settings.city.latitude, 13.08);

    // Close by but another place's name: moved.
    expect(await settings.useDetected(at(13.0900, 80.2750, 'Egmore')), isTrue);
    expect(settings.city.label, 'Egmore (IN)');
  });
}
