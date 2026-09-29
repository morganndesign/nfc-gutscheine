import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'support/text_emphasis.dart';

/// What a badge shows: the stored state, or "used up" for an active voucher
/// with no balance left (not a stored state).
enum BadgeStatus { active, usedUp, blocked, expired }

/// Visual and text of one badge status (05 §3.2 table).
@immutable
class StatusBadgeStyle {
  const StatusBadgeStyle._(this.icon, this.foreground, this.fill);

  /// The status icon.
  final WaiterIcon icon;

  /// Text and icon colour.
  final Color foreground;

  /// Badge fill.
  final Color fill;

  /// Style of [status] in the active theme.
  static StatusBadgeStyle of(BadgeStatus status, WaiterColors c) => switch (status) {
    BadgeStatus.active => StatusBadgeStyle._(WaiterIcon.circleCheck, c.success, c.successBg),
    BadgeStatus.usedUp => StatusBadgeStyle._(WaiterIcon.wallet, c.warning, c.warningBg),
    BadgeStatus.blocked => StatusBadgeStyle._(WaiterIcon.ban, c.danger, c.dangerBg),
    BadgeStatus.expired => StatusBadgeStyle._(WaiterIcon.calendarX, c.warning, c.warningBg),
  };
}

/// The localised label of a badge status (`badge.*`, 12 §5.9).
String statusBadgeLabel(AppLocalizations l10n, BadgeStatus status) => switch (status) {
  BadgeStatus.active => l10n.badgeActive,
  BadgeStatus.usedUp => l10n.badgeUsedUp,
  BadgeStatus.blocked => l10n.badgeBlocked,
  BadgeStatus.expired => l10n.badgeExpired,
};

/// Compact voucher status, always icon + text (05 §3.2): 24 pt high,
/// `radius.xs`, padding 8, `icon.16` + gap 4 + `type.caption`, theme tone
/// colours even on the brand-coloured card.
///
/// High contrast: text weight 600, icon stroke 1.75 and a 1-pt border in
/// the text colour (07 §3.4). On a card with dark text, [cardOutline]
/// (card text at 16 %) adds edge definition. Static text; on the
/// BalanceCard it is excluded from semantics (the card label says it).
class StatusBadge extends StatelessWidget {
  /// Creates a badge.
  const StatusBadge({required this.status, super.key, this.cardOutline});

  /// Status shown.
  final BadgeStatus status;

  /// 1-px outline on dark-text brand cards (`BrandCardColors.badgeOutline`).
  final Color? cardOutline;

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final StatusBadgeStyle style = StatusBadgeStyle.of(status, theme.colors);
    final bool hc = theme.isHighContrast;
    final Color? border = hc ? style.foreground : cardOutline;
    return Container(
      constraints: const BoxConstraints(minHeight: StatusBadgeTokens.height),
      padding: const EdgeInsets.symmetric(
        horizontal: StatusBadgeTokens.paddingHorizontal,
      ),
      decoration: BoxDecoration(
        color: style.fill,
        borderRadius: BorderRadius.circular(StatusBadgeTokens.radius),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hc)
            WaiterIconView.mark(
              style.icon,
              dimension: IconSize.s16.size,
              strokeWidth: IconSize.s24.stroke,
              color: style.foreground,
            )
          else
            WaiterIconView(
              style.icon,
              size: IconSize.s16,
              color: style.foreground,
            ),
          const SizedBox(width: StatusBadgeTokens.iconGap),
          ScaledText.rich(
            (ScaledStyles s) {
              final TextStyle base = s(
                TypeTokens.caption,
                color: style.foreground,
              );
              return TextSpan(
                text: statusBadgeLabel(AppLocalizations.of(context), status),
                style: hc ? base.semiBold(boldText: theme.boldText) : base,
              );
            },
            type: TypeTokens.caption,
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}
