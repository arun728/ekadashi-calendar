import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/wisdom_selection_service.dart';

void main() {
  late List<Map<String, dynamic>> rawQuestions;
  late WisdomSelectionService selectionService;

  setUpAll(() {
    final file = File('assets/wisdom/ekadashi_wisdom_full_bank_multilingual.json');
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    rawQuestions = List<Map<String, dynamic>>.from(data['questions'] as List);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    selectionService = WisdomSelectionService();
  });

  group('WisdomSelectionService - Sequence & Balancing', () {
    test('Builds balanced sequence rotating across categories without single-category clustering', () {
      final sequence = selectionService.buildBalancedSequence(
        rawQuestions,
        seed: 42,
      );
      expect(sequence.length, equals(rawQuestions.length));

      // Check for category clustering: no 4 consecutive questions should be of the same category
      // when other categories are still available
      final qMap = {for (final q in rawQuestions) q['question_id'] as String: q};
      int maxConsecutiveSameCategory = 0;
      int currentConsecutive = 1;
      String? lastCategory;

      for (final id in sequence) {
        final cat = qMap[id]!['category'] as String;
        if (cat == lastCategory) {
          currentConsecutive++;
          if (currentConsecutive > maxConsecutiveSameCategory) {
            maxConsecutiveSameCategory = currentConsecutive;
          }
        } else {
          currentConsecutive = 1;
          lastCategory = cat;
        }
      }

      // In the first 140 questions (before smaller categories run out), max consecutive should be <= 2
      final first140 = sequence.take(140).toList();
      int first140MaxConsecutive = 0;
      currentConsecutive = 1;
      lastCategory = null;
      for (final id in first140) {
        final cat = qMap[id]!['category'] as String;
        if (cat == lastCategory) {
          currentConsecutive++;
          if (currentConsecutive > first140MaxConsecutive) {
            first140MaxConsecutive = currentConsecutive;
          }
        } else {
          currentConsecutive = 1;
          lastCategory = cat;
        }
      }
      expect(first140MaxConsecutive, lessThanOrEqualTo(2));
    });

    test('Mixes classic and kbc formats throughout the sequence', () {
      final sequence = selectionService.buildBalancedSequence(
        rawQuestions,
        seed: 42,
      );
      final qMap = {for (final q in rawQuestions) q['question_id'] as String: q};

      final first50 = sequence.take(50).map((id) => qMap[id]!['format']).toList();
      expect(first50.contains('classic'), isTrue);
      expect(first50.contains('kbc'), isTrue);
    });

    test('Mixes easy, medium, and hard difficulties', () {
      final sequence = selectionService.buildBalancedSequence(
        rawQuestions,
        seed: 42,
      );
      final qMap = {for (final q in rawQuestions) q['question_id'] as String: q};

      final first30Difficulties = sequence
          .take(30)
          .map((id) => qMap[id]!['difficulty'] as String)
          .toSet();
      expect(first30Difficulties, containsAll(['easy', 'medium', 'hard']));
    });

    test('Avoids consecutive questions sharing the same concept_id', () {
      final sequence = selectionService.buildBalancedSequence(
        rawQuestions,
        seed: 42,
      );
      final qMap = {for (final q in rawQuestions) q['question_id'] as String: q};

      String? lastConcept;
      for (final id in sequence) {
        final concept = qMap[id]!['concept_id'] as String?;
        if (concept != null && lastConcept != null) {
          expect(concept != lastConcept, isTrue, reason: 'Consecutive questions have identical concept: $concept');
        }
        lastConcept = concept;
      }
    });

    test('Persists learning sequence and restores state across application restarts', () async {
      final prefs = await SharedPreferences.getInstance();
      await selectionService.init(rawQuestions, prefs: prefs);

      final initialQuestionId = selectionService.currentQuestionId;
      expect(initialQuestionId, isNotNull);

      // Advance sequence by skipping or answering
      final nextId = await selectionService.advance(prefs: prefs);
      expect(nextId, isNot(equals(initialQuestionId)));

      // Re-create service simulating app restart
      final newServiceInstance = WisdomSelectionService();
      await newServiceInstance.init(rawQuestions, prefs: prefs);

      // Must restore exact current question and sequence
      expect(newServiceInstance.currentQuestionId, equals(nextId));
      expect(newServiceInstance.sequence, equals(selectionService.sequence));
    });

    test('Daily question assignment is stable for same calendar date', () async {
      final prefs = await SharedPreferences.getInstance();
      await selectionService.init(rawQuestions, prefs: prefs);

      final date1 = DateTime(2026, 11, 6, 8, 30);
      final q1 = await selectionService.getOrAssignDailyQuestion(date1, prefs: prefs);

      // Same day, different time
      final date1Later = DateTime(2026, 11, 6, 21, 45);
      final q1Later = await selectionService.getOrAssignDailyQuestion(date1Later, prefs: prefs);
      expect(q1Later, equals(q1));

      // Different day -> different question
      final date2 = DateTime(2026, 11, 7, 9, 0);
      final q2 = await selectionService.getOrAssignDailyQuestion(date2, prefs: prefs);
      expect(q2, isNot(equals(q1)));
    });

    test('Exhaustion detected when all questions in sequence are answered', () async {
      final prefs = await SharedPreferences.getInstance();
      final smallPool = rawQuestions.take(3).toList();
      await selectionService.init(smallPool, prefs: prefs);

      expect(selectionService.isExhausted, isFalse);

      final qIds = smallPool.map((q) => q['question_id'] as String).toSet();
      selectionService.markCompleted(qIds);

      expect(selectionService.isExhausted, isTrue);
    });
  });
}

