import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/theme/brand_color.dart';
import 'package:giftcard_waiter/core/tokens/tokens.dart';

/// Contrast claims of 04 §8.2 / §8.4 (WCAG 2.x). The tables print ratios
/// to 2 dp; values are compared rounded to 2 dp.
void main() {
  double ratio(Color a, Color b) =>
      (contrastRatio(a, b) * 100).roundToDouble() / 100;

  const WaiterColors l = WaiterColors.light;
  const WaiterColors d = WaiterColors.dark;

  test('neutral text ≥ 4.5 : 1 on canvas, surface, raised', () {
    for (final WaiterColors c in <WaiterColors>[l, d]) {
      for (final Color bg in <Color>[c.bgCanvas, c.bgSurface, c.bgRaised]) {
        expect(contrastRatio(c.fgPrimary, bg), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(c.fgSecondary, bg), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(c.fgTertiary, bg), greaterThanOrEqualTo(4.5));
      }
    }
    expect(ratio(l.fgPrimary, l.bgCanvas), 16.97);
    expect(ratio(d.fgPrimary, d.bgCanvas), 18.00);
    expect(ratio(l.fgSecondary, l.bgCanvas), 7.41);
    expect(ratio(l.fgTertiary, l.bgCanvas), 4.63);
    expect(ratio(d.fgTertiary, d.bgKey), 4.92);
  });

  test('documented failure: fg.tertiary on bg.key (light) is 4.28', () {
    expect(ratio(l.fgTertiary, l.bgKey), 4.28);
  });

  test('actions', () {
    expect(ratio(l.fgOnAccent, l.actionPrimary), 17.72);
    expect(ratio(d.fgOnAccent, d.actionPrimary), 18.00);
    expect(ratio(l.fgOnAccent, l.actionPrimaryPressed), 14.89);
    expect(ratio(d.fgOnAccent, d.actionPrimaryPressed), 13.38);
    expect(contrastRatio(l.actionPrimary, l.bgCanvas), greaterThan(3));
  });

  test('border.control ≥ 3 : 1 as input boundary (13 · R06)', () {
    expect(ratio(l.borderControl, l.bgSurface), 3.42);
    expect(ratio(l.borderControl, l.bgCanvas), 3.28);
    expect(ratio(d.borderControl, d.bgSurface), 3.80);
    expect(ratio(d.borderControl, d.bgCanvas), 4.09);
    expect(ratio(d.borderControl, d.bgRaised), 3.51);
    // border.strong is insufficient as a sole boundary (04 §8.2).
    expect(contrastRatio(l.borderStrong, l.bgSurface), lessThan(3));
  });

  test('focus ring ≥ 3 : 1 (13 · R17)', () {
    expect(ratio(l.focusRing, l.bgCanvas), 16.97);
    expect(ratio(d.focusRing, d.bgCanvas), 10.70);
    expect(ratio(d.focusRing, d.bgSurface), 9.95);
  });

  test('hold ring ≥ 3 : 1 on the button fill (13 · R05)', () {
    expect(ratio(l.holdProgress, l.actionPrimary), 8.22);
    expect(ratio(l.holdProgress, l.actionPrimaryPressed), 6.91);
    expect(ratio(d.holdProgress, d.actionPrimary), 4.57);
    expect(ratio(d.holdProgress, d.actionPrimaryPressed), 3.40);
    // Plain saffron on the dark primary fails (why the token exists).
    expect(contrastRatio(d.accentSaffron, d.actionPrimary), lessThan(3));
  });

  test('status text on canvas, surface and own tint', () {
    for (final WaiterColors c in <WaiterColors>[l, d]) {
      for (final (Color fg, Color tint) in <(Color, Color)>[
        (c.success, c.successBg),
        (c.danger, c.dangerBg),
        (c.warning, c.warningBg),
        (c.info, c.infoBg),
      ]) {
        expect(contrastRatio(fg, c.bgCanvas), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(fg, c.bgSurface), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(fg, tint), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(c.fgPrimary, tint), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(c.fgSecondary, tint), greaterThanOrEqualTo(4.5));
      }
    }
    expect(ratio(l.success, l.bgCanvas), 5.25);
    expect(ratio(l.warning, l.warningBg), 4.84);
    expect(ratio(d.danger, d.dangerBg), 6.50);
  });

  test('on-colour labels (04 §8.4)', () {
    expect(ratio(l.fgOnDanger, l.danger), 6.47);
    expect(ratio(d.fgOnDanger, d.danger), 7.15);
    expect(ratio(l.fgOnDanger, l.dangerPressed), 8.31);
    expect(ratio(d.fgOnDanger, d.dangerPressed), 5.26);
    expect(ratio(l.fgOnSuccess, l.success), 5.48);
    expect(ratio(d.fgOnSuccess, d.success), 10.29);
  });

  test('saffron text and inverse (snackbar)', () {
    expect(ratio(l.accentSaffronText, l.bgCanvas), 4.81);
    expect(ratio(l.inverseFg, l.inverseBg), 17.72);
    expect(ratio(d.inverseFg, d.inverseBg), 15.44);
    expect(ratio(l.inverseAction, l.inverseBg), 8.22);
    expect(ratio(d.inverseAction, d.inverseBg), 9.18);
    expect(ratio(l.nfcArcHc, l.bgCanvas), 4.81);
  });

  test('high contrast raises secondary and tertiary text', () {
    const WaiterColors lh = WaiterColors.lightHighContrast;
    expect(ratio(lh.fgTertiary, lh.bgCanvas), 7.41);
    expect(ratio(lh.fgSecondary, lh.bgCanvas), 16.97);
    expect(
      contrastRatio(WaiterColors.darkHighContrast.fgTertiary, d.bgCanvas),
      greaterThanOrEqualTo(7.72 - 0.01),
    );
  });

  test('brand ink', () {
    expect(ratio(l.brandInk, l.bgCanvas), 17.10);
    expect(ratio(const Color(0xFFFFFFFF), l.brandInk), 17.85);
  });
}
