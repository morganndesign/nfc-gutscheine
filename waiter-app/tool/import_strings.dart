// String import pipeline for GiftCard Waiter.
//
// Usage (from the waiter-app directory):
//   dart run tool/import_strings.dart           # (re)write all outputs
//   dart run tool/import_strings.dart --check   # verify outputs are up to date
//
// Source: docs/design/waiter-app/12-ui-copy-and-error-messages.md, master
// string table §5.1–§5.21 (12 §5 owns the wording; 09 §6.5 owns the format).
//
// Outputs:
//   lib/l10n/app_en.arb (template, with @metadata), app_de.arb, app_bs.arb,
//   lib/l10n/app_hr.arb and app_sr.arb (generated copies of BHS, 09 §6.5),
//   lib/core/l10n/pseudo_app_localizations.g.dart (pseudo-localisation, 09 §6.5),
//   ios/Runner/{de,en,bs,hr,sr,sr-Latn}.lproj/InfoPlist.strings (12 §5.21,
//   09 §7.3).
//
// The script fails loudly (exit code 1, message on stderr) on a malformed
// row, a duplicate key, a missing language cell, invalid ICU, a placeholder
// mismatch across languages, an alias implemented as a key, or a key count
// that differs from the count stated in 12 §5.22.

import 'dart:convert';
import 'dart:io';

/// Path of the master document, relative to the waiter-app directory.
const String masterDocPath =
    '../docs/design/waiter-app/12-ui-copy-and-error-messages.md';

/// UI languages of the table, in column order (12 §1.2).
const List<String> tableLanguages = <String>['de', 'en', 'bhs'];

/// ARB locale per table language (09 §6.5).
const Map<String, String> arbLocaleOf = <String, String>{
  'de': 'de',
  'en': 'en',
  'bhs': 'bs',
};

/// Generated copies of the BHS file (09 §6.5).
const List<String> bhsCopyLocales = <String>['hr', 'sr'];

/// iOS lproj folders for the OS usage strings (09 §6.5 "Platform strings").
const Map<String, String> lprojLanguage = <String, String>{
  'de': 'de',
  'en': 'en',
  'bs': 'bhs',
  'hr': 'bhs',
  'sr': 'bhs',
  'sr-Latn': 'bhs',
};

/// §5.21 spec key → Info.plist key (09 §7.3).
const Map<String, String> infoPlistKeyOf = <String, String>{
  'camera.purpose': 'NSCameraUsageDescription',
  'faceId.purpose': 'NSFaceIDUsageDescription',
  'nfc.purpose': 'NFCReaderUsageDescription',
};

/// Placeholders that are integers (12 §4.2: `{count}`, `{seconds}`,
/// `{minutes}`, `{n}`). Any placeholder used as a plural argument is an
/// integer as well (e.g. `{euros}` in `a11y.spokenAmount`).
const Set<String> integerPlaceholders = <String>{
  'count',
  'seconds',
  'minutes',
  'n',
};

/// Required plural categories per table language (12 §1.9).
const Map<String, Set<String>> pluralCategories = <String, Set<String>>{
  'de': <String>{'one', 'other'},
  'en': <String>{'one', 'other'},
  'bhs': <String>{'one', 'few', 'other'},
};

/// Thrown for every problem in the source table. Always fatal.
class ImportError implements Exception {
  ImportError(this.message);

  final String message;

  @override
  String toString() => 'import_strings: $message';
}

/// One row of the master string table.
class StringEntry {
  StringEntry({
    required this.specKey,
    required this.section,
    required this.line,
    required this.texts,
    required this.limit,
    required this.limitLabel,
    required this.notes,
  });

  /// Spec key as written in 12, e.g. `charge.redeemFull`.
  final String specKey;

  /// Section number, e.g. `5.8`.
  final String section;

  /// 1-based line number in the source document.
  final int line;

  /// Normalised message per table language (`de`, `en`, `bhs`).
  final Map<String, String> texts;

  /// Content of the Max (or Politeness) column, if the section has one.
  final String? limit;

  /// Header of that column (`Max` or `Politeness`).
  final String? limitLabel;

  /// Notes column with markdown removed.
  final String notes;

  /// ARB identifier (09 §6.5 key mapping).
  String get arbKey => arbKeyOf(specKey);

  /// Placeholder names in order of first appearance in the EN text, with
  /// the Dart type used in the ARB metadata.
  late final Map<String, String> placeholders;
}

