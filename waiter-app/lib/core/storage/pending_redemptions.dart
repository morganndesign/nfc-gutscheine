import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'secure_store.dart';

/// A redemption whose outcome this phone does not know yet: sent (or about to
/// be sent) with [key], never answered definitively.
///
/// Written before the first request leaves the phone and removed only on a
/// definitive answer, so a lost response, a cancelled "checking" state or a
/// killed app can never lead to a second booking under a new key. While one is
/// open for a voucher, that voucher accepts no other amount until the server
/// has said whether it was booked.
@immutable
class PendingRedemption {
  const PendingRedemption({
    required this.key,
    required this.voucherId,
    required this.amount,
    required this.currency,
    required this.last4,
    required this.restaurantName,
    required this.lastSentAt,
  });

  factory PendingRedemption.fromJson(Map<String, Object?> json) => PendingRedemption(
    key: json['key']! as String,
    voucherId: json['voucher']! as String,
    amount: (json['amount']! as num).toInt(),
    currency: json['currency'] as String? ?? 'EUR',
    last4: json['last4'] as String? ?? '',
    restaurantName: json['restaurant'] as String? ?? '',
    lastSentAt: DateTime.parse(json['sent']! as String).toUtc(),
  );

  /// The `Idempotency-Key` of every request of this attempt.
  final String key;
  final String voucherId;

  /// Cents.
  final int amount;
  final String currency;
  final String last4;
  final String restaurantName;

  /// When the last request of this attempt left the phone (wall clock, UTC).
  final DateTime lastSentAt;

  PendingRedemption sentAt(DateTime at) => PendingRedemption(
    key: key,
    voucherId: voucherId,
    amount: amount,
    currency: currency,
    last4: last4,
    restaurantName: restaurantName,
    lastSentAt: at.toUtc(),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'voucher': voucherId,
    'amount': amount,
    'currency': currency,
    'last4': last4,
    'restaurant': restaurantName,
    'sent': lastSentAt.toIso8601String(),
  };
}

/// The open attempts of each user on this phone, encrypted at rest. They
/// survive sign-out and app restarts: only the user who sent an attempt can
/// ask the server for its outcome, so it is resolved when that user is back.
class PendingRedemptionStore extends ChangeNotifier {
  PendingRedemptionStore(this._store, {Uuid uuid = const Uuid(), DateTime Function()? now})
    : _uuid = uuid,
      _now = now ?? DateTime.now;

  static const String _key = 'pending_redemptions_v1';

  /// A request can run on the server at most this long after it was sent
  /// (gateway and PHP limits are 30 s); only after it is "not booked" final.
  static const Duration serverCeiling = Duration(seconds: 60);

  /// Upper bound per user; the oldest fall off (they are resolved long before).
  static const int maxPerUser = 50;

  final SecretStore _store;
  final Uuid _uuid;
  final DateTime Function() _now;

  Map<String, List<PendingRedemption>> _byUser = <String, List<PendingRedemption>>{};
  String? _userId;
  bool _loaded = false;

  DateTime now() => _now().toUtc();

  /// The open attempts of the signed-in user, oldest first.
  List<PendingRedemption> get entries =>
      List<PendingRedemption>.unmodifiable(_byUser[_userId] ?? const <PendingRedemption>[]);

  bool get isEmpty => entries.isEmpty;

  /// The open attempt for [voucherId], if any (there is at most one).
  PendingRedemption? forVoucher(String voucherId) {
    for (final PendingRedemption p in entries) {
      if (p.voucherId == voucherId) return p;
    }
    return null;
  }

  /// Whether a "not booked" answer for [p] is final: its last request can no
  /// longer be running on the server.
  bool notBookedIsFinal(PendingRedemption p) => now().difference(p.lastSentAt) >= serverCeiling;

  Future<void> load(String userId) async {
    _userId = userId;
    if (!_loaded) {
      _loaded = true;
      final String? raw = await _store.read(_key);
      if (raw != null) {
        try {
          final Map<String, Object?> json = (jsonDecode(raw) as Map<Object?, Object?>).cast<String, Object?>();
          _byUser = json.map(
            (String user, Object? rows) => MapEntry<String, List<PendingRedemption>>(
              user,
              (rows! as List<Object?>)
                  .map((Object? r) => PendingRedemption.fromJson((r! as Map<Object?, Object?>).cast<String, Object?>()))
                  .toList(),
            ),
          );
        } on Object {
          _byUser = <String, List<PendingRedemption>>{};
        }
      }
    }
    notifyListeners();
  }

  /// Signed out: the attempts stay stored for this user's next sign-in.
  void detach() {
    _userId = null;
    notifyListeners();
  }

  /// Opens an attempt and stores it before its first request is sent.
  Future<PendingRedemption> open({
    required String voucherId,
    required int amount,
    required String currency,
    required String last4,
    required String restaurantName,
  }) async {
    final String user = _userId ?? (throw StateError('No user signed in.'));
    final PendingRedemption p = PendingRedemption(
      key: _uuid.v4(),
      voucherId: voucherId,
      amount: amount,
      currency: currency,
      last4: last4,
      restaurantName: restaurantName,
      lastSentAt: now(),
    );
    final List<PendingRedemption> rows = <PendingRedemption>[
      ...(_byUser[user] ?? const <PendingRedemption>[]).where((PendingRedemption e) => e.voucherId != voucherId),
      p,
    ];
    _byUser[user] = rows.length > maxPerUser ? rows.sublist(rows.length - maxPerUser) : rows;
    await _persist();
    return p;
  }

  /// Records that another request of [p] is about to be sent.
  Future<PendingRedemption> resend(PendingRedemption p) => _replace(p, p.sentAt(now()));

  /// A definitive answer arrived: booked, refused or finally not booked.
  Future<void> resolve(PendingRedemption p) async {
    final String? user = _userId;
    if (user == null) return;
    _byUser[user] = (_byUser[user] ?? const <PendingRedemption>[])
        .where((PendingRedemption e) => e.key != p.key)
        .toList();
    await _persist();
  }

  Future<PendingRedemption> _replace(PendingRedemption old, PendingRedemption next) async {
    final String? user = _userId;
    if (user == null) return next;
    _byUser[user] = <PendingRedemption>[
      for (final PendingRedemption e in _byUser[user] ?? const <PendingRedemption>[]) e.key == old.key ? next : e,
    ];
    await _persist();
    return next;
  }

  Future<void> _persist() async {
    _byUser.removeWhere((String _, List<PendingRedemption> rows) => rows.isEmpty);
    if (_byUser.isEmpty) {
      await _store.delete(_key);
    } else {
      await _store.write(
        _key,
        jsonEncode(
          _byUser.map(
            (String user, List<PendingRedemption> rows) =>
                MapEntry<String, Object?>(user, rows.map((PendingRedemption p) => p.toJson()).toList()),
          ),
        ),
      );
    }
    notifyListeners();
  }
}
