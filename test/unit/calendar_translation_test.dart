import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUpAll(()=>EkadashiService().initializeData());
 for(final code in ['ta','hi','te']){
  test('$code has translated names, stories, rules, benefits, months and paksha in both years',(){
   final script=RegExp(code=='ta'?r'[\u0B80-\u0BFF]':code=='hi'?r'[\u0900-\u097F]':r'[\u0C00-\u0C7F]');
   for(final e in EkadashiService().getEkadashis(timezone:'IST',languageCode:code)){
    expect(e.usesContentFallback,isFalse,reason:'${e.occurrenceUid} $code');
    for(final value in [e.name,e.description,e.story,e.fastingRules,e.benefits,e.month,e.paksha]) {
     expect(script.hasMatch(value),isTrue,reason:'${e.occurrenceUid} $code: $value');
    }
   }
  });
 }
}
