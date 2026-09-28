import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart';

import '../api/api_failure.dart';
import '../api/card_link.dart';
import '../api/models.dart';
import '../api/waiter_api.dart';
import '../diagnostics/diagnostic_log.dart';
import '../format/amount_entry.dart';
import '../format/support_code.dart';
import '../platform/connectivity_service.dart';
import '../platform/feedback_service.dart';
import '../platform/nfc_service.dart';
import '../storage/recent_store.dart';
import '../storage/settings_store.dart';
import '../tokens/tokens.dart';
import 'clock.dart';
import 'loop_state.dart';
import 'redeem_attempts.dart';
import 'session_controller.dart';
import 'session_state.dart';

/// The one explicit state holder of the redeem loop (09 §4.1): Ready →
/// Scanning → LookingUp → Charge → Redeeming → Success, with Problem, QR and
/// manual entry. Implements the transitions and guards of 02 §4.5.4, the
/// redeem sub-machine of 09 §4.4 and the error surfaces of 03b §1.3 / 12 §3.
class LoopController extends ChangeNotifier {
  LoopController({
    required SessionController session,
    required WaiterApi api,
    required NfcService nfc,
    required FeedbackService feedback,
    required RecentStore recent,
    required ConnectivityService connectivity,
    required SettingsStore settings,
    required MonotonicClock clock,
    required List<String> cardDomains,
    required bool isIos,
    bool? allowHttpLinks,
    RedeemAttempts? attempts,
    DiagnosticLog? log,
  })  : _session = session,
        _api = api,
        _nfc = nfc,
        _feedback = feedback,
        _recent = recent,
        _connectivity = connectivity,
        _settings = settings,
        _clock = clock,
        _cardDomains = cardDomains,
        _allowHttpLinks = allowHttpLinks,
        _isIos = isIos,
        _attempts = attempts ?? RedeemAttempts(),
        _log = log {
    _sessionSubscription = _session.signals.listen(_onSessionSignal);
    _nfcSubscription = _nfc.events.listen(_onNfcEvent);
    _connectivity.addListener(_onConnectivity);
    _session.addListener(_onSessionChanged);
  }

  // Timings (04 A.6 time.*, 09 §4.4).
  static const Duration lookupSlowAfter = Duration(seconds: 3);
  /// S09 → S05 without a tap, measured from the response (AC-S09-3).
  static const Duration successReturn = Duration(milliseconds: 4520);

  /// Same with a screen reader running (03b §4, 10.52 s).
  static const Duration successReturnScreenReader = Duration(milliseconds: 10520);
  static const Duration uncertainCap = Duration(seconds: 20);
  static const List<Duration> retryWaits = <Duration>[Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];
  static const Duration duplicateReadWindow = Duration(seconds: 2);
  static const Duration readFailureWindow = Duration(seconds: 5);
  static const int readFailuresForHint = 3;
  static const Duration switchOfferLifetime = Duration(seconds: 6);

  /// Amounts from this value on need the 600 ms hold (brief §1).
  static const int holdThreshold = 10000;

  final SessionController _session;
  final WaiterApi _api;
  final NfcService _nfc;
  final FeedbackService _feedback;
  final RecentStore _recent;
  final ConnectivityService _connectivity;
  final SettingsStore _settings;
  final MonotonicClock _clock;
  List<String> _cardDomains;
  final bool? _allowHttpLinks;

  /// Hosts of card links; follows the environment when a development or
  /// staging build is pointed at another server.
  set cardDomains(List<String> value) => _cardDomains = value;
  final bool _isIos;
  final RedeemAttempts _attempts;
  final DiagnosticLog? _log;

  late final StreamSubscription<SessionSignal> _sessionSubscription;
  late final StreamSubscription<NfcEvent> _nfcSubscription;

  LoopState _state = const ReadyState();
  LoopState get state => _state;

  NfcAvailability _nfcAvailability = NfcAvailability.enabled;
  NfcAvailability get nfcAvailability => _nfcAvailability;

  bool _sheetOpen = false;

  /// Android reader mode must be on now (02 §4.5.2 "Reader mode" column).
  bool get wantsReaderMode {
    if (_isIos || _nfcAvailability != NfcAvailability.enabled || _sheetOpen) return false;
    if (_session.expired != null) return false;
    // 03a S17: a card tapped during the intro ends it and is looked up.
    if (_session.phase == AccessPhase.onboardingIntro) return _state is ReadyState;
    if (_session.phase != AccessPhase.active) return false;
    return switch (_state) {
      ReadyState() || LookingUpState() || ChargeState() || SuccessState() => true,
      ProblemState(:final Duration? until) => until == null || _clock.now() >= until,
      ScanningState() || QrScanState() || ManualEntryState() => false,
    };
  }

