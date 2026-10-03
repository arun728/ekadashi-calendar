import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/screens/global_search_screen.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/services/recent_search_repository.dart';

Widget createSearchTestApp() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeService()),
      ChangeNotifierProvider(create: (_) => LanguageService()),
    ],
    child: const MaterialApp(
      home: GlobalSearchScreen(
        ekadashiList: [],
        currentTimezone: 'IST',
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Typing keystrokes (p, pa, par) does NOT save intermediate recent searches', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = RecentSearchRepository();

    await tester.pumpWidget(createSearchTestApp());
    await tester.pumpAndSettle();

    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    // Initial state: 0 recent searches
    var recents = await repo.getRecentSearches();
    expect(recents.isEmpty, true);

    // Type 'p'
    await tester.enterText(textFieldFinder, 'p');
    await tester.pump(const Duration(milliseconds: 300));
    recents = await repo.getRecentSearches();
    expect(recents.isEmpty, true, reason: 'Typing "p" must NOT save to recent searches');

    // Type 'pa'
    await tester.enterText(textFieldFinder, 'pa');
    await tester.pump(const Duration(milliseconds: 300));
    recents = await repo.getRecentSearches();
    expect(recents.isEmpty, true, reason: 'Typing "pa" must NOT save to recent searches');

    // Type 'par'
    await tester.enterText(textFieldFinder, 'par');
    await tester.pump(const Duration(milliseconds: 300));
    recents = await repo.getRecentSearches();
    expect(recents.isEmpty, true, reason: 'Typing "par" must NOT save to recent searches');

    // Type 'Parivartana Ekadashi'
    await tester.enterText(textFieldFinder, 'Parivartana Ekadashi');
    await tester.pump(const Duration(milliseconds: 300));
    recents = await repo.getRecentSearches();
    expect(recents.isEmpty, true, reason: 'Typing without submitting must NOT save to recent searches');

    // Delete characters: 'Parivartana'
    await tester.enterText(textFieldFinder, 'Parivartana');
    await tester.pump(const Duration(milliseconds: 300));
    recents = await repo.getRecentSearches();
    expect(recents.isEmpty, true, reason: 'Deleting text must NOT save to recent searches');

    // Re-type 'Parivartana Ekadashi'
    await tester.enterText(textFieldFinder, 'Parivartana Ekadashi');
    await tester.pump(const Duration(milliseconds: 300));

    // NOW explicitly submit search via keyboard Enter/Search action
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // Verify: Exactly ONE recent search exists with the full submitted query
    recents = await repo.getRecentSearches();
    expect(recents.length, 1, reason: 'Only ONE recent search should be saved on explicit submit');
    expect(recents.first, 'Parivartana Ekadashi');
    expect(recents.contains('p'), false);
    expect(recents.contains('pa'), false);
    expect(recents.contains('par'), false);
    expect(recents.contains('Parivartana'), false);
  });

  testWidgets('Duplicate search moves entry to top without duplicating', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = RecentSearchRepository();
    await repo.addSearch('Nirjala Ekadashi');
    await repo.addSearch('Parivartana Ekadashi');

    await tester.pumpWidget(createSearchTestApp());
    await tester.pumpAndSettle();

    final textFieldFinder = find.byType(TextField);

    // Search for Nirjala Ekadashi again
    await tester.enterText(textFieldFinder, 'Nirjala Ekadashi');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final recents = await repo.getRecentSearches();
    expect(recents.length, 2);
    expect(recents.first, 'Nirjala Ekadashi');
    expect(recents[1], 'Parivartana Ekadashi');
  });

  testWidgets('Empty query does not create recent search entry', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = RecentSearchRepository();

    await tester.pumpWidget(createSearchTestApp());
    await tester.pumpAndSettle();

    final textFieldFinder = find.byType(TextField);

    // Submit empty string
    await tester.enterText(textFieldFinder, '   ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final recents = await repo.getRecentSearches();
    expect(recents.isEmpty, true);
  });
}
