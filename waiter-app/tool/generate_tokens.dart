// Design-token generator for GiftCard Waiter (09 §2).
//
// Reads `tokens/waiter.tokens.json` (W3C DTCG format), validates the schema
// and every `{reference}`, and writes `lib/core/tokens/tokens.g.dart`.
//
//   dart run tool/generate_tokens.dart          # generate
//   dart run tool/generate_tokens.dart --check  # CI: fail if out of date
//
// Exit code 1 on any validation error or (with --check) a stale output.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const String _inputPath = 'tokens/waiter.tokens.json';
const String _outputPath = 'lib/core/tokens/tokens.g.dart';

/// Tier-2 categories and the Dart type each becomes (09 §2.5).
const Map<String, String> _categoryClasses = <String, String>{
  'color': 'WaiterColors',
  'type': 'TypeTokens',
  'space': 'Space',
  'layout': 'LayoutTokens',
  'radius': 'Radii',
  'border': 'Borders',
  'focus': 'FocusTokens',
  'size': 'Sizes',
  'icon': 'IconSize',
  'illustration': 'IllustrationTokens',
  'elev': 'WaiterElevation',
  'opacity': 'Opacities',
  'z': 'ZLayers',
  'motion': 'Motion',
  'time': 'Times',
  'haptic': 'HapticToken',
  'sound': 'SoundToken',
};

const Set<String> _knownTypes = <String>{
  'color',
  'dimension',
  'number',
  'duration',
  'cubicBezier',
  'spring',
  'typography',
  'shadow',
  'haptic',
  'sound',
};

const Set<String> _fontFamilies = <String>{'Geist', 'GeistMono'};
const Set<int> _fontWeights = <int>{400, 500, 600, 700};

final RegExp _refPattern = RegExp(r'^\{([A-Za-z0-9.\-]+)\}$');
final RegExp _hexPattern = RegExp(r'^#([0-9A-Fa-f]{6})$');
final RegExp _rgbaPattern = RegExp(
  r'^rgba\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*([01](?:\.\d+)?)\s*\)$',
);
final RegExp _msPattern = RegExp(r'^(\d+)ms$');
final RegExp _pxPattern = RegExp(r'^(\d+(?:\.\d+)?)px$');
final RegExp _percentPattern = RegExp(r'^(-?\d+(?:\.\d+)?)%$');

class _Token {
  _Token(this.path, this.type, this.value, this.description, this.extensions);

  final List<String> path;
  final String type;
  final Object? value;
  final String? description;
  final Map<String, Object?> extensions;

  String get name => path.where((String s) => s != r'$root').join('.');
  String get category => path.first;

  /// Path below the category, without `$root`.
  List<String> get localPath =>
      path.skip(1).where((String s) => s != r'$root').toList();
}

class _Generator {
  _Generator(this.root);

  final Map<String, Object?> root;
  final List<String> errors = <String>[];
  final Map<String, _Token> tokens = <String, _Token>{};
  final Map<String, String> groupDescriptions = <String, String>{};
  final Map<String, Map<String, Object?>> groupExtensions =
      <String, Map<String, Object?>>{};
  final Set<String> tier3Groups = <String>{};

  // ---------------------------------------------------------------- parsing

  void collect() {
    for (final MapEntry<String, Object?> entry in root.entries) {
      if (entry.key == r'$description' || entry.key == r'$extensions') {
        continue;
      }
      if (entry.key.startsWith(r'$')) {
        errors.add('Unknown root key "${entry.key}".');
        continue;
      }
      final Object? group = entry.value;
      if (group is! Map<String, Object?>) {
        errors.add('Top-level "${entry.key}" must be a group.');
        continue;
      }
      final Object? ext = group[r'$extensions'];
      final bool isTier3 = ext is Map<String, Object?> && ext['tier'] == 3;
      if (isTier3) {
        tier3Groups.add(entry.key);
      } else if (!_categoryClasses.containsKey(entry.key)) {
        errors.add(
          'Unknown category "${entry.key}". Tier-3 component groups must set '
          r'"$extensions": {"tier": 3}.',
        );
      }
      _walk(<String>[entry.key], group);
    }
  }

  void _walk(List<String> path, Map<String, Object?> node) {
    final String where = path.join('.');
    if (node.containsKey(r'$value')) {
      final Object? type = node[r'$type'];
      if (type is! String || !_knownTypes.contains(type)) {
        errors.add('$where: missing or unknown \$type "$type".');
        return;
      }
      for (final String key in node.keys) {
        if (!const <String>{
          r'$type',
          r'$value',
          r'$description',
          r'$extensions',
        }.contains(key)) {
          errors.add('$where: unexpected key "$key" in token.');
        }
      }
      final Object? ext = node[r'$extensions'];
      final _Token token = _Token(
        List<String>.unmodifiable(path),
        type,
        node[r'$value'],
        node[r'$description'] as String?,
        ext is Map<String, Object?> ? ext : const <String, Object?>{},
      );
      if (tokens.containsKey(token.name)) {
        errors.add('$where: duplicate token name "${token.name}".');
      }
      tokens[token.name] = token;
      return;
    }
    for (final MapEntry<String, Object?> entry in node.entries) {
      if (entry.key == r'$description') {
        groupDescriptions[where] = entry.value! as String;
        continue;
      }
      if (entry.key == r'$extensions') {
        groupExtensions[where] = entry.value! as Map<String, Object?>;
        continue;
      }
      if (entry.key.startsWith(r'$') && entry.key != r'$root') {
        errors.add('$where: unknown group key "${entry.key}".');
        continue;
      }
      final Object? child = entry.value;
      if (child is! Map<String, Object?>) {
        errors.add('$where.${entry.key}: expected a token or group.');
        continue;
      }
      _walk(<String>[...path, entry.key], child);
    }
  }

  // ------------------------------------------------------------- references

  String? _refName(Object? value) {
    if (value is! String) return null;
    return _refPattern.firstMatch(value)?.group(1);
  }

  _Token? _lookup(String name, String from) {
    final _Token? t = tokens[name];
    if (t == null) errors.add('$from: unknown reference {$name}.');
    return t;
  }

  /// Resolves a scalar value (following references) for non-colour types.
  Object? resolveScalar(_Token token, [Set<String>? seen]) {
    final Set<String> visiting = seen ?? <String>{};
    final String? ref = _refName(token.value);
    if (ref == null) return token.value;
    if (!visiting.add(token.name)) {
      errors.add('${token.name}: reference cycle.');
      return null;
    }
    final _Token? target = _lookup(ref, token.name);
    if (target == null) return null;
    if (target.type != token.type) {
      errors.add(
        '${token.name}: references {$ref} of type ${target.type}, '
        'expected ${token.type}.',
      );
      return null;
    }
    return resolveScalar(target, visiting);
  }

