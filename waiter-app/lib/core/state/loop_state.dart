import 'package:flutter/foundation.dart';

import '../api/models.dart';
import '../format/amount_entry.dart';
import '../storage/pending_redemptions.dart';
import '../storage/recent_store.dart';

/// The redeem loop: Ready → QR scan → Presenting → Charge → Redeeming →
/// Success, plus Problem. Screens render from these values only; state names
/// are used in logs.
@immutable
sealed class LoopState {
  const LoopState();

  /// Name used in the diagnostic log and tests.
  String get name;
}

/// S05.
final class ReadyState extends LoopState {
  const ReadyState();

  @override
  String get name => 'Ready';
}

/// S12: the camera looks for a voucher QR.
final class QrScanState extends LoopState {
  const QrScanState();

  @override
  String get name => 'QrScan';
}

/// The screen a presentment was started from; it stays visible while
/// `POST /presentments` runs (S12 with its own progress, S10 with a busy
/// "Try again").
enum PresentOrigin { qr, problem }

/// While `POST /presentments` runs.
final class PresentingState extends LoopState {
  const PresentingState({required this.credential, required this.origin, this.slow = false, this.problem});

  /// The scanned QR text (sent again unchanged by "Try again").
  final String credential;
  final PresentOrigin origin;

  /// Still running after 3 s ("Still checking …").
  final bool slow;

  /// The problem being retried (origin [PresentOrigin.problem]).
  final ProblemState? problem;

  PresentingState markSlow() => PresentingState(credential: credential, origin: origin, slow: true, problem: problem);

  @override
  String get name => 'Presenting';
}

/// Voucher state variant of S07 (precedence: blocked › expired › empty).
enum VoucherCondition { redeemable, blocked, expired, empty }

VoucherCondition conditionOf(PresentedVoucher voucher) {
  if (voucher.status == VoucherStatus.blocked) return VoucherCondition.blocked;
  if (voucher.status == VoucherStatus.expired || voucher.isExpired) return VoucherCondition.expired;
  if (voucher.balance == 0) return VoucherCondition.empty;
  return VoucherCondition.redeemable;
}

/// The redeem sub-machine of S07/S08.
enum RedeemPhase {
  /// An earlier attempt on this voucher is unresolved: nothing can be redeemed
  /// until the server has said whether it was booked.
  resolving,

  /// Idle / editing.
  entering,

  /// Submitting.
  submitting,

  /// "Connection slow" after 8 s, re-sent at once with the same key.
  slow,

  /// Uncertain — silent automatic retries with the same key (up to 20 s).
  uncertainAuto,

  /// Uncertain — final: "Check again" / "Cancel".
  uncertainFinal,
}

/// Messages on S07 after a definitive answer or a local guard.
@immutable
sealed class ChargeNotice {
  const ChargeNotice();
}

/// The balance changed meanwhile — the voucher was updated from the answer.
final class BalanceChangedNotice extends ChargeNotice {
  const BalanceChangedNotice(this.balance);

  final int balance;
}

/// Over the per-redemption maximum.
final class MaxSingleNotice extends ChargeNotice {
  const MaxSingleNotice(this.max);

  final int max;
}

/// Over what the voucher may still pay today.
final class DailyLimitNotice extends ChargeNotice {
  const DailyLimitNotice(this.remaining);

  final int remaining;
}

/// Only the full balance may be redeemed.
final class FullOnlyNotice extends ChargeNotice {
  const FullOnlyNotice();
}

/// The voucher cannot be redeemed (anymore); "Nothing was booked".
final class NothingBookedNotice extends ChargeNotice {
  const NothingBookedNotice();
}

/// The server's answer could not be used — "Service not available" + code.
final class ServerFaultNotice extends ChargeNotice {
  const ServerFaultNotice(this.supportCode, {this.requestId = ''});

  final String supportCode;

  /// Full `X-Request-Id` (long-press copy).
  final String requestId;
}

/// Too many redemptions of this voucher; [until] on the monotonic clock.
final class VelocityNotice extends ChargeNotice {
  const VelocityNotice({this.until});

  final Duration? until;
}

/// 429 with countdown.
final class RateLimitNotice extends ChargeNotice {
  const RateLimitNotice(this.until);

  final Duration until;
}

/// An earlier, unconfirmed redemption of this voucher turned out to be booked.
final class EarlierBookedNotice extends ChargeNotice {
  const EarlierBookedNotice(this.amount);

  final int amount;
}

/// S07 / S08.
final class ChargeState extends LoopState {
  const ChargeState({
    required this.voucher,
    required this.presentmentId,
    required this.presentmentDeadline,
    required this.entry,
    this.phase = RedeemPhase.entering,
    this.attempt = 0,
    this.notice,
    this.maxSingle,
    this.presentmentExpired = false,
    this.pending,
    this.checking = false,
    this.supportCode,
    this.requestId,
  });

