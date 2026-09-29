import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// Typed views of the API payloads the waiter app uses. Parsing is strict: a
/// missing required field throws [FormatException], which the client reports
/// as a server fault instead of rendering half a voucher.

Map<String, Object?> _map(Object? value, String field) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  throw FormatException('Expected an object for "$field".');
}

String _string(Map<String, Object?> json, String field) {
  final Object? value = json[field];
  if (value is String) return value;
  throw FormatException('Expected a string for "$field".');
}

String? _stringOrNull(Map<String, Object?> json, String field) {
  final Object? value = json[field];
  return value is String && value.isNotEmpty ? value : null;
}

int _int(Map<String, Object?> json, String field) {
  final Object? value = json[field];
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw FormatException('Expected an integer for "$field".');
}

int? _intOrNull(Map<String, Object?> json, String field) {
  final Object? value = json[field];
  if (value == null) return null;
  return _int(json, field);
}

bool _bool(Map<String, Object?> json, String field, {bool fallback = false}) {
  final Object? value = json[field];
  return value is bool ? value : fallback;
}

DateTime? _dateOrNull(Map<String, Object?> json, String field) {
  final String? value = _stringOrNull(json, field);
  return value == null ? null : DateTime.parse(value).toUtc();
}

/// `GET /app/config`.
@immutable
class AppConfigData {
  const AppConfigData({
    required this.updateRequired,
    required this.maintenanceNotice,
    required this.supportEmail,
  });

  factory AppConfigData.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    return AppConfigData(
      updateRequired: data['update_required'] == true,
      maintenanceNotice: _stringOrNull(data, 'maintenance_notice'),
      supportEmail: _stringOrNull(data, 'support_email'),
    );
  }

  final bool updateRequired;
  final String? maintenanceNotice;
  final String? supportEmail;
}

/// The restaurant rules the app checks before the server does (the server
/// always decides).
@immutable
class RestaurantSettings {
  const RestaurantSettings({
    required this.allowPartialRedemption,
    required this.maxDebitPerTransaction,
    required this.brandColor,
    this.minVoucherValue,
    this.maxVoucherBalance,
    this.sendCustomerEmails = false,
  });

  factory RestaurantSettings.fromJson(Map<String, Object?> json) => RestaurantSettings(
    allowPartialRedemption: _bool(json, 'allow_partial_redemption', fallback: true),
    maxDebitPerTransaction: _intOrNull(json, 'max_debit_per_transaction'),
    brandColor: _stringOrNull(json, 'brand_color'),
    minVoucherValue: _intOrNull(json, 'min_voucher_value'),
    maxVoucherBalance: _intOrNull(json, 'max_voucher_balance'),
    sendCustomerEmails: _bool(json, 'send_customer_emails'),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'allow_partial_redemption': allowPartialRedemption,
    'max_debit_per_transaction': maxDebitPerTransaction,
    'brand_color': brandColor,
    'min_voucher_value': minVoucherValue,
    'max_voucher_balance': maxVoucherBalance,
    'send_customer_emails': sendCustomerEmails,
  };

  final bool allowPartialRedemption;

  /// Cents per redemption, or null when unknown.
  final int? maxDebitPerTransaction;

  /// `#RRGGBB` or null (→ `color.brand.ink`).
  final String? brandColor;

  /// Smallest value of a sold voucher, in cents.
  final int? minVoucherValue;

  /// Largest balance a voucher may hold, in cents.
  final int? maxVoucherBalance;

  /// Whether the guest gets a confirmation e-mail after a sale.
  final bool sendCustomerEmails;
}

