import 'package:uuid/uuid.dart';

/// Pending redeem attempts (09 §4.3 K1–K9): one `Idempotency-Key` per
/// (card id, amount). Memory only — a process kill discards them (K7).
class RedeemAttempts {
  RedeemAttempts({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  final Map<String, String> _keys = <String, String>{};

  static String _tuple(String cardId, int amount) => '$cardId|$amount';

  /// K1/K3: reuses the pending key for the tuple or creates one — called only
  /// when the Redeem action starts.
  String keyFor(String cardId, int amount) => _keys.putIfAbsent(_tuple(cardId, amount), _uuid.v4);

  bool hasPending(String cardId, int amount) => _keys.containsKey(_tuple(cardId, amount));

  /// K5: success, definitive 4xx, amount change, S07 closed.
  void close(String cardId, int amount) => _keys.remove(_tuple(cardId, amount));

  /// K5: amount changed — every other amount's attempt for the card is dropped.
  void keepOnly(String cardId, int amount) =>
      _keys.removeWhere((String tuple, String _) => tuple.startsWith('$cardId|') && tuple != _tuple(cardId, amount));

  /// K5: card switch, sign-out, business-day rollover, background > 15 min.
  void clear() => _keys.clear();
}
