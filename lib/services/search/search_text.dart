import 'package:characters/characters.dart';

/// Text helpers shared by every search (the Swift `SearchText`).
class SearchText {
  const SearchText._();

  static bool _keep(int v) =>
      (v >= 0x61 && v <= 0x7A) ||
      (v >= 0x30 && v <= 0x39) ||
      v == 0x5F ||
      (v >= 0x0900 && v <= 0x097F) ||
      (v >= 0x0980 && v <= 0x09FF) ||
      (v >= 0x0A80 && v <= 0x0AFF) ||
      (v >= 0x0B80 && v <= 0x0BFF) ||
      (v >= 0x0C00 && v <= 0x0C7F);

  /// Lower case; Latin letters, digits and Devanagari, Bengali, Gujarati,
  /// Tamil and Telugu
  /// (with their combining marks) are kept; anything else separates words.
  static String normalize(String text) {
    final out = StringBuffer();
    var lastWasSpace = true;
    for (final rune in text.toLowerCase().runes) {
      if (_keep(rune)) {
        out.writeCharCode(rune);
        lastWasSpace = false;
      } else if (!lastWasSpace) {
        out.write(' ');
        lastWasSpace = true;
      }
    }
    return out.toString().trim();
  }

  static final _digits = RegExp(r'^\d+$');

  /// Optimal-string-alignment Damerau–Levenshtein over displayed characters.
  /// Numeric and short queries stay strict; longer words allow two edits.
  static int? tokenDistance(String query, String candidate) {
    if (query == candidate || candidate.startsWith(query)) return 0;
    final a = query.characters.toList(), b = candidate.characters.toList();
    final maxEdits = a.length < 4 || _digits.hasMatch(query)
        ? 0
        : (a.length < 8 ? 1 : 2);
    if (maxEdits == 0 || (a.length - b.length).abs() > maxEdits) return null;
    final d = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        var value = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        ].reduce((x, y) => x < y ? x : y);
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          final swap = d[i - 2][j - 2] + 1;
          if (swap < value) value = swap;
        }
        d[i][j] = value;
      }
    }
    final distance = d[a.length][b.length];
    return distance <= maxEdits ? distance : null;
  }

  /// True when every letter of [needle] appears in [hay] in order, as in
  /// "ekdsh" and "ekadashi".
  static bool isSubsequence(String needle, String hay) {
    final n = needle.characters.toList();
    var index = 0;
    for (final c in hay.characters) {
      if (index == n.length) break;
      if (c == n[index]) index++;
    }
    return index == n.length;
  }
}
