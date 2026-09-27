import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/format/format.dart';
import '../core/platform/feedback_scope.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'money_context.dart';
import 'support/announce.dart';
import 'support/shake.dart';

/// Presentation state of the [AmountDisplay] (05 §2.2 states).
enum AmountDisplayState {
  /// Empty, entering or valid: implicit zeros `fg.tertiary`, typed digits
  /// `fg.primary`.
  entering,

  /// Amount above the balance: digits `color.danger`, message with
  /// `circle-alert`, QuickAmountChip; `haptic.warning`, a ±6 pt shake and an
  /// assertive announcement once when entering the state.
  overBalance,

  /// Above the maximum single redemption (after a 422): `color.danger`
  /// with the limit message; no shake.
  overLimit,

  /// Partial redemption disabled: the full balance in `fg.primary`, no
  /// placeholder, a `fg.secondary` caption.
  fixed,

  /// Redeeming (S08): value locked in `fg.primary`.
  locked,
}

/// The POS-style amount being entered (05 §2.2, 06 M12–M15).
///
/// [digits] is the typed digit string (`AmountEntry.digits`); the value is
/// digits ÷ 100. Placement of the symbol follows `MoneyFormat.parts`; the
/// symbol is set at 60 % on the same baseline with the locale's gap
/// (04 §3.4). The text shrinks in 2-pt steps to fit (min 40 pt) and is
/// never truncated or wrapped.
///
/// Motion: a typed digit slides in from 8 pt below and fades in (160 ms
/// `ease.decelerate`), existing digits move one slot left (160 ms
/// `ease.standard`); ⌫ reverses it; a clear fades the digits out right to
/// left; any other change (QuickAmountChip) and every change under Reduce
/// Motion cross-fades the whole string (160 ms). A new key retargets a
/// running roll-in.
///
/// Accessibility: the amount line is a polite live region labelled
/// `a11y.amount` with the spoken amount, debounced 400 ms so a burst of
/// keys is announced once; the message is its own static text and the
/// chip its own button (07 §5.5 reading order 5 → 6 → 7).
class AmountDisplay extends StatefulWidget {
  /// Creates the display.
  const AmountDisplay({
    required this.digits,
    required this.money,
    super.key,
    this.state = AmountDisplayState.entering,
    this.message,
    this.chip,
    this.overBalanceAnnouncement,
    this.shakeController,
    this.overBalanceEntryFeedback = true,
  });

  /// Typed digits without leading zeros (`''` = empty).
  final String digits;

  /// Currency and locale.
  final MoneyContext money;

  /// Presentation state.
  final AmountDisplayState state;

  /// Message slot text: `charge.overBalance`, `charge.maxSingle`, or the
  /// fixed-state caption `charge.fullOnly`.
  final String? message;

  /// QuickAmountChip shown in the message slot (over balance only).
  final Widget? chip;

  /// `a11y.overBalance` announced assertively when entering
  /// [AmountDisplayState.overBalance].
  final String? overBalanceAnnouncement;

  /// Limit-reached nudge (±3 pt) requested by the screen when the Keypad
  /// rejects an 8th digit.
  final ShakeController? shakeController;

  /// Whether entering [AmountDisplayState.overBalance] plays
  /// `haptic.warning` and the ±6 pt shake. `false` when the balance, not
  /// the amount, changed (03b §3.8: the screen plays `haptic.error`, no
  /// shake); the announcement is made either way.
  final bool overBalanceEntryFeedback;

  @override
  State<AmountDisplay> createState() => _AmountDisplayState();
}

class _AmountDisplayState extends State<AmountDisplay> {
  /// Distinguishes typed changes (per-glyph motion) from replacements
  /// (whole-string cross-fade).
  int _generation = 0;
  Set<String> _entering = const <String>{};
  final List<_Ghost> _ghosts = <_Ghost>[];
  Map<String, _PlacedGlyph> _lastLayout = const <String, _PlacedGlyph>{};
  int _ghostSerial = 0;
  final ShakeController _ownShake = ShakeController();
  Timer? _announceTimer;
  String? _liveLabel;

  int get _cents => widget.digits.isEmpty ? 0 : int.parse(widget.digits);

