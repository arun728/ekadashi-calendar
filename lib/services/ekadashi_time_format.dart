import '../l10n/app_language.dart';

/// One inward-rounded Parana display for Home, Panchang, share cards and widgets.
class EkadashiTimeFormat {
  static String window(
    String startIso,
    String endIso, {
    String language = 'en',
  }) {
    final start = DateTime.tryParse(startIso), end = DateTime.tryParse(endIso);
    if (start == null || (endIso.isNotEmpty && end == null)) return '';
    if (end != null && !end.isAfter(start)) return '';
    String secondPart(String iso) =>
        RegExp(r'T\d{2}:\d{2}:(\d{2})').firstMatch(iso)?.group(1) ?? '00';
    final seconds =
        startIso.contains('.') ||
        endIso.contains('.') ||
        secondPart(startIso) != '00' ||
        (endIso.isNotEmpty && secondPart(endIso) != '00');
    final milliseconds =
        end != null &&
        _floor(end.microsecondsSinceEpoch, 1000000) <=
            _ceil(start.microsecondsSinceEpoch, 1000000);
    final first = _boundary(startIso, true, seconds, milliseconds);
    if (end == null) {
      return AppStrings.translate(
        'panchang_after',
        language,
      ).replaceAll('{value0}', first);
    }
    return '$first - ${_boundary(endIso, false, seconds, milliseconds)}';
  }

  static int _floor(int value, int unit) {
    var result = value ~/ unit;
    if (value < 0 && value % unit != 0) result--;
    return result;
  }

  static int _ceil(int value, int unit) =>
      _floor(value, unit) + (value % unit == 0 ? 0 : 1);

  static String _boundary(
    String iso,
    bool up,
    bool seconds,
    bool milliseconds,
  ) {
    final t = iso.indexOf('T');
    if (t < 0) return '';
    final time = iso.substring(t + 1);
    final marker = time.indexOf(RegExp(r'[+\-Z]'));
    final wall = DateTime.parse(
      '${marker < 0 ? iso : iso.substring(0, t + 1 + marker)}Z',
    );
    final unit = milliseconds
        ? 1000
        : seconds
        ? 1000000
        : 60000000;
    final ticks =
        (up
            ? _ceil(wall.microsecondsSinceEpoch, unit)
            : _floor(wall.microsecondsSinceEpoch, unit)) *
        unit;
    final value = DateTime.fromMicrosecondsSinceEpoch(ticks, isUtc: true);
    String two(int number) => number.toString().padLeft(2, '0');
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final fraction = milliseconds
        ? '.${value.millisecond.toString().padLeft(3, '0')}'
        : '';
    return '${two(hour)}:${two(value.minute)}${seconds ? ':${two(value.second)}$fraction' : ''} ${value.hour < 12 ? 'AM' : 'PM'}';
  }
}
