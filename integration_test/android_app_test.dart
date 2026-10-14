import 'package:ekadashi_calendar/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/native_settings_service.dart';
import 'package:ekadashi_calendar/services/native_location_service.dart';
import 'package:ekadashi_calendar/services/native_notification_service.dart';

Future<void> pumpUi(WidgetTester tester, {int frames = 6}) async {
  // Keep the test moving when a platform activity leaves a progress indicator
  // animating in a background tab.
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> waitForUi(
  WidgetTester tester,
  bool Function() ready, {
  required String reason,
}) async {
  for (var attempt = 0; attempt < 50 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(ready(), isTrue, reason: reason);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real Android startup, settings, localization and navigation', (
    tester,
  ) async {
    // Only run on a dedicated test emulator/device: changes app preferences.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_launched', true);
    await prefs.setString('language_code', 'en');
    await prefs.setBool('is_dark_mode', true);
    final native = NativeSettingsService();
    final permissions = await native.checkAllPermissions();
    expect(permissions.androidVersion, greaterThanOrEqualTo(24));
    const mode = String.fromEnvironment(
      'TEST_PERMISSION_MODE',
      defaultValue: 'granted',
    );
    expect(permissions.hasLocationPermission, mode != 'denied');
    if (mode == 'denied' && permissions.androidVersion >= 33) {
      expect(permissions.hasNotificationPermission, isFalse);
    }
    if (mode == 'gps-off') {
      expect(await NativeLocationService().isLocationEnabled(), isFalse);
    }
    // Reset test-owned native preferences too, so repeated runs are independent.
    await native.updateNotificationSettings(NotificationPrefs.defaults());
    await NativeNotificationService().updateSettings(NotificationSettings());
    await NativeNotificationService().cancelAllNotifications();
    app.main();
    await tester.pump();
    // Location service has its own timeout; poll for a usable Home surface.
    for (
      var attempt = 0;
      attempt < 60 && find.byIcon(AppIcons.tabHome).evaluate().isEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byIcon(AppIcons.tabHome), findsOneWidget);
    for (
      var attempt = 0;
      attempt < 45 &&
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Without a location Home still names its city (the last known one,
    // else Chennai); "Use current location" lives in the city picker.
    expect(find.byKey(const Key('home_location_name')), findsOneWidget);
    if (mode == 'denied') expect(find.text('Location Denied'), findsNothing);
    await binding.convertFlutterSurfaceToImage();
    await pumpUi(tester);
    await binding.takeScreenshot('android_home');
    await tester.drag(
      find.byType(SingleChildScrollView).hitTestable().first,
      const Offset(0, -260),
    );
    await pumpUi(tester);
    await binding.takeScreenshot('android_home_parana');
    await tester.drag(
      find.byType(SingleChildScrollView).hitTestable().first,
      const Offset(0, 260),
    );
    await pumpUi(tester);
    await tester.tap(find.byKey(const Key('glass_tab_1')));
    await pumpUi(tester);
    final emptyDay = find.text('No Ekadashi on this day');
    if (emptyDay.evaluate().isNotEmpty &&
        find.byKey(const Key('glass_capsule_surface')).evaluate().isNotEmpty) {
      expect(
        tester.getRect(emptyDay).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const Key('glass_capsule_surface'))).top -
              8,
        ),
      );
    }
    await binding.takeScreenshot('android_calendar');
    await tester.tap(find.byIcon(AppIcons.tabSettings));
    await pumpUi(tester);
    expect(find.text('Appearance'), findsOneWidget);
    final themeSwitch = find.byType(SwitchListTile).first;
    final original = tester.widget<SwitchListTile>(themeSwitch).value;
    // Below the Premium card on short screens.
    await tester.ensureVisible(themeSwitch);
    await pumpUi(tester);
    await tester.tap(themeSwitch);
    await pumpUi(tester);
    expect(tester.widget<SwitchListTile>(themeSwitch).value, !original);
    expect(await native.isDarkMode(), !original);
    await binding.takeScreenshot('android_settings_theme');
    // The Android-only guide/settings pair stays operable after the glass layout.
    final settingsScroll = find
        .descendant(
          of: find.byType(ListView).hitTestable(),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_permission_actions_tube')),
      180,
      scrollable: settingsScroll,
    );
    await pumpUi(tester);
    for (final key in [
      'permission_guide_action',
      'permission_settings_action',
    ]) {
      expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
      expect(
        tester.getSize(find.byKey(Key(key))).shortestSide,
        greaterThanOrEqualTo(48),
      );
    }
    await binding.takeScreenshot('android_settings_actions');
    await tester.tap(find.byKey(const Key('permission_guide_action')));
    await pumpUi(tester);
    // The guide's row and the dialog share the title; check the dialog.
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(
          Provider.of<LanguageService>(
            tester.element(find.byType(MaterialApp)),
            listen: false,
          ).translate('perm_guide_title'),
        ),
      ),
      findsOneWidget,
    );
    await binding.takeScreenshot('android_permissions_guide');
    await tester.binding.handlePopRoute();
    await pumpUi(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_about_tube')),
      180,
      scrollable: settingsScroll,
    );
    await pumpUi(tester);
    await binding.takeScreenshot('android_settings_about');
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_appearance_tube')),
      -180,
      scrollable: settingsScroll,
    );
    await pumpUi(tester);
    // Master disable must cancel real WorkManager reminders.
    if (permissions.hasNotificationPermission) {
      final master = find.widgetWithText(
        SwitchListTile,
        'Enable Notifications',
      );
      if (tester.widget<SwitchListTile>(master).value) {
        await tester.tap(master);
        await pumpUi(tester);
      }
      expect((await native.getNotificationSettings()).enabled, isFalse);
      expect(
        await NativeNotificationService().getPendingNotificationCount(),
        0,
      );
    }
    final language = Provider.of<LanguageService>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    Future<void> selectTab(int index) async {
      final tab = find.byKey(Key('glass_tab_$index'));
      await waitForUi(
        tester,
        () => tab.hitTestable().evaluate().length == 1,
        reason: 'Tab $index must be ready to receive a tap',
      );
      await tester.tap(tab.hitTestable());
      await waitForUi(
        tester,
        () => tester.widget<Semantics>(tab).properties.selected == true,
        reason: 'Tab $index must become selected before checking its page',
      );
    }

    for (final locale in ['ta', 'hi', 'en']) {
      await selectTab(0);
      final headerPosition = tester.getTopLeft(
        find.byKey(const Key('home_options_tube')),
      );
      await tester.tap(find.byKey(const Key('language_menu')));
      const names = {'en': 'English', 'ta': 'தமிழ்', 'hi': 'हिंदी'};
      final choice = find.widgetWithText(PopupMenuItem<String>, names[locale]!);
      await waitForUi(
        tester,
        () => choice.hitTestable().evaluate().length == 1,
        reason: 'The $locale language menu item must be ready',
      );
      expect(find.byKey(const Key('open_global_search')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('home_options_tube'))),
        headerPosition,
      );
      await tester.tap(choice.hitTestable());
      // A selected locale alone does not mean the popup has finished closing.
      // Wait for the menu and reload before tapping the navigation beneath it.
      await waitForUi(
        tester,
        () =>
            language.currentLocale.languageCode == locale &&
            find.byType(PopupMenuItem<String>).evaluate().isEmpty &&
            find
                .byType(CircularProgressIndicator)
                .hitTestable()
                .evaluate()
                .isEmpty,
        reason: 'The $locale language change and popup dismissal must finish',
      );
      expect(language.currentLocale.languageCode, locale);
      await binding.takeScreenshot('android_home_$locale');
      await selectTab(4);
      final settingsList = find.byType(ListView).hitTestable();
      await waitForUi(
        tester,
        () => settingsList.evaluate().length == 1,
        reason: 'Settings must finish loading in $locale',
      );
      final scrollable = find
          .descendant(of: settingsList, matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.minScrollExtent);
      await tester.pump();
      final appearance = find.text(language.translate('appearance'));
      await tester.scrollUntilVisible(appearance, 180, scrollable: scrollable);
      expect(appearance.hitTestable(), findsOneWidget);
      await binding.takeScreenshot('android_settings_$locale');
    }
    for (final tab in [2, 3]) {
      await selectTab(tab);
      if (tab == 2) {
        await tester.tap(find.byKey(const Key('journey_tab_history')));
        await pumpUi(tester);
      }
      final anchor = find.byKey(
        Key(tab == 2 ? 'vrat_tabs_tube' : 'panchang_sections_tube'),
      );
      final anchorPosition = tester.getTopLeft(anchor);
      await tester.tap(
        find.byKey(
          Key(
            tab == 2 ? 'journey_history_year_menu' : 'panchang_city_selector',
          ),
        ),
      );
      final menuItems = find.byWidgetPredicate(
        (widget) => widget is PopupMenuItem,
      );
      await waitForUi(
        tester,
        () => menuItems.evaluate().isNotEmpty,
        reason: 'Tab $tab menu must open',
      );
      expect(find.byKey(const Key('open_global_search')), findsOneWidget);
      expect(tester.getTopLeft(anchor), anchorPosition);
      await tester.binding.handlePopRoute();
      await waitForUi(
        tester,
        () => menuItems.evaluate().isEmpty,
        reason: 'System Back must close tab $tab menu',
      );
      expect(tester.getTopLeft(anchor), anchorPosition);
    }
    await selectTab(0);
    final details = find.byKey(const Key('view_details'));
    await tester.ensureVisible(details);
    await tester.tap(details);
    await pumpUi(tester);
    expect(find.text('Significance'), findsOneWidget);
    await binding.takeScreenshot('android_details');
    await tester.pageBack();
    await pumpUi(tester);
    expect(find.byIcon(AppIcons.tabHome), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (permissions.hasNotificationPermission) {
      expect(
        await NativeNotificationService().getPendingNotificationCount(),
        0,
        reason: 'Changing language must not recreate disabled reminders',
      );
    }
  });
}
