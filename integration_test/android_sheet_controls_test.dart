import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/screens/premium_screen.dart';
import 'package:ekadashi_calendar/screens/global_search_screen.dart';
import 'package:ekadashi_calendar/screens/settings_screen.dart';
import 'package:ekadashi_calendar/widgets/app_icons.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android matching close controls and pull-down sheets in both Glass modes',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_launched', true);
      await prefs.setString('language_code', 'en');
      await prefs.setBool('is_dark_mode', true);
      await prefs.remove(ThemeService.glassLookKey);
      await tester.pumpWidget(const app.MyApp());
      Future<void> frames([int count = 8]) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      for (
        var i = 0;
        i < 240 &&
            find.byKey(const Key('home_page_indicator')).evaluate().isEmpty;
        i++
      ) {
        await frames(1);
      }
      expect(find.byKey(const Key('home_page_indicator')), findsOneWidget);
      final context = tester.element(find.byType(app.MainScreen));
      final theme = context.read<ThemeService>();
      await binding.convertFlutterSurfaceToImage();
      Future<void> snap(String name) async {
        await frames();
        await binding.takeScreenshot(name);
      }

      for (final enabled in [false, true]) {
        await theme.setGlassLook(enabled);
        await frames();
        await tester.tap(find.byKey(const Key('glass_tab_0')));
        await frames();
        await snap('home-controls-glass-$enabled');
        final homeButtons = [
          find.byKey(const Key('view_details')),
          find.byKey(const Key('home_share_card')),
          find.byKey(const Key('home_record_vrat')),
        ];
        final homeBounds = homeButtons.map(tester.getRect).toList();
        for (var i = 1; i < homeBounds.length; i++) {
          expect(homeBounds[i].size, const Size.square(48));
          expect(
            homeBounds[i].left - homeBounds[i - 1].right,
            greaterThanOrEqualTo(8),
          );
        }
        final press = await tester.startGesture(
          tester.getCenter(homeButtons.last),
        );
        await frames(1);
        expect(homeButtons.map(tester.getRect).toList(), homeBounds);
        await snap('home-controls-pressed-glass-$enabled');
        await press.up();
        await frames();
        expect(homeButtons.map(tester.getRect).toList(), homeBounds);
        expect(
          tester.getRect(find.byKey(const Key('app_toast'))).bottom,
          lessThanOrEqualTo(
            homeBounds.map((rect) => rect.top).reduce((a, b) => a < b ? a : b) -
                8,
          ),
        );
        await snap('home-controls-feedback-glass-$enabled');
        await tester.tap(find.byKey(const Key('home_location')));
        await frames();
        expect(
          find.byKey(const Key('city_picker_group_current')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('city_picker_group_search')),
          findsOneWidget,
        );
        await snap('city-picker-glass-$enabled');
        await tester.fling(find.text('Cancel'), const Offset(0, 650), 1200);
        await frames();
        await tester.tap(find.byKey(const Key('home_share_card')).first);
        await frames();
        expect(find.text('Cancel'), findsOneWidget);
        expect(
          tester.getCenter(find.byKey(const Key('share_card_save'))).dx,
          lessThan(
            tester.getCenter(find.byKey(const Key('share_card_share'))).dx,
          ),
        );
        await snap('share-sheet-glass-$enabled');
        await tester.fling(find.text('Cancel'), const Offset(0, 650), 1200);
        await frames();
        expect(find.text('Cancel'), findsNothing);
        for (final tab in [0, 1, 3, 4]) {
          await tester.tap(find.byKey(Key('glass_tab_$tab')));
          await frames();
          await snap('toolbar-tab-$tab-glass-$enabled');
          await tester.tap(find.byKey(const Key('open_global_search')));
          await frames();
          expect(find.byType(GlobalSearchScreen), findsOneWidget);
          await snap('search-tab-$tab-glass-$enabled');
          final list = find.byKey(const Key('search_start'));
          await tester.flingFrom(
            tester.getTopLeft(list) + const Offset(100, 25),
            const Offset(0, 650),
            1200,
          );
          await frames();
          expect(find.byType(GlobalSearchScreen), findsNothing);
        }
        await tester.tap(find.byKey(const Key('glass_tab_4')));
        await frames();
        final settingsScroll = find
            .descendant(
              of: find.byType(SettingsScreen),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byKey(const Key('settings_premium')),
          -250,
          scrollable: settingsScroll,
        );
        await tester.tap(find.byKey(const Key('settings_premium')));
        await frames();
        expect(find.byKey(const Key('premium_close')), findsOneWidget);
        await snap('premium-close-glass-$enabled');
        await tester.fling(
          find.byKey(const Key('premium_close')),
          const Offset(0, 650),
          1200,
        );
        await frames();
        expect(find.byType(PremiumScreen), findsNothing);
        final toggle = find.byKey(const Key('settings_glass_look'));
        await tester.scrollUntilVisible(
          toggle,
          180,
          scrollable: settingsScroll,
        );
        expect(
          find.descendant(
            of: toggle,
            matching: find.byIcon(AppIcons.glassLook),
          ),
          findsOneWidget,
        );
        await snap('settings-glass-icon-$enabled');
      }
      expect(tester.takeException(), isNull);
    },
  );
}
