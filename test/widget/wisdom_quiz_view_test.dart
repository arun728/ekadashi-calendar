import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/wisdom_progress_store.dart';
import 'package:ekadashi_calendar/services/wisdom_question_service.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/wisdom_question_card.dart';

void main() {
  late WisdomProgressStore store;
  late WisdomQuestionService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = WisdomProgressStore.instance;
    await store.resetForTesting();
    service = WisdomQuestionService.instance;
  });

  Widget buildTestWidget({
    Locale locale = const Locale('en'),
    WisdomQuestionCard? card,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WisdomProgressStore>.value(value: store),
        ChangeNotifierProvider<LanguageService>(
          create: (_) => LanguageService()..changeLanguage(locale.languageCode),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        home: Scaffold(
          body: SingleChildScrollView(
            child: card ??
                WisdomQuestionCard(
                  questionService: service,
                  progressStore: store,
                  currentDate: DateTime(2026, 11, 6),
                ),
          ),
        ),
      ),
    );
  }

  group('Wisdom UI & Formats (Classic, KBC, Localized Option Labels)', () {
    testWidgets('Renders localized option labels in Tamil (அ, ஆ, இ, ஈ)', (tester) async {
      service.loadFromData([
        {
          'question_id': 'TA_OPT_01',
          'category': 'ekadashi',
          'subcategory': 'general',
          'difficulty': 'easy',
          'format': 'classic',
          'publishable': true,
          'verification_status': 'reviewed',
          'available_languages': ['en', 'ta'],
          'translations': {
            'ta': {
              'question': 'ஏகாதசி விரதத்தின் முக்கிய நோக்கம் என்ன?',
              'options': {
                'A': 'இறை சிந்தனை',
                'B': 'உணவு கட்டுப்பாடு',
                'C': 'தியானம்',
                'D': 'தானம்',
              },
              'correct_option': 'A',
              'explanation': 'விளக்கம்',
            },
          },
        },
      ], metadata: {
        'option_labels': {
          'ta': ['அ', 'ஆ', 'இ', 'ஈ'],
        },
        'labels': {
          'category': {
            'ekadashi': {'ta': 'ஏகாதசி'},
          },
        },
      });

      await store.setDailyQuestion('TA_OPT_01', DateTime(2026, 11, 6));

      await tester.pumpWidget(buildTestWidget(locale: const Locale('ta')));
      await tester.pumpAndSettle();

      // Check localized option keys are displayed
      expect(find.text('அ'), findsOneWidget);
      expect(find.text('ஆ'), findsOneWidget);
      expect(find.text('இ'), findsOneWidget);
      expect(find.text('ஈ'), findsOneWidget);
    });

    testWidgets('Renders KBC format with context and insight', (tester) async {
      service.loadFromData([
        {
          'question_id': 'KBC_01',
          'category': 'bhagavad_gita',
          'subcategory': 'dialogue',
          'difficulty': 'medium',
          'format': 'kbc',
          'publishable': true,
          'verification_status': 'reviewed',
          'available_languages': ['en'],
          'translations': {
            'en': {
              'context': 'Kurukshetra Battlefield Scenario',
              'question': 'Who blew the Panchajanya conch?',
              'options': {
                'A': 'Arjuna',
                'B': 'Krishna',
                'C': 'Yudhishthira',
                'D': 'Bhima',
              },
              'correct_option': 'B',
              'explanation': 'Krishna blew the Panchajanya conch.',
              'insight': 'Conch shells signaled the beginning of righteous war.',
            },
          },
        },
      ]);

      await store.setDailyQuestion('KBC_01', DateTime(2026, 11, 6));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify KBC context scenario is displayed
      expect(find.text('Kurukshetra Battlefield Scenario'), findsOneWidget);
      expect(find.text('Who blew the Panchajanya conch?'), findsOneWidget);

      // Select option B and submit
      await tester.tap(find.byKey(const Key('wisdom_option_B')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('wisdom_submit_button')));
      await tester.pumpAndSettle();

      // Verify explanation and insight are displayed
      expect(find.text('Krishna blew the Panchajanya conch.'), findsOneWidget);
      expect(find.text('Conch shells signaled the beginning of righteous war.'), findsOneWidget);
    });

    testWidgets('Skip button records skip and advances without awarding points', (tester) async {
      service.loadFromData([
        {
          'question_id': 'SKIP_01',
          'category': 'ekadashi',
          'subcategory': 'general',
          'difficulty': 'easy',
          'format': 'classic',
          'publishable': true,
          'verification_status': 'reviewed',
          'available_languages': ['en'],
          'translations': {
            'en': {
              'question': 'Question to Skip?',
              'options': {'A': '1', 'B': '2', 'C': '3', 'D': '4'},
              'correct_option': 'A',
              'explanation': 'Exp',
            },
          },
        },
        {
          'question_id': 'NEXT_02',
          'category': 'mahabharata',
          'subcategory': 'general',
          'difficulty': 'easy',
          'format': 'classic',
          'publishable': true,
          'verification_status': 'reviewed',
          'available_languages': ['en'],
          'translations': {
            'en': {
              'question': 'Next Question After Skip?',
              'options': {'A': '1', 'B': '2', 'C': '3', 'D': '4'},
              'correct_option': 'B',
              'explanation': 'Exp',
            },
          },
        },
      ]);

      await store.setDailyQuestion('SKIP_01', DateTime(2026, 11, 6));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find Skip button
      final skipButton = find.byKey(const Key('wisdom_skip_button'));
      expect(skipButton, findsOneWidget);

      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      // Verify points remained 0
      expect(store.stats.totalPoints, equals(0));
      expect(store.stats.totalSkipped, equals(1));
    });
  });
}