  /// Resolves one theme's colour of a colour token (normal value).
  Object? resolveColor(_Token token, String theme, [Set<String>? seen]) {
    final Set<String> visiting = seen ?? <String>{};
    if (!visiting.add('${token.name}/$theme')) {
      errors.add('${token.name}: colour reference cycle.');
      return null;
    }
    final Object? raw = (token.value! as Map<String, Object?>)[theme];
    final String? ref = _refName(raw);
    if (ref == null) return raw;
    final _Token? target = _lookup(ref, token.name);
    if (target == null) return null;
    if (target.type != 'color') {
      errors.add('${token.name}: {$ref} is not a colour.');
      return null;
    }
    return resolveColor(target, theme, visiting);
  }

  /// Resolves the high-contrast colour of [token] for [theme].
  Object? resolveHighContrast(_Token token, String theme) {
    final Object? hc = token.extensions['highContrast'];
    if (hc == null) return resolveColor(token, theme);
    final String? ref = _refName(hc);
    if (ref != null) {
      final _Token? target = _lookup(ref, '${token.name} (highContrast)');
      if (target == null) return null;
      return resolveColor(target, theme);
    }
    final Object? raw = (hc as Map<String, Object?>)[theme];
    final String? innerRef = _refName(raw);
    if (innerRef != null) {
      final _Token? target = _lookup(innerRef, '${token.name} (highContrast)');
      return target == null ? null : resolveColor(target, theme);
    }
    return raw;
  }

  // ------------------------------------------------------------- validation

  void validate() {
    for (final _Token t in tokens.values) {
      switch (t.type) {
        case 'color':
          _validateColor(t);
        case 'dimension':
          final Object? v = resolveScalar(t);
          if (v is String) {
            if (_pxPattern.firstMatch(v) == null) {
              errors.add('${t.name}: dimension string must be "<n>px".');
            }
          } else if (v is! num) {
            errors.add('${t.name}: dimension must be a number.');
          }
          for (final String key in const <String>['compactHeight', 'stroke']) {
            final Object? e = t.extensions[key];
            if (e != null && e is! num) {
              errors.add('${t.name}: \$extensions.$key must be a number.');
            }
          }
        case 'number':
          if (resolveScalar(t) is! num) {
            errors.add('${t.name}: number expected.');
          }
        case 'duration':
          final Object? v = resolveScalar(t);
          if (v is! String || _msPattern.firstMatch(v) == null) {
            errors.add('${t.name}: duration must be "<n>ms".');
          }
        case 'cubicBezier':
          final Object? v = t.value;
          if (v is! List<Object?> ||
              v.length != 4 ||
              v.any((Object? e) => e is! num)) {
            errors.add('${t.name}: cubicBezier must be 4 numbers.');
          } else {
            final double x1 = (v[0]! as num).toDouble();
            final double x2 = (v[2]! as num).toDouble();
            if (x1 < 0 || x1 > 1 || x2 < 0 || x2 > 1) {
              errors.add('${t.name}: x control points must be in [0, 1].');
            }
          }
        case 'spring':
          final Object? v = t.value;
          if (v is! Map<String, Object?> ||
              v['response'] is! num ||
              v['damping'] is! num ||
              (v['response']! as num) <= 0 ||
              (v['damping']! as num) <= 0) {
            errors.add('${t.name}: spring needs response > 0, damping > 0.');
          }
        case 'typography':
          _validateTypography(t);
        case 'shadow':
          _validateShadow(t);
        case 'haptic':
          _validateHaptic(t);
        case 'sound':
          _validateSound(t);
      }
    }
    _validatePlacement();
  }

  void _validatePlacement() {
    for (final _Token t in tokens.values) {
      final String cat = t.category;
      final bool tier3 = tier3Groups.contains(cat);
      final Map<String, Set<String>> allowed = <String, Set<String>>{
        'color': <String>{'color'},
        'type': <String>{'typography', 'number', 'dimension'},
        'space': <String>{'dimension'},
        'layout': <String>{'dimension', 'number'},
        'radius': <String>{'dimension'},
        'border': <String>{'dimension'},
        'focus': <String>{'dimension'},
        'size': <String>{'dimension', 'number'},
        'icon': <String>{'dimension'},
        'illustration': <String>{'dimension', 'number'},
        'elev': <String>{'shadow'},
        'opacity': <String>{'number'},
        'z': <String>{'number'},
        'motion': <String>{'duration', 'cubicBezier', 'spring', 'number'},
        'time': <String>{'duration'},
        'haptic': <String>{'haptic'},
        'sound': <String>{'sound'},
      };
      if (tier3) {
        if (!const <String>{
          'dimension',
          'number',
          'duration',
          'color',
        }.contains(t.type)) {
          errors.add('${t.name}: type ${t.type} not allowed in tier 3.');
        }
        continue;
      }
      final Set<String>? ok = allowed[cat];
      if (ok != null && !ok.contains(t.type)) {
        errors.add('${t.name}: type ${t.type} not allowed in "$cat".');
      }
      if (cat == 'opacity') {
        final num v = resolveScalar(t)! as num;
        if (v < 0 || v > 1) errors.add('${t.name}: opacity out of [0, 1].');
      }
    }
  }

  void _validateColor(_Token t) {
    final Object? v = t.value;
    if (v is! Map<String, Object?> ||
        v.length != 2 ||
        !v.containsKey('light') ||
        !v.containsKey('dark')) {
      errors.add('${t.name}: colour \$value must be {light, dark}.');
      return;
    }
    for (final String theme in const <String>['light', 'dark']) {
      final Object? c = resolveColor(t, theme);
      if (c != null && _parseColor(c) == null) {
        errors.add('${t.name}.$theme: invalid colour "$c".');
      }
      final Object? hc = resolveHighContrast(t, theme);
      if (hc != null && _parseColor(hc) == null) {
        errors.add('${t.name}.$theme: invalid high-contrast colour "$hc".');
      }
    }
    if (tier3Groups.contains(t.category) &&
        resolveColor(t, 'light') != resolveColor(t, 'dark')) {
      errors.add('${t.name}: tier-3 colours must be theme-independent.');
    }
  }

