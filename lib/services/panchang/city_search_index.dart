import '../../l10n/place_names.dart';
import 'panchang_city.dart';

/// Every city with the text a search matches (its name, ASCII name, country
/// code and its name in [language]), prepared once per language: writing
/// 34,152 names in a script at every keystroke froze the keyboard. Results
/// are ranked as in Apple's and Google's city pickers: a name that starts
/// with the text, then a word that does, then any match; popular cities,
/// then shorter names, then catalog order break ties (CitySearchIndex in
/// EkadashiCore, the same ranking).
class CitySearchIndex {
  CitySearchIndex(
    List<PanchangCity> cities,
    this.language, {
    List<String> popularIds = const [],
  }) : _cities = cities,
       _names = [
         for (final city in cities)
           [
             city.label.toLowerCase(),
             city.searchTerms,
             PlaceNames.label(city.label, language).toLowerCase(),
           ],
       ],
       _popular = {
         for (final (rank, id) in popularIds.indexed) 'geonames-$id': rank,
       };

  final String language;
  final List<PanchangCity> _cities;
  final List<List<String>> _names;
  final Map<String, int> _popular;

  /// The text to look for, or null for fewer than two characters (UTF-16
  /// units, as iOS counts).
  static String? query(String text) {
    final q = text.trim().toLowerCase();
    return q.length >= 2 ? q : null;
  }

  List<PanchangCity> search(String text, {int limit = 20}) {
    final q = query(text);
    if (q == null) return const [];
    final found = <(int, int, int, int)>[];
    for (var order = 0; order < _names.length; order++) {
      var tier = 3;
      for (final field in _names[order]) {
        final t = _tier(q, field);
        if (t < tier) tier = t;
        if (tier == 0) break;
      }
      if (tier == 3) continue;
      final city = _cities[order];
      found.add((tier, _popular[city.id] ?? 1 << 30, city.label.length, order));
    }
    found.sort((a, b) {
      for (final (x, y) in [(a.$1, b.$1), (a.$2, b.$2), (a.$3, b.$3)]) {
        if (x != y) return x.compareTo(y);
      }
      return a.$4.compareTo(b.$4);
    });
    return [for (final f in found.take(limit)) _cities[f.$4]];
  }

  /// 0: [field] starts with [needle]; 1: a word in it does; 2: it contains
  /// [needle]; 3: no match.
  static int _tier(String needle, String field) {
    var best = 3;
    var at = field.indexOf(needle);
    while (at >= 0) {
      if (at == 0) return 0;
      final before = field.codeUnitAt(at - 1);
      final tier = before == 0x20 || before == 0x28 || before == 0x2D ? 1 : 2;
      if (tier < best) best = tier;
      at = field.indexOf(needle, at + 1);
    }
    return best;
  }
}
