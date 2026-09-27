import 'package:flutter/widgets.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

/// A static amount in an amount/balance style (04 §3.4): the currency
/// symbol at its 60 % token on the same baseline with the locale's gap,
/// scaled as one unit (max 130 %, then shrink-to-fit ≥ 40 pt, never
/// truncated). Hidden from assistive technology — the screen gives the
/// spoken form.
class MoneyText extends StatelessWidget {
  /// Creates the text.
  const MoneyText({
    required this.cents,
    required this.money,
    required this.type,
    required this.symbolType,
    super.key,
    this.color,
  });

  /// Amount in cents.
  final int cents;

  /// Formatting context.
  final MoneyContext money;

  /// Digit style (`type.amount.l`, `type.amount.xl`, `type.balance`).
  final TypeSpec type;

  /// Symbol style (`type.currency.*` of the same family).
  final TypeSpec symbolType;

  /// Colour; defaults to `fg.primary`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final MoneyParts parts = money.parts(cents);
    return ExcludeSemantics(
      child: ScaledText.rich(
        (ScaledStyles s) {
          final TextStyle digits = s(type, color: color);
          final TextStyle symbol = s(symbolType, color: color);
          final TextSpan gap = TextSpan(
            text: ' ',
            style: symbol.copyWith(
              letterSpacing: s.scale(
                type.fontSize *
                    (parts.spaced
                        ? TypeTokens.currencyGapSpaced
                        : TypeTokens.currencyGapTight),
              ),
            ),
          );
          return TextSpan(
            children: parts.symbolLeading
                ? <InlineSpan>[
                    TextSpan(text: parts.symbol, style: symbol),
                    gap,
                    TextSpan(text: parts.number, style: digits),
                  ]
                : <InlineSpan>[
                    TextSpan(text: parts.number, style: digits),
                    gap,
                    TextSpan(text: parts.symbol, style: symbol),
                  ],
          );
        },
        type: type,
        textAlign: TextAlign.center,
      ),
    );
  }
}
