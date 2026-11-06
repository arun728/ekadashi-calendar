library;

/// Data models for the Question of the Day / Wisdom Challenge feature.
///
/// Supports Schema 3.0 multilingual question bank with both classic and
/// KBC (Kaun Banega Crorepati) formats, localized option labels,
/// eligibility verification status, and rich explanations.

/// Question presentation format.
enum WisdomFormat {
  classic,
  kbc;

  static WisdomFormat fromString(String? value) {
    if (value?.toLowerCase() == 'kbc') return WisdomFormat.kbc;
    return WisdomFormat.classic;
  }
}

/// A localized translation entry for a question.
class WisdomTranslation {
  final String question;
  final Map<String, String> options;
  final String correctOption;
  final String explanation;
  final String? context;
  final Map<String, String>? optionFeedback;
  final String? insight;
  final String? traditionNote;

  const WisdomTranslation({
    required this.question,
    required this.options,
    required this.correctOption,
    required this.explanation,
    this.context,
    this.optionFeedback,
    this.insight,
    this.traditionNote,
  });

  factory WisdomTranslation.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as Map<String, dynamic>? ?? const {};
    final rawFeedback = json['option_feedback'] as Map<String, dynamic>?;

    final explanationText = (json['explanation'] as String?) ??
        (json['explanation_correct'] as String?) ??
        '';

    return WisdomTranslation(
      question: json['question'] as String? ?? '',
      options: rawOptions.map((k, v) => MapEntry(k.toString(), v.toString())),
      correctOption: json['correct_option'] as String? ?? '',
      explanation: explanationText,
      context: json['context'] as String?,
      optionFeedback: rawFeedback?.map((k, v) => MapEntry(k.toString(), v.toString())),
      insight: json['insight'] as String?,
      traditionNote: json['tradition_note'] as String?,
    );
  }
}

/// A single question loaded for a specific target language.
class WisdomQuestion {
  final String questionId;
  final WisdomFormat format;
  final String category;
  final String subcategory;
  final String difficulty;
  final String? bankTier;
  final String verificationStatus;
  final bool publishable;
  final String? conceptId;
  final String? questionStyle;
  final List<String>? derivedFrom;
  final Map<String, dynamic>? sourceMetadata;
  final List<String> availableLanguages;
  final String translationStatus;
  final Map<String, String> translationStatusMap;
  final Map<String, String> categoryLabels;
  final Map<String, String> difficultyLabels;
  final Map<String, String>? localizedOptionLabels;

  // Language-specific content
  final String question;
  final Map<String, String> options; // Keyed 'A', 'B', 'C', 'D'
  final String correctOption; // 'A', 'B', 'C', or 'D'
  final String explanation;
  final String? context;
  final Map<String, String>? optionFeedback;
  final String? insight;
  final String? traditionNote;

  const WisdomQuestion({
    required this.questionId,
    this.format = WisdomFormat.classic,
    required this.category,
    required this.subcategory,
    required this.difficulty,
    this.bankTier,
    this.verificationStatus = 'reviewed',
    required this.publishable,
    this.conceptId,
    this.questionStyle,
    this.derivedFrom,
    this.sourceMetadata,
    this.availableLanguages = const ['en'],
    this.translationStatus = 'unknown',
    this.translationStatusMap = const {},
    required this.categoryLabels,
    required this.difficultyLabels,
    this.localizedOptionLabels,
    required this.question,
    required this.options,
    required this.correctOption,
    required this.explanation,
    this.context,
    this.optionFeedback,
    this.insight,
    this.traditionNote,
  });

