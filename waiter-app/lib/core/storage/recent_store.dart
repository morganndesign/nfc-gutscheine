import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'secure_store.dart';

/// One row of the local shift history (09 §4.6). Nothing else is stored: no
/// full card number, no card id.
@immutable
class RecentEntry {
  const RecentEntry({
    required this.transactionId,
    required this.createdAt,
    required this.last4,
    required this.amount,
    required this.balanceAfter,
    required this.currency,
    required this.restaurantName,
    required this.businessDay,
    this.requestId = '',
  });

  factory RecentEntry.fromJson(Map<String, Object?> json) => RecentEntry(
        transactionId: json['tx'] as String,
        createdAt: DateTime.parse(json['at'] as String).toUtc(),
        last4: json['last4'] as String,
        amount: (json['amount'] as num).toInt(),
        balanceAfter: (json['balance'] as num).toInt(),
        currency: json['currency'] as String? ?? 'EUR',
        restaurantName: json['restaurant'] as String,
        businessDay: json['day'] as String,
        requestId: json['request'] as String? ?? '',
      );

  final String transactionId;
  final DateTime createdAt;
  final String last4;
  final int amount;
  final int balanceAfter;
  final String currency;
  final String restaurantName;

  /// Business-day key (`YYYY-MM-DD`, 04:00 rollover in the restaurant zone).
  final String businessDay;

  /// `X-Request-Id` of the redeem response; its last 6 characters are the
  /// support code in Recent detail (`recent.detail.supportCode`).
  final String requestId;

  Map<String, Object?> toJson() => <String, Object?>{
        'tx': transactionId,
        'at': createdAt.toIso8601String(),
        'last4': last4,
        'amount': amount,
        'balance': balanceAfter,
        'currency': currency,
        'restaurant': restaurantName,
        'day': businessDay,
        'request': requestId,
      };
}

/// Recent redemptions of the signed-in waiter on this device, today only.
/// Encrypted at rest via [SecretStore]; max 200 rows; deduplicated by
/// transaction id so a replayed response never adds a second row (I3).
class RecentStore extends ChangeNotifier {
  RecentStore(this._store);

  static const int maxRows = 200;
  static const String _key = 'recent_v1';

  final SecretStore _store;
  List<RecentEntry> _entries = const <RecentEntry>[];
  String? _userId;

  /// Newest first.
  List<RecentEntry> get entries => _entries;

  /// Loads the rows of [userId] for [businessDay]; rows of another user or day
  /// are dropped (user change, 04:00 rollover).
  Future<void> load({required String userId, required String businessDay}) async {
    _userId = userId;
    final String? raw = await _store.read(_key);
    List<RecentEntry> rows = const <RecentEntry>[];
    if (raw != null) {
      try {
        final Map<String, Object?> json = (jsonDecode(raw) as Map<Object?, Object?>).cast<String, Object?>();
        if (json['user'] == userId) {
          rows = (json['rows'] as List<Object?>)
              .map((Object? r) => RecentEntry.fromJson((r! as Map<Object?, Object?>).cast<String, Object?>()))
              .where((RecentEntry e) => e.businessDay == businessDay)
              .toList();
        }
      } on Object {
        rows = const <RecentEntry>[];
      }
    }
    _entries = List<RecentEntry>.unmodifiable(rows);
    await _persist();
    notifyListeners();
  }

  Future<void> add(RecentEntry entry) async {
    if (_entries.any((RecentEntry e) => e.transactionId == entry.transactionId)) return;
    final List<RecentEntry> next = <RecentEntry>[entry, ..._entries];
    _entries = List<RecentEntry>.unmodifiable(next.take(maxRows));
    try {
      await _persist();
    } on Object {
      // A Keystore or Keychain error: the row is shown for this app run. It never stops the redemption flow that
      // added it (an earlier booking found on S07 would otherwise stay "checking" forever).
    }
    notifyListeners();
  }

  /// Drops rows that are not from [businessDay] (rollover while running).
  Future<void> keepOnly(String businessDay) async {
    final List<RecentEntry> kept = _entries.where((RecentEntry e) => e.businessDay == businessDay).toList();
    if (kept.length == _entries.length) return;
    _entries = List<RecentEntry>.unmodifiable(kept);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _entries = const <RecentEntry>[];
    _userId = null;
    await _store.delete(_key);
    notifyListeners();
  }

  /// Total redeemed today (S13 header).
  int get total => _entries.fold<int>(0, (int sum, RecentEntry e) => sum + e.amount);

  Future<void> _persist() async {
    if (_userId == null) return;
    await _store.write(
      _key,
      jsonEncode(<String, Object?>{
        'user': _userId,
        'rows': _entries.map((RecentEntry e) => e.toJson()).toList(),
      }),
    );
  }
}