  void _validateTypography(_Token t) {
    final Object? v = t.value;
    if (v is! Map<String, Object?>) {
      errors.add('${t.name}: typography \$value must be an object.');
      return;
    }
    if (!_fontFamilies.contains(v['fontFamily'])) {
      errors.add('${t.name}: fontFamily must be one of $_fontFamilies.');
    }
    if (!_fontWeights.contains(v['fontWeight'])) {
      errors.add('${t.name}: fontWeight must be one of $_fontWeights.');
    }
    final Object? size = v['fontSize'];
    final Object? line = v['lineHeight'];
    if (size is! num || size <= 0 || line is! num || line <= 0) {
      errors.add('${t.name}: fontSize and lineHeight must be > 0.');
    } else if (line % 2 != 0) {
      errors.add('${t.name}: line heights are even numbers (04 §4.4).');
    }
    final Object? ls = v['letterSpacing'];
    if (ls is! String || _percentPattern.firstMatch(ls) == null) {
      errors.add('${t.name}: letterSpacing must be a percentage string.');
    }
    final Object? features = v['fontFeatures'];
    if (features is! List<Object?> ||
        features.any((Object? f) => f != 'tnum')) {
      errors.add('${t.name}: fontFeatures supports ["tnum"] only.');
    }
    final Object? transform = v['textTransform'];
    if (transform != null && transform != 'uppercase') {
      errors.add('${t.name}: textTransform must be "uppercase".');
    }
    final Object? maxScale = t.extensions['maxScale'];
    if (maxScale is! num || maxScale < 1) {
      errors.add('${t.name}: \$extensions.maxScale ≥ 1 required (04 §3.7).');
    }
    final Object? min = t.extensions['minSizeAfterShrink'];
    if (min != null && (min is! num || size is! num || min > size)) {
      errors.add('${t.name}: minSizeAfterShrink must be ≤ fontSize.');
    }
  }

  void _validateShadow(_Token t) {
    final Object? v = t.value;
    if (v is! Map<String, Object?> ||
        v['light'] is! List<Object?> ||
        v['dark'] is! Map<String, Object?>) {
      errors.add('${t.name}: shadow \$value must be {light: [...], dark: {}}.');
      return;
    }
    for (final Object? s in v['light']! as List<Object?>) {
      if (s is! Map<String, Object?>) {
        errors.add('${t.name}: shadow layer must be an object.');
        continue;
      }
      for (final String k in const <String>['x', 'y', 'blur', 'spread']) {
        if (s[k] is! num) {
          errors.add('${t.name}: shadow "$k" must be a number.');
        }
      }
      final Object? color = s['color'];
      if (color == 'brand') {
        final Object? alpha = s['alpha'];
        if (alpha is! num || alpha < 0 || alpha > 1) {
          errors.add('${t.name}: brand shadow needs alpha in [0, 1].');
        }
      } else if (color is! String || _parseColor(color) == null) {
        errors.add('${t.name}: invalid shadow colour "$color".');
      }
    }
    final Map<String, Object?> dark = v['dark']! as Map<String, Object?>;
    for (final String k in const <String>['surfaceStep', 'border']) {
      if (!dark.containsKey(k)) {
        errors.add('${t.name}: dark.$k required (null for none).');
        continue;
      }
      final Object? ref = dark[k];
      if (ref == null) continue;
      final String? name = _refName(ref);
      final _Token? target = name == null ? null : _lookup(name, t.name);
      if (target == null || target.type != 'color') {
        errors.add('${t.name}: dark.$k must reference a colour token.');
      }
    }
  }

  void _validateHaptic(_Token t) {
    final Object? v = t.value;
    if (v is! Map<String, Object?>) {
      errors.add('${t.name}: haptic \$value must be an object.');
      return;
    }
    if (v['severity'] is! int) {
      errors.add('${t.name}: severity (int) required.');
    }
    final Object? ios = v['ios'];
    if (ios is! Map<String, Object?> ||
        !const <String>{
          'impact',
          'selection',
          'notification',
        }.contains(ios['generator'])) {
      errors.add(
        '${t.name}: ios.generator must be impact/selection/notification.',
      );
    } else {
      if (ios['generator'] == 'impact' &&
          !const <String>{'light', 'medium', 'rigid'}.contains(ios['style'])) {
        errors.add('${t.name}: ios.style must be light/medium/rigid.');
      }
      if (ios['generator'] == 'notification' &&
          !const <String>{
            'success',
            'warning',
            'error',
          }.contains(ios['type'])) {
        errors.add('${t.name}: ios.type must be success/warning/error.');
      }
    }
    final Object? android = v['android'];
    if (android is! Map<String, Object?>) {
      errors.add('${t.name}: android mapping required.');
      return;
    }
    for (final String range in const <String>['api30', 'fallback']) {
      final Object? spec = android[range];
      if (spec is! Map<String, Object?>) {
        errors.add('${t.name}: android.$range required.');
        continue;
      }
      final Object? constants = spec['constants'];
      if (constants != null &&
          (constants is! List<Object?> ||
              constants.any(
                (Object? c) => !const <String>{
                  'KEYBOARD_TAP',
                  'CLOCK_TICK',
                  'CONFIRM',
                  'REJECT',
                }.contains(c),
              ))) {
        errors.add('${t.name}: android.$range.constants invalid.');
      }
      final Object? wave = spec['waveform'];
      if (wave != null) {
        if (wave is! Map<String, Object?> ||
            wave['timings'] is! List<Object?> ||
            wave['amplitudes'] is! List<Object?> ||
            (wave['timings']! as List<Object?>).length !=
                (wave['amplitudes']! as List<Object?>).length) {
          errors.add(
            '${t.name}: android.$range.waveform needs equal-length '
            'timings and amplitudes.',
          );
        }
      }
      if (constants == null && wave == null && spec['oneShot'] == null) {
        errors.add('${t.name}: android.$range has no effect.');
      }
    }
  }

  void _validateSound(_Token t) {
    final Object? v = t.value;
    if (v is! Map<String, Object?>) {
      errors.add('${t.name}: sound \$value must be an object.');
      return;
    }
    final Object? file = v['file'];
    if (file is! String || !RegExp(r'^gcw_[a-z0-9_]+$').hasMatch(file)) {
      errors.add('${t.name}: file must match gcw_<snake_case> (11 §6.1).');
    }
    final Object? maxMs = v['maxMs'];
    if (maxMs is! int || maxMs <= 0 || maxMs > 400) {
      errors.add('${t.name}: maxMs must be 1–400 (11 §1 rule 5).');
    }
    final Object? lufs = v['loudnessLufsM'];
    if (lufs is! num || lufs > -18) {
      errors.add('${t.name}: loudness must be ≤ −18 LUFS-M.');
    }
    if (v['truePeakDbtp'] is! num) {
      errors.add('${t.name}: truePeakDbtp required.');
    }
  }

