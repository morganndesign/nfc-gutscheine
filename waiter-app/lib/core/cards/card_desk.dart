import 'package:flutter/foundation.dart';

import '../api/api_failure.dart';
import '../api/models.dart';
import '../api/waiter_api.dart';
import '../format/amount_entry.dart';
import '../state/session_controller.dart';
import '../state/session_state.dart';
import 'card_presenter.dart';

typedef CardSheetTexts = ({String prompt, String checking, String done, String failed});

/// What a card desk step is doing.
enum DeskPhase {
  /// Waiting for input (a batch, a count, a card number, an action).
  idle,

  /// A request is running.
  busy,

  /// The card reader waits for a card.
  tapping,

  /// A card is on the phone; the server checks it.
  checking,
}

/// Confirming a card delivery: choose the delivered batch, type the counted quantity, tap one card of the parcel.
/// A matching count puts every card in stock; a mismatch puts the batch on hold for the platform.
class ReceiveDeliveryController extends ChangeNotifier {
  ReceiveDeliveryController({
    required WaiterApi api,
    required CardPresenter cards,
    required SessionController session,
    required CardSheetTexts texts,
  }) : _api = api,
       _cards = cards,
       _session = session,
       _texts = texts;

  final WaiterApi _api;
  final CardPresenter _cards;
  final SessionController _session;
  final CardSheetTexts _texts;
  bool _disposed = false;

  DeskPhase phase = DeskPhase.idle;
  List<CardBatchSummary>? batches;
  CardBatchSummary? batch;

  /// Digits typed for the count.
  String count = '';

  /// The batch's status after the receipt: `in_service` or `on_hold`.
  String? result;

  /// The last failure (null while none).
  CardPresentException? cardFailure;
  bool requestFailed = false;
  bool wrongCard = false;

  Future<void> load() async {
    _update(() {
      phase = DeskPhase.busy;
      requestFailed = false;
    });
    try {
      final List<CardBatchSummary> all = await _api.cardBatches();
      _update(
        () => batches = all.where((CardBatchSummary b) => b.status == 'delivered' || b.status == 'on_hold').toList(),
      );
    } on ApiFailure catch (e) {
      _session.handleFailure(e, SessionContext.lookup);
      _update(() => requestFailed = true);
    } finally {
      _update(() => phase = DeskPhase.idle);
    }
  }

  void choose(CardBatchSummary b) {
    if (b.status != 'delivered') return;
    _update(() {
      batch = b;
      count = '';
      result = null;
    });
  }

  EntryOutcome digit(int d) {
    if (count.isEmpty && d == 0) return EntryOutcome.ignored;
    if (count.length >= 5) return EntryOutcome.rejectedAtLimit;
    _update(() => count += '$d');
    return EntryOutcome.accepted;
  }

  EntryOutcome backspace() {
    if (count.isEmpty) return EntryOutcome.ignored;
    _update(() => count = count.substring(0, count.length - 1));
    return EntryOutcome.deleted;
  }

  EntryOutcome clearCount() {
    if (count.isEmpty) return EntryOutcome.ignored;
    _update(() => count = '');
    return EntryOutcome.cleared;
  }

  void back() {
    if (phase != DeskPhase.idle) return;
    _update(() {
      batch = null;
      count = '';
      result = null;
      cardFailure = null;
      requestFailed = false;
      wrongCard = false;
    });
  }

  /// Taps one card of the parcel and sends the receipt.
  Future<void> confirm() async {
    final CardBatchSummary? b = batch;
    if (b == null || count.isEmpty || phase != DeskPhase.idle) return;
    _update(() {
      phase = DeskPhase.tapping;
      cardFailure = null;
      requestFailed = false;
      wrongCard = false;
    });
    try {
      final CardPresented card = await _cards.present(
        'receive',
        texts: _texts,
        onDetected: () => _update(() => phase = DeskPhase.checking),
      );
      _update(() => phase = DeskPhase.busy);
      final String status = await _api.receiveCardBatch(b.id, int.parse(count), card.id);
      _update(() => result = status);
    } on CardPresentException catch (e) {
      if (e.api != null) _session.handleFailure(e.api!, SessionContext.lookup);
      if (e.failure != CardPresentFailure.cancelled) _update(() => cardFailure = e);
    } on ApiRejected catch (e) {
      if (!_session.handleFailure(e, SessionContext.lookup)) {
        _update(() => e.contextString('reason') == 'other_batch' ? wrongCard = true : requestFailed = true);
      }
    } on ApiFailure catch (e) {
      _session.handleFailure(e, SessionContext.lookup);
      _update(() => requestFailed = true);
    } finally {
      _update(() => phase = DeskPhase.idle);
    }
  }

