import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Brightness, Color;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart' show BoxShadow;
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/tokens/tokens.dart';

/// Snapshot of key token values against 04 Appendix A (09 §6.2 wave 0 exit
/// criterion: token snapshot tests pass).
void main() {
  group('generated file', () {
    test('is up to date with tokens/waiter.tokens.json', () async {
      final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
      final ProcessResult result = await Process.run(
        flutterRoot == null ? 'dart' : '$flutterRoot/bin/dart',
        <String>['run', 'tool/generate_tokens.dart', '--check'],
      );
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('colour (A.1)', () {
    const WaiterColors l = WaiterColors.light;
    const WaiterColors d = WaiterColors.dark;

    test('backgrounds', () {
      expect(l.bgCanvas, const Color(0xFFFAFAFA));
      expect(d.bgCanvas, const Color(0xFF0A0A0C));
      expect(l.bgSurface, const Color(0xFFFFFFFF));
      expect(d.bgSurface, const Color(0xFF141417));
      expect(d.bgRaised, const Color(0xFF1C1C21));
      expect(l.bgKey, const Color(0xFFF1F1F3));
      expect(d.bgKeyPressed, const Color(0xFF2A2A31));
    });

    test('foregrounds and actions', () {
      expect(l.fgPrimary, const Color(0xFF18181B));
      expect(d.fgPrimary, const Color(0xFFF4F4F5));
      expect(l.fgSecondary, const Color(0xFF52525B));
      expect(d.fgTertiary, const Color(0xFF8B8B94));
      expect(l.fgOnAccent, const Color(0xFFFFFFFF));
      expect(d.fgOnAccent, const Color(0xFF0A0A0C));
      expect(l.actionPrimaryPressed, const Color(0xFF27272A));
      expect(d.actionPrimaryPressed, const Color(0xFFD4D4D8));
    });

    test('brand, accent and status', () {
      expect(l.brandInk, const Color(0xFF0F172A));
      expect(d.brandInk, const Color(0xFF0F172A));
      expect(l.accentSaffron, const Color(0xFFE8A33D));
      expect(d.accentSaffron, const Color(0xFFF0B454));
      expect(l.accentSaffronText, const Color(0xFFB45309));
      expect(l.success, const Color(0xFF047857));
      expect(d.successBg, const Color(0xFF052E22));
      expect(l.danger, const Color(0xFFB91C1C));
      expect(d.dangerBg, const Color(0xFF2A0E0E));
      expect(d.warning, const Color(0xFFFBBF24));
      expect(l.infoBg, const Color(0xFFEFF6FF));
    });

    test('added tokens (04 §8.4)', () {
      expect(l.borderControl, const Color(0xFF8A8A93));
      expect(d.borderControl, const Color(0xFF71717A));
      expect(l.focusRing, const Color(0xFF18181B));
      expect(d.focusRing, const Color(0xFFF0B454));
      expect(l.focusAccent, const Color(0xFFE8A33D));
      expect(d.focusAccent, isNull);
      expect(l.holdProgress, const Color(0xFFE8A33D));
      expect(d.holdProgress, const Color(0xFFB45309));
      expect(l.holdTrack, const Color(0xFF4F4F52));
      expect(d.holdTrack, const Color(0xFFCFCFD0));
      expect(l.cardBorderDark, isNull);
      expect(d.cardBorderDark, const Color(0xFF26262B));
      expect(l.skeletonHighlight, const Color(0xFFE0E0E2));
      expect(l.nfcArcHc, const Color(0xFFB45309));
    });

    test('rgba tokens keep their alpha', () {
      expect(l.scrim.toARGB32(), 0x7A0A0A0C); // 0.48 × 255 = 122
      expect(d.scrim.toARGB32(), 0xA3000000); // 0.64 × 255 = 163
      expect(l.stateHover.toARGB32(), 0x0A18181B);
      expect(d.statePressedOverlay.toARGB32(), 0x14F4F4F5);
      expect(l.cameraOverlay.toARGB32(), 0x8F000000);
    });

    test('high-contrast modifier (04 §10.1)', () {
      const WaiterColors lh = WaiterColors.lightHighContrast;
      const WaiterColors dh = WaiterColors.darkHighContrast;
      expect(lh.fgSecondary, l.fgPrimary);
      expect(dh.fgSecondary, d.fgPrimary);
      expect(lh.fgTertiary, l.fgSecondary);
      expect(dh.fgTertiary, d.fgSecondary);
      expect(lh.borderSubtle, l.borderStrong);
      expect(dh.borderSubtle, d.borderStrong);
      expect(lh.scrim.toARGB32(), 0xA30A0A0C); // 0.64
      expect(dh.scrim.toARGB32(), 0xB8000000); // 0.72
      expect(lh.bgCanvas, l.bgCanvas);
      expect(lh.isHighContrast, isTrue);
      expect(
        WaiterColors.resolve(Brightness.dark, highContrast: true),
        same(WaiterColors.darkHighContrast),
      );
      expect(WaiterColors.highContrast(Brightness.light), same(lh));
    });

    test('lerp reaches both ends', () {
      expect(WaiterColors.lerp(l, d, 0), l);
      expect(WaiterColors.lerp(l, d, 1), d);
    });
  });

  group('typography (A.2)', () {
    test('type scale', () {
      void check(TypeSpec t, String family, int w, double s, double lh) {
        expect(t.fontFamily, family, reason: t.name);
        expect(t.fontWeight, w, reason: t.name);
        expect(t.fontSize, s, reason: t.name);
        expect(t.lineHeight, lh, reason: t.name);
      }

      check(TypeTokens.amountXl, 'Geist', 600, 64, 68);
      check(TypeTokens.amountL, 'Geist', 600, 48, 52);
      check(TypeTokens.balance, 'Geist', 600, 40, 44);
      check(TypeTokens.titleL, 'Geist', 600, 28, 34);
      check(TypeTokens.titleM, 'Geist', 600, 22, 28);
      check(TypeTokens.bodyL, 'Geist', 400, 17, 24);
      check(TypeTokens.bodyM, 'Geist', 400, 15, 22);
      check(TypeTokens.label, 'Geist', 600, 15, 20);
      check(TypeTokens.labelL, 'Geist', 600, 17, 22);
      check(TypeTokens.caption, 'Geist', 500, 13, 18);
      check(TypeTokens.overline, 'Geist', 600, 11, 14);
      check(TypeTokens.key, 'Geist', 500, 30, 36);
      check(TypeTokens.cardNumber, 'GeistMono', 500, 24, 32);
      check(TypeTokens.currencyXl, 'Geist', 600, 38, 68);
      check(TypeTokens.currencyL, 'Geist', 600, 29, 52);
      check(TypeTokens.currencyBalance, 'Geist', 600, 24, 44);
    });

    test('absolute tracking (04 §3.2 "Tracking (pt)")', () {
      expect(TypeTokens.amountXl.letterSpacing, closeTo(-1.60, 1e-9));
      expect(TypeTokens.amountL.letterSpacing, closeTo(-0.96, 1e-9));
      expect(TypeTokens.balance.letterSpacing, closeTo(-0.80, 1e-9));
      expect(TypeTokens.titleL.letterSpacing, closeTo(-0.28, 1e-9));
      expect(TypeTokens.titleM.letterSpacing, closeTo(-0.11, 1e-9));
      expect(TypeTokens.caption.letterSpacing, closeTo(0.065, 1e-9));
      expect(TypeTokens.overline.letterSpacing, closeTo(0.88, 1e-9));
      expect(TypeTokens.cardNumber.letterSpacing, closeTo(0.48, 1e-9));
      expect(TypeTokens.currencyXl.letterSpacing, closeTo(-0.38, 1e-9));
      expect(TypeTokens.bodyL.letterSpacing, 0);
    });

    test('scale caps and shrink (04 §3.7)', () {
      for (final TypeSpec t in <TypeSpec>[
        TypeTokens.amountXl,
        TypeTokens.amountL,
        TypeTokens.balance,
      ]) {
        expect(t.maxScale, 1.3, reason: t.name);
        expect(t.minSizeAfterShrink, 40, reason: t.name);
      }
      expect(TypeTokens.titleL.maxScale, 1.5);
      expect(TypeTokens.titleM.maxScale, 1.5);
      for (final TypeSpec t in <TypeSpec>[
        TypeTokens.bodyL,
        TypeTokens.bodyM,
        TypeTokens.label,
        TypeTokens.labelL,
        TypeTokens.caption,
      ]) {
        expect(t.maxScale, 2.0, reason: t.name);
        expect(t.shrinksToFit, isFalse, reason: t.name);
      }
      expect(TypeTokens.overline.maxScale, 1.3);
      expect(TypeTokens.key.maxScale, 1.2);
      expect(TypeTokens.cardNumber.maxScale, 1.3);
      expect(TypeTokens.cardNumber.minSizeAfterShrink, 20);
      expect(TypeTokens.shrinkStep, 2);
    });

    test('tabular figures on every style, uppercase overline', () {
      for (final TypeSpec t in TypeTokens.all) {
        expect(t.tabularFigures, isTrue, reason: t.name);
        expect(t.lineHeight % 2, 0, reason: '${t.name}: even line height');
      }
      expect(TypeTokens.overline.uppercase, isTrue);
      expect(TypeTokens.all, hasLength(16));
    });

    test('currency sizing (04 §3.4)', () {
      expect(TypeTokens.currencyRatio, 0.6);
      expect(TypeTokens.currencyGapSpaced * 64, closeTo(10.24, 1e-9));
      expect(TypeTokens.currencyGapTight * 64, closeTo(2.56, 1e-9));
    });
  });

  group('space, radius, border, size (A.3, A.4)', () {
    test('spacing scale', () {
      expect(
        <double>[
          Space.s0,
          Space.s1,
          Space.s2,
          Space.s3,
          Space.s4,
          Space.s5,
          Space.s6,
          Space.s8,
          Space.s10,
          Space.s12,
          Space.s16,
        ],
        <double>[0, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64],
      );
    });

    test('layout', () {
      expect(LayoutTokens.marginCompact, 20);
      expect(LayoutTokens.marginRegular, 24);
      expect(LayoutTokens.marginTablet, 32);
      expect(LayoutTokens.maxContentTablet, 560);
      expect(LayoutTokens.textMeasureTablet, 480);
      expect(LayoutTokens.compactHeight, 700);
    });

    test('radii', () {
      expect(
        <double>[Radii.xs, Radii.s, Radii.m, Radii.l, Radii.xl, Radii.sheet],
        <double>[8, 12, 16, 20, 28, 32],
      );
      expect(Radii.full, 999);
    });

    test('borders', () {
      expect(Borders.widthHairline(3), closeTo(1 / 3, 1e-12));
      expect(Borders.widthHairline(2), 0.5);
      expect(Borders.widthDefault, 1);
      expect(Borders.widthFocus, 2);
      expect(Borders.widthFocusHc, 3);
      expect(FocusTokens.offset, 2);
    });

    test('sizes', () {
      expect(Sizes.targetMin, 56);
      expect(Sizes.buttonL, 64);
      expect(Sizes.buttonLCompact, 56);
      expect(Sizes.buttonM, 56);
      expect(Sizes.key, 72);
      expect(Sizes.keyCompact, 64);
      expect(Sizes.keyGap, 8);
      expect(Sizes.chip, 40);
      expect(Sizes.iconButtonFill, 44);
      expect(Sizes.grabberWidth, 36);
      expect(Sizes.grabberHeight, 5);
      expect(Sizes.spinnerS, 20);
      expect(Sizes.spinnerSStroke, 2);
      expect(Sizes.spinnerLStroke, 3);
      expect(Sizes.ringHold, 28);
      expect(Sizes.ringCountdown, 48);
      expect(Sizes.successMark, 96);
      expect(Sizes.nfcCanvasWidth, 176);
      expect(Sizes.nfcCanvasHeight, 120);
      expect(
        <double>[Sizes.nfcArcR1, Sizes.nfcArcR2, Sizes.nfcArcR3],
        <double>[36, 56, 76],
      );
      expect(Sizes.balanceCardMaxHeight, 220);
      expect(Sizes.balanceCardCompact, 88);
    });

    test('icon sizes with compensated strokes (04 §11.2)', () {
      expect(
        IconSize.values.map((IconSize s) => (s.size, s.stroke)).toList(),
        <(double, double)>[
          (16, 1.5),
          (20, 1.75),
          (24, 1.75),
          (32, 2.0),
          (48, 2.5),
        ],
      );
      expect(IconSize.grid, 24);
    });

    test('tier-3 component tokens resolve their references', () {
      expect(ButtonTokens.largeHeight, Sizes.buttonL);
      expect(ButtonTokens.largeRadius, Radii.l);
      expect(KeypadTokens.keyHeight, 72);
      expect(KeypadTokens.keyHeightCompact, 64);
      expect(BalanceCardTokens.padding, Space.s6);
      expect(BalanceCardTokens.radius, Radii.xl);
      expect(BalanceCardTokens.compactHeight, 88);
      expect(HoldButtonTokens.slop, 12);
      expect(HoldButtonTokens.thresholdCents, 10000);
      expect(SheetTokens.radius, Radii.sheet);
      expect(ProblemScreenTokens.illustrationGap, Space.s8);
    });
  });

  group('elevation, opacity, z (A.5)', () {
    test('light shadows', () {
      final WaiterElevation e = WaiterElevation.resolve(WaiterColors.light);
      expect(e.level0.shadows, isEmpty);
      expect(e.level1.shadows.single.offset.dy, 1);
      expect(e.level1.shadows.single.blurRadius, 2);
      expect(e.level1.shadows.single.color.toARGB32(), 0x0A000000);
      expect(e.level2.shadows.single.offset.dy, 4);
      expect(e.level2.shadows.single.blurRadius, 16);
      expect(e.level3.shadows.single.offset.dy, 12);
      expect(e.level3Upward.shadows.single.offset.dy, -12);
      final BoxShadow brand = e.cardBrand(const Color(0xFF0F172A)).single;
      expect(brand.offset.dy, 16);
      expect(brand.blurRadius, 40);
      expect(brand.color.a, closeTo(0.28, 1e-6));
      expect(e.usesShadows, isTrue);
      expect(e.cardOutline, isNull);
    });

    test('dark: surface steps and hairlines, no shadows', () {
      final WaiterElevation e = WaiterElevation.resolve(WaiterColors.dark);
      expect(e.usesShadows, isFalse);
      expect(e.level1.shadows, isEmpty);
      expect(e.level1.surface, WaiterColors.dark.bgSurface);
      expect(e.level2.surface, WaiterColors.dark.bgRaised);
      expect(e.level2.outline, WaiterColors.dark.borderSubtle);
      expect(e.cardBrand(const Color(0xFF0F172A)), isEmpty);
      expect(e.cardOutline, const Color(0xFF26262B));
      final WaiterElevation hc = WaiterElevation.resolve(
        WaiterColors.darkHighContrast,
      );
      expect(hc.level2.outline, WaiterColors.dark.borderStrong);
    });

    test('opacity and z', () {
      expect(Opacities.disabled, 0.40);
      expect(Opacities.cardSecondary, 0.76);
      expect(Opacities.holdTrackLight, 0.24);
      expect(Opacities.holdTrackDark, 0.16);
      expect(
        <double>[
          Opacities.nfcIdleInner,
          Opacities.nfcIdleMiddle,
          Opacities.nfcIdleOuter,
        ],
        <double>[0.80, 0.56, 0.32],
      );
      expect(
        <int>[
          ZLayers.content,
          ZLayers.chrome,
          ZLayers.scrim,
          ZLayers.sheet,
          ZLayers.sheetStacked,
          ZLayers.snackbar,
          ZLayers.dialog,
        ],
        <int>[0, 10, 20, 30, 40, 45, 50],
      );
    });
  });

  group('motion, time (A.6)', () {
    test('durations and curves', () {
      expect(Motion.durationInstant, const Duration(milliseconds: 90));
      expect(Motion.durationFast, const Duration(milliseconds: 160));
      expect(Motion.durationBase, const Duration(milliseconds: 240));
      expect(Motion.durationSlow, const Duration(milliseconds: 360));
      expect(Motion.durationEmphasis, const Duration(milliseconds: 520));
      expect(Motion.easeStandard, const Cubic(0.2, 0, 0, 1));
      expect(Motion.easeDecelerate, const Cubic(0, 0, 0, 1));
      expect(Motion.easeAccelerate, const Cubic(0.3, 0, 1, 1));
    });

    test('springs follow 06 §2.2 conversion', () {
      // spring.card: ω₀ 14.96, k 223.8, c 24.5; spring.soft: k 130.5, c 20.6.
      expect(Motion.springCard.mass, 1);
      expect(Motion.springCard.stiffness, closeTo(223.8, 0.05));
      expect(Motion.springCard.damping, closeTo(24.5, 0.05));
      expect(Motion.springSoft.stiffness, closeTo(130.5, 0.05));
      expect(Motion.springSoft.damping, closeTo(20.6, 0.05));
      final double zeta =
          Motion.springCard.damping /
          (2 * math.sqrt(Motion.springCard.stiffness));
      expect(zeta, closeTo(0.82, 1e-9));
    });

    test('timing tokens', () {
      expect(Times.feedbackDelay, const Duration(milliseconds: 150));
      expect(Times.lookupSlow, const Duration(seconds: 3));
      expect(Times.lookupTimeout, const Duration(seconds: 10));
      expect(Times.redeemSlow, const Duration(seconds: 8));
      expect(Times.hold, const Duration(milliseconds: 600));
      expect(Times.longPressClear, const Duration(milliseconds: 500));
      expect(Times.successReturn, const Duration(seconds: 4));
      expect(Times.cardSwap, const Duration(milliseconds: 300));
      expect(Times.snackbar, const Duration(seconds: 4));
      expect(Times.skeletonSweep, const Duration(milliseconds: 1200));
      expect(Times.spinnerTurn, const Duration(milliseconds: 800));
      expect(Times.minIndicator, const Duration(milliseconds: 240));
    });
  });

  group('haptic and sound (11 §2)', () {
    test('seven haptic tokens with platform mapping', () {
      expect(HapticToken.values, hasLength(7));
      expect(HapticToken.key.spec.ios.impactStyle, IosImpactStyle.light);
      expect(HapticToken.key.spec.ios.intensities, <double>[0.5]);
      expect(
        HapticToken.key.spec.androidApi30.constants,
        <AndroidHapticConstant>[AndroidHapticConstant.keyboardTap],
      );
      expect(
        HapticToken.select.spec.ios.generator,
        IosHapticGenerator.selection,
      );
      expect(
        HapticToken.cardDetected.spec.androidFallback.oneShot?.amplitude,
        180,
      );
      final HapticSpec success = HapticToken.success.spec;
      expect(success.ios.notificationType, IosNotificationType.success);
      expect(success.androidApi30.constants, <AndroidHapticConstant>[
        AndroidHapticConstant.confirm,
      ]);
      expect(success.androidApi30.waveformDelayMs, 40);
      expect(success.androidApi30.waveform?.timingsMs, <int>[0, 20, 60, 30]);
      expect(success.androidApi30.waveform?.amplitudes, <int>[0, 160, 0, 255]);
      expect(HapticToken.warning.spec.androidApi30.waveform?.timingsMs, <int>[
        0,
        30,
        80,
        30,
      ]);
      expect(
        HapticToken.error.spec.androidApi30.constants,
        <AndroidHapticConstant>[AndroidHapticConstant.reject],
      );
      expect(HapticToken.error.spec.androidFallback.waveform?.timingsMs, <int>[
        0,
        40,
        60,
        40,
        60,
        40,
      ]);
      final HapticSpec tick = HapticToken.holdTick.spec;
      expect(tick.ios.impactStyle, IosImpactStyle.rigid);
      expect(tick.ios.intensities, <double>[0.5, 0.7, 1.0]);
      expect(tick.stepsMs, <int>[200, 400, 600]);
      expect(tick.androidApi30.constants.last, AndroidHapticConstant.confirm);
      expect(HapticToken.minSpacing, const Duration(milliseconds: 80));
      expect(HapticToken.keyCoalesce, const Duration(milliseconds: 50));
      expect(
        HapticToken.error.spec.severity,
        greaterThan(HapticToken.warning.spec.severity),
      );
    });

    test('four sound tokens with binding file names', () {
      expect(SoundToken.values.map((SoundToken s) => s.spec.file), <String>[
        'gcw_card_detected',
        'gcw_success',
        'gcw_warning',
        'gcw_error',
      ]);
      expect(SoundToken.cardDetected.spec.maxDuration.inMilliseconds, 60);
      expect(SoundToken.success.spec.maxDuration.inMilliseconds, 280);
      expect(SoundToken.warning.spec.maxDuration.inMilliseconds, 150);
      expect(SoundToken.error.spec.maxDuration.inMilliseconds, 240);
      expect(SoundToken.success.spec.loudnessLufsM, -18);
      expect(SoundToken.cardDetected.spec.loudnessLufsM, -22);
      expect(SoundToken.success.spec.iosFileName, 'gcw_success.caf');
    });

    test('platform sound files exist', () {
      for (final SoundToken s in SoundToken.values) {
        expect(
          File('ios/Runner/Sounds/${s.spec.iosFileName}').existsSync(),
          isTrue,
          reason: s.id,
        );
        expect(
          File(
            'android/app/src/main/res/raw/${s.spec.androidResourceName}.ogg',
          ).existsSync(),
          isTrue,
          reason: s.id,
        );
      }
    });
  });
}
