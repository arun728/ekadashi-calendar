import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/wisdom_progress_store.dart';
import '../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'Ekadashi Calendar',
      packageName: 'com.applausestudios.ekadashi_calendar',
      version: '2.0.0',
      buildNumber: '5',
      buildSignature: '',
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WisdomProgressStore.instance.resetForTesting();
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    required AppHarness harness,
    String langCode = 'en',
    bool reminderEnabled = false,
  }) async {
    tester.view.physicalSize = const Size(393, 2300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() => harness.install(preferences: {
      'language_code': langCode,
      'wisdom_reminder_enabled': reminderEnabled,
    }));
    await WisdomProgressStore.instance.load();

    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    // Navigate to Settings tab (tab index 4)
    await tester.tap(find.byKey(const Key('glass_tab_4')));
    await tester.pumpAndSettle();
  }

  testWidgets('Daily Question reminder switch displays in SettingsScreen', (tester) async {
    final harness = AppHarness();
    addTearDown(harness.uninstall);

    await pumpSettings(tester, harness: harness, reminderEnabled: false);

    final switchFinder = find.byKey(const Key('settings_reminder_daily_question'));
    expect(switchFinder, findsOneWidget);

    final Switch switchWidget = tester.widget<Switch>(
      find.descendant(of: switchFinder, matching: find.byType(Switch)),
    );
    expect(switchWidget.value, isFalse);
  });

  testWidgets('Pre-persisted reminder enabled displays as switched on', (tester) async {
    final harness = AppHarness();
    addTearDown(harness.uninstall);

    await pumpSettings(tester, harness: harness, reminderEnabled: true);

    final switchFinder = find.byKey(const Key('settings_reminder_daily_question'));
    expect(switchFinder, findsOneWidget);

    final Switch switchWidget = tester.widget<Switch>(
      find.descendant(of: switchFinder, matching: find.byType(Switch)),
    );
    expect(switchWidget.value, isTrue);
  });

  testWidgets('Toggling switch updates WisdomProgressStore and persists setting', (tester) async {
    final harness = AppHarness();
    addTearDown(harness.uninstall);

    await pumpSettings(tester, harness: harness, reminderEnabled: false);

    final switchFinder = find.byKey(const Key('settings_reminder_daily_question'));
    expect(switchFinder, findsOneWidget);

    // Scroll if needed to make switch visible
    await tester.scrollUntilVisible(switchFinder, 100);
    await tester.pumpAndSettle();

    // Toggle on
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(WisdomProgressStore.instance.reminderEnabled, isTrue);

    // Toggle off
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(WisdomProgressStore.instance.reminderEnabled, isFalse);
  });

  testWidgets('Displays translated title in Hindi without English fallback', (tester) async {
    final harness = AppHarness();
    addTearDown(harness.uninstall);

    await pumpSettings(tester, harness: harness, langCode: 'hi');

    final switchFinder = find.byKey(const Key('settings_reminder_daily_question'));
    expect(switchFinder, findsOneWidget);

    await tester.scrollUntilVisible(switchFinder, 100);
    await tester.pumpAndSettle();

    expect(find.text('आज का प्रश्न अनुस्मारक'), findsOneWidget);
  });
}
