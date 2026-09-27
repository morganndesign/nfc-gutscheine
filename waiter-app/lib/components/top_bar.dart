import 'package:flutter/widgets.dart';

import '../core/format/format.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'avatar.dart';
import 'icon_button.dart';
import 'support/hairline.dart';
import 'support/text_emphasis.dart';

/// Minimal, flat top chrome (05 §5.1): identity on Ready ([TopBar.home]),
/// close on task screens ([TopBar.task]). 56 pt + the top safe area,
/// `bg.canvas` (transparent over the camera), no shadow, no blur, no
/// collapse; a `border.subtle` hairline fades in when [scrolled].
class TopBar extends StatelessWidget {
  /// S05: Avatar + restaurant name, Recent and Menu IconButtons.
  const TopBar.home({
    required String this.restaurantName,
    required String this.userName,
    required VoidCallback this.onRecent,
    required VoidCallback this.onMenu,
    super.key,
    this.scrolled = false,
  }) : onClose = null,
       closeLabel = null,
       title = null,
       cardNumber = null,
       trailing = null,
       onCamera = false;

  /// S07, S10, S11, S12: ✕ leading ([onClose] `null` = dimmed while
  /// locked), optional centred [title] (screen
  /// title, header trait) or [cardNumber] (S07: `type.caption`,
  /// `fg.tertiary`, read in groups), optional [trailing] (S12 torch).
  const TopBar.task({
    required this.onClose,
    super.key,
    this.closeLabel,
    this.title,
    this.cardNumber,
    this.trailing,
    this.onCamera = false,
    this.scrolled = false,
  }) : assert(
         title == null || cardNumber == null,
         'A task bar shows a title or a card number, not both',
       ),
       restaurantName = null,
       userName = null,
       onRecent = null,
       onMenu = null;

  /// Restaurant name (home).
  final String? restaurantName;

  /// Waiter display name (home; initials and the Menu label).
  final String? userName;

  /// Opens Recent (home).
  final VoidCallback? onRecent;

  /// Opens the Menu (home).
  final VoidCallback? onMenu;

  /// Closes the task (task). `null` keeps ✕ visible but dimmed and
  /// inactive — the task cannot be left right now (S08 lock, 09 §4.4).
  final VoidCallback? onClose;

  /// Accessible label of ✕ (default `common.close`; S07 `a11y.charge.close`).
  final String? closeLabel;

  /// Centred screen title (S11).
  final String? title;

  /// Full card number digits shown as the centred title (S07).
  final String? cardNumber;

  /// Trailing control (S12 torch).
  final Widget? trailing;

  /// Transparent over the camera; ✕ uses the on-camera variant (S12).
  final bool onCamera;

  /// Whether content is scrolled beneath the bar.
  final bool scrolled;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final double margin = context.layout.margin;
    final double top = MediaQuery.paddingOf(context).top;
    final bool home = restaurantName != null;

    final Widget bar = home
        ? _home(context, l10n, margin)
        : _task(context, l10n, margin);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: ColoredBox(
        color: onCamera ? const Color(0x00000000) : c.bgCanvas,
        child: Padding(
          padding: EdgeInsets.only(top: top),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: TopBarTokens.height, child: bar),
              AnimatedOpacity(
                opacity: scrolled ? 1 : 0,
                duration: Motion.durationFast,
                curve: Motion.easeStandard,
                child: Hairline(color: c.borderSubtle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _home(BuildContext context, AppLocalizations l10n, double margin) {
    final String name = restaurantName!;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: margin,
        end: margin - IconButtonTokens.marginInset,
      ),
      child: Row(
        children: <Widget>[
          Avatar(name: userName!),
          const SizedBox(width: TopBarTokens.avatarGap),
          Expanded(
            child: Semantics(
              container: true,
              header: true,
              label: name,
              excludeSemantics: true,
              child: ScaledText.rich(
                (ScaledStyles s) => TextSpan(
                  text: name,
                  style: s(
                    TypeTokens.labelL,
                  ).semiBold(boldText: context.waiter.boldText),
                ),
                type: TypeTokens.labelL,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ),
          WaiterIconButton(
            icon: WaiterIcon.history,
            semanticLabel: l10n.topBarRecent,
            onPressed: onRecent,
          ),
          WaiterIconButton(
            icon: WaiterIcon.menu,
            semanticLabel: l10n.topBarMenu(userName!),
            onPressed: onMenu,
          ),
        ],
      ),
    );
  }

  Widget _task(BuildContext context, AppLocalizations l10n, double margin) {
    final WaiterColors c = context.colors;
    final String? screenTitle = title;
    final String? number = cardNumber;
    Widget? centre;
    if (screenTitle != null) {
      centre = Semantics(
        container: true,
        header: true,
        child: ScaledText(
          screenTitle,
          type: TypeTokens.labelL,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      );
    } else if (number != null) {
      centre = Semantics(
        label: l10n.chargeCardNumberA11y(Spoken.cardNumber(number)),
        excludeSemantics: true,
        child: ScaledText(
          CardNumber.format(number),
          type: TypeTokens.caption,
          color: c.fgTertiary,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
        ),
      );
    }
    const double side = IconButtonTokens.target;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: margin - IconButtonTokens.marginInset,
      ),
      child: Row(
        children: <Widget>[
          WaiterIconButton(
            icon: WaiterIcon.x,
            semanticLabel: closeLabel ?? l10n.commonClose,
            onPressed: onClose,
            variant: onCamera
                ? IconButtonVariant.onCamera
                : IconButtonVariant.plain,
          ),
          Expanded(child: Center(child: centre)),
          SizedBox(width: side, child: trailing),
        ],
      ),
    );
  }
}
