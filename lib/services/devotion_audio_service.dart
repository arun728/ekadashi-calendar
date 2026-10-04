import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class DevotionTrack {
  const DevotionTrack({
    required this.id,
    required this.premium,
    required this.cleared,
    required this.source,
    required this.sha256,
    this.titleKey = 'library_listen',
    this.offlineAllowed = false,
    this.attribution = '',
    this.license = '',
  });
  final String id, source, sha256, titleKey, attribution, license;
  final bool premium, cleared, offlineAllowed;
}

abstract interface class DevotionAudioDriver {
  Future<void> load(String source);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
}

class JustAudioDriver implements DevotionAudioDriver {
  AudioPlayer? _player;
  AudioPlayer get player => _player ??= AudioPlayer();
  Future<void>? _setup;
  Future<void> _configure() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  @override
  Future<void> load(String source) async {
    await (_setup ??= _configure());
    if (source.startsWith('asset:')) {
      await player.setAsset(source.substring(6));
    } else if (source.startsWith('file:')) {
      await player.setFilePath(Uri.parse(source).toFilePath());
    } else {
      await player.setUrl(source);
    }
  }

  @override
  Future<void> play() async {
    // just_audio's play Future completes only on pause/end; do not block UI.
    unawaited(player.play().catchError((_) {}));
  }

  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> stop() => player.stop();
  @override
  Future<void> seek(Duration position) => player.seek(position);
  Future<void> dispose() async {
    await _player?.dispose();
  }
}

/// Current verified entitlement is checked at selection, resume and every loop.
class DevotionAudioService extends ChangeNotifier {
  DevotionAudioService({required this.premium, required this.driver});
  void _attachNative() {
    if (_subscriptions.isNotEmpty) return;
    if (driver is JustAudioDriver) {
      final native = driver as JustAudioDriver;
      _subscriptions.add(
        native.player.playerStateStream.listen((state) {
          playing =
              state.playing &&
              state.processingState != ProcessingState.completed;
          final completedNow =
              state.processingState == ProcessingState.completed;
          if (completedNow && !_nativeCompleted) {
            _nativeCompleted = true;
            completed().catchError((_) {
              error = 'library_audio_error';
              _notify();
            });
          }
          if (!completedNow) _nativeCompleted = false;
          _notify();
        }),
      );
      _subscriptions.add(
        native.player.positionStream.listen((value) {
          position = value;
          _notify();
        }),
      );
      _subscriptions.add(
        native.player.durationStream.listen((value) {
          duration = value ?? Duration.zero;
          _notify();
        }),
      );
      _subscriptions.add(
        native.player.playbackEventStream.listen(
          (_) {},
          onError: (_) {
            error = 'library_audio_error';
            playing = false;
            _notify();
          },
        ),
      );
    }
  }

  final bool Function() premium;
  final DevotionAudioDriver driver;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  DevotionTrack? current;
  int remaining = 0;
  bool playing = false, busy = false;
  String? error;
  Duration position = Duration.zero, duration = Duration.zero;
  Timer? _sleep;
  int _epoch = 0;
  Future<void> _selectionTail = Future.value();
  bool _nativeCompleted = false;
  bool _disposed = false, _completing = false;
  final List<DevotionTrack> playlist = [];
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _allowed(DevotionTrack track) {
    if (!track.cleared || (track.premium && !premium())) {
      throw StateError('Audio not available');
    }
    if (!(track.source.startsWith('asset:') ||
        track.source.startsWith('file:') ||
        Uri.tryParse(track.source)?.scheme == 'https')) {
      throw StateError('Invalid audio source');
    }
  }

  Future<void> select(DevotionTrack track, {bool preserveSleep = false}) async {
    _allowed(track);
    final epoch = ++_epoch;
    final next = _selectionTail.then(
      (_) => _select(track, epoch, preserveSleep),
    );
    _selectionTail = next.catchError((_) {});
    await next;
  }

  Future<void> _select(
    DevotionTrack track,
    int epoch,
    bool preserveSleep,
  ) async {
    if (_disposed || epoch != _epoch) return;
    _attachNative();
    if (!preserveSleep) _sleep?.cancel();
    remaining = 1;
    busy = true;
    error = null;
    _notify();
    try {
      await driver.stop();
      await driver.load(track.source);
      if (_disposed || epoch != _epoch) return;
      _allowed(track);
      current = track;
      position = Duration.zero;
      await driver.play();
      playing = true;
    } catch (_) {
      if (epoch == _epoch) {
        current = null;
        playing = false;
        error = 'library_audio_error';
      }
      rethrow;
    } finally {
      if (epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> toggle() async {
    if (current == null || busy) return;
    _allowed(current!);
    if (playing) {
      await driver.pause();
      playing = false;
    } else {
      if (remaining == 0) {
        remaining = 1;
        await driver.seek(Duration.zero);
      }
      await driver.play();
      playing = true;
    }
    _notify();
  }

  Future<void> seek(Duration value) async {
    if (current == null) return;
    _allowed(current!);
    await driver.seek(value < Duration.zero ? Duration.zero : value);
  }

  Future<void> setRepeat(int repetitions) async {
    if (!premium()) throw StateError('Premium required');
    if (current == null || repetitions < 1 || repetitions > 108) {
      throw ArgumentError('Invalid repetition count');
    }
    remaining = repetitions;
    _notify();
  }

  Future<void> addToPlaylist(DevotionTrack track) async {
    if (!premium()) throw StateError('Premium required');
    _allowed(track);
    playlist.add(track);
    _notify();
  }

  void removeFromPlaylist(int index) {
    playlist.removeAt(index);
    _notify();
  }

  Future<void> completed() async {
    if (_disposed || _completing || current == null || remaining == 0) return;
    _completing = true;
    try {
      if (current!.premium && !premium()) {
        await stop();
        return;
      }
      if (!premium()) remaining = 1;
      remaining--;
      if (remaining > 0) {
        await driver.seek(Duration.zero);
        await driver.play();
        playing = true;
      } else if (playlist.isNotEmpty && premium()) {
        final next = playlist.removeAt(0);
        await select(next, preserveSleep: true);
      } else {
        await driver.pause();
        playing = false;
      }
      _notify();
    } finally {
      _completing = false;
    }
  }

  void sleepAfter(Duration duration) {
    if (!premium()) throw StateError('Premium required');
    if (duration <= Duration.zero || duration > const Duration(hours: 3)) {
      throw ArgumentError('Invalid sleep duration');
    }
    _sleep?.cancel();
    _sleep = Timer(duration, () {
      stop().catchError((_) {
        error = 'library_audio_error';
        _notify();
      });
    });
  }

  Future<void> entitlementChanged() async {
    if (!premium()) {
      playlist.clear();
      remaining = remaining > 0 ? 1 : 0;
      _sleep?.cancel();
      if (current?.premium == true) {
        await stop();
      }
      _notify();
    }
  }

  void dismiss() {
    current = null;
    _notify();
  }

  Future<void> stop() async {
    ++_epoch;
    _sleep?.cancel();
    remaining = 0;
    playing = false;
    busy = false;
    await driver.stop();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _sleep?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    if (driver is JustAudioDriver) {
      (driver as JustAudioDriver).dispose();
    }
    super.dispose();
  }
}
