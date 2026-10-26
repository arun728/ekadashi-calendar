import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/screens/panchang_pages.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_data_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_models.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_terms.dart';

void main() {
  setUpAll(() async { await PanchangTerms.load(); });
  setUp(() => SharedPreferences.setMockInitialValues({'language_code':'en'}));
  final date=DateTime.utc(2026,10,26);
  Future<void> show(WidgetTester tester,PanchangDataService data) async {
    await tester.pumpWidget(ChangeNotifierProvider(create:(_)=>LanguageService(),child:MaterialApp(home:Scaffold(body:PanchangScreen(initialDate:date,initialCity:PanchangCity.chennai,data:data)))));
    await tester.pump(const Duration(milliseconds:300));
  }
  testWidgets('daily loading is asynchronous and an old date cannot overwrite the new date', (tester) async {
    final first=Completer<PanchangDay>(), second=Completer<PanchangDay>();
    final store=PanchangDataService(dayLoader:(d,_)=>d==date?first.future:second.future);
    await show(tester,store);
    expect(find.byType(PanchangDailyView),findsNothing);
    await tester.tap(find.byKey(const Key('panchang_next_day')).hitTestable().first);
    await tester.pump();
    final next=date.add(const Duration(days:1));
    second.complete(const PanchangEngine().calculate(next,city:PanchangCity.chennai));
    await tester.pumpAndSettle();
    expect(tester.widget<PanchangDailyView>(find.byType(PanchangDailyView)).day.date,next);
    first.complete(const PanchangEngine().calculate(date,city:PanchangCity.chennai));
    await tester.pumpAndSettle();
    expect(tester.widget<PanchangDailyView>(find.byType(PanchangDailyView)).day.date,next);
    expect(tester.takeException(),isNull);
  });
  testWidgets('daily error is retryable and a disposed page ignores completion', (tester) async {
    var calls=0;
    final pending=Completer<PanchangDay>();
    final store=PanchangDataService(dayLoader:(_,_) {calls++;return calls==1?Future.error(StateError('retry')):pending.future;});
    await show(tester,store);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(calls,2);
    await tester.pumpWidget(const SizedBox());
    pending.complete(const PanchangEngine().calculate(date,city:PanchangCity.chennai));
    await tester.pump();
    expect(tester.takeException(),isNull);
  });
}
