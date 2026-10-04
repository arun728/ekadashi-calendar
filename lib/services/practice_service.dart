import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class PracticeRoutine {
  const PracticeRoutine({
    required this.id,
    required this.title,
    required this.steps,
    this.weekdays = const [],
    this.reminderMinute,
  });
  final String id, title;
  final List<String> steps;
  final List<int> weekdays;
  final int? reminderMinute;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'steps': steps,
    'weekdays': weekdays,
    'reminderMinute': reminderMinute,
  };
  factory PracticeRoutine.fromJson(Map<String, dynamic> value) =>
      PracticeRoutine(
        id: value['id'] as String,
        title: value['title'] as String,
        steps: List<String>.from(value['steps'] as List),
        weekdays: List<int>.from(value['weekdays'] as List),
        reminderMinute: value['reminderMinute'] as int?,
      );
}

/// Local practice data is independent of Vrat and the fasting reward ledger.
/// Mutations serialize and publish only after a successful durable write.
class PracticeService extends ChangeNotifier {
  PracticeService({
    required this.premium,
    DateTime Function()? clock,
    Future<String?> Function()? read,
    Future<bool> Function(String)? write,
  }) : _clock = clock ?? DateTime.now,
       _read = read,
       _write = write;
  static const storageKey = 'daily_practice_v1';
  final bool Function() premium;
  final DateTime Function() _clock;
  final Future<String?> Function()? _read;
  final Future<bool> Function(String)? _write;
  Future<void>? _initializing;
  Future<void> _tail = Future.value();
  bool _disposed = false, ready = false;
  String? loadError;
  Map<String, dynamic> _data = {
    'version': 1,
    'routines': [],
    'goals': [],
    'sessions': [],
    'days': [],
    'checks': {},
    'active': null,
    'quietStart': 1320,
    'quietEnd': 420,
  };
  Map<String, dynamic>? get _active => _data['active'] as Map<String, dynamic>?;
  int get count => _active?['count'] as int? ?? 0;
  int get goal => _active?['goal'] as int? ?? 108;
  int get malaSize => _active?['malaSize'] as int? ?? 108;
  int get rounds => count ~/ malaSize;
  String get mantra => _active?['mantra'] as String? ?? '';
  bool get haptics => _active?['haptics'] == true;
  bool get running => _active?['since'] != null;
  bool get hasSession => _active != null;
  int get elapsedSeconds =>
      (_active?['seconds'] as int? ?? 0) +
      (running
          ? math.max(
              0,
              _clock()
                  .difference(DateTime.parse(_active!['since'] as String))
                  .inSeconds,
            )
          : 0);
  int get quietStart => _data['quietStart'] as int;
  int get quietEnd => _data['quietEnd'] as int;
  List<PracticeRoutine> get routines => List.unmodifiable(
    (_data['routines'] as List).map(
      (v) => PracticeRoutine.fromJson(Map<String, dynamic>.from(v as Map)),
    ),
  );
  List<Map<String, dynamic>> get goals => _items('goals');
  List<Map<String, dynamic>> get sessions => _items('sessions');
  List<Map<String, dynamic>> _items(String name) => List.unmodifiable(
    (_data[name] as List).map(
      (v) => Map<String, dynamic>.unmodifiable(v as Map),
    ),
  );
  String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  int get streak {
    final dates = Set<String>.from(_data['days'] as List);
    var day = _clock();
    if (!dates.contains(_day(day))) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var result = 0;
    while (dates.contains(_day(day))) {
      result++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return result;
  }

  int get weeklyCount => sessions
      .where(
        (s) => !_date(
          s,
        ).isBefore(DateTime(_clock().year, _clock().month, _clock().day - 6)),
      )
      .fold(0, (sum, s) => sum + (s['count'] as int));
  DateTime _date(Map<String, dynamic> s) =>
      DateTime.parse(s['endedAt'] as String).toLocal();
  bool checked(String id, int step) =>
      (_data['checks'] as Map)['${_day(_clock())}/$id/$step'] == true;
  bool due(PracticeRoutine routine) =>
      routine.weekdays.isEmpty || routine.weekdays.contains(_clock().weekday);

  Future<void> initialize() => _initializing ??= _load();
  Future<void> _load() async {
    try {
      final raw = _read != null
          ? await _read()
          : (await SharedPreferences.getInstance()).getString(storageKey);
      if (raw != null) {
        final value = jsonDecode(raw) as Map<String, dynamic>;
        if (value['version'] != 1 ||
            value['routines'] is! List ||
            value['sessions'] is! List ||
            value['days'] is! List ||
            value['goals'] is! List ||
            value['checks'] is! Map) {
          throw const FormatException('Invalid practice data');
        }
        // Exercise typed readers before adopting persisted data. Do not erase corruption.
        for (final r in value['routines'] as List) {
          PracticeRoutine.fromJson(Map<String, dynamic>.from(r as Map));
        }
        _data = value;
      }
      ready = true;
      loadError = null;
      if (!_disposed) notifyListeners();
    } catch (_) {
      _initializing = null;
      loadError = 'practice_error';
      if (!_disposed) notifyListeners();
      rethrow;
    }
  }

  Future<void> _change(void Function(Map<String, dynamic>) mutation) {
    final next = _tail.then((_) async {
      await initialize();
      if (_disposed) throw StateError('Practice disposed');
      final draft = jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
      mutation(draft);
      final raw = jsonEncode(draft);
      final saved = _write != null
          ? await _write(raw)
          : await (await SharedPreferences.getInstance()).setString(
              storageKey,
              raw,
            );
      if (!saved) throw StateError('Practice storage failed');
      _data = draft;
      if (!_disposed) notifyListeners();
    });
    _tail = next.catchError((_) {});
    return next;
  }

  void _requirePremium() {
    if (!premium()) throw StateError('Premium required');
  }

  void _validGoal(String mantra, int goal, int size) {
    if (mantra.length > 240 ||
        goal < 1 ||
        goal > 100000 ||
        size < 1 ||
        size > 1080) {
      throw ArgumentError('Invalid goal');
    }
  }

  Future<void> start({
    String mantra = '',
    int goal = 108,
    int malaSize = 108,
    bool haptics = false,
  }) => _change((d) {
    if (d['active'] != null) {
      throw StateError('Resume or finish the active session');
    }
    _validGoal(mantra, goal, malaSize);
    if (mantra.isNotEmpty || goal != 108 || malaSize != 108 || haptics) {
      _requirePremium();
    }
    d['active'] = {
      'id': const Uuid().v4(),
      'mantra': mantra.trim(),
      'goal': goal,
      'malaSize': malaSize,
      'haptics': haptics,
      'count': 0,
      'seconds': 0,
      'since': _clock().toIso8601String(),
      'inputs': [],
      'saveHistory': premium(),
    };
  });
  Future<void> increment(String mutation) => _change((d) {
    final active = d['active'] as Map<String, dynamic>?;
    if (active == null || active['since'] == null) {
      throw StateError('Session not running');
    }
    if (mutation.isEmpty || mutation.length > 128) {
      throw ArgumentError('Invalid mutation');
    }
    final inputs = active['inputs'] as List;
    if (inputs.contains(mutation)) return;
    inputs.add(mutation);
    active['count'] = (active['count'] as int) + 1;
  });
  Future<void> pause() => _change((d) {
    final a = d['active'] as Map<String, dynamic>?;
    if (a == null || a['since'] == null) return;
    a['seconds'] = elapsedSeconds;
    a['since'] = null;
  });
  Future<void> resume() => _change((d) {
    final a = d['active'] as Map<String, dynamic>?;
    if (a == null) throw StateError('No active session');
    a['since'] ??= _clock().toIso8601String();
  });
  Future<void> finish() => _change((d) {
    final a = d['active'] as Map<String, dynamic>?;
    if (a == null) return;
    if ((a['count'] as int) > 0 || elapsedSeconds >= 60) {
      final days = d['days'] as List;
      if (!days.contains(_day(_clock()))) days.add(_day(_clock()));
      if (a['saveHistory'] == true) {
        (d['sessions'] as List).add({
          'id': a['id'],
          'mantra': a['mantra'],
          'count': a['count'],
          'seconds': elapsedSeconds,
          'goal': a['goal'],
          'malaSize': a['malaSize'],
          'endedAt': _clock().toIso8601String(),
        });
      }
    }
    d['active'] = null;
  });
  Future<void> saveGoal({
    required String mantra,
    required int goal,
    required int malaSize,
    bool haptics = false,
  }) => _change((d) {
    _requirePremium();
    _validGoal(mantra, goal, malaSize);
    if (mantra.trim().isEmpty) throw ArgumentError('Name required');
    (d['goals'] as List).add({
      'id': const Uuid().v4(),
      'mantra': mantra.trim(),
      'goal': goal,
      'malaSize': malaSize,
      'haptics': haptics,
    });
  });
  Future<void> removeGoal(String id) => _change((d) {
    (d['goals'] as List).removeWhere((g) => (g as Map)['id'] == id);
  });
  Future<void> saveRoutine(PracticeRoutine routine) => _change((d) {
    final list = d['routines'] as List;
    final existing = list.indexWhere((r) => (r as Map)['id'] == routine.id);
    if (routine.id.isEmpty ||
        routine.title.trim().isEmpty ||
        routine.title.length > 120 ||
        routine.steps.isEmpty ||
        routine.steps.length > 20 ||
        routine.steps.any(
          (s) => !['chant', 'listen', 'read', 'reflect'].contains(s),
        ) ||
        routine.weekdays.any((day) => day < 1 || day > 7) ||
        (routine.reminderMinute != null &&
            (routine.reminderMinute! < 0 || routine.reminderMinute! >= 1440))) {
      throw ArgumentError('Invalid routine');
    }
    if ((existing < 0 && list.isNotEmpty) ||
        routine.weekdays.isNotEmpty ||
        routine.reminderMinute != null) {
      _requirePremium();
    }
    if (existing >= 0 &&
        jsonEncode((list[existing] as Map)['steps']) !=
            jsonEncode(routine.steps)) {
      (d['checks'] as Map).removeWhere(
        (key, _) => (key as String).contains('/${routine.id}/'),
      );
    }
    if (existing < 0) {
      list.add(routine.toJson());
    } else {
      list[existing] = routine.toJson();
    }
  });
  Future<void> removeRoutine(String id) => _change((d) {
    (d['routines'] as List).removeWhere((r) => (r as Map)['id'] == id);
  });
  Future<void> toggleStep(String id, int step) => _change((d) {
    final routine = routines.firstWhere((r) => r.id == id);
    if (step < 0 || step >= routine.steps.length) {
      throw ArgumentError('Invalid step');
    }
    final checks = d['checks'] as Map;
    final key = '${_day(_clock())}/$id/$step';
    checks[key] = checks[key] != true;
    if (List.generate(
      routine.steps.length,
      (i) => checks['${_day(_clock())}/$id/$i'] == true,
    ).every((v) => v)) {
      final days = d['days'] as List;
      if (!days.contains(_day(_clock()))) days.add(_day(_clock()));
    }
  });
  Future<void> setQuietHours(int start, int end) => _change((d) {
    if (start < 0 || end < 0 || start >= 1440 || end >= 1440) {
      throw ArgumentError('Invalid quiet hours');
    }
    d['quietStart'] = start;
    d['quietEnd'] = end;
  });
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
