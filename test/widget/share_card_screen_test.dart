import 'dart:io';

import 'package:ekadashi_calendar/screens/share_card_screen.dart';
import 'package:ekadashi_calendar/screens/widgets/ekadashi_share_card.dart';
import 'package:ekadashi_calendar/services/app_links.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_settings.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The free share card (PR #20's design, ShareCardSheet.swift on iOS):
/// the same texts as iOS, no location, the Play Store link only, and Save
/// to Gallery with its outcomes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const gal = MethodChannel('gal');
  const share = MethodChannel('dev.fluttercommunity.plus/share');
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;

  setUpAll(() async {
    await initializeDateFormatting();
    temp = await Directory.systemTemp.createTemp('share_card_test');
  });
  tearDownAll(() => temp.delete(recursive: true));
  tearDown(() {
    for (final channel in [gal, share, paths]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  final event = EkadashiDate(
    id: 20,
    occurrenceUid: 'ekadashi:2026:20',
    contentId: 'papankusha-ekadashi',
    name: 'Papankusha Ekadashi',
    date: DateTime(2026, 10, 22),
    fastStartTime: '06:00 AM',
    fastBreakTime: 'Oct 23, 06:00 AM - 08:21 AM',
    description: 'The hook that pulls sins out.',
    paksha: 'Shukla',
    month: 'Ashwin',
  );

  test('the long date reads the same as on iOS in every language', () {
    // Apple's DateFormatter ("yMMMMEEEEd") on the same ICU data.
    const ios = {
      'en': 'Thursday, October 22, 2026',
      'hi': 'गुरुवार, 22 अक्तूबर 2026',
      'ta': 'வியாழன், 22 அக்டோபர், 2026',
      'te': '22, అక్టోబర్ 2026, గురువారం',
      'gu': 'ગુરુવાર, 22 ઑક્ટોબર, 2026',
      'bn': 'বৃহস্পতিবার, ২২ অক্টোবর, ২০২৬',
    };
    ios.forEach((code, text) {
      expect(ShareCardContent.longDate(DateTime(2026, 10, 22), code), text);
    });
  });

  test('the card texts are those of the iOS card', () {
    final content = ShareCardContent.of(
      event,
      language: 'en',
      tradition: 'Vaishnava',
    );
    expect(content.observance, 'Ekadashi observance');
    expect(content.tradition, 'Vaishnava');
    expect(content.pakshaMonth, 'SHUKLA • ASHWIN');
    expect(content.date, 'Thursday, October 22, 2026');
    expect(content.fastingTime, '06:00 AM');
    // The Parana window without the leading "Oct 23, ".
    expect(content.paranaTime, '06:00 AM - 08:21 AM');
    expect(content.significance, 'The hook that pulls sins out.');
    expect(content.branding, 'Ekadashi Calendar');
  });

  test('Android shares only its Play Store link', () {
    final text = AppLinks.shareCardMessage('Message');
    expect(text, 'Message\n\n${AppLinks.playStore}');
    expect(text, isNot(contains('apps.apple.com')));
  });

  Future<void> showCard(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    tester.view.physicalSize = const Size(393, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageService()),
          ChangeNotifierProvider(create: (_) => EkadashiSettings()),
        ],
        child: MaterialApp(home: ShareCardScreen(event: event)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps [key] with the real clock: the card is drawn to an image and
  /// written to disk, which the fake clock never finishes.
  Future<void> tapReal(WidgetTester tester, String key) async {
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Key(key)));
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('the preview shows the card without any location', (
    tester,
  ) async {
    await showCard(tester);
    final card = find.byKey(const Key('share_card_preview'));
    expect(card, findsOneWidget);
    for (final text in [
      'Papankusha Ekadashi',
      'SMARTA',
      'Thursday, October 22, 2026',
      'FASTING BEGINS',
      'PARANA WINDOW',
    ]) {
      expect(
        find.descendant(of: card, matching: find.text(text)),
        findsOneWidget,
        reason: text,
      );
    }
    // Home's city (Chennai by default) is never on the card.
    expect(
      find.descendant(of: card, matching: find.textContaining('Chennai')),
      findsNothing,
    );
    expect(find.byKey(const Key('share_card_share')), findsOneWidget);
    expect(find.byKey(const Key('share_card_save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Save to Gallery saves the card as a PNG', (tester) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(gal, (call) async {
      calls.add(call);
      return call.method == 'hasAccess' ? true : null;
    });
    await showCard(tester);
    await tapReal(tester, 'share_card_save');
    final put = calls.singleWhere((c) => c.method == 'putImageBytes');
    final args = put.arguments as Map;
    expect(args['album'], 'Ekadashi Calendar');
    expect(args['name'], 'ekadashi_ekadashi_2026_20');
    final bytes = args['bytes'] as Uint8List;
    expect(bytes.sublist(1, 4), 'PNG'.codeUnits);
    expect(find.text('Card saved to Gallery.'), findsOneWidget);
  });

  testWidgets('a refused gallery permission says how to allow it', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(gal, (call) async {
      if (call.method == 'hasAccess') return false;
      if (call.method == 'requestAccess') return false;
      throw PlatformException(code: 'ACCESS_DENIED');
    });
    await showCard(tester);
    await tapReal(tester, 'share_card_save');
    expect(
      find.text('Photo access is off. Allow it in Settings to save cards.'),
      findsOneWidget,
    );
  });

  testWidgets('Share sends the image with the message and Play link', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(paths, (_) async => temp.path);
    messenger.setMockMethodCallHandler(share, (call) async {
      calls.add(call);
      return null;
    });
    await showCard(tester);
    await tapReal(tester, 'share_card_share');
    final sent = calls.singleWhere((c) => c.method == 'shareFilesWithResult');
    final args = sent.arguments as Map;
    expect((args['paths'] as List).single, endsWith('.png'));
    expect(
      args['text'],
      'Papankusha Ekadashi is on Thu, 22 Oct 2026. Fasting and Parana times '
      'from the Ekadashi Calendar app are on this card.\n\n'
      '${AppLinks.playStore}',
    );
  });
}