  @override
  void didUpdateWidget(AmountDisplay old) {
    super.didUpdateWidget(old);
    final String before = old.digits;
    final String after = widget.digits;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (before != after) {
      _classifyChange(before, after, reduceMotion);
      _scheduleAnnouncement();
    } else {
      _entering = const <String>{};
    }

    final bool wasOver = old.state == AmountDisplayState.overBalance;
    if (!wasOver && widget.state == AmountDisplayState.overBalance) {
      if (widget.overBalanceEntryFeedback) {
        context.haptic(HapticToken.warning);
        (widget.shakeController ?? _ownShake).shake();
      }
      final String? message = widget.overBalanceAnnouncement;
      if (message != null) announce(context, message, assertive: true);
    }
  }

  void _classifyChange(String before, String after, bool reduceMotion) {
    final bool typed =
        after.length > before.length &&
        after.length - before.length <= 2 &&
        after.startsWith(before);
    final bool deleted =
        before.length - after.length == 1 && before.startsWith(after);
    final bool cleared = after.isEmpty && before.length > 1;
    if (reduceMotion || !(typed || deleted || cleared)) {
      _generation++;
      _entering = const <String>{};
      _ghosts.clear();
      return;
    }
    _entering = <String>{
      for (int k = before.length; k < after.length; k++) _typedKey(k),
    };
    final List<String> removed = <String>[
      for (int k = before.length - 1; k >= after.length; k--) _typedKey(k),
    ];
    for (int i = 0; i < removed.length; i++) {
      final _PlacedGlyph? glyph = _lastLayout[removed[i]];
      if (glyph == null) continue;
      _ghosts.add(
        _Ghost(
          id: _ghostSerial++,
          glyph: glyph,
          duration: cleared ? Motion.durationFast : Motion.durationInstant,
          delay: cleared ? _clearStagger * i : Duration.zero,
        ),
      );
    }
  }

  /// Right-to-left stagger of the clear (06 M13).
  static const Duration _clearStagger = Duration(milliseconds: 15);

  void _scheduleAnnouncement() {
    _announceTimer?.cancel();
    _announceTimer = Timer(AmountDisplayTokens.announceDebounce, () {
      if (mounted) setState(() {});
    });
  }

  void _removeGhost(int id) {
    if (!mounted) return;
    setState(() => _ghosts.removeWhere((_Ghost g) => g.id == id));
  }

  @override
  void dispose() {
    _announceTimer?.cancel();
    _ownShake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final bool compact = context.layout.heightClass.isCompact;
    final TypeSpec amountType = compact
        ? TypeTokens.amountL
        : TypeTokens.amountXl;
    final TypeSpec symbolType = compact
        ? TypeTokens.currencyL
        : TypeTokens.currencyXl;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    // The live label follows the value only after the debounce, so a
    // burst of keys is announced once with its final value.
    final bool debouncing = _announceTimer?.isActive ?? false;
    if (!debouncing || _liveLabel == null) {
      _liveLabel = l10n.a11yAmount(widget.money.spoken(_cents));
    }
    final String liveLabel = _liveLabel!;

    final Widget line = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _AmountLayout layout = _AmountLayout.compute(
          context: context,
          parts: widget.money.parts(_cents),
          typedCount: widget.digits.length,
          state: widget.state,
          amountType: amountType,
          symbolType: symbolType,
          maxWidth: constraints.maxWidth,
          colors: c,
        );
        _lastLayout = <String, _PlacedGlyph>{
          for (final _PlacedGlyph g in layout.glyphs) g.key: g,
        };
        final Widget glyphs = SizedBox(
          width: constraints.maxWidth,
          height: layout.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (final _Ghost ghost in _ghosts)
                _ExitGlyph(
                  key: ValueKey<String>('ghost${ghost.id}'),
                  ghost: ghost,
                  offsetX: layout.originX,
                  onDone: () => _removeGhost(ghost.id),
                ),
              for (final _PlacedGlyph g in layout.glyphs)
                _MovingGlyph(
                  key: ValueKey<String>(g.key),
                  glyph: g,
                  originX: layout.originX,
                  entering: _entering.contains(g.key),
                  enterDelay: _entering.contains(g.key) && _isSecondOfPair(g)
                      ? _pairDelay
                      : Duration.zero,
                  slide: g.kind == _GlyphKind.typed,
                ),
            ],
          ),
        );
        return AnimatedSwitcher(
          duration: Motion.durationFast,
          switchInCurve: Motion.easeStandard,
          switchOutCurve: Motion.easeStandard,
          layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
            alignment: Alignment.center,
            children: <Widget>[...previous, ?current],
          ),
          child: KeyedSubtree(
            key: ValueKey<int>(reduceMotion ? -_generation - 1 : _generation),
            child: glyphs,
          ),
        );
      },
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            container: true,
            liveRegion: true,
            label: liveLabel,
            excludeSemantics: true,
            child: Shake(
              controller: widget.shakeController ?? _ownShake,
              child: line,
            ),
          ),
          const SizedBox(height: AmountDisplayTokens.messageGap),
          _MessageSlot(
            message: widget.message,
            danger:
                widget.state == AmountDisplayState.overBalance ||
                widget.state == AmountDisplayState.overLimit,
            chip: widget.chip,
          ),
        ],
      ),
    );
  }

  /// "00" enters two digits; the second follows 30 ms later (06 M12).
  static const Duration _pairDelay = Duration(milliseconds: 30);

  bool _isSecondOfPair(_PlacedGlyph g) =>
      _entering.length == 2 && g.key == _typedKey(widget.digits.length - 1);
}

