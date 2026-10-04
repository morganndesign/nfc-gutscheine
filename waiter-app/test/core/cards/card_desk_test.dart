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
    expect(desk.tappingOldCard, isFalse);
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
}
