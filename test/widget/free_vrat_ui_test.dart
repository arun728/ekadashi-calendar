import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/vrat_tracker_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final code in ['en', 'ta', 'hi', 'te']) {
    testWidgets('$code Vrat has all free tabs and no enable/disable controls', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'vrat_tracker_enabled': false});
      final language = LanguageService();
      await language.changeLanguage(code);
      final tracker = VratTrackerService();
      await tracker.init();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: language),
            ChangeNotifierProvider.value(value: tracker),
          ],
          child: const MaterialApp(
            home: VratTrackerScreen(ekadashiList: [], currentTimezone: 'IST'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(language.translate('enable_vrat_tracker')),
        findsNothing,
      );
      expect(
        find.text(language.translate('disable_vrat_tracker')),
        findsNothing,
      );
      for (final key in ['overview', 'history', 'statistics', 'achievements']) {
        expect(
          find.widgetWithText(Tab, language.translate(key)),
          findsOneWidget,
        );
      }
      expect(find.byIcon(Icons.power_settings_new), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
