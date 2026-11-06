import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/wisdom_question_card.dart';
import 'package:ekadashi_calendar/services/wisdom_progress_store.dart';
import '../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;

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
    harness = AppHarness();
    await harness.install(preferences: {'vrat_tracker_enabled': true});
  });

  tearDown(() => harness.uninstall());

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
  }

  testWidgets('Home screen displays compact Today\'s Wisdom teaser card and tapping it opens Wisdom subtab in Journey', (tester) async {
    await pumpHome(tester);

    // Verify home teaser is present on Home screen
    final teaserFinder = find.byKey(const Key('home_wisdom_teaser'));
    expect(teaserFinder, findsOneWidget);

    // Scroll until visible and tap
    await tester.ensureVisible(teaserFinder);
    await tester.pumpAndSettle();
    await tester.tap(teaserFinder);
    await tester.pumpAndSettle();

    // Should have navigated to Journey tab and rendered WisdomQuestionCard
    expect(find.byType(WisdomQuestionCard), findsOneWidget);
  });
}
