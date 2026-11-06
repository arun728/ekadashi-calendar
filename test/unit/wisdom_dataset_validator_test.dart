import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/models/wisdom_question.dart';
import 'package:ekadashi_calendar/services/wisdom_content_validator.dart';

void main() {
  late Map<String, dynamic> fullBankJson;
  late WisdomContentValidator validator;

  setUpAll(() {
    final file = File('assets/wisdom/ekadashi_wisdom_full_bank_multilingual.json');
    expect(file.existsSync(), isTrue, reason: 'Full bank JSON file must exist in assets/wisdom/');
    fullBankJson = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    validator = WisdomContentValidator();
  });

  group('Wisdom Dataset Schema 3.0 & Integrity', () {
    test('Top-level metadata adheres to Schema 3.0', () {
      expect(fullBankJson['dataset_name'], equals('Ekadashi Wisdom Challenge - full question bank'));
      expect(fullBankJson['schema_version'], equals('3.0'));
      expect(fullBankJson['supported_languages'], isA<List>());
      expect(fullBankJson['option_labels'], isA<Map>());
      expect(fullBankJson['labels'], isA<Map>());
      expect(fullBankJson['ui_strings'], isA<Map>());
      expect(fullBankJson['questions'], isA<List>());
    });

    test('Contains exactly 218 questions with correct distribution', () {
      final questions = fullBankJson['questions'] as List;
      expect(questions.length, equals(218));

      final categories = <String, int>{};
      final formats = <String, int>{};
      final difficulties = <String, int>{};

      for (final q in questions) {
        final cat = q['category'] as String;
        final fmt = q['format'] as String;
        final diff = q['difficulty'] as String;
        categories[cat] = (categories[cat] ?? 0) + 1;
        formats[fmt] = (formats[fmt] ?? 0) + 1;
        difficulties[diff] = (difficulties[diff] ?? 0) + 1;
      }

      // Exactly as specified in prompt:
      expect(categories['ekadashi'], equals(100));
      expect(categories['bhagavad_gita'], equals(45));
      expect(categories['mahabharata'], equals(37));
      expect(categories['ramayana'], equals(36));

      expect(formats['classic'], equals(178));
      expect(formats['kbc'], equals(40));

      expect(difficulties['easy'], equals(58));
      expect(difficulties['medium'], equals(92));
      expect(difficulties['hard'], equals(68));
    });

    test('Option labels exist for all 6 supported languages', () {
      final optionLabels = fullBankJson['option_labels'] as Map<String, dynamic>;
      const languages = ['en', 'hi', 'ta', 'te', 'gu', 'bn'];
      for (final lang in languages) {
        expect(optionLabels.containsKey(lang), isTrue, reason: 'Missing option_labels for $lang');
        final labels = List<String>.from(optionLabels[lang] as List);
        expect(labels.length, equals(4), reason: 'Option labels for $lang must have 4 entries (A, B, C, D)');
      }
      expect(optionLabels['en'], equals(['A', 'B', 'C', 'D']));
      expect(optionLabels['hi'], equals(['क', 'ख', 'ग', 'घ']));
      expect(optionLabels['ta'], equals(['அ', 'ஆ', 'இ', 'ஈ']));
      expect(optionLabels['te'], equals(['అ', 'ఆ', 'ఇ', 'ఈ']));
      expect(optionLabels['gu'], equals(['અ', 'બ', 'ક', 'ડ']));
      expect(optionLabels['bn'], equals(['ক', 'খ', 'গ', 'ঘ']));
    });

    test('Content validator validates full dataset with 0 fatal errors', () {
      final report = validator.validate(fullBankJson);
      expect(report.isValid, isTrue, reason: 'Dataset failed validation: ${report.errors.join("\n")}');
      expect(report.totalQuestions, equals(218));
      expect(report.errors, isEmpty);
    });

    test('WisdomQuestion parses classic and kbc schema 3.0 fields properly', () {
      final questions = fullBankJson['questions'] as List;
      final classicRaw = questions.firstWhere((q) => q['format'] == 'classic');
      final kbcRaw = questions.firstWhere((q) => q['format'] == 'kbc');

      final classicQ = WisdomQuestion.fromJson(classicRaw as Map<String, dynamic>, 'en');
      expect(classicQ.format, equals(WisdomFormat.classic));
      expect(classicQ.questionId, isNotEmpty);
      expect(classicQ.options.keys, containsAll(['A', 'B', 'C', 'D']));
      expect(classicQ.explanation, isNotEmpty);

      final kbcQ = WisdomQuestion.fromJson(kbcRaw as Map<String, dynamic>, 'en');
      expect(kbcQ.format, equals(WisdomFormat.kbc));
      expect(kbcQ.questionId, isNotEmpty);
      expect(kbcQ.options.keys, containsAll(['A', 'B', 'C', 'D']));
      expect(kbcQ.insight, isNotNull);
      expect(kbcQ.optionFeedback, isNotNull);
    });
  });
}
