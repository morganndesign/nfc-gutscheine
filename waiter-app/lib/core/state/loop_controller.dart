import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart';

import '../api/api_failure.dart';
import '../api/models.dart';
import '../api/waiter_api.dart';
import '../cards/ntag424_session.dart';
import '../diagnostics/diagnostic_log.dart';
import '../format/amount_entry.dart';
import '../format/support_code.dart';
import '../platform/connectivity_service.dart';
import '../platform/feedback_service.dart';
import '../platform/nfc_relay.dart';
import '../storage/pending_redemptions.dart';
import '../storage/recent_store.dart';
import '../tokens/tokens.dart';
import 'clock.dart';
import 'loop_state.dart';
import 'session_controller.dart';
import 'session_state.dart';

/// An earlier, unconfirmed redemption whose outcome became known while the
/// waiter was elsewhere (shown once on S05).
@immutable
class PendingResolution {
  const PendingResolution({required this.booked, required this.amount, required this.currency});

  final bool booked;
  final int amount;
  final String currency;
}

/// The one explicit state holder of the redeem loop: Ready → QR scan →
/// Presenting → Charge → Redeeming → Success, with Problem.
///
/// Money safety rules:
/// - every redemption attempt is stored with its `Idempotency-Key` before the
///   first request leaves the phone ([PendingRedemptionStore]), and every
///   retry reuses that key;
/// - "nothing was booked" is only said after a definitive answer to that key;
/// - while an attempt is unresolved, its voucher accepts no other amount: it is
///   resolved first by asking the server for the key's outcome, never by
///   sending the debit again.
class LoopController extends ChangeNotifier {
  LoopController({
    required SessionController session,
    required WaiterApi api,
    required FeedbackService feedback,
    required RecentStore recent,
    required PendingRedemptionStore pending,
    required ConnectivityService connectivity,
    required MonotonicClock clock,
    NfcRelay nfc = const PlatformNfcRelay(),
    DiagnosticLog? log,
  }) : _session = session,
       _nfc = nfc,
       _api = api,
       _feedback = feedback,
       _recent = recent,
       _pending = pending,
       _connectivity = connectivity,
       _clock = clock,
       _log = log {
    _sessionSubscription = _session.signals.listen(_onSessionSignal);
    _connectivity.addListener(_onConnectivity);
    _session.addListener(_onSessionChanged);
  }

  /// "Still checking …" after this long.
  static const Duration presentSlowAfter = Duration(seconds: 3);

  /// S09 → S05 without a tap, measured from the response.
  static const Duration successReturn = Duration(milliseconds: 4520);

  /// Same with a screen reader running.
  static const Duration successReturnScreenReader = Duration(milliseconds: 10520);
  static const Duration uncertainCap = Duration(seconds: 20);
  static const List<Duration> retryWaits = <Duration>[Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];

  /// The presentment is not used in its last seconds: the redemption request
  /// must reach the server while it is still valid.
  static const Duration presentmentMargin = Duration(seconds: 3);

  /// How often unresolved attempts are asked about while S05 is shown.
  static const Duration resolveInterval = Duration(seconds: 20);

  /// Amounts from this value on need the 600 ms hold.
  static const int holdThreshold = 10000;

  final SessionController _session;
  final WaiterApi _api;
  final FeedbackService _feedback;
  final RecentStore _recent;
  final PendingRedemptionStore _pending;
  final ConnectivityService _connectivity;
  final MonotonicClock _clock;
  final NfcRelay _nfc;
  final DiagnosticLog? _log;

  /// The open card session (S11), closed when the card was checked or the waiter left.
  CardLink? _card;

  /// Texts of the iPhone card sheet, set by the screen that opens S11 (UI language).
  ({String prompt, String checking, String done, String failed}) _cardTexts = (
    prompt: 'Hold the card to the top of the phone.',
    checking: 'Checking the card …',
    done: 'Card checked',
    failed: 'The card could not be checked.',
  );

  late final StreamSubscription<SessionSignal> _sessionSubscription;

  LoopState _state = const ReadyState();
  LoopState get state => _state;

  bool get isOnline => _connectivity.isOnline;

  /// Whether this phone can read cards now (S05 offers "Tap card" only then).
  Future<NfcAvailability> cardReaderAvailability() => _nfc.availability();

  /// Keep the screen on: everywhere except the camera.
  bool get wantsKeepAwake => switch (_state) {
    QrScanState() => false,
    PresentingState(:final PresentOrigin origin) => origin != PresentOrigin.qr,
    _ => true,
  };

  /// Monotonic "now" for countdown rendering.
  Duration now() => _clock.now();

  /// The unresolved attempts of the signed-in user.
  List<PendingRedemption> get pendingRedemptions => _pending.entries;

  int _generation = 0;
  Timer? _slowTimer;
  Timer? _successTimer;
  Timer? _countdownTimer;
  Timer? _presentmentTimer;
  Timer? _recheckTimer;
  Timer? _resolveTimer;
  CancelToken? _inFlight;
  Completer<void>? _retryWait;
  Duration? _tapAt;
  bool _retryOnReconnect = false;
  bool _resolvingInBackground = false;

  /// Voucher and amount kept across "Scan again" when the presentment ran out.
  (String, AmountEntry)? _carry;

  final List<PendingResolution> _resolutions = <PendingResolution>[];
  bool _uncertainCancelled = false;

