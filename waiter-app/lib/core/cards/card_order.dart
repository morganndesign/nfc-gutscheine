import 'package:flutter/foundation.dart';

import '../api/api_failure.dart';
import '../api/models.dart';
import '../api/waiter_api.dart';
import '../format/amount_entry.dart';
import '../state/session_controller.dart';
import '../state/session_state.dart';
import 'card_desk.dart';

/// Ordering cards from the platform (managers and owners, Android and iPhone alike): the quantity is typed on the
/// keypad and sent; the platform accepts (a batch is ordered) or declines with a reason. The latest order is shown.
class CardOrderController extends ChangeNotifier {
  CardOrderController({required WaiterApi api, required SessionController session}) : _api = api, _session = session;

  /// The most a single order may ask for (as the server).
  static const int maxQuantity = 1000;

  final WaiterApi _api;
  final SessionController _session;
  bool _disposed = false;

  DeskPhase phase = DeskPhase.idle;

  /// Digits typed for the quantity.
  String count = '';

  /// The newest order, if any (its status is shown as a banner).
  CardOrderInfo? latest;

  /// The order just sent (the screen shows the confirmation).
  CardOrderInfo? sent;

  bool requestFailed = false;

  /// Three orders are already waiting for the platform.
  bool tooMany = false;

  int get quantity => count.isEmpty ? 0 : int.parse(count);

  Future<void> load() async {
    try {
      final List<CardOrderInfo> orders = await _api.cardOrders();
      _update(() => latest = orders.isEmpty ? null : orders.first);
    } on ApiFailure catch (e) {
      // The banner is a convenience: ordering works without it.
      _session.handleFailure(e, SessionContext.lookup);
    }
  }

  EntryOutcome digit(int d) {
    if (count.isEmpty && d == 0) return EntryOutcome.ignored;
    if (int.parse('$count$d') > maxQuantity) return EntryOutcome.rejectedAtLimit;
    _update(() => count += '$d');
    return EntryOutcome.accepted;
  }

  EntryOutcome backspace() {
    if (count.isEmpty) return EntryOutcome.ignored;
    _update(() => count = count.substring(0, count.length - 1));
    return EntryOutcome.deleted;
  }

  EntryOutcome clear() {
    if (count.isEmpty) return EntryOutcome.ignored;
    _update(() => count = '');
    return EntryOutcome.cleared;
  }

  Future<void> submit() async {
    if (count.isEmpty || phase != DeskPhase.idle) return;
    _update(() {
      phase = DeskPhase.busy;
      requestFailed = false;
      tooMany = false;
    });
    try {
      final CardOrderInfo order = await _api.orderCards(quantity);
      _update(() => sent = latest = order);
    } on ApiRejected catch (e) {
      if (!_session.handleFailure(e, SessionContext.lookup)) {
        _update(() => e.contextString('reason') == 'too_many_open' ? tooMany = true : requestFailed = true);
      }
    } on ApiFailure catch (e) {
      // A lost answer may still have placed the order; the list on the next visit shows it (3 open at most).
      _session.handleFailure(e, SessionContext.lookup);
      _update(() => requestFailed = true);
    } finally {
      _update(() => phase = DeskPhase.idle);
    }
  }

  void _update(void Function() change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
