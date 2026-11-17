import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/widgets/play_update_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.ekadashi.app_update');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> calls;
  late Map<String, Object>? offer;
  late bool accepts;

  setUp(() {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    calls = [];
    offer = {'state': 'available', 'versionCode': 7};
    accepts = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'check' => offer,
        'start' => accepts,
        'complete' => true,
        _ => throw MissingPluginException(),
      };
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageService(),
        child: const MaterialApp(
          home: Scaffold(
            body: PlayUpdateNotice(child: Text('Calendar content')),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> notify(WidgetTester tester, String state) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('state', {'state': state, 'versionCode': 7}),
      ),
      (_) {},
    );
    await tester.pump();
  }

  testWidgets(
    'a flexible download keeps the app usable and completes only on tap',
    (tester) async {
      await launch(tester);
      expect(find.text('Update available'), findsOneWidget);
      await tester.tap(find.text('Update'));
      await tester.pump();
      expect(calls, ['check', 'start']);
      expect(find.text('Downloading update…'), findsOneWidget);
      expect(find.text('Calendar content'), findsOneWidget);
      await notify(tester, 'downloaded');
      expect(find.text('Restart to update'), findsOneWidget);
      expect(calls, isNot(contains('complete')));
      await tester.tap(find.text('Restart to update'));
      await tester.pump();
      expect(calls.last, 'complete');
    },
  );

  testWidgets(
    'a downloaded update is recovered even if a prior process handled the download',
    (tester) async {
      offer = {'state': 'downloaded', 'versionCode': 7};
      await launch(tester);
      expect(find.text('Restart to update'), findsOneWidget);
    },
  );

  testWidgets(
    'cancel, a failed download and an unavailable update leave the app usable',
    (tester) async {
      accepts = false;
      await launch(tester);
      await tester.tap(find.text('Update'));
      await tester.pump();
      expect(find.text('Update available'), findsNothing);
      await notify(tester, 'failed');
      expect(
        find.text('Could not download or install the update.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Later'));
      await tester.pump();
      expect(find.text('Calendar content'), findsOneWidget);
      expect(find.text('Update available'), findsNothing);
    },
  );

  testWidgets('no Play offer leaves the app unchanged', (tester) async {
    offer = null;
    await launch(tester);
    expect(find.text('Calendar content'), findsOneWidget);
    expect(find.text('Update available'), findsNothing);
  });
}
