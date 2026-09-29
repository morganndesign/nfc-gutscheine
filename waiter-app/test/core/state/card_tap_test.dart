import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/platform/nfc_relay.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';

import '../../support/app_harness.dart';

/// Phase 4 in the app: a physical card is read and challenged through the phone. The app sends the fixed
/// commands, relays the server's command and the card's answer, and never interprets a key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String begin = '/presentments/cards';
  const String complete = '/presentments/cards/${Payloads.cardAuthentication}';
  late TestApp app;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  Future<void> started(WidgetTester tester, {FakeNfcRelay? nfc}) async {
    app = await TestApp.create(nfc: nfc);
    unawaited(app.session.start());
    await settle(tester);
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    app.dispose();
    await tester.pump(const Duration(minutes: 2));
  }

  testWidgets('tap → server challenge relayed → charge with the card voucher', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(201, Payloads.cardPresentment(balance: 4200)));

    app.loop.openCardTap();
    await settle(tester);

    final ChargeState charge = app.loop.state as ChargeState;
    expect(charge.voucher.balance, 4200);
    expect(charge.presentmentId, Payloads.presentmentId);

    // Exactly the fixed commands, then the server's command, byte for byte.
    expect(app.nfc.sent, <String>[
      '00A4040007D276000085010100',
      '00A4000C02E104',
      '00B0000000',
      '9071000002030000',
      '90AF00002035C3E05A752E0144BAC0DE51C1F22C56B34408A23D8AEA266CAB947EA8E0118D00',
    ]);
    expect(app.backend.to('POST', begin).single.body, <String, Object?>{
      'purpose': 'spend',
      'tap_url': FakeCard().tapUrl,
      'rf_uid': '04A39493CC8680',
      'challenge': 'A04C124213C186F22399D33AC2A30215',
    });
    expect(app.backend.to('POST', complete).single.body, <String, Object?>{'response': FakeCard().answerHex});
    expect(app.nfc.closed.single.failed, isFalse);
    await finish(tester);
  });

  testWidgets('a card of another system or an old tag is not recognised; nothing is sent', (WidgetTester tester) async {
    final FakeNfcRelay nfc = FakeNfcRelay()..card = (FakeCard()..refuse = (prefix: '00A40400', sw: '6A82'));
    await started(tester, nfc: nfc);

    app.loop.openCardTap();
    await settle(tester);

    expect((app.loop.state as ProblemState).kind, ProblemKind.cardNotRecognized);
    expect(app.backend.to('POST', begin), isEmpty);
    expect(app.nfc.closed.single.failed, isTrue);
    await finish(tester);
  });

  testWidgets('the card moves away: "Tap card again" starts over', (WidgetTester tester) async {
    final FakeNfcRelay nfc = FakeNfcRelay()..card = (FakeCard()..loseOn = '90AF');
    await started(tester, nfc: nfc);
    app.backend
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(201, Payloads.cardPresentment()));

    app.loop.openCardTap();
    await settle(tester);
    final ProblemState problem = app.loop.state as ProblemState;
    expect(problem.kind, ProblemKind.cardMoved);
    expect(problem.retryCard, isTrue);

    nfc.card = FakeCard();
    app.loop.retryPresent();
    await settle(tester);
    expect(app.loop.state, isA<ChargeState>());
    expect(app.backend.to('POST', begin), hasLength(2), reason: 'a new tap is a new challenge');
    await finish(tester);
  });

  testWidgets('server refusals: card not usable, copied or foreign card, throttled', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on(
        'POST',
        begin,
        FakeReply(422, Payloads.error('CARD_NOT_USABLE', <String, Object?>{'reason': 'state', 'state': 'suspended'})),
      )
      ..on('POST', begin, FakeReply(403, Payloads.error('SUN_REPLAYED')))
      ..on(
        'POST',
        begin,
        FakeReply(429, <String, Object?>{'message': 'x', 'code': 'PRESENTMENT_THROTTLED', 'retry_after': 30}),
      );

    app.loop.openCardTap();
    await settle(tester);
    ProblemState problem = app.loop.state as ProblemState;
    expect(problem.kind, ProblemKind.cardNotUsable);
    expect(problem.cardState, 'suspended');

    app.loop.back();
    app.loop.openCardTap();
    await settle(tester);
    expect((app.loop.state as ProblemState).kind, ProblemKind.cardNotRecognized);

    app.loop.back();
    app.loop.openCardTap();
    await settle(tester);
    problem = app.loop.state as ProblemState;
    expect(problem.kind, ProblemKind.throttled);
    await finish(tester);
  });

  testWidgets('the card answered but the server refuses the answer', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(403, Payloads.error('CARD_AUTHENTICATION_FAILED')));

    app.loop.openCardTap();
    await settle(tester);
    expect((app.loop.state as ProblemState).kind, ProblemKind.cardNotRecognized);
    await finish(tester);
  });

  testWidgets('no connection: "Try again" taps the card again', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', begin, FakeReply.transport())
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(201, Payloads.cardPresentment()));

    app.loop.openCardTap();
    await settle(tester);
    final ProblemState problem = app.loop.state as ProblemState;
    expect(problem.kind, ProblemKind.network);
    expect(problem.retryCard, isTrue);

    app.loop.retryPresent();
    await settle(tester);
    expect(app.loop.state, isA<ChargeState>());
    await finish(tester);
  });

  testWidgets('NFC off, no NFC, or the waiter closes the reader', (WidgetTester tester) async {
    final FakeNfcRelay nfc = FakeNfcRelay()..startFailure = NfcFailure.disabled;
    await started(tester, nfc: nfc);

    app.loop.openCardTap();
    await settle(tester);
    expect((app.loop.state as ProblemState).kind, ProblemKind.nfcOff);

    app.loop.back();
    nfc.startFailure = NfcFailure.unsupported;
    app.loop.openCardTap();
    await settle(tester);
    expect((app.loop.state as ProblemState).kind, ProblemKind.nfcUnsupported);

    app.loop.back();
    nfc.startFailure = NfcFailure.cancelled;
    app.loop.openCardTap();
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    await finish(tester);
  });

  testWidgets('leaving S11 while waiting ends the session; a late card is ignored', (WidgetTester tester) async {
    final FakeNfcRelay nfc = FakeNfcRelay()..card = null;
    await started(tester, nfc: nfc);

    app.loop.openCardTap();
    await settle(tester);
    expect(app.loop.state, isA<CardTapState>());
    expect(nfc.prompts.single, isNotEmpty);

    app.loop.back();
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    nfc.cancelWaiting();
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    expect(app.backend.to('POST', begin), isEmpty);
    await finish(tester);
  });
}
