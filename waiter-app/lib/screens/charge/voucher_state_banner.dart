import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/api/models.dart';
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';

/// The StatusBanner of a voucher that cannot be redeemed (05 §3.3, 12 §5.9);
/// icons per 10 §3.2. The appearance feedback is played by the loop
/// controller, so the banner plays none.
StatusBanner voucherStateBanner({
  required AppLocalizations l10n,
  required VoucherCondition condition,
  required PresentedVoucher voucher,
  required CalendarDate? expiry,
  required MoneyContext money,
}) {
  switch (condition) {
    case VoucherCondition.blocked:
      final String? reason = voucher.blockedReason;
      return StatusBanner(
        tone: BannerTone.danger,
        icon: WaiterIcon.ban,
        title: l10n.voucherBlocked,
        body: reason == null ? l10n.getManager : '${l10n.voucherBlockedReason(reason)}\n${l10n.getManager}',
        bodyMaxLines: reason == null ? null : _reasonLines,
      );
    case VoucherCondition.expired:
      return StatusBanner(
        tone: BannerTone.warning,
        icon: WaiterIcon.calendarX,
        title: l10n.voucherExpired,
        body: expiry == null ? l10n.getManager : l10n.voucherExpiredBody(money.date(expiry)),
      );
    case VoucherCondition.empty:
      return StatusBanner(
        tone: BannerTone.warning,
        icon: WaiterIcon.wallet,
        title: l10n.voucherEmpty,
        body: l10n.voucherEmptyBody,
      );
    case VoucherCondition.redeemable:
      throw ArgumentError.value(condition, 'condition', 'a redeemable voucher has no state banner');
  }
}

/// `blocked_reason` is manager-entered free text: 2 lines, then the
/// `getManager` line ("max 3 lines").
const int _reasonLines = 3;