  // ----------------------------------------------------------------- output

  String generate() {
    final StringBuffer out = StringBuffer()
      ..writeln('// GENERATED — do not edit.')
      ..writeln(
        '// Source: $_inputPath (version '
        '${(root[r'$extensions']! as Map<String, Object?>)['version']}).',
      )
      ..writeln('// Regenerate with: dart run tool/generate_tokens.dart')
      ..writeln()
      ..writeln('// ignore_for_file: public_member_api_docs')
      ..writeln()
      ..writeln("import 'dart:ui' show Brightness, Color, Offset;")
      ..writeln()
      ..writeln("import 'package:flutter/animation.dart' show Cubic;")
      ..writeln("import 'package:flutter/foundation.dart' show immutable;")
      ..writeln("import 'package:flutter/painting.dart' show BoxShadow;")
      ..writeln("import 'package:flutter/physics.dart' show SpringDescription;")
      ..writeln()
      ..writeln("import 'token_types.dart';")
      ..writeln();

    _emitColors(out);
    _emitTypography(out);
    _emitConstants(out, 'space', 'Space', '04 §4.1 spacing scale (4-pt base).');
    _emitConstants(
      out,
      'layout',
      'LayoutTokens',
      '04 §4.2–4.5 and 08 §1–2 layout values.',
    );
    _emitConstants(out, 'radius', 'Radii', '04 §5.1 radius scale.');
    _emitConstants(out, 'border', 'Borders', '04 §7 border widths.');
    _emitConstants(out, 'focus', 'FocusTokens', '04 §13.1 focus geometry.');
    _emitConstants(
      out,
      'size',
      'Sizes',
      '04 A.4 sizes: targets and fixed geometry.',
    );
    _emitIconSizes(out);
    _emitConstants(
      out,
      'illustration',
      'IllustrationTokens',
      '10 §4.3 illustration sizes and stroke.',
    );
    _emitElevation(out);
    _emitConstants(out, 'opacity', 'Opacities', '04 §13.2 opacity tokens.');
    _emitConstants(out, 'z', 'ZLayers', '04 §14 z-order.');
    _emitConstants(
      out,
      'motion',
      'Motion',
      '04 §15 / 06 §2 motion tokens. Springs use mass 1, stiffness '
          '(2π/response)² and damping 4π·ζ/response.',
    );
    _emitConstants(out, 'time', 'Times', '04 §15 timing tokens.');
    _emitHaptics(out);
    _emitSounds(out);
    for (final String group in tier3Groups) {
      final String cls = '${_pascal(group)}Tokens';
      _emitConstants(
        out,
        group,
        cls,
        groupDescriptions[group] ?? 'Tier-3 component tokens.',
      );
    }
    return out.toString();
  }

  Iterable<_Token> _inCategory(String cat) =>
      tokens.values.where((_Token t) => t.category == cat);

  void _doc(StringBuffer out, String? text, {String indent = '  '}) {
    if (text == null || text.isEmpty) return;
    out.writeln('$indent/// ${text.replaceAll('\n', ' ')}');
  }

  // -- colours

  void _emitColors(StringBuffer out) {
    final List<_Token> list = _inCategory('color').toList();
    final List<String> names = <String>[
      for (final _Token t in list) _member(t.localPath),
    ];
    final Map<String, bool> nullable = <String, bool>{};
    for (int i = 0; i < list.length; i++) {
      bool isNull = false;
      for (final String theme in const <String>['light', 'dark']) {
        if (resolveColor(list[i], theme) == null ||
            resolveHighContrast(list[i], theme) == null) {
          isNull = true;
        }
      }
      nullable[names[i]] = isNull;
    }

    out
      ..writeln('/// Semantic colours for one resolved theme (04 §8, A.1).')
      ..writeln('///')
      ..writeln(
        '/// Use [light], [dark] or [highContrast]; components read these',
      )
      ..writeln('/// fields, never literal colours (09 §1.2).')
      ..writeln('@immutable')
      ..writeln('class WaiterColors {')
      ..writeln('  const WaiterColors({')
      ..writeln('    required this.brightness,')
      ..writeln('    required this.isHighContrast,');
    for (final String n in names) {
      out.writeln('    required this.$n,');
    }
    out
      ..writeln('  });')
      ..writeln()
      ..writeln('  /// Theme this palette belongs to.')
      ..writeln('  final Brightness brightness;')
      ..writeln()
      ..writeln(
        '  /// Whether the high-contrast modifier (04 §10.1) is applied.',
      )
      ..writeln('  final bool isHighContrast;');
    for (int i = 0; i < list.length; i++) {
      out.writeln();
      _doc(out, '`${list[i].name}` — ${list[i].description ?? ''}'.trim());
      out.writeln(
        '  final Color${nullable[names[i]]! ? '?' : ''} ${names[i]};',
      );
    }

    void emitPalette(String id, String theme, bool hc, String doc) {
      out
        ..writeln()
        ..writeln('  /// $doc')
        ..writeln('  static const WaiterColors $id = WaiterColors(')
        ..writeln(
          '    brightness: Brightness.${theme == 'light' ? 'light' : 'dark'},',
        )
        ..writeln('    isHighContrast: $hc,');
      for (int i = 0; i < list.length; i++) {
        final Object? c = hc
            ? resolveHighContrast(list[i], theme)
            : resolveColor(list[i], theme);
        out.writeln('    ${names[i]}: ${_colorLiteral(c)},');
      }
      out.writeln('  );');
    }

    emitPalette('light', 'light', false, 'Light theme (04 §8.3).');
    emitPalette('dark', 'dark', false, 'Dark theme (04 §6.2, §8.3).');
    emitPalette(
      'lightHighContrast',
      'light',
      true,
      'Light theme with the high-contrast modifier (04 §10.1).',
    );
    emitPalette(
      'darkHighContrast',
      'dark',
      true,
      'Dark theme with the high-contrast modifier (04 §10.1).',
    );

    out
      ..writeln()
      ..writeln('  /// High-contrast palette for [brightness] (04 §10.1).')
      ..writeln('  static WaiterColors highContrast(Brightness brightness) =>')
      ..writeln('      brightness == Brightness.dark')
      ..writeln('          ? darkHighContrast')
      ..writeln('          : lightHighContrast;')
      ..writeln()
      ..writeln('  /// Resolves the palette for a theme and contrast setting.')
      ..writeln('  static WaiterColors resolve(')
      ..writeln('    Brightness brightness, {')
      ..writeln('    bool highContrast = false,')
      ..writeln('  }) {')
      ..writeln('    if (highContrast) {')
      ..writeln('      return WaiterColors.highContrast(brightness);')
      ..writeln('    }')
      ..writeln('    return brightness == Brightness.dark ? dark : light;')
      ..writeln('  }')
      ..writeln()
      ..writeln('  /// Interpolates for the theme cross-fade (04 §9 rule 2).')
      ..writeln(
        '  static WaiterColors lerp(WaiterColors a, WaiterColors b, double t) {',
      )
      ..writeln('    return WaiterColors(')
      ..writeln('      brightness: t < 0.5 ? a.brightness : b.brightness,')
      ..writeln(
        '      isHighContrast: t < 0.5 ? a.isHighContrast : b.isHighContrast,',
      );
    for (final String n in names) {
      out.writeln(
        nullable[n]!
            ? '      $n: a.$n == null || b.$n == null '
                  '? (t < 0.5 ? a.$n : b.$n) : Color.lerp(a.$n, b.$n, t),'
            : '      $n: Color.lerp(a.$n, b.$n, t)!,',
      );
    }
    out
      ..writeln('    );')
      ..writeln('  }')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  bool operator ==(Object other) =>')
      ..writeln('      other is WaiterColors &&')
      ..writeln('      other.brightness == brightness &&')
      ..writeln('      other.isHighContrast == isHighContrast &&');
    for (int i = 0; i < names.length; i++) {
      out.writeln(
        '      other.${names[i]} == ${names[i]}'
        '${i == names.length - 1 ? ';' : ' &&'}',
      );
    }
    out
      ..writeln()
      ..writeln('  @override')
      ..writeln('  int get hashCode => Object.hashAll(<Object?>[')
      ..writeln('    brightness,')
      ..writeln('    isHighContrast,');
    for (final String n in names) {
      out.writeln('    $n,');
    }
    out
      ..writeln('  ]);')
      ..writeln('}')
      ..writeln();
  }

