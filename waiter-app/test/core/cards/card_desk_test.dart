import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/cards/card_desk.dart';
import 'package:giftcard_waiter/core/cards/card_presenter.dart';
import 'package:giftcard_waiter/core/sale/sale_controller.dart';
import 'package:giftcard_waiter/core/api/models.dart';

import '../../support/app_harness.dart';

/// The card workflows of a restaurant on the phone: sell a card, confirm a delivery, suspend and replace a card.
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

  SaleController cardSale() => SaleController(
    api: app.services.api,
    session: app.session,
    printer: app.printer,
    form: SaleForm.card,
    cards: presenter(),
    cardTexts: texts,
  );

  Future<void> toDetails(SaleController sale, WidgetTester tester) async {
    sale.digit(5);
    sale.digit(0);
    sale.doubleZero();
    sale.continueToDetails();
    await settle(tester);
  }

  testWidgets('a card sale taps the stock card last and sells it with its bind presentment', (
    WidgetTester tester,
  ) async {
    await started(tester);
    app.backend
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly()))
      ..on('POST', '/vouchers', FakeReply(201, Payloads.soldCard()));
    final SaleController sale = cardSale();
    await toDetails(sale, tester);

    unawaited(sale.sell());
    await settle(tester);

    final SaleDone done = sale.state as SaleDone;
    expect(done.voucher.cardNumber, 'B-2026-0001-0007');
    expect(done.hasQr, isFalse);
    expect(app.backend.to('POST', begin).single.body!['purpose'], 'bind');
    final Map<String, Object?> body = app.backend.to('POST', '/vouchers').single.body!;
    expect(body['form'], 'card');
    expect(body['presentment_id'], Payloads.bindPresentmentId);
    expect(body['value'], 5000);
    sale.dispose();
    await finish(tester);
  });

  testWidgets('a lost answer is retried with the same key and the same tap, never a second card', (
    WidgetTester tester,
  ) async {
    await started(tester);
    app.backend
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly()))
      ..on('POST', '/vouchers', FakeReply.transport())
      ..on('POST', '/vouchers', FakeReply(200, Payloads.soldCard(replayed: true)));
    final SaleController sale = cardSale();
    await toDetails(sale, tester);

    unawaited(sale.sell());
    await settle(tester);
    expect((sale.state as SaleProblem).kind, SaleProblemKind.uncertain);
    unawaited(sale.sell());
    await settle(tester);

    expect(sale.state, isA<SaleDone>());
    final List<RecordedRequest> sales = app.backend.to('POST', '/vouchers');
    expect(sales, hasLength(2));
    expect(sales[0].headers['Idempotency-Key'], sales[1].headers['Idempotency-Key']);
    expect(sales[1].body!['presentment_id'], Payloads.bindPresentmentId);
    expect(app.backend.to('POST', begin), hasLength(1), reason: 'no second tap');
    sale.dispose();
    await finish(tester);
  });

  testWidgets('a card not in stock is a card problem and nothing is sold; tapping again uses a new tap', (
    WidgetTester tester,
  ) async {
    await started(tester);
    app.backend
      ..on(
        'POST',
        begin,
        FakeReply(422, Payloads.error('CARD_NOT_USABLE', <String, Object?>{'reason': 'state', 'state': 'active'})),
      )
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly()))
      ..on(
        'POST',
        '/vouchers',
        FakeReply(422, Payloads.error('PRESENTMENT_INVALID', <String, Object?>{'reason': 'expired'})),
      )
      ..on('POST', '/vouchers', FakeReply(201, Payloads.soldCard()));
    final SaleController sale = cardSale();
    await toDetails(sale, tester);

    unawaited(sale.sell());
    await settle(tester);
    final SaleProblem problem = sale.state as SaleProblem;
    expect(problem.kind, SaleProblemKind.card);
    expect(problem.card!.failure, CardPresentFailure.notUsable);
    expect(app.backend.to('POST', '/vouchers'), isEmpty);

    unawaited(sale.sell());
    await settle(tester);
    expect((sale.state as SaleProblem).kind, SaleProblemKind.failed, reason: 'the presentment expired: definitive');

    unawaited(sale.sell());
    await settle(tester);
    expect(sale.state, isA<SaleDone>());
    expect(app.backend.to('POST', begin), hasLength(3), reason: 'a new tap after the definitive refusal');
    sale.dispose();
    await finish(tester);
  });

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
    ], reason: 'only deliveries still to confirm');
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
    );

    unawaited(desk.find('b-2026-0001-0007 '));
    await settle(tester);
    expect(desk.card!.voucherBalance, 3200);

    unawaited(desk.suspend('Lost'));
    await settle(tester);
    expect(desk.card!.state, 'suspended');
    expect(desk.done, 'suspended');
    expect(app.backend.to('POST', '/cards/B-2026-0001-0007/suspend').single.body, <String, Object?>{'reason': 'Lost'});

    unawaited(desk.replace('Lost'));
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

  testWidgets('an unknown or malformed card number is not sent', (WidgetTester tester) async {
    await started(tester);
    app.backend.on('GET', '/cards/B-2026-0001-0404', FakeReply(404, Payloads.error('NOT_FOUND')));
    final CardLookupController desk = CardLookupController(
      api: app.services.api,
      cards: presenter(),
      session: app.session,
      texts: texts,
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
