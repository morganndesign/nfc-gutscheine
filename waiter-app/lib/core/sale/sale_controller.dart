import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/api_failure.dart';
import '../api/models.dart';
import '../api/waiter_api.dart';
import '../format/amount_entry.dart';
import '../platform/voucher_printer.dart';
import '../state/session_controller.dart';
import '../state/session_state.dart';

/// S20 · Sell voucher (managers and owners, Android and iPhone alike):
/// value → how the guest paid (+ optional e-mail) → `POST /vouchers` →
/// print the QR. The QR text is returned once and lives only in this
/// controller until the screen closes. Gift cards are sold under "Karte
/// verkaufen / aufladen" (S24), never here (decision 2026-10-05).
@immutable
sealed class SaleState {
  const SaleState();
}

/// Step 1: the value on the keypad. [rangeMin]/[rangeMax] are shown when the
/// value is outside the restaurant's limits.
final class SaleAmount extends SaleState {
  const SaleAmount({this.amount = AmountEntry.empty, this.rangeMin, this.rangeMax});

  final AmountEntry amount;
  final int? rangeMin;
  final int? rangeMax;

  bool get outOfRange => rangeMin != null || rangeMax != null;
}

/// Step 2: payment method, reference or reason, guest e-mail.
final class SaleDetails extends SaleState {
  const SaleDetails({
    required this.amount,
    this.method = PaymentMethod.cash,
    this.submitting = false,
    this.referenceMissing = false,
    this.reasonMissing = false,
    this.emailInvalid = false,
  });

  final AmountEntry amount;
  final PaymentMethod method;

  /// `POST /vouchers` in flight.
  final bool submitting;
  final bool referenceMissing;
  final bool reasonMissing;
  final bool emailInvalid;

  SaleDetails copyWith({
    PaymentMethod? method,
    bool? submitting,
    bool? referenceMissing,
    bool? reasonMissing,
    bool? emailInvalid,
  }) => SaleDetails(
    amount: amount,
    method: method ?? this.method,
    submitting: submitting ?? this.submitting,
    referenceMissing: referenceMissing ?? this.referenceMissing,
    reasonMissing: reasonMissing ?? this.reasonMissing,
    emailInvalid: emailInvalid ?? this.emailInvalid,
  );
}

enum SaleProblemKind {
  /// Definitive answer: nothing was sold.
  failed,

  /// No (readable) answer: it may have been sold — "Try again" replays with
  /// the same key.
  uncertain,

  /// 403: this role or this phone's sign-in may not sell (or not
  /// complimentary).
  notAllowed,
}

final class SaleProblem extends SaleState {
  const SaleProblem(this.kind, {required this.details, this.requestId});

  final SaleProblemKind kind;

  /// The entry to return to (and to send again after an uncertain answer).
  final SaleDetails details;
  final String? requestId;
}

/// Sold. The QR is printed from here as often as needed while the screen is
/// open; it cannot be shown again afterwards. A retry answered after the sale
/// window carries no QR ([hasQr] false): the screen then says how to proceed.
final class SaleDone extends SaleState {
  const SaleDone(this.voucher, {this.printing = false, this.printed = false, this.printFailed = false});

  final SoldVoucher voucher;
  final bool printing;

  bool get hasQr => voucher.printablePayload != null;

  /// At least one print job was handed to a printer.
  final bool printed;
  final bool printFailed;

  SaleDone copyWith({bool? printing, bool? printed, bool? printFailed}) => SaleDone(
    voucher,
    printing: printing ?? this.printing,
    printed: printed ?? this.printed,
    printFailed: printFailed ?? this.printFailed,
  );
}

class SaleController extends ChangeNotifier {
  SaleController({
    required WaiterApi api,
    required SessionController session,
    required VoucherPrinter printer,
    Uuid uuid = const Uuid(),
  }) : _api = api,
       _session = session,
       _printer = printer,
       _uuid = uuid,
       _idempotencyKey = uuid.v4();

  final WaiterApi _api;
  final SessionController _session;
  final VoucherPrinter _printer;
  final Uuid _uuid;

  /// One sale = one key, kept across "Try again" until the server answered
  /// definitively.
  String _idempotencyKey;
  bool _disposed = false;

  String reference = '';
  String reason = '';
  String email = '';

  /// For whom, and the buyer's message (on the voucher and its PDF).
  String recipient = '';
  String message = '';

  SaleState _state = const SaleAmount();
  SaleState get state => _state;

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  RestaurantSettings? get _settings => _session.user?.restaurant?.settings;

  /// The payment methods this user may record.
  List<PaymentMethod> get methods => <PaymentMethod>[
    PaymentMethod.cash,
    PaymentMethod.cardTerminal,
    PaymentMethod.bankTransfer,
    if (_session.user?.canSellComplimentary ?? false) PaymentMethod.complimentary,
  ];

