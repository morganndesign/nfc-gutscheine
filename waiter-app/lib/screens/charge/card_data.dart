import 'package:flutter/widgets.dart';
import 'package:giftcard_waiter/app/app_scope.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/api/models.dart';
import 'package:giftcard_waiter/core/format/format.dart';

/// The BalanceCard content of a scanned card (05 §3.1): the restaurant's
/// `brand_color` from the session and the expiry as a date in the
/// restaurant time zone (03b §2.14 "Expired on {date}").
BalanceCardData balanceCardDataOf(BuildContext context, ScannedCard card) {
  return BalanceCardData(
    restaurantName: card.restaurantName,
    balanceCents: card.balance,
    last4: card.last4,
    status: card.status,
    expiresAt: restaurantDateOf(context, card.expiresAt),
    brandColor: brandColorOf(context),
  );
}

/// The restaurant's `brand_color`, `null` = `color.brand.ink`.
String? brandColorOf(BuildContext context) =>
    context.services.session.user?.restaurant?.settings.brandColor;

/// [instant] as a calendar date in the restaurant time zone (09 §4.5).
CalendarDate? restaurantDateOf(BuildContext context, DateTime? instant) {
  if (instant == null) return null;
  final AppServices services = context.services;
  final String zone =
      services.session.user?.restaurant?.timezone ?? 'Europe/Vienna';
  return CalendarDate.ofInstant(
    instant,
    services.session.calendar.offsetAt(zone, instant),
  );
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
