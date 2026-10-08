import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

import '../../l10n/app_language.dart';
import '../search/search_catalog.dart';
import 'panchang_city.dart';
import 'panchang_models.dart';

/// Kinds of Panchang vocabulary in assets/panchang/terms.json.
enum PanchangTermKind {
  tithi('tithi'),
  paksha('paksha'),
  nakshatra('nakshatra'),
  yoga('yoga'),
  karana('karana'),
  month('month'),
  vara('vara'),
  rashi('rashi'),
  ritu('ritu'),
  ayana('ayana'),
  period('period'),
  choghadiya('choghadiya'),
  hora('hora'),
  anandadi('anandadi'),
  specialYoga('special_yoga'),
  observance('observance'),
  ekadashiName('ekadashi_name'),
  ekadashiRule('ekadashi_rule');

  const PanchangTermKind(this.raw);
  final String raw;
}

/// The Panchang in the app language (docs/ROADMAP.md Phase 2), like the
/// Swift `PanchangTerms`. The engine works in English terms; the shared
/// table gives each term in Hindi, Tamil and Telugu. Observance names come
/// from the search catalogue. Unknown terms stay in English.
class PanchangTerms {
  PanchangTerms._(this._table, this._catalog);

  static const asset = 'assets/panchang/terms.json';
  static PanchangTerms? _shared;

  /// The bundled table, once [load] has run.
  static PanchangTerms get shared =>
      _shared ?? (throw StateError('PanchangTerms.load() has not run'));

  static Future<PanchangTerms> load() async {
    if (_shared != null) return _shared!;
    final catalog = await SearchCatalog.load();
    final data = await rootBundle.load(asset);
    return _shared ??= PanchangTerms.parse(
      utf8.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ),
      catalog,
    );
  }

  factory PanchangTerms.parse(String text, SearchCatalog catalog) {
    final root = jsonDecode(text) as Map<String, dynamic>;
    final kinds = <String, Map<String, Map<String, String>>>{
      for (final kind in (root['kinds'] as Map<String, dynamic>).entries)
        kind.key: {
          for (final term in (kind.value as Map<String, dynamic>).entries)
            term.key: Map<String, String>.from(term.value as Map),
        },
    };
    return PanchangTerms._(kinds, catalog);
  }

  /// kind → English term → language → text.
  final Map<String, Map<String, Map<String, String>>> _table;
  final SearchCatalog _catalog;

  /// [term] in [language]; English (and anything unknown) unchanged.
  String translate(String term, PanchangTermKind kind, String language) {
    if (language == 'en') return term;
    return _table[kind.raw]?[term]?[language] ?? term;
  }

  /// "Shukla Pratipada", "Krishna Ekadashi"; Purnima and Amavasya stand alone.
  String tithi(String? paksha, String name, String language) {
    final tithi = translate(name, PanchangTermKind.tithi, language);
    if (paksha == null ||
        paksha.isEmpty ||
        name == 'Purnima' ||
        name == 'Amavasya') {
      return tithi;
    }
    return '${translate(paksha, PanchangTermKind.paksha, language)} $tithi';
  }

  /// "Kartika" or "Adhika Shravana".
  String month(String name, String language) {
    const prefix = 'Adhika ';
    if (!name.startsWith(prefix)) {
      return translate(name, PanchangTermKind.month, language);
    }
    final base = name.substring(prefix.length);
    return '${translate('Adhika', PanchangTermKind.month, language)} '
        '${translate(base, PanchangTermKind.month, language)}';
  }

  /// The engine's "Day · Udveg" and "Night · Amrit".
  String choghadiya(String name, String language) {
    final parts = name.split(' · ');
    if (parts.length != 2) {
      return translate(name, PanchangTermKind.choghadiya, language);
    }
    final half = AppStrings.translate(
      parts[0] == 'Night' ? 'panchang_night' : 'panchang_day',
      language,
    );
    return '$half · ${translate(parts[1], PanchangTermKind.choghadiya, language)}';
  }

  /// An observance's name: the catalogue's name, the table's, or English.
  String observanceName(PanchangObservance observance, String language) {
    final entry = _catalog.observance(observance.id, observance.name);
    if (entry != null) return entry.name(language);
    return translate(observance.name, PanchangTermKind.observance, language);
  }

  static const _noteSuffixes = [
    '. No bounded window; shown as after-only.',
    '. No bounded morning window; shown as after-only.',
    ', before Dwadashi ends',
  ];

  /// A calculated fast's rule or Parana reason; "Jaya: nakshatra end, ..."
  /// is translated through its "{rule}: ..." template.
  String ekadashiNote(String text, String language) {
    for (final suffix in _noteSuffixes) {
      if (text.endsWith(suffix) && text != suffix) {
        final base = text.substring(0, text.length - suffix.length);
        return ekadashiNote(base, language) +
            translate(suffix, PanchangTermKind.ekadashiRule, language);
      }
    }
    final direct = translate(text, PanchangTermKind.ekadashiRule, language);
    if (direct != text || language == 'en') return direct;
    final colon = text.indexOf(': ');
    if (colon < 0) return text;
    final rule = text.substring(0, colon);
    final template = '{rule}: ${text.substring(colon + 2)}';
    final translated = translate(
      template,
      PanchangTermKind.ekadashiRule,
      language,
    );
    if (translated == template) return text;
    return translated.replaceAll(
      '{rule}',
      translate(rule, PanchangTermKind.ekadashiRule, language),
    );
  }

  /// A period name (Rahu Kalam ...), choghadiya, hora planet or lagna rashi.
  String period(String name, String language) {
    if (name.contains(' · ')) return choghadiya(name, language);
    for (final kind in const [
      PanchangTermKind.period,
      PanchangTermKind.hora,
      PanchangTermKind.rashi,
    ]) {
      final text = translate(name, kind, language);
      if (text != name) return text;
    }
    return name;
  }
}

