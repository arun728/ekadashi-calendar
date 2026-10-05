import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import '../support/premium_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          File(
            'test/fonts/${entry.value}',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await loader.load();
    }
  });

  testWidgets('Panchang free and premium screens render review screenshots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    final backend = PremiumFixture()..premium = false;
    final premium = PremiumService(entitlements: backend);
    addTearDown(premium.dispose);

    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final directory = Directory('build/ui-screenshots/offscreen');
        await directory.create(recursive: true);
        await File(
          '${directory.path}/panchang_$name.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(
      ChangeNotifierProvider<PremiumService>.value(
        value: premium,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: RepaintBoundary(
            key: boundaryKey,
            child: Scaffold(
              body: PanchangScreen(initialDate: DateTime(2026, 2, 15)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unlock full Panchang'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture('free');

    backend.premium = true;
    await premium.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Five limbs'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const Key('panchang_scroll_view')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();
    expect(find.text('Panchang'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Panchang')).dy, lessThan(70));
    await capture('premium');
    expect(tester.takeException(), isNull);
  });
}
