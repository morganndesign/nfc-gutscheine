import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/api_failure.dart';
import '../api/models.dart';
import '../api/waiter_api.dart';
import '../cards/card_presenter.dart';
import '../format/amount_entry.dart';
import '../state/session_controller.dart';
import '../state/session_state.dart';

/// S24 · Top up card (managers and owners, `vouchers.reload`, Android and iPhone alike): tap the card → amount →
/// how the guest paid → booked with the tap. The tap is valid 60 s; when it is older at "Top up", the card is held
/// once more to confirm.
///
/// - A guest's active card (its balance shows) is topped up: `POST /vouchers/{id}/reloads`.
/// - A new card from stock (the tap names no voucher) is sold with that amount, like a card sale on S20:
///   `POST /vouchers` (form card) with the same tap. Staff need not switch screens for a guest who wants a card
///   "topped up" that was never sold. Only someone who may sell cards activates one.
@immutable
sealed class ReloadState {
  const ReloadState();
}

/// The guest's card is to be held to the phone ([checking] once it is there). [again]: confirming an expired tap.
final class ReloadTapCard extends ReloadState {
  const ReloadTapCard({this.again = false, this.checking = false});

  final bool again;
  final bool checking;
}

/// The amount on the keypad. A top-up shows [max] when it would exceed the balance limit; a new card shows the
/// sale range [min]–[max] when the value is outside it.
final class ReloadAmount extends ReloadState {
  const ReloadAmount({required this.card, this.amount = AmountEntry.empty, this.min, this.max});

  final CardPresented card;
  final AmountEntry amount;
  final int? min;
  final int? max;

  /// A card from stock: sold with this amount instead of topped up.
  bool get newCard => card.isNew;
}

/// Payment method and reference or reason.
final class ReloadDetails extends ReloadState {
  const ReloadDetails({
    required this.card,
    required this.amount,
    this.method = PaymentMethod.cash,
    this.submitting = false,
    this.referenceMissing = false,
    this.reasonMissing = false,
  });

  final CardPresented card;
  final AmountEntry amount;
  final PaymentMethod method;

  bool get newCard => card.isNew;

  /// The tap to confirm or the booking in flight.
  final bool submitting;
  final bool referenceMissing;
  final bool reasonMissing;

  ReloadDetails copyWith({PaymentMethod? method, bool? submitting, bool? referenceMissing, bool? reasonMissing}) =>
      ReloadDetails(
        card: card,
        amount: amount,
        method: method ?? this.method,
        submitting: submitting ?? this.submitting,
        referenceMissing: referenceMissing ?? this.referenceMissing,
        reasonMissing: reasonMissing ?? this.reasonMissing,
      );
}

enum ReloadProblemKind {
  /// The card could not be presented ([ReloadProblem.card]); nothing was booked.
  card,

  /// Definitive answer: nothing was booked.
  failed,

  /// No (readable) answer: it may have been booked — "Try again" replays with the same key.
  uncertain,

  /// 403 or RELOAD_NOT_ALLOWED.
  notAllowed,

  /// A new card from stock, and this sign-in may not sell cards: someone who may sell activates it.
  cannotSell,
}

final class ReloadProblem extends ReloadState {
  const ReloadProblem(this.kind, {this.details, this.card, this.requestId});

  final ReloadProblemKind kind;

  /// The entry to return to (null: the first tap failed).
  final ReloadDetails? details;
  final CardPresentException? card;
  final String? requestId;
}

final class ReloadDone extends ReloadState {
  const ReloadDone({required this.amount, required this.balance, required this.currency, this.activatedCard});

  ReloadDone.toppedUp(ReloadResult r) : this(amount: r.amount, balance: r.balance, currency: r.currency);

  ReloadDone.sold(SoldVoucher v, String cardNumber)
    : this(amount: v.value, balance: v.value, currency: v.currency, activatedCard: v.cardNumber ?? cardNumber);

  /// Cents loaded now.
  final int amount;

  /// The card's balance now.
  final int balance;
  final String currency;

  /// A new card from stock, sold and now active: its inventory number. Null for a top-up.
  final String? activatedCard;
}

class ReloadController extends ChangeNotifier {
  ReloadController({
    required WaiterApi api,
    required SessionController session,
    required CardPresenter cards,
    required ({String prompt, String again, String checking, String done, String failed}) texts,
    Uuid uuid = const Uuid(),
    DateTime Function()? clock,
  }) : _api = api,
       _session = session,
       _cards = cards,
       _texts = texts,
       _uuid = uuid,
       _clock = clock ?? DateTime.now,
       _idempotencyKey = uuid.v4();