  bool get isOnline => _connectivity.isOnline;

  /// Keep the screen on (09 §7.7): S05, S07–S10 and sheets — not S11/S12.
  bool get wantsKeepAwake => switch (_state) {
        QrScanState() || ManualEntryState() => false,
        LookingUpState(:final LookupOrigin origin) => origin != LookupOrigin.manual && origin != LookupOrigin.qr,
        _ => true,
      };

  /// V8: no successful card read on this device since 04:00 (03a S05).
  bool get showFirstCardTip => _settings.firstReadDay != _session.businessDayKey();

  bool get isIos => _isIos;

  /// Monotonic "now" for countdown rendering.
  Duration now() => _clock.now();

  int _generation = 0;
  Timer? _slowTimer;
  Timer? _successTimer;
  Timer? _countdownTimer;
  Timer? _switchTimer;
  CancelToken? _inFlight;
  Completer<void>? _retryWait;
  Duration? _tapAt;
  bool _retryOnReconnect = false;
  String? _heldLink;

  String? _lastUid;
  Duration? _lastReadAt;
  final List<Duration> _readFailures = <Duration>[];

  // ------------------------------------------------------------------ setup

  Future<void> refreshNfcAvailability() async {
    _nfcAvailability = await _nfc.availability();
    notifyListeners();
  }

  void setSheetOpen(bool open) {
    if (_sheetOpen == open) return;
    _sheetOpen = open;
    notifyListeners();
  }

  // ------------------------------------------------------------------ ready

  void clearReadyNotice() {
    if (_state case ReadyState(:final ReadyNotice? notice) when notice != null) _go(const ReadyState());
  }

  /// iPhone: "Scan card" (S05), "Scan next card" (S09), "Scan again" (S10).
  /// [texts] are the localised `ios.sheet.*` strings.
  Future<void> startScan(IosSheetTexts texts) async {
    if (!_isIos) {
      _go(const ReadyState());
      return;
    }
    _cancelTimers();
    _go(const ScanningState());
    try {
      await _nfc.startSession(texts);
    } on Object {
      _go(const ReadyState());
      _feedback.haptic(HapticToken.warning);
      _scanUnavailable = true;
      notifyListeners();
    }
  }

  bool _scanUnavailable = false;

  /// P09: NFC temporarily unavailable — shown once as a snackbar on S05.
  bool takeScanUnavailable() {
    final bool value = _scanUnavailable;
    _scanUnavailable = false;
    return value;
  }

  void openQr() {
    if (_state is! ReadyState) return;
    _go(const QrScanState());
  }

  void openManual() {
    if (_state is ReadyState || _state is ProblemState || _state is QrScanState) _go(const ManualEntryState());
  }

  /// S12: a QR code was decoded. Returns false when it is not a gift card
  /// (L10 inline on S12, `haptic.warning`, no request).
  bool qrDetected(String raw) {
    if (_state is! QrScanState) return false;
    final CardLink? link = CardLink.parse(raw, _cardDomains, allowHttp: _allowHttpLinks);
    if (link == null) {
      _feedback.haptic(HapticToken.warning);
      return false;
    }
    _feedback.both(HapticToken.cardDetected, SoundToken.cardDetected);
    unawaited(_lookup(ScanRequest.qr(url: link.url, isSunSigned: link.isSunSigned)));
    return true;
  }

  /// S11: 16 digits submitted.
  void submitManual(String digits) {
    if (_state is! ManualEntryState || digits.length != 16) return;
    unawaited(_lookup(ScanRequest.manual(digits: digits)));
  }

  /// Universal link / App Link `https://<domain>/c/<token>` (method `link`).
  void openLink(String url) {
    final CardLink? link = CardLink.parse(url, _cardDomains, allowHttp: _allowHttpLinks);
    if (link == null) return;
    if (_session.phase != AccessPhase.active || _session.expired != null) {
      _session.keepLink(link.url);
      return;
    }
    if (_state case ChargeState(:final bool isLocked) when isLocked) {
      // 03b §1.4: held until the attempt resolves.
      _heldLink = link.url;
      return;
    }
    final ScanRequest request = ScanRequest.link(url: link.url, isSunSigned: link.isSunSigned);
    if (_state case final ChargeState s when s.amount > 0 && !s.fullOnly && s.phase == RedeemPhase.entering) {
      _offerSwitch(s, request);
      return;
    }
    _cancelTimers();
    unawaited(_lookup(request));
  }

