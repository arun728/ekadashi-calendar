import 'tradition_service.dart';

/// General theological and timing guidance for breaking the Ekadashi fast (Parana)
class ParanaGeneralGuidance {
  final Map<String, String> meaning;
  final Map<String, String> whenToBreak;
  final Map<String, String> windowGuidance;
  final Map<String, String> dwadashiObservance;
  final Map<String, String> missedWindowGuidance;

  const ParanaGeneralGuidance({
    required this.meaning,
    required this.whenToBreak,
    required this.windowGuidance,
    required this.dwadashiObservance,
    required this.missedWindowGuidance,
  });

  String localizedMeaning(String langCode) => meaning[langCode] ?? meaning['en'] ?? '';
  String localizedWhenToBreak(String langCode) => whenToBreak[langCode] ?? whenToBreak['en'] ?? '';
  String localizedWindowGuidance(String langCode) => windowGuidance[langCode] ?? windowGuidance['en'] ?? '';
  String localizedDwadashiObservance(String langCode) => dwadashiObservance[langCode] ?? dwadashiObservance['en'] ?? '';
  String localizedMissedWindowGuidance(String langCode) => missedWindowGuidance[langCode] ?? missedWindowGuidance['en'] ?? '';

  factory ParanaGeneralGuidance.fromJson(Map<String, dynamic> json) {
    Map<String, String> parseMap(dynamic val) {
      if (val is Map) {
        return val.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return {'en': val?.toString() ?? ''};
    }

    return ParanaGeneralGuidance(
      meaning: parseMap(json['meaning']),
      whenToBreak: parseMap(json['when_to_break']),
      windowGuidance: parseMap(json['window_guidance']),
      dwadashiObservance: parseMap(json['dwadashi_observance']),
      missedWindowGuidance: parseMap(json['missed_window_guidance']),
    );
  }
}

/// Tradition-specific Parana rule with canonical source references
class TraditionParanaRule {
  final AppTradition tradition;
  final Map<String, String> title;
  final Map<String, String> rules;
  final String source;

  const TraditionParanaRule({
    required this.tradition,
    required this.title,
    required this.rules,
    required this.source,
  });

  String localizedTitle(String langCode) => title[langCode] ?? title['en'] ?? '';
  String localizedRules(String langCode) => rules[langCode] ?? rules['en'] ?? '';

  factory TraditionParanaRule.fromJson(AppTradition tradition, Map<String, dynamic> json) {
    Map<String, String> parseMap(dynamic val) {
      if (val is Map) {
        return val.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return {'en': val?.toString() ?? ''};
    }

    return TraditionParanaRule(
      tradition: tradition,
      title: parseMap(json['title']),
      rules: parseMap(json['rules']),
      source: json['source'] as String? ?? 'Canonical Consensus',
    );
  }
}

/// Complete Parana guidance document loaded from assets
class ParanaGuidanceDocument {
  final String version;
  final String source;
  final String verificationStatus;
  final String verificationNote;
  final ParanaGeneralGuidance general;
  final Map<AppTradition, TraditionParanaRule> traditions;
  final Map<String, String> traditionDifferencesNote;

  const ParanaGuidanceDocument({
    required this.version,
    required this.source,
    required this.verificationStatus,
    required this.verificationNote,
    required this.general,
    required this.traditions,
    required this.traditionDifferencesNote,
  });

  String localizedTraditionDifferences(String langCode) =>
      traditionDifferencesNote[langCode] ?? traditionDifferencesNote['en'] ?? '';

  factory ParanaGuidanceDocument.fromJson(Map<String, dynamic> json) {
    Map<String, String> parseMap(dynamic val) {
      if (val is Map) {
        return val.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return {'en': val?.toString() ?? ''};
    }

    final traditionsJson = json['traditions'] as Map<String, dynamic>? ?? {};
    final traditionsMap = <AppTradition, TraditionParanaRule>{};

    for (final tradition in AppTradition.values) {
      final tKey = tradition.name;
      if (traditionsJson.containsKey(tKey)) {
        traditionsMap[tradition] = TraditionParanaRule.fromJson(
          tradition,
          traditionsJson[tKey] as Map<String, dynamic>,
        );
      }
    }

    return ParanaGuidanceDocument(
      version: json['version'] as String? ?? '1.0',
      source: json['source'] as String? ?? 'Canonical Shastras',
      verificationStatus: json['verification_status'] as String? ?? 'verified',
      verificationNote: json['verification_note'] as String? ?? '',
      general: ParanaGeneralGuidance.fromJson(json['general_guidance'] as Map<String, dynamic>? ?? {}),
      traditions: traditionsMap,
      traditionDifferencesNote: parseMap(json['tradition_differences_note']),
    );
  }
}
