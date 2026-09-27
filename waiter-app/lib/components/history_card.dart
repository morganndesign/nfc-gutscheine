import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'button_label.dart';
import 'money_context.dart';
import 'support/shape.dart';
import 'support/text_emphasis.dart';

/// Summary header of Recent, S13 (05 §3.11): the shift total in
/// `type.title.l` (tabular) over the count line in `type.body.m`
/// `fg.secondary`.
///
/// Both come from the brief string `recent.summary` ("12 redemptions ·
/// € 486,40 today"): the count phrase is its part before the " · "
/// separator, so plural forms stay in the resource file. At the 200-row
/// cap the count line adds " · " + `recent.limit`.
///
/// `radius.xl`, padding 20; light: `bg.canvas` on the sheet + `elev.1`;
/// dark: `bg.raised` + 1-px `border.subtle`. One static element read as
/// "12 redemptions, 486 euros 40 today".
class HistoryCard extends StatelessWidget {
  /// Creates the card.
  const HistoryCard({
    required this.count,
    required this.totalCents,
    required this.money,
    super.key,
    this.limitReached = false,
  });

  /// Redemptions this business day.
  final int count;

  /// Sum of the redeemed amounts.
  final int totalCents;

  /// Formatting context.
  final MoneyContext money;

  /// Whether the 200-row cap was reached.
  final bool limitReached;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterTheme theme = context.waiter;
    final WaiterColors c = theme.colors;
    final bool dark = theme.brightness == Brightness.dark;
    final String summary = l10n.recentSummary(count, money.format(totalCents));
    final String countPhrase = summary.split(labelAmountSeparator).first;
    final String countLine = limitReached
        ? '$countPhrase$labelAmountSeparator${l10n.recentLimit}'
        : countPhrase;
    final String spoken = l10n
        .recentSummary(count, money.spoken(totalCents))
        .replaceFirst(labelAmountSeparator, ', ');

    return Semantics(
      container: true,
      label: spoken,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(HistoryCardTokens.padding),
        decoration: ShapeDecoration(
          color: dark ? c.bgRaised : c.bgCanvas,
          shape: waiterShapeAll(
            context,
            HistoryCardTokens.radius,
            side: innerSide(dark ? c.borderSubtle : null, width: 0),
          ),
          shadows: theme.elevation.level1.shadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ScaledText.rich(
              (ScaledStyles s) => TextSpan(
                text: money.format(totalCents),
                style: s(TypeTokens.titleL).tabular,
              ),
              type: TypeTokens.titleL,
            ),
            const SizedBox(height: Space.s1 / 2),
            ScaledText(countLine, type: TypeTokens.bodyM, color: c.fgSecondary),
          ],
        ),
      ),
    );
  }
}