  // ---------------------------------------------------------------- lookup

  LookupOrigin _originOf(LoopState state, ScanRequest request) {
    if (request.method == ScanMethod.link) return LookupOrigin.link;
    return switch (state) {
      ManualEntryState() => LookupOrigin.manual,
      QrScanState() => LookupOrigin.qr,
      ChargeState() => LookupOrigin.charge,
      SuccessState() => LookupOrigin.success,
      ProblemState() => LookupOrigin.problem,
      LookingUpState(:final LookupOrigin origin) => origin,
      ReadyState() || ScanningState() => LookupOrigin.ready,
    };
  }

  Future<void> _lookup(ScanRequest request) async {
    _cancelTimers();
    final bool verifyRescan = _verifyRescan;
    _verifyRescan = false;
    final LookupOrigin origin = _originOf(_state, request);
    final bool replacing = origin == LookupOrigin.charge || origin == LookupOrigin.success;
    final int generation = ++_generation;
    final LookingUpState looking = LookingUpState(
      request: request,
      origin: origin,
      problem: _state is ProblemState ? _state as ProblemState : null,
    );
    _go(looking);
    _slowTimer = _clock.timer(lookupSlowAfter, () {
      if (_generation == generation && _state is LookingUpState) _go((_state as LookingUpState).markSlow());
    });

    final CancelToken token = CancelToken();
    _inFlight = token;
    try {
      final ScannedCard card = await _api.scan(request, cancelToken: token);
      if (_generation != generation) return;
      _enterCharge(card, replacing: replacing);
    } on ApiCancelled {
      return;
    } on ApiFailure catch (e) {
      if (_generation != generation) return;
      _lookupFailed(request, e, verifyRescan: verifyRescan);
    } finally {
      if (identical(_inFlight, token)) _inFlight = null;
      _slowTimer?.cancel();
    }
  }

  void _lookupFailed(ScanRequest request, ApiFailure failure, {required bool verifyRescan}) {
    if (_session.handleFailure(failure, SessionContext.lookup)) {
      _go(const ReadyState());
      return;
    }
    final String support = SupportCode.fromRequestId(failure.requestId);
    final String requestId = failure.requestId;
    final ScanRequest? retry = request.isSunSigned ? null : request;

    // S11: a number the server does not accept is an inline field error (E19).
    if (failure case ApiRejected(status: 422) when request.method == ScanMethod.manual) {
      _feedback.haptic(HapticToken.error);
      _go(ManualEntryState(prefill: request.cardNumber ?? '', invalid: true));
      return;
    }

    switch (failure) {
      case ApiRejected(:final String code, :final int status, :final Duration? retryAfter):
        if (code == 'CARD_NOT_FOUND' || status == 404) {
          final bool manual = request.method == ScanMethod.manual;
          _problem(
            ProblemState(
              kind: manual ? ProblemKind.notFoundManual : ProblemKind.notFound,
              supportCode: support,
              requestId: requestId,
              manualDigits: manual ? request.cardNumber : null,
            ),
            error: true,
          );
        } else if (code == 'CARD_FOREIGN_RESTAURANT') {
          _problem(const ProblemState(kind: ProblemKind.foreign), error: true);
        } else if (code.startsWith('NFC_')) {
          _problem(
            ProblemState(
              kind: ProblemKind.verify,
              supportCode: support,
              requestId: requestId,
              verifyTag: switch (code) {
                'NFC_UID_MISMATCH' => VerifyTag.uid,
                'NFC_REPLAY_DETECTED' => VerifyTag.replay,
                _ => VerifyTag.sig,
              },
              verifyRescanUsed: verifyRescan,
            ),
            error: true,
          );
        } else if (status == 429) {
          final Duration until = _clock.now() + (retryAfter ?? const Duration(seconds: 60));
          _problem(ProblemState(kind: ProblemKind.throttled, until: until), error: false);
          _countdownTimer = _clock.timer(until - _clock.now(), () {
            _feedback.haptic(HapticToken.select);
            notifyListeners();
          });
        } else {
          _problem(ProblemState(kind: ProblemKind.server, retry: retry, supportCode: support, requestId: requestId), error: false);
        }
      case ApiTransportFailure():
        _problem(ProblemState(kind: ProblemKind.network, retry: retry), error: false);
      case ApiServerFault():
        _problem(ProblemState(kind: ProblemKind.server, retry: retry, supportCode: support, requestId: requestId), error: false);
      case ApiUnauthorized() || ApiCancelled():
        _go(const ReadyState());
    }
  }

  bool _verifyRescan = false;

