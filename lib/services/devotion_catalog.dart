import 'dart:convert';
import 'package:flutter/services.dart';
import 'devotion_audio_service.dart';

class DevotionLesson {
  const DevotionLesson({
    required this.id,
    required this.titleKey,
    required this.premium,
    required this.lines,
    required this.provenance,
  });
  final String id, titleKey, provenance;
  final bool premium;
  final List<Map<String, dynamic>> lines;
}

class DevotionCatalog {
  DevotionCatalog(this.tracks, this.lessons);
  final List<DevotionTrack> tracks;
  final List<DevotionLesson> lessons;
  static DevotionCatalog? _cached;
  static Future<DevotionCatalog> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final result = parse(
      jsonDecode(
            await rootBundle.loadString(
              'assets/devotion/catalog.json',
              cache: false,
            ),
          )
          as Map<String, dynamic>,
    );
    _cached = result;
    return result;
  }

  static DevotionCatalog parse(Map<String, dynamic> data) {
    if (data['version'] != 1) {
      throw const FormatException('Unsupported catalog');
    }
    final tracks = <DevotionTrack>[];
    final ids = <String>{};
    for (final raw in data['tracks'] as List) {
      final v = Map<String, dynamic>.from(raw as Map);
      final id = v['id'] as String;
      if (!ids.add(id) || id.isEmpty) {
        throw const FormatException('Duplicate/empty track');
      }
      // Explicit proof of both commercial rights and content review is required.
      if (v['rightsCleared'] != true ||
          v['reviewed'] != true ||
          (v['license'] as String? ?? '').isEmpty ||
          (v['provenance'] as String? ?? '').isEmpty ||
          (v['attribution'] as String? ?? '').isEmpty) {
        throw const FormatException('Uncleared content');
      }
      final source = v['source'] as String;
      if (!source.startsWith('asset:assets/devotion/') &&
          Uri.tryParse(source)?.scheme != 'https') {
        throw const FormatException('Unsafe source');
      }
      final hash = v['sha256'] as String;
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
        throw const FormatException('Missing integrity hash');
      }
      tracks.add(
        DevotionTrack(
          id: id,
          titleKey: v['titleKey'] as String,
          premium: v['premium'] == true,
          cleared: true,
          source: source,
          sha256: hash,
          offlineAllowed: v['offlineAllowed'] == true,
          attribution: v['attribution'] as String,
          license: v['license'] as String,
        ),
      );
    }
    final lessons = <DevotionLesson>[];
    for (final raw in data['lessons'] as List) {
      final v = Map<String, dynamic>.from(raw as Map);
      final lines = (v['lines'] as List)
          .map((l) => Map<String, dynamic>.unmodifiable(l as Map))
          .toList();
      if (lines.isEmpty ||
          !ids.add(v['id'] as String) ||
          (v['provenance'] as String).isEmpty) {
        throw const FormatException('Invalid lesson');
      }
      for (final line in lines) {
        if ((line['text'] as String).isEmpty ||
            (line['transliteration'] as String).isEmpty) {
          throw const FormatException('Invalid line');
        }
        if (line['trackId'] != null &&
            !tracks.any((t) => t.id == line['trackId'])) {
          throw const FormatException('Missing recitation');
        }
      }
      lessons.add(
        DevotionLesson(
          id: v['id'] as String,
          titleKey: v['titleKey'] as String,
          premium: v['premium'] == true,
          lines: List.unmodifiable(lines),
          provenance: v['provenance'] as String,
        ),
      );
    }
    return DevotionCatalog(
      List.unmodifiable(tracks),
      List.unmodifiable(lessons),
    );
  }
}
