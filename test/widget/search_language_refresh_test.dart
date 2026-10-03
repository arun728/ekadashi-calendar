import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/models/search_content_type.dart';
import 'package:ekadashi_calendar/screens/global_search_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/search_index_manager.dart';
import '../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;
  late LanguageService language;
  late List<EkadashiDate> telugu;
  setUp(() async {
    harness = AppHarness();
    await harness.install(preferences: {'language_code': 'te'});
    language = LanguageService();
    await language.changeLanguage('te');
    telugu = EkadashiService().getEkadashis(
      timezone: 'IST',
      languageCode: 'te',
    );
  });
  tearDown(() => harness.uninstall());
  testWidgets(
    'Explicit content language survives refreshed app calendar data',
    (tester) async {
      Widget screen(List<EkadashiDate> data) => ChangeNotifierProvider.value(
        value: language,
        child: MaterialApp(
          home: GlobalSearchScreen(
            ekadashiList: data,
            currentTimezone: 'IST',
            showBackButton: false,
          ),
        ),
      );
      await tester.pumpWidget(screen(telugu));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('search_language_selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nirjla');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        SearchIndexManager().search(
          'nirjla',
          languageCode: 'en',
          contentType: SearchContentType.ekadashi,
        ),
        isNotEmpty,
      );
      await tester.pumpWidget(screen(List.of(telugu)));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const Key('search_language_selector')),
            )
            .value,
        'en',
      );
      expect(
        SearchIndexManager().search(
          'nirjla',
          languageCode: 'en',
          contentType: SearchContentType.ekadashi,
        ),
        isNotEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