/// Panchang times and dates in the app language. Times are the location's
/// wall clock; the time zone is shown once per screen.
class PanchangFormat {
  const PanchangFormat._();

  /// "6:24 PM", "6:24 PM (next day)", "—" when unavailable.
  static String time(
    DateTime? instant,
    PanchangCity city,
    DateTime date,
    String language,
  ) {
    if (instant == null) return '—';
    final local = city.wallClock(instant);
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final marker = AppStrings.translate(
      local.hour < 12 ? 'panchang_am' : 'panchang_pm',
      language,
    );
    var text = '$hour:$minute $marker';
    final day = DateTime.utc(date.year, date.month, date.day);
    final delta = DateTime.utc(
      local.year,
      local.month,
      local.day,
    ).difference(day).inDays;
    if (delta == 1) {
      text += ' ${AppStrings.translate('panchang_next_day_marker', language)}';
    } else if (delta == -1) {
      text +=
          ' ${AppStrings.translate('panchang_previous_day_marker', language)}';
    } else if (delta != 0) {
      text += ' (${delta > 0 ? '+' : ''}$delta)';
    }
    return text;
  }

  /// "6:24 PM – 7:55 PM".
  static String range(
    DateTime? start,
    DateTime? end,
    PanchangCity city,
    DateTime date,
    String language,
  ) =>
      '${time(start, city, date, language)} – ${time(end, city, date, language)}';

  /// "Thu, 8 Oct 2026" in the language's script and month names.
  static String date(DateTime date, String language) =>
      format(date, 'EEE, d MMM yyyy', language);

  /// "October 2026".
  static String monthTitle(DateTime date, String language) =>
      format(date, 'LLLL yyyy', language);

  /// Short weekday ("Thu").
  static String weekday(DateTime date, String language) =>
      format(date, 'EEE', language);

  static String format(DateTime date, String pattern, String language) =>
      DateFormat(
        pattern,
        AppLanguage.codes.contains(language) ? language : 'en',
      ).format(DateTime.utc(date.year, date.month, date.day));
}