  /// Whether the guest gets a confirmation e-mail after the sale.
  bool get sendsGuestEmail => _settings?.sendCustomerEmails ?? false;

  // ------------------------------------------------------------------ amount

  EntryOutcome digit(int d) => _edit((AmountEntry a) => a.digit(d));

  EntryOutcome doubleZero() => _edit((AmountEntry a) => a.doubleZero());

  EntryOutcome backspace() => _edit((AmountEntry a) => a.backspace());

  EntryOutcome clear() => _edit((AmountEntry a) => a.clear());

  EntryOutcome _edit(EntryChange<AmountEntry> Function(AmountEntry a) change) {
    final SaleState s = _state;
    if (s is! SaleAmount) return EntryOutcome.ignored;
    final EntryChange<AmountEntry> c = change(s.amount);
    _set(SaleAmount(amount: c.value));
    return c.outcome;
  }

  bool get canContinue {
    final SaleState s = _state;
    return s is SaleAmount && !s.amount.isEmpty;
  }

  /// Amount → details, after the restaurant's limits.
  void continueToDetails() {
    final SaleState s = _state;
    if (s is! SaleAmount || s.amount.isEmpty) return;
    final int value = s.amount.cents;
    final int? min = _settings?.minVoucherValue;
    final int? max = _settings?.maxVoucherBalance;
    if ((min != null && value < min) || (max != null && value > max)) {
      _set(SaleAmount(amount: s.amount, rangeMin: min ?? 1, rangeMax: max ?? value));
      return;
    }
    _set(SaleDetails(amount: s.amount));
  }

  /// Details → amount (Back).
  void backToAmount() {
    final SaleState s = _state;
    if (s is SaleDetails && !s.submitting) _set(SaleAmount(amount: s.amount));
  }

  // ------------------------------------------------------------------ details

  void chooseMethod(PaymentMethod method) {
    final SaleState s = _state;
    if (s is SaleDetails && !s.submitting) {
      _set(s.copyWith(method: method, referenceMissing: false, reasonMissing: false));
    }
  }

  void setReference(String value) {
    reference = value;
    final SaleState s = _state;
    if (s is SaleDetails && s.referenceMissing && value.trim().isNotEmpty) _set(s.copyWith(referenceMissing: false));
  }

  void setReason(String value) {
    reason = value;
    final SaleState s = _state;
    if (s is SaleDetails && s.reasonMissing && value.trim().length >= 3) _set(s.copyWith(reasonMissing: false));
  }

  void setRecipient(String value) => recipient = value;

  void setMessage(String value) => message = value;

  void setEmail(String value) {
    email = value;
    final SaleState s = _state;
    if (s is SaleDetails && s.emailInvalid && _emailValid) _set(s.copyWith(emailInvalid: false));
  }

  bool get _emailValid => email.trim().isEmpty || _emailPattern.hasMatch(email.trim());

  // ------------------------------------------------------------------ sell

  /// Codes only the sale itself answers with. After a request that got no
  /// answer, only these prove that the key was not booked: the server checks
  /// the key before the limits and the payment policy, so a booked key is
  /// always answered with its sale. Anything else — 401, 403, 429, a gateway
  /// or an unknown code — says nothing about the earlier request.
  static const Set<String> _saleCodes = <String>{
    'INVALID_AMOUNT',
    'BALANCE_LIMIT_EXCEEDED',
    'VALIDATION_FAILED',
    'COMPLIMENTARY_NOT_ALLOWED',
  };

  /// A request with the current key went out and its answer never arrived:
  /// the voucher may have been sold. Cleared only by a definitive answer.
  bool _unanswered = false;

  /// True while the outcome of the last sale request is unknown. Leaving then
  /// asks first: only "Try again" (the same key) finds out without selling
  /// twice.
  bool get uncertain => _unanswered;

