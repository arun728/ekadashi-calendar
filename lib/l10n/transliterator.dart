// Writes a Latin place name in Hindi, Tamil, Telugu, Gujarati or Bengali
// script by sound ("Toronto" → "टोरोंटो"), for the cities the place-name
// table does not cover, so no Latin letters appear outside English.
// The same algorithm as Transliterator.swift (iOS); the shared fixture
// test/fixtures/transliteration.json keeps them identical.

/// [name] in [language]'s script; unchanged in English or an unknown language.
String transliterate(String name, String language) {
  final script = _scripts[language];
  if (script == null) return name;
  final out = StringBuffer();
  final word = StringBuffer();
  void flush() {
    if (word.isNotEmpty) out.write(_render(_units(word.toString()), script));
    word.clear();
  }

  for (final ch in _fold(name).split('')) {
    if (_asciiLetter.hasMatch(ch)) {
      word.write(ch);
    } else {
      flush();
      if (_number.hasMatch(ch) || ' -.,()/&'.contains(ch)) out.write(ch);
    }
  }
  flush();
  return out.toString().replaceAll('  ', ' ').trim();
}

final _asciiLetter = RegExp(r'^[a-z]$');
final _number = RegExp(r'^\p{N}$', unicode: true);

const _special = {
  'ə': 'e', 'Ə': 'e', 'ı': 'i', 'ł': 'l', 'Ł': 'l', 'ø': 'o', 'Ø': 'o', //
  'æ': 'ae', 'Æ': 'ae', 'ß': 'ss', 'đ': 'd', 'Đ': 'd', 'ħ': 'h', 'Ħ': 'h', //
  'þ': 'th', 'Þ': 'th', 'ŋ': 'ng', 'œ': 'oe', 'Œ': 'oe', 'ð': 'd',
};

