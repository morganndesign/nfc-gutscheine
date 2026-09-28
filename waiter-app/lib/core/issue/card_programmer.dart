import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_failure.dart';
import '../api/models.dart';
import '../api/waiter_api.dart';
import '../platform/nfc_service.dart';
import '../platform/tag_writer.dart';

/// Steps of S20 programming, in order (the dashboard's workflow, `dashboard/src/lib/nfc-programming.ts`).
enum ProgramStep { waiting, checking, writing, verifying, saving, locking }

@immutable
class ProgramProgress {
  const ProgramProgress(this.step, {this.retap = false});

  final ProgramStep step;

  /// The tag stopped answering: ask for a lift and re-tap.
  final bool retap;
}

@immutable
sealed class ProgramOutcome {
  const ProgramOutcome({required this.uid, required this.locked});

  final String uid;
  final bool locked;
}

/// Written, read back, verified and saved to the card.
final class TagProgrammed extends ProgramOutcome {
  const TagProgrammed({required super.uid, required this.tagType, required super.locked});

  final String tagType;
}

/// The server already has this chip for this card (e.g. the answer of an earlier attempt was lost).
final class TagAlreadyProgrammed extends ProgramOutcome {
  const TagAlreadyProgrammed({required super.uid, required super.locked});
}

/// Nothing was saved to the card. [code] is the dashboard's error code (`TAG_REFUSED`, `CHIP_IN_USE`,
/// `TAG_UNSUPPORTED`, `TAG_READ_ONLY`, `TAG_TOO_SMALL`, `TAG_REMOVED`, `TAG_SWAPPED`, `URL_MISMATCH`,
/// `URL_OUTDATED`, `NETWORK`, `CANCELLED`, or a server code).
class ProgrammingException implements Exception {
  const ProgrammingException(this.code, {this.conflictCardNumber, this.requestId});

  final String code;
  final String? conflictCardNumber;
  final String? requestId;

  @override
  String toString() => 'ProgrammingException($code)';
}

/// Cancels a running [CardProgrammer.program] (S20 closed, "Program later").
class ProgramCancel {
  final Completer<void> _done = Completer<void>();

  bool get isCancelled => _done.isCompleted;

  Future<void> get whenCancelled => _done.future;

  void cancel() {
    if (!_done.isCompleted) _done.complete();
  }
}

/// Programs one card's tag on the phone:
///
///   1. read the tag (UID + current content)
///   2. ask the server whether the chip / the link on it is free        POST /cards/{id}/nfc/check
///   3. refuse tags of other cards before anything is written
///   4. identify the chip (NTAG213/215/216 via GET_VERSION), write the NDEF URL record
///   5. read the tag again (from the chip, not the cache)
///   6. verify: same chip, URL exactly the card's URL
///   7. only now save the UID                                          POST /cards/{id}/nfc
///   8. lock the tag if the restaurant asks for it                     POST /cards/{id}/nfc/lock
///
/// Every attempt has one `attempt_id`; failures the server cannot see are reported to
/// POST /cards/{id}/nfc/attempts. Access failures ([ApiUnauthorized], device revoked, …) are rethrown
/// unchanged so the session handles them.
class CardProgrammer {
  CardProgrammer({required TagWriter writer, required WaiterApi api}) : _writer = writer, _api = api;

  final TagWriter _writer;
  final WaiterApi _api;

  static const Map<String, int> _capacity = <String, int>{'ntag213': 137, 'ntag215': 492, 'ntag216': 868};

  static String normalizeUid(String uid) => uid.replaceAll(RegExp('[^0-9A-Fa-f]'), '').toUpperCase();