  // -- typography

  void _emitTypography(StringBuffer out) {
    out
      ..writeln('/// Type scale (04 §3.2, A.2) and currency sizing (04 §3.4).')
      ..writeln('abstract final class TypeTokens {');
    final List<String> specs = <String>[];
    for (final _Token t in _inCategory('type')) {
      final String name = _member(t.localPath);
      out.writeln();
      _doc(out, '`${t.name}` — ${t.description ?? ''}'.trim());
      if (t.type == 'typography') {
        specs.add(name);
        final Map<String, Object?> v = t.value! as Map<String, Object?>;
        final double tracking = double.parse(
          _percentPattern.firstMatch(v['letterSpacing']! as String)!.group(1)!,
        );
        final Object? min = t.extensions['minSizeAfterShrink'];
        out
          ..writeln('  static const TypeSpec $name = TypeSpec(')
          ..writeln("    name: '${t.name}',")
          ..writeln("    fontFamily: '${v['fontFamily']}',")
          ..writeln('    fontWeight: ${v['fontWeight']},')
          ..writeln('    fontSize: ${_num(v['fontSize']! as num)},')
          ..writeln('    lineHeight: ${_num(v['lineHeight']! as num)},')
          ..writeln('    letterSpacingPercent: ${_num(tracking)},')
          ..writeln(
            '    tabularFigures: '
            '${(v['fontFeatures']! as List<Object?>).contains('tnum')},',
          )
          ..writeln('    maxScale: ${_num(t.extensions['maxScale']! as num)},');
        if (v['textTransform'] == 'uppercase') {
          out.writeln('    uppercase: true,');
        }
        if (min != null) {
          out.writeln('    minSizeAfterShrink: ${_num(min as num)},');
        }
        out.writeln('  );');
      } else {
        _emitScalar(out, t, name);
      }
    }
    out
      ..writeln()
      ..writeln('  /// Every text style token, in declaration order.')
      ..writeln('  static const List<TypeSpec> all = <TypeSpec>[');
    for (final String s in specs) {
      out.writeln('    $s,');
    }
    out
      ..writeln('  ];')
      ..writeln('}')
      ..writeln();
  }

  // -- generic constants

  void _emitConstants(
    StringBuffer out,
    String category,
    String className,
    String doc,
  ) {
    out
      ..writeln('/// $doc')
      ..writeln('abstract final class $className {');
    for (final _Token t in _inCategory(category)) {
      final String name = _member(t.localPath);
      out.writeln();
      _doc(out, '`${t.name}` — ${t.description ?? ''}'.trim());
      _emitScalar(out, t, name);
    }
    out
      ..writeln('}')
      ..writeln();
  }

  void _emitScalar(StringBuffer out, _Token t, String name) {
    switch (t.type) {
      case 'dimension':
        final Object v = resolveScalar(t)!;
        if (v is String) {
          final String px = _pxPattern.firstMatch(v)!.group(1)!;
          out
            ..writeln('  static double $name(double devicePixelRatio) =>')
            ..writeln('      ${_num(double.parse(px))} / devicePixelRatio;');
        } else {
          out.writeln('  static const double $name = ${_num(v as num)};');
        }
        final Object? compact = t.extensions['compactHeight'];
        if (compact != null) {
          out
            ..writeln()
            ..writeln('  /// `${t.name}` at compact height (< 700 pt).')
            ..writeln(
              '  static const double ${name}Compact = ${_num(compact as num)};',
            );
        }
        final Object? stroke = t.extensions['stroke'];
        if (stroke != null) {
          out
            ..writeln()
            ..writeln('  /// Stroke width of `${t.name}`.')
            ..writeln(
              '  static const double ${name}Stroke = ${_num(stroke as num)};',
            );
        }
      case 'number':
        final num v = resolveScalar(t)! as num;
        out.writeln(
          v is int
              ? '  static const int $name = $v;'
              : '  static const double $name = ${_num(v)};',
        );
      case 'duration':
        final String v = resolveScalar(t)! as String;
        out.writeln(
          '  static const Duration $name = '
          'Duration(milliseconds: ${_msPattern.firstMatch(v)!.group(1)});',
        );
      case 'cubicBezier':
        final List<Object?> v = t.value! as List<Object?>;
        out.writeln(
          '  static const Cubic $name = '
          'Cubic(${v.map((Object? e) => _num(e! as num)).join(', ')});',
        );
      case 'spring':
        final Map<String, Object?> v = t.value! as Map<String, Object?>;
        final double response = (v['response']! as num).toDouble();
        final double zeta = (v['damping']! as num).toDouble();
        final double omega = 2 * math.pi / response;
        out
          ..writeln(
            '  static const SpringDescription $name = SpringDescription(',
          )
          ..writeln('    mass: 1,')
          ..writeln('    stiffness: ${omega * omega},')
          ..writeln('    damping: ${2 * zeta * omega},')
          ..writeln('  );')
          ..writeln()
          ..writeln('  /// Response of `${t.name}` in seconds.')
          ..writeln(
            '  static const double ${name}Response = ${_num(response)};',
          )
          ..writeln()
          ..writeln('  /// Damping ratio ζ of `${t.name}`.')
          ..writeln(
            '  static const double ${name}DampingRatio = ${_num(zeta)};',
          );
      case 'color':
        out.writeln(
          '  static const Color $name = '
          '${_colorLiteral(resolveColor(t, 'light'))};',
        );
      default:
        errors.add('${t.name}: cannot emit ${t.type} as a constant.');
    }
  }

