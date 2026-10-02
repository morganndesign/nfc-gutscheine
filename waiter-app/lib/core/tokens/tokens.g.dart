// GENERATED — do not edit.
// Source: tokens/waiter.tokens.json (version 1.0.0).
// Regenerate with: dart run tool/generate_tokens.dart

// ignore_for_file: public_member_api_docs

import 'dart:ui' show Brightness, Color, Offset;

import 'package:flutter/animation.dart' show Cubic;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart' show BoxShadow;
import 'package:flutter/physics.dart' show SpringDescription;

import 'token_types.dart';

/// Semantic colours for one resolved theme (04 §8, A.1).
///
/// Use [light], [dark] or [highContrast]; components read these
/// fields, never literal colours (09 §1.2).
@immutable
class WaiterColors {
  const WaiterColors({
    required this.brightness,
    required this.isHighContrast,
    required this.bgCanvas,
    required this.bgSurface,
    required this.bgRaised,
    required this.bgKey,
    required this.bgKeyPressed,
    required this.fgPrimary,
    required this.fgSecondary,
    required this.fgTertiary,
    required this.fgOnAccent,
    required this.fgOnDanger,
    required this.fgOnSuccess,
    required this.borderSubtle,
    required this.borderStrong,
    required this.borderControl,
    required this.actionPrimary,
    required this.actionPrimaryPressed,
    required this.brandInk,
    required this.accentSaffron,
    required this.accentSaffronText,
    required this.success,
    required this.successBg,
    required this.danger,
    required this.dangerBg,
    required this.dangerPressed,
    required this.warning,
    required this.warningBg,
    required this.info,
    required this.infoBg,
    required this.scrim,
    required this.focusRing,
    required this.focusAccent,
    required this.holdProgress,
    required this.holdTrack,
    required this.inverseBg,
    required this.inverseFg,
    required this.inverseAction,
    required this.cardBorderDark,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.stateHover,
    required this.statePressedOverlay,
    required this.nfcArcHc,
    required this.cameraOverlay,
  });

  /// Theme this palette belongs to.
  final Brightness brightness;

  /// Whether the high-contrast modifier (04 §10.1) is applied.
  final bool isHighContrast;

  /// `color.bg.canvas` — Every screen background (04 §8.3).
  final Color bgCanvas;

  /// `color.bg.surface` — Sheets, TextField fill, HistoryCard (light).
  final Color bgSurface;

  /// `color.bg.raised` — Sheet on sheet, snackbar (dark), dialog (dark).
  final Color bgRaised;

  /// `color.bg.key` — Keys, SecondaryButton, chips, disabled button fill, skeleton base, pressed fill of TertiaryButton/IconButton/rows.
  final Color bgKey;

  /// `color.bg.keyPressed` — Pressed key, pressed SecondaryButton, pressed chip.
  final Color bgKeyPressed;

  /// `color.fg.primary` — Text, icons, amounts.
  final Color fgPrimary;

  /// `color.fg.secondary` — Secondary text, inactive icons, banner body.
  final Color fgSecondary;

  /// `color.fg.tertiary` — Meta, placeholders, timestamps, disabled labels. Never on bg.key (4.28 : 1 light).
  final Color fgTertiary;

  /// `color.fg.onAccent` — Label/icon on action.primary.
  final Color fgOnAccent;

  /// `color.fg.onDanger` — ➕ DangerButton label (04 §8.4).
  final Color fgOnDanger;

  /// `color.fg.onSuccess` — ➕ Check inside SuccessMark (13 · R22).
  final Color fgOnSuccess;

  /// `color.border.subtle` — Dividers, dark-mode outlines. Decorative only.
  final Color borderSubtle;

  /// `color.border.strong` — Grabber, focus-ring base track. Not a stand-alone input boundary.
  final Color borderStrong;

  /// `color.border.control` — ➕ Resting boundary of TextField/CardNumberField (≥ 3 : 1, 13 · R06).
  final Color borderControl;

  /// `color.action.primary` — PrimaryButton / HoldButton fill.
  final Color actionPrimary;

  /// `color.action.primaryPressed` — Pressed PrimaryButton.
  final Color actionPrimaryPressed;

  /// `color.brand.ink` — Default and fallback BalanceCard colour (04 §8.6).
  final Color brandInk;

  /// `color.accent.saffron` — NFC arcs, hold ring (light), focus accent, snackbar action. Never text on light.
  final Color accentSaffron;

  /// `color.accent.saffronText` — Saffron as text on light (rare).
  final Color accentSaffronText;

  /// `color.success` — Money moved, active status.
  final Color success;

  /// `color.success.bg` —
  final Color successBg;

  /// `color.danger` — Blocked, errors, over-balance.
  final Color danger;

  /// `color.danger.bg` —
  final Color dangerBg;

  /// `color.danger.pressed` — ➕ Pressed DangerButton.
  final Color dangerPressed;

  /// `color.warning` — Expired, inactive, zero balance, maintenance.
  final Color warning;

  /// `color.warning.bg` —
  final Color warningBg;

  /// `color.info` — Offline, neutral tips.
  final Color info;

  /// `color.info.bg` —
  final Color infoBg;

  /// `color.scrim` — Behind sheets and dialogs.
  final Color scrim;

  /// `color.focus.ring` — ➕ 2-pt focus ring (13 · R17).
  final Color focusRing;

  /// `color.focus.accent` — ➕ Light-theme decorative outer band on focus; none in dark.
  final Color? focusAccent;

  /// `color.hold.progress` — ➕ HoldButton ring progress (13 · R05).
  final Color holdProgress;

  /// `color.hold.track` — ➕ HoldButton ring track (onAccent 24 % / 16 % composited on primary).
  final Color holdTrack;

  /// `color.inverse.bg` — ➕ Snackbar background.
  final Color inverseBg;

  /// `color.inverse.fg` — ➕ Snackbar text.
  final Color inverseFg;

  /// `color.inverse.action` — ➕ Snackbar action label.
  final Color inverseAction;

  /// `color.card.borderDark` — ➕ BalanceCard outline in dark mode; none in light.
  final Color? cardBorderDark;

  /// `color.skeleton.base` — ➕ Skeleton shapes (= bg.key).
  final Color skeletonBase;

  /// `color.skeleton.highlight` — ➕ Skeleton sweep band (8 % highlight).
  final Color skeletonHighlight;

  /// `color.state.hover` — ➕ Pointer hover overlay.
  final Color stateHover;

  /// `color.state.pressedOverlay` — ➕ Pressed overlay where no *Pressed token exists.
  final Color statePressedOverlay;

  /// `color.nfc.arc.hc` — ➕ NFC arcs in high-contrast mode (04 §10.1).
  final Color nfcArcHc;

  /// `color.camera.overlay` — ➕ S12 viewfinder mask.
  final Color cameraOverlay;

  /// Light theme (04 §8.3).
  static const WaiterColors light = WaiterColors(
    brightness: Brightness.light,
    isHighContrast: false,
    bgCanvas: Color(0xFFFAFAFA),
    bgSurface: Color(0xFFFFFFFF),
    bgRaised: Color(0xFFFFFFFF),
    bgKey: Color(0xFFF1F1F3),
    bgKeyPressed: Color(0xFFE4E4E7),
    fgPrimary: Color(0xFF18181B),
    fgSecondary: Color(0xFF52525B),
    fgTertiary: Color(0xFF71717A),
    fgOnAccent: Color(0xFFFFFFFF),
    fgOnDanger: Color(0xFFFFFFFF),
    fgOnSuccess: Color(0xFFFFFFFF),
    borderSubtle: Color(0xFFE4E4E7),
    borderStrong: Color(0xFFA1A1AA),
    borderControl: Color(0xFF8A8A93),
    actionPrimary: Color(0xFF18181B),
    actionPrimaryPressed: Color(0xFF27272A),
    brandInk: Color(0xFF0F172A),
    accentSaffron: Color(0xFFE8A33D),
    accentSaffronText: Color(0xFFB45309),
    success: Color(0xFF047857),
    successBg: Color(0xFFECFDF5),
    danger: Color(0xFFB91C1C),
    dangerBg: Color(0xFFFEF2F2),
    dangerPressed: Color(0xFF991B1B),
    warning: Color(0xFFB45309),
    warningBg: Color(0xFFFFFBEB),
    info: Color(0xFF1D4ED8),
    infoBg: Color(0xFFEFF6FF),
    scrim: Color(0x7A0A0A0C),
    focusRing: Color(0xFF18181B),
    focusAccent: Color(0xFFE8A33D),
    holdProgress: Color(0xFFE8A33D),
    holdTrack: Color(0xFF4F4F52),
    inverseBg: Color(0xFF18181B),
    inverseFg: Color(0xFFFFFFFF),
    inverseAction: Color(0xFFE8A33D),
    cardBorderDark: null,
    skeletonBase: Color(0xFFF1F1F3),
    skeletonHighlight: Color(0xFFE0E0E2),
    stateHover: Color(0x0A18181B),
    statePressedOverlay: Color(0x1418181B),
    nfcArcHc: Color(0xFFB45309),
    cameraOverlay: Color(0x8F000000),
  );