  Future<ProgramOutcome> program({
    required String cardId,
    required String expectedUrl,
    required String attemptId,
    required bool lock,
    required ProgramCancel cancel,
    required Stream<NfcWriterTag> tags,
    void Function(ProgramProgress progress)? onProgress,
  }) async {
    String stage = 'read';
    NfcWriterTag? tag;
    String? tagType;
    String? readBackUrl;
    final Stopwatch watch = Stopwatch();
    final Map<String, int> timings = <String, int>{};

    void progress(ProgramStep step, {bool retap = false}) => onProgress?.call(ProgramProgress(step, retap: retap));

    Future<void> report(String result, String code) async {
      try {
        await _api.reportTagFailure(
          cardId: cardId,
          attemptId: attemptId,
          stage: stage,
          result: result,
          errorCode: code,
          uid: tag == null ? null : normalizeUid(tag.uid),
          tagType: tagType,
          previousUrl: tag?.url,
          readBackUrl: readBackUrl,
        );
      } on Object {
        // Logging is best effort; the operator already sees the error.
      }
    }

    // A tag operation; on "tag lost" the operator is asked to re-tap once and the step runs again on the
    // new tag (the writer keeps the latest tag).
    Future<T> onTag<T>(ProgramStep step, Future<T> Function() run) async {
      try {
        return await run();
      } on TagIoException catch (e) {
        if (e.code != 'TAG_LOST' && e.code != 'TIMEOUT' && e.code != 'NO_TAG') rethrow;
        progress(step, retap: true);
        final NfcWriterTag again = await _nextTag(tags, cancel, const Duration(seconds: 20));
        if (normalizeUid(again.uid) != normalizeUid(tag!.uid)) {
          throw const ProgrammingException('TAG_SWAPPED');
        }
        progress(step);
        return run();
      }
    }

    Future<T> server<T>(Future<T> Function() run) async {
      try {
        return await run();
      } on ApiRejected catch (e) {
        if (_isAccess(e)) rethrow;
        // Answered by the server, which logged it.
        throw _Answered(ProgrammingException(e.code, requestId: e.requestId));
      } on ApiUnauthorized {
        rethrow;
      } on ApiFailure catch (e) {
        throw ProgrammingException('NETWORK', requestId: e.requestId);
      }
    }

    try {
      // 1. Read the tag.
      progress(ProgramStep.waiting);
      tag = await _nextTag(tags, cancel, null);
      watch.start();
      final String uid = normalizeUid(tag.uid);

      // 2–3. Server check.
      stage = 'check';
      progress(ProgramStep.checking);
      final NfcCheckResult check = await server(
        () => _api.checkTag(cardId: cardId, attemptId: attemptId, uid: uid, currentUrl: tag!.url),
      );
      timings['check_ms'] = watch.elapsedMilliseconds;
      if (check.status == 'refused') {
        throw _Answered(
          ProgrammingException(check.reason ?? 'TAG_REFUSED', conflictCardNumber: check.conflictCardNumber),
        );
      }
      if (check.status == 'already_programmed') {
        bool locked = check.locked;
        if (lock && !locked) {
          locked = await _lock(cardId, attemptId, onTag, server, () => stage = 'lock', progress, report);
        }
        return TagAlreadyProgrammed(uid: uid, locked: locked);
      }
      if (check.expectedUrl != expectedUrl) throw const ProgrammingException('URL_OUTDATED');

      // 4. Identify the chip, then write.
      stage = 'detect';
      final TagInfo info = await onTag(ProgramStep.writing, _writer.inspect);
      if (info.type == null) throw const ProgrammingException('TAG_UNSUPPORTED');
      tagType = info.type;
      if (!info.writable) throw const ProgrammingException('TAG_READ_ONLY');
      final int capacity = info.maxSize > 0 ? info.maxSize : _capacity[info.type]!;
      if (_urlMessageSize(expectedUrl) > capacity) throw const ProgrammingException('TAG_TOO_SMALL');
      timings['detect_ms'] = watch.elapsedMilliseconds - timings['check_ms']!;

      stage = 'write';
      progress(ProgramStep.writing);
      final int writeStart = watch.elapsedMilliseconds;
      try {
        await onTag(ProgramStep.writing, () => _writer.writeUrl(expectedUrl));
      } on TagIoException catch (e) {
        if (e.code == 'READ_ONLY') throw const ProgrammingException('TAG_READ_ONLY');
        if (e.code == 'TOO_SMALL') throw const ProgrammingException('TAG_TOO_SMALL');
        throw const ProgrammingException('TAG_REMOVED');
      }
      timings['write_ms'] = watch.elapsedMilliseconds - writeStart;

      // 5–6. Read back and verify.
      stage = 'verify';
      progress(ProgramStep.verifying);
      final int verifyStart = watch.elapsedMilliseconds;
      final NfcTagRead back;
      try {
        back = await onTag(ProgramStep.verifying, _writer.readBack);
      } on TagIoException {
        throw const ProgrammingException('TAG_REMOVED');
      }
      readBackUrl = back.url;
      timings['verify_ms'] = watch.elapsedMilliseconds - verifyStart;
      if (normalizeUid(back.uid) != uid) throw const ProgrammingException('TAG_SWAPPED');
      if (back.url != expectedUrl) throw const ProgrammingException('URL_MISMATCH');

      // 7. Save the chip — the server compares URL and chip once more.
      stage = 'bind';
      progress(ProgramStep.saving);
      timings['total_ms'] = watch.elapsedMilliseconds;
      await server(
        () => _api.bindTag(
          cardId: cardId,
          attemptId: attemptId,
          tagType: info.type!,
          uid: uid,
          readBackUid: back.uid,
          readBackUrl: back.url ?? '',
          timings: timings,
        ),
      );

      // 8. Lock (optional). A lock error leaves a verified, writable tag.
      final bool locked = lock && await _lock(cardId, attemptId, onTag, server, () => stage = 'lock', progress, report);
      return TagProgrammed(uid: uid, tagType: info.type!, locked: locked);
    } on _Answered catch (e) {
      throw e.error;
    } on _Cancelled {
      if (tag != null) await report('cancelled', 'CANCELLED');
      throw const ProgrammingException('CANCELLED');
    } on ProgrammingException catch (e) {
      if (e.code != 'NETWORK') {
        final bool wrongTag = e.code == 'TAG_UNSUPPORTED' || e.code == 'TAG_READ_ONLY' || e.code == 'TAG_TOO_SMALL';
        await report(wrongTag ? 'refused' : 'failed', e.code);
      } else {
        await report('failed', 'NETWORK');
      }
      rethrow;
    } on TagIoException catch (e) {
      final String code = e.code == 'NOT_AVAILABLE' ? 'NFC_UNAVAILABLE' : 'TAG_REMOVED';
      await report('failed', code);
      throw ProgrammingException(code);
    }
  }