  /// True once after "Cancel" in the final uncertain state (S05 snackbar).
  bool takeUncertainCancelled() {
    final bool value = _uncertainCancelled;
    _uncertainCancelled = false;
    return value;
  }

  /// Outcomes of earlier unconfirmed redemptions, shown once on S05.
  List<PendingResolution> takeResolutions() {
    final List<PendingResolution> taken = List<PendingResolution>.of(_resolutions);
    _resolutions.clear();
    return taken;
  }

  // ------------------------------------------------------------------- scan

  /// S05 "Scan voucher", S09 "Scan next voucher", S10 "Scan again".
  void openQr() {
    switch (_state) {
      case ReadyState() || ProblemState():
        break;
      case SuccessState():
        _successTimer?.cancel();
      case QrScanState() || PresentingState() || ChargeState() || CardTapState():
        return;
    }
    _cancelTimers();
    _go(const QrScanState());
  }

  /// S12: a QR code was decoded. Returns false when it is not a voucher QR
  /// (shown inline on S12, `haptic.warning`, no request).
  bool qrDetected(String raw) {
    if (_state is! QrScanState) return false;
    final String credential = raw.trim();
    if (!voucherQrPattern.hasMatch(credential)) {
      _feedback.haptic(HapticToken.warning);
      return false;
    }
    _feedback.both(HapticToken.cardDetected, SoundToken.cardDetected);
    unawaited(_present(credential));
    return true;
  }

  Future<void> _present(String credential) async {
    _cancelTimers();
    final PresentOrigin origin = _state is ProblemState ? PresentOrigin.problem : PresentOrigin.qr;
    final int generation = ++_generation;
    _go(
      PresentingState(
        credential: credential,
        origin: origin,
        problem: _state is ProblemState ? _state as ProblemState : null,
      ),
    );
    _slowTimer = _clock.timer(presentSlowAfter, () {
      if (_generation == generation && _state is PresentingState) _go((_state as PresentingState).markSlow());
    });

    final CancelToken token = CancelToken();
    _inFlight = token;
    try {
      final Presentment presentment = await _api.presentQr(credential, cancelToken: token);
      if (_generation != generation) return;
      _enterCharge(presentment);
    } on ApiCancelled {
      return;
    } on ApiFailure catch (e) {
      if (_generation != generation) return;
      _presentFailed(credential, e);
    } finally {
      if (identical(_inFlight, token)) _inFlight = null;
      _slowTimer?.cancel();
    }
  }

  void _presentFailed(String credential, ApiFailure failure) {
    _carry = null;
    if (_session.handleFailure(failure, SessionContext.lookup)) {
      _go(const ReadyState());
      return;
    }
    final String support = SupportCode.fromRequestId(failure.requestId);
    final String requestId = failure.requestId;
    switch (failure) {
      case ApiRejected(:final int status, :final Duration? retryAfter) when status == 429:
        final Duration until = _clock.now() + (retryAfter ?? const Duration(seconds: 60));
        _go(ProblemState(kind: ProblemKind.throttled, until: until));
        _countdownTimer = _clock.timer(until - _clock.now(), () {
          _feedback.haptic(HapticToken.select);
          notifyListeners();
        });
      case ApiRejected(:final int status) when status < 500:
        // Unknown, revoked or foreign code, or a medium this till cannot take.
        _go(ProblemState(kind: ProblemKind.notRecognized, supportCode: support, requestId: requestId));
      case ApiRejected() || ApiServerFault():
        _go(ProblemState(kind: ProblemKind.server, retry: credential, supportCode: support, requestId: requestId));
      case ApiTransportFailure():
        _go(ProblemState(kind: ProblemKind.network, retry: credential));
      case ApiUnauthorized() || ApiCancelled():
        _go(const ReadyState());
    }
  }

  /// S10 "Try again": the same QR text again (a new presentment), or the card held to the phone again.
  void retryPresent() {
    if (_state case ProblemState(:final String? retry) when retry != null) {
      unawaited(_present(retry));
    } else if (_state case ProblemState(retryCard: true)) {
      openCardTap();
    }
  }

  // ------------------------------------------------------------------- card

  /// S05 "Tap card", S09 / S10 again: a physical card, held to the phone (S11). [texts] are shown on the
  /// iPhone's system sheet.
  void openCardTap({({String prompt, String checking, String done, String failed})? texts}) {
    switch (_state) {
      case ReadyState() || ProblemState():
        break;
      case SuccessState():
        _successTimer?.cancel();
      case QrScanState() || PresentingState() || ChargeState() || CardTapState():
        return;
    }
    if (texts != null) _cardTexts = texts;
    _cancelTimers();
    _carry = null;
    _go(const CardTapState());
    unawaited(_tapCard(++_generation));
  }