  /// S10; its haptic and sound (E25/E26) are played by the `ProblemScreen`
  /// template when it appears.
  void _problem(ProblemState problem, {required bool error}) => _go(problem);

  // --------------------------------------------------------------- problem

  /// S10 "Try again" — re-sends the identical lookup (never a SUN URL).
  void retryLookup() {
    if (_state case ProblemState(:final ScanRequest? retry) when retry != null) {
      unawaited(_lookup(retry));
    }
  }

  /// S10 "Scan again": Android waits for the next tap on S05; iPhone opens the
  /// sheet. From "verification failed" it allows exactly one fresh read.
  Future<void> scanAgain(IosSheetTexts texts) async {
    if (_state case ProblemState(kind: ProblemKind.verify)) _verifyRescan = true;
    if (_isIos) {
      await startScan(texts);
    } else {
      _go(const ReadyState());
    }
  }

  /// S10 "Edit number" (L02) → S11 with the digits kept.
  void editNumber() {
    if (_state case ProblemState(:final String? manualDigits)) {
      _go(ManualEntryState(prefill: manualDigits ?? ''));
    }
  }

  // ---------------------------------------------------------------- charge

  void _enterCharge(ScannedCard card, {required bool replacing}) {
    _settings.firstReadDay = _session.businessDayKey();
    final int? max = _session.user?.restaurant?.settings.maxSingleRedemption;
    final bool fullOnly = !card.allowPartialRedemption;
    final ChargeState next = ChargeState(
      card: card,
      entry: fullOnly ? AmountEntry.fromCents(card.balance) : AmountEntry.empty,
      maxSingle: max,
      replacedCard: replacing,
    );
    _go(next);
    switch (next.condition) {
      case CardCondition.blocked:
        _feedback.both(HapticToken.error, SoundToken.error);
      case CardCondition.expired || CardCondition.inactive || CardCondition.empty || CardCondition.replaced:
        _feedback.both(HapticToken.warning, SoundToken.warning);
      case CardCondition.redeemable:
        break;
    }
  }

  ChargeState? get _charge => _state is ChargeState ? _state as ChargeState : null;

  /// Keypad digit (0–9), `00`, ⌫ and long-press clear (E30–E33).
  void key(int digit) => _edit((AmountEntry e) => e.digit(digit));

  void doubleZero() => _edit((AmountEntry e) => e.doubleZero());

  void backspace() => _edit((AmountEntry e) => e.backspace());

  void clearAmount() => _edit((AmountEntry e) => e.clear());

  void _edit(EntryChange<AmountEntry> Function(AmountEntry entry) change) {
    final ChargeState? s = _charge;
    if (s == null || s.isLocked || s.fullOnly || s.condition != CardCondition.redeemable) return;
    // Key, clear and limit haptics (E30–E33) are played by the Keypad.
    final EntryChange<AmountEntry> result = change(s.entry);
    switch (result.outcome) {
      case EntryOutcome.ignored || EntryOutcome.pasteRejected || EntryOutcome.rejectedAtLimit:
        return;
      case EntryOutcome.cleared || EntryOutcome.accepted || EntryOutcome.deleted:
        _setAmount(s, result.value);
    }
  }

  void _setAmount(ChargeState s, AmountEntry entry) {
    // K5: a changed amount starts a new attempt; the kept one is dropped.
    _attempts.keepOnly(s.card.id, entry.cents);
    if (entry.cents != s.amount) _attempts.close(s.card.id, s.amount);
    final ChargeState next = s.copyWith(
      entry: entry,
      clearNotice: s.notice is! VelocityNotice && s.notice is! RateLimitNotice,
      clearSupportCode: true,
      replacedCard: false,
    );
    // E34 (crossing above the balance) is played by the AmountDisplay.
    _go(next);
  }

  /// `QuickAmountChip` "Use balance" / "Use maximum" (E35).
  void useAmount(int cents) {
    final ChargeState? s = _charge;
    if (s == null || s.isLocked || s.fullOnly) return;
    // E35 is played by the QuickAmountChip.
    _setAmount(s, AmountEntry.fromCents(cents));
  }

  /// True while a rate or velocity countdown blocks Redeem.
  bool redeemBlockedByCountdown(ChargeState s) => switch (s.notice) {
        RateLimitNotice(:final Duration until) => _clock.now() < until,
        // Without a known time Redeem stays enabled (AC-S07-29).
        VelocityNotice(:final Duration? until) => until != null && _clock.now() < until,
        _ => false,
      };

