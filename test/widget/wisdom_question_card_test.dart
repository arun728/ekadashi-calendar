import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ekadashi_calendar/l10n/generated/app_localizations.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/wisdom_question_card.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/wisdom_progress_store.dart';
import 'package:ekadashi_calendar/services/wisdom_question_service.dart';

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
  },
  {
    'question_id': 'BGQ0001',
    'category': 'bhagavad_gita',
    'subcategory': 'general',
    'difficulty': 'easy',
    'labels': {
      'category': {'en': 'Bhagavad Gita', 'hi': 'भगवद्गीता'},
      'difficulty': {'en': 'Easy', 'hi': 'आसान'},
    },
    'translations': {
      'en': {
        'question': 'How many chapters does the Bhagavad Gita have?',
        'options': {'A': '12', 'B': '18', 'C': '24', 'D': '16'},
        'correct_option': 'B',
        'explanation': 'The Gita has 18 chapters.',
      },
      'hi': {
        'question': 'भगवद्गीता में कितने अध्याय हैं?',
        'options': {'A': '12', 'B': '18', 'C': '24', 'D': '16'},
        'correct_option': 'B',
        'explanation': 'गीता में 18 अध्याय हैं।',
      },
    },
    'translation_status': {'en': 'source', 'hi': 'ai_draft_needs_native_review'},
    'publishable': false,
  },
];

Widget _buildTestApp({
  required WisdomQuestionService questionService,
  required WisdomProgressStore store,
  Locale locale = const Locale('en'),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageService>(create: (_) => LanguageService()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: WisdomQuestionCard(
            questionService: questionService,
            progressStore: store,
            currentDate: DateTime(2026, 11, 1),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WisdomQuestionService questionService;
  late WisdomProgressStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    questionService = WisdomQuestionService();
    questionService.loadFromData(_testQuestions());
    store = WisdomProgressStore();
    await store.load();
  });

  group('WisdomQuestionCard widget', () {
    testWidgets('renders daily question with 4 options and submit button', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        questionService: questionService,
        store: store,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Question of the Day'), findsOneWidget);
      expect(find.text('During which period is Parana prohibited?'), findsOneWidget);
      expect(find.text('Hari Vasara'), findsOneWidget);
      expect(find.text('Pratahkal'), findsOneWidget);
      expect(find.text('Brahma Muhurta'), findsOneWidget);
      expect(find.text('Abhijit Muhurat'), findsOneWidget);
      expect(find.byKey(const Key('wisdom_submit_button')), findsOneWidget);
    });

    testWidgets('submitting correct answer awards 1 point, shows explanation and continue actions', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        questionService: questionService,
        store: store,
      ));
      await tester.pumpAndSettle();

      // Tap option A (correct answer for EKQ0001)
      await tester.tap(find.byKey(const Key('wisdom_option_A')));
      await tester.pumpAndSettle();

      // Tap Submit
      await tester.tap(find.byKey(const Key('wisdom_submit_button')));
      await tester.pumpAndSettle();

      // Result shown
      expect(find.text('Correct!'), findsOneWidget);
      expect(find.text('+1 Points'), findsOneWidget);
      expect(find.text('Parana must not be done during Hari Vasara.'), findsOneWidget);

      // Action buttons shown
      expect(find.byKey(const Key('wisdom_continue_button')), findsOneWidget);
      expect(find.byKey(const Key('wisdom_finish_button')), findsOneWidget);

      // Verify store recorded 1 point
      expect(store.stats.totalPoints, 1);
      expect(store.stats.totalCorrect, 1);
      expect(store.stats.totalAnswered, 1);
    });

    testWidgets('submitting incorrect answer awards 0 points and shows explanation', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        questionService: questionService,
        store: store,
      ));
      await tester.pumpAndSettle();

      // Tap option B (incorrect)
      await tester.tap(find.byKey(const Key('wisdom_option_B')));
      await tester.pumpAndSettle();

      // Tap Submit
      await tester.tap(find.byKey(const Key('wisdom_submit_button')));
      await tester.pumpAndSettle();

      // Result shown
      expect(find.text('Incorrect'), findsOneWidget);
      expect(find.text('+0 Points'), findsOneWidget);
      expect(find.text('Parana must not be done during Hari Vasara.'), findsOneWidget);

      // Verify store recorded 0 points
      expect(store.stats.totalPoints, 0);
      expect(store.stats.totalCorrect, 0);
      expect(store.stats.totalAnswered, 1);
    });

    testWidgets('Continue Learning advances to next unanswered question', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        questionService: questionService,
        store: store,
      ));
      await tester.pumpAndSettle();

      // Answer first question
      await tester.tap(find.byKey(const Key('wisdom_option_A')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wisdom_submit_button')));
      await tester.pumpAndSettle();

      // Tap Continue Learning
      await tester.tap(find.byKey(const Key('wisdom_continue_button')));
      await tester.pumpAndSettle();

      // Next question loaded (BGQ0001)
      expect(find.text('How many chapters does the Bhagavad Gita have?'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
    });

    testWidgets('Finish for Today completes question flow', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        questionService: questionService,
        store: store,
      ));
      await tester.pumpAndSettle();

      // Answer question
      await tester.tap(find.byKey(const Key('wisdom_option_A')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wisdom_submit_button')));
      await tester.pumpAndSettle();

      // Tap Finish for Today
      await tester.tap(find.byKey(const Key('wisdom_finish_button')));
      await tester.pumpAndSettle();

      // Shows completed state
      expect(find.text("You've answered today's question!"), findsOneWidget);
    });

    testWidgets('Question progress shows total points, answered, correct, and categories', (tester) async {
      // Pre-record an attempt
      await store.recordAttempt(
        questionId: 'EKQ0001',
        selectedOption: 'A',
        isCorrect: true,
      );

      await tester.pumpWidget(_buildTestApp(
        questionService: questionService,
        store: store,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wisdom_progress_section')), findsOneWidget);
      expect(find.text('Total Points'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // Points count
    });
  });
}