  /// Reads the card, lets the server challenge it through the phone, and opens S07 with the presentment. The
  /// phone relays bytes; it never holds a key.
  Future<void> _tapCard(int generation) async {
    CardLink? card;
    try {
      card = await _nfc.start(prompt: _cardTexts.prompt);
      if (_generation != generation) {
        await card.close();
        return;
      }
      _card = card;
      _feedback.both(HapticToken.cardDetected, SoundToken.cardDetected);
      _go(const CardTapState(phase: CardTapPhase.checking));
      _slowTimer = _clock.timer(presentSlowAfter, () {
        if (_generation == generation && _state is CardTapState) _go((_state as CardTapState).copyWith(slow: true));
      });

      final CardTap tap = await Ntag424Session.read(card);
      final CancelToken token = CancelToken();
      _inFlight = token;
      final CardChallenge challenge = await _api.beginCardPresentment(tap, cancelToken: token);
      if (_generation != generation) return;
      final String answer = await Ntag424Session.answer(card, challenge.commandHex);
      final Presentment presentment = await _api.completeCardPresentment(challenge.authentication, answer, cancelToken: token);
      if (_generation != generation) return;
      await card.close(message: _cardTexts.done);
      _enterCharge(presentment);
    } on NfcRelayException catch (e) {
      if (_generation != generation) return;
      await card?.close(message: _cardTexts.failed, failed: true);
      _cardFailed(switch (e.failure) {
        NfcFailure.cancelled || NfcFailure.timeout || NfcFailure.busy => null,
        NfcFailure.disabled => const ProblemState(kind: ProblemKind.nfcOff, retryCard: true),
        NfcFailure.unsupported => const ProblemState(kind: ProblemKind.nfcUnsupported),
        NfcFailure.tagLost || NfcFailure.io => const ProblemState(kind: ProblemKind.cardMoved, retryCard: true),
      });
    } on CardProtocolException catch (e) {
      // Not a card of this system (or not personalised): it answered the fixed commands differently.
      _log?.record('card.protocol', e.step);
      if (_generation != generation) return;
      await card?.close(message: _cardTexts.failed, failed: true);
      _cardFailed(const ProblemState(kind: ProblemKind.cardNotRecognized));
    } on ApiCancelled {
      await card?.close();
    } on ApiFailure catch (e) {
      if (_generation != generation) return;
      await card?.close(message: _cardTexts.failed, failed: true);
      _cardApiFailed(e);
    } finally {
      if (identical(_card, card)) _card = null;
      _slowTimer?.cancel();
    }
  }

  void _cardFailed(ProblemState? problem) {
    // S10 plays its family's feedback.
    _go(problem ?? const ReadyState());
  }

  void _cardApiFailed(ApiFailure failure) {
    if (_session.handleFailure(failure, SessionContext.lookup)) {
      _go(const ReadyState());
      return;
    }
    final String support = SupportCode.fromRequestId(failure.requestId);
    final String requestId = failure.requestId;
    switch (failure) {
      case ApiRejected(:final int status, :final Duration? retryAfter) when status == 429:
        final Duration until = _clock.now() + (retryAfter ?? const Duration(seconds: 60));
        _go(ProblemState(kind: ProblemKind.throttled, until: until));
        _countdownTimer = _clock.timer(until - _clock.now(), () {
          _feedback.haptic(HapticToken.select);
          notifyListeners();
        });
      case ApiRejected(code: 'CARD_NOT_USABLE'):
        _go(ProblemState(
          kind: ProblemKind.cardNotUsable,
          cardState: failure.contextString('state') ?? failure.contextString('reason'),
          supportCode: support,
          requestId: requestId,
        ));
      case ApiRejected(:final int status) when status < 500:
        // Not a card of this restaurant, a copied tap, or a chip without the card's keys.
        _go(ProblemState(kind: ProblemKind.cardNotRecognized, supportCode: support, requestId: requestId));
      case ApiRejected() || ApiServerFault():
        _go(ProblemState(kind: ProblemKind.server, retryCard: true, supportCode: support, requestId: requestId));
      case ApiTransportFailure():
        _go(const ProblemState(kind: ProblemKind.network, retryCard: true));
      case ApiUnauthorized() || ApiCancelled():
        _go(const ReadyState());
    }
  }

  /// S10 "Scan again".
  void scanAgain() {
    if (_state case ProblemState(kind: ProblemKind.throttled, :final Duration? until)
        when until != null && _clock.now() < until) {
      return;
    }
    openQr();
  }

  // ---------------------------------------------------------------- charge

  void _enterCharge(Presentment presentment) {
    final PresentedVoucher voucher = presentment.voucher;
    final (String, AmountEntry)? carry = _carry;
    _carry = null;
    final bool fullOnly = !voucher.allowPartialRedemption;
    final Duration usable = presentment.expiresIn - presentmentMargin;
    final PendingRedemption? pending = _pending.forVoucher(voucher.id);
    final ChargeState next = ChargeState(
      voucher: voucher,
      presentmentId: presentment.id,
      presentmentDeadline: _clock.now() + (usable.isNegative ? Duration.zero : usable),
      entry: fullOnly
          ? AmountEntry.fromCents(voucher.balance)
          : (carry != null && carry.$1 == voucher.id ? carry.$2 : AmountEntry.empty),
      maxSingle: voucher.maxDebitPerTransaction ?? _session.user?.restaurant?.settings.maxDebitPerTransaction,
      phase: pending == null ? RedeemPhase.entering : RedeemPhase.resolving,
      pending: pending,
    );
    _go(next);
    _startPresentmentTimer(next.presentmentDeadline);
    if (pending != null) {
      unawaited(_resolveInCharge());
      return;
    }
    _conditionFeedback(next.condition);
  }

  void _conditionFeedback(VoucherCondition condition) {
    switch (condition) {
      case VoucherCondition.blocked:
        _feedback.both(HapticToken.error, SoundToken.error);
      case VoucherCondition.expired || VoucherCondition.empty:
        _feedback.both(HapticToken.warning, SoundToken.warning);
      case VoucherCondition.redeemable:
        break;
    }
  }