  /// Dark theme (04 §6.2, §8.3).
  static const WaiterColors dark = WaiterColors(
    brightness: Brightness.dark,
    isHighContrast: false,
    bgCanvas: Color(0xFF0A0A0C),
    bgSurface: Color(0xFF141417),
    bgRaised: Color(0xFF1C1C21),
    bgKey: Color(0xFF1E1E23),
    bgKeyPressed: Color(0xFF2A2A31),
    fgPrimary: Color(0xFFF4F4F5),
    fgSecondary: Color(0xFFA1A1AA),
    fgTertiary: Color(0xFF8B8B94),
    fgOnAccent: Color(0xFF0A0A0C),
    fgOnDanger: Color(0xFF0A0A0C),
    fgOnSuccess: Color(0xFF0A0A0C),
    borderSubtle: Color(0xFF26262B),
    borderStrong: Color(0xFF3F3F46),
    borderControl: Color(0xFF71717A),
    actionPrimary: Color(0xFFF4F4F5),
    actionPrimaryPressed: Color(0xFFD4D4D8),
    brandInk: Color(0xFF0F172A),
    accentSaffron: Color(0xFFF0B454),
    accentSaffronText: Color(0xFFF0B454),
    success: Color(0xFF34D399),
    successBg: Color(0xFF052E22),
    danger: Color(0xFFF87171),
    dangerBg: Color(0xFF2A0E0E),
    dangerPressed: Color(0xFFEF4444),
    warning: Color(0xFFFBBF24),
    warningBg: Color(0xFF2A1E06),
    info: Color(0xFF93C5FD),
    infoBg: Color(0xFF0B1A33),
    scrim: Color(0xA3000000),
    focusRing: Color(0xFFF0B454),
    focusAccent: null,
    holdProgress: Color(0xFFB45309),
    holdTrack: Color(0xFFCFCFD0),
    inverseBg: Color(0xFF1C1C21),
    inverseFg: Color(0xFFF4F4F5),
    inverseAction: Color(0xFFF0B454),
    cardBorderDark: Color(0xFF26262B),
    skeletonBase: Color(0xFF1E1E23),
    skeletonHighlight: Color(0xFF2F2F34),
    stateHover: Color(0x0AF4F4F5),
    statePressedOverlay: Color(0x14F4F4F5),
    nfcArcHc: Color(0xFFF0B454),
    cameraOverlay: Color(0x8F000000),
  );

  /// Light theme with the high-contrast modifier (04 §10.1).
  static const WaiterColors lightHighContrast = WaiterColors(
    brightness: Brightness.light,
    isHighContrast: true,
    bgCanvas: Color(0xFFFAFAFA),
    bgSurface: Color(0xFFFFFFFF),
    bgRaised: Color(0xFFFFFFFF),
    bgKey: Color(0xFFF1F1F3),
    bgKeyPressed: Color(0xFFE4E4E7),
    fgPrimary: Color(0xFF18181B),
    fgSecondary: Color(0xFF18181B),
    fgTertiary: Color(0xFF52525B),
    fgOnAccent: Color(0xFFFFFFFF),
    fgOnDanger: Color(0xFFFFFFFF),
    fgOnSuccess: Color(0xFFFFFFFF),
    borderSubtle: Color(0xFFA1A1AA),
    borderStrong: Color(0xFFA1A1AA),
    borderControl: Color(0xFF8A8A93),
    actionPrimary: Color(0xFF18181B),
    actionPrimaryPressed: Color(0xFF27272A),
    brandInk: Color(0xFF0F172A),
    accentSaffron: Color(0xFFE8A33D),
    accentSaffronText: Color(0xFFB45309),
    success: Color(0xFF047857),
    successBg: Color(0xFFECFDF5),
    danger: Color(0xFFB91C1C),
    dangerBg: Color(0xFFFEF2F2),
    dangerPressed: Color(0xFF991B1B),
    warning: Color(0xFFB45309),
    warningBg: Color(0xFFFFFBEB),
    info: Color(0xFF1D4ED8),
    infoBg: Color(0xFFEFF6FF),
    scrim: Color(0xA30A0A0C),
    focusRing: Color(0xFF18181B),
    focusAccent: Color(0xFFE8A33D),
    holdProgress: Color(0xFFE8A33D),
    holdTrack: Color(0xFF4F4F52),
    inverseBg: Color(0xFF18181B),
    inverseFg: Color(0xFFFFFFFF),
    inverseAction: Color(0xFFE8A33D),
    cardBorderDark: null,
    skeletonBase: Color(0xFFF1F1F3),
    skeletonHighlight: Color(0xFFE0E0E2),
    stateHover: Color(0x0A18181B),
    statePressedOverlay: Color(0x1418181B),
    nfcArcHc: Color(0xFFB45309),
    cameraOverlay: Color(0x8F000000),
  );

  /// Dark theme with the high-contrast modifier (04 §10.1).
  static const WaiterColors darkHighContrast = WaiterColors(
    brightness: Brightness.dark,
    isHighContrast: true,
    bgCanvas: Color(0xFF0A0A0C),
    bgSurface: Color(0xFF141417),
    bgRaised: Color(0xFF1C1C21),
    bgKey: Color(0xFF1E1E23),
    bgKeyPressed: Color(0xFF2A2A31),
    fgPrimary: Color(0xFFF4F4F5),
    fgSecondary: Color(0xFFF4F4F5),
    fgTertiary: Color(0xFFA1A1AA),
    fgOnAccent: Color(0xFF0A0A0C),
    fgOnDanger: Color(0xFF0A0A0C),
    fgOnSuccess: Color(0xFF0A0A0C),
    borderSubtle: Color(0xFF3F3F46),
    borderStrong: Color(0xFF3F3F46),
    borderControl: Color(0xFF71717A),
    actionPrimary: Color(0xFFF4F4F5),
    actionPrimaryPressed: Color(0xFFD4D4D8),
    brandInk: Color(0xFF0F172A),
    accentSaffron: Color(0xFFF0B454),
    accentSaffronText: Color(0xFFF0B454),
    success: Color(0xFF34D399),
    successBg: Color(0xFF052E22),
    danger: Color(0xFFF87171),
    dangerBg: Color(0xFF2A0E0E),
    dangerPressed: Color(0xFFEF4444),
    warning: Color(0xFFFBBF24),
    warningBg: Color(0xFF2A1E06),
    info: Color(0xFF93C5FD),
    infoBg: Color(0xFF0B1A33),
    scrim: Color(0xB8000000),
    focusRing: Color(0xFFF0B454),
    focusAccent: null,
    holdProgress: Color(0xFFB45309),
    holdTrack: Color(0xFFCFCFD0),
    inverseBg: Color(0xFF1C1C21),
    inverseFg: Color(0xFFF4F4F5),
    inverseAction: Color(0xFFF0B454),
    cardBorderDark: Color(0xFF26262B),
    skeletonBase: Color(0xFF1E1E23),
    skeletonHighlight: Color(0xFF2F2F34),
    stateHover: Color(0x0AF4F4F5),
    statePressedOverlay: Color(0x14F4F4F5),
    nfcArcHc: Color(0xFFF0B454),
    cameraOverlay: Color(0x8F000000),
  );

  /// High-contrast palette for [brightness] (04 §10.1).
  static WaiterColors highContrast(Brightness brightness) =>
      brightness == Brightness.dark ? darkHighContrast : lightHighContrast;

  /// Resolves the palette for a theme and contrast setting.
  static WaiterColors resolve(
    Brightness brightness, {
    bool highContrast = false,
  }) {
    if (highContrast) {
      return WaiterColors.highContrast(brightness);
    }
    return brightness == Brightness.dark ? dark : light;
  }

