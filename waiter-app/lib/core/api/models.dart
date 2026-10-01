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
  const AppConfigData({required this.updateRequired, required this.maintenanceNotice, required this.supportEmail});

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

  /// Top up a guest's card at the till (managers and owners).
  static const String reload = 'vouchers.reload';

  /// Platform staff: the personalisation station (station token).
  static const String personalize = 'platform.cards.personalize';

  /// Physical cards: see the restaurant's cards, confirm a delivery, link a card to a sale, suspend/replace.
  static const String cardsView = 'cards.view';
  static const String cardsReceive = 'cards.receive';
  static const String cardsBind = 'cards.bind';
  static const String cardsManage = 'cards.manage';
  static const String cardsReplaceLost = 'cards.replace_lost';
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

  /// Platform staff signed in as the personalisation station: no restaurant, cards only.
  bool get isStation => restaurant == null && permissions.contains(Permissions.personalize);

  /// Whether this account may use the app at all: a restaurant's till, or the station.
  bool get canUseApp => (canRedeem && restaurant != null) || isStation;

  /// "Sell voucher" (S20).
  bool get canSell => permissions.contains(Permissions.sell);

  /// The complimentary payment method (owners).
  bool get canSellComplimentary => permissions.contains(Permissions.sellComplimentary);

  /// Selling a physical card (a card voucher) needs selling and binding a card.
  bool get canSellCards => canSell && permissions.contains(Permissions.cardsBind);

  bool get canReceiveCards => permissions.contains(Permissions.cardsReceive);

  /// "Top up card": tap the guest's card, enter the amount, book the payment.
  bool get canReload => permissions.contains(Permissions.reload);

  /// Look up a card, suspend, resume and replace it.
  bool get canManageCards => permissions.contains(Permissions.cardsManage) && permissions.contains(Permissions.cardsView);

  /// Replace a card that is not at hand (lost, stolen): owners.
  bool get canReplaceLostCards => permissions.contains(Permissions.cardsReplaceLost);
}

/// Result of `POST /auth/token`.
@immutable
class SignInResult {
  const SignInResult({required this.token, required this.user});

  factory SignInResult.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    return SignInResult(token: _string(data, 'token'), user: SessionUser.fromJson(_map(data['user'], 'user')));
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

/// Step 1 of a card's live authentication (`POST /presentments/cards`): the
/// command the phone relays to the card, valid [expiresIn].
@immutable
class CardChallenge {
  const CardChallenge({required this.authentication, required this.commandHex, required this.expiresIn});

  factory CardChallenge.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    final String command = _string(data, 'command');
    if (!RegExp(r'^[0-9A-F]{76}$').hasMatch(command)) throw const FormatException('command');
    return CardChallenge(
      authentication: _string(data, 'authentication'),
      commandHex: command,
      expiresIn: Duration(seconds: _int(data, 'expires_in')),
    );
  }

  final String authentication;
  final String commandHex;
  final Duration expiresIn;
}

/// A card batch the station may personalise (`GET /admin/station/batches`).
@immutable
class StationBatch {
  const StationBatch({
    required this.id,
    required this.batchCode,
    required this.restaurant,
    required this.quantityOrdered,
    required this.qaPassed,
  });

  factory StationBatch.fromJson(Map<String, Object?> json) => StationBatch(
    id: _string(json, 'id'),
    batchCode: _string(json, 'batch_code'),
    restaurant: _string(json, 'restaurant'),
    quantityOrdered: _int(json, 'quantity_ordered'),
    qaPassed: _int(json, 'qa_passed'),
  );

  static List<StationBatch> listFromJson(Map<String, Object?> json) {
    final Object? data = json['data'];
    if (data is! List) throw const FormatException('data');
    return <StationBatch>[for (final Object? row in data) StationBatch.fromJson(_map(row, 'batch'))];
  }

  final String id;
  final String batchCode;
  final String restaurant;
  final int quantityOrdered;
  final int qaPassed;
}

/// One round of a station personalisation: the APDUs to relay next, or done (no id, no commands).
@immutable
class PersonalizationRound {
  const PersonalizationRound({
    required this.id,
    required this.stage,
    required this.commandsHex,
    required this.cardNumber,
    required this.cardState,
  });

  factory PersonalizationRound.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    final Object? commands = data['commands'];
    final Object? id = data['personalization'];
    final Map<String, Object?> card = _map(data['card'], 'card');
    if (commands is! List || (id != null && id is! String)) throw const FormatException('personalization');
    final List<String> hex = commands.whereType<String>().toList();
    if (hex.length != commands.length || hex.any((String c) => !RegExp(r'^(?:[0-9A-F]{2}){4,261}$').hasMatch(c))) {
      throw const FormatException('commands');
    }
    return PersonalizationRound(
      id: id as String?,
      stage: _string(data, 'stage'),
      commandsHex: hex,
      cardNumber: _string(card, 'card_number'),
      cardState: _string(card, 'state'),
    );
  }

  final String? id;
  final String stage;
  final List<String> commandsHex;
  final String cardNumber;
  final String cardState;

  bool get done => id == null;
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

