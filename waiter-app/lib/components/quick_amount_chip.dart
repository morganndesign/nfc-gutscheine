import 'package:flutter/widgets.dart';

import '../core/platform/feedback_scope.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'button_label.dart';
import 'money_context.dart';
import 'support/focus_ring.dart';
import 'support/pressable.dart';
import 'support/shape.dart';

/// Which correction a [QuickAmountChip] offers.
enum QuickAmount {
  /// `charge.useBalance` — over balance (05 §2.3).
  balance,

  /// `charge.useMax` — above the maximum single redemption (03b R10).
  maximum,
}

/// One-tap correction of the typed amount: "Use balance · € 32,50"
/// (05 §2.3, 06 M15).
///
/// 40-pt visual (`size.chip`), 56-pt target (8 pt above and below),
/// `radius.xs`, `bg.key` (+ 1-pt `border.control` in high contrast),
/// pressed `bg.keyPressed` and scale 0.97. Enters with a fade and scale
/// 0.92 → 1 from its leading edge (fade only under Reduce Motion).
/// Tapping plays `haptic.select` (11 E35) and calls [onPressed]; the screen
/// replaces the amount and removes the chip.
class QuickAmountChip extends StatefulWidget {
  /// Creates a chip.
  const QuickAmountChip({
    required this.cents,
    required this.money,
    required this.onPressed,
    super.key,
    this.kind = QuickAmount.balance,
  });

  /// The exact amount the chip applies.
  final int cents;

  /// Formatting context.
  final MoneyContext money;

  /// Applies the amount.
  final VoidCallback onPressed;

  /// Balance or maximum.
  final QuickAmount kind;

  @override
  State<QuickAmountChip> createState() => _QuickAmountChipState();
}

class _QuickAmountChipState extends State<QuickAmountChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: Motion.durationFast,
  )..forward();
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _enter,
    curve: Motion.easeDecelerate,
  );

  /// Entry scale of 06 M15.
  static const double _enterScale = 0.92;

  @override
  void dispose() {
    _curve.dispose();
    _enter.dispose();
    super.dispose();
  }

  String _label(AppLocalizations l10n, String amount) => switch (widget.kind) {
    QuickAmount.balance => l10n.chargeUseBalance(amount),
    QuickAmount.maximum => l10n.chargeUseMax(amount),
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterTheme theme = context.waiter;
    final WaiterColors c = theme.colors;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(ChipTokens.radius),
    );
    final String label = _label(l10n, widget.money.format(widget.cents));
    final String spoken = _label(
      l10n,
      widget.money.spoken(widget.cents),
    ).replaceFirst(labelAmountSeparator, ', ');

    final Widget chip = Pressable(
      onPressed: () {
        context.haptic(HapticToken.select);
        widget.onPressed();
      },
      pressedScale: Motion.pressScaleChip,
      semanticsLabel: spoken,
      builder: (BuildContext context, PressVisual visual) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: ChipTokens.target),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: FocusRing(
            visible: visual.focused,
            radius: radius,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: Color.lerp(c.bgKey, c.bgKeyPressed, visual.pressAmount),
                shape: waiterShape(
                  context,
                  radius,
                  side: innerSide(
                    theme.outlinesControls ? c.borderControl : null,
                  ),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: ChipTokens.height),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ChipTokens.paddingHorizontal,
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: ScaledText(
                      label,
                      type: TypeTokens.label,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return FadeTransition(
      opacity: _curve,
      child: reduceMotion
          ? chip
          : ScaleTransition(
              scale: Tween<double>(begin: _enterScale, end: 1).animate(_curve),
              alignment: AlignmentDirectional.centerStart.resolve(
                Directionality.of(context),
              ),
              child: chip,
            ),
    );
  }
}
