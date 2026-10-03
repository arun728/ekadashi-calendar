import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/search_index_manager.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/models/search_content_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<SearchIndexManager> index({String language = 'en'}) async {
    final s = SearchIndexManager();
    await s.buildIndexFromEkadashis([
      for (final year in [2026, 2027])
        EkadashiDate(
          id: year == 2026 ? 1 : 2027001,
          occurrenceUid: 'ekadashi:$year:01',
          name: language == 'te' ? 'వైకుంఠ ఏకాదశి' : 'Vaikuntha Ekadashi',
          date: DateTime(year, 1, 1),
          fastStartTime: '',
          fastBreakTime: '',
          description: language == 'te'
              ? 'భక్తితో ఉపవాసం'
              : 'Devotional observance',
          story: '',
          fastingRules: '',
        ),
    ], languageCode: language);
    return s;
  }

  test(
    'unmatched and punctuation-only queries return no unrelated boosted entries',
    () async {
      final s = await index();
      expect(s.search('zzzzreviewnomatch9999'), isEmpty);
      expect(s.search('!!!'), isEmpty);
    },
  );
  test(
    'one edit, transposition and two edits in long words find intended Ekadashi',
    () async {
      final s = await index();
      for (final query in ['vaikunta', 'vaikuntah', 'vaikntha', 'vaikxxtha']) {
        expect(
          s
              .search(query, contentType: SearchContentType.ekadashi)
              .map((e) => e.title),
          everyElement('Vaikuntha Ekadashi'),
          reason: query,
        );
        expect(
          s.search(query, contentType: SearchContentType.ekadashi),
          isNotEmpty,
          reason: query,
        );
      }
      expect(s.search('vx', contentType: SearchContentType.ekadashi), isEmpty);
      expect(
        s.search(
          'vaikuntha unrelatedword',
          contentType: SearchContentType.ekadashi,
        ),
        isEmpty,
      );
    },
  );
  test(
    'Telugu query retains its letters and matches the intended occurrence',
    () async {
      final s = await index(language: 'te');
      expect(SearchIndexManager.normalizeString('వైకుంఠ'), 'వైకుంఠ');
      expect(
        s.search('వైకుంఠ', contentType: SearchContentType.ekadashi),
        hasLength(2),
      );
    },
  );
  test(
    'requested language excludes unrelated English catalog entries',
    () async {
      final s = await index(language: 'te');
      expect(s.search('mantra', languageCode: 'te'), isEmpty);
    },
  );
  test('year selection preserves and distinguishes occurrences from both years',() async {
    final s=await index();
    for(final year in [2026,2027]) {
      final results=s.search('vaikuntha',contentType:SearchContentType.ekadashi,year:year);
      expect(results,hasLength(1));expect(results.single.sourceData['year'],year);
    }
  });
  test('latest language rebuild wins overlapping asynchronous indexing',() async {
    final s=await index();
    final old=s.buildIndexFromEkadashis([EkadashiDate(id:1,name:'Older English',date:DateTime(2026),fastStartTime:'',fastBreakTime:'',description:'')]);
    final current=s.buildIndexFromEkadashis([EkadashiDate(id:2027001,name:'కొత్త ఏకాదశి',date:DateTime(2027),fastStartTime:'',fastBreakTime:'',description:'')],languageCode:'te');
    await Future.wait([old,current]);
    expect(s.search('కొత్త',languageCode:'te'),isNotEmpty);expect(s.search('Older English'),isEmpty);
  });
  test('exact whole title token ranks above a merely matching prefix',() async {
    final s=SearchIndexManager();
    await s.buildIndexFromEkadashis([EkadashiDate(id:1,name:'Vaikuntham Ekadashi',date:DateTime(2026),fastStartTime:'',fastBreakTime:'',description:''),EkadashiDate(id:2,name:'Vaikuntha Ekadashi',date:DateTime(2026),fastStartTime:'',fastBreakTime:'',description:'')]);
    expect(s.search('vaikuntha',contentType:SearchContentType.ekadashi).first.title,'Vaikuntha Ekadashi');
  });

  test('typo match in a title outranks a passing mention in unrelated body text',() async {
    final s=SearchIndexManager();
    await s.buildIndexFromEkadashis([EkadashiDate(id:1,name:'Unrelated Ekadashi',date:DateTime(2026),fastStartTime:'',fastBreakTime:'',description:'Reaches Vaikuntha'),EkadashiDate(id:2,name:'Vaikuntha Ekadashi',date:DateTime(2026),fastStartTime:'',fastBreakTime:'',description:'')]);
    expect(s.search('vaikunta',contentType:SearchContentType.ekadashi).first.title,'Vaikuntha Ekadashi');
  });

}