  void _startPresentmentTimer(Duration deadline) {
    _presentmentTimer?.cancel();
    _presentmentTimer = _clock.timer(deadline - _clock.now(), () {
      final ChargeState? s = _charge;
      if (s == null || s.presentmentExpired) return;
      // An attempt in flight is decided by the server, never by this timer.
      if (s.phase != RedeemPhase.entering && s.phase != RedeemPhase.resolving) return;
      if (s.phase == RedeemPhase.entering && s.condition == VoucherCondition.redeemable) {
        _feedback.haptic(HapticToken.warning);
      }
      _go(s.copyWith(presentmentExpired: true));
    });
  }

  ChargeState? get _charge => _state is ChargeState ? _state as ChargeState : null;

  /// Keypad digit (0–9), `00`, ⌫ and long-press clear.
  void key(int digit) => _edit((AmountEntry e) => e.digit(digit));

  void doubleZero() => _edit((AmountEntry e) => e.doubleZero());

  void backspace() => _edit((AmountEntry e) => e.backspace());

  void clearAmount() => _edit((AmountEntry e) => e.clear());

  void _edit(EntryChange<AmountEntry> Function(AmountEntry entry) change) {
    final ChargeState? s = _charge;
    if (s == null || s.isLocked || s.fullOnly || s.condition != VoucherCondition.redeemable) return;
    final EntryChange<AmountEntry> result = change(s.entry);
    switch (result.outcome) {
      case EntryOutcome.ignored || EntryOutcome.pasteRejected || EntryOutcome.rejectedAtLimit:
        return;
      case EntryOutcome.cleared || EntryOutcome.accepted || EntryOutcome.deleted:
        _setAmount(s, result.value);
    }
  }

  void _setAmount(ChargeState s, AmountEntry entry) {
    _go(
      s.copyWith(
        entry: entry,
        clearNotice: s.notice is! VelocityNotice && s.notice is! RateLimitNotice,
        clearSupportCode: true,
      ),
    );
  }

  /// `QuickAmountChip` "Use balance" / "Use maximum".
  void useAmount(int cents) {
    final ChargeState? s = _charge;
    if (s == null || s.isLocked || s.fullOnly) return;
    _setAmount(s, AmountEntry.fromCents(cents));
  }

  /// True while a rate or velocity countdown blocks Redeem.
  bool redeemBlockedByCountdown(ChargeState s) => switch (s.notice) {
    RateLimitNotice(:final Duration until) => _clock.now() < until,
    // Without a known time Redeem stays enabled.
    VelocityNotice(:final Duration? until) => until != null && _clock.now() < until,
    _ => false,
  };

  /// Guards for REDEEM_TAP / HOLD_COMPLETE.
  bool canRedeem(ChargeState s) =>
      s.phase == RedeemPhase.entering &&
      s.condition == VoucherCondition.redeemable &&
      !s.presentmentExpired &&
      _clock.now() < s.presentmentDeadline &&
      s.amount > 0 &&
      !s.isOverBalance &&
      !s.isOverMax &&
      (!s.fullOnly || s.amount == s.voucher.balance) &&
      _connectivity.isOnline &&
      !redeemBlockedByCountdown(s);

  /// Warms up the success haptic when the button is pressed.
  void prepareRedeem() => _feedback.prepare(HapticToken.success);

  /// REDEEM_TAP (< € 100) or HOLD_COMPLETE (≥ € 100).
  Future<void> redeem() async {
    final ChargeState? s = _charge;
    if (s == null) return;
    if (!canRedeem(s)) {
      if (!_connectivity.isOnline) _feedback.haptic(HapticToken.warning);
      return;
    }
    _tapAt = _clock.now();
    final int generation = ++_generation;
    _go(s.copyWith(phase: RedeemPhase.submitting, attempt: 0, clearNotice: true, clearSupportCode: true));
    // Stored before the request leaves the phone; without it nothing is sent.
    final PendingRedemption pending;
    try {
      pending = await _pending.open(
        voucherId: s.voucher.id,
        amount: s.amount,
        currency: s.voucher.currency,
        last4: s.voucher.last4,
        restaurantName: s.voucher.restaurantName,
      );
    } on Object catch (e) {
      _log?.record('redeem.store', '$e');
      if (_generation == generation) {
        _go(s.copyWith(phase: RedeemPhase.entering, notice: const ServerFaultNotice('')));
        _feedback.haptic(HapticToken.warning);
      }
      return;
    }
    if (_generation != generation) return;
    final ChargeState? current = _charge;
    if (current != null) _go(current.copyWith(pending: pending));
    await _runAttempts(generation, pending, first: true);
  }

  /// Uncertain final: "Check again" — the same key, the same presentment.
  Future<void> tryAgain() async {
    final ChargeState? s = _charge;
    final PendingRedemption? pending = s?.pending;
    if (s == null || pending == null || s.phase != RedeemPhase.uncertainFinal) return;
    _retryOnReconnect = false;
    _tapAt = _clock.now();
    _go(s.copyWith(phase: RedeemPhase.submitting, attempt: 0, clearSupportCode: true));
    await _runAttempts(++_generation, pending);
  }

  /// Uncertain final: "Cancel" — back to S05. The attempt stays stored and is
  /// resolved by asking the server; this voucher takes no other amount until
  /// then.
  void cancelUncertain() {
    final ChargeState? s = _charge;
    if (s == null || s.phase != RedeemPhase.uncertainFinal) return;
    _retryOnReconnect = false;
    _feedback.haptic(HapticToken.select);
    _cancelTimers();
    _uncertainCancelled = true;
    _go(const ReadyState());
  }

