import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/models/wisdom_question.dart';
import 'package:ekadashi_calendar/services/wisdom_eligibility_service.dart';

void main() {
  late WisdomEligibilityService eligibilityService;

  setUp(() {
    eligibilityService = const WisdomEligibilityService();
  });

  group('Wisdom Eligibility Service', () {
    const mockReviewedQuestion = WisdomQuestion(
      questionId: 'TEST01',
      category: 'ekadashi',
      subcategory: 'rules',
      difficulty: 'easy',
      publishable: false, // Default in dataset
      verificationStatus: 'reviewed',
      availableLanguages: ['en', 'hi', 'ta'],
      translationStatus: 'source',
      translationStatusMap: {
        'en': 'source',
        'hi': 'ai_draft_needs_native_review',
        'ta': 'ai_draft_needs_native_review',
      },
      categoryLabels: {'en': 'Ekadashi'},
      difficultyLabels: {'en': 'Easy'},
      question: 'Test question?',
      options: {'A': 'Opt1', 'B': 'Opt2', 'C': 'Opt3', 'D': 'Opt4'},
      correctOption: 'A',
      explanation: 'Explanation',
    );

    test('Rejects question when publishable is false even if verificationStatus is reviewed', () {
      expect(mockReviewedQuestion.publishable, isFalse);
      expect(mockReviewedQuestion.verificationStatus, equals('reviewed'));
      expect(
        eligibilityService.isEligibleForProduction(mockReviewedQuestion, 'en'),
        isFalse,
      );
    });

    test('Rejects question when verificationStatus is not reviewed', () {
      const unreviewed = WisdomQuestion(
        questionId: 'TEST02',
        category: 'ekadashi',
        subcategory: 'rules',
        difficulty: 'easy',
        publishable: true,
        verificationStatus: 'pending_review',
        availableLanguages: ['en'],
        translationStatus: 'source',
        translationStatusMap: {'en': 'source'},
        categoryLabels: {'en': 'Ekadashi'},
        difficultyLabels: {'en': 'Easy'},
        question: 'Q',
        options: {'A': '1', 'B': '2', 'C': '3', 'D': '4'},
        correctOption: 'A',
        explanation: 'Exp',
      );
      expect(
        eligibilityService.isEligibleForProduction(unreviewed, 'en'),
        isFalse,
      );
    });

    test('Rejects question when requested language is not in availableLanguages', () {
      const pubQ = WisdomQuestion(
        questionId: 'TEST03',
        category: 'ekadashi',
        subcategory: 'rules',
        difficulty: 'easy',
        publishable: true,
        verificationStatus: 'reviewed',
        availableLanguages: ['en'],
        translationStatus: 'source',
        translationStatusMap: {'en': 'source'},
        categoryLabels: {'en': 'Ekadashi'},
        difficultyLabels: {'en': 'Easy'},
        question: 'Q',
        options: {'A': '1', 'B': '2', 'C': '3', 'D': '4'},
        correctOption: 'A',
        explanation: 'Exp',
      );
      expect(
        eligibilityService.isEligibleForProduction(pubQ, 'hi'),
        isFalse,
      );
    });

    test('Approves question when publishable, reviewed, language available and reviewed', () {
      const validPubQ = WisdomQuestion(
        questionId: 'TEST04',
        category: 'ekadashi',
        subcategory: 'rules',
        difficulty: 'easy',
        publishable: true,
        verificationStatus: 'reviewed',
        availableLanguages: ['en', 'ta'],
        translationStatus: 'source',
        translationStatusMap: {'en': 'source', 'ta': 'reviewed'},
        categoryLabels: {'en': 'Ekadashi'},
        difficultyLabels: {'en': 'Easy'},
        question: 'Q',
        options: {'A': '1', 'B': '2', 'C': '3', 'D': '4'},
        correctOption: 'A',
        explanation: 'Exp',
      );
      expect(
        eligibilityService.isEligibleForProduction(validPubQ, 'en'),
        isTrue,
      );
      expect(
        eligibilityService.isEligibleForProduction(validPubQ, 'ta'),
        isTrue,
      );
    });

    test('Preview eligibility allows draft questions for content review', () {
      expect(
        eligibilityService.isPreviewEligible(mockReviewedQuestion, 'en'),
        isTrue,
      );
    });

    test('Calculate points awards 0 points for preview questions or skips', () {
      // Production correct answer
      expect(
        eligibilityService.calculateAwardedPoints(
          isCorrect: true,
          isProductionEligible: true,
          isSkipped: false,
          isReview: false,
        ),
        equals(1),
      );

      // Preview mode correct answer must award 0 points!
      expect(
        eligibilityService.calculateAwardedPoints(
          isCorrect: true,
          isProductionEligible: false,
          isSkipped: false,
          isReview: false,
        ),
        equals(0),
      );

      // Skipped question must award 0 points!
      expect(
        eligibilityService.calculateAwardedPoints(
          isCorrect: false,
          isProductionEligible: true,
          isSkipped: true,
          isReview: false,
        ),
        equals(0),
      );

      // Review mode must award 0 points (no duplicate rewards)!
      expect(
        eligibilityService.calculateAwardedPoints(
          isCorrect: true,
          isProductionEligible: true,
          isSkipped: false,
          isReview: true,
        ),
        equals(0),
      );
    });
  });
}
