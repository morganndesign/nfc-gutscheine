import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';

/// Visual state of an input container (05 §2.4–2.5 token tables).
enum FieldTone {
  /// Resting: 1 pt `border.control` (2 pt in high contrast, 13 · R06).
  rest,

  /// Focused / typing: 2 pt `color.focus.ring` inner stroke (13 · R17).
  focused,

  /// Error: 2 pt `color.danger`.
  error,

  /// Disabled: `bg.key` fill, no border.
  disabled,
}

/// Container decoration of TextField and CardNumberField: `bg.surface`,
/// `radius.s`, inner stroke per [FieldTone] (no layout shift), colour
/// changes cross-fade over `motion.duration.fast`.
class FieldContainer extends StatelessWidget {
  /// Creates a container.
  const FieldContainer({
    required this.tone,
    required this.height,
    required this.child,
    super.key,
  });

  /// State of the boundary.
  final FieldTone tone;

  /// Minimum height (56 TextField, 64 CardNumberField).
  final double height;

  /// Content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final WaiterColors c = theme.colors;
    final BorderSide side = switch (tone) {
      FieldTone.rest => BorderSide(
        color: c.borderControl,
        width: theme.inputBorderWidth,
      ),
      FieldTone.focused => BorderSide(
        color: c.focusRing,
        width: Borders.widthFocus,
      ),
      FieldTone.error => BorderSide(color: c.danger, width: Borders.widthFocus),
      FieldTone.disabled => BorderSide.none,
    };
    return AnimatedContainer(
      duration: Motion.durationFast,
      curve: Motion.easeStandard,
      alignment: AlignmentDirectional.centerStart,
      constraints: BoxConstraints(minHeight: height),
      decoration: BoxDecoration(
        color: tone == FieldTone.disabled ? c.bgKey : c.bgSurface,
        borderRadius: BorderRadius.circular(TextFieldTokens.radius),
        border: Border.fromBorderSide(side),
      ),
      child: child,
    );
  }
}

/// The static label above an input (`type.label`; never floating).
class FieldLabel extends StatelessWidget {
  /// Creates a label.
  const FieldLabel(this.text, {required this.color, super.key});

  /// Label text.
  final String text;

  /// `fg.secondary`, `fg.primary` when focused, `fg.tertiary` disabled.
  final Color color;

  @override
  Widget build(BuildContext context) =>
      ScaledText(text, type: TypeTokens.label, color: color);
}

/// Helper or error line below an input (`type.body.m`); errors lead with a
/// `circle-alert` icon.16 and use `color.danger`. The line grows and fades
/// in over `motion.duration.fast` (06 M02).
class FieldMessage extends StatefulWidget {
  /// Creates the line; renders nothing when both texts are `null`.
  const FieldMessage({super.key, this.error, this.helper});

  /// Error text (wins over [helper]).
  final String? error;

  /// Helper text.
  final String? helper;

  @override
  State<FieldMessage> createState() => _FieldMessageState();
}

class _FieldMessageState extends State<FieldMessage> {
  /// Every change of the shown line gets its own key, so a line that
  /// disappears and comes back while the previous switch still runs never
  /// shares a key with its fading-out copy.
  int _serial = 0;

  @override
  void didUpdateWidget(FieldMessage old) {
    super.didUpdateWidget(old);
    final bool changed =
        (old.error ?? old.helper) != (widget.error ?? widget.helper) ||
        (old.error == null) != (widget.error == null);
    if (changed) _serial++;
  }

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    final String? error = widget.error;
    final String? text = error ?? widget.helper;
    return AnimatedSize(
      duration: Motion.durationFast,
      curve: Motion.easeStandard,
      alignment: AlignmentDirectional.topStart,
      child: AnimatedSwitcher(
        duration: Motion.durationFast,
        child: text == null
            ? SizedBox(key: ValueKey<int>(_serial), width: double.infinity)
            : Padding(
                key: ValueKey<int>(_serial),
                padding: const EdgeInsets.only(top: TextFieldTokens.helperGap),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (error != null) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: Space.s1 / 2),
                        child: WaiterIconView(
                          WaiterIcon.circleAlert,
                          size: IconSize.s16,
                          color: c.danger,
                        ),
                      ),
                      const SizedBox(width: AmountDisplayTokens.messageIconGap),
                    ],
                    Expanded(
                      child: ScaledText(
                        text,
                        type: TypeTokens.bodyM,
                        color: error != null ? c.danger : c.fgSecondary,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
