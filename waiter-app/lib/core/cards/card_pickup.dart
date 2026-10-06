import 'package:flutter/foundation.dart';

import '../api/api_failure.dart';
import '../api/models.dart';
import '../api/waiter_api.dart';
import '../state/session_controller.dart';
import '../state/session_state.dart';
import 'card_desk.dart';
import 'card_presenter.dart';

/// Why a gift card cannot be handed out for the scanned voucher (online sales, decision 2026-10-06).
enum CardPickupProblem {
  /// Not a voucher of this restaurant (unknown, revoked or foreign code).
  notRecognized,

  /// A voucher, but not one bought online with a gift card (a printed voucher, or already a card).
  notOnline,

  /// Bought online without a gift card.
  noCardOrdered,

  /// Its card was handed out already.
  pickedUp,

  /// Not before 24 hours after the payment ([CardPickupController.availableFrom]).
  tooEarly,

  /// The scan is older than its validity: scan again.
  scanAgain,

  /// The voucher is blocked or expired.
  voucherNotUsable,

  failed,
  offline,
}

/// Handing out the gift card of an online voucher (managers and owners, Android and iPhone alike): scan the QR from
/// the guest's e-mail, then hold a new card from stock to the phone. The card takes over the voucher and its
/// balance; the e-mailed QR stops at once.
class CardPickupController extends ChangeNotifier {
  CardPickupController({
    required WaiterApi api,
    required CardPresenter cards,
    required SessionController session,
    required CardSheetTexts texts,
    DateTime Function()? clock,
  }) : _api = api,
       _cards = cards,
       _session = session,
       _texts = texts,
       _clock = clock ?? DateTime.now;

  final WaiterApi _api;
  final CardPresenter _cards;
  final SessionController _session;
  final CardSheetTexts _texts;
  final DateTime Function() _clock;
  bool _disposed = false;

  DeskPhase phase = DeskPhase.idle;

  /// The scanned voucher (its balance and pickup), until the card is handed out.
  PresentedVoucher? voucher;
  String? _qrPresentmentId;

  CardPickupProblem? problem;

  /// For [CardPickupProblem.tooEarly]: from when the card may be handed out.
  DateTime? availableFrom;
  CardPresentException? cardFailure;

  /// The card handed out (the screen shows it).
  PickedUpCard? done;

  /// Step 1: the QR text the camera read.
  Future<void> scanned(String credential) async {
    if (phase != DeskPhase.idle) return;
    _update(() {
      phase = DeskPhase.busy;
      problem = null;
      cardFailure = null;
      availableFrom = null;
      done = null;
      voucher = null;
    });
    try {
      final Presentment p = await _api.presentQr(credential.trim(), purpose: 'pickup');
      final CardPickup? pickup = p.voucher.cardPickup;
      final DateTime? from = pickup?.from;
      _update(() {
        if (pickup == null) {
          problem = CardPickupProblem.noCardOrdered;
        } else if (!pickup.open) {
          problem = CardPickupProblem.pickedUp;
        } else if (from != null && _clock().isBefore(from)) {
          problem = CardPickupProblem.tooEarly;
          availableFrom = from.toLocal();
        } else {
          voucher = p.voucher;
          _qrPresentmentId = p.id;
        }
      });
    } on ApiRejected catch (e) {
      if (!_session.handleFailure(e, SessionContext.lookup)) {
        _update(() => problem = switch (e.code) {
          'PRESENTMENT_METHOD_NOT_ALLOWED' => CardPickupProblem.notOnline,
          'MEDIUM_NOT_RECOGNIZED' => CardPickupProblem.notRecognized,
          _ => e.status == 403 ? CardPickupProblem.failed : CardPickupProblem.notRecognized,
        });
      }
    } on ApiTransportFailure {
      _update(() => problem = CardPickupProblem.offline);
    } on ApiFailure catch (e) {
      _session.handleFailure(e, SessionContext.lookup);
      _update(() => problem = CardPickupProblem.failed);
    } finally {
      _update(() => phase = DeskPhase.idle);
    }
  }

  /// Step 2: a new card from stock, held to the phone, takes over the voucher.
  Future<void> handOut() async {
    final PresentedVoucher? v = voucher;
    final String? qr = _qrPresentmentId;
    if (v == null || qr == null || phase != DeskPhase.idle) return;
    _update(() {
      phase = DeskPhase.tapping;
      problem = null;
      cardFailure = null;
    });
    try {
      final CardPresented card = await _cards.present(
        'bind',
        texts: _texts,
        onDetected: () => _update(() => phase = DeskPhase.checking),
      );
      _update(() => phase = DeskPhase.busy);
      final PickedUpCard result = await _api.pickUpCard(v.id, qrPresentmentId: qr, cardPresentmentId: card.id);
      _update(() {
        done = result;
        voucher = null;
        _qrPresentmentId = null;
      });
    } on CardPresentException catch (e) {
      if (e.api != null) _session.handleFailure(e.api!, SessionContext.lookup);
      if (e.failure != CardPresentFailure.cancelled) _update(() => cardFailure = e);
    } on ApiRejected catch (e) {
      if (!_session.handleFailure(e, SessionContext.lookup)) {
        final String? reason = e.contextString('reason');
        _update(() {
          problem = switch (e.code) {
            // The scan's 60 seconds ran out while the card was fetched: scan the QR again.
            'PRESENTMENT_INVALID' when reason == 'expired' || reason == 'already_used' => CardPickupProblem.scanAgain,
            'INVALID_VOUCHER_STATE' when reason == 'picked_up' => CardPickupProblem.pickedUp,
            'INVALID_VOUCHER_STATE' when reason == 'too_early' => CardPickupProblem.tooEarly,
            'INVALID_VOUCHER_STATE' when reason == 'no_card_ordered' => CardPickupProblem.noCardOrdered,
            'VOUCHER_BLOCKED' || 'VOUCHER_EXPIRED' || 'VOUCHER_NOT_REDEEMABLE' => CardPickupProblem.voucherNotUsable,
            _ => CardPickupProblem.failed,
          };
          if (problem == CardPickupProblem.tooEarly) {
            final DateTime? from = DateTime.tryParse(e.contextString('from') ?? '');
            availableFrom = from?.toLocal();
          }
          if (problem != CardPickupProblem.failed) {
            voucher = null;
            _qrPresentmentId = null;
          }
        });
      }
    } on ApiTransportFailure {
      _update(() => problem = CardPickupProblem.offline);
    } on ApiFailure catch (e) {
      _session.handleFailure(e, SessionContext.lookup);
      _update(() => problem = CardPickupProblem.failed);
    } finally {
      _update(() => phase = DeskPhase.idle);
    }
  }

  /// Back to the scan (the next guest, or after a problem).
  void reset() {
    if (phase != DeskPhase.idle) return;
    _update(() {
      voucher = null;
      _qrPresentmentId = null;
      problem = null;
      cardFailure = null;
      availableFrom = null;
      done = null;
    });
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
