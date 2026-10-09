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
import 'package:ekadashi_calendar/screens/premium_screen.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';

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
  testWidgets('Android free tracker, tabs and first-record acceptance', (
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
    expect(tracker.trackerEnabled, isTrue);
    expect(find.text(lang.translate('enable_vrat_tracker')), findsNothing);
    expect(find.text(lang.translate('disable_vrat_tracker')), findsNothing);
    await binding.convertFlutterSurfaceToImage();
    await pumpUi(tester);
    await binding.takeScreenshot('free_vrat_initial');
    await binding.takeScreenshot('pr4_tracker_overview');
    for (final tab in ['history', 'statistics', 'achievements']) {
      // A narrow screen scrolls the chip row to the later sections.
      await tester.ensureVisible(find.byKey(Key('journey_tab_$tab')));
      await pumpUi(tester);
      await tester.tap(find.byKey(Key('journey_tab_$tab')));
      await pumpUi(tester);
      await binding.takeScreenshot('pr4_tracker_$tab');
    }
    await tester.ensureVisible(find.byKey(const Key('journey_tab_history')));
    await pumpUi(tester);
    await tester.tap(find.byKey(const Key('journey_tab_history')));
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
    Navigator.of(tester.element(find.byType(AchievementUnlockDialog))).pop();
    await pumpUi(tester);

    // Free tier: three Vrat entries; the fourth new entry opens the paywall.
    final pastEvents = occurrences
        .where((event) => event.date.isBefore(today) && event.id != past.id)
        .toList();
    for (final event in pastEvents.take(2)) {
      await tracker.recordVrat(
        ekadashiOccurrenceId: event.id,
        occurrenceUid: event.occurrenceUid,
        ekadashiDate: event.date.toIso8601String().substring(0, 10),
        ekadashiName: event.name,
        status: ObservanceStatus.observed,
      );
    }
    expect(tracker.recordedEntryCount, VratTrackerService.freeEntryLimit);
    final fourth = pastEvents[2];
    if (!context.mounted) return;
    RecordVratDialog.show(
      context,
      ekadashi: fourth,
      allOccurrences: occurrences,
      currentTimezone: 'IST',
    );
    await pumpUi(tester);
    final saveFourth = find.widgetWithText(
      ElevatedButton,
      lang.translate('record_observance'),
    );
    await tester.ensureVisible(saveFourth);
    await pumpUi(tester);
    await tester.tap(saveFourth);
    await pumpUi(tester, frames: 12);
    expect(find.byType(PremiumScreen), findsOneWidget);
    await binding.takeScreenshot('free_vrat_limit_paywall');
    await tester.tap(find.byKey(const Key('premium_close')));
    await pumpUi(tester);
    expect(tracker.getRecordByUid(fourth.occurrenceUid), isNull);
    expect(
      find.text(lang.translate('vrat_free_limit_reached')),
      findsOneWidget,
    );
    await binding.takeScreenshot('free_vrat_limit_message');
    debugPrint('Tracker UI: fourth free entry gated by premium');
    expect(tester.takeException(), isNull);
  });
}