/// Converts a spec key to its ARB identifier (09 §6.5): remove dots,
/// lowerCamelCase. `charge.redeemFull` → `chargeRedeemFull`,
/// `ios.sheet.alert` → `iosSheetAlert`, `getManager` → `getManager`.
String arbKeyOf(String specKey) {
  final List<String> parts = specKey.split('.');
  final StringBuffer out = StringBuffer(parts.first);
  for (final String part in parts.skip(1)) {
    out.write(part[0].toUpperCase());
    out.write(part.substring(1));
  }
  return out.toString();
}

// ---------------------------------------------------------------------------
// Markdown table parsing
// ---------------------------------------------------------------------------

/// Splits a markdown table row into trimmed cells. `\|` is an escaped pipe
/// inside a cell; pipes inside backtick code spans are literal as well.
List<String> splitRow(String line, int lineNo) {
  final String trimmed = line.trim();
  if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) {
    throw ImportError('line $lineNo: table row must start and end with "|"');
  }
  final List<String> cells = <String>[];
  final StringBuffer cell = StringBuffer();
  bool inCode = false;
  for (int i = 1; i < trimmed.length; i++) {
    final String ch = trimmed[i];
    if (ch == r'\' && i + 1 < trimmed.length && trimmed[i + 1] == '|') {
      cell.write('|');
      i++;
    } else if (ch == '`') {
      inCode = !inCode;
      cell.write(ch);
    } else if (ch == '|' && !inCode) {
      cells.add(cell.toString().trim());
      cell.clear();
    } else {
      cell.write(ch);
    }
  }
  if (inCode) {
    throw ImportError('line $lineNo: unbalanced backtick');
  }
  if (cell.toString().trim().isNotEmpty) {
    throw ImportError('line $lineNo: text after the final "|"');
  }
  return cells;
}

/// Removes markdown emphasis, code spans and links from a notes cell.
String stripMarkdown(String text) {
  return text
      .replaceAllMapped(
        RegExp(r'\[([^\]]*)\]\([^)]*\)'),
        (Match m) => m.group(1)!,
      )
      .replaceAll('**', '')
      .replaceAll('`', '')
      .trim();
}

final RegExp _specKeyPattern = RegExp(r'^[a-z][A-Za-z0-9]*(\.[A-Za-z0-9]+)*$');

/// Spec-mandated typography applied to every message (the table shows plain
/// spaces for readability; the rules are in the guidelines):
///
/// * 12 §1.7 — the ellipsis "…" is preceded by a no-break space.
/// * 12 §1.4 — masked card numbers: four U+2022 bullets, no-break space.
/// * 12 §1.4 — countdowns "{seconds} s" / "{minutes} min" with no-break space.
String normaliseMessage(String text) {
  return text
      .replaceAll(' \u2026', '\u00A0\u2026')
      .replaceAll('\u2022\u2022\u2022\u2022 ', '\u2022\u2022\u2022\u2022\u00A0')
      .replaceAllMapped(
        RegExp(r'\{seconds\} s\b'),
        (Match m) => '{seconds}\u00A0s',
      )
      .replaceAllMapped(
        RegExp(r'\{minutes\} min\b'),
        (Match m) => '{minutes}\u00A0min',
      );
}

/// Validates a language cell and returns the normalised message.
String cleanLanguageCell(String cell, String specKey, String lang, int lineNo) {
  final String where = 'line $lineNo ($specKey, $lang)';
  if (cell.isEmpty || cell == '—' || cell == '-') {
    throw ImportError('$where: missing language cell');
  }
  if (cell.contains('`')) {
    throw ImportError('$where: backtick in a message cell');
  }
  if (cell.contains('**') || cell.contains('<br')) {
    throw ImportError('$where: markdown formatting in a message cell');
  }
  if (cell.contains('!')) {
    throw ImportError('$where: exclamation mark (forbidden by 12 §1.7)');
  }
  if (cell.contains('...')) {
    throw ImportError('$where: "..." instead of U+2026 (12 §1.7)');
  }
  return normaliseMessage(cell);
}

/// Parses §5.1–§5.21. Returns ARB entries (§5.1–§5.20) and OS usage entries
/// (§5.21) separately, plus the key count stated in §5.22 and the alias
/// register.
class ParsedTable {
  ParsedTable({
    required this.entries,
    required this.osEntries,
    required this.statedKeyCount,
    required this.aliases,
  });