  Future<bool> _lock(
    String cardId,
    String attemptId,
    Future<T> Function<T>(ProgramStep, Future<T> Function()) onTag,
    Future<T> Function<T>(Future<T> Function()) server,
    void Function() setStage,
    void Function(ProgramStep step, {bool retap}) progress,
    Future<void> Function(String result, String code) report,
  ) async {
    setStage();
    progress(ProgramStep.locking);
    try {
      await onTag(ProgramStep.locking, _writer.lock);
      await server(() => _api.confirmTagLock(cardId: cardId, attemptId: attemptId));
      return true;
    } on ApiUnauthorized {
      rethrow;
    } on ApiRejected catch (e) {
      if (_isAccess(e)) rethrow;
      return false;
    } on Object {
      await report('failed', 'LOCK_FAILED');
      return false;
    }
  }

  static bool _isAccess(ApiRejected e) =>
      e.code == 'DEVICE_REVOKED' || e.code == 'RESTAURANT_SUSPENDED' || e.code == 'ACCOUNT_LOCKED';

  static Future<NfcWriterTag> _nextTag(Stream<NfcWriterTag> tags, ProgramCancel cancel, Duration? timeout) {
    final Completer<NfcWriterTag> done = Completer<NfcWriterTag>();
    late final StreamSubscription<NfcWriterTag> sub;
    sub = tags.listen((NfcWriterTag t) {
      if (!done.isCompleted) done.complete(t);
    });
    unawaited(
      cancel.whenCancelled.then((_) {
        if (!done.isCompleted) done.completeError(const _Cancelled());
      }),
    );
    Future<NfcWriterTag> result = done.future;
    if (timeout != null) {
      result = result.timeout(timeout, onTimeout: () => throw const ProgrammingException('TAG_REMOVED'));
    }
    return result.whenComplete(sub.cancel);
  }

  /// NDEF message size of one URI record (short record; URI prefix abbreviated as Android does).
  static int _urlMessageSize(String url) {
    const List<String> prefixes = <String>['https://www.', 'http://www.', 'https://', 'http://'];
    final String prefix = prefixes.firstWhere(url.startsWith, orElse: () => '');
    final int payload = 1 + (url.length - prefix.length);
    return 3 + 1 + payload + (payload > 255 ? 3 : 0);
  }
}

class _Answered implements Exception {
  const _Answered(this.error);

  final ProgrammingException error;
}

class _Cancelled implements Exception {
  const _Cancelled();
}
