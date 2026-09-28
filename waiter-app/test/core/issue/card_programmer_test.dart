import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/issue/card_programmer.dart';
import 'package:giftcard_waiter/core/platform/tag_writer.dart';

import '../../support/app_harness.dart';

/// S20 programming engine: the dashboard's write → read back → verify → bind workflow on the phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestApp app;
  late FakeTagWriter writer;
  late CardProgrammer programmer;
  late ProgramCancel cancel;

  setUp(() async {
    writer = FakeTagWriter();
    app = await TestApp.create(user: Payloads.manager(), tagWriter: writer);
    programmer = CardProgrammer(writer: writer, api: app.services.api);
    cancel = ProgramCancel();
  });

  tearDown(() => app.dispose());

  Future<ProgramOutcome> run({bool lock = false, List<ProgramProgress>? progress}) {
    final Future<ProgramOutcome> result = programmer.program(
      cardId: Payloads.newCardId,
      expectedUrl: Payloads.newCardUrl,
      attemptId: '11111111-2222-4333-8444-555555555555',
      lock: lock,
      cancel: cancel,
      tags: writer.tags,
      onProgress: progress?.add,
    );
    scheduleMicrotask(writer.tap);
    return result;
  }

  String path(String suffix) => '/cards/${Payloads.newCardId}$suffix';

  test('blank NTAG215: check → write → read back → verify → bind', () async {
    app.backend
      ..on('POST', path('/nfc/check'), FakeReply(200, Payloads.tagCheck()))
      ..on('POST', path('/nfc'), FakeReply(200, const <String, Object?>{'data': <String, Object?>{}}));
    final List<ProgramProgress> progress = <ProgramProgress>[];

    final ProgramOutcome outcome = await run(progress: progress);

    expect(outcome, isA<TagProgrammed>());
    expect((outcome as TagProgrammed).tagType, 'ntag215');
    expect(outcome.uid, '04A23F1B6C8012');
    expect(writer.calls, <String>['inspect', 'write:${Payloads.newCardUrl}', 'read']);
    expect(progress.map((ProgramProgress p) => p.step).toSet(), <ProgramStep>{
      ProgramStep.waiting,
      ProgramStep.checking,
      ProgramStep.writing,
      ProgramStep.verifying,
      ProgramStep.saving,
    });

    final Map<String, Object?> check = app.backend.to('POST', path('/nfc/check')).single.body!;
    expect(check['uid'], '04A23F1B6C8012');
    expect(check['attempt_id'], '11111111-2222-4333-8444-555555555555');
    final Map<String, Object?> bind = app.backend.to('POST', path('/nfc')).single.body!;
    expect(bind['method'], 'web_nfc');
    expect(bind['tag_type'], 'ntag215');
    expect(bind['uid'], '04A23F1B6C8012');
    expect(bind['read_back'], <String, Object?>{'uid': '04:A2:3F:1B:6C:80:12', 'url': Payloads.newCardUrl});
    expect(app.backend.to('POST', path('/nfc/attempts')), isEmpty);
  });

  test('a tag of another card is refused before anything is written', () async {
    app.backend.on(
      'POST',
      path('/nfc/check'),
      FakeReply(
        200,
        Payloads.tagCheck(status: 'refused', reason: 'TAG_LINKED_TO_OTHER_CARD', conflict: '5285 1058 7098 6488'),
      ),
    );

    await expectLater(
      run(),
      throwsA(
        isA<ProgrammingException>()
            .having((ProgrammingException e) => e.code, 'code', 'TAG_LINKED_TO_OTHER_CARD')
            .having((ProgrammingException e) => e.conflictCardNumber, 'conflict', '5285 1058 7098 6488'),
      ),
    );
    expect(writer.calls, isEmpty);
    expect(app.backend.to('POST', path('/nfc')), isEmpty);
    expect(app.backend.to('POST', path('/nfc/attempts')), isEmpty, reason: 'the server logged the refusal itself');
  });

  test('a chip other than NTAG213/215/216 (e.g. NTAG 424 DNA) is refused and reported', () async {
    writer.type = null;
    app.backend
      ..on('POST', path('/nfc/check'), FakeReply(200, Payloads.tagCheck()))
      ..on('POST', path('/nfc/attempts'), FakeReply(201, const <String, Object?>{}));

    await expectLater(
      run(),
      throwsA(isA<ProgrammingException>().having((ProgrammingException e) => e.code, 'code', 'TAG_UNSUPPORTED')),
    );
    expect(writer.written, isNull);
    final Map<String, Object?> report = app.backend.to('POST', path('/nfc/attempts')).single.body!;
    expect(report['result'], 'refused');
    expect(report['error_code'], 'TAG_UNSUPPORTED');
    expect(report['stage'], 'detect');
  });

  test('a read-back that differs is never saved', () async {
    writer.readBackUrl = 'https://cards.example.at/c/some-other-card';
    app.backend
      ..on('POST', path('/nfc/check'), FakeReply(200, Payloads.tagCheck()))
      ..on('POST', path('/nfc/attempts'), FakeReply(201, const <String, Object?>{}));

    await expectLater(
      run(),
      throwsA(isA<ProgrammingException>().having((ProgrammingException e) => e.code, 'code', 'URL_MISMATCH')),
    );
    expect(app.backend.to('POST', path('/nfc')), isEmpty);
    expect(app.backend.to('POST', path('/nfc/attempts')).single.body!['stage'], 'verify');
  });

  test('a different chip on the read-back is never saved', () async {
    writer.readBackUid = '04:00:00:00:00:00:01';
    app.backend
      ..on('POST', path('/nfc/check'), FakeReply(200, Payloads.tagCheck()))
      ..on('POST', path('/nfc/attempts'), FakeReply(201, const <String, Object?>{}));

    await expectLater(
      run(),
      throwsA(isA<ProgrammingException>().having((ProgrammingException e) => e.code, 'code', 'TAG_SWAPPED')),
    );
    expect(app.backend.to('POST', path('/nfc')), isEmpty);
  });

  test('tag lifted during the write: re-tap of the same tag continues', () async {
    writer.failNext['write'] = <TagIoException>[const TagIoException('TAG_LOST')];
    app.backend
      ..on('POST', path('/nfc/check'), FakeReply(200, Payloads.tagCheck()))
      ..on('POST', path('/nfc'), FakeReply(200, const <String, Object?>{'data': <String, Object?>{}}));
    final List<ProgramProgress> progress = <ProgramProgress>[];
    final Future<ProgramOutcome> result = run(progress: progress);
    await pumpEventQueue();
    expect(progress.last.retap, isTrue);
    writer.tap();

    expect(await result, isA<TagProgrammed>());
    expect(writer.calls.where((String c) => c.startsWith('write')).length, 2);
  });

  test('a different tag after the re-tap is refused', () async {
    writer.failNext['write'] = <TagIoException>[const TagIoException('TAG_LOST')];
    app.backend
      ..on('POST', path('/nfc/check'), FakeReply(200, Payloads.tagCheck()))
      ..on('POST', path('/nfc/attempts'), FakeReply(201, const <String, Object?>{}));
    final Future<ProgramOutcome> result = run();
    await pumpEventQueue();
    writer.tap(uid: '04:99:99:99:99:99:99');

    await expectLater(
      result,
      throwsA(isA<ProgrammingException>().having((ProgrammingException e) => e.code, 'code', 'TAG_SWAPPED')),
    );
  });

  test('restaurant locks tags: the verified tag is made read-only and confirmed', () async {
    app.backend
      ..on('POST', path('/nfc/check'), FakeReply(200, Payloads.tagCheck()))
      ..on('POST', path('/nfc'), FakeReply(200, const <String, Object?>{'data': <String, Object?>{}}))
      ..on('POST', path('/nfc/lock'), FakeReply(200, const <String, Object?>{'data': <String, Object?>{}}));

    final ProgramOutcome outcome = await run(lock: true);

    expect(outcome.locked, isTrue);
    expect(writer.calls.last, 'lock');
    expect(app.backend.to('POST', path('/nfc/lock')), hasLength(1));
  });

  test('no answer from the server during the check: NETWORK, nothing written', () async {
    app.backend
      ..on('POST', path('/nfc/check'), FakeReply.transport())
      ..on('POST', path('/nfc/attempts'), FakeReply.transport());

    await expectLater(
      run(),
      throwsA(isA<ProgrammingException>().having((ProgrammingException e) => e.code, 'code', 'NETWORK')),
    );
    expect(writer.calls, isEmpty);
  });

  test('cancel while waiting for the tag ends without any request', () async {
    final Future<ProgramOutcome> result = programmer.program(
      cardId: Payloads.newCardId,
      expectedUrl: Payloads.newCardUrl,
      attemptId: '11111111-2222-4333-8444-555555555555',
      lock: false,
      cancel: cancel,
      tags: writer.tags,
    );
    cancel.cancel();
    await expectLater(
      result,
      throwsA(isA<ProgrammingException>().having((ProgrammingException e) => e.code, 'code', 'CANCELLED')),
    );
    expect(app.backend.requests.where((RecordedRequest r) => r.path.startsWith('/cards')), isEmpty);
  });
}