@immutable
class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.currency,
    required this.timezone,
    required this.locale,
    required this.settings,
  });

  factory Restaurant.fromJson(Map<String, Object?> json) => Restaurant(
    id: _string(json, 'id'),
    name: _string(json, 'name'),
    currency: _stringOrNull(json, 'currency') ?? 'EUR',
    timezone: _stringOrNull(json, 'timezone') ?? 'Europe/Vienna',
    locale: _stringOrNull(json, 'locale') ?? 'de_AT',
    settings: RestaurantSettings.fromJson(_map(json['settings'], 'settings')),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'currency': currency,
    'timezone': timezone,
    'locale': locale,
    'settings': settings.toJson(),
  };

  final String id;
  final String name;
  final String currency;

  /// IANA zone, e.g. `Europe/Vienna` — business day and times.
  final String timezone;

  /// e.g. `de_AT` — money and date formatting, and the language of the
  /// printed voucher.
  final String locale;
  final RestaurantSettings settings;
}

/// Permissions the app acts on. The server checks every request; these only
/// decide what is shown.
abstract final class Permissions {
  static const String redeem = 'vouchers.redeem';
  static const String sell = 'vouchers.sell';
  static const String sellComplimentary = 'vouchers.sell_complimentary';
}

/// `/auth/me` and the `user` part of `POST /auth/token`.
@immutable
class SessionUser {
  const SessionUser({
    required this.id,
    required this.name,
    required this.email,
    required this.permissions,
    required this.restaurant,
    this.roleSlug,
  });

  factory SessionUser.fromJson(Map<String, Object?> json) {
    final Object? restaurant = json['restaurant'];
    final Object? permissions = json['permissions'];
    final Object? role = json['role'];
    return SessionUser(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      email: _string(json, 'email'),
      permissions: permissions is List ? permissions.whereType<String>().toList() : const <String>[],
      restaurant: restaurant == null ? null : Restaurant.fromJson(_map(restaurant, 'restaurant')),
      roleSlug: role is Map ? _stringOrNull(role.cast<String, Object?>(), 'slug') : null,
    );
  }

  final String id;
  final String name;
  final String email;
  final List<String> permissions;
  final Restaurant? restaurant;

  /// `owner`, `manager` or `waiter`.
  final String? roleSlug;

  /// Cached so S05 can render before `/auth/me` answers (offline start).
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'email': email,
    'permissions': permissions,
    'restaurant': restaurant?.toJson(),
    if (roleSlug != null) 'role': <String, Object?>{'slug': roleSlug},
  };

  /// Waiter initials for the `Avatar` (max. two letters).
  String get initials {
    final List<String> parts = name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final String first = parts.first.characters.first;
    final String last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  bool get canRedeem => permissions.contains(Permissions.redeem);

  /// "Sell voucher" (S20).
  bool get canSell => permissions.contains(Permissions.sell);

  /// The complimentary payment method (owners).
  bool get canSellComplimentary => permissions.contains(Permissions.sellComplimentary);
}

/// Result of `POST /auth/token`.
@immutable
class SignInResult {
  const SignInResult({required this.token, required this.user});

  factory SignInResult.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    return SignInResult(
      token: _string(data, 'token'),
      user: SessionUser.fromJson(_map(data['user'], 'user')),
    );
  }

  final String token;
  final SessionUser user;
}

/// Stored voucher states. "Empty" is not a state: an active voucher with
/// balance 0 is shown as used up.
enum VoucherStatus { active, blocked, expired }

VoucherStatus _status(String value) => VoucherStatus.values.firstWhere(
  (VoucherStatus s) => s.name == value,
  orElse: () => throw FormatException('Unknown voucher status "$value".'),
);

/// How a voucher reaches the guest: a card (NFC) or a digital voucher (QR).
enum VoucherKind { card, digital }

VoucherKind _kind(String value) => VoucherKind.values.firstWhere(
  (VoucherKind k) => k.name == value,
  orElse: () => throw FormatException('Unknown voucher kind "$value".'),
);

/// What the till sees of a presented voucher (`PresentedVoucherResource`).
/// No customer data.
@immutable
class PresentedVoucher {
  const PresentedVoucher({
    required this.id,
    required this.kind,
    required this.restaurantName,
    required this.voucherNumber,
    required this.status,
    required this.currency,
    required this.balance,
    required this.expiresAt,
    required this.isExpired,
    required this.blockedReason,
    required this.allowPartialRedemption,
    required this.maxDebitPerTransaction,
    required this.canRedeem,
  });