  final List<StringEntry> entries;
  final List<StringEntry> osEntries;
  final int statedKeyCount;

  /// Alias key → whether 12 §5.22 says it is kept as its own key.
  final Map<String, bool> aliases;
}

ParsedTable parseMasterTable(String markdown) {
  final List<String> lines = const LineSplitter().convert(markdown);
  final RegExp sectionHeading = RegExp(r'^### 5\.(\d+) ');
  final List<StringEntry> entries = <StringEntry>[];
  final List<StringEntry> osEntries = <StringEntry>[];
  final Set<String> seenSpecKeys = <String>{};
  final Map<String, String> seenArbKeys = <String, String>{};
  final Set<int> sectionsSeen = <int>{};
  int? statedKeyCount;
  final Map<String, bool> aliases = <String, bool>{};

  int? section;
  List<String>? header;
  bool inTable = false;

  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    final int lineNo = i + 1;
    final RegExpMatch? heading = sectionHeading.firstMatch(line);
    if (heading != null) {
      section = int.parse(heading.group(1)!);
      header = null;
      inTable = false;
      if (section <= 21) {
        sectionsSeen.add(section);
      }
      continue;
    }
    if (line.startsWith('## ') || line.startsWith('### ')) {
      section = null;
      header = null;
      inTable = false;
      continue;
    }
    if (section == null) {
      continue;
    }

    if (section == 22) {
      final RegExpMatch? count = RegExp(
        r'holds \*\*(\d+) keys\*\*',
      ).firstMatch(line);
      if (count != null) {
        statedKeyCount = int.parse(count.group(1)!);
      }
      if (line.startsWith('| `')) {
        final List<String> cells = splitRow(line, lineNo);
        if (cells.length != 2) {
          throw ImportError('line $lineNo: alias row needs 2 cells');
        }
        final bool kept = cells[0].contains('kept as its own key');
        for (final Match m in RegExp(r'`([^`]+)`').allMatches(cells[0])) {
          aliases[m.group(1)!] = kept;
        }
      }
      continue;
    }
    if (section < 1 || section > 21) {
      continue;
    }

    final bool isTableLine = line.trimLeft().startsWith('|');
    if (!isTableLine) {
      if (inTable) {
        inTable = false;
        header = null;
      }
      continue;
    }
    final List<String> cells = splitRow(line, lineNo);
    if (header == null) {
      header = cells;
      if (header.isEmpty || header.first != 'Key') {
        throw ImportError(
          'line $lineNo: §5.$section table must start with a '
          '"Key" column',
        );
      }
      for (final String required in <String>['DE', 'EN', 'BHS', 'Notes']) {
        if (!header.contains(required)) {
          throw ImportError(
            'line $lineNo: §5.$section header lacks "$required"',
          );
        }
      }
      inTable = true;
      continue;
    }
    if (cells.every((String c) => RegExp(r'^:?-{3,}:?$').hasMatch(c))) {
      continue;
    }
    if (cells.length != header.length) {
      throw ImportError(
        'line $lineNo: expected ${header.length} cells, found '
        '${cells.length} (malformed row)',
      );
    }
    final String keyCell = cells[0];
    final RegExpMatch? keyMatch = RegExp(r'^`([^`]+)`$').firstMatch(keyCell);
    if (keyMatch == null) {
      throw ImportError(
        'line $lineNo: key cell must be a single code span, '
        'found "$keyCell"',
      );
    }
    final String specKey = keyMatch.group(1)!;
    if (!_specKeyPattern.hasMatch(specKey)) {
      throw ImportError('line $lineNo: invalid key "$specKey" (12 §4.1)');
    }
    if (!seenSpecKeys.add(specKey)) {
      throw ImportError('line $lineNo: duplicate key "$specKey"');
    }
    final String arbKey = arbKeyOf(specKey);
    final String? clash = seenArbKeys[arbKey];
    if (clash != null) {
      throw ImportError(
        'line $lineNo: "$specKey" and "$clash" both map to '
        'the ARB identifier "$arbKey"',
      );
    }
    seenArbKeys[arbKey] = specKey;

    final Map<String, String> texts = <String, String>{
      'de': cleanLanguageCell(
        cells[header.indexOf('DE')],
        specKey,
        'de',
        lineNo,
      ),
      'en': cleanLanguageCell(
        cells[header.indexOf('EN')],
        specKey,
        'en',
        lineNo,
      ),
      'bhs': cleanLanguageCell(
        cells[header.indexOf('BHS')],
        specKey,
        'bhs',
        lineNo,
      ),
    };
    String? limitLabel;
    String? limit;
    for (final String label in <String>['Max', 'Politeness']) {
      if (header.contains(label)) {
        limitLabel = label;
        limit = stripMarkdown(cells[header.indexOf(label)]);
      }
    }
    final StringEntry entry = StringEntry(
      specKey: specKey,
      section: '5.$section',
      line: lineNo,
      texts: texts,
      limit: limit,
      limitLabel: limitLabel,
      notes: stripMarkdown(cells[header.indexOf('Notes')]),
    );
    if (section == 21) {
      osEntries.add(entry);
    } else {
      entries.add(entry);
    }
  }

  for (int s = 1; s <= 21; s++) {
    if (!sectionsSeen.contains(s)) {
      throw ImportError('section §5.$s not found');
    }
  }
  if (statedKeyCount == null) {
    throw ImportError('§5.22 does not state the key count');
  }
  if (aliases.isEmpty) {
    throw ImportError('§5.22 alias register not found');
  }
  return ParsedTable(
    entries: entries,
    osEntries: osEntries,
    statedKeyCount: statedKeyCount,
    aliases: aliases,
  );
}