  /// Codes only the redemption answers with, after it looked the key up: a
  /// booked key is always replayed, so these prove that it was not booked.
  static const Set<String> _redemptionCodes = <String>{
    'PRESENTMENT_INVALID',
    'INSUFFICIENT_BALANCE',
    'VOUCHER_BLOCKED',
    'VOUCHER_EXPIRED',
    'VOUCHER_NOT_REDEEMABLE',
    'INVALID_VOUCHER_STATE',
    'DEBIT_LIMIT_EXCEEDED',
    'VELOCITY_LIMIT_EXCEEDED',
    'INVALID_AMOUNT',
  };

  Future<void> _runAttempts(int generation, PendingRedemption pending, {bool first = false}) async {
    int retries = 0;
    bool slowRetryUsed = false;
    PendingRedemption attempt = pending;
    bool sendRecorded = first;
    // Whether an earlier request of this attempt went unanswered: then only an
    // answer from the redemption itself decides, not one from the gateway
    // (sign-in, permission or rate limit are checked before the key).
    bool unanswered = !first;

    while (_generation == generation) {
      final ChargeState? s = _charge;
      if (s == null) return;
      if (!sendRecorded) attempt = await _pending.resend(attempt);
      sendRecorded = false;
      if (_generation != generation) return;

      final CancelToken token = CancelToken();
      _inFlight = token;
      try {
        final RedeemResult result = await _api.redeem(
          voucherId: attempt.voucherId,
          amount: attempt.amount,
          presentmentId: s.presentmentId,
          idempotencyKey: attempt.key,
          cancelToken: token,
        );
        if (_generation != generation) return;
        await _pending.resolve(attempt);
        await _redeemSucceeded(result);
        return;
      } on ApiCancelled {
        return;
      } on ApiUnauthorized catch (e) {
        if (_generation != generation) return;
        _session.handleFailure(e, SessionContext.redeem);
        final ChargeState? current = _charge;
        if (unanswered) {
          // An earlier request may have been booked: resolved after signing in.
          if (current != null) _toUncertainFinal(current, e.requestId);
          return;
        }
        // Refused before it was handled: nothing was booked with this key.
        await _pending.resolve(attempt);
        if (current != null) _go(current.copyWith(phase: RedeemPhase.entering, clearPending: true));
        return;
      } on ApiRejected catch (e) {
        if (_generation != generation) return;
        if (unanswered && e.code != 'IDEMPOTENCY_CONFLICT' && !_redemptionCodes.contains(e.code)) {
          // Not an answer of the redemption itself (sign-in, permission, rate
          // limit, a gateway or an unknown code): says nothing about the
          // unanswered request. The attempt stays stored.
          if (_session.handleFailure(e, SessionContext.redeem)) {
            _go(const ReadyState());
            return;
          }
          final ChargeState? current = _charge;
          if (current != null) _toUncertainFinal(current, e.requestId);
          return;
        }
        if (e.code == 'IDEMPOTENCY_CONFLICT') {
          // The key is already booked, with another amount: never answered
          // by a new key. Ask what was booked and show it.
          final ChargeState? current = _charge;
          if (current != null) {
            _go(current.copyWith(phase: RedeemPhase.resolving, pending: attempt, checking: false));
            unawaited(_resolveInCharge());
          }
          return;
        }
        // A definitive answer to this key: the server looks the key up before
        // and after taking its locks, so a booked attempt is always replayed.
        await _pending.resolve(attempt);
        if (_session.handleFailure(e, SessionContext.redeem)) {
          _go(const ReadyState());
          return;
        }
        _redeemRejected(e);
        return;
      } on ApiFailure catch (e) {
        if (_generation != generation) return;
        final ChargeState? current = _charge;
        if (current == null) return;
        unanswered = true;

        // First attempt unanswered after 8 s: "Connection slow", re-sent at once.
        if (e is ApiTransportFailure && e.timedOut && current.phase == RedeemPhase.submitting && !slowRetryUsed) {
          slowRetryUsed = true;
          _go(current.copyWith(phase: RedeemPhase.slow));
          continue;
        }

        final Duration elapsed = _clock.now() - (_tapAt ?? _clock.now());
        if (current.phase != RedeemPhase.uncertainAuto) _feedback.haptic(HapticToken.warning);
        if (retries >= retryWaits.length || elapsed >= uncertainCap) {
          _toUncertainFinal(current, e.requestId);
          return;
        }

        final Duration wait = retryWaits[retries];
        if (elapsed + wait >= uncertainCap) {
          _go(current.copyWith(phase: RedeemPhase.uncertainAuto, attempt: retries + 1));
          await _waitForRetry(uncertainCap - elapsed);
          if (_generation != generation) return;
          final ChargeState? latest = _charge;
          if (latest != null) _toUncertainFinal(latest, e.requestId);
          return;
        }

        retries++;
        _go(current.copyWith(phase: RedeemPhase.uncertainAuto, attempt: retries));
        await _waitForRetry(wait);
      } finally {
        if (identical(_inFlight, token)) _inFlight = null;
      }
    }
  }