  /// Interpolates for the theme cross-fade (04 §9 rule 2).
  static WaiterColors lerp(WaiterColors a, WaiterColors b, double t) {
    return WaiterColors(
      brightness: t < 0.5 ? a.brightness : b.brightness,
      isHighContrast: t < 0.5 ? a.isHighContrast : b.isHighContrast,
      bgCanvas: Color.lerp(a.bgCanvas, b.bgCanvas, t)!,
      bgSurface: Color.lerp(a.bgSurface, b.bgSurface, t)!,
      bgRaised: Color.lerp(a.bgRaised, b.bgRaised, t)!,
      bgKey: Color.lerp(a.bgKey, b.bgKey, t)!,
      bgKeyPressed: Color.lerp(a.bgKeyPressed, b.bgKeyPressed, t)!,
      fgPrimary: Color.lerp(a.fgPrimary, b.fgPrimary, t)!,
      fgSecondary: Color.lerp(a.fgSecondary, b.fgSecondary, t)!,
      fgTertiary: Color.lerp(a.fgTertiary, b.fgTertiary, t)!,
      fgOnAccent: Color.lerp(a.fgOnAccent, b.fgOnAccent, t)!,
      fgOnDanger: Color.lerp(a.fgOnDanger, b.fgOnDanger, t)!,
      fgOnSuccess: Color.lerp(a.fgOnSuccess, b.fgOnSuccess, t)!,
      borderSubtle: Color.lerp(a.borderSubtle, b.borderSubtle, t)!,
      borderStrong: Color.lerp(a.borderStrong, b.borderStrong, t)!,
      borderControl: Color.lerp(a.borderControl, b.borderControl, t)!,
      actionPrimary: Color.lerp(a.actionPrimary, b.actionPrimary, t)!,
      actionPrimaryPressed: Color.lerp(
        a.actionPrimaryPressed,
        b.actionPrimaryPressed,
        t,
      )!,
      brandInk: Color.lerp(a.brandInk, b.brandInk, t)!,
      accentSaffron: Color.lerp(a.accentSaffron, b.accentSaffron, t)!,
      accentSaffronText: Color.lerp(
        a.accentSaffronText,
        b.accentSaffronText,
        t,
      )!,
      success: Color.lerp(a.success, b.success, t)!,
      successBg: Color.lerp(a.successBg, b.successBg, t)!,
      danger: Color.lerp(a.danger, b.danger, t)!,
      dangerBg: Color.lerp(a.dangerBg, b.dangerBg, t)!,
      dangerPressed: Color.lerp(a.dangerPressed, b.dangerPressed, t)!,
      warning: Color.lerp(a.warning, b.warning, t)!,
      warningBg: Color.lerp(a.warningBg, b.warningBg, t)!,
      info: Color.lerp(a.info, b.info, t)!,
      infoBg: Color.lerp(a.infoBg, b.infoBg, t)!,
      scrim: Color.lerp(a.scrim, b.scrim, t)!,
      focusRing: Color.lerp(a.focusRing, b.focusRing, t)!,
      focusAccent: a.focusAccent == null || b.focusAccent == null
          ? (t < 0.5 ? a.focusAccent : b.focusAccent)
          : Color.lerp(a.focusAccent, b.focusAccent, t),
      holdProgress: Color.lerp(a.holdProgress, b.holdProgress, t)!,
      holdTrack: Color.lerp(a.holdTrack, b.holdTrack, t)!,
      inverseBg: Color.lerp(a.inverseBg, b.inverseBg, t)!,
      inverseFg: Color.lerp(a.inverseFg, b.inverseFg, t)!,
      inverseAction: Color.lerp(a.inverseAction, b.inverseAction, t)!,
      cardBorderDark: a.cardBorderDark == null || b.cardBorderDark == null
          ? (t < 0.5 ? a.cardBorderDark : b.cardBorderDark)
          : Color.lerp(a.cardBorderDark, b.cardBorderDark, t),
      skeletonBase: Color.lerp(a.skeletonBase, b.skeletonBase, t)!,
      skeletonHighlight: Color.lerp(
        a.skeletonHighlight,
        b.skeletonHighlight,
        t,
      )!,
      stateHover: Color.lerp(a.stateHover, b.stateHover, t)!,
      statePressedOverlay: Color.lerp(
        a.statePressedOverlay,
        b.statePressedOverlay,
        t,
      )!,
      nfcArcHc: Color.lerp(a.nfcArcHc, b.nfcArcHc, t)!,
      cameraOverlay: Color.lerp(a.cameraOverlay, b.cameraOverlay, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WaiterColors &&
      other.brightness == brightness &&
      other.isHighContrast == isHighContrast &&
      other.bgCanvas == bgCanvas &&
      other.bgSurface == bgSurface &&
      other.bgRaised == bgRaised &&
      other.bgKey == bgKey &&
      other.bgKeyPressed == bgKeyPressed &&
      other.fgPrimary == fgPrimary &&
      other.fgSecondary == fgSecondary &&
      other.fgTertiary == fgTertiary &&
      other.fgOnAccent == fgOnAccent &&
      other.fgOnDanger == fgOnDanger &&
      other.fgOnSuccess == fgOnSuccess &&
      other.borderSubtle == borderSubtle &&
      other.borderStrong == borderStrong &&
      other.borderControl == borderControl &&
      other.actionPrimary == actionPrimary &&
      other.actionPrimaryPressed == actionPrimaryPressed &&
      other.brandInk == brandInk &&
      other.accentSaffron == accentSaffron &&
      other.accentSaffronText == accentSaffronText &&
      other.success == success &&
      other.successBg == successBg &&
      other.danger == danger &&
      other.dangerBg == dangerBg &&
      other.dangerPressed == dangerPressed &&
      other.warning == warning &&
      other.warningBg == warningBg &&
      other.info == info &&
      other.infoBg == infoBg &&
      other.scrim == scrim &&
      other.focusRing == focusRing &&
      other.focusAccent == focusAccent &&
      other.holdProgress == holdProgress &&
      other.holdTrack == holdTrack &&
      other.inverseBg == inverseBg &&
      other.inverseFg == inverseFg &&
      other.inverseAction == inverseAction &&
      other.cardBorderDark == cardBorderDark &&
      other.skeletonBase == skeletonBase &&
      other.skeletonHighlight == skeletonHighlight &&
      other.stateHover == stateHover &&
      other.statePressedOverlay == statePressedOverlay &&
      other.nfcArcHc == nfcArcHc &&
      other.cameraOverlay == cameraOverlay;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    brightness,
    isHighContrast,
    bgCanvas,
    bgSurface,
    bgRaised,
    bgKey,
    bgKeyPressed,
    fgPrimary,
    fgSecondary,
    fgTertiary,
    fgOnAccent,
    fgOnDanger,
    fgOnSuccess,
    borderSubtle,
    borderStrong,
    borderControl,
    actionPrimary,
    actionPrimaryPressed,
    brandInk,
    accentSaffron,
    accentSaffronText,
    success,
    successBg,
    danger,
    dangerBg,
    dangerPressed,
    warning,
    warningBg,
    info,
    infoBg,
    scrim,
    focusRing,
    focusAccent,
    holdProgress,
    holdTrack,
    inverseBg,
    inverseFg,
    inverseAction,
    cardBorderDark,
    skeletonBase,
    skeletonHighlight,
    stateHover,
    statePressedOverlay,
    nfcArcHc,
    cameraOverlay,
  ]);
}

/// Type scale (04 §3.2, A.2) and currency sizing (04 §3.4).
abstract final class TypeTokens {
  /// `type.amount.xl` — Amount being typed (S07, S08).
  static const TypeSpec amountXl = TypeSpec(
    name: 'type.amount.xl',
    fontFamily: 'Geist',
    fontWeight: 600,
    fontSize: 64,
    lineHeight: 68,
    letterSpacingPercent: -2.5,
    tabularFigures: true,
    maxScale: 1.3,
    minSizeAfterShrink: 40,
  );

  /// `type.amount.l` — Success amount (S09).
  static const TypeSpec amountL = TypeSpec(
    name: 'type.amount.l',
    fontFamily: 'Geist',
    fontWeight: 600,
    fontSize: 48,
    lineHeight: 52,
    letterSpacingPercent: -2,
    tabularFigures: true,
    maxScale: 1.3,
    minSizeAfterShrink: 40,
  );

  /// `type.balance` — Balance on BalanceCard.
  static const TypeSpec balance = TypeSpec(
    name: 'type.balance',
    fontFamily: 'Geist',
    fontWeight: 600,
    fontSize: 40,
    lineHeight: 44,
    letterSpacingPercent: -2,
    tabularFigures: true,
    maxScale: 1.3,
    minSizeAfterShrink: 40,
  );

  /// `type.title.l` — Screen titles (S02, S10, S15, S16).
  static const TypeSpec titleL = TypeSpec(
    name: 'type.title.l',
    fontFamily: 'Geist',
    fontWeight: 600,
    fontSize: 28,
    lineHeight: 34,
    letterSpacingPercent: -1,
    tabularFigures: true,
    maxScale: 1.5,
  );

  /// `type.title.m` — Sheet titles, restaurant name on BalanceCard, dialog titles.
  static const TypeSpec titleM = TypeSpec(
    name: 'type.title.m',
    fontFamily: 'Geist',
    fontWeight: 600,
    fontSize: 22,
    lineHeight: 28,
    letterSpacingPercent: -0.5,
    tabularFigures: true,
    maxScale: 1.5,
  );

  /// `type.body.l` — Primary body, Ready instruction, row primary text.
  static const TypeSpec bodyL = TypeSpec(
    name: 'type.body.l',
    fontFamily: 'Geist',
    fontWeight: 400,
    fontSize: 17,
    lineHeight: 24,
    letterSpacingPercent: 0,
    tabularFigures: true,
    maxScale: 2,
  );

  /// `type.body.m` — Secondary body, banner body, inline messages.
  static const TypeSpec bodyM = TypeSpec(
    name: 'type.body.m',
    fontFamily: 'Geist',
    fontWeight: 400,
    fontSize: 15,
    lineHeight: 22,
    letterSpacingPercent: 0,
    tabularFigures: true,
    maxScale: 2,
  );

  /// `type.label` — Regular buttons, chips, snackbar action.
  static const TypeSpec label = TypeSpec(
    name: 'type.label',
    fontFamily: 'Geist',
    fontWeight: 600,
    fontSize: 15,
    lineHeight: 20,
    letterSpacingPercent: 0,
    tabularFigures: true,
    maxScale: 2,
  );

  /// `type.label.l` — ➕ Large buttons (64 pt CTA).
  static const TypeSpec labelL = TypeSpec(
    name: 'type.label.l',
    fontFamily: 'Geist',
    fontWeight: 600,
    fontSize: 17,
    lineHeight: 22,
    letterSpacingPercent: 0,
    tabularFigures: true,
    maxScale: 2,
  );

  /// `type.caption` — Meta, masked card number, badges, timestamps.
  static const TypeSpec caption = TypeSpec(
    name: 'type.caption',
    fontFamily: 'Geist',
    fontWeight: 500,
    fontSize: 13,
    lineHeight: 18,
    letterSpacingPercent: 0.5,
    tabularFigures: true,
    maxScale: 2,
  );

