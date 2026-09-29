import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'buttons.dart';
import 'snackbar.dart';
import 'support/shape.dart';

/// The answer of a [WaiterDialog].
enum DialogChoice {
  /// The changing action on top (Sign out / Switch).
  confirm,

  /// The safe action at the bottom — also scrim tap, Android back, Escape.
  cancel,
}

/// A modal decision (05 §4.3): the sign-out confirmation and closing a sale
/// whose QR was not printed (both [destructive], DangerButton).
///
/// Content width (max 360), centred 24 pt above centre, `radius.xl`,
/// padding 24; title `type.title.m`, body `type.body.m` `fg.secondary`;
/// two regular buttons stacked, the safe one nearest the thumb. Light:
/// `bg.surface` + `elev.2`; dark: `bg.raised` + 1-px `border.subtle`.
class WaiterDialog extends StatelessWidget {
  /// Creates the dialog body (use [showWaiterDialog] to present it).
  const WaiterDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onChoice,
    super.key,
    this.destructive = false,
  });

  /// Title (question in sign-out, "Different card detected").
  final String title;

  /// Body (max 3 lines).
  final String body;

  /// Top button label.
  final String confirmLabel;

  /// Bottom (safe) button label.
  final String cancelLabel;

  /// Whether the top button is a DangerButton.
  final bool destructive;

  /// Receives the choice.
  final ValueChanged<DialogChoice> onChoice;

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final WaiterColors c = theme.colors;
    final bool dark = theme.brightness == Brightness.dark;
    final BorderRadius radius = BorderRadius.circular(DialogTokens.radius);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.layout.contentWidth.clamp(0, DialogTokens.maxWidth),
        ),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: dark ? c.bgRaised : c.bgSurface,
            shape: waiterShape(
              context,
              radius,
              side: innerSide(dark ? c.borderSubtle : null, width: 0),
            ),
            shadows: theme.elevation.level2.shadows,
          ),
          child: Padding(
            padding: const EdgeInsets.all(DialogTokens.padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Focus(
                  autofocus: true,
                  child: Semantics(
                    container: true,
                    header: true,
                    child: ScaledText(title, type: TypeTokens.titleM),
                  ),
                ),
                const SizedBox(height: DialogTokens.titleBodyGap),
                ScaledText(body, type: TypeTokens.bodyM, color: c.fgSecondary),
                const SizedBox(height: DialogTokens.bodyButtonsGap),
                if (destructive)
                  DangerButton(
                    label: confirmLabel,
                    onPressed: () => onChoice(DialogChoice.confirm),
                  )
                else
                  PrimaryButton(
                    label: confirmLabel,
                    size: ButtonSize.regular,
                    onPressed: () => onChoice(DialogChoice.confirm),
                  ),
                const SizedBox(height: DialogTokens.buttonGap),
                SecondaryButton(
                  label: cancelLabel,
                  onPressed: () => onChoice(DialogChoice.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Presents a [WaiterDialog] (05 §4.3): dismisses any snackbar, scrim
/// `color.scrim`; scrim tap, Android back and Escape choose
/// [DialogChoice.cancel]. Enters with scale 0.96 → 1 + fade (240 ms
/// decelerate), exits with a 160-ms fade; fades only under Reduce Motion.
Future<DialogChoice> showWaiterDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  SnackbarHost.maybeOf(context)?.dismiss();
  final DialogChoice? choice = await Navigator.of(context).push(
    _DialogRoute(
      scrim: context.colors.scrim,
      barrierLabel: AppLocalizations.of(context).commonCancel,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      builder: (BuildContext dialogContext) => WaiterDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        onChoice: (DialogChoice c) => Navigator.of(dialogContext).pop(c),
      ),
    ),
  );
  return choice ?? DialogChoice.cancel;
}

class _DialogRoute extends PopupRoute<DialogChoice> {
  _DialogRoute({
    required this.scrim,
    required this.barrierLabel,
    required this.reduceMotion,
    required this.builder,
  });

  final Color scrim;
  final bool reduceMotion;
  final WidgetBuilder builder;

  @override
  final String barrierLabel;

  @override
  Color get barrierColor => scrim;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Motion.durationFast : Motion.durationBase;

  @override
  Duration get reverseTransitionDuration => Motion.durationFast;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Escape and Android back reach the route's DismissIntent → cancel.
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(
            left: context.layout.margin,
            right: context.layout.margin,
            bottom: -DialogTokens.offsetY * 2,
          ),
          child: Builder(builder: builder),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final bool entering = animation.status != AnimationStatus.reverse;
    final Animation<double> opacity = CurvedAnimation(
      parent: animation,
      curve: entering ? Motion.easeDecelerate : Motion.easeStandard,
    );
    if (reduceMotion || !entering) {
      return FadeTransition(opacity: opacity, child: child);
    }
    return FadeTransition(
      opacity: opacity,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: DialogTokens.enterScale,
          end: 1,
        ).animate(opacity),
        child: child,
      ),
    );
  }
}
