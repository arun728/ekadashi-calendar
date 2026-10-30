import 'dart:async';
import 'panchang_city.dart';

/// Bounded session reuse of both completed and in-flight calculations.
/// Completed values get a new Future in the caller's zone (widget-test fake
/// clocks must not inherit a completed Future from another test zone).
class PanchangCalculationCache<T extends Object> {
  PanchangCalculationCache({int capacity = 24})
    : capacity = capacity < 1 ? 1 : capacity;
  final int capacity;
  final _entries = <String, _Entry<T>>{};
  T? cached(String key) => _entries[key]?.value;
  void clear() => _entries.clear();
  void put(String key, T value) {
    _entries[key] = _Entry<T>()..value = value;
    _trim();
  }

  void _trim() {
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  Future<T> value(String key, FutureOr<T> Function() calculate) {
    final previous = _entries[key];
    if (previous?.value case final T value) return Future.value(value);
    if (previous?.pending case final Future<T> running) return running;
    final entry = _Entry<T>();
    _entries[key] = entry;
    _trim();
    return entry.pending = Future<T>.sync(calculate).then(
      (value) {
        entry.value = value;
        entry.pending = null;
        return value;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_entries[key], entry)) _entries.remove(key);
        Error.throwWithStackTrace(error, stack);
      },
    );
  }
}

class _Entry<T> {
  T? value;
  Future<T>? pending;
}

/// Complete calculation identity; translated labels are intentionally absent.
String panchangPlaceKey(PanchangCity city) =>
    '${city.id}|${city.label}|${city.latitude}|${city.longitude}|${city.timeZoneId}';
