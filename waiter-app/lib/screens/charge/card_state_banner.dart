import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/api/models.dart';
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';

/// The StatusBanner of a card that cannot be redeemed (03b §2.14–2.15,
/// 05 §3.3, 12 §5.9); icons per 10 §3.2. The appearance feedback (11 E22–
/// E24) is played by the loop controller, so the banner plays none.
StatusBanner cardStateBanner({
  required AppLocalizations l10n,
  required CardCondition condition,
  required ScannedCard card,
  required CalendarDate? expiry,
  required MoneyContext money,
}) {
  switch (condition) {
    case CardCondition.blocked:
      final String? reason = card.blockedReason;
      return StatusBanner(
        tone: BannerTone.danger,
        icon: WaiterIcon.ban,
        title: l10n.cardBlocked,
        body: reason == null
            ? l10n.getManager
            : '${l10n.cardBlockedReason(reason)}\n${l10n.getManager}',
        bodyMaxLines: reason == null ? null : _reasonLines,
      );
    case CardCondition.expired:
      return StatusBanner(
        tone: BannerTone.warning,
        icon: WaiterIcon.calendarX,
        title: l10n.cardExpired,
        body: expiry == null
            ? l10n.getManager
            : l10n.cardExpiredBody(money.date(expiry)),
      );
    case CardCondition.replaced:
      return StatusBanner(
        tone: BannerTone.warning,
        icon: WaiterIcon.replace,
        title: l10n.cardReplaced,
        body: l10n.cardReplacedBody,
      );
    case CardCondition.inactive:
      return StatusBanner(
        tone: BannerTone.warning,
        icon: WaiterIcon.circleDashed,
        title: l10n.cardInactive,
        body: l10n.cardInactiveBody,
      );
    case CardCondition.empty:
      return StatusBanner(
        tone: BannerTone.warning,
        icon: WaiterIcon.wallet,
        title: l10n.cardEmpty,
        body: l10n.cardEmptyBody,
      );
    case CardCondition.redeemable:
      throw ArgumentError.value(
        condition,
        'condition',
        'a redeemable card has no card-state banner',
      );
  }
}

/// `blocked_reason` is manager-entered free text: 2 lines, then the
/// `getManager` line (03b §2.14, 05 §3.3 "max 3 lines").
const int _reasonLines = 3;
