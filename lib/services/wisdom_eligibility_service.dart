library;

import '../models/wisdom_question.dart';

/// Service responsible for managing question eligibility and publication status.
///
/// Ensures unreviewed or unapproved questions are not presented to production
/// users, while providing safe preview access for editorial verification.
class WisdomEligibilityService {
  const WisdomEligibilityService();

  static const instance = WisdomEligibilityService();

  /// Whether [question] is eligible for production users in [languageCode].
  ///
  /// Strict requirements:
  /// 1. `publishable == true`
  /// 2. `verification_status == 'reviewed'`
  /// 3. [languageCode] is present in `available_languages`
  /// 4. Translation status is 'source' or 'reviewed' (if [requireNativeReviewed] is true)
  /// 5. Valid question text, 4 options, valid correct option, and explanation
  bool isEligibleForProduction(
    WisdomQuestion question,
    String languageCode, {
    bool requireNativeReviewed = true,
  }) {
    if (!question.publishable) return false;
    if (question.verificationStatus != 'reviewed') return false;
    if (!question.availableLanguages.contains(languageCode)) return false;

    final status = question.translationStatusMap[languageCode] ??
        question.translationStatus;
    if (requireNativeReviewed) {
      if (status != 'source' && status != 'reviewed') {
        return false;
      }
    }

    if (question.question.trim().isEmpty) return false;
    if (question.options.length < 4) return false;
    if (question.correctOption.trim().isEmpty) return false;
    if (question.explanation.trim().isEmpty) return false;

    return true;
  }

  /// Whether [question] is eligible for development/admin content preview.
  ///
  /// In preview mode:
  /// - Draft, unpublished, or pending-review questions may be displayed for inspection
  /// - Draft questions must not enter production shuffled sequence
  /// - Draft questions must not award production points
  bool isPreviewEligible(WisdomQuestion question, String languageCode) {
    if (question.question.trim().isEmpty) return false;
    if (question.options.isEmpty) return false;
    return true;
  }

  /// Calculate points for an answer.
  ///
  /// Production eligible correct answer: 1 point (or [configuredPoints]).
  /// Preview/draft question: 0 points.
  /// Skipped question: 0 points.
  /// Review mode: 0 points (no duplicate points).
  /// Incorrect answer: 0 points.
  int calculateAwardedPoints({
    required bool isCorrect,
    required bool isProductionEligible,
    required bool isSkipped,
    required bool isReview,
    int configuredPoints = 1,
  }) {
    if (!isCorrect) return 0;
    if (isSkipped) return 0;
    if (isReview) return 0;
    if (!isProductionEligible) return 0;
    return configuredPoints;
  }
}
