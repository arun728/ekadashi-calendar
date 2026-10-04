import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ekadashi_calendar/services/devotion_audio_service.dart';
import 'package:ekadashi_calendar/services/devotion_downloads.dart';
import 'package:ekadashi_calendar/services/devotion_catalog.dart';

void main() {
  test('catalog refuses a recording without commercial rights and review', () {
    expect(
      () => DevotionCatalog.parse({
        'version': 1,
        'lessons': [],
        'tracks': [
          {'id': 'bad', 'rightsCleared': false},
        ],
      }),
      throwsFormatException,
    );
  });
  test(
    'offline download verifies bytes before publishing and rejects corruption',
    () async {
      final dir = await Directory.systemTemp.createTemp('devotion-test-');
      addTearDown(() => dir.delete(recursive: true));
      final bytes = [1, 2, 3, 4];
      final hash = sha256.convert(bytes).toString();
      bool corrupt = true, paid = true;
      var calls = 0;
      final store = DevotionDownloads(
        premium: () => paid,
        directory: () async => dir,
        client: MockClient((request) async {
          calls++;
          expect(request.followRedirects, isFalse);
          return http.Response.bytes(corrupt ? [9] : bytes, 200);
        }),
      );
      final track = DevotionTrack(
        id: 'a',
        premium: true,
        cleared: true,
        source: 'https://example.test/audio',
        sha256: hash,
        offlineAllowed: true,
      );
      await expectLater(store.download(track), throwsStateError);
      expect(await store.cached(track), isNull);
      expect(
        await dir
            .list(recursive: true)
            .where((f) => f.path.endsWith('.part'))
            .length,
        0,
      );
      corrupt = false;
      await store.download(track);
      expect(await store.cached(track), isNotNull);
      paid = false;
      final before = calls;
      await expectLater(store.download(track), throwsStateError);
      expect(calls, before);
      // Downgrade preserves a valid download; access is separately checked by playback.
      expect(await store.cached(track), isNotNull);
      store.dispose();
    },
  );
}
