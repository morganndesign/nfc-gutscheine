import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

void main() {
  group('waiterThemeData (09 §2.5)', () {
    test('installs the WaiterTheme extension and maps system roles', () {
      final ThemeData light = waiterThemeData(Brightness.light);
      final WaiterTheme waiter = light.extension<WaiterTheme>()!;
      expect(waiter.colors, WaiterColors.light);
      expect(light.useMaterial3, isTrue);
      expect(light.scaffoldBackgroundColor, WaiterColors.light.bgCanvas);
      expect(light.colorScheme.primary, WaiterColors.light.actionPrimary);
      expect(light.colorScheme.onPrimary, WaiterColors.light.fgOnAccent);
      expect(light.colorScheme.error, WaiterColors.light.danger);
      expect(light.colorScheme.outline, WaiterColors.light.borderControl);
      expect(light.splashFactory, NoSplash.splashFactory);
      expect(light.textTheme.bodyLarge, waiter.textStyles.bodyL);
      expect(
        light.textSelectionTheme.cursorColor,
        WaiterColors.light.fgPrimary,
      );
    });

    test('dark, high contrast and bold text variants', () {
      final WaiterTheme t = waiterThemeData(
        Brightness.dark,
        highContrast: true,
        boldText: true,
      ).extension<WaiterTheme>()!;
      expect(t.colors, WaiterColors.darkHighContrast);
      expect(t.elevation.usesShadows, isFalse);
      expect(t.boldText, isTrue);
      expect(t.textStyles.titleL.fontWeight, FontWeight.w700);
      expect(t.statusBannerBody.fontWeight, FontWeight.w700);
      expect(t.outlinesControls, isTrue);
      expect(t.illustrationLine, WaiterColors.dark.fgPrimary);
    });

    test('lerp is used for the theme cross-fade', () {
      final WaiterTheme a = WaiterTheme.resolve(brightness: Brightness.light);
      final WaiterTheme b = WaiterTheme.resolve(brightness: Brightness.dark);
      expect(a.lerp(b, 0), a);
      expect(a.lerp(b, 1).colors, b.colors);
      final WaiterTheme mid = a.lerp(b, 0.5);
      expect(
        mid.colors.bgCanvas,
        Color.lerp(
          WaiterColors.light.bgCanvas,
          WaiterColors.dark.bgCanvas,
          0.5,
        ),
      );
    });
  });

  testWidgets('context extensions', (WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: waiterThemeData(Brightness.light),
        home: Builder(
          builder: (BuildContext context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(ctx.colors, WaiterColors.light);
    expect(ctx.textStyles.amountXl.fontSize, 64);
    expect(ctx.elevation.usesShadows, isTrue);
    expect(ctx.waiter.statusBannerBody, ctx.textStyles.bodyM);
    expect(ctx.layout.widthClass, WidthClass.tablet); // test window 800 × 600
  });

  group('layout (04 §4, 08 §1)', () {
    WaiterLayout at(double w, double h, {double top = 0, double bottom = 0}) =>
        WaiterLayout.fromWindow(
          Size(w, h),
          EdgeInsets.only(top: top, bottom: bottom),
        );

    test('width classes and margins', () {
      expect(WidthClass.of(340), WidthClass.compact);
      expect(WidthClass.of(375), WidthClass.standard);
      expect(WidthClass.of(412), WidthClass.large);
      expect(WidthClass.of(820), WidthClass.tablet);
      expect(
        <double>[
          WidthClass.compact.margin,
          WidthClass.standard.margin,
          WidthClass.large.margin,
          WidthClass.tablet.margin,
        ],
        <double>[20, 20, 24, 32],
      );
      expect(WidthClass.tablet.columns, 8);
      expect(WidthClass.standard.gutter, 8);
    });

    test('iPhone SE is compact height; iPhone 15 is regular', () {
      final WaiterLayout se = at(375, 667, top: 20);
      expect(se.heightClass, HeightClass.compact);
      expect(se.keyHeight, 52);
      expect(se.largeButtonHeight, 56);
      expect(se.ctaBottomPadding, 20);
      expect(se.contentWidth, 335);
      final WaiterLayout i15 = at(393, 852, top: 59, bottom: 34);
      expect(i15.heightClass, HeightClass.regular);
      expect(i15.keyHeight, 72);
      expect(i15.largeButtonHeight, 64);
      expect(i15.ctaBottomPadding, 16);
    });

    test('tablet content is capped at 560, text at 480, keypad at 400', () {
      final WaiterLayout ipad = at(1024, 1366, top: 24, bottom: 20);
      expect(ipad.maxContentWidth, 560);
      expect(ipad.contentWidth, 560);
      expect(ipad.textMeasure, 480);
      expect(ipad.keypadWidth, 400);
    });

    test('ID-1 card height and minimum window', () {
      expect(WaiterLayout.idOneCardHeight(335), closeTo(211.2, 0.1));
      expect(WaiterLayout.idOneCardHeight(353), 220);
      expect(at(300, 600).isBelowMinimumWindow, isTrue);
      expect(at(320, 568).isBelowMinimumWindow, isFalse);
    });
  });
}
