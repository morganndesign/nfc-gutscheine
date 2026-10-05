import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/cards/card_desk.dart';
import 'package:giftcard_waiter/core/cards/card_presenter.dart';
import 'package:giftcard_waiter/core/api/models.dart';

import '../../support/app_harness.dart';

/// The card workflows of a restaurant on the phone: confirm a delivery, suspend and replace a card. Selling a card
/// is part of "Karte verkaufen / aufladen" (reload_controller_test).
/// The phone relays the card's answers; the server decides.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String begin = '/presentments/cards';
  const String complete = '/presentments/cards/${Payloads.cardAuthentication}';
  const ({String prompt, String checking, String done, String failed}) texts = (
    prompt: 'Hold',
    checking: 'Checking',
    done: 'Done',
    failed: 'Failed',
  );
  late TestApp app;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  Future<void> started(WidgetTester tester) async {
    app = await TestApp.create(user: Payloads.cardManager(), nfc: FakeNfcRelay());
    unawaited(app.session.start());
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    app.dispose();
    await tester.pump(const Duration(minutes: 2));
  }

  CardPresenter presenter() => CardPresenter(api: app.services.api, nfc: app.nfc);

  testWidgets('a delivery is confirmed with the count and one tapped card of the parcel', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('GET', '/card-batches', FakeReply(200, Payloads.cardBatches()))
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly(state: 'delivered')))
      ..on(
        'POST',
        '/card-batches/b-1/receipt',
        FakeReply(200, <String, Object?>{
          'data': <String, Object?>{'status': 'in_service'},
        }),
      );
    final ReceiveDeliveryController desk = ReceiveDeliveryController(
      api: app.services.api,
      cards: presenter(),
      session: app.session,
      texts: texts,
    );
    unawaited(desk.load());
    await settle(tester);

    expect(desk.batches!.map((CardBatchSummary b) => b.batchCode), <String>[
      'B-2026-0001',
    ], reason: 'only shipped deliveries are still to confirm');
    desk.choose(desk.batches!.single);
    desk.digit(5);
    desk.digit(0);
    unawaited(desk.confirm());
    await settle(tester);

    expect(desk.result, 'in_service');
    expect(app.backend.to('POST', begin).single.body!['purpose'], 'receive');
    expect(app.backend.to('POST', '/card-batches/b-1/receipt').single.body, <String, Object?>{
      'count': 50,
      'presentment_id': Payloads.bindPresentmentId,
    });
    desk.dispose();
    await finish(tester);
  });

  testWidgets('a card is found, suspended and replaced by a tapped stock card', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('GET', '/cards/B-2026-0001-0007', FakeReply(200, Payloads.cardInfo()))
      ..on('POST', '/cards/B-2026-0001-0007/suspend', FakeReply(200, Payloads.cardInfo(state: 'suspended')))
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly(number: 'B-2026-0001-0009')))
      ..on(
        'POST',
        '/cards/B-2026-0001-0007/replacement',
        FakeReply(200, Payloads.cardInfo(number: 'B-2026-0001-0009')),
      );
    final CardLookupController desk = CardLookupController(
      api: app.services.api,
      cards: presenter(),
      session: app.session,
      texts: texts,
      oldCardTexts: texts,
      resumeTexts: texts,
    );

    unawaited(desk.find('b-2026-0001-0007 '));
    await settle(tester);
    expect(desk.card!.voucherBalance, 3200);

    unawaited(desk.suspend('Lost'));
    unawaited(desk.suspend('Lost')); // a double press sends one request
    await settle(tester);
    expect(desk.card!.state, 'suspended');
    expect(desk.done, 'suspended');
    expect(app.backend.to('POST', '/cards/B-2026-0001-0007/suspend').single.body, <String, Object?>{'reason': 'Lost'});

    // Lost (an owner): only the new card is tapped.
    unawaited(desk.replace('Lost', oldCardAtHand: false));
    await settle(tester);
    expect(desk.done, 'replaced');
    expect(desk.replaced, 'B-2026-0001-0007');
    expect(desk.card!.cardNumber, 'B-2026-0001-0009');
    expect(app.backend.to('POST', begin).single.body!['purpose'], 'bind');
    expect(app.backend.to('POST', '/cards/B-2026-0001-0007/replacement').single.body, <String, Object?>{
      'presentment_id': Payloads.bindPresentmentId,
      'reason': 'Lost',
    });
    desk.dispose();
    await finish(tester);
  });

  testWidgets('a damaged card is tapped before the stock card and both presentments are sent', (WidgetTester tester) async {
    await started(tester);
    const String surrenderId = '01a0f000-0000-7000-8000-0000000005d0';
    app.backend
      ..on('GET', '/cards/B-2026-0001-0007', FakeReply(200, Payloads.cardInfo()))
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly(id: surrenderId, state: 'active')))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly(number: 'B-2026-0001-0009')))
      ..on(
        'POST',
        '/cards/B-2026-0001-0007/replacement',
        FakeReply(200, Payloads.cardInfo(number: 'B-2026-0001-0009')),
      );
    final CardLookupController desk = CardLookupController(
      api: app.services.api,
      cards: presenter(),
      session: app.session,
      texts: texts,
      oldCardTexts: texts,
      resumeTexts: texts,
    );
    unawaited(desk.find('B-2026-0001-0007'));
    await settle(tester);

    unawaited(desk.replace('Damaged', oldCardAtHand: true));
    await settle(tester);
    expect(desk.done, 'replaced');
    expect(app.backend.to('POST', begin).map((RecordedRequest r) => r.body!['purpose']), <String>['surrender', 'bind']);
    expect(app.backend.to('POST', '/cards/B-2026-0001-0007/replacement').single.body, <String, Object?>{
      'presentment_id': Payloads.bindPresentmentId,
      'surrender_presentment_id': surrenderId,
      'reason': 'Damaged',
    });
    expect(desk.tappingFor, CardTapFor.newCard);
    desk.dispose();
    await finish(tester);
  });

  testWidgets('an unknown or malformed card number is not sent', (WidgetTester tester) async {
    await started(tester);
    app.backend.on('GET', '/cards/B-2026-0001-0404', FakeReply(404, Payloads.error('NOT_FOUND')));
    final CardLookupController desk = CardLookupController(
      api: app.services.api,
      cards: presenter(),
      session: app.session,
      texts: texts,
      oldCardTexts: texts,
      resumeTexts: texts,
    );

    unawaited(desk.find('1268834313520042'));
    await settle(tester);
    expect(desk.notFound, isTrue);
    expect(app.backend.requests.where((RecordedRequest r) => r.path.startsWith('/cards')), isEmpty);

    unawaited(desk.find('B-2026-0001-0404'));
    await settle(tester);
    expect(desk.notFound, isTrue);
    expect(desk.card, isNull);
    desk.dispose();
    await finish(tester);
  });

  CardLookupController lookup() => CardLookupController(
    api: app.services.api,
    cards: presenter(),
    session: app.session,
    texts: texts,
    oldCardTexts: texts,
    resumeTexts: texts,
  );

  testWidgets('a found card is resumed only with its own resume tap (K4)', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('GET', '/cards/B-2026-0001-0007', FakeReply(200, Payloads.cardInfo(state: 'suspended')))
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly(state: 'suspended')))
      ..on('POST', '/cards/B-2026-0001-0007/resume', FakeReply(200, Payloads.cardInfo()));
    final CardLookupController desk = lookup();
    unawaited(desk.find('B-2026-0001-0007'));
    await settle(tester);

    unawaited(desk.resume('Found'));
    await tester.pump();
    expect(desk.tappingFor, CardTapFor.resume);
    await settle(tester);
    expect(desk.done, 'resumed');
    expect(desk.card!.state, 'active');
    expect(app.backend.to('POST', begin).single.body!['purpose'], 'resume');
    expect(app.backend.to('POST', '/cards/B-2026-0001-0007/resume').single.body, <String, Object?>{
      'reason': 'Found',
      'presentment_id': Payloads.bindPresentmentId,
    });
    desk.dispose();
    await finish(tester);
  });

  testWidgets('a card of a compromised batch is never resumed, and another tapped card is named (K6, T7)', (
    WidgetTester tester,
  ) async {
    await started(tester);
    app.backend
      ..on('GET', '/cards/B-2026-0001-0007', FakeReply(200, Payloads.cardInfo(state: 'suspended', resumable: false)))
      ..on('GET', '/cards/B-2026-0001-0008', FakeReply(200, Payloads.cardInfo(number: 'B-2026-0001-0008', state: 'suspended')))
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly(state: 'suspended')))
      ..on(
        'POST',
        '/cards/B-2026-0001-0008/resume',
        FakeReply(422, Payloads.error('PRESENTMENT_INVALID', <String, Object?>{'reason': 'other_card'})),
      );
    final CardLookupController desk = lookup();
    unawaited(desk.find('B-2026-0001-0007'));
    await settle(tester);
    expect(desk.card!.resumable, isFalse);
    unawaited(desk.resume('Found'));
    await settle(tester);
    expect(app.backend.to('POST', begin), isEmpty, reason: 'nothing is tapped for a card that is replaced instead');

    unawaited(desk.find('B-2026-0001-0008'));
    await settle(tester);
    unawaited(desk.resume('Found'));
    await settle(tester);
    expect(desk.error, CardDeskError.otherCard);
    expect(desk.done, isNull);
    desk.dispose();
    await finish(tester);
  });

  testWidgets('a replacement whose answer was lost is found booked by reading the card again (K5)', (
    WidgetTester tester,
  ) async {
    await started(tester);
    app.backend
      ..on('GET', '/cards/B-2026-0001-0007', FakeReply(200, Payloads.cardInfo()))
      ..on(
        'GET',
        '/cards/B-2026-0001-0007',
        FakeReply(200, Payloads.cardInfo(state: 'replaced', successor: 'B-2026-0001-0009')),
      )
      ..on('GET', '/cards/B-2026-0001-0009', FakeReply(200, Payloads.cardInfo(number: 'B-2026-0001-0009')))
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly(number: 'B-2026-0001-0009')))
      ..on('POST', '/cards/B-2026-0001-0007/replacement', FakeReply.transport());
    final CardLookupController desk = lookup();
    unawaited(desk.find('B-2026-0001-0007'));
    await settle(tester);

    unawaited(desk.replace('Lost', oldCardAtHand: false));
    await settle(tester);
    expect(desk.error, isNull);
    expect(desk.done, 'replaced');
    expect(desk.replaced, 'B-2026-0001-0007');
    expect(desk.card!.cardNumber, 'B-2026-0001-0009');
    desk.dispose();
    await finish(tester);
  });

  testWidgets('a refused card action says why (T7)', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('GET', '/cards/B-2026-0001-0007', FakeReply(200, Payloads.cardInfo()))
      ..on('GET', '/cards/B-2026-0001-0007', FakeReply(200, Payloads.cardInfo(state: 'revoked')))
      ..on(
        'POST',
        '/cards/B-2026-0001-0007/suspend',
        FakeReply(409, Payloads.error('CARD_STATE_INVALID', <String, Object?>{'state': 'revoked'})),
      )
      ..on('POST', '/cards/B-2026-0001-0007/suspend', FakeReply(403, Payloads.error('FORBIDDEN')));
    final CardLookupController desk = lookup();
    unawaited(desk.find('B-2026-0001-0007'));
    await settle(tester);

    unawaited(desk.suspend('Lost'));
    await settle(tester);
    expect(desk.error, CardDeskError.state);
    expect(desk.card!.state, 'revoked', reason: 'the current state is shown');

    unawaited(desk.suspend('Lost'));
    await settle(tester);
    expect(desk.error, CardDeskError.forbidden);
    desk.dispose();
    await finish(tester);
  });

  test('the card shows when its voucher cannot pay (K11)', () {
    expect(CardInfo.fromJson(Payloads.cardInfo()).voucherProblem, isNull);
    expect(CardInfo.fromJson(Payloads.cardInfo(voucherStatus: 'blocked')).voucherProblem, 'blocked');
    expect(CardInfo.fromJson(Payloads.cardInfo(expired: true)).voucherProblem, 'expired');
    expect(CardInfo.fromJson(Payloads.cardInfo(voucherStatus: 'refunded')).voucherProblem, 'closed');
    expect(CardInfo.fromJson(Payloads.cardInfo(balance: null)).voucherProblem, isNull);
  });

  testWidgets('a receipt whose answer was lost is settled by the batch status (K5)', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('GET', '/card-batches', FakeReply(200, Payloads.cardBatches()))
      ..on(
        'GET',
        '/card-batches',
        FakeReply(200, <String, Object?>{
          'data': <Object?>[
            <String, Object?>{'id': 'b-1', 'batch_code': 'B-2026-0001', 'status': 'on_hold', 'quantity_ordered': 50, 'counts': <String, Object?>{'in_transit': 50, 'available': 0}},
          ],
        }),
      )
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly(state: 'delivered')))
      ..on('POST', '/card-batches/b-1/receipt', FakeReply.transport());
    final ReceiveDeliveryController desk = ReceiveDeliveryController(
      api: app.services.api,
      cards: presenter(),
      session: app.session,
      texts: texts,
    );
    unawaited(desk.load());
    await settle(tester);
    desk.choose(desk.batches!.first);
    desk.digit(4);
    desk.digit(9);
    unawaited(desk.confirm());
    await settle(tester);

    expect(desk.requestFailed, isFalse);
    expect(desk.result, 'on_hold', reason: 'the receipt was booked: the count did not match');
    desk.dispose();
    await finish(tester);
  });
}