// ---------------------------------------------------------------------------
// ICU MessageFormat validation
// ---------------------------------------------------------------------------

/// Result of parsing one ICU message: argument names and, for plural
/// arguments, the category sets used.
class IcuInfo {
  final List<String> arguments = <String>[];
  final Map<String, Set<String>> plurals = <String, Set<String>>{};

  /// Offsets of `#` inside plural branches → the plural argument name.
  final Map<int, String> pounds = <int, String>{};

  void _addArgument(String name) {
    if (!arguments.contains(name)) {
      arguments.add(name);
    }
  }
}

/// Minimal ICU MessageFormat parser covering what 09 §6.5 allows:
/// `{name}`, `{name, plural, cat {msg} …}`, `{name, select, …}` and `#`.
class IcuParser {
  IcuParser(this.source, this.where);

  final String source;
  final String where;
  int _pos = 0;
  final IcuInfo info = IcuInfo();

  IcuInfo parse() {
    _message(nested: false, plural: null);
    if (_pos != source.length) {
      _fail('unexpected "}"');
    }
    return info;
  }

  Never _fail(String message) {
    throw ImportError(
      '$where: invalid ICU at offset $_pos: $message in '
      '"$source"',
    );
  }

  void _message({required bool nested, required String? plural}) {
    while (_pos < source.length) {
      final String ch = source[_pos];
      if (ch == '{') {
        _argument(plural);
      } else if (ch == '#' && plural != null) {
        info.pounds[_pos] = plural;
        _pos++;
      } else if (ch == '}') {
        if (!nested) {
          _fail('unbalanced "}"');
        }
        return;
      } else {
        _pos++;
      }
    }
    if (nested) {
      _fail('unterminated sub-message');
    }
  }

  String _identifier() {
    final Match? m = RegExp(
      r'\s*([A-Za-z][A-Za-z0-9]*)\s*',
    ).matchAsPrefix(source, _pos);
    if (m == null) {
      _fail('expected an argument name');
    }
    _pos = m.end;
    return m.group(1)!;
  }

  void _argument(String? outerPlural) {
    _pos++; // {
    final String name = _identifier();
    info._addArgument(name);
    if (_pos < source.length && source[_pos] == '}') {
      _pos++;
      return;
    }
    if (_pos >= source.length || source[_pos] != ',') {
      _fail('expected "," or "}" after "$name"');
    }
    _pos++;
    final String type = _identifier();
    if (type != 'plural' && type != 'select') {
      _fail('unsupported argument type "$type"');
    }
    if (_pos >= source.length || source[_pos] != ',') {
      _fail('expected "," after "$type"');
    }
    _pos++;
    final Set<String> categories = <String>{};
    while (true) {
      final Match? sel = RegExp(
        r'\s*(=\d+|[A-Za-z]+)\s*',
      ).matchAsPrefix(source, _pos);
      if (sel == null) {
        break;
      }
      final String category = sel.group(1)!;
      _pos = sel.end;
      if (_pos >= source.length || source[_pos] != '{') {
        _fail('expected "{" after selector "$category"');
      }
      if (!categories.add(category)) {
        _fail('duplicate selector "$category"');
      }
      _pos++;
      _message(nested: true, plural: type == 'plural' ? name : outerPlural);
      _pos++; // }
    }
    final Match? close = RegExp(r'\s*\}').matchAsPrefix(source, _pos);
    if (close == null) {
      _fail('expected "}" to close "$name"');
    }
    _pos = close.end;
    if (!categories.contains('other')) {
      _fail('"$name" has no "other" branch');
    }
    if (type == 'plural') {
      const Set<String> cldr = <String>{
        'zero',
        'one',
        'two',
        'few',
        'many',
        'other',
      };
      for (final String c in categories) {
        if (!c.startsWith('=') && !cldr.contains(c)) {
          _fail('unknown plural category "$c"');
        }
      }
      info.plurals[name] = categories;
    }
  }
}

