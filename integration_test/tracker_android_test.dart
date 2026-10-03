import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/achievement_unlock_dialog.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/record_vrat_dialog.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/vrat_tracker_screen.dart';

Future<void> pumpUi(WidgetTester tester, {int frames = 6}) async {
  // The Home screen can retain an indeterminate location indicator while a
  // software emulator has no geocoder network. Pump a bounded interval rather
  // than waiting for every ticker in the whole app to become idle.
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android tracker opt-in, tabs and first-record acceptance', (
    tester,
  ) async {
    // Dedicated emulator only. Reset just the test-owned app preferences.
    final prefs = await SharedPreferences.getInstance();
    for (final key
        in prefs
            .getKeys()
            .where((key) => key.startsWith('vrat_tracker_'))
            .toList()) {
      await prefs.remove(key);
    }
    await prefs.setBool('has_launched', true);
    await prefs.setString('language_code', 'en');
    app.main();
    await tester.pump();
    for (
      var frame = 0;
      frame < 120 && find.byIcon(Icons.spa_outlined).evaluate().isEmpty;
      frame++
    ) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byIcon(Icons.spa_outlined), findsOneWidget);
    debugPrint('Tracker UI: Home ready');
    await tester.tap(find.byIcon(Icons.spa_outlined));
    await pumpUi(tester);
    final screen = find.byType(VratTrackerScreen);
    final context = tester.element(screen);
    final tracker = context.read<VratTrackerService>();
    final lang = context.read<LanguageService>();
    expect(tracker.trackerEnabled, isFalse);
    await binding.convertFlutterSurfaceToImage();
    await pumpUi(tester);
    await binding.takeScreenshot('pr4_tracker_opt_in');
    await tester.tap(find.text(lang.translate('enable_vrat_tracker')));
    await pumpUi(tester);
    expect(tracker.trackerEnabled, isTrue);
    await binding.takeScreenshot('pr4_tracker_overview');
    for (final tab in ['history', 'statistics', 'achievements']) {
      await tester.tap(find.widgetWithText(Tab, lang.translate(tab)));
      await pumpUi(tester);
      await binding.takeScreenshot('pr4_tracker_$tab');
    }
    await tester.tap(find.widgetWithText(Tab, lang.translate('history')));
    await pumpUi(tester);
    final occurrences = tester.widget<VratTrackerScreen>(screen).ekadashiList;
    final today = DateTime.now();
    final past = occurrences.firstWhere((event) => event.date.isBefore(today));
    final row = find.text(past.name).hitTestable().first;
    await tester.ensureVisible(row);
    await pumpUi(tester);
    await tester.tap(row);
    await pumpUi(tester);
    expect(find.byType(RecordVratDialog), findsOneWidget);
    await binding.takeScreenshot('pr4_tracker_record');
    final save = find.widgetWithText(
      ElevatedButton,
      lang.translate('record_observance'),
    );
    await tester.ensureVisible(save);
    await pumpUi(tester);
    await tester.tap(save);
    await pumpUi(tester, frames: 12);
    expect(tracker.getRecord(past.id), isNotNull);
    await binding.takeScreenshot('pr4_tracker_after_save');
    // Release gate: save closes the sheet before one localized achievement UI.
    expect(
      find.byType(RecordVratDialog),
      findsNothing,
      reason: 'Save must close the sheet before showing a one-time achievement',
    );
    expect(find.byType(AchievementUnlockDialog), findsOneWidget);
    expect(find.text(lang.translate('achievement_unlocked')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
