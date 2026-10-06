import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/cards/card_pickup.dart';
import 'package:giftcard_waiter/core/cards/card_presenter.dart';

import '../../support/app_harness.dart';

/// Handing out the gift card of an online voucher (online sales, decision 2026-10-06), Android and iPhone alike: the
/// e-mailed QR is scanned with purpose `pickup`, a stock card is tapped (`bind`), and the server moves the voucher
/// to the card. The phone never decides; it says why when the server refuses.
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

  Map<String, Object?> pickupPresentment({Map<String, Object?>? pickup = const <String, Object?>{'open': true, 'from': '2026-10-05T12:00:00Z'}}) {
    final Map<String, Object?> p = Payloads.presentment(balance: 5000);
    final Map<String, Object?> data = Map<String, Object?>.of(p['data']! as Map<String, Object?>);
    data['purpose'] = 'pickup';
    data['voucher'] = <String, Object?>{...data['voucher']! as Map<String, Object?>, 'card_pickup': pickup};
    return <String, Object?>{'data': data};
  }

  CardPickupController controller({DateTime? now}) => CardPickupController(
    api: app.services.api,
    cards: CardPresenter(api: app.services.api, nfc: app.nfc),
    session: app.session,
    texts: texts,
    clock: () => now ?? DateTime.utc(2026, 10, 6, 12),
  );

  Future<void> started(WidgetTester tester) async {
    app = await TestApp.create(user: Payloads.cardManager(), nfc: FakeNfcRelay());
    unawaited(app.session.start());
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    app.dispose();
    await tester.pump(const Duration(minutes: 2));
  }

  testWidgets('the e-mailed QR, then a stock card: the card takes over the voucher', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', '/presentments', FakeReply(201, pickupPresentment()))
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly(number: 'B-2026-0001-0042')))
      ..on(
        'POST',
        '/vouchers/${Payloads.voucherId}/card-pickup',
        FakeReply(200, <String, Object?>{
          'data': <String, Object?>{
            'id': Payloads.voucherId,
            'balance': 5000,
            'currency': 'EUR',
            'media': <Object?>[
              <String, Object?>{'type': 'printable_qr', 'status': 'revoked', 'card_number': null},
              <String, Object?>{'type': 'nfc_card', 'status': 'active', 'card_number': 'B-2026-0001-0042'},
            ],
          },
        }),
      );
    final CardPickupController c = controller();
    unawaited(c.scanned(Payloads.qr));
    await settle(tester);
    expect(c.voucher?.balance, 5000);
    expect(app.backend.to('POST', '/presentments').single.body!['purpose'], 'pickup');

    unawaited(c.handOut());
    await settle(tester);
    expect(c.done?.cardNumber, 'B-2026-0001-0042');
    expect(c.done?.balance, 5000);
    expect(app.backend.to('POST', begin).single.body!['purpose'], 'bind');
    expect(app.backend.to('POST', '/vouchers/${Payloads.voucherId}/card-pickup').single.body, <String, Object?>{
      'qr_presentment_id': Payloads.presentmentId,
      'presentment_id': Payloads.bindPresentmentId,
    });
    c.dispose();
    await finish(tester);
  });

  testWidgets('no card ordered, already picked up, too early, a printed voucher: each says why, no card is tapped', (
    WidgetTester tester,
  ) async {
    await started(tester);
    app.backend
      ..on('POST', '/presentments', FakeReply(201, pickupPresentment(pickup: null)))
      ..on('POST', '/presentments', FakeReply(201, pickupPresentment(pickup: <String, Object?>{'open': false, 'from': null})))
      ..on('POST', '/presentments', FakeReply(201, pickupPresentment(pickup: <String, Object?>{'open': true, 'from': '2026-10-07T12:00:00Z'})))
      ..on(
        'POST',
        '/presentments',
        FakeReply(422, Payloads.error('PRESENTMENT_METHOD_NOT_ALLOWED', <String, Object?>{'kind': 'digital', 'method': 'printable_qr'})),
      );
    final CardPickupController c = controller();
    final List<CardPickupProblem?> problems = <CardPickupProblem?>[];
    for (int i = 0; i < 4; i++) {
      unawaited(c.scanned(Payloads.qr));
      await settle(tester);
      problems.add(c.problem);
      expect(c.voucher, isNull);
    }
    expect(problems, <CardPickupProblem>[
      CardPickupProblem.noCardOrdered,
      CardPickupProblem.pickedUp,
      CardPickupProblem.tooEarly,
      CardPickupProblem.notOnline,
    ]);
    expect(app.backend.to('POST', begin), isEmpty);
    c.dispose();
    await finish(tester);
  });

  testWidgets('a scan that expired while the card was fetched asks for the QR again', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', '/presentments', FakeReply(201, pickupPresentment()))
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly()))
      ..on(
        'POST',
        '/vouchers/${Payloads.voucherId}/card-pickup',
        FakeReply(422, Payloads.error('PRESENTMENT_INVALID', <String, Object?>{'reason': 'expired'})),
      );
    final CardPickupController c = controller();
    unawaited(c.scanned(Payloads.qr));
    await settle(tester);
    unawaited(c.handOut());
    await settle(tester);
    expect(c.problem, CardPickupProblem.scanAgain);
    expect(c.voucher, isNull);
    expect(c.done, isNull);
    c.dispose();
    await finish(tester);
  });
}
