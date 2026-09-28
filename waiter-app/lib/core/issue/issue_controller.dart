import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/api_failure.dart';
import '../api/models.dart';
import '../api/waiter_api.dart';
import '../format/amount_entry.dart';
import '../platform/nfc_service.dart';
import '../platform/tag_writer.dart';
import '../state/session_controller.dart';
import '../state/session_state.dart';
import 'card_programmer.dart';

/// S20 · New gift card (managers and owners): amount (+ optional guest e-mail) → card created on the server
/// → tag written, read back and verified → card number and balance. Redemption is not touched.
@immutable
sealed class IssueState {
  const IssueState();
}

/// Amount and e-mail entry. [creating]: `POST /cards` in flight.
final class IssueEntry extends IssueState {
  const IssueEntry({
    this.amount = AmountEntry.empty,
    this.creating = false,
    this.emailInvalid = false,
    this.rangeMin,
    this.rangeMax,
  });

  final AmountEntry amount;
  final bool creating;
  final bool emailInvalid;

  /// Cents, after the server refused the value (INVALID_AMOUNT).
  final int? rangeMin;
  final int? rangeMax;

  IssueEntry copyWith({AmountEntry? amount, bool? creating, bool? emailInvalid, bool clearRange = false}) => IssueEntry(
    amount: amount ?? this.amount,
    creating: creating ?? this.creating,
    emailInvalid: emailInvalid ?? this.emailInvalid,
    rangeMin: clearRange ? null : rangeMin,
    rangeMax: clearRange ? null : rangeMax,
  );
}

enum CreateProblemKind {
  /// Definitive answer: nothing was created.
  failed,

  /// No (readable) answer: it may have been created — "Try again" replays with the same key.
  uncertain,

  /// 403: the role or this phone's sign-in does not allow selling cards.
  notAllowed,
}

final class IssueCreateProblem extends IssueState {
  const IssueCreateProblem(this.kind, {required this.amount, this.requestId});

  final CreateProblemKind kind;
  final AmountEntry amount;
  final String? requestId;
}

/// The card exists; its tag is being programmed.
final class IssueProgramming extends IssueState {
  const IssueProgramming(this.card, {this.progress = const ProgramProgress(ProgramStep.waiting), this.nfcOff = false});

  final IssuedCard card;
  final ProgramProgress progress;

  /// NFC is switched off in the system settings.
  final bool nfcOff;
}

/// The card exists; this tag attempt failed and nothing was saved to the card.
final class IssueTagProblem extends IssueState {
  const IssueTagProblem(this.card, this.error);

  final IssuedCard card;
  final ProgrammingException error;
}

/// Done: [programmed] false after "Program later" (the card works via its number; tag later in the dashboard).
final class IssueDone extends IssueState {
  const IssueDone(this.card, {required this.programmed, this.locked = false});

  final IssuedCard card;
  final bool programmed;
  final bool locked;
}

class IssueController extends ChangeNotifier {
  IssueController({
    required WaiterApi api,
    required TagWriter writer,
    required NfcService nfc,
    required SessionController session,
    Uuid uuid = const Uuid(),
  }) : _api = api,
       _writer = writer,
       _nfc = nfc,
       _session = session,
       _uuid = uuid,
       _programmer = CardProgrammer(writer: writer, api: api) {
    _idempotencyKey = _uuid.v4();
    _nfcSubscription = _nfc.events.listen((NfcEvent e) {
      if (e is NfcAdapterChanged) {
        final IssueState s = _state;
        if (s is IssueProgramming) {
          final bool off = e.availability != NfcAvailability.enabled;
          if (off != s.nfcOff) {
            _set(IssueProgramming(s.card, progress: s.progress, nfcOff: off));
            if (!off) unawaited(_program(s.card));
          }
        }
      }
    });
  }

  final WaiterApi _api;
  final TagWriter _writer;
  final NfcService _nfc;
  final SessionController _session;
  final Uuid _uuid;
  final CardProgrammer _programmer;
  late final StreamSubscription<NfcEvent> _nfcSubscription;

  /// One sale = one key, kept across "Try again" until the server answered definitively.
  late String _idempotencyKey;
  ProgramCancel? _cancel;
  bool _writerOn = false;
  bool _disposed = false;

  String email = '';

  IssueState _state = const IssueEntry();
  IssueState get state => _state;

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  bool get emailValid => email.trim().isEmpty || _emailPattern.hasMatch(email.trim());

  // ------------------------------------------------------------------ entry

  EntryOutcome digit(int d) => _edit((AmountEntry a) => a.digit(d));

  EntryOutcome doubleZero() => _edit((AmountEntry a) => a.doubleZero());

  EntryOutcome backspace() => _edit((AmountEntry a) => a.backspace());

  EntryOutcome clear() => _edit((AmountEntry a) => a.clear());

  EntryOutcome _edit(EntryChange<AmountEntry> Function(AmountEntry a) change) {
    final IssueState s = _state;
    if (s is! IssueEntry || s.creating) return EntryOutcome.ignored;
    final EntryChange<AmountEntry> c = change(s.amount);
    _set(s.copyWith(amount: c.value, clearRange: true));
    return c.outcome;
  }

  void setEmail(String value) {
    email = value;
    final IssueState s = _state;
    if (s is IssueEntry && s.emailInvalid && emailValid) _set(s.copyWith(emailInvalid: false));
  }

  bool get canCreate {
    final IssueState s = _state;
    return s is IssueEntry && !s.creating && !s.amount.isEmpty;
  }

