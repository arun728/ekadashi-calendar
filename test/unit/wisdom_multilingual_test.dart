import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/wisdom_question_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> rawWisdomJson;
  late Map<String, dynamic> rawGlossaryJson;

  setUpAll(() {
    final wisdomFile = File('assets/wisdom/ekadashi_wisdom.json');
    expect(wisdomFile.existsSync(), isTrue);
    rawWisdomJson = jsonDecode(wisdomFile.readAsStringSync()) as Map<String, dynamic>;

    final glossaryFile = File('assets/wisdom/religious_terms_glossary.json');
    expect(glossaryFile.existsSync(), isTrue);
    rawGlossaryJson = jsonDecode(glossaryFile.readAsStringSync()) as Map<String, dynamic>;
  });

  group('Wisdom Dataset Integrity & Parity', () {
    test('Dataset contains exactly 80 questions with 20 per category', () {
      final questions = rawWisdomJson['questions'] as List;
      expect(questions.length, 80);

      final categoryCounts = <String, int>{};
      for (final q in questions) {
        final cat = q['category'] as String;
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      }

      expect(categoryCounts['ekadashi'], 20);
      expect(categoryCounts['bhagavad_gita'], 20);
      expect(categoryCounts['mahabharata'], 20);
      expect(categoryCounts['ramayana'], 20);
    });

    test('All categories contain easy, medium, and hard difficulties', () {
      final questions = rawWisdomJson['questions'] as List;
      final categoryDifficulties = <String, Set<String>>{};

      for (final q in questions) {
        final cat = q['category'] as String;
        final diff = q['difficulty'] as String;
        categoryDifficulties.putIfAbsent(cat, () => <String>{}).add(diff);
      }

      for (final cat in ['ekadashi', 'bhagavad_gita', 'mahabharata', 'ramayana']) {
        expect(categoryDifficulties[cat], containsAll(['easy', 'medium', 'hard']));
      }
    });

    test('All questions have valid correct answers in [A, B, C, D]', () {
      final questions = rawWisdomJson['questions'] as List;
      for (final q in questions) {
        final t = (q['translations'] as Map<String, dynamic>)['en'] as Map<String, dynamic>;
        final correct = t['correct_option'] as String;
        expect(['A', 'B', 'C', 'D'], contains(correct),
            reason: 'Question ${q['question_id']} has invalid correct_option: $correct');
      }
    });

    test('All 80 questions have complete translations in all 6 supported languages', () {
      final questions = rawWisdomJson['questions'] as List;
      final languages = ['en', 'hi', 'ta', 'te', 'gu', 'bn'];

      for (final q in questions) {
        final qId = q['question_id'] as String;
        final translations = q['translations'] as Map<String, dynamic>;

        for (final lang in languages) {
          expect(translations.containsKey(lang), isTrue,
              reason: 'Question $qId missing translation for $lang');

          final t = translations[lang] as Map<String, dynamic>;
          expect(t['question']?.toString().trim().isNotEmpty, isTrue,
              reason: 'Question $qId has empty question text for $lang');

          final options = t['options'] as Map<String, dynamic>?;
          expect(options, isNotNull, reason: 'Question $qId missing options for $lang');
          for (final optKey in ['A', 'B', 'C', 'D']) {
            expect(options![optKey]?.toString().trim().isNotEmpty, isTrue,
                reason: 'Question $qId option $optKey is empty for $lang');
          }

          expect(t['explanation']?.toString().trim().isNotEmpty, isTrue,
              reason: 'Question $qId has empty explanation for $lang');
        }
      }
    });

    test('No English / Latin characters in non-English question texts and options', () {
      // Per AGENTS.md rule: "In Hindi, Tamil, Telugu, Gujarati and Bengali no English
      // or Latin letters appear anywhere on screen".
      // Note: Option keys inside internal JSON are 'A','B','C','D', but question text,
      // option texts and explanations must not have Latin characters.
      final latinPattern = RegExp(r'[a-zA-Z]');
      final questions = rawWisdomJson['questions'] as List;
      final nonEnglishLangs = ['hi', 'ta', 'te', 'gu', 'bn'];

      for (final q in questions) {
        final qId = q['question_id'] as String;
        final translations = q['translations'] as Map<String, dynamic>;

        for (final lang in nonEnglishLangs) {
          final t = translations[lang] as Map<String, dynamic>;
          final qText = t['question'] as String;
          expect(latinPattern.hasMatch(qText), isFalse,
              reason: 'Question $qId in $lang contains Latin letters: "$qText"');

          final options = t['options'] as Map<String, dynamic>;
          for (final optEntry in options.entries) {
            final optVal = optEntry.value as String;
            expect(latinPattern.hasMatch(optVal), isFalse,
                reason: 'Question $qId option ${optEntry.key} in $lang contains Latin letters: "$optVal"');
          }

          final explanation = t['explanation'] as String;
          expect(latinPattern.hasMatch(explanation), isFalse,
              reason: 'Question $qId explanation in $lang contains Latin letters: "$explanation"');
        }
      }
    });

    test('Religious terms glossary contains valid translations in 6 languages', () {
      expect(rawGlossaryJson.isNotEmpty, isTrue);
      for (final section in ['structural_words', 'names', 'numbers', 'months']) {
        final sectionMap = rawGlossaryJson[section] as Map<String, dynamic>;
        expect(sectionMap.isNotEmpty, isTrue);
        for (final entry in sectionMap.entries) {
          final tr = entry.value as Map<String, dynamic>;
          for (final l in ['hi', 'ta', 'te', 'gu', 'bn']) {
            expect(tr.containsKey(l), isTrue,
                reason: 'Glossary term ${entry.key} missing $l translation');
          }
        }
      }
    });

    test('WisdomQuestionService parses all questions cleanly into models', () {
      final service = WisdomQuestionService();
      service.loadFromData(List<Map<String, dynamic>>.from(rawWisdomJson['questions'] as List));

      expect(service.allQuestionIds.length, 80);

      for (final id in service.allQuestionIds) {
        for (final lang in ['en', 'hi', 'ta', 'te', 'gu', 'bn']) {
          final q = service.getQuestion(id, lang);
          expect(q, isNotNull);
          expect(q!.options.length, 4);
          expect(q.options.containsKey('A'), isTrue);
          expect(q.options.containsKey('B'), isTrue);
          expect(q.options.containsKey('C'), isTrue);
          expect(q.options.containsKey('D'), isTrue);
          expect(q.correctOption, isIn(['A', 'B', 'C', 'D']));
        }
      }
    });
  });
}