  factory PresentedVoucher.fromJson(Map<String, Object?> json) {
    final Object? actions = json['actions'];
    return PresentedVoucher(
      id: _string(json, 'id'),
      kind: _kind(_string(json, 'kind')),
      restaurantName: _string(json, 'restaurant_name'),
      voucherNumber: _string(json, 'voucher_number').replaceAll(RegExp(r'\D'), ''),
      status: _status(_string(json, 'status')),
      currency: _stringOrNull(json, 'currency') ?? 'EUR',
      balance: _int(json, 'balance'),
      expiresAt: _dateOrNull(json, 'expires_at'),
      isExpired: _bool(json, 'is_expired'),
      blockedReason: _stringOrNull(json, 'blocked_reason'),
      allowPartialRedemption: _bool(json, 'allow_partial_redemption', fallback: true),
      maxDebitPerTransaction: _intOrNull(json, 'max_debit_per_transaction'),
      canRedeem: actions is Map && actions['redeem'] == true,
    );
  }

  final String id;
  final VoucherKind kind;
  final String restaurantName;

  /// Internal voucher number (digits only), shown to staff — never a
  /// credential.
  final String voucherNumber;
  final VoucherStatus status;
  final String currency;

  /// Cents.
  final int balance;
  final DateTime? expiresAt;
  final bool isExpired;
  final String? blockedReason;
  final bool allowPartialRedemption;

  /// Cents per redemption, or null when the restaurant sets none.
  final int? maxDebitPerTransaction;
  final bool canRedeem;

  String get last4 => voucherNumber.length <= 4 ? voucherNumber : voucherNumber.substring(voucherNumber.length - 4);

  PresentedVoucher copyWith({VoucherStatus? status, int? balance, bool? isExpired, bool? allowPartialRedemption}) =>
      PresentedVoucher(
        id: id,
        kind: kind,
        restaurantName: restaurantName,
        voucherNumber: voucherNumber,
        status: status ?? this.status,
        currency: currency,
        balance: balance ?? this.balance,
        expiresAt: expiresAt,
        isExpired: isExpired ?? this.isExpired,
        blockedReason: blockedReason,
        allowPartialRedemption: allowPartialRedemption ?? this.allowPartialRedemption,
        maxDebitPerTransaction: maxDebitPerTransaction,
        canRedeem: canRedeem,
      );
}

/// `POST /presentments` → 201: single use, valid for [expiresIn] from receipt,
/// bound to this user, this phone and [voucher].
@immutable
class Presentment {
  const Presentment({required this.id, required this.expiresIn, required this.voucher});

  factory Presentment.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    return Presentment(
      id: _string(data, 'id'),
      expiresIn: Duration(seconds: _int(data, 'expires_in')),
      voucher: PresentedVoucher.fromJson(_map(data['voucher'], 'voucher')),
    );
  }

  final String id;

  /// Validity left when the server answered (counted down from receipt, so the
  /// phone's clock does not matter).
  final Duration expiresIn;
  final PresentedVoucher voucher;
}

/// A booked redemption (`data.transaction`).
@immutable
class RedeemedTransaction {
  const RedeemedTransaction({
    required this.id,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory RedeemedTransaction.fromJson(Map<String, Object?> json) => RedeemedTransaction(
    id: _string(json, 'id'),
    // Redemptions are stored as negative ledger amounts.
    amount: _int(json, 'amount').abs(),
    balanceAfter: _int(json, 'balance_after'),
    createdAt: DateTime.parse(_string(json, 'created_at')).toUtc(),
  );

  final String id;

  /// Redeemed cents (positive).
  final int amount;
  final int balanceAfter;
  final DateTime createdAt;
}

/// `POST /vouchers/{id}/redemptions` → 201, or 200 with `replayed: true`.
@immutable
class RedeemResult {
  const RedeemResult({required this.transaction, required this.replayed, this.requestId = ''});

  factory RedeemResult.fromJson(Map<String, Object?> json, {String requestId = ''}) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    return RedeemResult(
      transaction: RedeemedTransaction.fromJson(_map(data['transaction'], 'transaction')),
      replayed: json['replayed'] == true,
      requestId: requestId,
    );
  }

  final RedeemedTransaction transaction;
  final bool replayed;

  /// `X-Request-Id` of the answered attempt (Recent detail support code).
  final String requestId;
}

/// `GET /vouchers/{id}/redemptions/{key}`: the outcome of one of this user's
/// own attempts, asked for without sending the debit again.
@immutable
sealed class RedemptionOutcome {
  const RedemptionOutcome();