  /// `type.overline` — 'GIFT CARD' on BalanceCard, section overlines in sheets.
  static const TypeSpec overline = TypeSpec(
    name: 'type.overline',
    fontFamily: 'Geist',
    fontWeight: 600,
    fontSize: 11,
    lineHeight: 14,
    letterSpacingPercent: 8,
    tabularFigures: true,
    maxScale: 1.3,
    uppercase: true,
  );

  /// `type.key` — Keypad digits.
  static const TypeSpec key = TypeSpec(
    name: 'type.key',
    fontFamily: 'Geist',
    fontWeight: 500,
    fontSize: 30,
    lineHeight: 36,
    letterSpacingPercent: 0,
    tabularFigures: true,
    maxScale: 1.2,
  );

  /// `type.cardNumber` — ➕ CardNumberField (S11) only.
  static const TypeSpec cardNumber = TypeSpec(
    name: 'type.cardNumber',
    fontFamily: 'GeistMono',
    fontWeight: 500,
    fontSize: 24,
    lineHeight: 32,
    letterSpacingPercent: 2,
    tabularFigures: true,
    maxScale: 1.3,
    minSizeAfterShrink: 20,
  );

  /// `type.currency.xl` — ➕ Currency symbol inside type.amount.xl (60 % of 64), baseline-aligned.
  static const TypeSpec currencyXl = TypeSpec(
    name: 'type.currency.xl',
    fontFamily: 'Geist',
    fontWeight: 600,
    fontSize: 38,
    lineHeight: 68,
    letterSpacingPercent: -1,
    tabularFigures: true,
    maxScale: 1.3,
  );

  /// `type.currency.l` — ➕ Currency symbol inside type.amount.l (60 % of 48).
  static const TypeSpec currencyL = TypeSpec(
    name: 'type.currency.l',
    fontFamily: 'Geist',
    fontWeight: 600,
    fontSize: 29,
    lineHeight: 52,
    letterSpacingPercent: -1,
    tabularFigures: true,
    maxScale: 1.3,
  );

  /// `type.currency.balance` — ➕ Currency symbol inside type.balance (60 % of 40).
  static const TypeSpec currencyBalance = TypeSpec(
    name: 'type.currency.balance',
    fontFamily: 'Geist',
    fontWeight: 600,
    fontSize: 24,
    lineHeight: 44,
    letterSpacingPercent: -1,
    tabularFigures: true,
    maxScale: 1.3,
  );

  /// `type.currency.ratio` — ➕ Currency symbol size as a fraction of the amount size (04 §3.4).
  static const double currencyRatio = 0.6;

  /// `type.currency.gap.spaced` — ➕ Symbol gap in em of the amount size — de-AT, de-DE, de-CH.
  static const double currencyGapSpaced = 0.16;

  /// `type.currency.gap.tight` — ➕ Symbol gap in em of the amount size — en-GB, en-US.
  static const double currencyGapTight = 0.04;

  /// `type.shrinkStep` — Shrink-to-fit steps down in 2-pt steps (04 §3.7).
  static const double shrinkStep = 2;

  /// Every text style token, in declaration order.
  static const List<TypeSpec> all = <TypeSpec>[
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
  ];
}

/// 04 §4.1 spacing scale (4-pt base).
abstract final class Space {
  /// `space.0` —
  static const double s0 = 0;

  /// `space.1` —
  static const double s1 = 4;

  /// `space.2` —
  static const double s2 = 8;

  /// `space.3` —
  static const double s3 = 12;

  /// `space.4` —
  static const double s4 = 16;

  /// `space.5` —
  static const double s5 = 20;

  /// `space.6` —
  static const double s6 = 24;

  /// `space.8` —
  static const double s8 = 32;

  /// `space.10` —
  static const double s10 = 40;

  /// `space.12` —
  static const double s12 = 48;

  /// `space.16` —
  static const double s16 = 64;
}

/// 04 §4.2–4.5 and 08 §1–2 layout values.
abstract final class LayoutTokens {
  /// `layout.margin.compact` — Width < 400 pt (04 §4.2; 08 W-compact and W-standard).
  static const double marginCompact = 20;

  /// `layout.margin.regular` — Width 400–599 pt (08 W-large).
  static const double marginRegular = 24;

  /// `layout.margin.tablet` — Width ≥ 600 pt.
  static const double marginTablet = 32;

  /// `layout.widthClass.standard` — Lower bound of W-standard (08 §1.1).
  static const double widthClassStandard = 360;

  /// `layout.widthClass.regular` — Lower bound of regular width / W-large (04 §4.2, 08 §1.1).
  static const double widthClassRegular = 400;

  /// `layout.widthClass.tablet` — Lower bound of tablet width (04 §4.2, 08 §1.1).
  static const double widthClassTablet = 600;

  /// `layout.grid.phoneColumns` — 04 §4.2.
  static const int gridPhoneColumns = 4;

  /// `layout.grid.phoneGutter` — 04 §4.2.
  static const double gridPhoneGutter = 8;

  /// `layout.grid.tabletColumns` — 04 §4.2.
  static const int gridTabletColumns = 8;

  /// `layout.grid.tabletGutter` — 04 §4.2.
  static const double gridTabletGutter = 16;

  /// `layout.maxContent.tablet` — ➕ Single-column tablet screens (04 §4.2, A.3).
  static const double maxContentTablet = 560;

  /// `layout.textMeasure.tablet` — ➕ Tablet body text column (04 §3.5, A.3).
  static const double textMeasureTablet = 480;

  /// `layout.textMeasure.centred` — Centred block column: S10, EmptyState, S09, Splash (04 §3.5).
  static const double textMeasureCentred = 320;

  /// `layout.maxForm` — Max form width S02/S11 (08 §2).
  static const double maxForm = 400;

  /// `layout.maxSheet` — Max sheet width on tablets (08 §2).
  static const double maxSheet = 560;

  /// `layout.maxKeypad` — Keypad max width (05 §2.1, 08 §2).
  static const double maxKeypad = 400;

  /// `layout.compactHeight` — Window heights below this are compact (04 §4.3, 08 §1.2).
  static const double compactHeight = 700;

  /// `layout.minWindow.width` — 08 §1.3.
  static const double minWindowWidth = 320;

  /// `layout.minWindow.height` — 08 §1.3.
  static const double minWindowHeight = 568;

  /// `layout.ctaBottom.withHomeIndicator` — CTA block bottom padding on devices with a home indicator / gesture bar (04 §4.4).
  static const double ctaBottomWithHomeIndicator = 16;

  /// `layout.ctaBottom.withoutHomeIndicator` — CTA block bottom padding on devices without (04 §4.4).
  static const double ctaBottomWithoutHomeIndicator = 20;

  /// `layout.gapBeforeCta` — Minimum free space above the CTA block (04 §4.4).
  static const double gapBeforeCta = 32;

  /// `layout.edgeNoTouch` — iOS: nothing interactive within 16 pt of the side edges except full-width buttons (04 §4.5).
  static const double edgeNoTouch = 16;
}

/// 04 §5.1 radius scale.
abstract final class Radii {
  /// `radius.xs` —
  static const double xs = 8;

  /// `radius.s` —
  static const double s = 12;

  /// `radius.m` —
  static const double m = 16;

  /// `radius.l` —
  static const double l = 20;

  /// `radius.xl` —
  static const double xl = 28;

  /// `radius.sheet` —
  static const double sheet = 32;

  /// `radius.full` —
  static const double full = 999;

  /// `radius.continuousMin` — iOS: radii ≥ 16 pt render as continuous corners (04 §5.2).
  static const double continuousMin = 16;
}

/// 04 §7 border widths.
abstract final class Borders {
  /// `border.width.hairline` — ➕ 1 physical pixel = 1 / devicePixelRatio pt (04 §7).
  static double widthHairline(double devicePixelRatio) => 1 / devicePixelRatio;

  /// `border.width.default` — ➕ TextField at rest, HC outlines.
  static const double widthDefault = 1;

  /// `border.width.focus` — ➕ Focus ring, focused/error inputs.
  static const double widthFocus = 2;

  /// `border.width.focus.hc` — ➕ Focus ring in high contrast.
  static const double widthFocusHc = 3;

  /// `border.width.control.hc` — ➕ Input boundary in high contrast (04 §10.1).
  static const double widthControlHc = 2;
}

/// 04 §13.1 focus geometry.
abstract final class FocusTokens {
  /// `focus.offset` — ➕ Ring drawn outside with 2-pt offset (04 §13.1).
  static const double offset = 2;
}

/// 04 A.4 sizes: targets and fixed geometry.
abstract final class Sizes {
  /// `size.target.min` — 56 × 56 pt (brief).
  static const double targetMin = 56;

  /// `size.button.l` — Large button height.
  static const double buttonL = 64;

  /// `size.button.l` at compact height (< 700 pt).
  static const double buttonLCompact = 56;

  /// `size.button.m` — Regular button height.
  static const double buttonM = 56;

  /// `size.key` — Keypad key height.
  static const double key = 72;

  /// `size.key` at compact height (< 700 pt).
  static const double keyCompact = 52;

  /// `size.key.gap` — Keypad gap (≥ 8).
  static const double keyGap = 8;

  /// `size.topBar` — + safe area.
  static const double topBar = 56;

  /// `size.chip` — QuickAmountChip visual height.
  static const double chip = 40;

  /// `size.chip.target` — QuickAmountChip target height.
  static const double chipTarget = 56;