/// Replaces `#` inside plural branches by the plural argument (`{count}`).
/// Both are the same ICU; Flutter's gen-l10n does not substitute `#`
/// (it would render a literal "#"), so the table's `# Einlösung` is written
/// as `{count} Einlösung`.
String expandPounds(String message, IcuInfo info) {
  if (info.pounds.isEmpty) {
    return message;
  }
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < message.length; i++) {
    final String? name = info.pounds[i];
    out.write(name == null ? message[i] : '{$name}');
  }
  return out.toString();
}

/// Validates ICU syntax, plural categories and placeholder parity for one
/// entry, and fills [StringEntry.placeholders].
void validateEntry(StringEntry entry) {
  final Map<String, IcuInfo> infos = <String, IcuInfo>{};
  for (final String lang in tableLanguages) {
    final IcuInfo info = IcuParser(
      entry.texts[lang]!,
      'line ${entry.line} (${entry.specKey}, $lang)',
    ).parse();
    for (final MapEntry<String, Set<String>> plural in info.plurals.entries) {
      final Set<String> named = plural.value
          .where((String c) => !c.startsWith('='))
          .toSet();
      final Set<String> required = pluralCategories[lang]!;
      if (named.length != required.length || !named.containsAll(required)) {
        throw ImportError(
          'line ${entry.line} (${entry.specKey}, $lang): '
          'plural "${plural.key}" must use exactly $required '
          '(12 §1.9), found $named',
        );
      }
    }
    infos[lang] = info;
    entry.texts[lang] = expandPounds(entry.texts[lang]!, info);
  }
  final Set<String> en = infos['en']!.arguments.toSet();
  for (final String lang in tableLanguages) {
    final Set<String> other = infos[lang]!.arguments.toSet();
    if (other.length != en.length || !other.containsAll(en)) {
      throw ImportError(
        'line ${entry.line} (${entry.specKey}): placeholder '
        'mismatch — en $en vs $lang $other',
      );
    }
  }
  final Set<String> pluralArgs = <String>{
    for (final IcuInfo info in infos.values) ...info.plurals.keys,
  };
  entry.placeholders = <String, String>{
    for (final String name in infos['en']!.arguments)
      name: integerPlaceholders.contains(name) || pluralArgs.contains(name)
          ? 'int'
          : 'String',
  };
}

// ---------------------------------------------------------------------------
// Output generation
// ---------------------------------------------------------------------------

String _description(StringEntry e) {
  final StringBuffer out = StringBuffer(
    'Spec key: ${e.specKey} (12 §${e.section})',
  );
  if (e.limitLabel != null) {
    out.write(' · ${e.limitLabel}: ${e.limit}');
  }
  if (e.notes.isNotEmpty) {
    out.write(' · Notes: ${e.notes}');
  }
  return out.toString();
}

/// JSON with visible escapes for invisible typography (no-break space).
String _encodeJson(Map<String, Object?> json) {
  final String text = const JsonEncoder.withIndent('  ').convert(json);
  return '${text.replaceAll('\u00A0', r'\u00a0')}\n';
}

