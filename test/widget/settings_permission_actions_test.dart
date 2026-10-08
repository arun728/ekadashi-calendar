import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/l10n/generated/app_localizations.dart';
import 'package:ekadashi_calendar/screens/widgets/settings_permission_actions.dart';

void main() {
  for (final code in ['en', 'ta', 'hi', 'te', 'gu', 'bn']) {
    testWidgets(
      '$code Android permission actions fit and remain accessible at 2x',
      (tester) async {
        var guide = 0, settings = 0;
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(code),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(brightness: Brightness.dark),
            home: Builder(
              builder: (context) {
                final strings = AppLocalizations.of(context);
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SettingsPermissionActions(
                        title: strings.app_settings,
                        guideTooltip: strings.perm_guide_title,
                        settingsTooltip: strings.settings_button,
                        onGuide: () => guide++,
                        onSettings: () => settings++,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final key in [
          'permission_guide_action',
          'permission_settings_action',
        ]) {
          final finder = find.byKey(Key(key));
          expect(tester.getSize(finder).shortestSide, greaterThanOrEqualTo(48));
          await tester.tap(finder);
        }
        expect(guide, 1);
        expect(settings, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
