import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/widgets/ekadashi_lifecycle_status.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_lifecycle.dart';
import 'package:ekadashi_calendar/l10n/app_language.dart';

void main() {
  final event = EkadashiDate(id: 20, name: 'Papankusha', date: DateTime(2026,10,22), fastStartTime: '06:00 AM', fastBreakTime: '06:00 AM - 09:55 AM', description: '',
    fastingStartIso: '2026-10-22T06:00:00+05:30', paranaStartIso: '2026-10-23T06:00:00+05:30', paranaEndIso: '2026-10-23T09:55:00+05:30');
  for(final language in AppLanguage.codes) {
    for(final width in [320.0,390.0]) {
      testWidgets('Details statuses meet trailing edge with no overflow $language $width', (tester) async {
        tester.view.physicalSize=Size(width,844); tester.view.devicePixelRatio=1;
        addTearDown(tester.view.reset);
        for(final now in [DateTime.utc(2026,10,12), DateTime.utc(2026,10,21,20), DateTime.utc(2026,10,22,8), DateTime.utc(2026,10,23,2), DateTime.utc(2026,10,24)]) {
          for(final scale in [1.0,2.0]) {
            await withClock(Clock.fixed(now), () async {
              await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(scale)), child: Padding(padding: const EdgeInsets.all(20), child: EkadashiLifecycleStatus(event: event, timezone:'Asia/Kolkata',language:language))))));
              await tester.pumpAndSettle();
              final status = EkadashiLifecycle.of(event,now,'Asia/Kolkata');
              final pill = find.byType(StatusPill);
              expect(pill,findsOneWidget);
              expect(tester.getRect(pill).right,closeTo(width-20,1));
              expect(find.text(status.label(language)),findsOneWidget);
              expect(tester.takeException(),isNull);
              await tester.pumpWidget(const SizedBox());
            });
          }
        }
      });
    }
  }
}
