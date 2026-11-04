library;

/// Data models for the Question of the Day / Wisdom Challenge feature.
///
/// Questions are loaded from the bundled `assets/wisdom/ekadashi_wisdom.json`
/// dataset and displayed inside the Journey (Vrat) tab's Achievements section.

/// A single question in a specific language.
class WisdomQuestion {
  final String questionId;
  final String category;
  final String subcategory;
  final String difficulty;
  final Map<String, String> categoryLabels;
  final Map<String, String> difficultyLabels;
  final String question;
  final Map<String, String> options; // A, B, C, D
  final String correctOption;
  final String explanation;
  final String translationStatus;
  final bool publishable;

  const WisdomQuestion({
    required this.questionId,
    required this.category,
    required this.subcategory,
    required this.difficulty,
    required this.categoryLabels,
    required this.difficultyLabels,
    required this.question,
    required this.options,
    required this.correctOption,
    required this.explanation,
    required this.translationStatus,
    required this.publishable,
  });

  /// Build a [WisdomQuestion] from the JSON dataset for a specific language.
  ///
  /// Falls back to English when [languageCode] is missing from translations.
  factory WisdomQuestion.fromJson(
    Map<String, dynamic> json,
    String languageCode,
  ) {
    final translations =
        json['translations'] as Map<String, dynamic>? ?? const {};
    final langData =
        (translations[languageCode] ?? translations['en']) as Map<String, dynamic>? ??
        const {};
    final labels = json['labels'] as Map<String, dynamic>? ?? const {};
    final catLabels = labels['category'] as Map<String, dynamic>? ?? const {};
    final diffLabels =
        labels['difficulty'] as Map<String, dynamic>? ?? const {};
    final statusMap =
        json['translation_status'] as Map<String, dynamic>? ?? const {};
    final optionsRaw =
        langData['options'] as Map<String, dynamic>? ?? const {};

    return WisdomQuestion(
      questionId: json['question_id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      subcategory: json['subcategory'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      categoryLabels: catLabels.map((k, v) => MapEntry(k, v.toString())),
      difficultyLabels: diffLabels.map((k, v) => MapEntry(k, v.toString())),
      question: langData['question'] as String? ?? '',
      options: optionsRaw.map((k, v) => MapEntry(k, v.toString())),
      correctOption: langData['correct_option'] as String? ?? '',
      explanation: langData['explanation'] as String? ?? '',
      translationStatus: statusMap[languageCode]?.toString() ?? 'unknown',
      publishable: json['publishable'] as bool? ?? false,
    );
  }

  /// The localized category label, falling back to the raw category string.
  String categoryLabel(String languageCode) =>
      categoryLabels[languageCode] ?? categoryLabels['en'] ?? category;

  /// The localized difficulty label, falling back to the raw difficulty string.
  String difficultyLabel(String languageCode) =>
      difficultyLabels[languageCode] ?? difficultyLabels['en'] ?? difficulty;

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

  const QuestionAttempt({
    required this.questionId,
    required this.selectedOption,
    required this.isCorrect,
    required this.pointsAwarded,
    required this.answeredAtUTC,
  });

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'selectedOption': selectedOption,
    'isCorrect': isCorrect,
    'pointsAwarded': pointsAwarded,
    'answeredAtUTC': answeredAtUTC,
  };

  factory QuestionAttempt.fromJson(Map<String, dynamic> json) =>
      QuestionAttempt(
        questionId: json['questionId'] as String? ?? '',
        selectedOption: json['selectedOption'] as String? ?? '',
        isCorrect: json['isCorrect'] as bool? ?? false,
        pointsAwarded: json['pointsAwarded'] as int? ?? 0,
        answeredAtUTC: json['answeredAtUTC'] as String? ?? '',
      );
}

/// Aggregate statistics for the user's question activity.
class WisdomStats {
  final int totalAnswered;
  final int totalCorrect;
  final int totalPoints;
  final Map<String, int> categoryAnswered;
  final Map<String, int> categoryCorrect;

  const WisdomStats({
    this.totalAnswered = 0,
    this.totalCorrect = 0,
    this.totalPoints = 0,
    this.categoryAnswered = const {},
    this.categoryCorrect = const {},
  });
}

