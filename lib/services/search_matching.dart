import 'package:characters/characters.dart';

/// Keeps Indic letters and combining marks. Punctuation is a token boundary.
String normalizeSearchText(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^\w\s\u0900-\u097F\u0B80-\u0BFF\u0C00-\u0C7F]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Optimal-string-alignment Damerau–Levenshtein over displayed characters.
/// Numeric/short queries remain strict; longer words tolerate up to two edits.
int? searchTokenDistance(String query, String candidate) {
  if (query == candidate || candidate.startsWith(query)) return 0;
  final a = query.characters.toList(), b = candidate.characters.toList();
  final maxEdits = a.length < 4 || RegExp(r'^\d+$').hasMatch(query)
      ? 0
      : a.length < 8
      ? 1
      : 2;
  if (maxEdits == 0 || (a.length - b.length).abs() > maxEdits) return null;
  final d = List.generate(
    a.length + 1,
    (i) => List<int>.filled(b.length + 1, 0),
  );
  for (var i = 0; i <= a.length; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final values = [
        d[i - 1][j] + 1,
        d[i][j - 1] + 1,
        d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      ];
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        values.add(d[i - 2][j - 2] + 1);
      }
      d[i][j] = values.reduce((x, y) => x < y ? x : y);
    }
  }
  final distance = d[a.length][b.length];
  return distance <= maxEdits ? distance : null;
}