  void _toUncertainFinal(ChargeState s, String requestId) {
    _feedback.haptic(HapticToken.warning);
    _retryOnReconnect = !_connectivity.isOnline;
    _go(
      s.copyWith(
        phase: RedeemPhase.uncertainFinal,
        supportCode: SupportCode.fromRequestId(requestId),
        requestId: requestId,
      ),
    );
  }

  /// Waits [duration]; a connectivity-restored event skips the wait.
  Future<void> _waitForRetry(Duration duration) {
    final Completer<void> done = Completer<void>();
    _retryWait = done;
    final Timer timer = _clock.timer(duration, () {
      if (!done.isCompleted) done.complete();
    });
    return done.future.whenComplete(() {
      timer.cancel();
      if (identical(_retryWait, done)) _retryWait = null;
    });
  }

  Future<void> _redeemSucceeded(RedeemResult result) async {
    final ChargeState? s = _charge;
    if (s == null) return;
    final PresentedVoucher voucher = s.voucher.copyWith(balance: result.transaction.balanceAfter);
    final RecentEntry entry = _recentEntry(voucher, result.transaction, result.requestId);
    _presentmentTimer?.cancel();
    _feedback.both(HapticToken.success, SoundToken.success);
    _successAt = _clock.now();
    _successTotal = successReturn;
    _go(SuccessState(entry: entry, voucher: voucher));
    _log?.record('redeem.ok', result.replayed ? 'replayed' : 'created');
    _startSuccessTimer();
    await _recent.add(entry);
  }

  RecentEntry _recentEntry(PresentedVoucher voucher, RedeemedTransaction tx, String requestId) => RecentEntry(
    transactionId: tx.id,
    createdAt: tx.createdAt,
    last4: voucher.last4,
    amount: tx.amount,
    balanceAfter: tx.balanceAfter,
    currency: voucher.currency,
    restaurantName: voucher.restaurantName,
    businessDay: _session.businessDayKey(tx.createdAt),
    requestId: requestId,
  );

  void _redeemRejected(ApiRejected e) {
    final ChargeState? s = _charge;
    if (s == null) return;
    ChargeState next = s.copyWith(phase: RedeemPhase.entering, clearPending: true, clearSupportCode: true);
    bool error = true;
    bool sound = true;

    switch (e.code) {
      case 'PRESENTMENT_INVALID':
        // Ran out, or refused: scan again. Nothing was booked with this key.
        next = next.copyWith(presentmentExpired: true, notice: const NothingBookedNotice());
        error = false;
      case 'INSUFFICIENT_BALANCE':
        final int balance = e.contextInt('balance') ?? s.voucher.balance;
        next = next.copyWith(voucher: s.voucher.copyWith(balance: balance), notice: BalanceChangedNotice(balance));
      case 'VOUCHER_BLOCKED':
        next = next.copyWith(
          voucher: s.voucher.copyWith(status: VoucherStatus.blocked),
          notice: const NothingBookedNotice(),
        );
      case 'VOUCHER_EXPIRED':
        next = next.copyWith(voucher: s.voucher.copyWith(isExpired: true), notice: const NothingBookedNotice());
      case 'VOUCHER_NOT_REDEEMABLE' || 'INVALID_VOUCHER_STATE':
        final VoucherStatus? status = VoucherStatus.values.asNameMap()[e.contextString('status')];
        next = next.copyWith(
          voucher: status == null ? s.voucher.copyWith(balance: 0) : s.voucher.copyWith(status: status),
          notice: const NothingBookedNotice(),
        );
      case 'DEBIT_LIMIT_EXCEEDED':
        final int? max = e.contextInt('max');
        if (e.contextString('limit') == 'per_voucher_per_day') {
          next = next.copyWith(notice: DailyLimitNotice(e.contextInt('remaining') ?? 0));
        } else if (max != null) {
          next = next.copyWith(maxSingle: max, notice: MaxSingleNotice(max));
        } else {
          next = next.copyWith(notice: const NothingBookedNotice());
        }
      case 'INVALID_AMOUNT':
        final int? balance = e.contextInt('balance');
        if (balance != null) {
          next = next.copyWith(
            voucher: s.voucher.copyWith(balance: balance, allowPartialRedemption: false),
            entry: AmountEntry.fromCents(balance),
            notice: const FullOnlyNotice(),
          );
          error = false;
          sound = false;
        } else {
          next = next.copyWith(
            notice: ServerFaultNotice(SupportCode.fromRequestId(e.requestId), requestId: e.requestId),
          );
          error = false;
          sound = false;
        }
      case 'VELOCITY_LIMIT_EXCEEDED':
        next = next.copyWith(
          notice: VelocityNotice(until: e.retryAfter == null ? null : _clock.now() + e.retryAfter!),
        );
        error = false;
        _scheduleCountdown(e.retryAfter);
      default:
        if (e.status == 429) {
          final Duration wait = e.retryAfter ?? const Duration(seconds: 60);
          next = next.copyWith(notice: RateLimitNotice(_clock.now() + wait));
          error = false;
          _scheduleCountdown(wait);
        } else {
          next = next.copyWith(
            notice: ServerFaultNotice(SupportCode.fromRequestId(e.requestId), requestId: e.requestId),
          );
          error = false;
          sound = false;
        }
    }

    _go(next);
    if (error) {
      _feedback.both(HapticToken.error, SoundToken.error);
    } else if (sound) {
      _feedback.both(HapticToken.warning, SoundToken.warning);
    } else {
      _feedback.haptic(HapticToken.warning);
    }
  }