  factory RedemptionOutcome.fromJson(Map<String, Object?> json, {String requestId = ''}) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    return switch (_string(data, 'status')) {
      'booked' => RedemptionBooked(
        voucher: PresentedVoucher.fromJson(_map(data['voucher'], 'voucher')),
        transaction: RedeemedTransaction.fromJson(_map(data['transaction'], 'transaction')),
        requestId: requestId,
      ),
      'not_booked' => const RedemptionNotBooked(),
      final String other => throw FormatException('Unknown outcome "$other".'),
    };
  }
}

final class RedemptionBooked extends RedemptionOutcome {
  const RedemptionBooked({required this.voucher, required this.transaction, this.requestId = ''});

  final PresentedVoucher voucher;
  final RedeemedTransaction transaction;
  final String requestId;
}

/// Not booked (yet): final only once the attempt can no longer be running on
/// the server.
final class RedemptionNotBooked extends RedemptionOutcome {
  const RedemptionNotBooked();
}

/// How the guest paid for a sold voucher.
enum PaymentMethod {
  cash('cash'),
  cardTerminal('card_terminal'),
  bankTransfer('bank_transfer'),
  complimentary('complimentary');

  const PaymentMethod(this.wire);

  final String wire;

  /// Terminal receipt or bank reference required.
  bool get needsReference => this == cardTerminal || this == bankTransfer;

  /// A reason is required (and the owner's permission).
  bool get needsReason => this == complimentary;
}

/// The `payment` object of a sale.
@immutable
class PaymentInput {
  const PaymentInput({required this.method, this.reference, this.reason});

  final PaymentMethod method;
  final String? reference;
  final String? reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'method': method.wire,
    if (method.needsReference) 'reference': reference,
    if (method.needsReason) 'reason': reason,
  };
}

/// `POST /vouchers` → 201, or 200 with `replayed: true` (a retry within the
/// server's window re-issues a fresh QR and revokes the unseen one).
@immutable
class SoldVoucher {
  const SoldVoucher({
    required this.id,
    required this.value,
    required this.currency,
    required this.printablePayload,
    required this.replayed,
    this.expiresAt,
  });

  factory SoldVoucher.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    final Map<String, Object?> printable = _map(json['printable'], 'printable');
    return SoldVoucher(
      id: _string(data, 'id'),
      value: _int(data, 'balance'),
      currency: _stringOrNull(data, 'currency') ?? 'EUR',
      expiresAt: _dateOrNull(data, 'expires_at'),
      printablePayload: _string(printable, 'payload'),
      replayed: json['replayed'] == true,
    );
  }

  final String id;

  /// Cents.
  final int value;
  final String currency;
  final DateTime? expiresAt;

  /// The QR text (`GCPV1.` + 43 characters). Returned once; it lives in
  /// memory only until the sale screen closes.
  final String printablePayload;
  final bool replayed;
}

/// `GET /devices/current` (S14 device name).
@immutable
class CurrentDevice {
  const CurrentDevice({required this.name});

  factory CurrentDevice.fromJson(Map<String, Object?> json) {
    final Object? data = json['data'];
    return CurrentDevice(name: data is Map ? (data['name'] as String? ?? '') : '');
  }

  final String name;
}
