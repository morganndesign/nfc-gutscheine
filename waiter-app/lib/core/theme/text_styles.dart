import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../tokens/tokens.dart';

/// Raises a Geist weight by one step for iOS Bold Text / Android bold text
/// (04 §10.2): 400 → 500, 500 → 600, 600 → 700. 700 is the heaviest bundled
/// weight and stays 700.
int boldTextWeight(int weight) => weight >= 700 ? 700 : weight + 100;

/// Builds the [TextStyle] of [type] at [fontSize] (09 §3).
///
/// - family and weight from the token, weight raised one step if [boldText];
/// - line height as a fixed ratio (`lineHeight / fontSize`), so the line box
///   scales proportionally with the size;
/// - letter spacing converted from percent to an absolute value at
///   [fontSize];
/// - `tnum` where the token asks for it (04 §3.3);
/// - [TextLeadingDistribution.even]: Geist's ascender (1005) and descender
///   (295) are symmetric around its cap-height centre (710 / 2), so even
///   leading centres the cap height in the line box (04 §3.2).
TextStyle textStyleFor(
  TypeSpec type, {
  double? fontSize,
  bool boldText = false,
  Color? color,
}) {
  final double size = fontSize ?? type.fontSize;
  final int weight = boldText
      ? boldTextWeight(type.fontWeight)
      : type.fontWeight;
  return TextStyle(
    inherit: false,
    color: color,
    fontFamily: type.fontFamily,
    fontSize: size,
    fontWeight: FontWeight.values[weight ~/ 100 - 1],
    height: type.height,
    letterSpacing: type.letterSpacingAt(size),
    leadingDistribution: TextLeadingDistribution.even,
    textBaseline: TextBaseline.alphabetic,
    fontFeatures: type.tabularFigures
        ? const <FontFeature>[FontFeature.tabularFigures()]
        : const <FontFeature>[],
    decoration: TextDecoration.none,
  );
}

/// The app's named text styles (04 §3.2, A.2) for one theme and Bold Text
/// setting.
///
/// Styles carry `color.fg.primary` as their default colour; components
/// override the colour with a semantic token where the spec says so.
/// Text-scale clamps are applied by `ScaledText` / `clampedScaler`
/// (04 §3.7), not by the styles themselves.
@immutable
class WaiterTextStyles {
  /// Creates the style set from token data.
  WaiterTextStyles({required this.boldText, required this.defaultColor})
    : amountXl = _style(TypeTokens.amountXl, boldText, defaultColor),
      amountL = _style(TypeTokens.amountL, boldText, defaultColor),
      balance = _style(TypeTokens.balance, boldText, defaultColor),
      titleL = _style(TypeTokens.titleL, boldText, defaultColor),
      titleM = _style(TypeTokens.titleM, boldText, defaultColor),
      bodyL = _style(TypeTokens.bodyL, boldText, defaultColor),
      bodyM = _style(TypeTokens.bodyM, boldText, defaultColor),
      label = _style(TypeTokens.label, boldText, defaultColor),
      labelL = _style(TypeTokens.labelL, boldText, defaultColor),
      caption = _style(TypeTokens.caption, boldText, defaultColor),
      overline = _style(TypeTokens.overline, boldText, defaultColor),
      key = _style(TypeTokens.key, boldText, defaultColor),
      cardNumber = _style(TypeTokens.cardNumber, boldText, defaultColor),
      currencyXl = _style(TypeTokens.currencyXl, boldText, defaultColor),
      currencyL = _style(TypeTokens.currencyL, boldText, defaultColor),
      currencyBalance = _style(
        TypeTokens.currencyBalance,
        boldText,
        defaultColor,
      );

  const WaiterTextStyles._raw({
    required this.boldText,
    required this.defaultColor,
    required this.amountXl,
    required this.amountL,
    required this.balance,
    required this.titleL,
    required this.titleM,
    required this.bodyL,
    required this.bodyM,
    required this.label,
    required this.labelL,
    required this.caption,
    required this.overline,
    required this.key,
    required this.cardNumber,
    required this.currencyXl,
    required this.currencyL,
    required this.currencyBalance,
  });

  static TextStyle _style(TypeSpec type, bool bold, Color color) =>
      textStyleFor(type, boldText: bold, color: color);

  /// Whether Bold Text raised every weight by one step (04 §10.2).
  final bool boldText;

  /// Colour applied by default (`color.fg.primary`).
  final Color defaultColor;

  /// `type.amount.xl` — amount being typed (S07, S08).
  final TextStyle amountXl;

  /// `type.amount.l` — success amount (S09).
  final TextStyle amountL;

  /// `type.balance` — balance on the BalanceCard.
  final TextStyle balance;

  /// `type.title.l` — screen titles.
  final TextStyle titleL;