  void _scheduleCountdown(Duration? wait) {
    _countdownTimer?.cancel();
    if (wait == null) return;
    _countdownTimer = _clock.timer(wait, notifyListeners);
  }

  /// "Scan again" on S07 once the presentment ran out: the amount is kept for
  /// the same voucher.
  void rescan() {
    final ChargeState? s = _charge;
    if (s == null || s.phase == RedeemPhase.submitting || s.phase == RedeemPhase.slow || s.isUncertain) return;
    _carry = (s.voucher.id, s.entry);
    _cancelTimers();
    _go(const QrScanState());
  }

  /// ✕ / Back on S07: no confirmation. An unresolved attempt stays stored.
  void closeCharge() {
    final ChargeState? s = _charge;
    if (s == null) return;
    if (s.phase != RedeemPhase.entering && s.phase != RedeemPhase.resolving) return;
    _generation++;
    _cancelTimers();
    _go(const ReadyState());
  }

  // ------------------------------------------------------------- resolving

  /// Resolving on S07: asks whether the earlier attempt on this voucher was
  /// booked. "Check again" calls this too.
  Future<void> _resolveInCharge() async {
    final ChargeState? s = _charge;
    final PendingRedemption? pending = s?.pending;
    if (s == null || pending == null || s.phase != RedeemPhase.resolving || s.checking) return;
    _recheckTimer?.cancel();
    final int generation = _generation;
    _go(s.copyWith(checking: true, clearSupportCode: true));
    try {
      final RedemptionOutcome outcome = await _api.redemptionOutcome(
        voucherId: pending.voucherId,
        idempotencyKey: pending.key,
      );
      if (_generation != generation) return;
      final ChargeState? current = _charge;
      if (current == null) return;
      switch (outcome) {
        case RedemptionBooked(:final PresentedVoucher voucher, :final RedeemedTransaction transaction, :final String requestId):
          await _pending.resolve(pending);
          await _recent.add(_recentEntry(voucher, transaction, requestId));
          _log?.record('redeem.resolved', 'booked');
          final ChargeState? latest = _charge;
          if (latest == null || _generation != generation) return;
          final ChargeState next = latest.copyWith(
            voucher: voucher,
            phase: RedeemPhase.entering,
            checking: false,
            clearPending: true,
            entry: voucher.allowPartialRedemption ? AmountEntry.empty : AmountEntry.fromCents(voucher.balance),
            notice: EarlierBookedNotice(transaction.amount),
          );
          _go(next);
          _feedback.both(HapticToken.warning, SoundToken.warning);
        case RedemptionNotBooked():
          if (_pending.notBookedIsFinal(pending)) {
            await _pending.resolve(pending);
            _log?.record('redeem.resolved', 'not booked');
            final ChargeState? latest = _charge;
            if (latest == null || _generation != generation) return;
            _go(latest.copyWith(phase: RedeemPhase.entering, checking: false, clearPending: true));
            _conditionFeedback(latest.condition);
          } else {
            // The attempt may still be running on the server: ask again once
            // it no longer can.
            _go(current.copyWith(checking: false));
            final Duration wait =
                PendingRedemptionStore.serverCeiling - _pending.now().difference(pending.lastSentAt);
            _recheckTimer = _clock.timer(wait.isNegative ? Duration.zero : wait, () => unawaited(_resolveInCharge()));
          }
      }
    } on ApiFailure catch (e) {
      if (_generation != generation) return;
      final ChargeState? current = _charge;
      if (current == null) return;
      if (_session.handleFailure(e, SessionContext.lookup)) {
        _go(const ReadyState());
        return;
      }
      _go(
        current.copyWith(
          checking: false,
          supportCode: e is ApiTransportFailure ? null : SupportCode.fromRequestId(e.requestId),
          requestId: e is ApiTransportFailure ? null : e.requestId,
        ),
      );
    }
  }

  /// S07 resolving: "Check again".
  void checkPending() => unawaited(_resolveInCharge());

  /// Asks about every unresolved attempt not on screen; outcomes are queued
  /// for S05 ([takeResolutions]).
  Future<void> resolvePending() async {
    if (_resolvingInBackground || !_connectivity.isOnline || _session.phase != AccessPhase.active) return;
    _resolvingInBackground = true;
    try {
      for (final PendingRedemption pending in _pending.entries) {
        if (_charge?.voucher.id == pending.voucherId) continue;
        final RedemptionOutcome outcome;
        try {
          outcome = await _api.redemptionOutcome(voucherId: pending.voucherId, idempotencyKey: pending.key);
        } on ApiFailure catch (e) {
          _session.handleFailure(e, SessionContext.lookup);
          return;
        }
        if (_charge?.voucher.id == pending.voucherId) continue;
        switch (outcome) {
          case RedemptionBooked(:final PresentedVoucher voucher, :final RedeemedTransaction transaction, :final String requestId):
            await _pending.resolve(pending);
            await _recent.add(_recentEntry(voucher, transaction, requestId));
            _resolutions.add(PendingResolution(booked: true, amount: transaction.amount, currency: voucher.currency));
          case RedemptionNotBooked() when _pending.notBookedIsFinal(pending):
            await _pending.resolve(pending);
            _resolutions.add(PendingResolution(booked: false, amount: pending.amount, currency: pending.currency));
          case RedemptionNotBooked():
            break;
        }
      }
    } finally {
      _resolvingInBackground = false;
      _scheduleResolve();
      notifyListeners();
    }
  }