  // -- icon sizes

  void _emitIconSizes(StringBuffer out) {
    final List<_Token> steps = <_Token>[];
    _Token? grid;
    for (final _Token t in _inCategory('icon')) {
      if (t.localPath.single == 'grid') {
        grid = t;
      } else {
        steps.add(t);
      }
    }
    if (grid == null) {
      errors.add('icon.grid is required.');
      return;
    }
    out
      ..writeln(
        '/// Icon size tokens with size-compensated strokes (04 §11.2).',
      )
      ..writeln('enum IconSize {');
    for (int i = 0; i < steps.length; i++) {
      final _Token t = steps[i];
      _doc(out, '`${t.name}` — ${t.description ?? ''}'.trim());
      out.writeln(
        '  s${t.localPath.single}(${_num(t.value! as num)}, '
        '${_num(t.extensions['stroke']! as num)})'
        '${i == steps.length - 1 ? ';' : ','}',
      );
    }
    out
      ..writeln()
      ..writeln('  const IconSize(this.size, this.stroke);')
      ..writeln()
      ..writeln('  /// Rendered size in pt.')
      ..writeln('  final double size;')
      ..writeln()
      ..writeln('  /// Stroke width in pt at [size] (strokes never scale).')
      ..writeln('  final double stroke;')
      ..writeln()
      ..writeln('  /// ${grid.description}')
      ..writeln('  static const double grid = ${_num(grid.value! as num)};')
      ..writeln('}')
      ..writeln();
  }

  // -- elevation