  final WaiterApi _api;
  final SessionController _session;
  final CardPresenter _cards;
  final ({String prompt, String again, String checking, String done, String failed}) _texts;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// Margin kept before the tap's expiry for the request to reach the server.
  static const Duration _margin = Duration(seconds: 8);

  String _idempotencyKey;
  String? _presentmentId;
  DateTime? _presentmentValidUntil;
  bool _disposed = false;

  /// A request with the current key went out and its answer never arrived.
  bool _unanswered = false;

  bool get uncertain => _unanswered;

  String reference = '';
  String reason = '';

  ReloadState _state = const ReloadTapCard();
  ReloadState get state => _state;

  RestaurantSettings? get _settings => _session.user?.restaurant?.settings;

  /// The currency of the amount: the voucher's, or the restaurant's for a new card.
  String currencyOf(CardPresented card) => card.voucher?.currency ?? _session.user?.restaurant?.currency ?? 'EUR';

  List<PaymentMethod> get methods => <PaymentMethod>[
    PaymentMethod.cash,
    PaymentMethod.cardTerminal,
    PaymentMethod.bankTransfer,
    if (_session.user?.canSellComplimentary ?? false) PaymentMethod.complimentary,
  ];

  // ------------------------------------------------------------------ tap

  /// Step 1: the card. A guest's card brings its voucher and balance; a new card from stock brings none.
  Future<void> tap() async {
    if (_state case ReloadTapCard(checking: true)) return;
    _set(const ReloadTapCard());
    final CardPresented? p = await _present(again: false);
    if (p == null) return;
    // Said at once, not after the amount: the server would refuse the sale anyway.
    if (p.isNew && !(_session.user?.canSellCards ?? false)) {
      _definitive();
      _set(const ReloadProblem(ReloadProblemKind.cannotSell));
      return;
    }
    _set(ReloadAmount(card: p));
  }

  /// [expected]: confirming an expired tap, which must be the same card in the same state.
  Future<CardPresented?> _present({required bool again, CardPresented? expected}) async {
    try {
      final CardPresented p = await _cards.present(
        'reload',
        texts: (
          prompt: again ? _texts.again : _texts.prompt,
          checking: _texts.checking,
          done: _texts.done,
          failed: _texts.failed,
        ),
        onDetected: () => _set(ReloadTapCard(again: again, checking: true)),
      );
      if (expected != null && (p.cardNumber != expected.cardNumber || p.isNew != expected.isNew)) {
        // Another card, or the new card was sold at another till meanwhile: the entry was for that card.
        throw CardPresentException(
          CardPresentFailure.notUsable,
          cardState: p.cardNumber != expected.cardNumber ? CardPresentException.otherCard : 'card_state',
        );
      }
      _presentmentId = p.id;
      _presentmentValidUntil = _clock().add(p.expiresIn - _margin);
      return p;
    } on CardPresentException catch (e) {
      if (e.api != null) _session.handleFailure(e.api!, SessionContext.lookup);
      if (_disposed) return null;
      _set(ReloadProblem(ReloadProblemKind.card, card: e, requestId: e.requestId, details: _lastDetails));
      return null;
    }
  }

  ReloadDetails? _lastDetails;

  // ------------------------------------------------------------------ amount

  EntryOutcome digit(int d) => _edit((AmountEntry a) => a.digit(d));

  EntryOutcome doubleZero() => _edit((AmountEntry a) => a.doubleZero());

  EntryOutcome backspace() => _edit((AmountEntry a) => a.backspace());

  EntryOutcome clear() => _edit((AmountEntry a) => a.clear());

  EntryOutcome _edit(EntryChange<AmountEntry> Function(AmountEntry a) change) {
    final ReloadState s = _state;
    if (s is! ReloadAmount) return EntryOutcome.ignored;
    final EntryChange<AmountEntry> c = change(s.amount);
    _set(ReloadAmount(card: s.card, amount: c.value));
    return c.outcome;
  }

  bool get canContinue => _state is ReloadAmount && !(_state as ReloadAmount).amount.isEmpty;

  /// The most that can be loaded without exceeding the restaurant's balance limit (null: no limit known).
  int? _room(PresentedVoucher voucher) {
    final int? max = _settings?.maxVoucherBalance;
    return max == null ? null : (max - voucher.balance).clamp(0, max);
  }