  void _scheduleResolve() {
    _resolveTimer?.cancel();
    if (_pending.isEmpty) return;
    _resolveTimer = _clock.timer(resolveInterval, () => unawaited(resolvePending()));
  }

  // --------------------------------------------------------------- success

  Duration? _successAt;
  Duration _successTotal = successReturn;

  void _startSuccessTimer() {
    _successAt ??= _clock.now();
    _successTimer?.cancel();
    final Duration remaining = _successTotal - (_clock.now() - _successAt!);
    _successTimer = _clock.timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (_state case SuccessState(presenting: false)) _go(const ReadyState());
    });
  }

  /// S09 with a screen reader: the automatic return is extended to 10.52 s.
  void extendSuccessForScreenReader() {
    if (_state is! SuccessState || _successTotal == successReturnScreenReader) return;
    _successTotal = successReturnScreenReader;
    if (_state case SuccessState(presenting: false)) _startSuccessTimer();
  }

  /// Monotonic time the success response arrived (hairline progress).
  Duration? get successAt => _successAt;

  /// Total time S09 stays without a tap.
  Duration get successTotal => _successTotal;

  /// Any tap on S09 or the countdown ending.
  void finishSuccess() {
    if (_state is! SuccessState) return;
    _successTimer?.cancel();
    _go(const ReadyState());
  }

  /// "Show guest": presentation mode pauses the automatic return.
  void presentToGuest(bool presenting) {
    if (_state case SuccessState(:final RecentEntry entry, :final PresentedVoucher voucher)) {
      if (presenting) {
        _successTimer?.cancel();
      } else {
        _startSuccessTimer();
      }
      _go(SuccessState(entry: entry, voucher: voucher, presenting: presenting));
    }
  }

  // ---------------------------------------------------------------- closing

  /// ✕ on S10, S12 and Android back; returns false on S05 (the system then
  /// moves the app to the background). Ignored while money may be moving;
  /// Back in the final uncertain state = Cancel.
  bool back() {
    switch (_state) {
      case ReadyState():
        return false;
      case ChargeState(:final RedeemPhase phase):
        switch (phase) {
          case RedeemPhase.uncertainFinal:
            cancelUncertain();
          case RedeemPhase.entering || RedeemPhase.resolving:
            closeCharge();
          case RedeemPhase.submitting || RedeemPhase.slow || RedeemPhase.uncertainAuto:
            break;
        }
        return true;
      case SuccessState():
        finishSuccess();
        return true;
      case PresentingState(:final PresentOrigin origin, :final ProblemState? problem):
        // Cancel returns to the screen the scan came from.
        _generation++;
        _inFlight?.cancel();
        _slowTimer?.cancel();
        _go(origin == PresentOrigin.problem && problem != null ? problem : const QrScanState());
        return true;
      case CardTapState():
        // Leaving S11 ends the card session; an answer that arrives later is ignored.
        _generation++;
        _inFlight?.cancel();
        _slowTimer?.cancel();
        final CardLink? card = _card;
        _card = null;
        // No card yet: end the waiting session (Android reader mode, the iPhone sheet).
        unawaited(card != null ? card.close() : _nfc.cancel());
        _go(const ReadyState());
        return true;
      case QrScanState() || ProblemState():
        _carry = null;
        _cancelTimers();
        _go(const ReadyState());
        return true;
    }
  }

  // ------------------------------------------------------ session and network

  void _onSessionSignal(SessionSignal signal) {
    switch (signal) {
      case SessionSignal.signedOut || SessionSignal.contextDropped:
        _generation++;
        _inFlight?.cancel();
        _retryWait?.complete();
        _carry = null;
        _cancelTimers();
        _resolveTimer?.cancel();
        _go(const ReadyState());
      case SessionSignal.reauthenticated:
        notifyListeners();
    }
  }

  AccessPhase? _lastPhase;

  void _onSessionChanged() {
    final AccessPhase phase = _session.phase;
    if (phase != _lastPhase) {
      _lastPhase = phase;
      if (phase == AccessPhase.active) unawaited(resolvePending());
    }
    notifyListeners();
  }

  void _onConnectivity() {
    if (_connectivity.isOnline) {
      final Completer<void>? wait = _retryWait;
      if (wait != null && !wait.isCompleted) wait.complete();
      final ChargeState? s = _charge;
      if (_retryOnReconnect && s?.phase == RedeemPhase.uncertainFinal) {
        _retryOnReconnect = false;
        unawaited(tryAgain());
      }
      if (s != null && s.phase == RedeemPhase.resolving && !s.checking) unawaited(_resolveInCharge());
      unawaited(resolvePending());
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------ core

  void _cancelTimers() {
    _slowTimer?.cancel();
    _successTimer?.cancel();
    _countdownTimer?.cancel();
    _presentmentTimer?.cancel();
    _recheckTimer?.cancel();
  }

  void _go(LoopState next) {
    final LoopState previous = _state;
    _state = next;
    if (previous.name != next.name) _log?.record('state', next.name);
    if (next is ReadyState && previous is! ReadyState) {
      _session.readyShown();
      if (_pending.entries.isNotEmpty) unawaited(resolvePending());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelTimers();
    _resolveTimer?.cancel();
    _inFlight?.cancel();
    unawaited(_sessionSubscription.cancel());
    _connectivity.removeListener(_onConnectivity);
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