  /// `size.badge` —
  static const double badge = 24;

  /// `size.field` — TextField container.
  static const double field = 56;

  /// `size.cardNumberField` —
  static const double cardNumberField = 64;

  /// `size.row` — TransactionRow min height.
  static const double row = 64;

  /// `size.avatar.m` —
  static const double avatarM = 40;

  /// `size.avatar.l` —
  static const double avatarL = 56;

  /// `size.iconButton.fill` — Pressed fill circle.
  static const double iconButtonFill = 44;

  /// `size.grabber.width` —
  static const double grabberWidth = 36;

  /// `size.grabber.height` —
  static const double grabberHeight = 5;

  /// `size.snackbar.min` —
  static const double snackbarMin = 56;

  /// `size.spinner.s` —
  static const double spinnerS = 20;

  /// Stroke width of `size.spinner.s`.
  static const double spinnerSStroke = 2;

  /// `size.spinner.l` —
  static const double spinnerL = 32;

  /// Stroke width of `size.spinner.l`.
  static const double spinnerLStroke = 3;

  /// `size.ring.hold` —
  static const double ringHold = 28;

  /// Stroke width of `size.ring.hold`.
  static const double ringHoldStroke = 3;

  /// `size.ring.countdown` —
  static const double ringCountdown = 48;

  /// Stroke width of `size.ring.countdown`.
  static const double ringCountdownStroke = 3;

  /// `size.successMark` —
  static const double successMark = 96;

  /// `size.hairline.countdown` —
  static const double hairlineCountdown = 2;

  /// `size.nfc.canvas.width` — Glow may overflow (04 A.4, 05 §3.4).
  static const double nfcCanvasWidth = 176;

  /// `size.nfc.canvas.height` —
  static const double nfcCanvasHeight = 120;

  /// `size.nfc.arc.r1` — Inner arc radius.
  static const double nfcArcR1 = 36;

  /// `size.nfc.arc.r2` — Middle arc radius.
  static const double nfcArcR2 = 56;

  /// `size.nfc.arc.r3` — Outer arc radius.
  static const double nfcArcR3 = 76;

  /// `size.nfc.arc.stroke` —
  static const double nfcArcStroke = 3;

  /// `size.nfc.arc.sweep` — Degrees, centred on 12 o'clock.
  static const int nfcArcSweep = 100;

  /// `size.balanceCard.maxHeight` — Phones (brief).
  static const double balanceCardMaxHeight = 220;

  /// `size.balanceCard.compact` — BalanceCard / compact strip (13 · R11).
  static const double balanceCardCompact = 88;
}

/// Icon size tokens with size-compensated strokes (04 §11.2).
enum IconSize {
  /// `icon.16` — StatusBadge, inline message icon, row chevrons, chips.
  s16(16, 1.5),

  /// `icon.20` — Regular buttons, Banner, Snackbar leading icon.
  s20(20, 1.75),

  /// `icon.24` — Default: TopBar IconButtons, large buttons, StatusBanner, keypad delete.
  s24(24, 1.75),

  /// `icon.32` — BalanceCard NFC glyph, NfcScanAnimation centre glyph.
  s32(32, 2),

  /// `icon.48` — ProblemScreen icon, S16 permission states.
  s48(48, 2.5);

  const IconSize(this.size, this.stroke);

  /// Rendered size in pt.
  final double size;

  /// Stroke width in pt at [size] (strokes never scale).
  final double stroke;

  /// Icon master viewBox (10 §3.1).
  static const double grid = 24;
}

/// 10 §4.3 illustration sizes and stroke.
abstract final class IllustrationTokens {
  /// `illustration.problem` — S10, S15 (10 §4.3).
  static const double problem = 120;

  /// `illustration.problem` at compact height (< 700 pt).
  static const double problemCompact = 96;

  /// `illustration.empty` — S13 Recent empty state (10 §4.3).
  static const double empty = 96;

  /// `illustration.intro` — S17 intro (10 §4.3, 13 · R04).
  static const double intro = 160;

  /// `illustration.intro` at compact height (< 700 pt).
  static const double introCompact = 120;

  /// `illustration.stroke` — Monoline stroke at the rendered size (10 §4.2).
  static const double stroke = 1.75;

  /// `illustration.strokeHcExtra` — High contrast: stroke +0.25 pt (10 §4.5).
  static const double strokeHcExtra = 0.25;

  /// `illustration.hideAtTextScale` — Problem screens hide the illustration at text size ≥ 150 % (10 §4.3).
  static const double hideAtTextScale = 1.5;
}

/// Elevation per theme (04 §6, A.5).
///
/// Light: shadows. Dark: no shadows; surface steps plus a
/// hairline outline (09 §2.4). Resolve from the active
/// [WaiterColors] so the high-contrast modifier propagates.
@immutable
class WaiterElevation {
  const WaiterElevation({
    required this.brightness,
    required this.level0,
    required this.level1,
    required this.level2,
    required this.level3,
    required this.level3Upward,
    required this.cardOutline,
  });

