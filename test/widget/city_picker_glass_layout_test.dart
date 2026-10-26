import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_location_store.dart';
import 'package:ekadashi_calendar/screens/widgets/city_picker_sheet.dart';
import 'package:ekadashi_calendar/widgets/app_icons.dart';
import 'package:ekadashi_calendar/widgets/glass_look.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    tz.initializeTimeZones();
    await PanchangLocationStore.cities();
  });
  for (final language in AppLanguage.codes) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'city groups $language dark=$dark scale=$scale for both tabs and modes',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            final lang = LanguageService();
            await lang.changeLanguage(language);
            tester.view.physicalSize = Size(scale == 1 ? 393 : 320, 852);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            for (final manual in [false, true]) {
              Rect? original;
              for (final enabled in [false, true]) {
                await tester.pumpWidget(
                  ChangeNotifierProvider.value(
                    value: lang,
                    child: MaterialApp(
                      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                      home: GlassLook(
                        enabled: enabled,
                        child: Scaffold(
                          body: CityPickerSheet(
                            key: ValueKey('$enabled-$manual'),
                            title: 'Test',
                            footer: '',
                            current: PanchangCity.chennai,
                            icon: AppIcons.locationPicked,
                            onPick: (_) async {},
                            onLocate: () async => 'panchang_location_denied',
                            extra: manual
                                ? ManualCoordinatesSection(
                                    city: PanchangCity.chennai,
                                    onSave: (_) async {},
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                final group = find.byKey(
                  const Key('city_picker_group_current'),
                );
                expect(group, findsOneWidget);
                final rect = tester.getRect(group);
                expect(rect.left, greaterThanOrEqualTo(16));
                expect(rect.right, lessThanOrEqualTo(scale == 1 ? 377 : 304));
                if (original != null) expect(rect, original);
                original = rect;
                expect(
                  find.byKey(const Key('city_picker_group_search')),
                  findsOneWidget,
                );
                expect(
                  find.byKey(const Key('city_picker_group_popular')),
                  findsOneWidget,
                );
                expect(tester.takeException(), isNull);
                if (!enabled && !manual) {
                  final locate = find.byKey(
                    const Key('ekadashi_location_current_button'),
                  );
                  await tester.ensureVisible(locate);
                  await tester.tap(locate);
                  await tester.pumpAndSettle();
                  expect(
                    find.text(
                      AppStrings.translate(
                        'panchang_location_denied',
                        language,
                      ),
                    ),
                    findsOneWidget,
                  );
                  expect(tester.takeException(), isNull);
                }
              }
            }
          },
        );
      }
    }
  }
}