Map<String, String> buildArbFiles(List<StringEntry> entries) {
  final Map<String, String> files = <String, String>{};

  final Map<String, Object?> template = <String, Object?>{'@@locale': 'en'};
  for (final StringEntry e in entries) {
    template[e.arbKey] = e.texts['en'];
    template['@${e.arbKey}'] = <String, Object?>{
      'description': _description(e),
      if (e.placeholders.isNotEmpty)
        'placeholders': <String, Object?>{
          for (final MapEntry<String, String> p in e.placeholders.entries)
            p.key: <String, Object?>{'type': p.value},
        },
    };
  }
  files['app_en.arb'] = _encodeJson(template);

  Map<String, Object?> translation(String lang, String locale) {
    return <String, Object?>{
      '@@locale': locale,
      for (final StringEntry e in entries) e.arbKey: e.texts[lang],
    };
  }

  files['app_de.arb'] = _encodeJson(translation('de', 'de'));
  files['app_bs.arb'] = _encodeJson(translation('bhs', 'bs'));
  for (final String copy in bhsCopyLocales) {
    files['app_$copy.arb'] = _encodeJson(translation('bhs', copy));
  }
  return files;
}

String _plistEscape(String text) =>
    text.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

Map<String, String> buildInfoPlistStrings(List<StringEntry> osEntries) {
  final Set<String> found = osEntries.map((StringEntry e) => e.specKey).toSet();
  if (found.length != infoPlistKeyOf.length ||
      !found.containsAll(infoPlistKeyOf.keys)) {
    throw ImportError(
      '§5.21 must contain exactly ${infoPlistKeyOf.keys}, '
      'found $found',
    );
  }
  final Map<String, String> files = <String, String>{};
  for (final MapEntry<String, String> lproj in lprojLanguage.entries) {
    final StringBuffer out = StringBuffer()
      ..writeln(
        '/* Generated by tool/import_strings.dart from 12 §5.21. '
        'Do not edit. */',
      );
    for (final StringEntry e in osEntries) {
      final String text = e.texts[lproj.value]!;
      if (RegExp(r'\{[A-Za-z]').hasMatch(text)) {
        throw ImportError(
          'line ${e.line}: OS usage string must not contain '
          'placeholders',
        );
      }
      out
        ..writeln()
        ..writeln('/* ${e.specKey} */')
        ..writeln('"${infoPlistKeyOf[e.specKey]}" = "${_plistEscape(text)}";');
    }
    files['${lproj.key}.lproj/InfoPlist.strings'] = out.toString();
  }
  return files;
}

/// Generates the pseudo-localisation subclass of `AppLocalizations`
/// (09 §6.5). String arguments are passed as markers so the transformation
/// never touches placeholder values.
String buildPseudoLocalizations(List<StringEntry> entries) {
  final StringBuffer out = StringBuffer()
    ..writeln('// GENERATED by tool/import_strings.dart — do not edit.')
    ..writeln('// Pseudo-localisation wrapper for AppLocalizations (09 §6.5).')
    ..writeln()
    ..writeln("import '../../l10n/app_localizations.dart';")
    ..writeln("import 'pseudo_transform.dart';")
    ..writeln()
    ..writeln('/// [AppLocalizations] whose every message is pseudo-localised')
    ..writeln('/// with [pseudoLocalize]; placeholder values are kept intact.')
    ..writeln('class PseudoAppLocalizations extends AppLocalizations {')
    ..writeln('  /// Wraps [base].')
    ..writeln('  PseudoAppLocalizations(this.base) : super(base.localeName);')
    ..writeln()
    ..writeln('  /// The real localizations being transformed.')
    ..writeln('  final AppLocalizations base;');
  for (final StringEntry e in entries) {
    out.writeln();
    if (e.placeholders.isEmpty) {
      out
        ..writeln('  @override')
        ..writeln(
          '  String get ${e.arbKey} => pseudoLocalize(base.${e.arbKey});',
        );
      continue;
    }
    final List<String> params = <String>[];
    final List<String> args = <String>[];
    final List<String> values = <String>[];
    int marker = 0;
    for (final MapEntry<String, String> p in e.placeholders.entries) {
      params.add('${p.value} ${p.key}');
      if (p.value == 'String') {
        args.add('pseudoMarker($marker)');
        values.add(p.key);
        marker++;
      } else {
        args.add(p.key);
      }
    }
    out
      ..writeln('  @override')
      ..writeln('  String ${e.arbKey}(${params.join(', ')}) => pseudoLocalize(')
      ..writeln('        base.${e.arbKey}(${args.join(', ')}),')
      ..writeln('        <String>[${values.join(', ')}],')
      ..writeln('      );');
  }
  out.writeln('}');
  return out.toString();
}