  /// Guards of 02 §4.5.4 for REDEEM_TAP / HOLD_COMPLETE.
  bool canRedeem(ChargeState s) =>
      s.phase == RedeemPhase.entering &&
      s.condition == CardCondition.redeemable &&
      s.amount > 0 &&
      !s.isOverBalance &&
      !s.isOverMax &&
      (!s.fullOnly || s.amount == s.card.balance) &&
      _connectivity.isOnline &&
      !redeemBlockedByCountdown(s);

  /// Warms up the success haptic when the button is pressed (09 §7.8).
  void prepareRedeem() => _feedback.prepare(HapticToken.success);

  /// REDEEM_TAP (< € 100) or HOLD_COMPLETE (≥ € 100).
  Future<void> redeem() async {
    final ChargeState? s = _charge;
    if (s == null) return;
    if (!canRedeem(s)) {
      if (!_connectivity.isOnline) _feedback.haptic(HapticToken.warning);
      return;
    }
    final String key = _attempts.keyFor(s.card.id, s.amount);
    _tapAt = _clock.now();
    _go(s.copyWith(phase: RedeemPhase.submitting, attempt: 0, clearNotice: true, clearSupportCode: true, replacedCard: false));
    await _runAttempts(++_generation, s.card, s.amount, key);
  }

  /// Uncertain final: "Try again" — same key (TRY_AGAIN).
  Future<void> tryAgain() async {
    final ChargeState? s = _charge;
    if (s == null || s.phase != RedeemPhase.uncertainFinal) return;
    _retryOnReconnect = false;
    final String key = _attempts.keyFor(s.card.id, s.amount);
    _tapAt = _clock.now();
    _go(s.copyWith(phase: RedeemPhase.submitting, attempt: 0, clearSupportCode: true));
    await _runAttempts(++_generation, s.card, s.amount, key);
  }

  /// Uncertain final: "Cancel" — back to Editing, attempt kept (K6, R05).
  void cancelUncertain() {
    final ChargeState? s = _charge;
    if (s == null || s.phase != RedeemPhase.uncertainFinal) return;
    _retryOnReconnect = false;
    _feedback.haptic(HapticToken.select);
    _go(s.copyWith(phase: RedeemPhase.entering, notice: const UncertainCancelledNotice(), clearSupportCode: true));
    _releaseHeldLink();
  }

  Future<void> _runAttempts(int generation, ScannedCard card, int amount, String key) async {
    int retries = 0;
    bool slowRetryUsed = false;

    while (_generation == generation) {
      final CancelToken token = CancelToken();
      _inFlight = token;
      try {
        final RedeemResult result = await _api.redeem(
          cardId: card.id,
          amount: amount,
          idempotencyKey: key,
          cancelToken: token,
        );
        if (_generation != generation) return;
        await _redeemSucceeded(result, amount);
        return;
      } on ApiCancelled {
        return;
      } on ApiUnauthorized catch (e) {
        if (_generation != generation) return;
        // K6: the attempt survives re-authentication; back on S07 with the amount.
        _session.handleFailure(e, SessionContext.redeem);
        final ChargeState? s = _charge;
        if (s != null) _go(s.copyWith(phase: RedeemPhase.entering));
        return;
      } on ApiRejected catch (e) {
        if (_generation != generation) return;
        _attempts.close(card.id, amount);
        if (_session.handleFailure(e, SessionContext.redeem)) {
          _attempts.clear();
          _go(const ReadyState());
          return;
        }
        _redeemRejected(e);
        return;
      } on ApiFailure catch (e) {
        if (_generation != generation) return;
        final ChargeState? s = _charge;
        if (s == null) return;

        // First attempt unanswered after 8 s: "Connection slow", re-sent at once.
        if (e is ApiTransportFailure && e.timedOut && s.phase == RedeemPhase.submitting && !slowRetryUsed) {
          slowRetryUsed = true;
          _go(s.copyWith(phase: RedeemPhase.slow));
          continue;
        }

        final Duration elapsed = _clock.now() - (_tapAt ?? _clock.now());
        if (s.phase != RedeemPhase.uncertainAuto) {
          _feedback.haptic(HapticToken.warning);
        }
        if (retries >= retryWaits.length || elapsed >= uncertainCap) {
          _toUncertainFinal(s, e.requestId);
          return;
        }

        final Duration wait = retryWaits[retries];
        if (elapsed + wait >= uncertainCap) {
          _go(s.copyWith(phase: RedeemPhase.uncertainAuto, attempt: retries + 1));
          await _waitForRetry(uncertainCap - elapsed);
          if (_generation != generation) return;
          final ChargeState? current = _charge;
          if (current != null) _toUncertainFinal(current, e.requestId);
          return;
        }

        retries++;
        _go(s.copyWith(phase: RedeemPhase.uncertainAuto, attempt: retries));
        await _waitForRetry(wait);
      } finally {
        if (identical(_inFlight, token)) _inFlight = null;
      }
    }
  }

