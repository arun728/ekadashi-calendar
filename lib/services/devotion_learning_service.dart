import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DevotionLearningService extends ChangeNotifier {
  DevotionLearningService({required this.premium, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final bool Function() premium;
  final DateTime Function() _clock;
  Map<String, dynamic> _data = {'bookmarks': {}, 'reviews': {}};
  Future<void>? _init;
  Future<void> _tail = Future.value();
  bool _disposed = false;
  Future<void> initialize() => _init ??= _load();
  Future<void> _load() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      'devotion_learning_v1',
    );
    if (raw != null) _data = jsonDecode(raw) as Map<String, dynamic>;
    if (!_disposed) notifyListeners();
  }

  bool bookmarked(String lesson, int line) =>
      (_data['bookmarks'] as Map)['$lesson/$line'] == true;
  DateTime? due(String lesson) {
    final review = (_data['reviews'] as Map)[lesson] as Map?;
    return review == null ? null : DateTime.parse(review['due'] as String);
  }

  Future<void> _change(void Function(Map<String, dynamic>) mutate) {
    final next = _tail.then((_) async {
      await initialize();
      if (!premium()) throw StateError('Premium required');
      final d = jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
      mutate(d);
      if (!await (await SharedPreferences.getInstance()).setString(
        'devotion_learning_v1',
        jsonEncode(d),
      )) {
        throw StateError('Learning storage failed');
      }
      _data = d;
      if (!_disposed) notifyListeners();
    });
    _tail = next.catchError((_) {});
    return next;
  }

  Future<void> bookmark(String lesson, int line) => _change((d) {
    if (lesson.isEmpty || line < 0) throw ArgumentError('Invalid line');
    final key = '$lesson/$line';
    final bookmarks = d['bookmarks'] as Map;
    bookmarks[key] = bookmarks[key] != true;
  });
  Future<void> revise(String lesson) => _change((d) {
    if (lesson.isEmpty) throw ArgumentError('Invalid lesson');
    final now = _clock();
    final day = DateTime(now.year, now.month, now.day);
    final reviews = d['reviews'] as Map;
    final prior = reviews[lesson] as Map?;
    if (prior != null && DateTime.parse(prior['due'] as String).isAfter(day)) {
      return;
    }
    final level = prior == null ? 0 : ((prior['level'] as int) + 1).clamp(0, 4);
    final next = DateTime(
      day.year,
      day.month,
      day.day + [1, 3, 7, 14, 30][level],
    );
    reviews[lesson] = {'level': level, 'due': next.toIso8601String()};
  });
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
