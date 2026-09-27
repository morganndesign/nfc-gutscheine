import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'button_label.dart';
import 'spinner.dart';
import 'support/delayed_presence.dart';
import 'support/focus_ring.dart';
import 'support/pressable.dart';
import 'support/shape.dart';

/// Size variants of filled buttons (05 §1.0).
enum ButtonSize {
  /// 64 pt (56 at compact height), `radius.l`, `type.label.l`, `icon.24`,
  /// full width.
  large,

  /// 56 pt, `radius.m`, `type.label`, `icon.20`; hugs (min 120) or full
  /// width.
  regular,
}

/// Progress of the action a button started (05 §1.1 states).
enum ButtonStatus {
  /// Ready.
  idle,

  /// Request in flight: inert, pressed look for up to 150 ms, then Spinner.
  loading,

  /// Loading for more than 8 s (S08): Spinner + `redeem.slow`.
  slow,

  /// Hand-off to the next screen: the spinner cross-fades to `circle-check`
  /// for 160 ms (only when a screen change follows).
  success,
}

/// Colours of one filled-button family per state.
@immutable
class _FilledColors {
  const _FilledColors({
    required this.fill,
    required this.pressedFill,
    required this.foreground,
    this.outline,
  });

  final Color fill;
  final Color pressedFill;
  final Color foreground;
  final Color? outline;
}

/// The single most important action of a screen (05 §1.1).
///
/// Activation on touch-up inside; a move of more than 16 pt outside
/// cancels. While [status] is not [ButtonStatus.idle] the button is inert
/// (double activation impossible). Labels carrying an amount break at
/// " · " ([ButtonLabel]). Disabled buttons stay readable by screen readers
/// with [disabledReason] as hint.
class PrimaryButton extends StatelessWidget {
  /// Creates a primary button.
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.size = ButtonSize.large,
    this.icon,
    this.status = ButtonStatus.idle,
    this.semanticLabel,
    this.disabledReason,
    this.fullWidth = true,
    this.loadingLabel,
    this.focusNode,
  });

  /// Visible label (verb + object, amounts pre-formatted).
  final String label;

  /// Shown next to the Spinner while [status] is [ButtonStatus.loading]
  /// (S08: `charge.redeeming`, 03b §3.1 / 09 §4.4); `null` shows the
  /// Spinner alone.
  final String? loadingLabel;

  /// Keyboard focus node — the screen's Enter/Return target (05 §1.1).
  final FocusNode? focusNode;

  /// Action; `null` renders the disabled state.
  final VoidCallback? onPressed;

  /// Size variant.
  final ButtonSize size;

  /// Optional leading icon.
  final WaiterIcon? icon;

  /// Action progress.
  final ButtonStatus status;

  /// Accessible label when it differs from [label] (spoken amounts).
  final String? semanticLabel;

  /// Hint read when disabled ("Enter amount", over-balance message).
  final String? disabledReason;

  /// Full content width (regular size only; large is always full width).
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    return _FilledButton(
      label: label,
      onPressed: onPressed,
      size: size,
      icon: icon,
      status: status,
      semanticLabel: semanticLabel,
      disabledReason: disabledReason,
      fullWidth: fullWidth,
      loadingLabel: loadingLabel,
      focusNode: focusNode,
      colors: _FilledColors(
        fill: c.actionPrimary,
        pressedFill: c.actionPrimaryPressed,
        foreground: c.fgOnAccent,
      ),
    );
  }
}

/// A lower-importance real alternative (05 §1.2): `bg.key` fill,
/// `fg.primary` label; high contrast adds a 1-pt `border.control` outline.
class SecondaryButton extends StatelessWidget {
  /// Creates a secondary button.
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.size = ButtonSize.regular,
    this.icon,
    this.status = ButtonStatus.idle,
    this.semanticLabel,
    this.disabledReason,
    this.fullWidth = true,
  });

  /// Visible label.
  final String label;

  /// Action; `null` renders the disabled state.
  final VoidCallback? onPressed;

  /// Size variant.
  final ButtonSize size;

  /// Optional leading icon.
  final WaiterIcon? icon;

  /// Action progress.
  final ButtonStatus status;

  /// Accessible label when it differs from [label].
  final String? semanticLabel;

  /// Hint read when disabled.
  final String? disabledReason;

  /// Full width (default) or hug content with a 120-pt minimum.
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final WaiterColors c = theme.colors;
    return _FilledButton(
      label: label,
      onPressed: onPressed,
      size: size,
      icon: icon,
      status: status,
      semanticLabel: semanticLabel,
      disabledReason: disabledReason,
      fullWidth: fullWidth,
      colors: _FilledColors(
        fill: c.bgKey,
        pressedFill: c.bgKeyPressed,
        foreground: c.fgPrimary,
        outline: theme.outlinesControls ? c.borderControl : null,
      ),
    );
  }
}