  void _toUncertainFinal(ChargeState s, String requestId) {
    _feedback.haptic(HapticToken.warning);
    _retryOnReconnect = !_connectivity.isOnline;
    _go(s.copyWith(phase: RedeemPhase.uncertainFinal, supportCode: SupportCode.fromRequestId(requestId), requestId: requestId));
  }

  /// Waits [duration]; a connectivity-restored event skips the wait (09 §4.4).
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

  Future<void> _redeemSucceeded(RedeemResult result, int amount) async {
    final ChargeState? s = _charge;
    _attempts.close(result.card.id, amount);
    final RecentEntry entry = RecentEntry(
      transactionId: result.transaction.id,
      createdAt: result.transaction.createdAt,
      last4: result.card.last4,
      amount: result.transaction.amount,
      balanceAfter: result.transaction.balanceAfter,
      currency: result.card.currency,
      restaurantName: result.card.restaurantName,
      businessDay: _session.businessDayKey(result.transaction.createdAt),
      requestId: result.requestId,
    );
    _feedback.both(HapticToken.success, SoundToken.success);
    _successAt = _clock.now();
    _successTotal = successReturn;
    _go(SuccessState(entry: entry, card: result.card));
    _log?.record('redeem.ok', result.replayed ? 'replayed' : 'created');
    _startSuccessTimer();
    await _recent.add(entry);
    if (s != null) _releaseHeldLink();
  }

