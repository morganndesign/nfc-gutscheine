import 'package:flutter/widgets.dart';

import '../core/format/format.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'money_context.dart';
import 'support/focus_ring.dart';
import 'support/hairline.dart';
import 'support/pressable.dart';
import 'support/shape.dart';
import 'support/text_emphasis.dart';

/// One redemption in the shift history, S13 Recent (05 §3.10).
///
/// Min 64 pt (grows with text), horizontal padding = screen margin,
/// vertical 10. Columns: time (`type.body.m`, tabular, `fg.secondary`,
/// 48 pt / 64 pt for 12-hour locales), masked card (`type.body.l`) over
/// the remaining balance (`type.caption`, `fg.tertiary`), amount
/// (`type.body.l` 600, tabular, trailing) and a `chevron-right`. Pressed:
/// `bg.key` fill inset 8 pt, `radius.m`, no scale. A hairline divider
/// starts at the card column ([showDivider] false after the last row).
/// One focus stop, role button.
class TransactionRow extends StatelessWidget {
  /// Creates a row.
  const TransactionRow({
    required this.time,
    required this.last4,
    required this.amountCents,
    required this.remainingCents,
    required this.money,
    required this.onPressed,
    super.key,
    this.showDivider = true,
  });

  /// Redemption time in the restaurant time zone.
  final WallTime time;

  /// Voucher ending.
  final String last4;

  /// Redeemed amount (no sign).
  final int amountCents;

  /// Balance after the redemption.
  final int remainingCents;

  /// Formatting context.
  final MoneyContext money;

  /// Opens the detail sheet.
  final VoidCallback onPressed;

  /// Whether a divider follows the row.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final double margin = context.layout.margin;
    final double timeColumn = money.usesTwelveHourClock
        ? TransactionRowTokens.timeColumn12h
        : TransactionRowTokens.timeColumn;
    final String timeText = money.time(time);
    final String remaining = remainingCents == 0
        ? l10n.recentRowEmpty
        : l10n.recentRowRemaining(money.format(remainingCents));
    const BorderRadius radius = BorderRadius.all(Radius.circular(Radii.m));

    return Pressable(
      onPressed: onPressed,
      semanticsLabel: l10n.recentRowA11y(
        timeText,
        Spoken.characters(last4),
        money.spoken(amountCents),
        money.spoken(remainingCents),
      ),
      builder: (BuildContext context, PressVisual visual) {
        final Color fill = Color.lerp(
          c.bgKey.withValues(alpha: 0),
          c.bgKey,
          visual.pressAmount,
        )!;
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TransactionRowTokens.pressedInset,
                ),
                child: FocusRing(
                  visible: visual.focused,
                  radius: radius,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: visual.hovered
                          ? Color.alphaBlend(c.stateHover, fill)
                          : fill,
                      shape: waiterShape(context, radius),
                    ),
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TransactionRowTokens.height,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: margin,
                  vertical: TransactionRowTokens.paddingVertical,
                ),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: timeColumn,
                      child: ScaledText.rich(
                        (ScaledStyles s) => TextSpan(
                          text: timeText,
                          style: s(
                            TypeTokens.bodyM,
                            color: c.fgSecondary,
                          ).tabular,
                        ),
                        type: TypeTokens.bodyM,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ScaledText(
                            l10n.balanceCardMasked(last4),
                            type: TypeTokens.bodyL,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                          ScaledText(
                            remaining,
                            type: TypeTokens.caption,
                            color: c.fgTertiary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.s2),
                    ScaledText.rich(
                      (ScaledStyles s) => TextSpan(
                        text: money.format(amountCents),
                        style: s(
                          TypeTokens.bodyL,
                        ).tabular.semiBold(boldText: context.waiter.boldText),
                      ),
                      type: TypeTokens.bodyL,
                      maxLines: 1,
                      softWrap: false,
                    ),
                    const SizedBox(width: TransactionRowTokens.chevronGap),
                    WaiterIconView(
                      WaiterIcon.chevronRight,
                      size: IconSize.s16,
                      color: c.fgTertiary,
                    ),
                  ],
                ),
              ),
            ),
            if (showDivider)
              PositionedDirectional(
                start: margin + timeColumn,
                end: 0,
                bottom: 0,
                child: Hairline(color: c.borderSubtle),
              ),
          ],
        );
      },
    );
  }
}
