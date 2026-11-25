import 'package:ekadashi_calendar/widgets/app_icons.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ekadashi_calendar/widgets/settings_group.dart';
import '../support/app_harness.dart';

/// Android Settings follows the iOS SettingsView element by element: grouped
/// sections with headers outside the cards, icon rows, iOS switches, and
/// the Version row inside About. Full-page PNGs go to
/// build/ui-screenshots/offscreen/settings_full_<locale>_<theme>.png.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final cupertino = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await cupertino.load();
    for (final entry in {
      'Roboto': ['EkadashiTestFont.ttf'],
      'MaterialIcons': ['MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(
          File(
            'test/fonts/$file',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      }
      await loader.load();
    }
  });

  for (final locale in ['en', 'hi']) {
    for (final dark in [true, false]) {
      final theme = dark ? 'dark' : 'light';
      testWidgets('$locale $theme Settings matches the iOS layout', (
        tester,
      ) async {
        // The build's version, as the Play Store build reports it.
        PackageInfo.setMockInitialValues(
          appName: 'Ekadashi Calendar',
          packageName: 'com.applausestudios.ekadashi_calendar',
          version: '2.0.0',
          buildNumber: '5',
          buildSignature: '',
        );
        final harness = AppHarness();
        await tester.runAsync(
          () => harness.install(
            preferences: {'language_code': locale, 'is_dark_mode': dark},
          ),
        );
        addTearDown(harness.uninstall);
        // Tall enough for the whole page, as on the device scrolled top to bottom.
        tester.view.physicalSize = const Size(393, 2300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(key: key, child: harness.app()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('glass_tab_4')));
        await tester.pumpAndSettle();
        final lang = Provider.of<LanguageService>(
          tester.element(find.byType(MaterialApp)),
          listen: false,
        );

        Future<void> capture(String name) => tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final directory = Directory('build/ui-screenshots/offscreen');
          await directory.create(recursive: true);
          await File(
            '${directory.path}/settings_${name}_${locale}_$theme.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
        await capture('full');

        // Settings redesign (25 Nov 2026): the Premium card, a Notifications
        // row, then Appearance, Google Calendar and About & legal, in the iOS
        // order. Reminder controls live on the Notifications page.
        Future<void> checkHeaders(
          List<String> headers,
          Map<String, String> tubes,
        ) async {
          double? previous;
          for (final name in headers) {
            final header = find.byKey(Key('settings_header_$name'));
            expect(header, findsOneWidget, reason: name);
            expect(
              find.descendant(
                of: header,
                matching: find.text(lang.translate(name)),
              ),
              findsOneWidget,
            );
            final top = tester.getTopLeft(header).dy;
            if (previous != null) {
              expect(top, greaterThan(previous), reason: name);
            }
            previous = top;
            final tube = find.byKey(Key(tubes[name]!));
            expect(tester.getTopLeft(tube).dy, greaterThan(top), reason: name);
          }
        }

        final notificationsRow = find.byKey(
          const Key('settings_notifications'),
        );
        expect(notificationsRow, findsOneWidget);
        expect(
          tester.getTopLeft(notificationsRow).dy,
          greaterThan(
            tester.getTopLeft(find.byKey(const Key('settings_premium'))).dy,
          ),
        );
        await checkHeaders(
          ['appearance', 'google_calendar', 'settings_about_legal'],
          {
            'appearance': 'settings_appearance_tube',
            'google_calendar': 'settings_google_tube',
            'settings_about_legal': 'settings_about_tube',
          },
        );
        expect(
          tester.getTopLeft(notificationsRow).dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const Key('settings_header_appearance')))
                .dy,
          ),
        );
        for (final gone in [
          'notifications',
          'permissions',
          'journey_tab',
          'about',
        ]) {
          expect(
            find.byKey(Key('settings_header_$gone')),
            findsNothing,
            reason: gone,
          );
        }
        expect(find.byKey(const Key('notifications_add_event')), findsNothing);
        // No Material dividers between sections (iOS has none).
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Divider),
          ),
          findsNothing,
        );

        // Appearance: Widget Preview with a teal grid icon and a chevron,
        // then Dark Mode with a moon icon and an iOS switch.
        final appearance = find.byKey(const Key('settings_appearance_tube'));
        Finder inTube(Finder tube, Finder matching) =>
            find.descendant(of: tube, matching: matching);
        expect(
          inTube(appearance, find.byIcon(AppIcons.widgetPreview)),
          findsOneWidget,
        );
        expect(
          inTube(appearance, find.byIcon(AppIcons.rowDisclosure)),
          findsOneWidget,
        );
        expect(
          inTube(appearance, find.byIcon(AppIcons.darkMode)),
          findsOneWidget,
        );
        expect(
          tester
              .getTopLeft(
                inTube(appearance, find.text(lang.translate('widget_preview'))),
              )
              .dy,
          lessThan(
            tester
                .getTopLeft(
                  inTube(appearance, find.text(lang.translate('dark_mode'))),
                )
                .dy,
          ),
        );
        expect(
          inTube(appearance, find.byKey(const Key('journey_badge_haptics'))),
          findsOneWidget,
          reason: 'badge haptics moved from the old Journey section',
        );
        // Google Calendar: Import and Disconnect.
        final google = find.byKey(const Key('settings_google_tube'));
        for (final key in [
          'settings_google_import',
          'settings_google_disconnect',
        ]) {
          expect(
            inTube(google, find.byKey(Key(key))),
            findsOneWidget,
            reason: key,
          );
        }
        // Every switch is drawn as the iOS switch (adaptive, iOS platform).
        final switches = find.byType(Switch);
        expect(switches, findsWidgets);
        for (final element in switches.evaluate()) {
          expect(Theme.of(element).platform, TargetPlatform.iOS);
        }

        // About: Rate, Share and the Version row inside the same card.
        final about = find.byKey(const Key('settings_about_tube'));
        expect(
          inTube(about, find.text(lang.translate('version'))),
          findsOneWidget,
        );
        expect(inTube(about, find.byIcon(AppIcons.share)), findsOneWidget);
        expect(inTube(about, find.text('2.0.0')), findsOneWidget);
        expect(inTube(about, find.text('1.1.1')), findsNothing);
        for (final key in [
          'settings_terms',
          'settings_privacy',
          'settings_contact_support',
        ]) {
          expect(
            inTube(about, find.byKey(Key(key))),
            findsOneWidget,
            reason: key,
          );
        }

        // Premium: white label on a capsule button.
        final cta = tester.widget<FilledButton>(
          find.byKey(const Key('settings_premium')),
        );
        expect(cta.style?.shape?.resolve({}), isA<StadiumBorder>());
        expect(cta.style?.foregroundColor?.resolve({}), Colors.white);

        // The Notifications page: the master switch, Ekadashi, Festivals and
        // events, then "Reminders not arriving?".
        await tester.ensureVisible(notificationsRow);
        await tester.tap(notificationsRow);
        await tester.pumpAndSettle();
        await checkHeaders(
          [
            'notifications',
            'notifications_section_ekadashi',
            'notifications_section_events',
            'settings_reminders_not_arriving',
          ],
          {
            'notifications': 'settings_notifications_tube',
            'notifications_section_ekadashi':
                'settings_notifications_ekadashi_tube',
            'notifications_section_events':
                'settings_notifications_events_tube',
            'settings_reminders_not_arriving':
                'settings_permission_actions_tube',
          },
        );
        await capture('notifications');
        // Ekadashi statuses are grey details, as on iOS (not green).
        final status = tester.widget<Text>(
          inTube(
            find.byKey(const Key('settings_notifications_ekadashi_tube')),
            find.text(lang.translate('status_active')),
          ).first,
        );
        expect(status.style?.color, isNot(Colors.green));

        // Permissions: App Settings and Permissions Guide rows.
        final permissions = find.byKey(
          const Key('settings_permission_actions_tube'),
        );
        expect(
          inTube(permissions, find.text(lang.translate('app_settings'))),
          findsOneWidget,
        );
        expect(
          inTube(permissions, find.text(lang.translate('app_settings_desc'))),
          findsOneWidget,
        );
        expect(
          inTube(permissions, find.text(lang.translate('perm_guide_title'))),
          findsOneWidget,
        );

        // A test notification answers with the iOS toast, not a SnackBar.
        final test = find.text(lang.translate('test_notification'));
        await tester.ensureVisible(test);
        await tester.pumpAndSettle();
        await tester.tap(test);
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const Key('app_toast')),
            matching: find.text(lang.translate('notif_sent_msg')),
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // The reminder editor: an iOS sheet with Cancel and Save in its
        // bar, grouped cards.
        await tester.tap(find.byKey(const Key('notifications_add_event')));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SheetBar),
            matching: find.text(lang.translate('cancel')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(SettingsCard),
          ),
          findsNWidgets(3),
        );
        await capture('reminder_editor');
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Contact support emails Apptinel; Google actions open Calendar', (
    tester,
  ) async {
    final opened = <String>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    const androidChannel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.url_launcher_android.UrlLauncherApi.launchUrl',
      StandardMessageCodec(),
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      opened.add((call.arguments as Map)['url'] as String);
      return true;
    });
    messenger.setMockDecodedMessageHandler(androidChannel, (message) async {
      opened.add((message! as List<Object?>).first! as String);
      return [true];
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockDecodedMessageHandler(androidChannel, null);
    });
    final harness = AppHarness();
    await tester.runAsync(() => harness.install());
    addTearDown(harness.uninstall);
    tester.view.physicalSize = const Size(393, 2300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('glass_tab_4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_contact_support')));
    await tester.pumpAndSettle();
    expect(opened, ['mailto:contact@apptinel.com']);

    // The Calendar tab opens and runs its own Disconnect (its spinner keeps
    // turning here: the Google sign-in plugin does not answer in tests).
    await tester.tap(find.byKey(const Key('settings_google_disconnect')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('settings_google_tube')), findsNothing);
    expect(find.byKey(const Key('calendar_month_tube')), findsOneWidget);
  });
}
