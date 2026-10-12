import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_key_days.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_models.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_terms.dart';
import 'package:ekadashi_calendar/services/search/search_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Phase 2 on Android (docs/ROADMAP.md): one app language for every tab,
/// Panchang included, from the same terms table as iOS.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PanchangTerms terms;
  late SearchCatalog catalog;
  late List<DatedObservance> observances2026;
  final service = EkadashiService();
  const others = ['hi', 'ta', 'te', 'gu', 'bn'];

  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting();
    await service.initializeData();
    terms = await PanchangTerms.load();
    catalog = await SearchCatalog.load();
    observances2026 = const PanchangEngine().observanceCalendar(
      2026,
      city: PanchangCity.newDelhi,
    );
  });

  test('languages keep their order and new ones are appended', () {
    // Never reorder: new languages go after Bengali.
    expect(AppLanguage.codes.take(6), ['en', 'hi', 'ta', 'te', 'gu', 'bn']);
    expect(AppLanguage.codes.toSet(), hasLength(AppLanguage.codes.length));
    for (final language in AppLanguage.all) {
      expect(language.nativeName, isNotEmpty);
      expect(
        File('lib/l10n/app_${language.code}.arb').existsSync(),
        isTrue,
        reason: 'every registered language ships its strings',
      );
    }
  });

  test('no string is accidentally left in English', () {
    final english =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    const sameEverywhere = {'filter_google'};
    final same = <String>[];
    for (final language in AppLanguage.codes.skip(1)) {
      final arb =
          jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
              as Map<String, dynamic>;
      for (final entry in english.entries) {
        if (entry.key.startsWith('@') || sameEverywhere.contains(entry.key)) {
          continue;
        }
        final source = entry.value as String;
        if (!RegExp(
          r'[A-Za-z]',
        ).hasMatch(source.replaceAll(RegExp(r'\{value\d\}'), ''))) {
          continue;
        }
        if (arb[entry.key] == source) same.add('$language ${entry.key}');
      }
    }
    expect(same, isEmpty);
  });

  test('every Panchang term the engine shows is translated', () {
    final missing = <String>{};
    void check(String term, PanchangTermKind kind) {
      if (term.isEmpty) return;
      for (final language in others) {
        if (terms.translate(term, kind, language) == term) {
          missing.add('$language ${kind.raw} $term');
        }
      }
    }

    const engine = PanchangEngine();
    for (final city in [PanchangCity.newDelhi, PanchangCity.chennai]) {
      for (var i = 0; i < 400; i += 3) {
        final day = engine.calculate(
          DateTime.utc(2026, 1, 1).add(Duration(days: i)),
          city: city,
        );
        check(day.tithi.name, PanchangTermKind.tithi);
        check(day.nakshatra.name, PanchangTermKind.nakshatra);
        check(day.yoga.name, PanchangTermKind.yoga);
        check(day.karana.name, PanchangTermKind.karana);
        check(day.vara, PanchangTermKind.vara);
        check(day.sunRashi, PanchangTermKind.rashi);
        check(day.moonRashi, PanchangTermKind.rashi);
        check(day.ritu, PanchangTermKind.ritu);
        check(day.ayana, PanchangTermKind.ayana);
        check(day.anandadiYoga, PanchangTermKind.anandadi);
        for (final y in day.specialYogas) {
          check(y, PanchangTermKind.specialYoga);
        }
        for (final month in [day.amantaMonth, day.purnimantaMonth]) {
          for (final language in others) {
            if (terms.month(month, language) == month) {
              missing.add('$language month $month');
            }
          }
        }
        for (final p in [
          day.rahukala,
          day.yamaganda,
          day.gulika,
          day.abhijit,
          day.brahmaMuhurta,
          ...day.additionalPeriods,
          ...day.choghadiya,
          ...day.hora,
          ...day.lagna,
        ]) {
          if (p == null) continue;
          for (final language in others) {
            if (terms.period(p.name, language) == p.name) {
              missing.add('$language period ${p.name}');
            }
          }
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('compound terms are translated part by part', () {
    expect(terms.tithi('Shukla', 'Pratipada', 'hi'), 'शुक्ल प्रतिपदा');
    expect(terms.tithi('Krishna', 'Amavasya', 'te'), 'అమావాస్య');
    expect(terms.tithi('Shukla', 'Purnima', 'ta'), 'பௌர்ணமி');
    expect(terms.tithi('Krishna', 'Ekadashi', 'en'), 'Krishna Ekadashi');
    expect(terms.month('Adhika Shravana', 'hi'), 'अधिक श्रावण');
    expect(terms.month('Kartika', 'te'), 'కార్తీకం');
    expect(terms.choghadiya('Night · Amrit', 'hi'), 'रात · अमृत');
    expect(terms.choghadiya('Day · Rog', 'en'), 'Day · Rog');
  });

  test('every engine observance has a localized name', () {
    final missing = <String>{};
    for (final dated in observances2026) {
      for (final language in others) {
        if (terms.observanceName(dated.observance, language) ==
            dated.observance.name) {
          missing.add('$language ${dated.observance.id}');
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('calculated Ekadashi names, rules and reasons are translated', () {
    final missing = <String>{};
    for (final tradition in EkadashiTradition.values) {
      final fasts = const CalculatedEkadashiEngine().calculate(
        DateTime.utc(2026, 1, 1),
        365,
        PanchangCity.newDelhi,
        tradition,
      );
      expect(fasts.length, greaterThan(20));
      for (final fast in fasts) {
        for (final language in others) {
          if (terms.translate(
                fast.name,
                PanchangTermKind.ekadashiName,
                language,
              ) ==
              fast.name) {
            missing.add('$language ${fast.name}');
          }
          if (terms.ekadashiNote(fast.rule, language) == fast.rule) {
            missing.add('$language ${fast.rule}');
          }
          if (terms.ekadashiNote(fast.paranaReason, language) ==
              fast.paranaReason) {
            missing.add('$language ${fast.paranaReason}');
          }
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('times and dates follow the language', () {
    const city = PanchangCity.newDelhi;
    final date = DateTime.utc(2026, 10, 8);
    final evening = city.dateAtHour(date, 18).add(const Duration(minutes: 24));
    expect(PanchangFormat.time(evening, city, date, 'en'), '6:24 PM');
    expect(
      PanchangFormat.time(
        evening.add(const Duration(days: 1)),
        city,
        date,
        'en',
      ),
      '6:24 PM (next day)',
    );
    expect(PanchangFormat.time(null, city, date, 'en'), '—');
    final hindi = PanchangFormat.time(evening, city, date, 'hi');
    expect(hindi, contains('6:24'));
    expect(hindi, isNot('6:24 PM'));
    expect(PanchangFormat.date(date, 'en'), 'Thu, 8 Oct 2026');
    expect(PanchangFormat.date(date, 'ta'), isNot('Thu, 8 Oct 2026'));
    expect(PanchangFormat.monthTitle(date, 'en'), 'October 2026');
  });

  test('Key days list published Ekadashis and catalogued observances', () {
    final month = DateTime.utc(2026, 11, 1);
    final days = PanchangKeyDays.month(
      month,
      observances: observances2026,
      ekadashis: service.getEkadashis(timezone: 'IST', languageCode: 'en'),
      language: 'en',
      catalog: catalog,
    );
    expect(
      days.every((d) => d.date.year == 2026 && d.date.month == 11),
      isTrue,
    );
    final dates = [for (final d in days) d.date];
    expect(dates, [...dates]..sort());
    final ekadashis = days
        .where((d) => d.categories.contains(SearchCategory.ekadashi))
        .toList();
    expect(ekadashis, hasLength(2));
    expect(ekadashis.every((d) => !d.requiresPremium), isTrue);
    expect(
      days.any(
        (d) =>
            d.key == 'deepavali' &&
            d.date == DateTime.utc(2026, 11, 8) &&
            d.requiresPremium,
      ),
      isTrue,
    );
    expect(days.any((d) => d.key == 'ekadashi'), isFalse);

    final hindi = PanchangKeyDays.month(
      month,
      observances: observances2026,
      ekadashis: service.getEkadashis(timezone: 'IST', languageCode: 'hi'),
      language: 'hi',
      catalog: catalog,
    );
    expect(
      hindi.firstWhere((d) => d.key == 'deepavali').title,
      'दीपावली (लक्ष्मी पूजा)',
    );
    final festivals = PanchangKeyDays.filter(hindi, SearchCategory.festival);
    expect(festivals, isNotEmpty);
    expect(
      festivals.every((d) => d.categories.contains(SearchCategory.festival)),
      isTrue,
    );
    expect(PanchangKeyDays.filter(hindi, null), hasLength(hindi.length));
  });
}