  final PresentedVoucher voucher;

  /// The single-use proof that the voucher is here; spent by the redemption.
  final String presentmentId;

  /// Monotonic time after which the presentment is no longer used.
  final Duration presentmentDeadline;
  final AmountEntry entry;
  final RedeemPhase phase;

  /// Automatic retry number shown in the uncertain panel.
  final int attempt;
  final ChargeNotice? notice;

  /// Per-redemption maximum (checked client-side).
  final int? maxSingle;

  /// The presentment ran out or was refused: the voucher must be scanned again.
  final bool presentmentExpired;

  /// The unresolved attempt on this voucher (while [phase] is resolving or
  /// uncertain).
  final PendingRedemption? pending;

  /// Resolving: the outcome question is in flight.
  final bool checking;

  /// Support code of the last failed attempt.
  final String? supportCode;

  /// Full `X-Request-Id` behind [supportCode] (long-press copy).
  final String? requestId;

  int get amount => entry.cents;

  VoucherCondition get condition => conditionOf(voucher);

  /// Partial redemption disabled: the amount is fixed to the balance.
  bool get fullOnly => !voucher.allowPartialRedemption;

  bool get isOverBalance => amount > voucher.balance;

  bool get isOverMax => maxSingle != null && amount > maxSingle!;

  /// Keypad, chip, ✕ and back are locked while money may be moving, and the
  /// amount while an attempt is unresolved.
  bool get isLocked =>
      phase == RedeemPhase.submitting ||
      phase == RedeemPhase.slow ||
      phase == RedeemPhase.uncertainAuto ||
      phase == RedeemPhase.uncertainFinal ||
      phase == RedeemPhase.resolving;

  bool get isUncertain => phase == RedeemPhase.uncertainAuto || phase == RedeemPhase.uncertainFinal;

  ChargeState copyWith({
    PresentedVoucher? voucher,
    String? presentmentId,
    Duration? presentmentDeadline,
    AmountEntry? entry,
    RedeemPhase? phase,
    int? attempt,
    ChargeNotice? notice,
    bool clearNotice = false,
    int? maxSingle,
    bool? presentmentExpired,
    PendingRedemption? pending,
    bool clearPending = false,
    bool? checking,
    String? supportCode,
    String? requestId,
    bool clearSupportCode = false,
  }) => ChargeState(
    voucher: voucher ?? this.voucher,
    presentmentId: presentmentId ?? this.presentmentId,
    presentmentDeadline: presentmentDeadline ?? this.presentmentDeadline,
    entry: entry ?? this.entry,
    phase: phase ?? this.phase,
    attempt: attempt ?? this.attempt,
    notice: clearNotice ? null : (notice ?? this.notice),
    maxSingle: maxSingle ?? this.maxSingle,
    presentmentExpired: presentmentExpired ?? this.presentmentExpired,
    pending: clearPending ? null : (pending ?? this.pending),
    checking: checking ?? this.checking,
    supportCode: clearSupportCode ? null : (supportCode ?? this.supportCode),
    requestId: clearSupportCode ? null : (requestId ?? this.requestId),
  );

  @override
  String get name => switch (phase) {
    RedeemPhase.resolving => 'Charge.Resolving',
    RedeemPhase.entering => condition == VoucherCondition.redeemable ? 'Charge.Entering' : 'Charge.VoucherProblem',
    RedeemPhase.submitting => 'Redeeming',
    RedeemPhase.slow => 'Slow',
    RedeemPhase.uncertainAuto || RedeemPhase.uncertainFinal => 'Uncertain',
  };
}

/// S09. Amount and remaining balance come from the server response.
final class SuccessState extends LoopState {
  const SuccessState({required this.entry, required this.voucher, this.presenting = false});

  final RecentEntry entry;
  final PresentedVoucher voucher;

  /// "Show guest" presentation mode: the automatic return is paused.
  final bool presenting;

  @override
  String get name => 'Success';
}

/// S10 variants.
enum ProblemKind {
  /// Not a voucher of this restaurant (unknown, revoked or foreign code).
  notRecognized,

  /// Too many failed scans on this phone.
  throttled,

  /// No connection.
  network,

  /// The server's answer could not be used.
  server,
}

final class ProblemState extends LoopState {
  const ProblemState({required this.kind, this.retry, this.supportCode, this.requestId, this.until});

  final ProblemKind kind;

  /// The QR text for "Try again" (network / server).
  final String? retry;
  final String? supportCode;

  /// Full `X-Request-Id` behind [supportCode] (long-press copy).
  final String? requestId;

  /// Throttled: monotonic time when scanning is possible again.
  final Duration? until;

  @override
  String get name => 'Problem.${kind.name}';
}
