import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/services/display_clock.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/screens/widget_preview_screen.dart';
import '../support/app_harness.dart';
void main(){testWidgets('hidden native preview has no refresh ticks',(tester)async{
 final harness=AppHarness();await tester.runAsync(harness.install);addTearDown(harness.uninstall);
 var reads=0;DisplayClock.setTestClock((){reads++;return DateTime.utc(2026,10,22);});addTearDown(()=>DisplayClock.setTestClock(null));
 await tester.pumpWidget(ChangeNotifierProvider(create:(_)=>LanguageService(),child:const MaterialApp(home:TickerMode(enabled:false,child:WidgetPreviewScreen(ekadashiList:[])))));
 await tester.pumpAndSettle();final initial=reads;await tester.pump(const Duration(minutes:2));expect(reads,initial);
 await tester.pumpWidget(const SizedBox());
});}
