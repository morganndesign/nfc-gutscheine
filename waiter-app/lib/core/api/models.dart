import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// Typed views of the API payloads the waiter app uses (09 §9.2). Parsing is
/// strict: a missing required field throws [FormatException], which the client
/// reports as a server fault instead of rendering half a card.

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

/// `GET /app/config` (prerequisite 4).
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

/// Restaurant rules the app enforces client-side before the server does.
@immutable
class RestaurantSettings {
  const RestaurantSettings({
    required this.allowPartialRedemption,
    required this.maxSingleRedemption,
    required this.brandColor,
    this.lockTagsAfterWrite = false,
  });

  factory RestaurantSettings.fromJson(Map<String, Object?> json) => RestaurantSettings(
        allowPartialRedemption: _bool(json, 'allow_partial_redemption', fallback: true),
        maxSingleRedemption: _intOrNull(json, 'max_single_redemption'),
        brandColor: _stringOrNull(json, 'brand_color'),
        lockTagsAfterWrite: _bool(json, 'lock_nfc_tags_after_write'),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'allow_partial_redemption': allowPartialRedemption,
        'max_single_redemption': maxSingleRedemption,
        'brand_color': brandColor,
        'lock_nfc_tags_after_write': lockTagsAfterWrite,
      };

  /// S20: make a verified tag read-only (restaurant setting, same as the dashboard).
  final bool lockTagsAfterWrite;

  final bool allowPartialRedemption;

  /// Cents, or null when the restaurant has no cap.
  final int? maxSingleRedemption;

  /// `#RRGGBB` or null (→ `color.brand.ink`, 04 §8.6).
  final String? brandColor;
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

  /// IANA zone, e.g. `Europe/Vienna` — business day and times (09 §4.5).
  final String timezone;

  /// e.g. `de_AT` — money and date formatting (12 §1.4).
  final String locale;
  final RestaurantSettings settings;
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

  /// `owner`, `manager` or `waiter` (null in profiles cached by older versions).
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

  bool get canRedeem => permissions.contains('cards.scan') && permissions.contains('cards.redeem');

  /// "New gift card" (S20): managers and owners whose sign-in carries both abilities. Only decides what is
  /// shown; the server checks role and token on every request.
  bool get canIssueCards =>
      (roleSlug == 'manager' || roleSlug == 'owner') &&
      permissions.contains('cards.create') &&
      permissions.contains('cards.write_nfc');
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

enum CardStatus { active, inactive, blocked, expired, redeemed, replaced }

CardStatus _status(String value) => CardStatus.values.firstWhere(
      (CardStatus s) => s.name == value,
      orElse: () => throw FormatException('Unknown card status "$value".'),
    );

/// The waiter view of a card (`POST /scan`, and `data.card` of a redeem for a
/// token without `cards.view`). No customer data exists in it (brief §0).
@immutable
class ScannedCard {
  const ScannedCard({
    required this.id,
    required this.restaurantName,
    required this.cardNumber,
    required this.status,
    required this.currency,
    required this.balance,
    required this.expiresAt,
    required this.isExpired,
    required this.blockedReason,
    required this.allowPartialRedemption,
    required this.canRedeem,
  });

  factory ScannedCard.fromJson(Map<String, Object?> json) {
    final Object? actions = json['actions'];
    return ScannedCard(
      id: _string(json, 'id'),
      restaurantName: _string(json, 'restaurant_name'),
      cardNumber: _string(json, 'card_number').replaceAll(RegExp(r'\D'), ''),
      status: _status(_string(json, 'status')),
      currency: _stringOrNull(json, 'currency') ?? 'EUR',
      balance: _int(json, 'balance'),
      expiresAt: _dateOrNull(json, 'expires_at'),
      isExpired: _bool(json, 'is_expired'),
      blockedReason: _stringOrNull(json, 'blocked_reason'),
      allowPartialRedemption: _bool(json, 'allow_partial_redemption', fallback: true),
      canRedeem: actions is Map && actions['redeem'] == true,
    );
  }

  final String id;
  final String restaurantName;

  /// 16 digits, no spaces.
  final String cardNumber;
  final CardStatus status;
  final String currency;

  /// Cents.
  final int balance;
  final DateTime? expiresAt;
  final bool isExpired;
  final String? blockedReason;
  final bool allowPartialRedemption;
  final bool canRedeem;

  String get last4 => cardNumber.substring(cardNumber.length - 4);

  ScannedCard copyWith({CardStatus? status, int? balance, bool? isExpired, bool? allowPartialRedemption}) => ScannedCard(
        id: id,
        restaurantName: restaurantName,
        cardNumber: cardNumber,
        status: status ?? this.status,
        currency: currency,
        balance: balance ?? this.balance,
        expiresAt: expiresAt,
        isExpired: isExpired ?? this.isExpired,
        blockedReason: blockedReason,
        allowPartialRedemption: allowPartialRedemption ?? this.allowPartialRedemption,
        canRedeem: canRedeem,
      );
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

/// `POST /cards/{id}/redeem` → 201, or 200 with `replayed: true`.
@immutable
class RedeemResult {
  const RedeemResult({required this.card, required this.transaction, required this.replayed, this.requestId = ''});

  factory RedeemResult.fromJson(Map<String, Object?> json, {String requestId = ''}) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    return RedeemResult(
      card: ScannedCard.fromJson(_map(data['card'], 'card')),
      transaction: RedeemedTransaction.fromJson(_map(data['transaction'], 'transaction')),
      replayed: json['replayed'] == true,
      requestId: requestId,
    );
  }

  final ScannedCard card;
  final RedeemedTransaction transaction;
  final bool replayed;

  /// `X-Request-Id` of the answered attempt (Recent detail support code).
  final String requestId;
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

/// `POST /cards` (S20): the sold card and the link its tag must carry.
@immutable
class IssuedCard {
  const IssuedCard({
    required this.id,
    required this.cardNumber,
    required this.balance,
    required this.currency,
    required this.url,
    required this.replayed,
  });

  factory IssuedCard.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    final Map<String, Object?> nfc = _map(json['nfc'], 'nfc');
    return IssuedCard(
      id: _string(data, 'id'),
      cardNumber: _stringOrNull(data, 'card_number_formatted') ?? _string(data, 'card_number'),
      balance: _int(data, 'balance'),
      currency: _stringOrNull(data, 'currency') ?? 'EUR',
      url: _string(nfc, 'url'),
      replayed: json['replayed'] == true,
    );
  }

  final String id;

  /// Grouped for reading aloud, e.g. `1268 8343 1352 0042`.
  final String cardNumber;

  /// Cents.
  final int balance;
  final String currency;

  /// The card URL, written verbatim to the tag and compared verbatim on read-back.
  final String url;
  final bool replayed;
}

/// `POST /cards/{id}/nfc/check` (S20, same contract as the dashboard).
@immutable
class NfcCheckResult {
  const NfcCheckResult({
    required this.status,
    required this.expectedUrl,
    this.reason,
    this.conflictCardNumber,
    this.locked = false,
  });

  factory NfcCheckResult.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    final Object? conflict = data['conflict'];
    return NfcCheckResult(
      status: _string(data, 'status'),
      expectedUrl: _string(data, 'expected_url'),
      reason: _stringOrNull(data, 'reason'),
      conflictCardNumber: conflict is Map ? _stringOrNull(conflict.cast<String, Object?>(), 'card_number') : null,
      locked: data['locked'] == true,
    );
  }

  /// `available`, `already_programmed` or `refused`.
  final String status;
  final String expectedUrl;
  final String? reason;
  final String? conflictCardNumber;
  final bool locked;
}
