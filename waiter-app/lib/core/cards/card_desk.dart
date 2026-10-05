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

  /// The deliveries to confirm. With [open] (the home screen's "delivery arrived" notice) that batch is chosen at
  /// once when it still waits for its receipt.
  Future<void> load({String? open}) async {
    _update(() {
      phase = DeskPhase.busy;
      requestFailed = false;
    });
    try {
      final List<CardBatchSummary> all = await _api.cardBatches();
      _update(
        () => batches = all.where((CardBatchSummary b) => b.status == 'shipped' || b.status == 'on_hold').toList(),
      );
      for (final CardBatchSummary b in batches!) {
        if (b.id == open) choose(b);
      }
    } on ApiFailure catch (e) {
      _session.handleFailure(e, SessionContext.lookup);
      _update(() => requestFailed = true);
    } finally {
      _update(() => phase = DeskPhase.idle);
    }
  }

  void choose(CardBatchSummary b) {
    if (b.status != 'shipped') return;
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
        if (e.contextString('reason') == 'other_batch') {
          _update(() => wrongCard = true);
        } else if (e.code == 'CARD_STATE_INVALID') {
          // The batch is no longer waiting: an earlier receipt (whose answer was lost) or another phone booked it.
          await _reconcile(b);
        } else {
          _update(() => requestFailed = true);
        }
      }
    } on ApiFailure catch (e) {
      _session.handleFailure(e, SessionContext.lookup);
      // No answer: the receipt may have been booked. The batch's status says (K5).
      if (e is ApiTransportFailure || e is ApiServerFault) {
        await _reconcile(b);
      } else {
        _update(() => requestFailed = true);
      }
    } finally {
      _update(() => phase = DeskPhase.idle);
    }
  }

  /// Reads the batch again after an unclear receipt: still `shipped` means nothing was booked; `on_hold` or gone
  /// from the list (in service) means the receipt was booked.
  Future<void> _reconcile(CardBatchSummary b) async {
    try {
      final List<CardBatchSummary> all = await _api.cardBatches();
      final CardBatchSummary? now = all.where((CardBatchSummary x) => x.id == b.id).firstOrNull;
      _update(() {
        batches = all.where((CardBatchSummary x) => x.status == 'shipped' || x.status == 'on_hold').toList();
        switch (now?.status) {
          case 'shipped':
            requestFailed = true;
          case 'on_hold':
            result = 'on_hold';
          default:
            result = 'in_service';
        }
      });
    } on ApiFailure catch (e) {
      _session.handleFailure(e, SessionContext.lookup);
      _update(() => requestFailed = true);
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

/// Which card the reader waits for on the card desk.
enum CardTapFor {
  /// A new card from stock (replacement).
  newCard,

  /// The guest's old card, at hand (a damaged card being replaced).
  oldCard,

  /// The found card, to resume it (decision 2026-10-06: only with the card at hand).
  resume,
}

/// Why the last card desk action did not happen (audit T7: the real reason, not always "try again").
enum CardDeskError {
  /// Try again.
  failed,

  /// The card changed meanwhile (the current state is shown).
  state,

  /// The tap was another card.
  otherCard,

  /// This sign-in may not do this.
  forbidden,

  /// The card pays for no voucher.
  notLinked,

  /// No answer and the card could not be read again: look it up.
  uncertain,
}

/// Looking up a guest's card by its inventory number (shown with the voucher in the dashboard): suspend it when
/// it is lost, resume it when found (tapping it), replace it with a stock card (the balance stays with the voucher).
class CardLookupController extends ChangeNotifier {
  CardLookupController({
    required WaiterApi api,
    required CardPresenter cards,
    required SessionController session,
    required CardSheetTexts texts,
    required CardSheetTexts oldCardTexts,
    required CardSheetTexts resumeTexts,
  }) : _api = api,
       _cards = cards,
       _session = session,
       _texts = texts,
       _oldCardTexts = oldCardTexts,
       _resumeTexts = resumeTexts;

  final WaiterApi _api;
  final CardPresenter _cards;
  final SessionController _session;
  final CardSheetTexts _texts;
  final CardSheetTexts _oldCardTexts;
  final CardSheetTexts _resumeTexts;
  bool _disposed = false;

  /// While tapping: which card is wanted.
  CardTapFor tappingFor = CardTapFor.newCard;

  static final RegExp _number = RegExp(r'^B-\d{4}-\d{4}-\d{4,}$');

  DeskPhase phase = DeskPhase.idle;
  CardInfo? card;
  bool notFound = false;

  /// The last action's refusal (null while none).
  CardDeskError? error;
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
    _update(() {
      phase = DeskPhase.busy;
      notFound = false;
      error = null;
      cardFailure = null;
    });
    try {
      final CardInfo found = await _api.card(number);
      _update(() {
        card = found;
        done = null;
        replaced = null;
      });
    } on ApiRejected catch (e) {
      if (!_session.handleFailure(e, SessionContext.lookup)) {
        _update(() => e.status == 404 ? notFound = true : error = CardDeskError.failed);
      }
    } on ApiFailure catch (e) {
      _session.handleFailure(e, SessionContext.lookup);
      _update(() => error = CardDeskError.failed);
    } finally {
      _update(() => phase = DeskPhase.idle);
    }
  }

  Future<void> suspend(String reason) async {
    final CardInfo? current = card;
    // A second press before the button disabled itself sends nothing (a second "suspend" is refused as a failure).
    if (current == null || phase != DeskPhase.idle) return;
    _start(DeskPhase.busy);
    try {
      final CardInfo next = await _api.changeCard(current.cardNumber, 'suspend', reason);
      _update(() {
        card = next;
        done = 'suspended';
      });
    } on ApiFailure catch (e) {
      await _refused(e, current, expect: 'suspended');
    } finally {
      _end();
    }
  }

  /// A found card works again only when it is here: it is held to the phone (a `resume` tap of this very card).
  /// A card from a compromised batch is never resumed ([CardInfo.resumable] false): it is replaced.
  Future<void> resume(String reason) async {
    final CardInfo? current = card;
    if (current == null || phase != DeskPhase.idle || current.resumable == false) return;
    _start(DeskPhase.tapping, tapFor: CardTapFor.resume);
    try {
      final CardPresented tapped = await _cards.present(
        'resume',
        texts: _resumeTexts,
        onDetected: () => _update(() => phase = DeskPhase.checking),
      );
      _update(() => phase = DeskPhase.busy);
      final CardInfo next = await _api.changeCard(current.cardNumber, 'resume', reason, presentmentId: tapped.id);
      _update(() {
        card = next;
        done = 'resumed';
      });
    } on CardPresentException catch (e) {
      if (e.api != null) _session.handleFailure(e.api!, SessionContext.lookup);
      if (e.failure != CardPresentFailure.cancelled) _update(() => cardFailure = e);
    } on ApiFailure catch (e) {
      await _refused(e, current, expect: 'active');
    } finally {
      _end();
    }
  }

  /// Moves the voucher to a stock card. With [oldCardAtHand] the guest's card is tapped first (it proves it is at the
  /// till); without it (lost, stolen) the server accepts it only from an owner.
  Future<void> replace(String reason, {required bool oldCardAtHand}) async {
    final CardInfo? current = card;
    if (current == null || phase != DeskPhase.idle) return;
    _start(DeskPhase.tapping, tapFor: oldCardAtHand ? CardTapFor.oldCard : CardTapFor.newCard);
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
          tappingFor = CardTapFor.newCard;
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
      await _refused(e, current, expect: 'replaced');
    } finally {
      _end();
    }
  }

  void clear() {
    if (phase != DeskPhase.idle) return;
    _update(() {
      card = null;
      notFound = false;
      error = null;
      cardFailure = null;
      done = null;
      replaced = null;
    });
  }

  Future<void> cancelTap() async {
    if (phase == DeskPhase.tapping) await _cards.cancel();
  }

  void _start(DeskPhase next, {CardTapFor tapFor = CardTapFor.newCard}) => _update(() {
    phase = next;
    tappingFor = tapFor;
    notFound = false;
    error = null;
    cardFailure = null;
    done = null;
  });

  void _end() => _update(() {
    phase = DeskPhase.idle;
    tappingFor = CardTapFor.newCard;
  });

  /// An action on [before] was refused or got no answer. A refusal says why; without an answer (or when the card
  /// changed meanwhile) the card is read again: when it reached [expect], the action was booked (K5, T7).
  Future<void> _refused(ApiFailure e, CardInfo before, {required String expect}) async {
    if (e is ApiRejected && e.status == 403) {
      _update(() => error = CardDeskError.forbidden);
      return;
    }
    if (_session.handleFailure(e, SessionContext.lookup)) return;
    final bool unanswered = e is ApiTransportFailure || e is ApiServerFault;
    if (e is ApiRejected && !unanswered) {
      final CardDeskError reason = switch (e.code) {
        'PRESENTMENT_INVALID' when e.contextString('reason') == 'other_card' => CardDeskError.otherCard,
        'CARD_STATE_INVALID' when e.contextString('state') == null && e.contextString('reason') == null =>
          CardDeskError.notLinked,
        'CARD_STATE_INVALID' => CardDeskError.state,
        _ => CardDeskError.failed,
      };
      if (reason != CardDeskError.state) {
        _update(() => error = reason);
        return;
      }
    }
    // Read the card again: its state shows what happened.
    try {
      final CardInfo now = await _api.card(before.cardNumber);
      if (now.state == expect) {
        final String? successor = now.successor;
        if (expect == 'replaced' && successor != null) {
          final CardInfo next = await _api.card(successor);
          _update(() {
            replaced = before.cardNumber;
            card = next;
            done = 'replaced';
          });
        } else {
          _update(() {
            card = now;
            done = expect == 'active' ? 'resumed' : expect;
          });
        }
        return;
      }
      _update(() {
        card = now;
        error = unanswered ? CardDeskError.failed : CardDeskError.state;
      });
    } on ApiFailure catch (again) {
      _session.handleFailure(again, SessionContext.lookup);
      _update(() => error = CardDeskError.uncertain);
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
