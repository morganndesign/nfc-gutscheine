import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_failure.dart';
import '../api/models.dart';
import '../api/waiter_api.dart';
import '../cards/ntag424_session.dart';
import '../platform/nfc_relay.dart';

/// Where the station is.
enum StationPhase {
  /// Choosing a batch (or loading the list).
  batches,

  /// Waiting for the next blank card on the phone.
  waiting,

  /// A card is on the phone; the server's rounds are running.
  working,
}

/// Why the last card is not finished. Every one of them is resumable by holding the card again, except
/// [rejected] and [unknownChip], which mean: set the card aside.
enum StationFailure {
  /// The card left the field during a round.
  tagLost,

  /// The server refused a round (a wrong answer, an expired round).
  refused,

  /// Not a chip of this batch, or already finished.
  rejected,

  /// A chip whose keys are neither factory nor ours.
  unknownChip,

  offline,
  server,
  nfcOff,
  nfcUnsupported,
}

/// The outcome of the last card, shown while the station waits for the next one.
@immutable
class StationOutcome {
  const StationOutcome.done(String this.cardNumber) : failure = null, detail = null;

  const StationOutcome.failed(StationFailure this.failure, {this.detail}) : cardNumber = null;

  final String? cardNumber;
  final StationFailure? failure;

  /// The technical reason (the server's refusal reason or the reader's error), shown small to platform staff
  /// so a failing chip can be diagnosed: e.g. `not_ntag424`, `auth:91AE`, `tag_lost`.
  final String? detail;
}

/// The internal personalisation station (Android; platform staff with a station token). The phone relays the
/// server's APDUs to one blank chip after the other; it never sees a key. After each card the station waits for
/// the next one until the operator finishes the batch.
class StationController extends ChangeNotifier {
  StationController({
    required WaiterApi api,
    required NfcRelay nfc,
    required String Function() prompt,
    void Function(ApiFailure failure)? onAuthFailure,
    Duration pause = const Duration(milliseconds: 900),
  }) : _api = api,
       _nfc = nfc,
       _prompt = prompt,
       _onAuthFailure = onAuthFailure,
       _pause = pause;

  final WaiterApi _api;
  final NfcRelay _nfc;
  final String Function() _prompt;
  final void Function(ApiFailure failure)? _onAuthFailure;

  /// Between two cards: the operator takes the card away, and iPhone needs a moment before a new reader session
  /// can start. It also keeps a reader that keeps failing from being restarted in a tight loop.
  final Duration _pause;

  /// Status words after which the next command of a round is sent. 9190 is what a real NTAG 424 DNA answers
  /// to Read_Sig (its originality signature); stopping there left every genuine chip "incomplete".
  static const Set<String> _success = <String>{'9000', '9100', '91AF', '9190'};

  StationPhase _phase = StationPhase.batches;
  List<StationBatch>? _batches;
  bool _loading = false;
  StationFailure? _loadFailure;
  StationBatch? _batch;
  StationOutcome? _last;
  int _finished = 0;
  int _run = 0;
  bool _choosing = false;
  bool _disposed = false;

  StationPhase get phase => _phase;
  List<StationBatch>? get batches => _batches;
  bool get loading => _loading;
  StationFailure? get loadFailure => _loadFailure;
  StationBatch? get batch => _batch;
  StationOutcome? get last => _last;

  /// Cards finished in this batch run.
  int get finished => _finished;

