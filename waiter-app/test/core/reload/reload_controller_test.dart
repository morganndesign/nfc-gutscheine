import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/api/models.dart';
import 'package:giftcard_waiter/core/cards/card_presenter.dart';
import 'package:giftcard_waiter/core/reload/reload_controller.dart';

import '../../support/app_harness.dart';

/// Topping up a guest's card at the till: tap the card (its balance shows), enter the amount, say how the guest
/// paid. The tap is the proof the card is there; the server books once per key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String begin = '/presentments/cards';
  const String complete = '/presentments/cards/${Payloads.cardAuthentication}';
  const String reloads = '/vouchers/${Payloads.voucherId}/reloads';
  late TestApp app;
  late DateTime now;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  Future<void> started(WidgetTester tester) async {
    now = DateTime(2026, 10, 2, 12);
    app = await TestApp.create(user: Payloads.reloadManager(), nfc: FakeNfcRelay());
    unawaited(app.session.start());
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    app.dispose();
    await tester.pump(const Duration(minutes: 2));
  }

  void cardAnswers({int times = 1, int balance = 2000}) {
    for (int i = 0; i < times; i++) {
      app.backend
        ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
        ..on('POST', complete, FakeReply(200, Payloads.presentment(balance: balance, id: 'tap-$i')));
    }
  }

  ReloadController controller() => ReloadController(
    api: app.services.api,
    session: app.session,
    cards: CardPresenter(api: app.services.api, nfc: app.nfc),
    texts: (prompt: 'Hold', again: 'Again', checking: 'Checking', done: 'Done', failed: 'Failed'),
    clock: () => now,
  );

  Future<ReloadController> toDetails(WidgetTester tester, {int euros = 30}) async {
    final ReloadController c = controller();
    unawaited(c.tap());
    await settle(tester);
    expect((c.state as ReloadAmount).voucher.balance, 2000);
    for (final String d in '${euros}00'.split('')) {
      c.digit(int.parse(d));
    }
    c.continueToDetails();
    expect(c.state, isA<ReloadDetails>());
    return c;
  }

  testWidgets('tap, amount, payment: booked with the reload tap', (WidgetTester tester) async {
    await started(tester);
    cardAnswers();
    app.backend.on('POST', reloads, FakeReply(201, Payloads.reloaded()));
    final ReloadController c = await toDetails(tester);

    unawaited(c.submit());
    await settle(tester);

    final ReloadDone done = c.state as ReloadDone;
    expect(done.result.amount, 3000);
    expect(done.result.balance, 5000);
    expect(app.backend.to('POST', begin).single.body!['purpose'], 'reload');
    final Map<String, Object?> body = app.backend.to('POST', reloads).single.body!;
    expect(body['amount'], 3000);
    expect(body['presentment_id'], 'tap-0');
    expect(body['payment'], <String, Object?>{'method': 'cash'});
    c.dispose();
    await finish(tester);
  });

  testWidgets('a card terminal top-up needs the receipt reference', (WidgetTester tester) async {
    await started(tester);
    cardAnswers();
    app.backend.on('POST', reloads, FakeReply(201, Payloads.reloaded()));
    final ReloadController c = await toDetails(tester);

    c.chooseMethod(PaymentMethod.cardTerminal);
    unawaited(c.submit());
    await settle(tester);
    expect((c.state as ReloadDetails).referenceMissing, isTrue);
    expect(app.backend.to('POST', reloads), isEmpty);

    c.setReference('TID-4711');
    unawaited(c.submit());
    await settle(tester);
    expect(c.state, isA<ReloadDone>());
    expect(app.backend.to('POST', reloads).single.body!['payment'], <String, Object?>{
      'method': 'card_terminal',
      'reference': 'TID-4711',
    });
    c.dispose();
    await finish(tester);
  });

  testWidgets('a tap older than its validity is confirmed with the card once more', (WidgetTester tester) async {
    await started(tester);
    cardAnswers(times: 2);
    app.backend.on('POST', reloads, FakeReply(201, Payloads.reloaded()));
    final ReloadController c = await toDetails(tester);

    now = now.add(const Duration(seconds: 55));
    unawaited(c.submit());
    await settle(tester);

    expect(c.state, isA<ReloadDone>());
    expect(app.backend.to('POST', begin), hasLength(2));
    expect(app.backend.to('POST', reloads).single.body!['presentment_id'], 'tap-1');
    c.dispose();
    await finish(tester);
  });

  testWidgets('a lost answer is retried with the same key and tap, never booked twice', (WidgetTester tester) async {
    await started(tester);
    cardAnswers();
    app.backend
      ..on('POST', reloads, FakeReply.transport())
      ..on('POST', reloads, FakeReply(200, Payloads.reloaded(replayed: true)));
    final ReloadController c = await toDetails(tester);

    unawaited(c.submit());
    await settle(tester);
    expect((c.state as ReloadProblem).kind, ReloadProblemKind.uncertain);
    expect(c.uncertain, isTrue);

    now = now.add(const Duration(minutes: 5)); // the tap has expired: the replay still needs no new tap
    unawaited(c.submit());
    await settle(tester);

    expect(c.state, isA<ReloadDone>());
    final List<RecordedRequest> sent = app.backend.to('POST', reloads);
    expect(sent, hasLength(2));
    expect(sent[0].headers['Idempotency-Key'], sent[1].headers['Idempotency-Key']);
    expect(sent[1].body!['presentment_id'], 'tap-0');
    expect(app.backend.to('POST', begin), hasLength(1));
    c.dispose();
    await finish(tester);
  });

  testWidgets('the balance limit keeps the amount on the keypad with the room left', (WidgetTester tester) async {
    await started(tester);
    cardAnswers(balance: 45000);
    final ReloadController c = controller();
    unawaited(c.tap());
    await settle(tester);

    for (final int d in <int>[1, 0, 0, 0, 0]) {
      c.digit(d);
    }
    c.continueToDetails();
    final ReloadAmount s = c.state as ReloadAmount;
    expect(s.max, 5000, reason: 'max_voucher_balance 500 € − balance 450 €');
    c.dispose();
    await finish(tester);
  });

  testWidgets('a card suspended after the tap is a card problem and nothing is booked', (WidgetTester tester) async {
    await started(tester);
    cardAnswers();
    app.backend.on(
      'POST',
      reloads,
      FakeReply(422, Payloads.error('PRESENTMENT_INVALID', <String, Object?>{'reason': 'card_not_active'})),
    );
    final ReloadController c = await toDetails(tester);

    unawaited(c.submit());
    await settle(tester);

    final ReloadProblem p = c.state as ReloadProblem;
    expect(p.kind, ReloadProblemKind.card);
    expect(p.card!.failure, CardPresentFailure.notUsable);
    expect(c.uncertain, isFalse);
    c.back();
    expect(c.state, isA<ReloadDetails>());
    c.dispose();
    await finish(tester);
  });

  testWidgets('a blank card (nothing on it) ends in a card problem, never an endless spinner', (
    WidgetTester tester,
  ) async {
    await started(tester);
    for (final String answer in <String>['${'00' * 32}9000', '']) {
      app.nfc.card = FakeCard()..script = (String apdu) => apdu.startsWith('00B00000') ? answer : null;
      final ReloadController c = controller();
      unawaited(c.tap());
      await settle(tester);

      final ReloadProblem p = c.state as ReloadProblem;
      expect(p.kind, ReloadProblemKind.card);
      expect(p.card!.failure, CardPresentFailure.notRecognized);
      expect(app.backend.to('POST', begin), isEmpty, reason: 'nothing is sent to the server');
      expect(app.nfc.closed.last.failed, isTrue);
      c.dispose();
    }
    await finish(tester);
  });

  testWidgets('a waiter-level sign-in is told it may not top up', (WidgetTester tester) async {
    await started(tester);
    cardAnswers();
    app.backend.on('POST', reloads, FakeReply(403, Payloads.error('FORBIDDEN', <String, Object?>{})));
    final ReloadController c = await toDetails(tester);

    unawaited(c.submit());
    await settle(tester);
    expect((c.state as ReloadProblem).kind, ReloadProblemKind.notAllowed);
    c.dispose();
    await finish(tester);
  });
}
