library;

/// Validation report returned by [WisdomContentValidator].
class WisdomValidationReport {
  final bool isValid;
  final int totalQuestions;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, int> categoryCounts;
  final Map<String, int> formatCounts;
  final Map<String, int> difficultyCounts;

  const WisdomValidationReport({
    required this.isValid,
    required this.totalQuestions,
    required this.errors,
    required this.warnings,
    required this.categoryCounts,
    required this.formatCounts,
    required this.difficultyCounts,
  });
}

/// Automated validator for the Schema 3.0 multilingual question bank.
class WisdomContentValidator {
  static const validCategories = {
    'ekadashi',
    'bhagavad_gita',
    'mahabharata',
    'ramayana',
  };

  static const validDifficulties = {
    'easy',
    'medium',
    'hard',
  };

  static const validFormats = {
    'classic',
    'kbc',
  };

  static const validOptionKeys = {'A', 'B', 'C', 'D'};

  static const supportedLanguages = {'en', 'hi', 'ta', 'te', 'gu', 'bn'};

  /// Validate the complete dataset JSON object.
  WisdomValidationReport validate(Map<String, dynamic> json) {
    final errors = <String>[];
    final warnings = <String>[];
    final seenIds = <String>{};

    final categoryCounts = <String, int>{};
    final formatCounts = <String, int>{};
    final difficultyCounts = <String, int>{};

    // Check top-level metadata
    if (json['dataset_name'] != 'ekadashi_wisdom_full_bank' &&
        json['dataset_name'] != 'ekadashi_wisdom') {
      warnings.add('Dataset name is ${json['dataset_name']}');
    }

    final questionsRaw = json['questions'];
    if (questionsRaw is! List) {
      return WisdomValidationReport(
        isValid: false,
        totalQuestions: 0,
        errors: ['"questions" key is missing or not a list.'],
        warnings: warnings,
        categoryCounts: const {},
        formatCounts: const {},
        difficultyCounts: const {},
      );
    }

    for (var i = 0; i < questionsRaw.length; i++) {
      final item = questionsRaw[i];
      if (item is! Map<String, dynamic>) {
        errors.add('Question at index $i is not a valid JSON map');
        continue;
      }

      final qId = item['question_id'] as String?;
      // 1. Missing question ID
      if (qId == null || qId.trim().isEmpty) {
        errors.add('Missing question_id at index $i');
        continue;
      }

      // 2. Duplicate question IDs
      if (seenIds.contains(qId)) {
        errors.add('Duplicate question_id: $qId');
      } else {
        seenIds.add(qId);
      }

      // 3. Category validation
      final category = item['category'] as String?;
      if (category == null || !validCategories.contains(category)) {
        errors.add('[$qId] Invalid category: $category');
      } else {
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      // 4. Difficulty validation
      final difficulty = item['difficulty'] as String?;
      if (difficulty == null || !validDifficulties.contains(difficulty)) {
        errors.add('[$qId] Invalid difficulty: $difficulty');
      } else {
        difficultyCounts[difficulty] = (difficultyCounts[difficulty] ?? 0) + 1;
      }

      // 5. Format validation
      final format = item['format'] as String?;
      if (format == null || !validFormats.contains(format)) {
        errors.add('[$qId] Invalid format: $format');
      } else {
        formatCounts[format] = (formatCounts[format] ?? 0) + 1;
      }

      // 14. Publication status
      final pub = item['publishable'];
      if (pub is! bool) {
        errors.add('[$qId] Invalid publishable status: $pub (must be boolean)');
      }

      // 15. Source metadata
      final sourceMeta = item['source_metadata'];
      if (sourceMeta != null && sourceMeta is! Map) {
        errors.add('[$qId] Invalid source_metadata format');
      }

      // 13. Available languages
      final availLangs = item['available_languages'];
      if (availLangs is! List) {
        errors.add('[$qId] Missing or invalid available_languages');
      } else {
        for (final l in availLangs) {
          if (!supportedLanguages.contains(l.toString())) {
            errors.add('[$qId] Unsupported language code in available_languages: $l');
          }
        }
      }

      // Translations validation
      final translations = item['translations'];
      if (translations is! Map<String, dynamic> || translations.isEmpty) {
        errors.add('[$qId] Missing or invalid translations');
        continue;
      }

      // Check English translation at minimum as base
      final enTrans = translations['en'];
      if (enTrans is! Map<String, dynamic>) {
        errors.add('[$qId] Missing required English translation');
      } else {
        // 6. Missing question text
        final qText = enTrans['question'] as String?;
        if (qText == null || qText.trim().isEmpty) {
          errors.add('[$qId] Missing question text in English translation');
        }

        // 7. Missing options
        final options = enTrans['options'];
        if (options is! Map<String, dynamic>) {
          errors.add('[$qId] Missing options in English translation');
        } else {
          for (final optKey in validOptionKeys) {
            final optVal = options[optKey];
            if (optVal == null || optVal.toString().trim().isEmpty) {
              errors.add('[$qId] Missing or empty option $optKey');
            }
          }
        }

        // 8 & 9. Correct answer validation
        final correct = enTrans['correct_option'] as String?;
        if (correct == null || !validOptionKeys.contains(correct.toUpperCase())) {
          errors.add('[$qId] Invalid correct_option: $correct (must be A, B, C, or D)');
        }

        // 10. Missing explanation
        final explanation = (enTrans['explanation'] as String?) ??
            (enTrans['explanation_correct'] as String?);
        if (explanation == null || explanation.trim().isEmpty) {
          errors.add('[$qId] Missing explanation in English translation');
        }

        // KBC specific requirements
        if (format == 'kbc') {
          final feedback = enTrans['option_feedback'];
          if (feedback is! Map<String, dynamic> || feedback.isEmpty) {
            warnings.add('[$qId] KBC question missing option_feedback');
          }
          final insight = enTrans['insight'] as String?;
          if (insight == null || insight.trim().isEmpty) {
            warnings.add('[$qId] KBC question missing insight');
          }
        }
      }

      // 12. Translation status validation
      final statusMap = item['translation_status'];
      if (statusMap is! Map<String, dynamic>) {
        errors.add('[$qId] Missing translation_status map');
      }
    }

    return WisdomValidationReport(
      isValid: errors.isEmpty,
      totalQuestions: seenIds.length,
      errors: errors,
      warnings: warnings,
      categoryCounts: categoryCounts,
      formatCounts: formatCounts,
      difficultyCounts: difficultyCounts,
    );
  }
}

