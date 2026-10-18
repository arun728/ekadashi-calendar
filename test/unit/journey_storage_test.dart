import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
import 'journey_rewards_test.dart' show journeyEvents, journeyNow;

class _AwardStore extends InMemorySharedPreferencesStore {
 _AwardStore():super.empty();
 bool fail=false;
 @override Future<bool> setValue(String type,String key,Object value)async {
  if(fail&&key.endsWith('journey_badges_v1'))return false;
  return super.setValue(type,key,value);
 }
}
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUpAll(tzdata.initializeTimeZones);
 setUp(()=>SharedPreferences.setMockInitialValues({}));
 test('award write failure preserves history and retries the unpresented award',()async{
  final original=SharedPreferencesStorePlatform.instance,store=_AwardStore();
  SharedPreferencesStorePlatform.instance=store;
  addTearDown(()=>SharedPreferencesStorePlatform.instance=original);
  final tracker=VratTrackerService(now:()=>journeyNow),es=journeyEvents(2026);
  await tracker.init(occurrences:es);store.fail=true;
  expect(await tracker.recordVrat(ekadashiOccurrenceId:es[0].id,occurrenceUid:es[0].occurrenceUid,ekadashiDate:'2026-01-03',ekadashiName:'E',status:ObservanceStatus.observed,occurrences:es),isEmpty);
  expect(tracker.rewardsStorageError,true);expect(tracker.getAllRecords().length,1);
  store.fail=false;expect((await tracker.refreshAchievements(es)).map((a)=>a.id),['first_vrat']);expect(tracker.rewardsStorageError,false);
 });
 test('valid envelope wins over corrupt legacy store and retains presentation',()async{
  final tracker=VratTrackerService(now:()=>journeyNow),es=journeyEvents(2026);
  await tracker.init(occurrences:es);
  final awards=await tracker.recordVrat(ekadashiOccurrenceId:es[0].id,occurrenceUid:es[0].occurrenceUid,ekadashiDate:'2026-01-03',ekadashiName:'E',status:ObservanceStatus.observed,occurrences:es);
  await tracker.markAnnouncementsPresented(awards.map((a)=>a.id));
  await (await SharedPreferences.getInstance()).setString('vrat_tracker_user_achievements','invalid');
  final restored=VratTrackerService(now:()=>journeyNow);await restored.init(occurrences:es);
  expect(restored.rewardsStorageError,false);expect(restored.userAchievements['first_vrat']?.isUnlocked,true);expect(await restored.refreshAchievements(es),isEmpty);
 });
}