/// Canonical decomposition with the combining marks removed (Unicode NFD of
/// the Latin letters used in place names), generated from Python's
/// unicodedata for U+00C0–U+02FF, U+1E00–U+1EFF and the catalog's letters.
const _decomposed = <String, String>{
  '\u{c0}': 'A',
  '\u{c1}': 'A',
  '\u{c2}': 'A',
  '\u{c3}': 'A',
  '\u{c4}': 'A',
  '\u{c5}': 'A',
  '\u{c7}': 'C',
  '\u{c8}': 'E',
  '\u{c9}': 'E',
  '\u{ca}': 'E',
  '\u{cb}': 'E',
  '\u{cc}': 'I',
  '\u{cd}': 'I',
  '\u{ce}': 'I',
  '\u{cf}': 'I',
  '\u{d1}': 'N',
  '\u{d2}': 'O',
  '\u{d3}': 'O',
  '\u{d4}': 'O',
  '\u{d5}': 'O',
  '\u{d6}': 'O',
  '\u{d9}': 'U',
  '\u{da}': 'U',
  '\u{db}': 'U',
  '\u{dc}': 'U',
  '\u{dd}': 'Y',
  '\u{e0}': 'a',
  '\u{e1}': 'a',
  '\u{e2}': 'a',
  '\u{e3}': 'a',
  '\u{e4}': 'a',
  '\u{e5}': 'a',
  '\u{e7}': 'c',
  '\u{e8}': 'e',
  '\u{e9}': 'e',
  '\u{ea}': 'e',
  '\u{eb}': 'e',
  '\u{ec}': 'i',
  '\u{ed}': 'i',
  '\u{ee}': 'i',
  '\u{ef}': 'i',
  '\u{f1}': 'n',
  '\u{f2}': 'o',
  '\u{f3}': 'o',
  '\u{f4}': 'o',
  '\u{f5}': 'o',
  '\u{f6}': 'o',
  '\u{f9}': 'u',
  '\u{fa}': 'u',
  '\u{fb}': 'u',
  '\u{fc}': 'u',
  '\u{fd}': 'y',
  '\u{ff}': 'y',
  '\u{100}': 'A',
  '\u{101}': 'a',
  '\u{102}': 'A',
  '\u{103}': 'a',
  '\u{104}': 'A',
  '\u{105}': 'a',
  '\u{106}': 'C',
  '\u{107}': 'c',
  '\u{108}': 'C',
  '\u{109}': 'c',
  '\u{10a}': 'C',
  '\u{10b}': 'c',
  '\u{10c}': 'C',
  '\u{10d}': 'c',
  '\u{10e}': 'D',
  '\u{10f}': 'd',
  '\u{112}': 'E',
  '\u{113}': 'e',
  '\u{114}': 'E',
  '\u{115}': 'e',
  '\u{116}': 'E',
  '\u{117}': 'e',
  '\u{118}': 'E',
  '\u{119}': 'e',
  '\u{11a}': 'E',
  '\u{11b}': 'e',
  '\u{11c}': 'G',
  '\u{11d}': 'g',
  '\u{11e}': 'G',
  '\u{11f}': 'g',
  '\u{120}': 'G',
  '\u{121}': 'g',
  '\u{122}': 'G',
  '\u{123}': 'g',
  '\u{124}': 'H',
  '\u{125}': 'h',
  '\u{128}': 'I',
  '\u{129}': 'i',
  '\u{12a}': 'I',
  '\u{12b}': 'i',
  '\u{12c}': 'I',
  '\u{12d}': 'i',
  '\u{12e}': 'I',
  '\u{12f}': 'i',
  '\u{130}': 'I',
  '\u{134}': 'J',
  '\u{135}': 'j',
  '\u{136}': 'K',
  '\u{137}': 'k',
  '\u{139}': 'L',
  '\u{13a}': 'l',
  '\u{13b}': 'L',
  '\u{13c}': 'l',
  '\u{13d}': 'L',
  '\u{13e}': 'l',
  '\u{143}': 'N',
  '\u{144}': 'n',
  '\u{145}': 'N',
  '\u{146}': 'n',
  '\u{147}': 'N',
  '\u{148}': 'n',
  '\u{14c}': 'O',
  '\u{14d}': 'o',
  '\u{14e}': 'O',
  '\u{14f}': 'o',
  '\u{150}': 'O',
  '\u{151}': 'o',
  '\u{154}': 'R',
  '\u{155}': 'r',
  '\u{156}': 'R',
  '\u{157}': 'r',
  '\u{158}': 'R',
  '\u{159}': 'r',
  '\u{15a}': 'S',
  '\u{15b}': 's',
  '\u{15c}': 'S',
  '\u{15d}': 's',
  '\u{15e}': 'S',
  '\u{15f}': 's',
  '\u{160}': 'S',
  '\u{161}': 's',
  '\u{162}': 'T',
  '\u{163}': 't',
  '\u{164}': 'T',
  '\u{165}': 't',
  '\u{168}': 'U',
  '\u{169}': 'u',
  '\u{16a}': 'U',
  '\u{16b}': 'u',
  '\u{16c}': 'U',
  '\u{16d}': 'u',
  '\u{16e}': 'U',
  '\u{16f}': 'u',
  '\u{170}': 'U',
  '\u{171}': 'u',
  '\u{172}': 'U',
  '\u{173}': 'u',
  '\u{174}': 'W',
  '\u{175}': 'w',
  '\u{176}': 'Y',
  '\u{177}': 'y',
  '\u{178}': 'Y',
  '\u{179}': 'Z',
  '\u{17a}': 'z',
  '\u{17b}': 'Z',
  '\u{17c}': 'z',
  '\u{17d}': 'Z',
  '\u{17e}': 'z',
  '\u{1a0}': 'O',
  '\u{1a1}': 'o',
  '\u{1af}': 'U',
  '\u{1b0}': 'u',
  '\u{1cd}': 'A',
  '\u{1ce}': 'a',
  '\u{1cf}': 'I',
  '\u{1d0}': 'i',
  '\u{1d1}': 'O',
  '\u{1d2}': 'o',
  '\u{1d3}': 'U',
  '\u{1d4}': 'u',
  '\u{1d5}': 'U',
  '\u{1d6}': 'u',
  '\u{1d7}': 'U',
  '\u{1d8}': 'u',
  '\u{1d9}': 'U',
  '\u{1da}': 'u',
  '\u{1db}': 'U',
  '\u{1dc}': 'u',
  '\u{1de}': 'A',
  '\u{1df}': 'a',
  '\u{1e0}': 'A',
  '\u{1e1}': 'a',
  '\u{1e2}': '\u{c6}',
  '\u{1e3}': '\u{e6}',
  '\u{1e6}': 'G',
  '\u{1e7}': 'g',
  '\u{1e8}': 'K',
  '\u{1e9}': 'k',
  '\u{1ea}': 'O',
  '\u{1eb}': 'o',
  '\u{1ec}': 'O',
  '\u{1ed}': 'o',
  '\u{1ee}': '\u{1b7}',
  '\u{1ef}': '\u{292}',
  '\u{1f0}': 'j',
  '\u{1f4}': 'G',
  '\u{1f5}': 'g',
  '\u{1f8}': 'N',
  '\u{1f9}': 'n',
  '\u{1fa}': 'A',
  '\u{1fb}': 'a',
  '\u{1fc}': '\u{c6}',
  '\u{1fd}': '\u{e6}',
  '\u{1fe}': '\u{d8}',
  '\u{1ff}': '\u{f8}',
  '\u{200}': 'A',
  '\u{201}': 'a',
  '\u{202}': 'A',
  '\u{203}': 'a',
  '\u{204}': 'E',
  '\u{205}': 'e',
  '\u{206}': 'E',
  '\u{207}': 'e',
  '\u{208}': 'I',
  '\u{209}': 'i',
  '\u{20a}': 'I',
  '\u{20b}': 'i',
  '\u{20c}': 'O',
  '\u{20d}': 'o',
  '\u{20e}': 'O',
  '\u{20f}': 'o',
  '\u{210}': 'R',
  '\u{211}': 'r',
  '\u{212}': 'R',
  '\u{213}': 'r',
  '\u{214}': 'U',
  '\u{215}': 'u',
  '\u{216}': 'U',
  '\u{217}': 'u',
  '\u{218}': 'S',
  '\u{219}': 's',
  '\u{21a}': 'T',
  '\u{21b}': 't',
  '\u{21e}': 'H',
  '\u{21f}': 'h',
  '\u{226}': 'A',
  '\u{227}': 'a',
  '\u{228}': 'E',
  '\u{229}': 'e',
  '\u{22a}': 'O',
  '\u{22b}': 'o',
  '\u{22c}': 'O',
  '\u{22d}': 'o',
  '\u{22e}': 'O',
  '\u{22f}': 'o',
  '\u{230}': 'O',
  '\u{231}': 'o',
  '\u{232}': 'Y',
  '\u{233}': 'y',
  '\u{303}': '',
  '\u{304}': '',
  '\u{307}': '',
  '\u{308}': '',
  '\u{327}': '',
  '\u{331}': '',
  '\u{1e00}': 'A',
  '\u{1e01}': 'a',
  '\u{1e02}': 'B',
  '\u{1e03}': 'b',
  '\u{1e04}': 'B',
  '\u{1e05}': 'b',
  '\u{1e06}': 'B',
  '\u{1e07}': 'b',
  '\u{1e08}': 'C',
  '\u{1e09}': 'c',
  '\u{1e0a}': 'D',
  '\u{1e0b}': 'd',
  '\u{1e0c}': 'D',
  '\u{1e0d}': 'd',
  '\u{1e0e}': 'D',
  '\u{1e0f}': 'd',
  '\u{1e10}': 'D',
  '\u{1e11}': 'd',
  '\u{1e12}': 'D',
  '\u{1e13}': 'd',
  '\u{1e14}': 'E',
  '\u{1e15}': 'e',
  '\u{1e16}': 'E',
  '\u{1e17}': 'e',
  '\u{1e18}': 'E',
  '\u{1e19}': 'e',
  '\u{1e1a}': 'E',
  '\u{1e1b}': 'e',
  '\u{1e1c}': 'E',
  '\u{1e1d}': 'e',
  '\u{1e1e}': 'F',
  '\u{1e1f}': 'f',
  '\u{1e20}': 'G',
  '\u{1e21}': 'g',
  '\u{1e22}': 'H',
  '\u{1e23}': 'h',
  '\u{1e24}': 'H',
  '\u{1e25}': 'h',
  '\u{1e26}': 'H',
  '\u{1e27}': 'h',
  '\u{1e28}': 'H',
  '\u{1e29}': 'h',
  '\u{1e2a}': 'H',
  '\u{1e2b}': 'h',
  '\u{1e2c}': 'I',
  '\u{1e2d}': 'i',
  '\u{1e2e}': 'I',
  '\u{1e2f}': 'i',
  '\u{1e30}': 'K',
  '\u{1e31}': 'k',
  '\u{1e32}': 'K',
  '\u{1e33}': 'k',
  '\u{1e34}': 'K',
  '\u{1e35}': 'k',
  '\u{1e36}': 'L',
  '\u{1e37}': 'l',
  '\u{1e38}': 'L',
  '\u{1e39}': 'l',
  '\u{1e3a}': 'L',
  '\u{1e3b}': 'l',
  '\u{1e3c}': 'L',
  '\u{1e3d}': 'l',
  '\u{1e3e}': 'M',
  '\u{1e3f}': 'm',
  '\u{1e40}': 'M',
  '\u{1e41}': 'm',
  '\u{1e42}': 'M',
  '\u{1e43}': 'm',
  '\u{1e44}': 'N',
  '\u{1e45}': 'n',
  '\u{1e46}': 'N',
  '\u{1e47}': 'n',
  '\u{1e48}': 'N',
  '\u{1e49}': 'n',
  '\u{1e4a}': 'N',
  '\u{1e4b}': 'n',
  '\u{1e4c}': 'O',
  '\u{1e4d}': 'o',
  '\u{1e4e}': 'O',
  '\u{1e4f}': 'o',
  '\u{1e50}': 'O',
  '\u{1e51}': 'o',
  '\u{1e52}': 'O',
  '\u{1e53}': 'o',
  '\u{1e54}': 'P',
  '\u{1e55}': 'p',
  '\u{1e56}': 'P',
  '\u{1e57}': 'p',
  '\u{1e58}': 'R',
  '\u{1e59}': 'r',
  '\u{1e5a}': 'R',
  '\u{1e5b}': 'r',
  '\u{1e5c}': 'R',
  '\u{1e5d}': 'r',
  '\u{1e5e}': 'R',
  '\u{1e5f}': 'r',
  '\u{1e60}': 'S',
  '\u{1e61}': 's',
  '\u{1e62}': 'S',
  '\u{1e63}': 's',
  '\u{1e64}': 'S',
  '\u{1e65}': 's',
  '\u{1e66}': 'S',
  '\u{1e67}': 's',
  '\u{1e68}': 'S',
  '\u{1e69}': 's',
  '\u{1e6a}': 'T',
  '\u{1e6b}': 't',
  '\u{1e6c}': 'T',
  '\u{1e6d}': 't',
  '\u{1e6e}': 'T',
  '\u{1e6f}': 't',
  '\u{1e70}': 'T',
  '\u{1e71}': 't',
  '\u{1e72}': 'U',
  '\u{1e73}': 'u',
  '\u{1e74}': 'U',
  '\u{1e75}': 'u',
  '\u{1e76}': 'U',
  '\u{1e77}': 'u',
  '\u{1e78}': 'U',
  '\u{1e79}': 'u',
  '\u{1e7a}': 'U',
  '\u{1e7b}': 'u',
  '\u{1e7c}': 'V',
  '\u{1e7d}': 'v',
  '\u{1e7e}': 'V',
  '\u{1e7f}': 'v',
  '\u{1e80}': 'W',
  '\u{1e81}': 'w',
  '\u{1e82}': 'W',
  '\u{1e83}': 'w',
  '\u{1e84}': 'W',
  '\u{1e85}': 'w',
  '\u{1e86}': 'W',
  '\u{1e87}': 'w',
  '\u{1e88}': 'W',
  '\u{1e89}': 'w',
  '\u{1e8a}': 'X',
  '\u{1e8b}': 'x',
  '\u{1e8c}': 'X',
  '\u{1e8d}': 'x',
  '\u{1e8e}': 'Y',
  '\u{1e8f}': 'y',
  '\u{1e90}': 'Z',
  '\u{1e91}': 'z',
  '\u{1e92}': 'Z',
  '\u{1e93}': 'z',
  '\u{1e94}': 'Z',
  '\u{1e95}': 'z',
  '\u{1e96}': 'h',
  '\u{1e97}': 't',
  '\u{1e98}': 'w',
  '\u{1e99}': 'y',
  '\u{1e9b}': '\u{17f}',
  '\u{1ea0}': 'A',
  '\u{1ea1}': 'a',
  '\u{1ea2}': 'A',
  '\u{1ea3}': 'a',
  '\u{1ea4}': 'A',
  '\u{1ea5}': 'a',
  '\u{1ea6}': 'A',
  '\u{1ea7}': 'a',
  '\u{1ea8}': 'A',
  '\u{1ea9}': 'a',
  '\u{1eaa}': 'A',
  '\u{1eab}': 'a',
  '\u{1eac}': 'A',
  '\u{1ead}': 'a',
  '\u{1eae}': 'A',
  '\u{1eaf}': 'a',
  '\u{1eb0}': 'A',
  '\u{1eb1}': 'a',
  '\u{1eb2}': 'A',
  '\u{1eb3}': 'a',
  '\u{1eb4}': 'A',
  '\u{1eb5}': 'a',
  '\u{1eb6}': 'A',
  '\u{1eb7}': 'a',
  '\u{1eb8}': 'E',
  '\u{1eb9}': 'e',
  '\u{1eba}': 'E',
  '\u{1ebb}': 'e',
  '\u{1ebc}': 'E',
  '\u{1ebd}': 'e',
  '\u{1ebe}': 'E',
  '\u{1ebf}': 'e',
  '\u{1ec0}': 'E',
  '\u{1ec1}': 'e',
  '\u{1ec2}': 'E',
  '\u{1ec3}': 'e',
  '\u{1ec4}': 'E',
  '\u{1ec5}': 'e',
  '\u{1ec6}': 'E',
  '\u{1ec7}': 'e',
  '\u{1ec8}': 'I',
  '\u{1ec9}': 'i',
  '\u{1eca}': 'I',
  '\u{1ecb}': 'i',
  '\u{1ecc}': 'O',
  '\u{1ecd}': 'o',
  '\u{1ece}': 'O',
  '\u{1ecf}': 'o',
  '\u{1ed0}': 'O',
  '\u{1ed1}': 'o',
  '\u{1ed2}': 'O',
  '\u{1ed3}': 'o',
  '\u{1ed4}': 'O',
  '\u{1ed5}': 'o',
  '\u{1ed6}': 'O',
  '\u{1ed7}': 'o',
  '\u{1ed8}': 'O',
  '\u{1ed9}': 'o',
  '\u{1eda}': 'O',
  '\u{1edb}': 'o',
  '\u{1edc}': 'O',
  '\u{1edd}': 'o',
  '\u{1ede}': 'O',
  '\u{1edf}': 'o',
  '\u{1ee0}': 'O',
  '\u{1ee1}': 'o',
  '\u{1ee2}': 'O',
  '\u{1ee3}': 'o',
  '\u{1ee4}': 'U',
  '\u{1ee5}': 'u',
  '\u{1ee6}': 'U',
  '\u{1ee7}': 'u',
  '\u{1ee8}': 'U',
  '\u{1ee9}': 'u',
  '\u{1eea}': 'U',
  '\u{1eeb}': 'u',
  '\u{1eec}': 'U',
  '\u{1eed}': 'u',
  '\u{1eee}': 'U',
  '\u{1eef}': 'u',
  '\u{1ef0}': 'U',
  '\u{1ef1}': 'u',
  '\u{1ef2}': 'Y',
  '\u{1ef3}': 'y',
  '\u{1ef4}': 'Y',
  '\u{1ef5}': 'y',
  '\u{1ef6}': 'Y',
  '\u{1ef7}': 'y',
  '\u{1ef8}': 'Y',
  '\u{1ef9}': 'y',
};