  void _redeemRejected(ApiRejected e) {
    final ChargeState? s = _charge;
    if (s == null) return;
    ChargeState next = s.copyWith(phase: RedeemPhase.entering, clearSupportCode: true);
    bool error = true;
    bool sound = true;

    switch (e.code) {
      case 'INSUFFICIENT_BALANCE':
        final int balance = e.contextInt('balance') ?? s.card.balance;
        next = next.copyWith(card: s.card.copyWith(balance: balance), notice: BalanceChangedNotice(balance));
      case 'CARD_BLOCKED':
        next = next.copyWith(card: s.card.copyWith(status: CardStatus.blocked), notice: const NothingBookedNotice());
      case 'CARD_EXPIRED':
        next = next.copyWith(card: s.card.copyWith(isExpired: true), notice: const NothingBookedNotice());
      case 'CARD_NOT_REDEEMABLE' || 'INVALID_CARD_STATE':
        final CardStatus status = CardStatus.values.asNameMap()[e.contextString('status')] ?? CardStatus.redeemed;
        next = next.copyWith(
          card: s.card.copyWith(status: status, balance: status == CardStatus.redeemed ? 0 : null),
          notice: const NothingBookedNotice(),
        );
      case 'INVALID_AMOUNT':
        final int? max = e.contextInt('max_single_redemption');
        final int? balance = e.contextInt('balance');
        if (max != null) {
          next = next.copyWith(maxSingle: max, notice: MaxSingleNotice(max));
        } else if (balance != null) {
          next = next.copyWith(
            card: s.card.copyWith(balance: balance, allowPartialRedemption: false),
            entry: AmountEntry.fromCents(balance),
            notice: const FullOnlyNotice(),
          );
          error = false;
          sound = false;
        } else {
          next = next.copyWith(notice: ServerFaultNotice(SupportCode.fromRequestId(e.requestId), requestId: e.requestId));
          error = false;
          sound = false;
        }
      case 'IDEMPOTENCY_CONFLICT':
        next = next.copyWith(notice: const TapAgainNotice());
        error = false;
        sound = false;
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
          next = next.copyWith(notice: ServerFaultNotice(SupportCode.fromRequestId(e.requestId), requestId: e.requestId));
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
    _releaseHeldLink();
  }

  void _scheduleCountdown(Duration? wait) {
    _countdownTimer?.cancel();
    if (wait == null) return;
    _countdownTimer = _clock.timer(wait, notifyListeners);
  }

  /// ✕ / Back on S07 (N6): no confirmation; the amount and any kept attempt
  /// for this card are discarded.
  void closeCharge() {
    final ChargeState? s = _charge;
    if (s == null || s.isLocked) return;
    _attempts.clear();
    _go(const ReadyState());
  }

  // ---------------------------------------------------------- card switch

  /// P14: "Switch" on the snackbar (E54).
  void acceptSwitch() {
    final ChargeState? s = _charge;
    final ScanRequest? pending = s?.pendingSwitch;
    if (s == null || pending == null || s.isLocked) return;
    _switchTimer?.cancel();
    _feedback.haptic(HapticToken.select);
    _attempts.clear();
    unawaited(_lookup(pending));
  }

  /// P14 / E53: another card while an amount is typed — offered for 6 s.
  void _offerSwitch(ChargeState s, ScanRequest request) {
    _feedback.haptic(HapticToken.warning);
    _go(s.copyWith(pendingSwitch: request));
    _switchTimer?.cancel();
    _switchTimer = _clock.timer(switchOfferLifetime, keepCard);
  }

  /// With a screen reader the offer is a dialog without a timeout (12 P14).
  void holdSwitchOffer() => _switchTimer?.cancel();

  /// P14: "Keep".
  void keepCard() {
    final ChargeState? s = _charge;
    if (s == null || s.pendingSwitch == null) return;
    _switchTimer?.cancel();
    _go(s.copyWith(clearPendingSwitch: true));
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

  /// S09 with a screen reader: the automatic return is extended to 10.52 s
  /// from the response (03b §4).
  void extendSuccessForScreenReader() {
    if (_state is! SuccessState || _successTotal == successReturnScreenReader) return;
    _successTotal = successReturnScreenReader;
    if (_state case SuccessState(presenting: false)) _startSuccessTimer();
  }

  /// Monotonic time the success response arrived (hairline progress).
  Duration? get successAt => _successAt;

  /// Total time S09 stays without a tap.
  Duration get successTotal => _successTotal;

  /// Any tap on S09 or the countdown ending (TIMER_4S / TAP).
  void finishSuccess() {
    if (_state is! SuccessState) return;
    _successTimer?.cancel();
    _go(const ReadyState());
  }

  /// "Show guest": presentation mode pauses the automatic return.
  void presentToGuest(bool presenting) {
    if (_state case SuccessState(:final RecentEntry entry, :final ScannedCard card)) {
      if (presenting) {
        _successTimer?.cancel();
      } else {
        _startSuccessTimer();
      }
      _go(SuccessState(entry: entry, card: card, presenting: presenting));
    }
  }

  // ---------------------------------------------------------------- closing

  /// ✕ on S10, S11, S12 and Android back; returns false on S05 (the system
  /// then moves the app to the background, N4). Ignored while money may be
  /// moving (N5); Back in the final uncertain state = Cancel.
  bool back() {
    switch (_state) {
      case ReadyState():
        return false;
      case ChargeState(:final RedeemPhase phase, :final bool isLocked):
        if (isLocked) return true;
        if (phase == RedeemPhase.uncertainFinal) {
          cancelUncertain();
        } else {
          closeCharge();
        }
        return true;
      case SuccessState():
        finishSuccess();
        return true;
      case LookingUpState(:final LookupOrigin origin, :final ScanRequest request, :final ProblemState? problem):
        // Cancel returns to the screen the lookup came from (03a §6.4, §7, §8).
        _generation++;
        _inFlight?.cancel();
        _go(switch (origin) {
          LookupOrigin.manual => ManualEntryState(prefill: request.cardNumber ?? ''),
          LookupOrigin.qr => const QrScanState(),
          LookupOrigin.problem when problem != null => problem,
          _ => const ReadyState(),
        });
        return true;
      case ScanningState() || QrScanState() || ManualEntryState() || ProblemState():
        _go(const ReadyState());
        return true;
    }
  }

  // ------------------------------------------------------------------- NFC

  void _onNfcEvent(NfcEvent event) {
    switch (event) {
      case NfcAdapterChanged(:final NfcAvailability availability):
        _nfcAvailability = availability;
        notifyListeners();
      case NfcSessionEnded(:final NfcSessionEnd reason):
        if (_state is! ScanningState) return;
        if (reason == NfcSessionEnd.systemBusy || reason == NfcSessionEnd.unavailable) {
          _scanUnavailable = true;
          _feedback.haptic(HapticToken.warning);
          _go(const ReadyState());
        } else {
          // P08 / E16: silent return with the hint.
          _go(const ReadyState(notice: ReadyNotice.iosTimeout));
        }
      case NfcReadFailed():
        _onReadFailed();
      case NfcWriterTag():
        // S20 programs this tag; it is never looked up as a card.
        break;
      case NfcTagRead(:final String uid, :final String? url):
        if (_isIos) {
          unawaited(_onIosTag(uid, url));
        } else {
          _onAndroidTag(uid, url);
        }
    }
  }

  Future<void> _onIosTag(String uid, String? url) async {
    if (_state is! ScanningState) return;
    final CardLink? link = url == null ? null : CardLink.parse(url, _cardDomains, allowHttp: _allowHttpLinks);
    if (link == null) {
      await _nfc.rejectTag();
      return;
    }
    await _nfc.finishSession();
    unawaited(_lookup(ScanRequest.nfc(url: link.url, uid: uid, isSunSigned: link.isSunSigned)));
  }

  void _onAndroidTag(String uid, String? url) {
    if (!wantsReaderMode) return;
    final Duration now = _clock.now();
    if (_lastUid == uid && _lastReadAt != null && now - _lastReadAt! < duplicateReadWindow) return;

    final LoopState current = _state;
    if (current is ChargeState && current.isLocked) return; // 03b §1.4: ignored, no feedback.
    if (current is LookingUpState) return;
    if (current is ChargeState && current.phase == RedeemPhase.uncertainFinal) return;

    final CardLink? link = url == null ? null : CardLink.parse(url, _cardDomains, allowHttp: _allowHttpLinks);
    if (link == null) {
      if (current is ReadyState) {
        _feedback.both(HapticToken.warning, SoundToken.warning);
        _go(const ReadyState(notice: ReadyNotice.notCard));
      }
      return;
    }
    _lastUid = uid;
    _lastReadAt = now;
    _readFailures.clear();

    final ScanRequest request = ScanRequest.nfc(url: link.url, uid: uid, isSunSigned: link.isSunSigned);

    if (current is ReadyState && !_connectivity.isOnline) {
      _feedback.haptic(HapticToken.warning);
      _go(const ReadyState(notice: ReadyNotice.offlineRead));
      return;
    }

    if (current is ChargeState && current.amount > 0 && !current.fullOnly) {
      if (current.pendingSwitch == null) _offerSwitch(current, request);
      return;
    }

    _feedback.both(HapticToken.cardDetected, SoundToken.cardDetected);
    if (_session.phase == AccessPhase.onboardingIntro) _session.finishIntro();
    unawaited(_lookup(request));
  }

  void _onReadFailed() {
    if (_isIos || _state is! ReadyState) return;
    final Duration now = _clock.now();
    _readFailures
      ..add(now)
      ..removeWhere((Duration t) => now - t > readFailureWindow);
    if (_readFailures.length >= readFailuresForHint) {
      _readFailures.clear();
      _feedback.haptic(HapticToken.warning);
      _go(const ReadyState(notice: ReadyNotice.readFailed));
    }
  }

  // ------------------------------------------------------ session and network

  void _onSessionSignal(SessionSignal signal) {
    switch (signal) {
      case SessionSignal.signedOut || SessionSignal.contextDropped:
        _generation++;
        _inFlight?.cancel();
        _retryWait?.complete();
        _attempts.clear();
        _cancelTimers();
        _go(const ReadyState());
      case SessionSignal.reauthenticated:
        notifyListeners();
    }
  }

  AccessPhase? _lastPhase;

  void _onSessionChanged() {
    final AccessPhase phase = _session.phase;
    if (phase == _lastPhase) {
      notifyListeners();
      return;
    }
    _lastPhase = phase;
    if (phase == AccessPhase.active) {
      final String? link = _session.takePendingLink();
      if (link != null) openLink(link);
    }
    notifyListeners();
  }

  void _onConnectivity() {
    if (_connectivity.isOnline) {
      final Completer<void>? wait = _retryWait;
      if (wait != null && !wait.isCompleted) wait.complete();
      if (_retryOnReconnect && _charge?.phase == RedeemPhase.uncertainFinal) {
        _retryOnReconnect = false;
        unawaited(tryAgain());
      }
    }
    notifyListeners();
  }

  void _releaseHeldLink() {
    final String? link = _heldLink;
    _heldLink = null;
    if (link != null) scheduleMicrotask(() => openLink(link));
  }

  // ------------------------------------------------------------------ core

  void _cancelTimers() {
    _slowTimer?.cancel();
    _successTimer?.cancel();
    _countdownTimer?.cancel();
    _switchTimer?.cancel();
  }

  void _go(LoopState next) {
    final LoopState previous = _state;
    _state = next;
    if (previous.name != next.name) _log?.record('state', next.name);
    if (next is ReadyState && previous is! ReadyState) _session.readyShown();
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelTimers();
    _inFlight?.cancel();
    unawaited(_sessionSubscription.cancel());
    unawaited(_nfcSubscription.cancel());
    _connectivity.removeListener(_onConnectivity);
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