  // ------------------------------------------------------------------ create

  Future<void> create() async {
    final IssueState s = _state;
    final AmountEntry amount = switch (s) {
      IssueEntry(:final AmountEntry amount, :final bool creating) when !creating && !amount.isEmpty => amount,
      IssueCreateProblem(:final AmountEntry amount) => amount,
      _ => AmountEntry.empty,
    };
    if (amount.isEmpty) return;
    if (!emailValid) {
      _set(IssueEntry(amount: amount, emailInvalid: true));
      return;
    }
    _set(IssueEntry(amount: amount, creating: true));
    final String trimmed = email.trim();
    try {
      final IssuedCard card = await _api.createCard(
        value: amount.cents,
        customerEmail: trimmed.isEmpty ? null : trimmed,
        idempotencyKey: _idempotencyKey,
      );
      if (_disposed) return;
      _idempotencyKey = _uuid.v4();
      _set(IssueProgramming(card));
      unawaited(_program(card));
    } on ApiRejected catch (e) {
      if (_disposed) return;
      // 403 here means "not allowed to sell" (shown on S20), not the app-wide FORBIDDEN block.
      if (e.code != 'FORBIDDEN' && _session.handleFailure(e, SessionContext.lookup)) return;
      _idempotencyKey = _uuid.v4(); // definitive answer: nothing was created
      switch (e.code) {
        case 'FORBIDDEN':
          _set(IssueCreateProblem(CreateProblemKind.notAllowed, amount: amount, requestId: e.requestId));
        case 'INVALID_AMOUNT':
          _set(IssueEntry(amount: amount, rangeMin: e.contextInt('min'), rangeMax: e.contextInt('max')));
        case 'VALIDATION_FAILED' when e.fieldErrors.keys.any((String k) => k.startsWith('customer')):
          _set(IssueEntry(amount: amount, emailInvalid: true));
        default:
          _set(IssueCreateProblem(CreateProblemKind.failed, amount: amount, requestId: e.requestId));
      }
    } on ApiUnauthorized catch (e) {
      _session.handleFailure(e, SessionContext.lookup);
      if (!_disposed) _set(IssueEntry(amount: amount));
    } on ApiFailure catch (e) {
      // Timeout, no connection or 5xx: the card may exist. The same key makes "Try again" safe.
      if (!_disposed) _set(IssueCreateProblem(CreateProblemKind.uncertain, amount: amount, requestId: e.requestId));
    }
  }

  /// Back from a create problem to the entry (amount kept).
  void backToEntry() {
    final IssueState s = _state;
    if (s is IssueCreateProblem) _set(IssueEntry(amount: s.amount));
  }

  // ------------------------------------------------------------------ program

  /// "Try again" after a tag problem: a new attempt on the same card.
  Future<void> retryTag() async {
    final IssueState s = _state;
    if (s is! IssueTagProblem) return;
    _set(IssueProgramming(s.card));
    await _program(s.card);
  }

  /// "Program later": the card stays without a tag (programmable later in the dashboard).
  Future<void> programLater() async {
    final IssueState s = _state;
    final IssuedCard? card = switch (s) {
      IssueProgramming(:final IssuedCard card) || IssueTagProblem(:final IssuedCard card) => card,
      _ => null,
    };
    if (card == null) return;
    _cancel?.cancel();
    await _writerMode(false);
    _set(IssueDone(card, programmed: false));
  }

  /// "Sell another card".
  void startOver() {
    email = '';
    _idempotencyKey = _uuid.v4();
    _set(const IssueEntry());
  }

  Future<void> _program(IssuedCard card) async {
    if ((await _nfc.availability()) != NfcAvailability.enabled) {
      if (!_disposed && _state is IssueProgramming) _set(IssueProgramming(card, nfcOff: true));
      return;
    }
    _cancel?.cancel();
    final ProgramCancel cancel = ProgramCancel();
    _cancel = cancel;
    await _writerMode(true);
    try {
      final ProgramOutcome outcome = await _programmer.program(
        cardId: card.id,
        expectedUrl: card.url,
        attemptId: _uuid.v4(),
        lock: _session.user?.restaurant?.settings.lockTagsAfterWrite ?? false,
        cancel: cancel,
        tags: _writer.tags,
        onProgress: (ProgramProgress p) {
          if (!cancel.isCancelled && !_disposed) _set(IssueProgramming(card, progress: p));
        },
      );
      if (cancel.isCancelled || _disposed) return;
      await _writerMode(false);
      _set(IssueDone(card, programmed: true, locked: outcome.locked));
    } on ProgrammingException catch (e) {
      if (cancel.isCancelled || _disposed) return;
      await _writerMode(false);
      _set(IssueTagProblem(card, e));
    } on ApiFailure catch (e) {
      if (_disposed) return;
      await _writerMode(false);
      _session.handleFailure(e, SessionContext.lookup);
      if (!_disposed) _set(IssueTagProblem(card, const ProgrammingException('NETWORK')));
    }
  }

  Future<void> _writerMode(bool on) async {
    if (_writerOn == on) return;
    _writerOn = on;
    try {
      await _writer.setEnabled(enabled: on);
    } on Object {
      // The plugin is gone (engine detached); nothing to switch.
    }
  }

  void _set(IssueState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel?.cancel();
    unawaited(_nfcSubscription.cancel());
    if (_writerOn) {
      _writerOn = false;
      unawaited(_writer.setEnabled(enabled: false).catchError((Object _) {}));
    }
    super.dispose();
  }
}