/// `POST /vouchers/{id}/reloads` → 201, or 200 with `replayed: true` (a retry answered with the booking).
@immutable
class ReloadResult {
  const ReloadResult({required this.amount, required this.balance, required this.currency, required this.replayed});

  factory ReloadResult.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    final Map<String, Object?> voucher = _map(data['voucher'], 'voucher');
    return ReloadResult(
      amount: _int(_map(data['transaction'], 'transaction'), 'amount'),
      balance: _int(voucher, 'balance'),
      currency: _stringOrNull(voucher, 'currency') ?? 'EUR',
      replayed: json['replayed'] == true,
    );
  }

  /// The credited amount (positive).
  final int amount;

  /// The voucher's balance after the top-up.
  final int balance;
  final String currency;
  final bool replayed;
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
    this.cardNumber,
  });

  factory SoldVoucher.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    // A retry answered after the sale window (or from another phone) repeats
    // the sale without a new QR: `printable` is null then.
    final Object? printable = json['printable'];
    final bool replayed = json['replayed'] == true;
    final Object? card = json['card'];
    final String? cardNumber = card is Map ? _stringOrNull(card.cast<String, Object?>(), 'card_number') : null;
    if (printable == null && !replayed && cardNumber == null) throw const FormatException('printable missing');
    return SoldVoucher(
      id: _string(data, 'id'),
      value: _int(data, 'balance'),
      currency: _stringOrNull(data, 'currency') ?? 'EUR',
      expiresAt: _dateOrNull(data, 'expires_at'),
      printablePayload: printable == null ? null : _string(_map(printable, 'printable'), 'payload'),
      replayed: replayed,
      cardNumber: cardNumber,
    );
  }

  final String id;

  /// Cents.
  final int value;
  final String currency;
  final DateTime? expiresAt;

  /// The QR text (`GCPV1.` + 43 characters). Returned once; it lives in
  /// memory only until the sale screen closes. Null only for a [replayed]
  /// sale whose QR can no longer be issued.
  final String? printablePayload;
  final bool replayed;

  /// A card sale: the inventory number of the card now active for this voucher.
  final String? cardNumber;
}

/// A card presented for binding or receiving (a live-authenticated tap without a voucher yet).
@immutable
class CardPresented {
  const CardPresented({required this.id, required this.cardNumber, required this.cardState, required this.expiresIn});

  factory CardPresented.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    final Map<String, Object?> card = _map(data['card'], 'card');
    return CardPresented(
      id: _string(data, 'id'),
      cardNumber: _string(card, 'card_number'),
      cardState: _string(card, 'state'),
      expiresIn: Duration(seconds: _int(data, 'expires_in')),
    );
  }

  final String id;
  final String cardNumber;
  final String cardState;
  final Duration expiresIn;
}

/// A delivery of cards for this restaurant (`GET /card-batches`).
@immutable
class CardBatchSummary {
  const CardBatchSummary({required this.id, required this.batchCode, required this.status, required this.inTransit, this.deliveredAt});

  factory CardBatchSummary.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> counts = _map(json['counts'], 'counts');
    return CardBatchSummary(
      id: _string(json, 'id'),
      batchCode: _string(json, 'batch_code'),
      status: _string(json, 'status'),
      inTransit: _int(counts, 'in_transit'),
      deliveredAt: _dateOrNull(json, 'delivered_at'),
    );
  }

  static List<CardBatchSummary> listFromJson(Map<String, Object?> json) {
    final Object? data = json['data'];
    if (data is! List) throw const FormatException('data');
    return <CardBatchSummary>[for (final Object? row in data) CardBatchSummary.fromJson(_map(row, 'batch'))];
  }

  final String id;
  final String batchCode;

  /// `delivered` waits for the receipt; `on_hold` after a count that did not match.
  final String status;

  /// Cards shipped and not yet received.
  final int inTransit;
  final DateTime? deliveredAt;
}

/// A card as staff see it (`GET /cards/{number}`): no id, no UID.
@immutable
class CardInfo {
  const CardInfo({required this.cardNumber, required this.state, this.voucherBalance, this.currency, this.successor});

  factory CardInfo.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> data = _map(json['data'], 'data');
    final Object? voucher = data['voucher'];
    final Map<String, Object?>? v = voucher is Map ? voucher.cast<String, Object?>() : null;
    return CardInfo(
      cardNumber: _string(data, 'card_number'),
      state: _string(data, 'state'),
      voucherBalance: v == null ? null : _int(v, 'balance'),
      currency: v == null ? null : _stringOrNull(v, 'currency'),
      successor: _stringOrNull(data, 'successor'),
    );
  }

  final String cardNumber;

  /// `available`, `active`, `suspended`, `replaced`, …
  final String state;

  /// Cents; null when the card pays for no voucher.
  final int? voucherBalance;
  final String? currency;

  /// The card that replaced this one.
  final String? successor;
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