String _typedKey(int index) => 't$index';

enum _GlyphKind { symbol, typed, placeholder, separator }

@immutable
class _PlacedGlyph {
  const _PlacedGlyph({
    required this.key,
    required this.kind,
    required this.text,
    required this.style,
    required this.x,
    required this.top,
  });

  final String key;
  final _GlyphKind kind;
  final String text;
  final TextStyle style;

  /// Offset from the start of the centred unit.
  final double x;
  final double top;
}

@immutable
class _Ghost {
  const _Ghost({
    required this.id,
    required this.glyph,
    required this.duration,
    required this.delay,
  });

  final int id;
  final _PlacedGlyph glyph;
  final Duration duration;
  final Duration delay;
}

/// Glyph positions of one amount at the size that fits (04 §3.4, §3.7).
class _AmountLayout {
  const _AmountLayout(this.glyphs, this.width, this.height, this.originX);

  final List<_PlacedGlyph> glyphs;
  final double width;
  final double height;

  /// Start x of the centred unit inside the available width.
  final double originX;

  static _AmountLayout compute({
    required BuildContext context,
    required MoneyParts parts,
    required int typedCount,
    required AmountDisplayState state,
    required TypeSpec amountType,
    required TypeSpec symbolType,
    required double maxWidth,
    required WaiterColors colors,
  }) {
    final WaiterTextStyles styles = context.textStyles;
    final double start = scaledFontSize(context, amountType);
    final bool danger =
        state == AmountDisplayState.overBalance ||
        state == AmountDisplayState.overLimit;
    final bool noPlaceholder =
        state == AmountDisplayState.fixed || state == AmountDisplayState.locked;
    final bool hasValue = typedCount > 0;

    Color colorFor(_GlyphKind kind, bool significant) {
      if (danger) return colors.danger;
      if (noPlaceholder) return colors.fgPrimary;
      return switch (kind) {
        _GlyphKind.symbol => hasValue ? colors.fgPrimary : colors.fgTertiary,
        _ => significant ? colors.fgPrimary : colors.fgTertiary,
      };
    }

    List<_PlacedGlyph> place(double size) {
      final double factor = size / amountType.fontSize;
      final TextStyle digitStyle = styles.at(amountType, size);
      final TextStyle symbolStyle = styles.at(
        symbolType,
        symbolType.fontSize * factor,
      );
      final double gap =
          size *
          (parts.spaced
              ? TypeTokens.currencyGapSpaced
              : TypeTokens.currencyGapTight);
      final double digitBaseline = _baseline(digitStyle);
      final double symbolTop = digitBaseline - _baseline(symbolStyle);

      final List<_PlacedGlyph> number = <_PlacedGlyph>[];
      int digitsRight = 0;
      final String text = parts.number;
      final List<_PlacedGlyph> reversed = <_PlacedGlyph>[];
      for (int i = text.length - 1; i >= 0; i--) {
        final String ch = text[i];
        final bool isDigit = ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
        final _GlyphKind kind;
        final String key;
        final bool significant;
        if (isDigit) {
          significant = digitsRight < typedCount;
          kind = significant ? _GlyphKind.typed : _GlyphKind.placeholder;
          key = significant
              ? _typedKey(typedCount - 1 - digitsRight)
              : 'z$digitsRight';
          digitsRight++;
        } else {
          kind = _GlyphKind.separator;
          significant = digitsRight < typedCount;
          key = 's$digitsRight';
        }
        reversed.add(
          _PlacedGlyph(
            key: key,
            kind: kind,
            text: ch,
            style: digitStyle.copyWith(color: colorFor(kind, significant)),
            x: 0,
            top: 0,
          ),
        );
      }
      number.addAll(reversed.reversed);

      final _PlacedGlyph symbol = _PlacedGlyph(
        key: 'sym',
        kind: _GlyphKind.symbol,
        text: parts.symbol,
        style: symbolStyle.copyWith(color: colorFor(_GlyphKind.symbol, true)),
        x: 0,
        top: symbolTop,
      );

      final List<_PlacedGlyph> ordered = parts.symbolLeading
          ? <_PlacedGlyph>[symbol, ...number]
          : <_PlacedGlyph>[...number, symbol];
      final List<_PlacedGlyph> placed = <_PlacedGlyph>[];
      double x = 0;
      for (int i = 0; i < ordered.length; i++) {
        final _PlacedGlyph g = ordered[i];
        final bool gapBefore =
            (!parts.symbolLeading && g.kind == _GlyphKind.symbol) ||
            (parts.symbolLeading && i == 1);
        if (gapBefore) x += gap;
        placed.add(
          _PlacedGlyph(
            key: g.key,
            kind: g.kind,
            text: g.text,
            style: g.style,
            x: x,
            top: g.top,
          ),
        );
        x += _advance(g.text, g.style);
      }
      return placed;
    }

    double widthOf(List<_PlacedGlyph> glyphs) =>
        glyphs.last.x + _advance(glyphs.last.text, glyphs.last.style);

    final double size = shrinkToFitSize(
      startSize: start,
      minSize: math.min(start, amountType.minSizeAfterShrink!),
      maxWidth: maxWidth,
      widthAt: (double s) => widthOf(place(s)),
    );
    final List<_PlacedGlyph> glyphs = place(size);
    final double width = widthOf(glyphs);
    final double height = size * amountType.height;
    final double origin = maxWidth.isFinite
        ? math.max(0, (maxWidth - width) / 2)
        : 0;
    return _AmountLayout(glyphs, width, height, origin);
  }

