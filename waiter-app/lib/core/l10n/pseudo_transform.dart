/// Pseudo-localisation transform (09 §6.5): every string is rendered about
/// 40 % longer with accented letters, e.g. "Karte scannen" →
/// "[Ķàŕţé šçàññéñ ~~~]", so layouts can be tested for expansion and glyph
/// coverage.
///
/// Placeholder values are never transformed: generated code passes
/// [pseudoMarker]s instead of String arguments and hands the real values to
/// [pseudoLocalize], which substitutes them after the transformation.
library;

const String _markerStart = '\uE000';
const String _markerEnd = '\uE001';

/// Marker standing for the String argument at [index] (Private Use Area
/// characters, never present in real copy).
String pseudoMarker(int index) => '$_markerStart$index$_markerEnd';

/// Letters in Latin-1 / Latin Extended-A only, so the bundled Geist font
/// renders them (brief §5 glyph coverage).
const Map<String, String> _accents = <String, String>{
  'a': 'à', 'c': 'ç', 'd': 'ď', 'e': 'é', 'g': 'ĝ', 'h': 'ĥ', 'i': 'î', //
  'j': 'ĵ', 'k': 'ķ', 'l': 'ļ', 'n': 'ñ', 'o': 'ö', 'r': 'ŕ', 's': 'š', //
  't': 'ţ', 'u': 'û', 'w': 'ŵ', 'y': 'ý', 'z': 'ž', //
  'A': 'À', 'C': 'Ç', 'D': 'Ď', 'E': 'É', 'G': 'Ĝ', 'H': 'Ĥ', 'I': 'Î', //
  'J': 'Ĵ', 'K': 'Ķ', 'L': 'Ļ', 'N': 'Ñ', 'O': 'Ö', 'R': 'Ŕ', 'S': 'Š', //
  'T': 'Ţ', 'U': 'Û', 'W': 'Ŵ', 'Y': 'Ý', 'Z': 'Ž',
};

final RegExp _markerPattern = RegExp('$_markerStart(\\d+)$_markerEnd');

/// Share of added length (09 §6.5: "+40 %").
const double pseudoExpansion = 0.4;

/// Pseudo-localises [text]: accents letters outside markers, substitutes
/// [values] for the markers, then wraps the result as `[… ~~~]` so that the
/// total length is at least 140 % of the real string.
String pseudoLocalize(String text, [List<String> values = const <String>[]]) {
  final StringBuffer accented = StringBuffer();
  int last = 0;
  for (final RegExpMatch m in _markerPattern.allMatches(text)) {
    _accent(text.substring(last, m.start), accented);
    final int index = int.parse(m.group(1)!);
    accented.write(values[index]);
    last = m.end;
  }
  _accent(text.substring(last), accented);
  final String body = accented.toString();
  // "[", " " and "]" count towards the expansion; at least one "~".
  final int target = (body.length * (1 + pseudoExpansion)).ceil();
  final int tildes = target - body.length - 3 < 1
      ? 1
      : target - body.length - 3;
  return '[$body ${'~' * tildes}]';
}

void _accent(String segment, StringBuffer out) {
  for (final int rune in segment.runes) {
    final String ch = String.fromCharCode(rune);
    out.write(_accents[ch] ?? ch);
  }
}