  Future<void> cancelTap() async {
    if (phase == DeskPhase.tapping) await _cards.cancel();
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

/// Looking up a guest's card by its inventory number (shown with the voucher in the dashboard): suspend it when
/// it is lost, resume it when found, replace it with a stock card (the balance stays with the voucher).
class CardLookupController extends ChangeNotifier {
  CardLookupController({
    required WaiterApi api,
    required CardPresenter cards,
    required SessionController session,
    required CardSheetTexts texts,
    required CardSheetTexts oldCardTexts,
  }) : _api = api,
       _cards = cards,
       _session = session,
       _texts = texts,
       _oldCardTexts = oldCardTexts;

  final WaiterApi _api;
  final CardPresenter _cards;
  final SessionController _session;
  final CardSheetTexts _texts;
  final CardSheetTexts _oldCardTexts;
  bool _disposed = false;

  /// While tapping for a replacement: whether the old card (true) or the new stock card is wanted.
  bool tappingOldCard = false;

  static final RegExp _number = RegExp(r'^B-\d{4}-\d{4}-\d{4,}$');

  DeskPhase phase = DeskPhase.idle;
  CardInfo? card;
  bool notFound = false;
  bool requestFailed = false;
  CardPresentException? cardFailure;

  /// What the last action did: `suspended`, `resumed` or `replaced` (then [card] is the new card).
  String? done;

  /// The card that was replaced (for the confirmation).
  String? replaced;

  static String normalise(String input) => input.trim().toUpperCase().replaceAll(' ', '');

  static bool isNumber(String input) => _number.hasMatch(normalise(input));

  Future<void> find(String input) async {
    final String number = normalise(input);
    if (!_number.hasMatch(number) || phase != DeskPhase.idle) {
      _update(() => notFound = true);
      return;
    }
    await _request(() async {
      card = await _api.card(number);
      done = null;
      replaced = null;
    });
  }

  Future<void> suspend(String reason) => _change('suspend', reason, 'suspended');

  Future<void> resume(String reason) => _change('resume', reason, 'resumed');

  Future<void> _change(String action, String reason, String outcome) async {
    final CardInfo? current = card;
    if (current == null) return;
    await _request(() async {
      card = await _api.changeCard(current.cardNumber, action, reason);
      done = outcome;
    });
  }

  /// Moves the voucher to a stock card. With [oldCardAtHand] the guest's card is tapped first (it proves it is at the
  /// till); without it (lost, stolen) the server accepts it only from an owner.
  Future<void> replace(String reason, {required bool oldCardAtHand}) async {
    final CardInfo? current = card;
    if (current == null || phase != DeskPhase.idle) return;
    _update(() {
      phase = DeskPhase.tapping;
      tappingOldCard = oldCardAtHand;
      cardFailure = null;
      requestFailed = false;
      done = null;
    });
    try {
      String? surrender;
      if (oldCardAtHand) {
        surrender = (await _cards.present(
          'surrender',
          texts: _oldCardTexts,
          onDetected: () => _update(() => phase = DeskPhase.checking),
        )).id;
        _update(() {
          phase = DeskPhase.tapping;
          tappingOldCard = false;
        });
      }
      final CardPresented fresh = await _cards.present(
        'bind',
        texts: _texts,
        onDetected: () => _update(() => phase = DeskPhase.checking),
      );
      _update(() => phase = DeskPhase.busy);
      final CardInfo next = await _api.replaceCard(current.cardNumber, fresh.id, reason, surrenderPresentmentId: surrender);
      _update(() {
        replaced = current.cardNumber;
        card = next;
        done = 'replaced';
      });
    } on CardPresentException catch (e) {
      if (e.api != null) _session.handleFailure(e.api!, SessionContext.lookup);
      if (e.failure != CardPresentFailure.cancelled) _update(() => cardFailure = e);
    } on ApiFailure catch (e) {
      if (!_session.handleFailure(e, SessionContext.lookup)) _update(() => requestFailed = true);
    } finally {
      _update(() {
        phase = DeskPhase.idle;
        tappingOldCard = false;
      });
    }
  }

  void clear() {
    if (phase != DeskPhase.idle) return;
    _update(() {
      card = null;
      notFound = false;
      requestFailed = false;
      cardFailure = null;
      done = null;
      replaced = null;
    });
  }

  Future<void> cancelTap() async {
    if (phase == DeskPhase.tapping) await _cards.cancel();
  }

  Future<void> _request(Future<void> Function() run) async {
    _update(() {
      phase = DeskPhase.busy;
      notFound = false;
      requestFailed = false;
      cardFailure = null;
    });
    try {
      await run();
    } on ApiRejected catch (e) {
      if (!_session.handleFailure(e, SessionContext.lookup)) {
        _update(() => e.status == 404 ? notFound = true : requestFailed = true);
      }
    } on ApiFailure catch (e) {
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