  void _emitElevation(StringBuffer out) {
    final List<_Token> levels = _inCategory('elev').toList();
    String colorRef(Object? ref) {
      if (ref == null) return 'null';
      final _Token target = tokens[_refName(ref)!]!;
      return 'colors.${_member(target.localPath)}';
    }

    String shadowList(List<Object?> layers, {bool upward = false}) {
      if (layers.isEmpty) return '<BoxShadow>[]';
      final List<String> items = <String>[];
      for (final Object? l in layers) {
        final Map<String, Object?> s = l! as Map<String, Object?>;
        final num y = s['y']! as num;
        items.add(
          'BoxShadow(color: ${_colorLiteral(s['color'])}, '
          'offset: Offset(${_num(s['x']! as num)}, ${_num(upward ? -y : y)}), '
          'blurRadius: ${_num(s['blur']! as num)}, '
          'spreadRadius: ${_num(s['spread']! as num)})',
        );
      }
      return '<BoxShadow>[${items.join(', ')}]';
    }

    final List<String> fields = <String>[];
    final StringBuffer lightInit = StringBuffer();
    final StringBuffer darkInit = StringBuffer();
    _Token? brand;
    for (final _Token t in levels) {
      final Map<String, Object?> v = t.value! as Map<String, Object?>;
      final List<Object?> light = v['light']! as List<Object?>;
      if (light.any(
        (Object? l) => (l! as Map<String, Object?>)['color'] == 'brand',
      )) {
        brand = t;
        continue;
      }
      final String name = 'level${_pascal(t.localPath.join('-'))}';
      final Map<String, Object?> dark = v['dark']! as Map<String, Object?>;
      final List<String> variants = <String>[name];
      if (t.extensions['upward'] == true) variants.add('${name}Upward');
      for (final String field in variants) {
        fields.add(field);
        final bool upward = field.endsWith('Upward');
        lightInit.writeln(
          light.isEmpty
              ? '        $field: ElevationLevel.none,'
              : '        $field: ElevationLevel(shadows: '
                    '${shadowList(light, upward: upward)}),',
        );
        final bool flatDark =
            dark['surfaceStep'] == null && dark['border'] == null;
        darkInit.writeln(
          flatDark
              ? '        $field: ElevationLevel.none,'
              : '        $field: ElevationLevel(surface: '
                    '${colorRef(dark['surfaceStep'])}, outline: '
                    '${colorRef(dark['border'])}),',
        );
      }
    }
    if (brand == null) {
      errors.add('elev: a brand shadow token (color "brand") is required.');
      return;
    }
    final Map<String, Object?> brandLayer =
        ((brand.value! as Map<String, Object?>)['light']! as List<Object?>)
                .single!
            as Map<String, Object?>;
    final Map<String, Object?> brandDark =
        (brand.value! as Map<String, Object?>)['dark']! as Map<String, Object?>;

    out
      ..writeln('/// Elevation per theme (04 §6, A.5).')
      ..writeln('///')
      ..writeln('/// Light: shadows. Dark: no shadows; surface steps plus a')
      ..writeln('/// hairline outline (09 §2.4). Resolve from the active')
      ..writeln('/// [WaiterColors] so the high-contrast modifier propagates.')
      ..writeln('@immutable')
      ..writeln('class WaiterElevation {')
      ..writeln('  const WaiterElevation({')
      ..writeln('    required this.brightness,');
    for (final String f in fields) {
      out.writeln('    required this.$f,');
    }
    out
      ..writeln('    required this.cardOutline,')
      ..writeln('  });')
      ..writeln()
      ..writeln('  /// Resolves the elevation set for [colors].')
      ..writeln('  factory WaiterElevation.resolve(WaiterColors colors) {')
      ..writeln('    if (colors.brightness == Brightness.dark) {')
      ..writeln('      return WaiterElevation(')
      ..writeln('        brightness: Brightness.dark,')
      ..write(darkInit)
      ..writeln('        cardOutline: ${colorRef(brandDark['border'])},')
      ..writeln('      );')
      ..writeln('    }')
      ..writeln('    return const WaiterElevation(')
      ..writeln('        brightness: Brightness.light,')
      ..write(lightInit)
      ..writeln('        cardOutline: null,')
      ..writeln('    );')
      ..writeln('  }')
      ..writeln()
      ..writeln('  /// Theme of this set.')
      ..writeln('  final Brightness brightness;');
    for (final String f in fields) {
      final String token = f.startsWith('level')
          ? 'elev.${f.substring(5).replaceAll('Upward', '').toLowerCase()}'
          : f;
      out
        ..writeln()
        ..writeln(
          '  /// `$token`${f.endsWith('Upward') ? ' cast upward (sheets)' : ''}.',
        )
        ..writeln('  final ElevationLevel $f;');
    }
    out
      ..writeln()
      ..writeln('  /// `${brand.name}` dark treatment: 1-px outline, no glow.')
      ..writeln('  final Color? cardOutline;')
      ..writeln()
      ..writeln('  /// Whether this theme expresses elevation with shadows.')
      ..writeln('  bool get usesShadows => brightness == Brightness.light;')
      ..writeln()
      ..writeln('  /// `${brand.name}`: ${brand.description ?? ''}')
      ..writeln('  List<BoxShadow> cardBrand(Color brand) {')
      ..writeln(
        '    if (brightness == Brightness.dark) return const <BoxShadow>[];',
      )
      ..writeln('    return <BoxShadow>[')
      ..writeln('      BoxShadow(')
      ..writeln(
        '        color: brand.withValues(alpha: '
        '${_num(brandLayer['alpha']! as num)}),',
      )
      ..writeln(
        '        offset: const Offset(${_num(brandLayer['x']! as num)}, '
        '${_num(brandLayer['y']! as num)}),',
      )
      ..writeln('        blurRadius: ${_num(brandLayer['blur']! as num)},')
      ..writeln('        spreadRadius: ${_num(brandLayer['spread']! as num)},')
      ..writeln('      ),')
      ..writeln('    ];')
      ..writeln('  }')
      ..writeln()
      ..writeln('  /// Interpolates for the theme cross-fade.')
      ..writeln('  static WaiterElevation lerp(')
      ..writeln('    WaiterElevation a,')
      ..writeln('    WaiterElevation b,')
      ..writeln('    double t,')
      ..writeln('  ) {')
      ..writeln('    if (t == 0) return a;')
      ..writeln('    if (t == 1) return b;')
      ..writeln('    return WaiterElevation(')
      ..writeln('      brightness: t < 0.5 ? a.brightness : b.brightness,');
    for (final String f in fields) {
      out.writeln('      $f: ElevationLevel.lerp(a.$f, b.$f, t),');
    }
    out
      ..writeln(
        '      cardOutline: Color.lerp(a.cardOutline, b.cardOutline, t),',
      )
      ..writeln('    );')
      ..writeln('  }')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  bool operator ==(Object other) =>')
      ..writeln('      other is WaiterElevation &&')
      ..writeln('      other.brightness == brightness &&');
    for (final String f in fields) {
      out.writeln('      other.$f == $f &&');
    }
    out
      ..writeln('      other.cardOutline == cardOutline;')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  int get hashCode => Object.hash(')
      ..writeln('    brightness,');
    for (final String f in fields) {
      out.writeln('    $f,');
    }
    out
      ..writeln('    cardOutline,')
      ..writeln('  );')
      ..writeln('}')
      ..writeln();
  }

  // -- haptics

  void _emitHaptics(StringBuffer out) {
    final List<_Token> list = _inCategory('haptic').toList();
    final Map<String, Object?> rules = groupExtensions['haptic'] ?? const {};
    String androidSpec(Map<String, Object?> s) {
      final List<String> parts = <String>[];
      final Object? constants = s['constants'];
      if (constants is List<Object?>) {
        parts.add(
          'constants: <AndroidHapticConstant>[${constants.map((Object? c) => 'AndroidHapticConstant.${_camel((c! as String).toLowerCase().split('_'))}').join(', ')}]',
        );
      }
      final Object? wave = s['waveform'];
      if (wave is Map<String, Object?>) {
        parts.add(
          'waveform: VibrationWaveform(timingsMs: <int>${wave['timings']}, '
          'amplitudes: <int>${wave['amplitudes']})',
        );
      }
      final Object? delay = s['waveformDelayMs'];
      if (delay is int) parts.add('waveformDelayMs: $delay');
      final Object? oneShot = s['oneShot'];
      if (oneShot is Map<String, Object?>) {
        parts.add(
          'oneShot: VibrationOneShot(durationMs: ${oneShot['durationMs']}, '
          'amplitude: ${oneShot['amplitude']})',
        );
      }
      return 'AndroidHapticSpec(${parts.join(', ')})';
    }

    out
      ..writeln(
        '/// Haptic tokens with platform mapping (04 §16, 11 §2.1, §5).',
      )
      ..writeln('///')
      ..writeln(
        '/// Components never call platform haptics directly; they hand a',
      )
      ..writeln('/// token to the feedback service (09 §2.5, §7.8).')
      ..writeln('enum HapticToken {');
    for (int i = 0; i < list.length; i++) {
      final _Token t = list[i];
      final Map<String, Object?> v = t.value! as Map<String, Object?>;
      final Map<String, Object?> ios = v['ios']! as Map<String, Object?>;
      final Map<String, Object?> android =
          v['android']! as Map<String, Object?>;
      final List<String> iosParts = <String>[
        'generator: IosHapticGenerator.${ios['generator']}',
        if (ios['style'] != null) 'impactStyle: IosImpactStyle.${ios['style']}',
        if (ios['type'] != null)
          'notificationType: IosNotificationType.${ios['type']}',
        if (ios['intensities'] != null)
          'intensities: <double>[${(ios['intensities']! as List<Object?>).map((Object? e) => _num(e! as num)).join(', ')}]',
      ];
      _doc(out, '`${t.name}` — ${t.description ?? ''}'.trim());
      out
        ..writeln('  ${_member(t.localPath)}(')
        ..writeln("    'haptic.${t.localPath.join('.')}',")
        ..writeln('    HapticSpec(')
        ..writeln('      severity: ${v['severity']},')
        ..writeln('      ios: IosHapticSpec(${iosParts.join(', ')}),')
        ..writeln(
          '      androidApi30: '
          '${androidSpec(android['api30']! as Map<String, Object?>)},',
        )
        ..writeln(
          '      androidFallback: '
          '${androidSpec(android['fallback']! as Map<String, Object?>)},',
        );
      if (v['stepsMs'] is List<Object?>) {
        out.writeln('      stepsMs: <int>${v['stepsMs']},');
      }
      out
        ..writeln('    ),')
        ..writeln('  )${i == list.length - 1 ? ';' : ','}');
    }
    out
      ..writeln()
      ..writeln('  const HapticToken(this.id, this.spec);')
      ..writeln()
      ..writeln('  /// Token name, e.g. `haptic.success`.')
      ..writeln('  final String id;')
      ..writeln()
      ..writeln('  /// Platform mapping.')
      ..writeln('  final HapticSpec spec;')
      ..writeln()
      ..writeln(
        '  /// Keys coalesce to at most one haptic per this interval (11 T5).',
      )
      ..writeln(
        '  static const Duration keyCoalesce = '
        'Duration(milliseconds: ${rules['keyCoalesceMs']});',
      )
      ..writeln()
      ..writeln('  /// Two different haptics closer than this: the later,')
      ..writeln('  /// higher-severity one wins (11 T6).')
      ..writeln(
        '  static const Duration minSpacing = '
        'Duration(milliseconds: ${rules['minSpacingMs']});',
      )
      ..writeln('}')
      ..writeln();
  }

  // -- sounds

  void _emitSounds(StringBuffer out) {
    final List<_Token> list = _inCategory('sound').toList();
    out
      ..writeln('/// Sound tokens (04 §16, 11 §2.2, §6).')
      ..writeln('enum SoundToken {');
    for (int i = 0; i < list.length; i++) {
      final _Token t = list[i];
      final Map<String, Object?> v = t.value! as Map<String, Object?>;
      _doc(out, '`${t.name}` — ${t.description ?? ''}'.trim());
      out
        ..writeln('  ${_member(t.localPath)}(')
        ..writeln("    'sound.${t.localPath.join('.')}',")
        ..writeln('    SoundSpec(')
        ..writeln("      file: '${v['file']}',")
        ..writeln('      maxDuration: Duration(milliseconds: ${v['maxMs']}),')
        ..writeln('      loudnessLufsM: ${_num(v['loudnessLufsM']! as num)},')
        ..writeln('      truePeakDbtp: ${_num(v['truePeakDbtp']! as num)},')
        ..writeln('    ),')
        ..writeln('  )${i == list.length - 1 ? ';' : ','}');
    }
    out
      ..writeln()
      ..writeln('  const SoundToken(this.id, this.spec);')
      ..writeln()
      ..writeln('  /// Token name, e.g. `sound.success`.')
      ..writeln('  final String id;')
      ..writeln()
      ..writeln('  /// File and level data.')
      ..writeln('  final SoundSpec spec;')
      ..writeln('}')
      ..writeln();
  }

  // ---------------------------------------------------------------- helpers

  String _member(List<String> localPath) {
    final String name = _camel(
      localPath.expand((String s) => s.split('-')).toList(),
    );
    return RegExp(r'^\d').hasMatch(name) ? 's$name' : name;
  }

  static String _camel(List<String> parts) {
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      final String p = parts[i];
      if (p.isEmpty) continue;
      b.write(i == 0 ? p : p[0].toUpperCase() + p.substring(1));
    }
    return b.toString();
  }

