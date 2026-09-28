import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/api/models.dart';
import 'package:giftcard_waiter/core/issue/issue_controller.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';

import '../../support/app_harness.dart';

/// S20 state machine: amount → POST /cards (idempotent) → tag → done; access failures go to the session,
/// "not allowed to sell" does not block the app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;
  late FakeTagWriter writer;
  late IssueController c;
  bool started = false;

  Future<void> start({Map<String, Object?>? user}) async {
    writer = FakeTagWriter();
    app = await TestApp.create(user: user ?? Payloads.manager(), tagWriter: writer);
    await app.session.start();
    c = IssueController(api: app.services.api, writer: writer, nfc: app.nfc, session: app.session);
    started = true;
  }

  tearDown(() {
    if (!started) return;
    started = false;
    c.dispose();
    app.dispose();
  });

  void type(String digits) {
    for (final int d in digits.split('').map(int.parse)) {
      c.digit(d);
    }
  }

  test('the profile decides who sees S20: managers and owners with both abilities', () {
    expect(SessionUser.fromJson(Payloads.manager()).canIssueCards, isTrue);
    expect(SessionUser.fromJson(Payloads.manager(role: 'owner')).canIssueCards, isTrue);
    expect(
      SessionUser.fromJson(Payloads.manager(issuing: false)).canIssueCards,
      isFalse,
      reason: 'token issued before the update',
    );
    expect(SessionUser.fromJson(Payloads.manager(role: 'waiter')).canIssueCards, isFalse);
    expect(SessionUser.fromJson(Payloads.user()).canIssueCards, isFalse);
    // Cached profile survives a restart with its role.
    expect(SessionUser.fromJson(SessionUser.fromJson(Payloads.manager()).toJson()).canIssueCards, isTrue);
  });

  test('create: value, active, guest e-mail and an idempotency key; then programming starts', () async {
    await start();
    app.backend.on('POST', '/cards', FakeReply(201, Payloads.issued()));
    type('5000');
    c.setEmail(' guest@example.at ');

    await c.create();

    final RecordedRequest r = app.backend.to('POST', '/cards').single;
    expect(r.body, <String, Object?>{
      'value': 5000,
      'activate': true,
      'customer': <String, Object?>{'email': 'guest@example.at'},
    });
    expect(r.header('Idempotency-Key'), isNotEmpty);
    expect(c.state, isA<IssueProgramming>());
    expect((c.state as IssueProgramming).card.cardNumber, '1268 8343 1352 0042');
    await pumpEventQueue();
    expect(writer.enabled, isTrue, reason: 'writer mode on: tags are programmed, never looked up');
  });

  test('no answer: "Try again" repeats the same key, so the card is never sold twice', () async {
    await start();
    app.backend
      ..on('POST', '/cards', FakeReply(500, Payloads.error('SERVER_ERROR')))
      ..on('POST', '/cards', FakeReply(200, Payloads.issued(replayed: true)));
    type('2500');

    await c.create();
    expect(c.state, isA<IssueCreateProblem>());
    expect((c.state as IssueCreateProblem).kind, CreateProblemKind.uncertain);

    await c.create();
    final List<RecordedRequest> calls = app.backend.to('POST', '/cards');
    expect(calls, hasLength(2));
    expect(calls[0].header('Idempotency-Key'), calls[1].header('Idempotency-Key'));
    expect(c.state, isA<IssueProgramming>());
  });

  test('403 shows "not allowed" on S20 and does not block the app', () async {
    await start();
    app.backend.on('POST', '/cards', FakeReply(403, Payloads.error('FORBIDDEN')));
    type('5000');

    await c.create();

    expect((c.state as IssueCreateProblem).kind, CreateProblemKind.notAllowed);
    expect(app.session.phase, AccessPhase.active);
  });

  test('value outside the restaurant range: back to the entry with the limits', () async {
    await start();
    app.backend.on(
      'POST',
      '/cards',
      FakeReply(422, Payloads.error('INVALID_AMOUNT', <String, Object?>{'min': 500, 'max': 100000})),
    );
    type('100');

    await c.create();

    final IssueEntry s = c.state as IssueEntry;
    expect(s.rangeMin, 500);
    expect(s.rangeMax, 100000);
    expect(s.amount.cents, 100);
  });

  test('an invalid e-mail is caught before any request', () async {
    await start();
    type('5000');
    c.setEmail('not-an-address');

    await c.create();

    expect((c.state as IssueEntry).emailInvalid, isTrue);
    expect(app.backend.to('POST', '/cards'), isEmpty);
  });

  test('full sale: tag programmed → done with card number and balance; writer off again', () async {
    await start();
    app.backend
      ..on('POST', '/cards', FakeReply(201, Payloads.issued(value: 7500)))
      ..on('POST', '/cards/${Payloads.newCardId}/nfc/check', FakeReply(200, Payloads.tagCheck()))
      ..on(
        'POST',
        '/cards/${Payloads.newCardId}/nfc',
        FakeReply(200, const <String, Object?>{'data': <String, Object?>{}}),
      );
    type('7500');

    await c.create();
    await pumpEventQueue();
    writer.tap();
    await pumpEventQueue();

    final IssueDone done = c.state as IssueDone;
    expect(done.programmed, isTrue);
    expect(done.card.balance, 7500);
    expect(writer.enabled, isFalse);
    expect(app.backend.to('POST', '/scan'), isEmpty, reason: 'redemption flow untouched');
  });

  test('tag problem → "Program later" keeps the card without a tag', () async {
    await start();
    writer.type = null;
    app.backend
      ..on('POST', '/cards', FakeReply(201, Payloads.issued()))
      ..on('POST', '/cards/${Payloads.newCardId}/nfc/check', FakeReply(200, Payloads.tagCheck()))
      ..on('POST', '/cards/${Payloads.newCardId}/nfc/attempts', FakeReply(201, const <String, Object?>{}));
    type('5000');
    await c.create();
    await pumpEventQueue();
    writer.tap();
    await pumpEventQueue();
    expect((c.state as IssueTagProblem).error.code, 'TAG_UNSUPPORTED');

    await c.programLater();

    expect((c.state as IssueDone).programmed, isFalse);
    expect(writer.enabled, isFalse);
  });
}
