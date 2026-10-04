import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'devotion_audio_service.dart';

class DevotionDownloads {
  DevotionDownloads({
    required this.premium,
    http.Client? client,
    Future<Directory> Function()? directory,
  }) : _client = client ?? http.Client(),
       _directory = directory ?? getApplicationSupportDirectory;
  final bool Function() premium;
  final http.Client _client;
  final Future<Directory> Function() _directory;
  Future<File> _file(DevotionTrack track) async {
    final dir = Directory('${(await _directory()).path}/devotion');
    await dir.create(recursive: true);
    // Content-addressed paths never contain untrusted track names.
    return File('${dir.path}/${track.sha256}.audio');
  }

  void _allowed(DevotionTrack track) {
    if (!premium() ||
        !track.cleared ||
        !track.offlineAllowed ||
        Uri.tryParse(track.source)?.scheme != 'https' ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(track.sha256)) {
      throw StateError('Download unavailable');
    }
  }

  Future<String?> cached(DevotionTrack track) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(track.sha256)) return null;
    final file = await _file(track);
    if (!await file.exists()) return null;
    if ((await file.length()) > 50 * 1024 * 1024 ||
        sha256.convert(await file.readAsBytes()).toString() != track.sha256) {
      await file.delete();
      return null;
    }
    return file.uri.toString();
  }

  Future<void> download(DevotionTrack track) async {
    _allowed(track);
    final file = await _file(track);
    if (await cached(track) != null) return;
    final request = http.Request('GET', Uri.parse(track.source))
      ..followRedirects = false;
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 ||
        (response.contentLength ?? 0) > 50 * 1024 * 1024) {
      throw StateError('Download failed');
    }
    // Unique partial file avoids races; nothing becomes playable until integrity passes.
    final partial = await File(
      '${file.path}.${const Uuid().v4()}.part',
    ).create();
    final sink = partial.openWrite();
    var length = 0;
    try {
      await (() async {
        await for (final bytes in response.stream) {
          length += bytes.length;
          if (length > 50 * 1024 * 1024) throw StateError('Download too large');
          sink.add(bytes);
        }
        await sink.flush();
      })().timeout(const Duration(seconds: 60));
      await sink.close();
      if (sha256.convert(await partial.readAsBytes()).toString() !=
          track.sha256) {
        throw StateError('Integrity failed');
      }
      _allowed(track);
      await partial.rename(file.path);
    } catch (_) {
      await sink.close();
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  Future<void> remove(DevotionTrack track) async {
    final file = await _file(track);
    if (await file.exists()) await file.delete();
  }

  void dispose() => _client.close();
}