final _marks = RegExp('[\u0300-\u036F]');
const _apostrophes = "'’‘ʻʼ`";

/// Lowercase ASCII letters, with accents and apostrophes removed.
String _fold(String text) {
  final mapped = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    final special = _special[ch];
    if (special != null) {
      mapped.write(special);
    } else {
      mapped.write(_decomposed[ch] ?? ch);
    }
  }
  final lower = mapped.toString().toLowerCase().replaceAll(_marks, '');
  return [
    for (final rune in lower.runes)
      if (!_apostrophes.contains(String.fromCharCode(rune)))
        String.fromCharCode(rune),
  ].join();
}

const _vowelLetters = {'a', 'e', 'i', 'o', 'u'};
const _vowels = {'a', 'aa', 'i', 'ii', 'u', 'uu', 'e', 'ai', 'o', 'au'};

/// Longest match first.
const _clusters = <(String, List<String>)>[
  ('chr', ['k', 'r']), ('tch', ['ch']), ('sch', ['sh']), ('chh', ['ch']), //
  ('ch', ['ch']), ('sh', ['sh']), ('zh', ['j']), ('th', ['th']), //
  ('dh', ['dh']), ('kh', ['kh']), ('gh', ['g']), ('bh', ['bh']), //
  ('ph', ['f']), ('jh', ['jh']), ('ck', ['k']), ('qu', ['k', 'v']), //
  ('x', ['k', 's']), ('aa', ['aa']), ('ee', ['ii']), ('ea', ['ii']), //
  ('oo', ['uu']), ('ou', ['u']), ('ow', ['o']), ('ai', ['ai']), //
  ('ay', ['e']), ('au', ['au']), ('aw', ['o']), ('ei', ['e']), //
  ('ey', ['e']), ('ie', ['ii']), ('oa', ['o']), ('oe', ['o']), //
  ('ue', ['uu']),
];

