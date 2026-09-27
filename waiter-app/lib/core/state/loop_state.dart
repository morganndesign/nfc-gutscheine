import 'package:flutter/foundation.dart';

import '../api/models.dart';
import '../api/waiter_api.dart';
import '../format/amount_entry.dart';
import '../storage/recent_store.dart';

/// The redeem loop (02 §4.5): Ready → Scanning → LookingUp → Charge →
/// Redeeming → Success, plus the alternatives and Problem. Screens render
/// from these values only (09 §4.1 rule 2); state names are used in logs.
@immutable
sealed class LoopState {
  const LoopState();

  /// Name used in the diagnostic log and test scripts (02 §4.5.2).
  String get name;
}

/// One-off hints on S05 (not errors of the loop; 03a S05).
enum ReadyNotice {
  /// P08: iPhone sheet timed out or was cancelled (`ready.ios.timeout`).
  iosTimeout,

  /// L09: card read while known offline (Android).
  offlineRead,

  /// L11 / E13: three failed reads within 5 s (Android).
  readFailed,

  /// L10 / E13a: the tag is not a gift card (Android).
  notCard,
}

/// S05 Ready (+ S06 Android inline, S16 variants via [LoopController] flags).
final class ReadyState extends LoopState {
  const ReadyState({this.notice});

  final ReadyNotice? notice;

  @override
  String get name => 'Ready.Idle';
}

/// S06 on iPhone: the system NFC sheet is open.
final class ScanningState extends LoopState {
  const ScanningState();

  @override
  String get name => 'Scanning';
}

/// S12.
final class QrScanState extends LoopState {
  const QrScanState();

  @override
  String get name => 'QrScan';
}

/// S11; [prefill] keeps the digits after L02 "Edit number" or a cancelled
/// lookup; [invalid] = the server rejected the number format (E19,
/// `manual.error.invalid`).
final class ManualEntryState extends LoopState {
  const ManualEntryState({this.prefill = '', this.invalid = false});

  final String prefill;
  final bool invalid;

  @override
  String get name => 'ManualEntry';
}

/// The screen a lookup was started from — it stays visible while
/// `POST /scan` runs (03a §6.4, 03b §2): S05 inline, S11 / S12 with their
/// own progress, S07 skeleton (links, new card on S07/S09), S10 (Try again).
enum LookupOrigin { ready, manual, qr, link, charge, success, problem }

/// While `POST /scan` runs.
final class LookingUpState extends LoopState {
  const LookingUpState({required this.request, required this.origin, this.slow = false, this.problem});

  final ScanRequest request;
  final LookupOrigin origin;

  /// L08: still running after 3 s ("Still looking …").
  final bool slow;

  /// The problem being retried (origin [LookupOrigin.problem]).
  final ProblemState? problem;

  LookingUpState markSlow() => LookingUpState(request: request, origin: origin, slow: true, problem: problem);

  @override
  String get name => 'LookingUp';
}

/// Card state variant of S07 (03b §1.3 precedence: blocked › expired ›
/// replaced › inactive › zero balance).
enum CardCondition { redeemable, blocked, expired, replaced, inactive, empty }

CardCondition conditionOf(ScannedCard card) {
  if (card.status == CardStatus.blocked) return CardCondition.blocked;
  if (card.status == CardStatus.expired || card.isExpired) return CardCondition.expired;
  if (card.status == CardStatus.replaced) return CardCondition.replaced;
  if (card.status == CardStatus.inactive) return CardCondition.inactive;
  if (card.status == CardStatus.redeemed || card.balance == 0) return CardCondition.empty;
  return CardCondition.redeemable;
}

/// The redeem sub-machine of S07/S08 (09 §4.4).
enum RedeemPhase {
  /// Idle / Editing.
  entering,

  /// Submitting (S08 states 1–2).
  submitting,

  /// Retrying — "Connection slow" after 8 s.
  slow,

  /// Uncertain — silent automatic retries (up to 20 s after the tap).
  uncertainAuto,

  /// Uncertain — final: "Try again" / "Cancel".
  uncertainFinal,
}

/// Messages on S07 after a definitive answer or a local guard (12 §3.2).
@immutable
sealed class ChargeNotice {
  const ChargeNotice();
}

/// R06: the balance changed meanwhile — card updated from `context.balance`.
final class BalanceChangedNotice extends ChargeNotice {
  const BalanceChangedNotice(this.balance);

  final int balance;
}

/// R10: over `max_single_redemption`.
final class MaxSingleNotice extends ChargeNotice {
  const MaxSingleNotice(this.max);

  final int max;
}

/// R11: only the full balance may be redeemed.
final class FullOnlyNotice extends ChargeNotice {
  const FullOnlyNotice();
}

/// R07–R09: the card cannot be redeemed (anymore); "Nothing was booked".
final class NothingBookedNotice extends ChargeNotice {
  const NothingBookedNotice();
}

/// R12: client defect — "Something went wrong" + support code.
final class ServerFaultNotice extends ChargeNotice {
  const ServerFaultNotice(this.supportCode, {this.requestId = ''});

  final String supportCode;

  /// Full `X-Request-Id` (long-press copy).
  final String requestId;
}

/// R13: 409 IDEMPOTENCY_CONFLICT — "Please tap Redeem again".
final class TapAgainNotice extends ChargeNotice {
  const TapAgainNotice();
}

