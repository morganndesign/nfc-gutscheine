import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format/format.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'support/announce.dart';
import 'support/field_parts.dart';
import 'support/shake.dart';

/// Manual entry of the 16-digit card number via the card-number Keypad
/// (05 §2.5). Read-only for the system keyboard.
///
/// Geist Mono (`type.cardNumber`) in four groups of four with a 12-pt group
/// gap; empty cells show "·" in `fg.tertiary`; a 2 × 24 pt caret after the
/// last digit blinks 1 s on / 1 s off (steady under Reduce Motion). New
/// digits fade in over 90 ms. The line shrinks in 2-pt steps (min 20 pt) to
/// fit. Border: 1 pt `border.control` when empty or [loading], 2 pt
/// `focus.ring` while typing, 2 pt `danger` with [errorText].
/// Each accepted digit is echoed politely; the value reads in groups.
/// Long press offers the system Paste action ([onPaste]).
class CardNumberField extends StatefulWidget {
  /// Creates the field.
  const CardNumberField({
    required this.digits,
    super.key,
    this.errorText,
    this.loading = false,
    this.onPaste,
    this.shakeController,
  });

  /// Typed digits (`CardNumberEntry.digits`).
  final String digits;

  /// Error text (`manual.errorInvalid`, not found, `manual.errorPaste`).
  final String? errorText;

  /// Lookup in flight: digits `fg.secondary`, resting border.
  final bool loading;

  /// Receives the clipboard text chosen via Paste; the screen applies the
  /// paste rule (`CardNumberEntry.paste`).
  final ValueChanged<String>? onPaste;

  /// Limit-reached nudge / error shake.
  final ShakeController? shakeController;

  @override
  State<CardNumberField> createState() => _CardNumberFieldState();
}

class _CardNumberFieldState extends State<CardNumberField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: CardNumberFieldTokens.caretBlink * 2,
  );
  final ContextMenuController _menu = ContextMenuController();

  static const int _groupSize = 4;

  /// "·" U+00B7 for empty cells (05 §2.5).
  static const String _emptyCell = '·';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBlink();
  }

  @override
  void didUpdateWidget(CardNumberField old) {
    super.didUpdateWidget(old);
    _syncBlink();
    if (widget.digits.length > old.digits.length &&
        widget.digits.startsWith(old.digits)) {
      announce(
        context,
        Spoken.characters(widget.digits.substring(old.digits.length)),
      );
    }
  }

  void _syncBlink() {
    final bool steady =
        MediaQuery.disableAnimationsOf(context) || widget.loading;
    if (steady) {
      _blink
        ..stop()
        ..value = 0;
    } else if (!_blink.isAnimating) {
      _blink.repeat();
    }
  }

  @override
  void dispose() {
    _menu.remove();
    _blink.dispose();
    super.dispose();
  }

  void _showPaste(Offset globalPosition) {
    final ValueChanged<String>? onPaste = widget.onPaste;
    if (onPaste == null) return;
    _menu.show(
      context: context,
      contextMenuBuilder: (BuildContext menuContext) =>
          AdaptiveTextSelectionToolbar.buttonItems(
            anchors: TextSelectionToolbarAnchors(primaryAnchor: globalPosition),
            buttonItems: <ContextMenuButtonItem>[
              ContextMenuButtonItem(
                type: ContextMenuButtonType.paste,
                onPressed: () async {
                  _menu.remove();
                  final ClipboardData? data = await Clipboard.getData(
                    Clipboard.kTextPlain,
                  );
                  final String? text = data?.text;
                  if (text != null) onPaste(text);
                },
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final String digits = widget.digits;
    final FieldTone tone = widget.errorText != null
        ? FieldTone.error
        : widget.loading || digits.isEmpty
        ? FieldTone.rest
        : FieldTone.focused;

    final Widget line = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const TypeSpec type = TypeTokens.cardNumber;
        double advanceAt(double size) {
          final TextPainter p = TextPainter(
            text: TextSpan(text: '0', style: context.textStyles.at(type, size)),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
          )..layout();
          final double w = p.width;
          p.dispose();
          return w;
        }

        const int groups = CardNumber.length ~/ _groupSize;
        double widthAt(double size) =>
            advanceAt(size) * CardNumber.length +
            CardNumberFieldTokens.groupGap * (groups - 1) +
            CardNumberFieldTokens.caretWidth;
        final double start = scaledFontSize(context, type);
        final double size = shrinkToFitSize(
          startSize: start,
          minSize: math.min(start, type.minSizeAfterShrink!),
          maxWidth: constraints.maxWidth,
          widthAt: widthAt,
        );
        final double cell = advanceAt(size);
        final TextStyle style = context.textStyles.at(type, size);
        final Color digitColor = widget.loading ? c.fgSecondary : c.fgPrimary;

        double cellX(int index) =>
            index * cell +
            (index ~/ _groupSize) * CardNumberFieldTokens.groupGap;
        final int caretIndex = math.min(digits.length, CardNumber.length);
        final double caretX = digits.length >= CardNumber.length
            ? cellX(CardNumber.length - 1) + cell
            : cellX(caretIndex);
        final double height = size * type.height;

        return SizedBox(
          height: height,
          width: widthAt(size),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (int i = 0; i < CardNumber.length; i++)
                Positioned(
                  left: cellX(i),
                  top: 0,
                  width: cell,
                  height: height,
                  child: i < digits.length
                      ? TweenAnimationBuilder<double>(
                          key: ValueKey<String>('d$i${digits[i]}'),
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: Motion.durationInstant,
                          builder: (BuildContext context, double t, _) =>
                              Opacity(
                                opacity: t,
                                child: _Cell(
                                  digits[i],
                                  style.copyWith(color: digitColor),
                                ),
                              ),
                        )
                      : _Cell(_emptyCell, style.copyWith(color: c.fgTertiary)),
                ),
              if (!widget.loading)
                Positioned(
                  left: caretX - CardNumberFieldTokens.caretWidth / 2,
                  top: (height - CardNumberFieldTokens.caretHeight) / 2,
                  child: FadeTransition(
                    opacity: _blink.drive(_BlinkTween()),
                    child: Container(
                      width: CardNumberFieldTokens.caretWidth,
                      height: CardNumberFieldTokens.caretHeight,
                      color: c.fgPrimary,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    return Shake(
      controller: widget.shakeController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ExcludeSemantics(
            child: FieldLabel(l10n.manualTitle, color: c.fgSecondary),
          ),
          const SizedBox(height: TextFieldTokens.labelGap),
          Semantics(
            textField: true,
            readOnly: true,
            label: l10n.manualTitle,
            value: Spoken.cardNumber(digits),
            hint: l10n.manualHelper,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: (LongPressStartDetails d) =>
                  _showPaste(d.globalPosition),
              child: FieldContainer(
                tone: tone,
                height: CardNumberFieldTokens.height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CardNumberFieldTokens.paddingHorizontal,
                  ),
                  child: line,
                ),
              ),
            ),
          ),
          FieldMessage(error: widget.errorText),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, this.style);

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Center(
    child: RichText(
      text: TextSpan(text: text, style: style),
      textScaler: TextScaler.noScaling,
      maxLines: 1,
      softWrap: false,
    ),
  );
}

/// 1 s on, 1 s off.
class _BlinkTween extends Animatable<double> {
  @override
  double transform(double t) => t < 0.5 ? 1 : 0;
}