  Future<void> load() async {
    _loading = true;
    _loadFailure = null;
    _notify();
    try {
      _batches = await _api.stationBatches();
    } on ApiFailure catch (e) {
      _loadFailure = _failureOf(e);
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Starts a batch run: waits for cards until [finish]. A second tap on a batch row while one run starts or
  /// runs is ignored (two runs would fight over the one reader: "busy", shown as a failed card).
  Future<void> choose(StationBatch batch) async {
    if (_choosing || _batch != null) return;
    _choosing = true;
    final NfcAvailability availability;
    try {
      availability = await _nfc.availability();
    } finally {
      _choosing = false;
    }
    if (_disposed) return;
    if (availability != NfcAvailability.ready) {
      _last = StationOutcome.failed(
        availability == NfcAvailability.disabled ? StationFailure.nfcOff : StationFailure.nfcUnsupported,
      );
      _notify();
      return;
    }
    _batch = batch;
    _last = null;
    _finished = 0;
    final int run = ++_run;
    unawaited(_cards(run));
  }

  /// Back to the list; a card session still open is closed.
  Future<void> finish() async {
    _run++;
    if (_phase == StationPhase.waiting) unawaited(_nfc.cancel());
    _batch = null;
    _phase = StationPhase.batches;
    _last = null;
    _notify();
    await load();
  }

  Future<void> _cards(int run) async {
    while (!_disposed && run == _run) {
      _phase = StationPhase.waiting;
      _notify();
      final CardLink link;
      try {
        link = await _nfc.start(prompt: _prompt());
      } on NfcRelayException catch (e) {
        if (run != _run || _disposed) return;
        if (e.failure == NfcFailure.cancelled || e.failure == NfcFailure.timeout) {
          // iPhone sheet closed: the operator decides (finish or choose again).
          _batch = null;
          _phase = StationPhase.batches;
          _notify();
          return;
        }
        _last = StationOutcome.failed(
          e.failure == NfcFailure.disabled ? StationFailure.nfcOff : StationFailure.tagLost,
        );
        _notify();
        if (e.failure == NfcFailure.disabled || e.failure == NfcFailure.unsupported) {
          _phase = StationPhase.batches;
          _batch = null;
          _notify();
          return;
        }
        await Future<void>.delayed(_pause);
        continue;
      }
      if (run != _run || _disposed) {
        await link.close();
        return;
      }
      _phase = StationPhase.working;
      _notify();
      final StationOutcome outcome = await _personalize(link, _batch!);
      await link.close(failed: outcome.failure != null);
      if (run != _run || _disposed) return;
      _last = outcome;
      if (outcome.cardNumber != null) _finished++;
      _notify();
      await Future<void>.delayed(_pause);
    }
  }

  Future<StationOutcome> _personalize(CardLink link, StationBatch batch) async {
    try {
      PersonalizationRound round = await _api.beginPersonalization(batch.id, link.uidHex);
      while (!round.done) {
        final List<String> answers = <String>[];
        for (final String command in round.commandsHex) {
          final Uint8List answer = await link.transceive(Ntag424Session.bytesOf(command));
          final String hex = Ntag424Session.hexOf(answer);
          answers.add(hex);
          if (!_success.contains(hex.substring(hex.length - 4))) break;
        }
        round = await _api.continuePersonalization(round.id!, answers);
      }
      return StationOutcome.done(round.cardNumber);
    } on NfcRelayException catch (e) {
      return StationOutcome.failed(StationFailure.tagLost, detail: e.failure.name);
    } on ApiFailure catch (e) {
      return StationOutcome.failed(_failureOf(e), detail: _detailOf(e));
    }
  }

  static String? _detailOf(ApiFailure e) => switch (e) {
    ApiRejected(code: 'CARD_PERSONALIZATION_FAILED') => <String?>[
      e.contextString('reason'),
      e.contextString('detail'),
    ].whereType<String>().join(' · '),
    ApiRejected() => e.code,
    ApiUnauthorized() => e.code,
    _ => null,
  };

  StationFailure _failureOf(ApiFailure e) {
    if (e is ApiTransportFailure) return StationFailure.offline;
    if (e is ApiUnauthorized) {
      _onAuthFailure?.call(e);
      return StationFailure.server;
    }
    if (e is ApiRejected) {
      if (e.code == 'CARD_PERSONALIZATION_FAILED') {
        final String reason = e.contextString('reason') ?? '';
        // Never keyable: foreign keys, not an NTAG 424 DNA, not a genuine NXP chip, failed before. Set aside.
        if (const <String>{'auth:91AE', 'not_ntag424', 'not_genuine', 'qa_failed'}.contains(reason)) {
          return StationFailure.unknownChip;
        }
        if (reason == 'other_batch' || reason == 'already_personalized') return StationFailure.rejected;
        return StationFailure.refused;
      }
      if (e.status == 403) _onAuthFailure?.call(e);
      return StationFailure.server;
    }
    return StationFailure.server;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_phase == StationPhase.waiting) unawaited(_nfc.cancel());
    _disposed = true;
    _run++;
    super.dispose();
  }
}