  void continueToDetails() {
    final ReloadState s = _state;
    if (s is! ReloadAmount || s.amount.isEmpty) return;
    final int value = s.amount.cents;
    final PresentedVoucher? voucher = s.card.voucher;
    if (voucher == null) {
      // A new card is sold: the sale's limits (as on S20).
      final int? min = _settings?.minVoucherValue;
      final int? max = _settings?.maxVoucherBalance;
      if ((min != null && value < min) || (max != null && value > max)) {
        _set(ReloadAmount(card: s.card, amount: s.amount, min: min ?? 1, max: max ?? value));
        return;
      }
    } else {
      final int? room = _room(voucher);
      if (room != null && value > room) {
        _set(ReloadAmount(card: s.card, amount: s.amount, max: room));
        return;
      }
    }
    _set(ReloadDetails(card: s.card, amount: s.amount));
  }

  void backToAmount() {
    final ReloadState s = _state;
    if (s is ReloadDetails && !s.submitting) _set(ReloadAmount(card: s.card, amount: s.amount));
  }

  // ------------------------------------------------------------------ details

  void chooseMethod(PaymentMethod method) {
    final ReloadState s = _state;
    if (s is ReloadDetails && !s.submitting) {
      _set(s.copyWith(method: method, referenceMissing: false, reasonMissing: false));
    }
  }

  void setReference(String value) {
    reference = value;
    final ReloadState s = _state;
    if (s is ReloadDetails && s.referenceMissing && value.trim().isNotEmpty) _set(s.copyWith(referenceMissing: false));
  }

  void setReason(String value) {
    reason = value;
    final ReloadState s = _state;
    if (s is ReloadDetails && s.reasonMissing && value.trim().length >= 3) _set(s.copyWith(reasonMissing: false));
  }

  // ------------------------------------------------------------------ book

  /// Codes only the top-up or the sale itself answers with: after a lost answer they prove nothing was booked
  /// (the server answers a booked key before it checks anything else).
  static const Set<String> _reloadCodes = <String>{
    'INVALID_AMOUNT',
    'BALANCE_LIMIT_EXCEEDED',
    'RELOAD_NOT_ALLOWED',
    'VALIDATION_FAILED',
    'COMPLIMENTARY_NOT_ALLOWED',
    'PRESENTMENT_INVALID',
    ..._voucherCodes,
  };

  /// The voucher behind the card cannot take money (blocked, expired, closed): nothing was booked.
  static const Set<String> _voucherCodes = <String>{
    'VOUCHER_BLOCKED',
    'VOUCHER_EXPIRED',
    'VOUCHER_NOT_REDEEMABLE',
    'INVALID_VOUCHER_STATE',
  };