  /// Build a [WisdomQuestion] from the JSON record for [languageCode].
  ///
  /// Falls back to English if the translation is missing.
  factory WisdomQuestion.fromJson(
    Map<String, dynamic> json,
    String languageCode, {
    Map<String, List<String>>? allOptionLabels,
  }) {
    final translations =
        json['translations'] as Map<String, dynamic>? ?? const {};
    final langData = (translations[languageCode] ?? translations['en'])
            as Map<String, dynamic>? ??
        const {};

    final labels = json['labels'] as Map<String, dynamic>? ?? const {};
    final catLabels = labels['category'] as Map<String, dynamic>? ?? const {};
    final diffLabels = labels['difficulty'] as Map<String, dynamic>? ?? const {};
    final statusMap = json['translation_status'] as Map<String, dynamic>? ?? const {};
    final availLangs = (json['available_languages'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const ['en'];

    final parsedTrans = WisdomTranslation.fromJson(langData);

    // Build localized option labels (e.g. A -> 'அ', B -> 'ஆ')
    Map<String, String>? optLabels;
    if (allOptionLabels != null && allOptionLabels.containsKey(languageCode)) {
      final list = allOptionLabels[languageCode]!;
      if (list.length >= 4) {
        optLabels = {
          'A': list[0],
          'B': list[1],
          'C': list[2],
          'D': list[3],
        };
      }
    }

    final rawDerived = json['derived_from'];
    final derivedList = rawDerived is List
        ? rawDerived.map((e) => e.toString()).toList()
        : rawDerived is String
            ? [rawDerived]
            : null;

    return WisdomQuestion(
      questionId: json['question_id'] as String? ?? '',
      format: WisdomFormat.fromString(json['format'] as String?),
      category: json['category'] as String? ?? '',
      subcategory: json['subcategory'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      bankTier: json['bank_tier'] as String?,
      verificationStatus: json['verification_status'] as String? ?? 'reviewed',
      publishable: json['publishable'] as bool? ?? false,
      conceptId: json['concept_id'] as String?,
      questionStyle: json['question_style'] as String?,
      derivedFrom: derivedList,
      sourceMetadata: json['source_metadata'] as Map<String, dynamic>?,
      availableLanguages: availLangs,
      translationStatus: statusMap[languageCode]?.toString() ?? 'unknown',
      translationStatusMap: statusMap.map((k, v) => MapEntry(k, v.toString())),
      categoryLabels: catLabels.map((k, v) => MapEntry(k, v.toString())),
      difficultyLabels: diffLabels.map((k, v) => MapEntry(k, v.toString())),
      localizedOptionLabels: optLabels,
      question: parsedTrans.question,
      options: parsedTrans.options,
      correctOption: parsedTrans.correctOption,
      explanation: parsedTrans.explanation,
      context: parsedTrans.context,
      optionFeedback: parsedTrans.optionFeedback,
      insight: parsedTrans.insight,
      traditionNote: parsedTrans.traditionNote,
    );
  }

  /// The localized category label, falling back to the raw category string.
  String categoryLabel(String languageCode) =>
      categoryLabels[languageCode] ?? categoryLabels['en'] ?? category;

  /// The localized difficulty label, falling back to the raw difficulty string.
  String difficultyLabel(String languageCode) =>
      difficultyLabels[languageCode] ?? difficultyLabels['en'] ?? difficulty;

  /// The localized letter for option [key] ('A', 'B', 'C', 'D').
  String localizedOptionKey(String key) =>
      localizedOptionLabels?[key] ?? key;

  /// Whether [selectedOption] is the correct answer.
  bool isCorrect(String selectedOption) =>
      selectedOption.toUpperCase() == correctOption.toUpperCase();
}

/// A persisted record of a user's answer to a question.
class QuestionAttempt {
  final String questionId;
  final String selectedOption;
  final bool isCorrect;
  final int pointsAwarded;
  final String answeredAtUTC;
  final bool isSkipped;
  final bool isReview;

  const QuestionAttempt({
    required this.questionId,
    required this.selectedOption,
    required this.isCorrect,
    required this.pointsAwarded,
    required this.answeredAtUTC,
    this.isSkipped = false,
    this.isReview = false,
  });

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'selectedOption': selectedOption,
    'isCorrect': isCorrect,
    'pointsAwarded': pointsAwarded,
    'answeredAtUTC': answeredAtUTC,
    'isSkipped': isSkipped,
    'isReview': isReview,
  };

  factory QuestionAttempt.fromJson(Map<String, dynamic> json) =>
      QuestionAttempt(
        questionId: json['questionId'] as String? ?? '',
        selectedOption: json['selectedOption'] as String? ?? '',
        isCorrect: json['isCorrect'] as bool? ?? false,
        pointsAwarded: json['pointsAwarded'] as int? ?? 0,
        answeredAtUTC: json['answeredAtUTC'] as String? ?? '',
        isSkipped: json['isSkipped'] as bool? ?? false,
        isReview: json['isReview'] as bool? ?? false,
      );
}

/// Aggregate statistics for the user's question activity.
class WisdomStats {
  final int totalAnswered;
  final int totalCorrect;
  final int totalPoints;
  final int totalSkipped;
  final Map<String, int> categoryAnswered;
  final Map<String, int> categoryCorrect;

  const WisdomStats({
    this.totalAnswered = 0,
    this.totalCorrect = 0,
    this.totalPoints = 0,
    this.totalSkipped = 0,
    this.categoryAnswered = const {},
    this.categoryCorrect = const {},
  });

  double get accuracyPercentage =>
      totalAnswered > 0 ? (totalCorrect / totalAnswered) * 100 : 0.0;
}