const _singles = {
  'a': 'a', 'e': 'e', 'i': 'i', 'o': 'o', 'u': 'u', 'b': 'b', 'd': 'D', //
  'f': 'f', 'g': 'g', 'h': 'h', 'j': 'j', 'k': 'k', 'l': 'l', 'm': 'm', //
  'n': 'n', 'p': 'p', 'q': 'k', 'r': 'r', 's': 's', 't': 'T', 'v': 'v', //
  'w': 'v', 'z': 'z',
};

List<String> _units(String word) {
  final letters = word.split('');
  // A silent final "e" after a consonant ("Melbourne").
  if (letters.length >= 5 &&
      letters.last == 'e' &&
      !_vowelLetters.contains(letters[letters.length - 2])) {
    letters.removeLast();
  }
  final result = <String>[];
  var i = 0;
  while (i < letters.length) {
    final ch = letters[i];
    // Doubled consonants sound once ("Seattle").
    if (i > 0 &&
        letters[i - 1] == ch &&
        !_vowelLetters.contains(ch) &&
        ch != 'y') {
      i += 1;
      continue;
    }
    // A final "gh" is silent ("Raleigh"); "g" is soft before e, i, y ("George").
    if (ch == 'g' &&
        i + 1 < letters.length &&
        letters[i + 1] == 'h' &&
        i + 2 == letters.length) {
      i += 2;
      continue;
    }
    if (ch == 'g' &&
        i + 1 < letters.length &&
        'eiy'.contains(letters[i + 1]) &&
        (i > 0 || letters.length > 3)) {
      result.add('j');
      i += 1;
      continue;
    }
    // A silent "h" after a vowel with no vowel after it ("John", "Sharjah").
    if (ch == 'h' &&
        i > 0 &&
        _vowelLetters.contains(letters[i - 1]) &&
        (i + 1 == letters.length || !_vowelLetters.contains(letters[i + 1]))) {
      i += 1;
      continue;
    }
    (String, List<String>)? cluster;
    for (final candidate in _clusters) {
      if (!_matches(candidate.$1, letters, i)) continue;
      // "aw", "ay", "ow", "ey" glide into a following vowel ("Ottawa").
      final pattern = candidate.$1;
      if ('wy'.contains(pattern[pattern.length - 1]) &&
          pattern.length == 2 &&
          i + 2 < letters.length &&
          _vowelLetters.contains(letters[i + 2])) {
        continue;
      }
      cluster = candidate;
      break;
    }
    if (cluster != null) {
      result.addAll(cluster.$2);
      i += cluster.$1.length;
      continue;
    }
    if (ch == 'c') {
      final next = i + 1 < letters.length ? letters[i + 1] : ' ';
      result.add('eiy'.contains(next) ? 's' : 'k');
    } else if (ch == 'y') {
      // A consonant before a vowel ("York"), else a vowel ("Sydney").
      final next = i + 1 < letters.length ? letters[i + 1] : ' ';
      result.add(_vowelLetters.contains(next) ? 'y' : 'ii');
    } else if (_singles[ch] case final sound?) {
      result.add(sound);
    }
    i += 1;
  }
  // Word-final "a" is long in place names ("Agra"); an unstressed final
  // "-on", "-en", "-er" is a short a ("Boston", "Manchester"); "n" before a
  // consonant is a nasal sign.
  if (result.length > 1 && result.last == 'a') result[result.length - 1] = 'aa';
  if (result.length > 1 && result.last == 'i') result[result.length - 1] = 'ii';
  if (letters.length >= 5 &&
      result.length >= 3 &&
      !_vowels.contains(result[result.length - 1]) &&
      ['o', 'e'].contains(result[result.length - 2]) &&
      !_vowels.contains(result[result.length - 3])) {
    result[result.length - 2] = 'a';
  }
  for (var k = 0; k < result.length; k++) {
    if (result[k] == 'n' &&
        k + 1 < result.length &&
        !_vowels.contains(result[k + 1]) &&
        k > 0 &&
        _vowels.contains(result[k - 1])) {
      result[k] = 'N';
    }
  }
  // A glide between two vowels: "Miami" (i·y·aa), "Kuala" (u·v·a).
  final glided = <String>[];
  for (final sound in result) {
    if (glided.isNotEmpty &&
        _vowels.contains(glided.last) &&
        _vowels.contains(sound)) {
      final last = glided.last;
      if (['i', 'ii', 'e'].contains(last)) {
        glided.add('y');
      } else if (['u', 'uu', 'o'].contains(last) &&
          ['a', 'aa'].contains(sound)) {
        glided.add('v');
      }
    }
    glided.add(sound);
  }
  return glided;
}