  /// `type.title.m` — sheet, dialog and card titles.
  final TextStyle titleM;

  /// `type.body.l` — primary body.
  final TextStyle bodyL;

  /// `type.body.m` — secondary body.
  final TextStyle bodyM;

  /// `type.label` — regular buttons, chips, snackbar action.
  final TextStyle label;

  /// `type.label.l` — large buttons.
  final TextStyle labelL;

  /// `type.caption` — meta, masked number, badges, timestamps.
  final TextStyle caption;

  /// `type.overline` — uppercase overlines (apply uppercase via
  /// `ScaledText` or [TypeSpec.uppercase]).
  final TextStyle overline;

  /// `type.key` — keypad digits.
  final TextStyle key;

  /// `type.cardNumber` — Geist Mono card number on S11.
  final TextStyle cardNumber;

  /// `type.currency.xl` — symbol inside `type.amount.xl`.
  final TextStyle currencyXl;

  /// `type.currency.l` — symbol inside `type.amount.l`.
  final TextStyle currencyL;

  /// `type.currency.balance` — symbol inside `type.balance`.
  final TextStyle currencyBalance;

  /// The style for [type] at its base size.
  TextStyle of(TypeSpec type) {
    return switch (type.name) {
      'type.amount.xl' => amountXl,
      'type.amount.l' => amountL,
      'type.balance' => balance,
      'type.title.l' => titleL,
      'type.title.m' => titleM,
      'type.body.l' => bodyL,
      'type.body.m' => bodyM,
      'type.label' => label,
      'type.label.l' => labelL,
      'type.caption' => caption,
      'type.overline' => overline,
      'type.key' => key,
      'type.cardNumber' => cardNumber,
      'type.currency.xl' => currencyXl,
      'type.currency.l' => currencyL,
      'type.currency.balance' => currencyBalance,
      _ => textStyleFor(type, boldText: boldText, color: defaultColor),
    };
  }

  /// The style for [type] rendered at an explicit [fontSize] (used after
  /// clamping and shrink-to-fit); tracking is recomputed for the size.
  TextStyle at(TypeSpec type, double fontSize, {Color? color}) {
    return textStyleFor(
      type,
      fontSize: fontSize,
      boldText: boldText,
      color: color ?? defaultColor,
    );
  }

  /// Interpolates for the theme cross-fade (colours only change).
  static WaiterTextStyles lerp(
    WaiterTextStyles a,
    WaiterTextStyles b,
    double t,
  ) {
    // Exact ends: TextStyle.lerp normalises some null fields to empty lists.
    if (t == 0) return a;
    if (t == 1) return b;
    TextStyle l(TextStyle x, TextStyle y) => TextStyle.lerp(x, y, t)!;
    return WaiterTextStyles._raw(
      boldText: t < 0.5 ? a.boldText : b.boldText,
      defaultColor: Color.lerp(a.defaultColor, b.defaultColor, t)!,
      amountXl: l(a.amountXl, b.amountXl),
      amountL: l(a.amountL, b.amountL),
      balance: l(a.balance, b.balance),
      titleL: l(a.titleL, b.titleL),
      titleM: l(a.titleM, b.titleM),
      bodyL: l(a.bodyL, b.bodyL),
      bodyM: l(a.bodyM, b.bodyM),
      label: l(a.label, b.label),
      labelL: l(a.labelL, b.labelL),
      caption: l(a.caption, b.caption),
      overline: l(a.overline, b.overline),
      key: l(a.key, b.key),
      cardNumber: l(a.cardNumber, b.cardNumber),
      currencyXl: l(a.currencyXl, b.currencyXl),
      currencyL: l(a.currencyL, b.currencyL),
      currencyBalance: l(a.currencyBalance, b.currencyBalance),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WaiterTextStyles &&
      other.boldText == boldText &&
      other.defaultColor == defaultColor &&
      other.amountXl == amountXl &&
      other.amountL == amountL &&
      other.balance == balance &&
      other.titleL == titleL &&
      other.titleM == titleM &&
      other.bodyL == bodyL &&
      other.bodyM == bodyM &&
      other.label == label &&
      other.labelL == labelL &&
      other.caption == caption &&
      other.overline == overline &&
      other.key == key &&
      other.cardNumber == cardNumber &&
      other.currencyXl == currencyXl &&
      other.currencyL == currencyL &&
      other.currencyBalance == currencyBalance;

  @override
  int get hashCode => Object.hash(
    boldText,
    defaultColor,
    amountXl,
    amountL,
    balance,
    titleL,
    titleM,
    bodyL,
    bodyM,
    label,
    labelL,
    caption,
    overline,
    key,
    cardNumber,
    currencyXl,
    currencyL,
    currencyBalance,
  );
}
