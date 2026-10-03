import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/models/search_content_type.dart';
import 'package:ekadashi_calendar/services/recent_search_repository.dart';
import 'package:ekadashi_calendar/services/search_index_manager.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Module 19 — RecentSearchRepository Tests (EC2-FR-082)', () {
    late RecentSearchRepository repo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = RecentSearchRepository();
    });

    test('addSearch adds search term to top and retrieves correctly', () async {
      await repo.addSearch('Ekadashi');
      await repo.addSearch('Nirjala');

      final recents = await repo.getRecentSearches();
      expect(recents.length, 2);
      expect(recents.first, 'Nirjala');
      expect(recents[1], 'Ekadashi');
    });

    test('addSearch deduplicates and moves re-searched term to top', () async {
      await repo.addSearch('Ekadashi');
      await repo.addSearch('Katha');
      await repo.addSearch('Ekadashi'); // Repeated

      final recents = await repo.getRecentSearches();
      expect(recents.length, 2);
      expect(recents.first, 'Ekadashi');
      expect(recents[1], 'Katha');
    });

    test('addSearch limits to maximum 10 items', () async {
      for (int i = 1; i <= 15; i++) {
        await repo.addSearch('Query $i');
      }

      final recents = await repo.getRecentSearches();
      expect(recents.length, 10);
      expect(recents.first, 'Query 15');
      expect(recents.contains('Query 1'), false);
    });

    test('deleteSearch removes only the specified term', () async {
      await repo.addSearch('Mantra');
      await repo.addSearch('Food');
      await repo.deleteSearch('Food');

      final recents = await repo.getRecentSearches();
      expect(recents.length, 1);
      expect(recents.first, 'Mantra');
    });

    test('clearAll removes all recent searches', () async {
      await repo.addSearch('Vrat');
      await repo.addSearch('Temple');
      await repo.clearAll();

      final recents = await repo.getRecentSearches();
      expect(recents.isEmpty, true);
    });

    test(
      'addSearch trims whitespace and rejects empty/whitespace query',
      () async {
        await repo.addSearch('   ');
        await repo.addSearch('');
        var recents = await repo.getRecentSearches();
        expect(recents.isEmpty, true);

        await repo.addSearch('  Parivartana Ekadashi  ');
        recents = await repo.getRecentSearches();
        expect(recents.length, 1);
        expect(recents.first, 'Parivartana Ekadashi');
      },
    );

    test(
      'sanitizeHistory cleans up intermediate progressive prefixes from legacy bug',
      () {
        final raw = [
          'Parivartana Ekadashi',
          'par',
          'pa',
          'p',
          'Nirjala Ekadashi',
        ];
        final cleaned = RecentSearchRepository.sanitizeHistory(raw);
        expect(cleaned.length, 2);
        expect(cleaned, ['Parivartana Ekadashi', 'Nirjala Ekadashi']);
      },
    );

    test(
      'addSearch cleans legacy intermediate prefixes of the added query',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('ec2_recent_searches_list', [
          'p',
          'pa',
          'par',
        ]);

        await repo.addSearch('Parivartana Ekadashi');
        final recents = await repo.getRecentSearches();
        expect(recents.length, 1);
        expect(recents.first, 'Parivartana Ekadashi');
      },
    );
  });

  group(
    'Module 19 — SearchIndexManager & Catalog Tests (EC2-FR-079, EC2-FR-080)',
    () {
      late SearchIndexManager manager;

      setUp(() {
        SharedPreferences.setMockInitialValues({});
        manager = SearchIndexManager();
      });

      test(
        'SearchIndexManager indexes curated content across all 8 content types',
        () async {
          await manager.buildIndexFromEkadashis([]);

          final allEntries = manager.allEntries;
          expect(allEntries.isNotEmpty, true);

          // Verify presence of indexed items for each category
          final types = allEntries.map((e) => e.contentType).toSet();
          expect(types.contains(SearchContentType.katha), true);
          expect(types.contains(SearchContentType.mantra), true);
          expect(types.contains(SearchContentType.food), true);
          expect(types.contains(SearchContentType.vratInfo), true);
          expect(types.contains(SearchContentType.festival), true);
          expect(types.contains(SearchContentType.temple), true);
          expect(types.contains(SearchContentType.event), true);
        },
      );

      test(
        'Search normalization handles case, punctuation, and leading/trailing spaces',
        () async {
          await manager.buildIndexFromEkadashis([]);

          final res1 = manager.search('nirjala');
          final res2 = manager.search('  NIRJALA!  ');
          expect(res1.isNotEmpty, true);
          expect(res2.isNotEmpty, true);
          expect(res1.first.id, res2.first.id);
        },
      );

      test(
        'Search relevance ranks exact title higher than description matches',
        () async {
          await manager.buildIndexFromEkadashis([]);

          final results = manager.search('Nirjala Ekadashi Mahatmya');
          expect(results.isNotEmpty, true);
          expect(results.first.title.toLowerCase().contains('nirjala'), true);
          expect(results.first.relevanceScore >= 80, true);
        },
      );

      test(
        'Filter chips correctly restrict results by category (EC2-FR-080)',
        () async {
          await manager.buildIndexFromEkadashis([]);

          // 1. Food only
          final foodResults = manager.search(
            'potato',
            contentType: SearchContentType.food,
          );
          expect(foodResults.isNotEmpty, true);
          for (final r in foodResults) {
            expect(r.contentType, SearchContentType.food);
          }

          // 2. Mantra only
          final mantraResults = manager.search(
            'om',
            contentType: SearchContentType.mantra,
          );
          expect(mantraResults.isNotEmpty, true);
          for (final r in mantraResults) {
            expect(r.contentType, SearchContentType.mantra);
          }

          // 3. Vrat Info only
          final vratResults = manager.search(
            'parana',
            contentType: SearchContentType.vratInfo,
          );
          expect(vratResults.isNotEmpty, true);
          for (final r in vratResults) {
            expect(r.contentType, SearchContentType.vratInfo);
          }
        },
      );

      test('Live search suggestions return relevant matching titles', () async {
        await manager.buildIndexFromEkadashis([]);

        final suggestions = manager.getLiveSuggestions('vish', limit: 5);
        expect(suggestions.isNotEmpty, true);
        expect(suggestions.any((s) => s.toLowerCase().contains('vish')), true);
      });
    },
  );

  group('Module 19 — Offline Search & Download Integration (EC2-FR-081)', () {
    late SearchIndexManager manager;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      manager = SearchIndexManager();
    });

    test(
      'Offline mode returns only downloaded content, excluding online-only items',
      () async {
        await manager.buildIndexFromEkadashis([]);

        // Online search should show online-only items
        manager.setForcedOffline(false);
        final onlineResults = manager.search(
          'Vaikuntha Ekadashi Celestial Gate Story',
          contentType: SearchContentType.katha,
        );
        expect(onlineResults.isNotEmpty, true);
        final item = onlineResults.first;
        expect(item.isOnlineOnly, true);
        expect(item.isDownloaded, false);

        // In Offline mode, online-only items MUST NOT appear
        manager.setForcedOffline(true);
        final offlineResults = manager.search(
          'Vaikuntha Ekadashi Celestial Gate Story',
          contentType: SearchContentType.katha,
        );
        expect(offlineResults.isEmpty, true);
      },
    );

    test(
      'Downloading content makes it immediately available in offline search',
      () async {
        await manager.buildIndexFromEkadashis([]);

        const targetId = 'katha_online_vaikuntha';

        // 1. Verify it is not available in offline search
        manager.setForcedOffline(true);
        var offlineResults = manager.search(
          'Vaikuntha Ekadashi Celestial Gate Story',
          contentType: SearchContentType.katha,
        );
        expect(offlineResults.isEmpty, true);

        // 2. Download content
        final downloadSuccess = await manager.downloadContent(targetId);
        expect(downloadSuccess, true);

        // 3. Now search again offline: it should be found and marked as isDownloaded = true
        offlineResults = manager.search(
          'Vaikuntha Ekadashi Celestial Gate Story',
          contentType: SearchContentType.katha,
        );
        expect(offlineResults.isNotEmpty, true);
        expect(offlineResults.first.isDownloaded, true);
        expect(offlineResults.first.id, targetId);
      },
    );
  });

  group('Module 19 — Data Safety Requirement (Read-Only Verification)', () {
    test(
      'Existing Ekadashi calculation and dates remain completely unmodified',
      () async {
        final sampleEkadashi = EkadashiDate(
          id: 20261021,
          name: 'Papankusha Ekadashi',
          date: DateTime(2026, 10, 21),
          fastStartTime: '06:12 AM',
          fastBreakTime: '06:12 AM - 10:15 AM',
          description: 'Papankusha description text',
          story: 'Story text',
          fastingRules: 'Fasting rules text',
          benefits: 'Spiritual benefits text',
          fastingStartIso: '2026-10-21T06:12:00+05:30',
          paranaStartIso: '2026-10-22T06:12:00+05:30',
          paranaEndIso: '2026-10-22T10:15:00+05:30',
        );

        final manager = SearchIndexManager();
        await manager.buildIndexFromEkadashis([sampleEkadashi]);

        // Verify that sampleEkadashi object was not mutated
        expect(sampleEkadashi.id, 20261021);
        expect(sampleEkadashi.name, 'Papankusha Ekadashi');
        expect(sampleEkadashi.date, DateTime(2026, 10, 21));
        expect(sampleEkadashi.fastBreakTime, '06:12 AM - 10:15 AM');
        expect(sampleEkadashi.fastingStartIso, '2026-10-21T06:12:00+05:30');

        // Verify search finds it accurately
        final results = manager.search('Papankusha');
        expect(results.isNotEmpty, true);
        expect(results.first.contentType, SearchContentType.ekadashi);
        expect(results.first.id, 'ekadashi_20261021');
      },
    );
  });
}