  static final Map<TextStyle, double> _baselines = <TextStyle, double>{};
  static final Map<(String, TextStyle), double> _advances =
      <(String, TextStyle), double>{};

  static TextPainter _painter(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    textScaler: TextScaler.noScaling,
  )..layout();

  static double _baseline(TextStyle style) {
    final TextStyle key = style.copyWith(color: const Color(0xFF000000));
    return _baselines[key] ??= () {
      final TextPainter p = _painter('0', key);
      final double b = p.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      p.dispose();
      return b;
    }();
  }

  static double _advance(String text, TextStyle style) {
    final TextStyle key = style.copyWith(color: const Color(0xFF000000));
    return _advances[(text, key)] ??= () {
      final TextPainter p = _painter(text, key);
      final double w = p.width;
      p.dispose();
      return w;
    }();
  }
}

/// A glyph at its slot; moves with 160 ms `ease.standard`, enters with a
/// slide + fade (typed digits) or a fade (placeholders, separators).
class _MovingGlyph extends StatefulWidget {
  const _MovingGlyph({
    required this.glyph,
    required this.originX,
    required this.entering,
    required this.enterDelay,
    required this.slide,
    super.key,
  });

  final _PlacedGlyph glyph;
  final double originX;
  final bool entering;
  final Duration enterDelay;
  final bool slide;

  @override
  State<_MovingGlyph> createState() => _MovingGlyphState();
}

