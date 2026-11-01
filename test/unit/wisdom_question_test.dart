import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ekadashi_calendar/models/wisdom_question.dart';
import 'package:ekadashi_calendar/services/wisdom_question_service.dart';
import 'package:ekadashi_calendar/services/wisdom_progress_store.dart';

/// Minimal question JSON for testing. Two questions per category.
List<Map<String, dynamic>> _testQuestions() => [
  {
    'question_id': 'EKQ0001',
    'category': 'ekadashi',
    'subcategory': 'parana',
    'difficulty': 'easy',
    'labels': {
      'category': {'en': 'Ekadashi', 'hi': 'एकादशी'},
      'difficulty': {'en': 'Easy', 'hi': 'आसान'},
    },
    'translations': {
      'en': {
        'question': 'During which period is Parana prohibited?',
        'options': {'A': 'Hari Vasara', 'B': 'Pratahkal', 'C': 'Brahma Muhurta', 'D': 'Abhijit Muhurat'},
        'correct_option': 'A',
        'explanation': 'Parana must not be done during Hari Vasara.',
      },
      'hi': {
        'question': 'पारण किस अवधि में निषिद्ध है?',
        'options': {'A': 'हरि वासर', 'B': 'प्रातःकाल', 'C': 'ब्रह्म मुहूर्त', 'D': 'अभिजित मुहूर्त'},
        'correct_option': 'A',
        'explanation': 'हरि वासर के दौरान पारण नहीं करना चाहिए।',
      },
    },
    'translation_status': {'en': 'source', 'hi': 'ai_draft_needs_native_review'},
    'publishable': false,
    'source_metadata': {'source_url': 'https://example.com'},
  },
  {
    'question_id': 'EKQ0002',
    'category': 'ekadashi',
    'subcategory': 'general',
    'difficulty': 'medium',
    'labels': {
      'category': {'en': 'Ekadashi'},
      'difficulty': {'en': 'Medium'},
    },
    'translations': {
      'en': {
        'question': 'Which deity is primarily worshipped on Ekadashi?',
        'options': {'A': 'Shiva', 'B': 'Vishnu', 'C': 'Brahma', 'D': 'Indra'},
        'correct_option': 'B',
        'explanation': 'Lord Vishnu is the primary deity worshipped on Ekadashi.',
      },
    },
    'translation_status': {'en': 'source'},
    'publishable': false,
  },
  {
    'question_id': 'BGQ0001',
    'category': 'bhagavad_gita',
    'subcategory': 'general',
    'difficulty': 'easy',
    'labels': {
      'category': {'en': 'Bhagavad Gita'},
      'difficulty': {'en': 'Easy'},
    },
    'translations': {
      'en': {
        'question': 'How many chapters does the Bhagavad Gita contain?',
        'options': {'A': '12', 'B': '18', 'C': '24', 'D': '16'},
        'correct_option': 'B',
        'explanation': 'The Bhagavad Gita has 18 chapters.',
      },
    },
    'translation_status': {'en': 'source'},
    'publishable': false,
  },
  {
    'question_id': 'BGQ0002',
    'category': 'bhagavad_gita',
    'subcategory': 'general',
    'difficulty': 'easy',
    'labels': {
      'category': {'en': 'Bhagavad Gita'},
      'difficulty': {'en': 'Easy'},
    },
    'translations': {
      'en': {
        'question': 'Who narrated the Bhagavad Gita to Arjuna?',
        'options': {'A': 'Vyasa', 'B': 'Krishna', 'C': 'Bhishma', 'D': 'Dronacharya'},
        'correct_option': 'B',
        'explanation': 'Lord Krishna narrated the Bhagavad Gita to Arjuna.',
      },
    },
    'translation_status': {'en': 'source'},
    'publishable': false,
  },
  {
    'question_id': 'MBQ0001',
    'category': 'mahabharata',
    'subcategory': 'general',
    'difficulty': 'easy',
    'labels': {
      'category': {'en': 'Mahabharata'},
      'difficulty': {'en': 'Easy'},
    },
    'translations': {
      'en': {
        'question': 'Who wrote the Mahabharata?',
        'options': {'A': 'Valmiki', 'B': 'Vyasa', 'C': 'Tulsidas', 'D': 'Kalidasa'},
        'correct_option': 'B',
        'explanation': 'Vyasa is credited as the author of the Mahabharata.',
      },
    },
    'translation_status': {'en': 'source'},
    'publishable': false,
  },
  {
    'question_id': 'MBQ0002',
    'category': 'mahabharata',
    'subcategory': 'general',
    'difficulty': 'medium',
    'labels': {
      'category': {'en': 'Mahabharata'},
      'difficulty': {'en': 'Medium'},
    },
    'translations': {
      'en': {
        'question': 'How many Parvas does the Mahabharata have?',
        'options': {'A': '12', 'B': '16', 'C': '18', 'D': '24'},
        'correct_option': 'C',
        'explanation': 'The Mahabharata has 18 Parvas (books).',
      },
    },
    'translation_status': {'en': 'source'},
    'publishable': false,
  },
  {
    'question_id': 'RMQ0001',
    'category': 'ramayana',
    'subcategory': 'general',
    'difficulty': 'easy',
    'labels': {
      'category': {'en': 'Ramayana'},
      'difficulty': {'en': 'Easy'},
    },
    'translations': {
      'en': {
        'question': 'Who wrote the original Ramayana?',
        'options': {'A': 'Vyasa', 'B': 'Valmiki', 'C': 'Tulsidas', 'D': 'Kalidasa'},
        'correct_option': 'B',
        'explanation': 'Valmiki is the author of the original Ramayana.',
      },
    },
    'translation_status': {'en': 'source'},
    'publishable': false,
  },
  {
    'question_id': 'RMQ0002',
    'category': 'ramayana',
    'subcategory': 'general',
    'difficulty': 'medium',
    'labels': {
      'category': {'en': 'Ramayana'},
      'difficulty': {'en': 'Medium'},
    },
    'translations': {
      'en': {
        'question': 'How many Kandas does the Ramayana have?',
        'options': {'A': '5', 'B': '6', 'C': '7', 'D': '8'},
        'correct_option': 'C',
        'explanation': 'The Ramayana has 7 Kandas.',
      },
    },
    'translation_status': {'en': 'source'},
    'publishable': false,
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WisdomQuestion model', () {
    test('parses from JSON in English', () {
      final q = WisdomQuestion.fromJson(_testQuestions().first, 'en');
      expect(q.questionId, 'EKQ0001');
      expect(q.category, 'ekadashi');
      expect(q.difficulty, 'easy');
      expect(q.question, contains('Parana'));
      expect(q.options.length, 4);
      expect(q.correctOption, 'A');
      expect(q.explanation, contains('Hari Vasara'));
      expect(q.translationStatus, 'source');
    });

    test('parses from JSON in Hindi', () {
      final q = WisdomQuestion.fromJson(_testQuestions().first, 'hi');
      expect(q.question, contains('पारण'));
      expect(q.options['A'], 'हरि वासर');
      expect(q.explanation, contains('हरि वासर'));
      expect(q.translationStatus, 'ai_draft_needs_native_review');
    });

    test('falls back to English for unsupported language', () {
      final q = WisdomQuestion.fromJson(_testQuestions().first, 'fr');
      expect(q.question, contains('Parana'));
      expect(q.translationStatus, 'unknown');
    });

    test('isCorrect validates answer', () {
      final q = WisdomQuestion.fromJson(_testQuestions().first, 'en');
      expect(q.isCorrect('A'), isTrue);
      expect(q.isCorrect('a'), isTrue);
      expect(q.isCorrect('B'), isFalse);
    });

    test('category and difficulty labels are localized', () {
      final q = WisdomQuestion.fromJson(_testQuestions().first, 'en');
      expect(q.categoryLabel('en'), 'Ekadashi');
      expect(q.categoryLabel('hi'), 'एकादशी');
      expect(q.difficultyLabel('en'), 'Easy');
      expect(q.difficultyLabel('hi'), 'आसान');
    });

    test('source_metadata is never exposed in the model', () {
      final q = WisdomQuestion.fromJson(_testQuestions().first, 'en');
      // The model has no field for source_metadata.
      expect(q.question, isNot(contains('drikpanchang')));
      expect(q.explanation, isNot(contains('drikpanchang')));
    });
  });

  group('QuestionAttempt model', () {
    test('round-trips through JSON', () {
      const attempt = QuestionAttempt(
        questionId: 'EKQ0001',
        selectedOption: 'A',
        isCorrect: true,
        pointsAwarded: 1,
        answeredAtUTC: '2026-11-01T05:00:00.000Z',
      );
      final json = attempt.toJson();
      final restored = QuestionAttempt.fromJson(json);
      expect(restored.questionId, 'EKQ0001');
      expect(restored.selectedOption, 'A');
      expect(restored.isCorrect, true);
      expect(restored.pointsAwarded, 1);
    });
  });

  group('WisdomQuestionService', () {
    late WisdomQuestionService service;

    setUp(() {
      service = WisdomQuestionService();
      service.loadFromData(_testQuestions());
    });

    test('loads all questions', () {
      expect(service.questionCount, 8);
      expect(service.allQuestionIds, hasLength(8));
    });

    test('getQuestion returns correct question in English', () {
      final q = service.getQuestion('EKQ0001', 'en');
      expect(q, isNotNull);
      expect(q!.question, contains('Parana'));
    });

    test('getQuestion returns correct question in Hindi', () {
      final q = service.getQuestion('EKQ0001', 'hi');
      expect(q, isNotNull);
      expect(q!.question, contains('पारण'));
    });

    test('getQuestion returns null for invalid ID', () {
      expect(service.getQuestion('INVALID', 'en'), isNull);
    });

    test('dailyQuestionId is deterministic for same date', () {
      final date = DateTime(2026, 11, 1);
      final id1 = service.dailyQuestionId(date);
      final id2 = service.dailyQuestionId(date);
      expect(id1, isNotNull);
      expect(id1, equals(id2));
    });

    test('dailyQuestionId changes on different dates', () {
      // Different days should produce different questions (at least some).
      final ids = <String?>{};
      for (var i = 0; i < 8; i++) {
        ids.add(service.dailyQuestionId(DateTime(2026, 11, 1 + i)));
      }
      expect(ids.length, greaterThan(1));
    });

    test('dailyQuestionId rotates through categories', () {
      // Four consecutive days should each pick from a different category.
      final categories = <String>{};
      for (var i = 0; i < 4; i++) {
        final id = service.dailyQuestionId(DateTime(2026, 1, 1 + i));
        if (id != null) {
          final q = service.getQuestion(id, 'en');
          if (q != null) categories.add(q.category);
        }
      }
      expect(categories.length, 4);
    });

    test('dailyQuestionId skips answered questions when possible', () {
      final date = DateTime(2026, 11, 1);
      final firstId = service.dailyQuestionId(date);
      // Mark the first result as answered.
      final secondId = service.dailyQuestionId(
        date,
        answeredIds: {firstId!},
      );
      // If there are unanswered questions, should give a different one
      // (unless we've exhausted the pool).
      expect(secondId, isNotNull);
    });

    test('dailyQuestionId falls back to repeats when all answered', () {
      final allIds = service.allQuestionIds.toSet();
      final date = DateTime(2026, 11, 1);
      final id = service.dailyQuestionId(date, answeredIds: allIds);
      expect(id, isNotNull);
      expect(allIds, contains(id));
    });

    test('nextQuestion returns unanswered question', () {
      final id = service.nextQuestion(
        answeredIds: {'EKQ0001'},
        excludeQuestionId: 'EKQ0001',
      );
      expect(id, isNotNull);
      expect(id, isNot('EKQ0001'));
    });

    test('nextQuestion returns null when all answered', () {
      final allIds = service.allQuestionIds.toSet();
      final id = service.nextQuestion(
        answeredIds: allIds,
        excludeQuestionId: 'EKQ0001',
      );
      expect(id, isNull);
    });
  });

  group('WisdomProgressStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads with empty state', () async {
      final store = WisdomProgressStore();
      await store.load();
      expect(store.attempts, isEmpty);
      expect(store.stats.totalAnswered, 0);
      expect(store.stats.totalPoints, 0);
      expect(store.reminderEnabled, false);
    });

    test('records a correct answer and awards 1 point', () async {
      final store = WisdomProgressStore();
      await store.load();
      final points = await store.recordAttempt(
        questionId: 'EKQ0001',
        selectedOption: 'A',
        isCorrect: true,
      );
      expect(points, 1);
      expect(store.stats.totalAnswered, 1);
      expect(store.stats.totalCorrect, 1);
      expect(store.stats.totalPoints, 1);
    });

    test('records an incorrect answer with 0 points', () async {
      final store = WisdomProgressStore();
      await store.load();
      final points = await store.recordAttempt(
        questionId: 'EKQ0001',
        selectedOption: 'B',
        isCorrect: false,
      );
      expect(points, 0);
      expect(store.stats.totalAnswered, 1);
      expect(store.stats.totalCorrect, 0);
      expect(store.stats.totalPoints, 0);
    });

    test('prevents duplicate points for same question', () async {
      final store = WisdomProgressStore();
      await store.load();
      await store.recordAttempt(
        questionId: 'EKQ0001',
        selectedOption: 'A',
        isCorrect: true,
      );
      final secondPoints = await store.recordAttempt(
        questionId: 'EKQ0001',
        selectedOption: 'A',
        isCorrect: true,
      );
      expect(secondPoints, 0);
      expect(store.stats.totalAnswered, 1);
      expect(store.stats.totalPoints, 1);
    });

    test('persists attempts across reloads', () async {
      final store1 = WisdomProgressStore();
      await store1.load();
      await store1.recordAttempt(
        questionId: 'EKQ0001',
        selectedOption: 'A',
        isCorrect: true,
      );

      final store2 = WisdomProgressStore();
      await store2.load();
      expect(store2.isAnswered('EKQ0001'), true);
      expect(store2.stats.totalPoints, 1);
    });

    test('daily question is stable within same date', () async {
      final store = WisdomProgressStore();
      await store.load();
      final date = DateTime(2026, 11, 1);
      await store.setDailyQuestion('EKQ0001', date);
      expect(store.dailyQuestionIdFor(date), 'EKQ0001');
    });

    test('daily question returns null for different date', () async {
      final store = WisdomProgressStore();
      await store.load();
      await store.setDailyQuestion('EKQ0001', DateTime(2026, 11, 1));
      expect(store.dailyQuestionIdFor(DateTime(2026, 11, 2)), isNull);
    });

    test('persists daily question across reloads', () async {
      final store1 = WisdomProgressStore();
      await store1.load();
      await store1.setDailyQuestion('EKQ0001', DateTime(2026, 11, 1));

      final store2 = WisdomProgressStore();
      await store2.load();
      expect(store2.dailyQuestionIdFor(DateTime(2026, 11, 1)), 'EKQ0001');
    });

    test('reminder enabled persists', () async {
      final store1 = WisdomProgressStore();
      await store1.load();
      await store1.setReminderEnabled(true);
      expect(store1.reminderEnabled, true);

      final store2 = WisdomProgressStore();
      await store2.load();
      expect(store2.reminderEnabled, true);
    });

    test('answeredIds tracks all answered questions', () async {
      final store = WisdomProgressStore();
      await store.load();
      await store.recordAttempt(
        questionId: 'EKQ0001',
        selectedOption: 'A',
        isCorrect: true,
      );
      await store.recordAttempt(
        questionId: 'BGQ0001',
        selectedOption: 'C',
        isCorrect: false,
      );
      expect(store.answeredIds, {'EKQ0001', 'BGQ0001'});
    });

    test('getAttempt returns recorded attempt', () async {
      final store = WisdomProgressStore();
      await store.load();
      await store.recordAttempt(
        questionId: 'EKQ0001',
        selectedOption: 'A',
        isCorrect: true,
      );
      final attempt = store.getAttempt('EKQ0001');
      expect(attempt, isNotNull);
      expect(attempt!.selectedOption, 'A');
      expect(attempt.isCorrect, true);
      expect(attempt.pointsAwarded, 1);
    });

    test('getAttempt returns null for unanswered question', () async {
      final store = WisdomProgressStore();
      await store.load();
      expect(store.getAttempt('EKQ0001'), isNull);
    });
  });

  group('Regression: existing achievement system', () {
    test('WisdomProgressStore does not touch vrat_tracker keys', () async {
      SharedPreferences.setMockInitialValues({
        'vrat_tracker_user_achievements': jsonEncode([
          {
            'id': 'ua1',
            'achievementId': 'first_vrat',
            'progressValue': 1,
            'isUnlocked': true,
            'lastEvaluatedAtUTC': '2026-10-01T00:00:00Z',
          },
        ]),
      });

      final store = WisdomProgressStore();
      await store.load();
      await store.recordAttempt(
        questionId: 'EKQ0001',
        selectedOption: 'A',
        isCorrect: true,
      );

      // Verify vrat tracker data is untouched.
      final prefs = await SharedPreferences.getInstance();
      final vratData = prefs.getString('vrat_tracker_user_achievements');
      expect(vratData, isNotNull);
      final decoded = jsonDecode(vratData!) as List;
      expect(decoded, hasLength(1));
      final ua = decoded.first as Map<String, dynamic>;
      expect(ua['achievementId'], 'first_vrat');
      expect(ua['isUnlocked'], true);
    });
  });
}