/// Confirms a destructive action — only in the sign-out Dialog (05 §1.4):
/// `color.danger` fill, `color.fg.onDanger` label, regular size, full
/// dialog width, no icon.
class DangerButton extends StatelessWidget {
  /// Creates a danger button.
  const DangerButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.status = ButtonStatus.idle,
  });

  /// Visible label ("Sign out").
  final String label;

  /// Action.
  final VoidCallback onPressed;

  /// Action progress (sign-out revokes the token server-side).
  final ButtonStatus status;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    return _FilledButton(
      label: label,
      onPressed: onPressed,
      size: ButtonSize.regular,
      status: status,
      fullWidth: true,
      colors: _FilledColors(
        fill: c.danger,
        pressedFill: c.dangerPressed,
        foreground: c.fgOnDanger,
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  const _FilledButton({
    required this.label,
    required this.onPressed,
    required this.size,
    required this.status,
    required this.fullWidth,
    required this.colors,
    this.icon,
    this.semanticLabel,
    this.disabledReason,
    this.loadingLabel,
    this.focusNode,
  });

  final String label;
  final String? loadingLabel;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;
  final ButtonSize size;
  final WaiterIcon? icon;
  final ButtonStatus status;
  final String? semanticLabel;
  final String? disabledReason;
  final bool fullWidth;
  final _FilledColors colors;

  bool get _large => size == ButtonSize.large;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    final double height = _large
        ? context.layout.largeButtonHeight
        : ButtonTokens.regularHeight;
    final double radius = _large
        ? ButtonTokens.largeRadius
        : ButtonTokens.regularRadius;
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final bool enabled = onPressed != null;
    final bool busy =
        status == ButtonStatus.loading || status == ButtonStatus.slow;
    final bool inert = status != ButtonStatus.idle;
    final Color foreground = enabled ? colors.foreground : c.fgTertiary;

    return DelayedPresence(
      active: busy,
      builder: (BuildContext context, bool spinnerVisible) {
        return Pressable(
          onPressed: onPressed,
          focusNode: focusNode,
          inert: inert,
          forcePressed: busy && !spinnerVisible,
          pressedScale: Motion.pressScaleButton,
          semanticsLabel: semanticLabel ?? label,
          semanticsHint: enabled ? null : disabledReason,
          builder: (BuildContext context, PressVisual visual) {
            final Color fill = enabled
                ? Color.lerp(
                    colors.fill,
                    colors.pressedFill,
                    visual.pressAmount,
                  )!
                : c.bgKey;
            return _Surface(
              radius: borderRadius,
              fill: fill,
              outline: colors.outline,
              hovered: visual.hovered && enabled,
              focused: visual.focused,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: height,
                  minWidth: fullWidth || _large
                      ? double.infinity
                      : ButtonTokens.regularMinWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _large
                        ? ButtonTokens.largePaddingHorizontal
                        : ButtonTokens.regularPaddingHorizontal,
                    vertical: ButtonTokens.labelPaddingVerticalMin,
                  ),
                  child: Center(
                    widthFactor: fullWidth || _large ? null : 1,
                    heightFactor: 1,
                    child: _ButtonContent(
                      label: label,
                      icon: icon,
                      large: _large,
                      foreground: foreground,
                      status: status,
                      spinnerVisible: spinnerVisible,
                      loadingLabel: loadingLabel,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.radius,
    required this.fill,
    required this.hovered,
    required this.focused,
    required this.child,
    this.outline,
  });

  final BorderRadius radius;
  final Color fill;
  final Color? outline;
  final bool hovered;
  final bool focused;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Color color = hovered
        ? Color.alphaBlend(context.colors.stateHover, fill)
        : fill;
    return FocusRing(
      visible: focused,
      radius: radius,
      child: AnimatedContainer(
        duration: Motion.durationFast,
        curve: Motion.easeStandard,
        decoration: ShapeDecoration(
          color: color,
          shape: waiterShape(context, radius, side: innerSide(outline)),
        ),
        child: child,
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.large,
    required this.foreground,
    required this.status,
    required this.spinnerVisible,
    required this.loadingLabel,
  });

  final String label;
  final String? loadingLabel;
  final WaiterIcon? icon;
  final bool large;
  final Color foreground;
  final ButtonStatus status;
  final bool spinnerVisible;

  @override
  Widget build(BuildContext context) {
    final TypeSpec type = large ? TypeTokens.labelL : TypeTokens.label;
    final bool success = status == ButtonStatus.success;
    final bool showIndicator = spinnerVisible || success;
    final Widget text = ButtonLabel(label, type: type, color: foreground);
    final Widget labelRow = icon == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              WaiterIconView(
                icon!,
                size: large ? IconSize.s24 : IconSize.s20,
                color: foreground,
              ),
              const SizedBox(width: ButtonTokens.regularIconGap),
              Flexible(child: text),
            ],
          );

    final Widget indicator = success
        ? WaiterIconView(WaiterIcon.circleCheck, color: foreground)
        : _Busy(
            text: status == ButtonStatus.slow
                ? AppLocalizations.of(context).redeemSlow
                : loadingLabel,
            // 05 §1.1: "Connection slow" is set in `type.label`.
            type: status == ButtonStatus.slow ? TypeTokens.label : type,
            color: foreground,
          );

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        AnimatedOpacity(
          opacity: showIndicator ? 0 : 1,
          duration: Motion.durationInstant,
          curve: Motion.easeAccelerate,
          child: labelRow,
        ),
        AnimatedOpacity(
          opacity: showIndicator ? 1 : 0,
          duration: Motion.durationFast,
          curve: Motion.easeDecelerate,
          child: AnimatedSwitcher(
            duration: Motion.durationFast,
            child: showIndicator
                ? KeyedSubtree(key: ValueKey<bool>(success), child: indicator)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.text, required this.type, required this.color});

  /// Text beside the Spinner: the loading label or `redeem.slow`.
  final String? text;
  final TypeSpec type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Widget spinner = Spinner(color: color);
    final String? label = text;
    if (label == null) return spinner;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        spinner,
        const SizedBox(width: ButtonTokens.largeIconGap),
        Flexible(
          child: ScaledText(
            label,
            type: type,
            color: color,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Low-emphasis text action (05 §1.3): label only, a 44-pt `bg.key` pill
/// appears while pressed; 56-pt target, hug width (min 120), never
/// underlined or coloured. [isLink] gives the role link (web pages).
class TertiaryButton extends StatelessWidget {
  /// Creates a tertiary button.
  const TertiaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.large = false,
    this.isLink = false,
    this.semanticLabel,
  });

  /// Visible label.
  final String label;

  /// Action; `null` renders the disabled state.
  final VoidCallback? onPressed;

  /// `type.label.l` when stacked under a large PrimaryButton.
  final bool large;

  /// Role link instead of button.
  final bool isLink;

  /// Accessible label when it differs from [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(ButtonTokens.tertiaryRadius),
    );
    final bool enabled = onPressed != null;
    return Pressable(
      onPressed: onPressed,
      isLink: isLink,
      semanticsLabel: semanticLabel ?? label,
      builder: (BuildContext context, PressVisual visual) {
        final Color fill = Color.lerp(
          c.bgKey.withValues(alpha: 0),
          c.bgKey,
          visual.pressAmount,
        )!;
        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: Sizes.targetMin,
            minWidth: ButtonTokens.tertiaryMinWidth,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: FocusRing(
              visible: visual.focused,
              radius: radius,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: visual.hovered && enabled
                      ? Color.alphaBlend(c.stateHover, fill)
                      : fill,
                  shape: waiterShape(context, radius),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: ButtonTokens.tertiaryPressedFillHeight,
                    minWidth: ButtonTokens.tertiaryMinWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ButtonTokens.tertiaryPaddingHorizontal,
                    ),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: ScaledText(
                        label,
                        type: large ? TypeTokens.labelL : TypeTokens.label,
                        color: enabled ? c.fgPrimary : c.fgTertiary,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