bool _matches(String pattern, List<String> letters, int at) {
  if (at + pattern.length > letters.length) return false;
  for (var k = 0; k < pattern.length; k++) {
    if (letters[at + k] != pattern[k]) return false;
  }
  return true;
}

class _Script {
  const _Script({
    required this.consonants,
    required this.independent,
    required this.signs,
    required this.virama,
    required this.nasal,
    required this.finalVirama,
    this.initialN,
    this.initialY,
    this.nasalBefore = const {},
  });
  final Map<String, String> consonants;
  final Map<String, String> independent;
  final Map<String, String> signs;
  final String virama;
  final String nasal;

  /// Tamil and Telugu close a final consonant with the virama.
  final bool finalVirama;

  /// Tamil writes a word-initial n as ந and a later one as ன.
  final String? initialN;

  /// Bengali writes a word-initial y as ইয় ("York").
  final String? initialY;

  /// Tamil's nasal letter of the following consonant's group.
  final Map<String, String> nasalBefore;
}

String _render(List<String> sounds, _Script s) {
  final out = StringBuffer();
  var i = 0;
  while (i < sounds.length) {
    final sound = sounds[i];
    if (sound == 'N') {
      final next = i + 1 < sounds.length ? sounds[i + 1] : '';
      out.write(s.nasalBefore[next] ?? s.nasal);
    } else if (_vowels.contains(sound)) {
      out.write(s.independent[sound] ?? '');
    } else {
      var letter = s.consonants[sound] ?? '';
      if (sound == 'n' && i == 0 && s.initialN != null) letter = s.initialN!;
      if (sound == 'y' && i == 0 && s.initialY != null) letter = s.initialY!;
      out.write(letter);
      final next = i + 1 < sounds.length ? sounds[i + 1] : null;
      if (next != null && _vowels.contains(next)) {
        if (next != 'a') out.write(s.signs[next] ?? '');
        i += 1;
      } else if (next != null || s.finalVirama) {
        // A cluster, or a final consonant in Tamil and Telugu.
        out.write(s.virama);
      }
    }
    i += 1;
  }
  return out.toString();
}

