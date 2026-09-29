import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tokens/tokens.dart';
import 'context_ext.dart';
import 'svg_stroke_loader.dart';

/// Every icon of the app (10 §3.2; semantic map 04 §11.4).
///
/// One meaning, one icon, everywhere. Files are `assets/icons/ic_<name>.svg`
/// on a 24 × 24 grid, stroke 1.75, round caps and joins, `currentColor`.
/// Optical nudges of 04 §11.3 are drawn into the masters (`delete` −1,
/// `nfcArcs` toward its open side).
enum WaiterIcon {
  /// NFC arcs (custom): BalanceCard, S05 centre glyph, iOS "Scan card".
  nfcArcs('ic_nfc_arcs'),

  /// Card with arcs, the app mark (custom): S01, S02, S04.
  cardArcs('ic_card_arcs'),

  /// Close: task screens and sheets.
  x('ic_x'),

  /// Recent redemptions (TopBar).
  history('ic_history'),

  /// Menu (TopBar).
  menu('ic_menu'),

  /// Delete digit (keypad).
  delete('ic_delete'),

  /// QR scan.
  scanQrCode('ic_scan_qr_code'),

  /// Manual entry.
  keyboard('ic_keyboard'),

  /// Scan frame hint (S12).
  scanLine('ic_scan_line'),

  /// Success / active.
  circleCheck('ic_circle_check'),

  /// Plain check (selected state).
  check('ic_check'),

  /// Warning.
  triangleAlert('ic_triangle_alert'),

  /// Error / danger.
  circleAlert('ic_circle_alert'),

  /// Info.
  info('ic_info'),

  /// Blocked.
  ban('ic_ban'),

  /// Expired.
  calendarX('ic_calendar_x'),

  /// Inactive.
  circleDashed('ic_circle_dashed'),

  /// Used up / zero balance.
  wallet('ic_wallet'),

  /// Replaced.
  replace('ic_replace'),

  /// Clock (connection slow, throttled).
  clock('ic_clock'),

  /// Offline.
  wifiOff('ic_wifi_off'),

  /// Refresh (uncertain status line).
  refreshCw('ic_refresh_cw'),

  /// Server error.
  serverOff('ic_server_off'),

  /// Verification.
  shieldAlert('ic_shield_alert'),

  /// Locked / revoked / paused.
  lock('ic_lock'),

  /// Maintenance.
  wrench('ic_wrench'),

  /// Update required.
  circleArrowUp('ic_circle_arrow_up'),

  /// Face ID.
  scanFace('ic_scan_face'),

  /// Fingerprint / Touch ID.
  fingerprint('ic_fingerprint'),

  /// Show password.
  eye('ic_eye'),

  /// Hide password.
  eyeOff('ic_eye_off'),

  /// Torch on.
  flashlight('ic_flashlight'),

  /// Torch off.
  flashlightOff('ic_flashlight_off'),

  /// Row chevron.
  chevronRight('ic_chevron_right'),

  /// Settings.
  settings('ic_settings'),

  /// Help.
  circleHelp('ic_circle_help'),

  /// Sign out.
  logOut('ic_log_out'),

  /// Theme light.
  sun('ic_sun'),

  /// Theme dark.
  moon('ic_moon'),

  /// Theme system / device.
  smartphone('ic_smartphone'),

  /// Sound.
  volume2('ic_volume_2'),

  /// Haptics.
  vibrate('ic_vibrate'),

  /// Keep screen on.
  sunDim('ic_sun_dim'),

  /// Card.
  creditCard('ic_credit_card'),

  /// Restaurant.
  store('ic_store'),

  /// Account.
  user('ic_user'),

  /// Print the sold voucher (S20).
  printer('ic_printer'),

  /// Voucher: "Sell voucher" (S05, S20).
  ticket('ic_ticket');

  const WaiterIcon(this.fileName);

  /// File name without extension (10 §1.2).
  final String fileName;

  /// Asset path.
  String get assetName => 'assets/icons/$fileName.svg';
}

/// Stroke width of the icon masters in grid units.
const double iconMasterStroke = 1.75;

/// Recolours elements whose id starts with `accent` (the NFC arcs of
/// `nfcArcs` / `cardArcs`), e.g. saffron arcs on the S01 mark.
@immutable
class _AccentColorMapper extends ColorMapper {
  const _AccentColorMapper(this.accent);

  final Color accent;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (id != null && id.startsWith('accent')) return accent;
    return color;
  }

  @override
  bool operator ==(Object other) =>
      other is _AccentColorMapper && other.accent == accent;

  @override
  int get hashCode => accent.hashCode;
}

/// Renders a [WaiterIcon] at an icon size token with its size-compensated
/// stroke (04 §11.2: 16 → 1.5, 20/24 → 1.75, 32 → 2.0, 48 → 2.5 pt).
///
/// Colour defaults to `color.fg.primary`. Without a [semanticLabel] the
/// icon is decorative and hidden from assistive technology; icon-only
/// controls pass their label (10 §3.1 rule 5).
class WaiterIconView extends StatelessWidget {
  /// An icon at a size token.
  WaiterIconView(
    this.icon, {
    super.key,
    IconSize size = IconSize.s24,
    this.color,
    this.accentColor,
    this.semanticLabel,
  }) : dimension = size.size,
       strokeWidth = size.stroke;

  /// The app mark or a glyph at a non-token size, e.g. the 96-pt S01 mark
  /// with a 5-pt stroke (matching the native launch screen, 10 §2.3).
  const WaiterIconView.mark(
    this.icon, {
    required this.dimension,
    required this.strokeWidth,
    super.key,
    this.color,
    this.accentColor,
    this.semanticLabel,
  });

  /// Which icon.
  final WaiterIcon icon;

  /// Rendered size in pt.
  final double dimension;

  /// Stroke width in pt at [dimension].
  final double strokeWidth;

  /// Line colour; defaults to `color.fg.primary`.
  final Color? color;

  /// Colour of accent elements (NFC arcs); defaults to [color].
  final Color? accentColor;

  /// Accessibility label; `null` = decorative.
  final String? semanticLabel;

  /// Factor applied to the master's strokes for [dimension]/[strokeWidth].
  double get strokeScale =>
      strokeWidth * IconSize.grid / dimension / iconMasterStroke;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? context.colors.fgPrimary;
    return SvgPicture(
      StrokeScaledSvgLoader(
        icon.assetName,
        strokeScale: strokeScale,
        theme: SvgTheme(currentColor: c),
        colorMapper: accentColor == null
            ? null
            : _AccentColorMapper(accentColor!),
      ),
      width: dimension,
      height: dimension,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
