import 'package:intl/intl.dart';

/// Payload shown on the home-screen widget (all fields required for v1).
class NextEkadashiWidgetData {
  final String name;
  final String dateLabel; // e.g. Aug 09, 2026
  final String weekdayLabel; // e.g. Sunday
  final String startFastingLabel; // e.g. 05:56 AM
  final String significance;
  final String languageCode;
  final int? ekadashiId;

  const NextEkadashiWidgetData({
    required this.name,
    required this.dateLabel,
    required this.weekdayLabel,
    required this.startFastingLabel,
    required this.significance,
    required this.languageCode,
    this.ekadashiId,
  });

  /// Empty / fallback when no upcoming Ekadashi.
  factory NextEkadashiWidgetData.empty({String languageCode = 'en'}) {
    return NextEkadashiWidgetData(
      name: _noUpcomingName(languageCode),
      dateLabel: '—',
      weekdayLabel: '—',
      startFastingLabel: '—',
      significance: _noUpcomingSignificance(languageCode),
      languageCode: languageCode,
      ekadashiId: null,
    );
  }

  static String _noUpcomingName(String lang) {
    switch (lang) {
      case 'hi':
        return 'कोई आगामी एकादशी नहीं';
      case 'ta':
        return 'வரவிருக்கும் ஏகாதசி இல்லை';
      case 'te':
        return 'రాబోయే ఏకాదశి లేదు';
      default:
        return 'No upcoming Ekadashi';
    }
  }

  static String _noUpcomingSignificance(String lang) {
    switch (lang) {
      case 'hi':
        return 'कैलेंडर में अगली एकादशी उपलब्ध नहीं है।';
      case 'ta':
        return 'அட்டவணையில் அடுத்த ஏகாதசி இல்லை.';
      case 'te':
        return 'క్యాలెండర్‌లో తదుపరి ఏకాదశి లేదు.';
      default:
        return 'No further Ekadashi in the current calendar.';
    }
  }

  Map<String, String> toWidgetKeys() => {
        'widget_name': name,
        'widget_date': dateLabel,
        'widget_weekday': weekdayLabel,
        'widget_start_fasting': startFastingLabel,
        'widget_significance': significance,
        'widget_language': languageCode,
        if (ekadashiId != null) 'widget_ekadashi_id': '$ekadashiId',
      };

  /// Max significance length for widget (2 lines-ish).
  static String truncateSignificance(String text, {int maxChars = 120}) {
    final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars - 1).trimRight()}…';
  }
}

/// Pure builder: pick next Ekadashi on/after [now] from already-localized list.
class NextEkadashiWidgetBuilder {
  /// [entries] must already use the user's language for name/description/fastStartTime.
  static NextEkadashiWidgetData build({
    required List<({
      int? id,
      String name,
      DateTime date,
      String fastStartTime,
      String description,
    })> entries,
    required DateTime now,
    required String languageCode,
    String? dateLocale,
  }) {
    final locale = dateLocale ?? _intlLocale(languageCode);
    final today = DateTime(now.year, now.month, now.day);

    final upcoming = entries.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      return !d.isBefore(today);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (upcoming.isEmpty) {
      return NextEkadashiWidgetData.empty(languageCode: languageCode);
    }

    final next = upcoming.first;
    final dateFmt = DateFormat.yMMMd(locale);
    final weekdayFmt = DateFormat.EEEE(locale);

    return NextEkadashiWidgetData(
      name: next.name,
      dateLabel: dateFmt.format(next.date),
      weekdayLabel: weekdayFmt.format(next.date),
      startFastingLabel: next.fastStartTime.trim().isEmpty
          ? '—'
          : next.fastStartTime.trim(),
      significance: NextEkadashiWidgetData.truncateSignificance(next.description),
      languageCode: languageCode,
      ekadashiId: next.id,
    );
  }

  static String _intlLocale(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return 'hi';
      case 'ta':
        return 'ta';
      case 'te':
        return 'te';
      default:
        return 'en';
    }
  }
}