  Future<void> sell() async {
    final SaleState s = _state;
    final SaleDetails? details = switch (s) {
      SaleDetails(:final bool submitting) when !submitting => s,
      SaleProblem(kind: SaleProblemKind.uncertain || SaleProblemKind.failed, :final SaleDetails details) => details,
      _ => null,
    };
    if (details == null) return;

    final PaymentMethod method = details.method;
    final bool referenceMissing = method.needsReference && reference.trim().isEmpty;
    final bool reasonMissing = method.needsReason && reason.trim().length < 3;
    if (!_unanswered && (referenceMissing || reasonMissing || !_emailValid)) {
      _set(
        details.copyWith(
          submitting: false,
          referenceMissing: referenceMissing,
          reasonMissing: reasonMissing,
          emailInvalid: !_emailValid,
        ),
      );
      return;
    }

    _set(details.copyWith(submitting: true));
    final String trimmedEmail = email.trim();
    try {
      final SoldVoucher sold = await _api.sell(
        value: details.amount.cents,
        payment: PaymentInput(method: method, reference: reference.trim(), reason: reason.trim()),
        customerEmail: trimmedEmail.isEmpty ? null : trimmedEmail,
        recipientName: recipient.trim().isNotEmpty ? recipient.trim() : null,
        giftMessage: message.trim().isNotEmpty ? message.trim() : null,
        idempotencyKey: _idempotencyKey,
      );
      _definitive();
      _set(SaleDone(sold));
    } on ApiRejected catch (e) {
      if (_disposed) return;
      final SaleDetails back = details.copyWith(submitting: false);
      if (_unanswered && !_saleCodes.contains(e.code)) {
        // The earlier request may have sold the voucher: keep the key. (A 403
        // here is about selling, never the app-wide block.)
        if (e.status != 403) _session.handleFailure(e, SessionContext.lookup);
        _set(SaleProblem(SaleProblemKind.uncertain, details: back, requestId: e.requestId));
        return;
      }
      final bool forbidden = e.status == 403;
      // 403 here means "not allowed to sell" (shown on S20), not the app-wide block.
      if (!forbidden && _session.handleFailure(e, SessionContext.lookup)) {
        _definitive();
        return;
      }
      if (e.code == 'IDEMPOTENCY_CONFLICT') {
        // The key is known with another value: the earlier sale stands; never
        // answered by a new key without the waiter seeing it.
        _set(SaleProblem(SaleProblemKind.uncertain, details: back, requestId: e.requestId));
        return;
      }
      _definitive(); // nothing was sold
      if (forbidden || e.code == 'COMPLIMENTARY_NOT_ALLOWED') {
        _set(SaleProblem(SaleProblemKind.notAllowed, details: back, requestId: e.requestId));
      } else if (e.code == 'INVALID_AMOUNT' || e.code == 'BALANCE_LIMIT_EXCEEDED') {
        _set(
          SaleAmount(
            amount: details.amount,
            rangeMin: e.contextInt('min') ?? _settings?.minVoucherValue ?? 1,
            rangeMax: e.contextInt('max') ?? _settings?.maxVoucherBalance ?? details.amount.cents,
          ),
        );
      } else if (e.code == 'VALIDATION_FAILED' && e.fieldErrors.isNotEmpty) {
        final Iterable<String> fields = e.fieldErrors.keys;
        _set(
          back.copyWith(
            referenceMissing: fields.contains('payment.reference'),
            reasonMissing: fields.contains('payment.reason'),
            emailInvalid: fields.any((String k) => k.startsWith('customer')),
          ),
        );
      } else {
        _set(SaleProblem(SaleProblemKind.failed, details: back, requestId: e.requestId));
      }
    } on ApiUnauthorized catch (e) {
      _session.handleFailure(e, SessionContext.lookup);
      if (_disposed) return;
      final SaleDetails back = details.copyWith(submitting: false);
      if (_unanswered) {
        _set(SaleProblem(SaleProblemKind.uncertain, details: back, requestId: e.requestId));
      } else {
        // Refused before it was handled: nothing was sold.
        _set(back);
      }
    } on ApiFailure catch (e) {
      // Timeout, no connection or 5xx: it may have been sold. The same key
      // makes "Try again" safe and returns the sale (with a fresh QR while
      // the guest is still at the counter).
      _unanswered = true;
      if (!_disposed) {
        _set(
          SaleProblem(SaleProblemKind.uncertain, details: details.copyWith(submitting: false), requestId: e.requestId),
        );
      }
    }
  }

  /// The server answered for the current key: the next sale gets a new one.
  void _definitive() {
    _unanswered = false;
    _idempotencyKey = _uuid.v4();
  }

  /// Back from a definitive problem to the details (entry kept).
  void backToDetails() {
    final SaleState s = _state;
    if (s is SaleProblem && s.kind != SaleProblemKind.uncertain) _set(s.details);
  }

  // ------------------------------------------------------------------ print

  Future<void> print(PrintableVoucher Function(SoldVoucher sold) sheet) async {
    final SaleState s = _state;
    if (s is! SaleDone || !s.hasQr || s.printing) return;
    _set(s.copyWith(printing: true, printFailed: false));
    bool printed = false;
    bool failed = false;
    try {
      // False: the print dialog was closed without printing.
      printed = await _printer.print(sheet(s.voucher));
    } on Object {
      failed = true;
    }
    final SaleState now = _state;
    if (_disposed || now is! SaleDone) return;
    _set(now.copyWith(printing: false, printed: now.printed || printed, printFailed: failed));
  }

  /// "Sell another voucher".
  void startOver() {
    if (_unanswered) return;
    reference = '';
    reason = '';
    email = '';
    recipient = '';
    message = '';
    _idempotencyKey = _uuid.v4();
    _set(const SaleAmount());
  }

  void _set(SaleState next) {
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