  Future<void> submit() async {
    final ReloadState s = _state;
    final ReloadDetails? details = switch (s) {
      ReloadDetails(:final bool submitting) when !submitting => s,
      ReloadProblem(
        kind: ReloadProblemKind.uncertain || ReloadProblemKind.failed || ReloadProblemKind.card,
        :final ReloadDetails? details,
      )
          when details != null =>
        details,
      _ => null,
    };
    if (details == null) return;
    _lastDetails = details.copyWith(submitting: false);

    final PaymentMethod method = details.method;
    final bool referenceMissing = method.needsReference && reference.trim().isEmpty;
    final bool reasonMissing = method.needsReason && reason.trim().length < 3;
    if (!_unanswered && (referenceMissing || reasonMissing)) {
      _set(details.copyWith(submitting: false, referenceMissing: referenceMissing, reasonMissing: reasonMissing));
      return;
    }

    // A retry after a lost answer sends the same key and tap: the server answers a booked key first.
    final DateTime? validUntil = _presentmentValidUntil;
    if (!_unanswered && (_presentmentId == null || validUntil == null || _clock().isAfter(validUntil))) {
      _presentmentId = null;
      _set(const ReloadTapCard(again: true));
      // The screen was closed meanwhile (signed out, blocked): nothing is booked that no one sees.
      if (await _present(again: true, expected: details.card) == null || _disposed) return;
    }

    _set(details.copyWith(submitting: true));
    final PaymentInput payment = PaymentInput(method: method, reference: reference.trim(), reason: reason.trim());
    final PresentedVoucher? voucher = details.card.voucher;
    try {
      final ReloadDone done = voucher == null
          // A new card: the card sale of S20 with this tap (server rules, limits, idempotency and audit of a sale).
          ? ReloadDone.sold(
              await _api.sell(
                value: details.amount.cents,
                payment: payment,
                idempotencyKey: _idempotencyKey,
                cardPresentmentId: _presentmentId!,
              ),
              details.card.cardNumber,
            )
          : ReloadDone.toppedUp(
              await _api.reload(
                voucherId: voucher.id,
                amount: details.amount.cents,
                payment: payment,
                presentmentId: _presentmentId!,
                idempotencyKey: _idempotencyKey,
              ),
            );
      _definitive();
      _set(done);
    } on ApiRejected catch (e) {
      if (_disposed) return;
      final ReloadDetails back = details.copyWith(submitting: false);
      if (_unanswered && !_reloadCodes.contains(e.code)) {
        if (e.status != 403) _session.handleFailure(e, SessionContext.lookup);
        _set(ReloadProblem(ReloadProblemKind.uncertain, details: back, requestId: e.requestId));
        return;
      }
      final bool forbidden = e.status == 403;
      if (!forbidden && _session.handleFailure(e, SessionContext.lookup)) {
        _definitive();
        return;
      }
      if (e.code == 'IDEMPOTENCY_CONFLICT') {
        _set(ReloadProblem(ReloadProblemKind.uncertain, details: back, requestId: e.requestId));
        return;
      }
      _definitive(); // nothing was booked
      if (forbidden && voucher == null) {
        _set(ReloadProblem(ReloadProblemKind.cannotSell, details: back, requestId: e.requestId));
      } else if (forbidden || e.code == 'RELOAD_NOT_ALLOWED' || e.code == 'COMPLIMENTARY_NOT_ALLOWED') {
        _set(ReloadProblem(ReloadProblemKind.notAllowed, details: back, requestId: e.requestId));
      } else if (voucher == null && (e.code == 'INVALID_AMOUNT' || e.code == 'BALANCE_LIMIT_EXCEEDED')) {
        _set(
          ReloadAmount(
            card: details.card,
            amount: details.amount,
            min: e.contextInt('min') ?? _settings?.minVoucherValue ?? 1,
            max: e.contextInt('max') ?? _settings?.maxVoucherBalance ?? details.amount.cents,
          ),
        );
      } else if (voucher != null && e.code == 'BALANCE_LIMIT_EXCEEDED') {
        final int? max = e.contextInt('max_voucher_balance');
        final int balance = e.contextInt('balance') ?? voucher.balance;
        _set(
          ReloadAmount(
            card: details.card,
            amount: details.amount,
            max: max == null ? 0 : (max - balance).clamp(0, max),
          ),
        );
      } else if (e.code == 'PRESENTMENT_INVALID' && e.contextString('reason') == 'expired') {
        // Too slow for the tap: confirm with the card once more.
        _set(back);
        await submit();
      } else if (e.code == 'PRESENTMENT_INVALID' || _voucherCodes.contains(e.code)) {
        _set(
          ReloadProblem(
            ReloadProblemKind.card,
            details: back,
            requestId: e.requestId,
            // The reason (`card_not_active`, `card_state`) picks the message.
            card: CardPresentException(
              CardPresentFailure.notUsable,
              cardState: e.contextString('reason'),
              requestId: e.requestId,
              api: e,
            ),
          ),
        );
      } else if (e.code == 'VALIDATION_FAILED' && e.fieldErrors.isNotEmpty) {
        final Iterable<String> fields = e.fieldErrors.keys;
        _set(
          back.copyWith(
            referenceMissing: fields.contains('payment.reference'),
            reasonMissing: fields.contains('payment.reason'),
          ),
        );
      } else {
        _set(ReloadProblem(ReloadProblemKind.failed, details: back, requestId: e.requestId));
      }
    } on ApiUnauthorized catch (e) {
      _session.handleFailure(e, SessionContext.lookup);
      if (_disposed) return;
      final ReloadDetails back = details.copyWith(submitting: false);
      _set(_unanswered ? ReloadProblem(ReloadProblemKind.uncertain, details: back, requestId: e.requestId) : back);
    } on ApiFailure catch (e) {
      // Timeout, no connection or 5xx: it may have been booked. The same key makes "Try again" safe.
      _unanswered = true;
      if (!_disposed) {
        _set(
          ReloadProblem(
            ReloadProblemKind.uncertain,
            details: details.copyWith(submitting: false),
            requestId: e.requestId,
          ),
        );
      }
    }
  }

  /// The server answered for the current key: the next top-up gets a new key and a new tap.
  void _definitive() {
    _unanswered = false;
    _idempotencyKey = _uuid.v4();
    _presentmentId = null;
    _presentmentValidUntil = null;
  }

  /// Back from a definitive problem: to the entry, or (the first tap failed) to the tap.
  void back() {
    final ReloadState s = _state;
    if (s is! ReloadProblem || s.kind == ReloadProblemKind.uncertain) return;
    final ReloadDetails? d = s.details;
    _set(d ?? const ReloadTapCard());
  }

  /// "Top up another card".
  void startOver() {
    if (_unanswered) return;
    reference = '';
    reason = '';
    _lastDetails = null;
    _definitive();
    _set(const ReloadTapCard());
  }

  /// Leaving while the reader waits stops it.
  Future<void> cancelTap() async {
    if (_state is ReloadTapCard) await _cards.cancel();
  }

  void _set(ReloadState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
