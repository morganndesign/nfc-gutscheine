import 'package:flutter/widgets.dart';
import 'package:giftcard_waiter/app/app_scope.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/api/models.dart';
import 'package:giftcard_waiter/core/branding/restaurant_logo.dart';
import 'package:giftcard_waiter/core/format/format.dart';

/// The BalanceCard content of a presented voucher (05 §3.1): the restaurant's
/// `brand_color` from the session and the expiry as a date in the
/// restaurant time zone ("Expired on {date}").
BalanceCardData balanceCardDataOf(BuildContext context, PresentedVoucher voucher) {
  return BalanceCardData(
    restaurantName: voucher.restaurantName,
    balanceCents: voucher.balance,
    last4: voucher.last4,
    status: voucher.isExpired && voucher.status == VoucherStatus.active ? VoucherStatus.expired : voucher.status,
    expiresAt: restaurantDateOf(context, voucher.expiresAt),
    brandColor: brandColorOf(context),
    logo: restaurantLogos.peek(context.services.session.user?.restaurant?.settings.logoUrl),
  );
}

/// The restaurant's `brand_color`, `null` = `color.brand.ink`.
String? brandColorOf(BuildContext context) => context.services.session.user?.restaurant?.settings.brandColor;

/// [instant] as a calendar date in the restaurant time zone (09 §4.5).
CalendarDate? restaurantDateOf(BuildContext context, DateTime? instant) {
  if (instant == null) return null;
  final AppServices services = context.services;
  final String zone = services.session.user?.restaurant?.timezone ?? 'Europe/Vienna';
  return CalendarDate.ofInstant(instant, services.session.calendar.offsetAt(zone, instant));
}

/// Logs `brand_color_contrast_fallback` once per restaurant and app run
/// (05 §3.1 `onContrastFallback`, 13 · RK-06).
void logContrastFallback(BuildContext context) {
  final AppServices services = context.services;
  final String restaurant = services.session.user?.restaurant?.id ?? '';
  if (_contrastFallbackLogged.add(restaurant)) {
    services.log.record('brand_color_contrast_fallback', restaurant);
  }
}

final Set<String> _contrastFallbackLogged = <String>{};
