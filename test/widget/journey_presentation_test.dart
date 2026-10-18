import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/journey_rewards.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/achievement_unlock_dialog.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/journey_artwork.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/journey_rewards_views.dart';

void main(){
 setUp(()=>SharedPreferences.setMockInitialValues({}));
 testWidgets('all 21 vector badges paint in locked and earned states at both sizes',(tester)async{
  for(final b in JourneyBadgeCatalog.all([2026,2027])){
   for(final size in [48.0,160.0]){
    await tester.pumpWidget(MaterialApp(home:Row(children:[JourneyBadgeArt(definition:b,size:size),JourneyBadgeArt(definition:b,size:size,earned:false)])));
    expect(find.byType(CustomPaint),findsWidgets); expect(tester.takeException(),isNull,reason:b.id);
   }
  }
 });
 testWidgets('grouped unlocks deduplicate, respect haptics setting and expose details',(tester)async{
  final calls=<Object?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,(call)async{if(call.method=='HapticFeedback.vibrate')calls.add(call.arguments);return null;});
  addTearDown(()=>tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,null));
  final tracker=VratTrackerService(); await tracker.init(); await tracker.setBadgeHaptics(false);
  final badges=JourneyBadgeCatalog.all([]).take(2).map((b)=>b.achievement).toList();
  await tester.pumpWidget(MultiProvider(providers:[ChangeNotifierProvider.value(value:tracker),ChangeNotifierProvider(create:(_)=>LanguageService())],child:MaterialApp(home:Builder(builder:(c)=>Scaffold(body:TextButton(onPressed:()=>AchievementUnlockDialog.showGroup(c,[...badges,...badges]),child:const Text('show')))))));
  await tester.tap(find.text('show'));await tester.pumpAndSettle();
  expect(find.text('First Step'),findsOneWidget);expect(find.text('Taking Root'),findsOneWidget);
  expect(calls,isEmpty);
  await tester.tap(find.byKey(const Key('journey_celebration_close')));await tester.pumpAndSettle();
  final restored=VratTrackerService();await restored.init();expect(restored.badgeHaptics,false);
 });
 testWidgets('annual share card forces dark rendering in either app appearance',(tester)async{
  final p=JourneyRewards.calculate(occurrences:[],history:[],completeYears:{}).year(2027);
  final images=<Object>[];
  for(final brightness in [Brightness.light,Brightness.dark]){
   final boundary=GlobalKey();
   await tester.pumpWidget(ChangeNotifierProvider(create:(_)=>LanguageService(),child:MaterialApp(theme:ThemeData(brightness:brightness),home:Center(child:RepaintBoundary(key:boundary,child:SizedBox(width:360,child:JourneyAnnualShareCard(progress:p,badges:[])))))));
   await tester.pumpAndSettle();
   final render=boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
   final image=await render.toImage();images.add((await image.toByteData())!.buffer.asUint8List().toList());image.dispose();
  }
  expect(images[0],images[1]);
 });
}