  static String _pascal(String s) {
    final String c = _camel(s.split('-'));
    return c[0].toUpperCase() + c.substring(1);
  }

  static String _num(num v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  static int? _parseColor(Object? value) {
    if (value is! String) return null;
    final RegExpMatch? hex = _hexPattern.firstMatch(value);
    if (hex != null) return 0xFF000000 | int.parse(hex.group(1)!, radix: 16);
    final RegExpMatch? rgba = _rgbaPattern.firstMatch(value);
    if (rgba != null) {
      final List<int> rgb = <int>[
        for (int i = 1; i <= 3; i++) int.parse(rgba.group(i)!),
      ];
      final double a = double.parse(rgba.group(4)!);
      if (rgb.any((int c) => c > 255) || a > 1) return null;
      final int alpha = (a * 255).round();
      return (alpha << 24) | (rgb[0] << 16) | (rgb[1] << 8) | rgb[2];
    }
    return null;
  }

  static String _colorLiteral(Object? value) {
    if (value == null) return 'null';
    final int argb = _parseColor(value)!;
    return 'Color(0x${argb.toRadixString(16).toUpperCase().padLeft(8, '0')})';
  }
}

Future<void> main(List<String> args) async {
  final bool check = args.contains('--check');
  final File input = File(_inputPath);
  if (!input.existsSync()) {
    stderr.writeln('Run from the app root: $_inputPath not found.');
    exitCode = 1;
    return;
  }
  final Object? decoded = jsonDecode(await input.readAsString());
  if (decoded is! Map<String, Object?>) {
    stderr.writeln('$_inputPath: root must be an object.');
    exitCode = 1;
    return;
  }
  final _Generator gen = _Generator(decoded)
    ..collect()
    ..validate();
  final String source = gen.errors.isEmpty ? gen.generate() : '';
  if (gen.errors.isNotEmpty) {
    stderr.writeln('Token validation failed (${gen.errors.length}):');
    for (final String e in gen.errors) {
      stderr.writeln('  - $e');
    }
    exitCode = 1;
    return;
  }

  final Directory tmp = await Directory.systemTemp.createTemp('tokens');
  final File staged = File('${tmp.path}/tokens.g.dart');
  await staged.writeAsString(source);
  final ProcessResult fmt = await Process.run(
    Platform.resolvedExecutable,
    <String>['format', '--language-version=3.9', staged.path],
  );
  if (fmt.exitCode != 0) {
    stderr
      ..writeln('dart format failed:')
      ..writeln(fmt.stderr);
    exitCode = 1;
    return;
  }
  final String formatted = await staged.readAsString();
  await tmp.delete(recursive: true);

  final File output = File(_outputPath);
  if (check) {
    final bool upToDate =
        output.existsSync() && await output.readAsString() == formatted;
    if (!upToDate) {
      stderr.writeln('$_outputPath is out of date. Run the generator.');
      exitCode = 1;
      return;
    }
    stdout.writeln('$_outputPath is up to date (${gen.tokens.length} tokens).');
    return;
  }
  await output.writeAsString(formatted);
  stdout.writeln('Wrote $_outputPath (${gen.tokens.length} tokens).');
}