class _MovingGlyphState extends State<_MovingGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: Motion.durationFast,
    value: widget.entering ? 0 : 1,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _enter,
    curve: Motion.easeDecelerate,
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    if (widget.entering) {
      if (widget.enterDelay == Duration.zero) {
        _enter.forward();
      } else {
        _delay = Timer(widget.enterDelay, () {
          if (mounted) _enter.forward();
        });
      }
    }
  }

  @override
  void didUpdateWidget(_MovingGlyph old) {
    super.didUpdateWidget(old);
    // A newer key retargets: a running roll-in jumps to its end (06 M12).
    if (!widget.entering && _enter.value < 1) {
      _delay?.cancel();
      _enter.value = 1;
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _curve.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _PlacedGlyph g = widget.glyph;
    return AnimatedPositioned(
      duration: Motion.durationFast,
      curve: Motion.easeStandard,
      left: widget.originX + g.x,
      top: g.top,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (BuildContext context, Widget? child) {
          final double t = _curve.value;
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(
                0,
                widget.slide ? AmountDisplayTokens.digitSlide * (1 - t) : 0,
              ),
              child: child,
            ),
          );
        },
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: g.style.color),
          duration: Motion.durationFast,
          curve: Motion.easeStandard,
          builder: (BuildContext context, Color? color, Widget? _) => RichText(
            text: TextSpan(
              text: g.text,
              style: g.style.copyWith(color: color),
            ),
            textScaler: TextScaler.noScaling,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}

/// A removed digit dropping 8 pt and fading out (06 M13).
class _ExitGlyph extends StatefulWidget {
  const _ExitGlyph({
    required this.ghost,
    required this.offsetX,
    required this.onDone,
    super.key,
  });

  final _Ghost ghost;
  final double offsetX;
  final VoidCallback onDone;

  @override
  State<_ExitGlyph> createState() => _ExitGlyphState();
}

class _ExitGlyphState extends State<_ExitGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: widget.ghost.duration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _exit,
    curve: Motion.easeAccelerate,
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _exit.addStatusListener((AnimationStatus s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    if (widget.ghost.delay == Duration.zero) {
      _exit.forward();
    } else {
      _delay = Timer(widget.ghost.delay, () {
        if (mounted) _exit.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _curve.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _PlacedGlyph g = widget.ghost.glyph;
    return Positioned(
      left: widget.offsetX + g.x,
      top: g.top,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _curve,
          builder: (BuildContext context, Widget? child) => Opacity(
            opacity: 1 - _curve.value,
            child: Transform.translate(
              offset: Offset(0, AmountDisplayTokens.digitSlide * _curve.value),
              child: child,
            ),
          ),
          child: RichText(
            text: TextSpan(text: g.text, style: g.style),
            textScaler: TextScaler.noScaling,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}

/// Message slot ④ + chip ⑤ below the amount (05 §2.2): min 40 pt high,
/// `type.body.m` with an `icon.16` in danger states; enters with a fade
/// and 4-pt rise (06 M14).
class _MessageSlot extends StatelessWidget {
  const _MessageSlot({
    required this.message,
    required this.danger,
    required this.chip,
  });

  final String? message;
  final bool danger;
  final Widget? chip;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    final Color color = danger ? c.danger : c.fgSecondary;
    final String? text = message;
    final Widget content = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.s2,
      children: <Widget>[
        if (text != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (danger) ...<Widget>[
                WaiterIconView(
                  WaiterIcon.circleAlert,
                  size: IconSize.s16,
                  color: color,
                ),
                const SizedBox(width: AmountDisplayTokens.messageIconGap),
              ],
              Flexible(
                child: ScaledText(
                  text,
                  type: TypeTokens.bodyM,
                  color: color,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ?chip,
      ],
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AmountDisplayTokens.messageMinHeight,
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: Motion.durationFast,
          switchInCurve: Motion.easeDecelerate,
          transitionBuilder: (Widget child, Animation<double> animation) =>
              FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
          child: KeyedSubtree(
            key: ValueKey<bool>(text != null || chip != null),
            child: text == null && chip == null
                ? const SizedBox.shrink()
                : content,
          ),
        ),
      ),
    );
  }
}