/// All generated files, keyed by path relative to the waiter-app directory.
Map<String, String> buildOutputs(String markdown) {
  final ParsedTable table = parseMasterTable(markdown);

  final int total = table.entries.length + table.osEntries.length;
  if (total != table.statedKeyCount) {
    throw ImportError(
      'key count mismatch: table rows §5.1–§5.21 = $total, '
      '§5.22 states ${table.statedKeyCount}',
    );
  }
  final Set<String> allKeys = <String>{
    for (final StringEntry e in table.entries) e.specKey,
    for (final StringEntry e in table.osEntries) e.specKey,
  };
  for (final MapEntry<String, bool> alias in table.aliases.entries) {
    if (allKeys.contains(alias.key) && !alias.value) {
      throw ImportError(
        'alias "${alias.key}" (12 §5.22) must not be '
        'implemented as a separate key',
      );
    }
  }
  for (final StringEntry e in table.entries) {
    validateEntry(e);
  }

  // Cells are trimmed by the parser; a message must not carry stray
  // whitespace introduced by normalisation.
  for (final StringEntry e in table.entries) {
    for (final String lang in tableLanguages) {
      if (e.texts[lang]!.trim() != e.texts[lang]) {
        throw ImportError(
          'line ${e.line} (${e.specKey}, $lang): '
          'leading or trailing whitespace',
        );
      }
    }
  }

  return <String, String>{
    for (final MapEntry<String, String> f in buildArbFiles(
      table.entries,
    ).entries)
      'lib/l10n/${f.key}': f.value,
    for (final MapEntry<String, String> f in buildInfoPlistStrings(
      table.osEntries,
    ).entries)
      'ios/Runner/${f.key}': f.value,
    'lib/core/l10n/pseudo_app_localizations.g.dart': buildPseudoLocalizations(
      table.entries,
    ),
  };
}

/// Formats generated Dart sources with `dart format` (the running `dart`
/// executable), so the committed files are stable under the repository's
/// formatter.
void formatDartOutputs(Map<String, String> outputs) {
  final Directory temp = Directory.systemTemp.createTempSync('import_strings');
  try {
    for (final String path in outputs.keys.toList()) {
      if (!path.endsWith('.dart')) {
        continue;
      }
      final File file = File('${temp.path}/${path.split('/').last}')
        ..writeAsStringSync(outputs[path]!);
      final ProcessResult result = Process.runSync(
        Platform.resolvedExecutable,
        <String>['format', '--language-version=3.9', file.path],
      );
      if (result.exitCode != 0) {
        throw ImportError('dart format failed for $path: ${result.stderr}');
      }
      outputs[path] = file.readAsStringSync();
    }
  } finally {
    temp.deleteSync(recursive: true);
  }
}

/// Entry point. Must be run from the waiter-app directory.
void main(List<String> args) {
  final bool check = args.contains('--check');
  final List<String> unknown = args
      .where((String a) => a != '--check')
      .toList();
  if (unknown.isNotEmpty) {
    stderr.writeln(
      'Unknown arguments: $unknown\n'
      'Usage: dart run tool/import_strings.dart [--check]',
    );
    exitCode = 64;
    return;
  }
  final File doc = File(masterDocPath);
  if (!doc.existsSync()) {
    stderr.writeln(
      'import_strings: master document not found at '
      '${doc.absolute.path} (run from the waiter-app directory)',
    );
    exitCode = 1;
    return;
  }
  final Map<String, String> outputs;
  try {
    outputs = buildOutputs(doc.readAsStringSync());
  } on ImportError catch (e) {
    stderr.writeln(e);
    exitCode = 1;
    return;
  }

  try {
    formatDartOutputs(outputs);
  } on ImportError catch (e) {
    stderr.writeln(e);
    exitCode = 1;
    return;
  }

  final List<String> stale = <String>[];
  for (final MapEntry<String, String> f in outputs.entries) {
    final File file = File(f.key);
    final bool same = file.existsSync() && file.readAsStringSync() == f.value;
    if (check) {
      if (!same) {
        stale.add(f.key);
      }
    } else if (!same) {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(f.value);
      stdout.writeln('wrote ${f.key}');
    }
  }
  if (check && stale.isNotEmpty) {
    stderr.writeln(
      'import_strings --check: out of date: ${stale.join(', ')}\n'
      'Run: dart run tool/import_strings.dart',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'import_strings: ${outputs.length} files '
    '${check ? 'up to date' : 'in sync'}.',
  );
}