/// R14: velocity limit; [until] on the monotonic clock when known.
final class VelocityNotice extends ChargeNotice {
  const VelocityNotice({this.until});

  final Duration? until;
}

/// R15: 429 TOO_MANY_REQUESTS with countdown.
final class RateLimitNotice extends ChargeNotice {
  const RateLimitNotice(this.until);

  final Duration until;
}

/// R05: after "Cancel" in the final uncertain state.
final class UncertainCancelledNotice extends ChargeNotice {
  const UncertainCancelledNotice();
}

/// S07 / S08.
final class ChargeState extends LoopState {
  const ChargeState({
    required this.card,
    required this.entry,
    this.phase = RedeemPhase.entering,
    this.attempt = 0,
    this.notice,
    this.maxSingle,
    this.supportCode,
    this.requestId,
    this.pendingSwitch,
    this.replacedCard = false,
  });

  final ScannedCard card;
  final AmountEntry entry;
  final RedeemPhase phase;

  /// Automatic retry number shown in the uncertain panel (`uncertain.retrying`).
  final int attempt;
  final ChargeNotice? notice;

  /// Cap known from settings or a previous 422 (checked client-side).
  final int? maxSingle;

  /// Support code of the last failed attempt (uncertain final, R12).
  final String? supportCode;

  /// Full `X-Request-Id` behind [supportCode] (long-press copy).
  final String? requestId;

  /// Android: another card was read while an amount is typed (P14/E53).
  final ScanRequest? pendingSwitch;

  /// True right after a card replaced the previous one (M21 cross-fade).
  final bool replacedCard;

  int get amount => entry.cents;

  CardCondition get condition => conditionOf(card);

  /// Partial redemption disabled: the amount is fixed to the balance (R11).
  bool get fullOnly => !card.allowPartialRedemption;

  bool get isOverBalance => amount > card.balance;

  bool get isOverMax => maxSingle != null && amount > maxSingle!;

  /// Keypad, chip, ✕ and back are locked while money may be moving (03b §1.4).
  bool get isLocked =>
      phase == RedeemPhase.submitting || phase == RedeemPhase.slow || phase == RedeemPhase.uncertainAuto;

  bool get isUncertain => phase == RedeemPhase.uncertainAuto || phase == RedeemPhase.uncertainFinal;

  ChargeState copyWith({
    ScannedCard? card,
    AmountEntry? entry,
    RedeemPhase? phase,
    int? attempt,
    ChargeNotice? notice,
    bool clearNotice = false,
    int? maxSingle,
    String? supportCode,
    String? requestId,
    bool clearSupportCode = false,
    ScanRequest? pendingSwitch,
    bool clearPendingSwitch = false,
    bool? replacedCard,
  }) =>
      ChargeState(
        card: card ?? this.card,
        entry: entry ?? this.entry,
        phase: phase ?? this.phase,
        attempt: attempt ?? this.attempt,
        notice: clearNotice ? null : (notice ?? this.notice),
        maxSingle: maxSingle ?? this.maxSingle,
        supportCode: clearSupportCode ? null : (supportCode ?? this.supportCode),
        requestId: clearSupportCode ? null : (requestId ?? this.requestId),
        pendingSwitch: clearPendingSwitch ? null : (pendingSwitch ?? this.pendingSwitch),
        replacedCard: replacedCard ?? this.replacedCard,
      );

  @override
  String get name => switch (phase) {
        RedeemPhase.entering => condition == CardCondition.redeemable ? 'Charge.Entering' : 'Charge.CardProblem',
        RedeemPhase.submitting => 'Redeeming',
        RedeemPhase.slow => 'Slow',
        RedeemPhase.uncertainAuto || RedeemPhase.uncertainFinal => 'Uncertain',
      };
}

/// S09. Amount and remaining balance come from the server response (I5).
final class SuccessState extends LoopState {
  const SuccessState({required this.entry, required this.card, this.presenting = false});

  final RecentEntry entry;
  final ScannedCard card;

  /// "Show guest" presentation mode: the 4 s return is paused.
  final bool presenting;

  @override
  String get name => 'Success';
}

/// S10 variants (09 §5 `problem/{variant}`).
enum ProblemKind { notFound, notFoundManual, foreign, verify, throttled, network, server, notGiftCard }

/// Neutral tag after the support code of verification failures (L04).
enum VerifyTag { uid, sig, replay }

final class ProblemState extends LoopState {
  const ProblemState({
    required this.kind,
    this.retry,
    this.supportCode,
    this.requestId,
    this.verifyTag,
    this.until,
    this.manualDigits,
    this.verifyRescanUsed = false,
  });

  final ProblemKind kind;

  /// The identical lookup for "Try again" (network/server) — null for
  /// SUN-signed cards, which need a fresh read ("Scan again", 03b §1.2).
  final ScanRequest? retry;
  final String? supportCode;

  /// Full `X-Request-Id` behind [supportCode] (long-press copy, AC-S10-6).
  final String? requestId;
  final VerifyTag? verifyTag;

  /// Throttled: monotonic time when scanning is possible again.
  final Duration? until;

  /// L02: digits kept for "Edit number".
  final String? manualDigits;

  /// L04: the tertiary "Scan again" allows one fresh read (`verifyFinal`).
  final bool verifyRescanUsed;

  @override
  String get name => 'Problem.${kind.name}';
}
