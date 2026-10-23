import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/display_clock.dart';
void main(){test('Debug override survives frame callback zones and clears back to real time',(){
 final date=DateTime.utc(2026,10,22);DisplayClock.setTestClock(()=>date);
 expect(DisplayClock.now(),date);DisplayClock.setTestClock(null);
 expect(DisplayClock.now().difference(DateTime.now()).inSeconds.abs(),lessThan(2));
});}
