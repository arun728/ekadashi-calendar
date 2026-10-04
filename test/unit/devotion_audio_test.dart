import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/devotion_audio_service.dart';

class AudioFake implements DevotionAudioDriver {
  final List<String> calls = [];
  @override
  Future<void> load(String source) async {
    calls.add('load:$source');
  }

  @override
  Future<void> play() async {
    calls.add('play');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek');
  }
}

class SlowAudioFake extends AudioFake {
  final gate = Completer<void>();
  String? loaded;
  @override
  Future<void> load(String source) async {
    if (source == 'asset:first') await gate.future;
    loaded = source;
  }
}

void main() {
  const free = DevotionTrack(
    id: 'free',
    premium: false,
    cleared: true,
    source: 'asset:fixture.wav',
    sha256: '',
  );
  const paid = DevotionTrack(
    id: 'paid',
    premium: true,
    cleared: true,
    source: 'asset:fixture.wav',
    sha256: '',
  );
  test(
    'uncleared content and premium tracks fail closed before loading',
    () async {
      final driver = AudioFake();
      final service = DevotionAudioService(
        premium: () => false,
        driver: driver,
      );
      await expectLater(service.select(paid), throwsStateError);
      await expectLater(
        service.select(
          const DevotionTrack(
            id: 'bad',
            premium: false,
            cleared: false,
            source: 'asset:fixture.wav',
            sha256: '',
          ),
        ),
        throwsStateError,
      );
      expect(driver.calls, isEmpty);
      service.dispose();
    },
  );
  test('108-cycle playback stops after exactly 108 completions', () async {
    final driver = AudioFake();
    final service = DevotionAudioService(premium: () => true, driver: driver);
    await service.select(free);
    await service.setRepeat(108);
    for (var i = 0; i < 107; i++) {
      await service.completed();
    }
    expect(service.remaining, 1);
    await service.completed();
    expect(service.remaining, 0);
    expect(driver.calls.where((c) => c == 'play'), hasLength(108));
    expect(driver.calls.last, 'pause');
    service.dispose();
  });
  test(
    'free playback works but repeat configuration requires premium',
    () async {
      final driver = AudioFake();
      final service = DevotionAudioService(
        premium: () => false,
        driver: driver,
      );
      await service.select(free);
      expect(service.current?.id, 'free');
      await expectLater(service.setRepeat(108), throwsStateError);
      service.dispose();
    },
  );
  test(
    'rapid selection cannot leave the player loaded with an older track',
    () async {
      final driver = SlowAudioFake();
      final service = DevotionAudioService(premium: () => true, driver: driver);
      final first = service.select(
        const DevotionTrack(
          id: 'first',
          premium: false,
          cleared: true,
          source: 'asset:first',
          sha256: '',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final second = service.select(
        const DevotionTrack(
          id: 'second',
          premium: false,
          cleared: true,
          source: 'asset:second',
          sha256: '',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      driver.gate.complete();
      await Future.wait([first, second]);
      expect(service.current?.id, 'second');
      expect(driver.loaded, 'asset:second');
      service.dispose();
    },
  );
  test('expiry stops premium audio and prevents repeat grants', () async {
    var paid = true;
    final driver = AudioFake();
    final service = DevotionAudioService(premium: () => paid, driver: driver);
    await service.select(
      const DevotionTrack(
        id: 'paid',
        premium: true,
        cleared: true,
        source: 'asset:fixture',
        sha256: '',
      ),
    );
    await service.setRepeat(108);
    paid = false;
    await service.entitlementChanged();
    expect(service.playing, isFalse);
    expect(service.remaining, 0);
    expect(driver.calls.last, 'stop');
    await expectLater(service.toggle(), throwsStateError);
    service.dispose();
  });
}