Map<String, String> _table(String keys, String values) =>
    Map.fromIterables(keys.split(' '), values.split(' '));

const _consonantKeys =
    'k kh g gh ch j jh T Th D Dh t th d dh n p f b bh m y r l v sh s h z';
const _vowelKeys = 'a aa i ii u uu e ai o au';
const _signKeys = 'aa i ii u uu e ai o au';

final _scripts = <String, _Script>{
  'hi': _Script(
    consonants: _table(
      _consonantKeys,
      'क ख ग घ च ज झ ट ठ ड ढ त थ द ध न प फ़ ब भ म य र ल व श स ह ज़',
    ),
    independent: _table(_vowelKeys, 'अ आ इ ई उ ऊ ए ऐ ओ औ'),
    signs: _table(_signKeys, 'ा ि ी ु ू े ै ो ौ'),
    virama: '्',
    nasal: 'ं',
    finalVirama: false,
  ),
  'gu': _Script(
    consonants: _table(
      _consonantKeys,
      'ક ખ ગ ઘ ચ જ ઝ ટ ઠ ડ ઢ ત થ દ ધ ન પ ફ બ ભ મ ય ર લ વ શ સ હ ઝ',
    ),
    independent: _table(_vowelKeys, 'અ આ ઇ ઈ ઉ ઊ એ ઐ ઓ ઔ'),
    signs: _table(_signKeys, 'ા િ ી ુ ૂ ે ૈ ો ૌ'),
    virama: '્',
    nasal: 'ં',
    finalVirama: false,
  ),
  'bn': _Script(
    consonants: _table(
      _consonantKeys,
      'ক খ গ ঘ চ জ ঝ ট ঠ ড ঢ ত থ দ ধ ন প ফ ব ভ ম য় র ল ভ শ স হ জ',
    ),
    independent: _table(_vowelKeys, 'অ আ ই ঈ উ ঊ এ ঐ ও ঔ'),
    signs: _table(_signKeys, 'া ি ী ু ূ ে ৈ ো ৌ'),
    virama: '্',
    nasal: 'ং',
    finalVirama: false,
    initialY: 'ইয়',
  ),
  'te': _Script(
    consonants: _table(
      _consonantKeys,
      'క ఖ గ ఘ చ జ ఝ ట ఠ డ ఢ త థ ద ధ న ప ఫ బ భ మ య ర ల వ శ స హ జ',
    ),
    independent: _table(_vowelKeys, 'అ ఆ ఇ ఈ ఉ ఊ ఏ ఐ ఓ ఔ'),
    signs: _table(_signKeys, 'ా ి ీ ు ూ ే ై ో ౌ'),
    virama: '్',
    nasal: 'ం',
    finalVirama: true,
  ),
  'ta': _Script(
    consonants: _table(
      _consonantKeys,
      'க க க க ச ஜ ஜ ட ட ட ட த த த த ன ப ப ப ப ம ய ர ல வ ஷ ஸ ஹ ஜ',
    ),
    independent: _table(_vowelKeys, 'அ ஆ இ ஈ உ ஊ ஏ ஐ ஓ ஔ'),
    signs: _table(_signKeys, 'ா ி ீ ு ூ ே ை ோ ௌ'),
    virama: '்',
    nasal: 'ன்',
    finalVirama: true,
    initialN: 'ந',
    nasalBefore: _table(
      'k kh g gh ch j jh T Th D Dh t th d dh p f b bh m',
      'ங் ங் ங் ங் ஞ் ஞ் ஞ் ண் ண் ண் ண் ந் ந் ந் ந் ம் ம் ம் ம் ம்',
    ),
  ),
};