  /// Resolves the elevation set for [colors].
  factory WaiterElevation.resolve(WaiterColors colors) {
    if (colors.brightness == Brightness.dark) {
      return WaiterElevation(
        brightness: Brightness.dark,
        level0: ElevationLevel.none,
        level1: ElevationLevel(
          surface: colors.bgSurface,
          outline: colors.borderSubtle,
        ),
        level2: ElevationLevel(
          surface: colors.bgRaised,
          outline: colors.borderSubtle,
        ),
        level3: ElevationLevel(
          surface: colors.bgSurface,
          outline: colors.borderSubtle,
        ),
        level3Upward: ElevationLevel(
          surface: colors.bgSurface,
          outline: colors.borderSubtle,
        ),
        cardOutline: colors.cardBorderDark,
      );
    }
    return const WaiterElevation(
      brightness: Brightness.light,
      level0: ElevationLevel.none,
      level1: ElevationLevel(
        shadows: <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 1),
            blurRadius: 2,
            spreadRadius: 0,
          ),
        ],
      ),
      level2: ElevationLevel(
        shadows: <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      level3: ElevationLevel(
        shadows: <BoxShadow>[
          BoxShadow(
            color: Color(0x1F000000),
            offset: Offset(0, 12),
            blurRadius: 32,
            spreadRadius: 0,
          ),
        ],
      ),
      level3Upward: ElevationLevel(
        shadows: <BoxShadow>[
          BoxShadow(
            color: Color(0x1F000000),
            offset: Offset(0, -12),
            blurRadius: 32,
            spreadRadius: 0,
          ),
        ],
      ),
      cardOutline: null,
    );
  }

  /// Theme of this set.
  final Brightness brightness;

  /// `elev.0`.
  final ElevationLevel level0;

  /// `elev.1`.
  final ElevationLevel level1;

  /// `elev.2`.
  final ElevationLevel level2;

  /// `elev.3`.
  final ElevationLevel level3;

  /// `elev.3` cast upward (sheets).
  final ElevationLevel level3Upward;

  /// `elev.card` dark treatment: 1-px outline, no glow.
  final Color? cardOutline;

  /// Whether this theme expresses elevation with shadows.
  bool get usesShadows => brightness == Brightness.light;

  /// Interpolates for the theme cross-fade.
  static WaiterElevation lerp(WaiterElevation a, WaiterElevation b, double t) {
    if (t == 0) return a;
    if (t == 1) return b;
    return WaiterElevation(
      brightness: t < 0.5 ? a.brightness : b.brightness,
      level0: ElevationLevel.lerp(a.level0, b.level0, t),
      level1: ElevationLevel.lerp(a.level1, b.level1, t),
      level2: ElevationLevel.lerp(a.level2, b.level2, t),
      level3: ElevationLevel.lerp(a.level3, b.level3, t),
      level3Upward: ElevationLevel.lerp(a.level3Upward, b.level3Upward, t),
      cardOutline: Color.lerp(a.cardOutline, b.cardOutline, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WaiterElevation &&
      other.brightness == brightness &&
      other.level0 == level0 &&
      other.level1 == level1 &&
      other.level2 == level2 &&
      other.level3 == level3 &&
      other.level3Upward == level3Upward &&
      other.cardOutline == cardOutline;

  @override
  int get hashCode => Object.hash(
    brightness,
    level0,
    level1,
    level2,
    level3,
    level3Upward,
    cardOutline,
  );
}

/// 04 §13.2 opacity tokens.
abstract final class Opacities {
  /// `opacity.disabled` — ➕ Disabled groups only.
  static const double disabled = 0.4;

  /// `opacity.cardSecondary` — ➕ Secondary text on BalanceCard if still ≥ 4.5 : 1.
  static const double cardSecondary = 0.76;

  /// `opacity.placeholder` — ➕ Placeholders use fg.tertiary at full opacity.
  static const double placeholder = 1;

  /// `opacity.pressedOverlay` —
  static const double pressedOverlay = 0.08;

  /// `opacity.hover` —
  static const double hover = 0.04;

  /// `opacity.holdTrack.light` —
  static const double holdTrackLight = 0.24;

  /// `opacity.holdTrack.dark` —
  static const double holdTrackDark = 0.16;

  /// `opacity.skeletonPlaceholder.card` — ➕ Placeholder bars on a brand-coloured skeleton card.
  static const double skeletonPlaceholderCard = 0.16;

  /// `opacity.skeletonHighlight` —
  static const double skeletonHighlight = 0.08;

  /// `opacity.spinnerTrack` — Spinner track = current colour at 16 % (04 §17.2).
  static const double spinnerTrack = 0.16;

  /// `opacity.nfc.idle.inner` —
  static const double nfcIdleInner = 0.8;

  /// `opacity.nfc.idle.middle` —
  static const double nfcIdleMiddle = 0.56;

  /// `opacity.nfc.idle.outer` —
  static const double nfcIdleOuter = 0.32;
}

/// 04 §14 z-order.
abstract final class ZLayers {
  /// `z.content` —
  static const int content = 0;

  /// `z.chrome` —
  static const int chrome = 10;

  /// `z.scrim` —
  static const int scrim = 20;

  /// `z.sheet` —
  static const int sheet = 30;

  /// `z.sheetStacked` —
  static const int sheetStacked = 40;

  /// `z.snackbar` —
  static const int snackbar = 45;

  /// `z.dialog` —
  static const int dialog = 50;
}

/// 04 §15 / 06 §2 motion tokens. Springs use mass 1, stiffness (2π/response)² and damping 4π·ζ/response.
abstract final class Motion {
  /// `motion.duration.instant` —
  static const Duration durationInstant = Duration(milliseconds: 90);

  /// `motion.duration.fast` —
  static const Duration durationFast = Duration(milliseconds: 160);

  /// `motion.duration.base` —
  static const Duration durationBase = Duration(milliseconds: 240);

  /// `motion.duration.slow` —
  static const Duration durationSlow = Duration(milliseconds: 360);

  /// `motion.duration.emphasis` —
  static const Duration durationEmphasis = Duration(milliseconds: 520);

  /// `motion.ease.standard` — Default for everything that moves and stays.
  static const Cubic easeStandard = Cubic(0.2, 0, 0, 1);

  /// `motion.ease.decelerate` — Entering elements, release.
  static const Cubic easeDecelerate = Cubic(0, 0, 0, 1);

  /// `motion.ease.accelerate` — Leaving elements.
  static const Cubic easeAccelerate = Cubic(0.3, 0, 1, 1);

  /// `motion.spring.card` — BalanceCard arrival, SuccessMark halo (13 · R10).
  static const SpringDescription springCard = SpringDescription(
    mass: 1,
    stiffness: 223.80055331268386,
    damping: 24.534342628034576,
  );

  /// Response of `motion.spring.card` in seconds.
  static const double springCardResponse = 0.42;

  /// Damping ratio ζ of `motion.spring.card`.
  static const double springCardDampingRatio = 0.82;

  /// `motion.spring.soft` — Sheets, snackbar.
  static const SpringDescription springSoft = SpringDescription(
    mass: 1,
    stiffness: 130.5071656342394,
    damping: 20.563151914405918,
  );

  /// Response of `motion.spring.soft` in seconds.
  static const double springSoftResponse = 0.55;

  /// Damping ratio ζ of `motion.spring.soft`.
  static const double springSoftDampingRatio = 0.9;

  /// `motion.pressScale.key` — 13 · R20.
  static const double pressScaleKey = 0.96;

  /// `motion.pressScale.button` — 13 · R20.
  static const double pressScaleButton = 0.98;

  /// `motion.pressScale.chip` — 13 · R20.
  static const double pressScaleChip = 0.97;
}

/// 04 §15 timing tokens.
abstract final class Times {
  /// `time.feedbackDelay` — Skeleton / spinner only after 150 ms.
  static const Duration feedbackDelay = Duration(milliseconds: 150);

  /// `time.lookupSlow` — 'Still looking…'.
  static const Duration lookupSlow = Duration(milliseconds: 3000);

  /// `time.lookupTimeout` — Network error.
  static const Duration lookupTimeout = Duration(milliseconds: 10000);

  /// `time.redeemSlow` — 'Connection slow', automatic idempotent retry.
  static const Duration redeemSlow = Duration(milliseconds: 8000);

  /// `time.hold` —
  static const Duration hold = Duration(milliseconds: 600);

  /// `time.longPressClear` — Keypad delete long-press.
  static const Duration longPressClear = Duration(milliseconds: 500);

  /// `time.successReturn` —
  static const Duration successReturn = Duration(milliseconds: 4000);

  /// `time.cardSwap` — Android new-card cross-fade.
  static const Duration cardSwap = Duration(milliseconds: 300);

  /// `time.snackbar` —
  static const Duration snackbar = Duration(milliseconds: 4000);

  /// `time.skeletonSweep` — Linear.
  static const Duration skeletonSweep = Duration(milliseconds: 1200);

  /// `time.spinnerTurn` — One revolution, linear.
  static const Duration spinnerTurn = Duration(milliseconds: 800);

  /// `time.minIndicator` — An indicator, once shown, stays at least this long.
  static const Duration minIndicator = Duration(milliseconds: 240);
}

/// Haptic tokens with platform mapping (04 §16, 11 §2.1, §5).
///
/// Components never call platform haptics directly; they hand a
/// token to the feedback service (09 §2.5, §7.8).
enum HapticToken {
  /// `haptic.key` — An input registered (keypad touch-down).
  key(
    'haptic.key',
    HapticSpec(
      severity: 0,
      ios: IosHapticSpec(
        generator: IosHapticGenerator.impact,
        impactStyle: IosImpactStyle.light,
        intensities: <double>[0.5],
      ),
      androidApi30: AndroidHapticSpec(
        constants: <AndroidHapticConstant>[AndroidHapticConstant.keyboardTap],
      ),
      androidFallback: AndroidHapticSpec(
        constants: <AndroidHapticConstant>[AndroidHapticConstant.keyboardTap],
      ),
    ),
  ),

  /// `haptic.select` — A choice/selection changed.
  select(
    'haptic.select',
    HapticSpec(
      severity: 1,
      ios: IosHapticSpec(generator: IosHapticGenerator.selection),
      androidApi30: AndroidHapticSpec(
        constants: <AndroidHapticConstant>[AndroidHapticConstant.clockTick],
      ),
      androidFallback: AndroidHapticSpec(
        constants: <AndroidHapticConstant>[AndroidHapticConstant.clockTick],
      ),
    ),
  ),

  /// `haptic.cardDetected` — A card was read. Paired with sound.cardDetected.
  cardDetected(
    'haptic.cardDetected',
    HapticSpec(
      severity: 2,
      ios: IosHapticSpec(
        generator: IosHapticGenerator.impact,
        impactStyle: IosImpactStyle.medium,
        intensities: <double>[1],
      ),
      androidApi30: AndroidHapticSpec(
        constants: <AndroidHapticConstant>[AndroidHapticConstant.confirm],
      ),
      androidFallback: AndroidHapticSpec(
        oneShot: VibrationOneShot(durationMs: 20, amplitude: 180),
      ),
    ),
  ),

  /// `haptic.success` — Money moved. Paired with sound.success.
  success(
    'haptic.success',
    HapticSpec(
      severity: 3,
      ios: IosHapticSpec(
        generator: IosHapticGenerator.notification,
        notificationType: IosNotificationType.success,
      ),
      androidApi30: AndroidHapticSpec(
        constants: <AndroidHapticConstant>[AndroidHapticConstant.confirm],
        waveform: VibrationWaveform(
          timingsMs: <int>[0, 20, 60, 30],
          amplitudes: <int>[0, 160, 0, 255],
        ),
        waveformDelayMs: 40,
      ),
      androidFallback: AndroidHapticSpec(
        waveform: VibrationWaveform(
          timingsMs: <int>[0, 20, 60, 30],
          amplitudes: <int>[0, 160, 0, 255],
        ),
      ),
    ),
  ),

  /// `haptic.warning` — Attention, recoverable.
  warning(
    'haptic.warning',
    HapticSpec(
      severity: 4,
      ios: IosHapticSpec(
        generator: IosHapticGenerator.notification,
        notificationType: IosNotificationType.warning,
      ),
      androidApi30: AndroidHapticSpec(
        waveform: VibrationWaveform(
          timingsMs: <int>[0, 30, 80, 30],
          amplitudes: <int>[0, 200, 0, 200],
        ),
      ),
      androidFallback: AndroidHapticSpec(
        waveform: VibrationWaveform(
          timingsMs: <int>[0, 30, 80, 30],
          amplitudes: <int>[0, 200, 0, 200],
        ),
      ),
    ),
  ),

  /// `haptic.error` — Failed / blocked.
  error(
    'haptic.error',
    HapticSpec(
      severity: 5,
      ios: IosHapticSpec(
        generator: IosHapticGenerator.notification,
        notificationType: IosNotificationType.error,
      ),
      androidApi30: AndroidHapticSpec(
        constants: <AndroidHapticConstant>[AndroidHapticConstant.reject],
      ),
      androidFallback: AndroidHapticSpec(
        waveform: VibrationWaveform(
          timingsMs: <int>[0, 40, 60, 40, 60, 40],
          amplitudes: <int>[0, 255, 0, 255, 0, 255],
        ),
      ),
    ),
  ),

  /// `haptic.holdTick` — HoldButton at 33 / 66 / 100 % (step index selects intensity / constant).
  holdTick(
    'haptic.holdTick',
    HapticSpec(
      severity: 1,
      ios: IosHapticSpec(
        generator: IosHapticGenerator.impact,
        impactStyle: IosImpactStyle.rigid,
        intensities: <double>[0.5, 0.7, 1],
      ),
      androidApi30: AndroidHapticSpec(
        constants: <AndroidHapticConstant>[
          AndroidHapticConstant.clockTick,
          AndroidHapticConstant.clockTick,
          AndroidHapticConstant.confirm,
        ],
      ),
      androidFallback: AndroidHapticSpec(
        constants: <AndroidHapticConstant>[
          AndroidHapticConstant.clockTick,
          AndroidHapticConstant.clockTick,
          AndroidHapticConstant.clockTick,
        ],
      ),
      stepsMs: <int>[200, 400, 600],
    ),
  );

  const HapticToken(this.id, this.spec);

  /// Token name, e.g. `haptic.success`.
  final String id;

  /// Platform mapping.
  final HapticSpec spec;

  /// Keys coalesce to at most one haptic per this interval (11 T5).
  static const Duration keyCoalesce = Duration(milliseconds: 50);

  /// Two different haptics closer than this: the later,
  /// higher-severity one wins (11 T6).
  static const Duration minSpacing = Duration(milliseconds: 80);
}

/// Sound tokens (04 §16, 11 §2.2, §6).
enum SoundToken {
  /// `sound.cardDetected` — Single soft glass tick, 1.6 kHz.
  cardDetected(
    'sound.cardDetected',
    SoundSpec(
      file: 'gcw_card_detected',
      maxDuration: Duration(milliseconds: 60),
      loudnessLufsM: -22,
      truePeakDbtp: -1,
    ),
  ),

  /// `sound.success` — Two-note rising chime E6 → B6 — the signature.
  success(
    'sound.success',
    SoundSpec(
      file: 'gcw_success',
      maxDuration: Duration(milliseconds: 280),
      loudnessLufsM: -18,
      truePeakDbtp: -1,
    ),
  ),

  /// `sound.warning` — Single mid tone 660 Hz.
  warning(
    'sound.warning',
    SoundSpec(
      file: 'gcw_warning',
      maxDuration: Duration(milliseconds: 150),
      loudnessLufsM: -20,
      truePeakDbtp: -1,
    ),
  ),

  /// `sound.error` — Two low tones 330 Hz, 2 × 90 ms, 60 ms gap.
  error(
    'sound.error',
    SoundSpec(
      file: 'gcw_error',
      maxDuration: Duration(milliseconds: 240),
      loudnessLufsM: -20,
      truePeakDbtp: -1,
    ),
  );

  const SoundToken(this.id, this.spec);

  /// Token name, e.g. `sound.success`.
  final String id;

  /// File and level data.
  final SoundSpec spec;
}

/// Tier 3 — 05 §1.0 shared button rules.
abstract final class ButtonTokens {
  /// `button.large.height` —
  static const double largeHeight = 64;

  /// `button.large.radius` —
  static const double largeRadius = 20;

  /// `button.large.paddingHorizontal` —
  static const double largePaddingHorizontal = 24;

  /// `button.large.iconGap` —
  static const double largeIconGap = 8;

  /// `button.regular.height` —
  static const double regularHeight = 56;

  /// `button.regular.radius` —
  static const double regularRadius = 16;

  /// `button.regular.paddingHorizontal` —
  static const double regularPaddingHorizontal = 20;

  /// `button.regular.iconGap` —
  static const double regularIconGap = 8;

  /// `button.regular.minWidth` —
  static const double regularMinWidth = 120;

  /// `button.labelPaddingVerticalMin` — Wrapped labels: min 12 pt top/bottom.
  static const double labelPaddingVerticalMin = 12;

  /// `button.stackGap` —
  static const double stackGap = 12;

  /// `button.sideBySideGap` —
  static const double sideBySideGap = 8;

  /// `button.cancelSlop` — A touch that moves > 16 pt outside cancels the press.
  static const double cancelSlop = 16;

  /// `button.tertiary.pressedFillHeight` —
  static const double tertiaryPressedFillHeight = 44;

  /// `button.tertiary.radius` —
  static const double tertiaryRadius = 16;

  /// `button.tertiary.paddingHorizontal` —
  static const double tertiaryPaddingHorizontal = 16;

  /// `button.tertiary.minWidth` —
  static const double tertiaryMinWidth = 120;
}

/// Tier 3 — 05 §1.5.
abstract final class HoldButtonTokens {
  /// `holdButton.ringInset` — Ring leading inset (centre 34 pt from the leading edge).
  static const double ringInset = 20;

  /// `holdButton.labelPaddingHorizontal` —
  static const double labelPaddingHorizontal = 60;

  /// `holdButton.lineGap` —
  static const double lineGap = 2;

  /// `holdButton.captionOpacity` — Line 2 in fg.onAccent at 72 %.
  static const double captionOpacity = 0.72;

  /// `holdButton.disabledTrackOpacity` — Disabled ring track: fg.tertiary at 24 %.
  static const double disabledTrackOpacity = 0.24;

  /// `holdButton.slop` — Hold cancelled when the finger leaves by more than 12 pt (13 · R21).
  static const double slop = 12;

  /// `holdButton.tapTeachThreshold` — A press shorter than this emphasises line 2.
  static const Duration tapTeachThreshold = Duration(milliseconds: 250);

  /// `holdButton.tapTeachDuration` —
  static const Duration tapTeachDuration = Duration(milliseconds: 1200);

  /// `holdButton.thresholdCents` — holdToConfirmThresholdCents (€ 100,00).
  static const int thresholdCents = 10000;
}

/// Tier 3 — 05 §1.6.
abstract final class IconButtonTokens {
  /// `iconButton.target` —
  static const double target = 56;

  /// `iconButton.fill` —
  static const double fill = 44;

  /// `iconButton.marginInset` — Target edge at margin − 16 pt.
  static const double marginInset = 16;
}

/// Tier 3 — 05 §2.1.
abstract final class KeypadTokens {
  /// `keypad.key.height` —
  static const double keyHeight = 72;

  /// `keypad.key.height` at compact height (< 700 pt).
  static const double keyHeightCompact = 52;

  /// `keypad.key.radius` —
  static const double keyRadius = 20;

  /// `keypad.gap` —
  static const double gap = 8;

  /// `keypad.maxWidth` —
  static const double maxWidth = 400;

  /// `keypad.deleteNudge` — Delete glyph nudged 1 pt left (04 §11.3).
  static const double deleteNudge = -1;

  /// `keypad.maxAmountDigits` —
  static const int maxAmountDigits = 7;

  /// `keypad.maxCardDigits` —
  static const int maxCardDigits = 16;
}

/// Tier 3 — 05 §2.2.
abstract final class AmountDisplayTokens {
  /// `amountDisplay.messageGap` —
  static const double messageGap = 4;

  /// `amountDisplay.messageMinHeight` —
  static const double messageMinHeight = 40;

  /// `amountDisplay.messageIconGap` —
  static const double messageIconGap = 8;

  /// `amountDisplay.digitSlide` —
  static const double digitSlide = 8;

  /// `amountDisplay.limitNudge` — Limit-reached nudge ±3 pt (13 · R18).
  static const double limitNudge = 3;

  /// `amountDisplay.announceDebounce` —
  static const Duration announceDebounce = Duration(milliseconds: 400);
}

/// Tier 3 — 05 §2.3 QuickAmountChip.
abstract final class ChipTokens {
  /// `chip.height` —
  static const double height = 40;

  /// `chip.target` —
  static const double target = 56;

  /// `chip.radius` —
  static const double radius = 8;

  /// `chip.paddingHorizontal` —
  static const double paddingHorizontal = 12;

  /// `chip.enterRise` —
  static const double enterRise = 4;
}

/// Tier 3 — 05 §2.4.
abstract final class TextFieldTokens {
  /// `textField.height` —
  static const double height = 56;

  /// `textField.radius` —
  static const double radius = 12;

  /// `textField.paddingHorizontal` —
  static const double paddingHorizontal = 16;

  /// `textField.labelGap` —
  static const double labelGap = 8;

  /// `textField.helperGap` —
  static const double helperGap = 8;

  /// `textField.stackGap` —
  static const double stackGap = 16;

  /// `textField.shake` — Field error shake ±6 pt, 240 ms, 2 cycles (13 · R18).
  static const double shake = 6;
}

/// Tier 3 — 05 §2.5.
abstract final class CardNumberFieldTokens {
  /// `cardNumberField.height` —
  static const double height = 64;

  /// `cardNumberField.radius` —
  static const double radius = 12;

  /// `cardNumberField.paddingHorizontal` —
  static const double paddingHorizontal = 16;

  /// `cardNumberField.groupGap` —
  static const double groupGap = 12;

  /// `cardNumberField.caretWidth` —
  static const double caretWidth = 2;

  /// `cardNumberField.caretHeight` —
  static const double caretHeight = 24;

  /// `cardNumberField.caretBlink` —
  static const Duration caretBlink = Duration(milliseconds: 1000);
}

/// Tier 3 — 05 §3.1, 04 §8.6.
abstract final class BalanceCardTokens {
  /// `balanceCard.aspectRatio` — ID-1 width ÷ height.
  static const double aspectRatio = 1.586;

  /// `balanceCard.minFullHeight` — Below this the compact strip is used; above it the full card face scales down as a whole.
  static const double minFullHeight = 96;

  /// `balanceCard.padding` —
  static const double padding = 24;

  /// `balanceCard.glyphSize` —
  static const double glyphSize = 32;

  /// `balanceCard.nameGlyphClearance` —
  static const double nameGlyphClearance = 40;

  /// `balanceCard.overlineGap` —
  static const double overlineGap = 4;

  /// `balanceCard.metaGap` —
  static const double metaGap = 4;

  /// `balanceCard.badgeGap` —
  static const double badgeGap = 8;

  /// `balanceCard.compact.height` —
  static const double compactHeight = 88;

  /// `balanceCard.compact.radius` —
  static const double compactRadius = 20;

  /// `balanceCard.compact.padding` —
  static const double compactPadding = 12;

  /// `balanceCard.compact.glyphSize` —
  static const double compactGlyphSize = 20;

  /// `balanceCard.compact.rowGap` —
  static const double compactRowGap = 2;

  /// `balanceCard.sheenMix` — Sheen stops: +6 % toward white → +6 % toward black (sRGB).
  static const double sheenMix = 0.06;

  /// `balanceCard.desaturation` — OKLCH chroma reduction for blocked/expired/replaced.
  static const double desaturation = 0.4;

  /// `balanceCard.minTextContrast` —
  static const double minTextContrast = 4.5;

  /// `balanceCard.minGlyphContrast` —
  static const double minGlyphContrast = 3;

  /// `balanceCard.lightEdgeContrast` —
  static const double lightEdgeContrast = 1.5;

  /// `balanceCard.textDark` — Near-black text candidate B (04 §8.6).
  static const Color textDark = Color(0xFF0A0A0C);

  /// `balanceCard.textLight` — White text candidate A (04 §8.6).
  static const Color textLight = Color(0xFFFFFFFF);

  /// `balanceCard.shadowAlpha` —
  static const double shadowAlpha = 0.28;
}

/// Tier 3 — 05 §3.2.
abstract final class StatusBadgeTokens {
  /// `statusBadge.height` —
  static const double height = 24;

  /// `statusBadge.paddingHorizontal` —
  static const double paddingHorizontal = 8;

  /// `statusBadge.iconGap` —
  static const double iconGap = 4;

  /// `statusBadge.radius` —
  static const double radius = 8;

  /// `statusBadge.darkTextOutlineOpacity` — On a card with dark text: 1-px outline in that text colour at 16 %.
  static const double darkTextOutlineOpacity = 0.16;
}

/// Tier 3 — 05 §3.3.
abstract final class StatusBannerTokens {
  /// `statusBanner.radius` —
  static const double radius = 16;

  /// `statusBanner.padding` —
  static const double padding = 16;

  /// `statusBanner.iconGap` —
  static const double iconGap = 12;

  /// `statusBanner.titleBodyGap` —
  static const double titleBodyGap = 2;

  /// `statusBanner.bodyActionGap` —
  static const double bodyActionGap = 4;

  /// `statusBanner.minHeight` —
  static const double minHeight = 56;

  /// `statusBanner.darkOutlineOpacity` —
  static const double darkOutlineOpacity = 0.24;
}

/// Tier 3 — 05 §3.4 NfcScanAnimation.
abstract final class NfcScanTokens {
  /// `nfcScan.centerY` — Centre C at (88, 100) in the 176 × 120 canvas.
  static const double centerY = 100;

  /// `nfcScan.dot` —
  static const double dot = 8;

  /// `nfcScan.glowRadius` —
  static const double glowRadius = 96;

  /// `nfcScan.breathPeriod` — 13 · R07.
  static const Duration breathPeriod = Duration(milliseconds: 2400);

  /// `nfcScan.breathScale` —
  static const double breathScale = 1.04;

  /// `nfcScan.readingScale` —
  static const double readingScale = 1.06;

  /// `nfcScan.outerLag` —
  static const Duration outerLag = Duration(milliseconds: 120);

  /// `nfcScan.disabledDotStroke` —
  static const double disabledDotStroke = 1.5;
}

/// Tier 3 — 05 §3.8.
abstract final class SuccessMarkTokens {
  /// `successMark.size` —
  static const double size = 96;

  /// `successMark.checkStroke` —
  static const double checkStroke = 6;

  /// `successMark.circleDraw` — 13 · R09.
  static const Duration circleDraw = Duration(milliseconds: 240);

  /// `successMark.checkDraw` — 13 · R09.
  static const Duration checkDraw = Duration(milliseconds: 200);
}

/// Tier 3 — 05 §3.10.
abstract final class TransactionRowTokens {
  /// `transactionRow.height` —
  static const double height = 64;

  /// `transactionRow.paddingVertical` —
  static const double paddingVertical = 10;

  /// `transactionRow.timeColumn` —
  static const double timeColumn = 48;

  /// `transactionRow.timeColumn12h` —
  static const double timeColumn12h = 64;

  /// `transactionRow.chevronGap` —
  static const double chevronGap = 8;

  /// `transactionRow.pressedInset` —
  static const double pressedInset = 8;
}

/// Tier 3 — 05 §3.11.
abstract final class HistoryCardTokens {
  /// `historyCard.radius` —
  static const double radius = 28;

  /// `historyCard.padding` —
  static const double padding = 20;
}

/// Tier 3 — 05 §4.1.
abstract final class SnackbarTokens {
  /// `snackbar.maxWidth` —
  static const double maxWidth = 560;

  /// `snackbar.minHeight` —
  static const double minHeight = 56;

  /// `snackbar.radius` —
  static const double radius = 12;

  /// `snackbar.paddingHorizontal` —
  static const double paddingHorizontal = 16;

  /// `snackbar.paddingVertical` —
  static const double paddingVertical = 12;

  /// `snackbar.actionGap` —
  static const double actionGap = 16;

  /// `snackbar.ctaGap` —
  static const double ctaGap = 12;

  /// `snackbar.noCtaBottomGap` —
  static const double noCtaBottomGap = 16;

  /// `snackbar.enterRise` —
  static const double enterRise = 16;

  /// `snackbar.exitDrop` —
  static const double exitDrop = 8;

  /// `snackbar.accessibleDuration` — Informational snackbars with a screen reader or Switch Control.
  static const Duration accessibleDuration = Duration(milliseconds: 10000);
}

/// Tier 3 — 05 §4.2 BottomSheet.
abstract final class SheetTokens {
  /// `sheet.radius` —
  static const double radius = 32;

  /// `sheet.grabberTop` —
  static const double grabberTop = 8;

  /// `sheet.handleArea` —
  static const double handleArea = 24;

  /// `sheet.header` —
  static const double header = 56;

  /// `sheet.largeTopGap` —
  static const double largeTopGap = 12;

  /// `sheet.stackedScrim` — Second scrim over the first sheet.
  static const Color stackedScrim = Color(0x52000000);

  /// `sheet.dismissFraction` —
  static const double dismissFraction = 0.3;

  /// `sheet.dismissVelocity` — pt/s.
  static const int dismissVelocity = 800;
}

/// Tier 3 — 05 §4.3.
abstract final class DialogTokens {
  /// `dialog.maxWidth` —
  static const double maxWidth = 360;

  /// `dialog.radius` —
  static const double radius = 28;

  /// `dialog.padding` —
  static const double padding = 24;

  /// `dialog.offsetY` —
  static const double offsetY = -24;

  /// `dialog.titleBodyGap` —
  static const double titleBodyGap = 8;

  /// `dialog.bodyButtonsGap` —
  static const double bodyButtonsGap = 24;

  /// `dialog.buttonGap` —
  static const double buttonGap = 12;

  /// `dialog.enterScale` —
  static const double enterScale = 0.96;
}

/// Tier 3 — 05 §4.4.
abstract final class BannerTokens {
  /// `banner.minHeight` —
  static const double minHeight = 48;

  /// `banner.minHeightWithAction` —
  static const double minHeightWithAction = 56;

  /// `banner.paddingVertical` —
  static const double paddingVertical = 12;

  /// `banner.iconGap` —
  static const double iconGap = 12;

  /// `banner.edgeOpacity` —
  static const double edgeOpacity = 0.24;
}

/// Tier 3 — 05 §4.5.
abstract final class EmptyStateTokens {
  /// `emptyState.illustrationGap` —
  static const double illustrationGap = 24;

  /// `emptyState.titleBodyGap` —
  static const double titleBodyGap = 8;

  /// `emptyState.actionGap` —
  static const double actionGap = 24;

  /// `emptyState.column` —
  static const double column = 320;

  /// `emptyState.bias` —
  static const double bias = 24;
}

/// Tier 3 — 05 §4.6.
abstract final class ProblemScreenTokens {
  /// `problemScreen.column` —
  static const double column = 320;

  /// `problemScreen.illustrationGap` — Illustration → title (10 §4.3, authoritative for illustration placement).
  static const double illustrationGap = 32;

  /// `problemScreen.iconGap` — Icon 48 / ProgressRing → title (05 §4.6).
  static const double iconGap = 24;

  /// `problemScreen.titleBodyGap` —
  static const double titleBodyGap = 12;

  /// `problemScreen.bodyCodeGap` —
  static const double bodyCodeGap = 16;

  /// `problemScreen.actionGap` —
  static const double actionGap = 12;

  /// `problemScreen.bias` —
  static const double bias = 32;
}

/// Tier 3 — 05 §5.1.
abstract final class TopBarTokens {
  /// `topBar.height` —
  static const double height = 56;

  /// `topBar.avatarGap` —
  static const double avatarGap = 12;
}
