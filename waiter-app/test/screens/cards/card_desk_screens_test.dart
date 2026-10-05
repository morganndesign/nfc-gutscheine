import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/cards/s22_receive_delivery.dart';
import 'package:giftcard_waiter/screens/cards/s23_card_lookup.dart';
import 'package:giftcard_waiter/screens/cards/s25_order_cards.dart';
import 'package:giftcard_waiter/screens/s20_sell_voucher.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import '../charge/charge_harness.dart' show typeDigits;

/// Card workflows on the phone (Android and iPhone alike): where cards are sold, confirming a delivery, finding,
/// suspending and replacing a card.
void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  Finder text(String value) => find.text(value, findRichText: true);
  Finder primary(String prefix) =>
      find.byWidgetPredicate((Widget w) => w is PrimaryButton && w.label.startsWith(prefix));

  const String begin = '/presentments/cards';
  const String complete = '/presentments/cards/${Payloads.cardAuthentication}';

  // Decision 2026-10-05: one place per thing. "Gutschein verkaufen" is the printed voucher, without a choice step;
  // gift cards are sold and topped up under "Karte verkaufen / aufladen" (S24).
  for (final bool ios in <bool>[false, true]) {
    testWidgets('${ios ? 'iPhone' : 'Android'}: selling a voucher opens the printed voucher directly, cards have their own button', (
      WidgetTester tester,
    ) async {
      final TestApp app = await TestApp.create(isIos: ios, user: Payloads.cardManager(), nfc: FakeNfcRelay());
      await pumpWaiterApp(tester, app);
      expect(text(en.reloadReady), findsOneWidget);
      expect(en.reloadReady, 'Sell / top up card');

      await tester.tap(text(en.readySell));
      await settle(tester);
      expect(find.byType(SellVoucherScreen), findsOneWidget);
      expect(text(en.saleAmountLabel), findsOneWidget, reason: 'no "What are you selling?" step');
      expect(text(en.saleCardDoneTitle), findsNothing);
      expect(app.nfc.prompts, isEmpty, reason: 'selling a voucher never waits for a card');
      await finishApp(tester, app);
    });
  }

  testWidgets('without a card reader there is no card button; the voucher sale is the same', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(user: Payloads.manager());
    await pumpWaiterApp(tester, app);
    expect(text(en.reloadReady), findsNothing);
    await tester.tap(text(en.readySell));
    await settle(tester);
    expect(find.byType(SellVoucherScreen), findsOneWidget);
    expect(text(en.saleAmountLabel), findsOneWidget);
    await finishApp(tester, app);
  });

  // Decision 2026-10-04: restaurants order cards in the app (and the dashboard); the platform accepts or declines.
  for (final bool ios in <bool>[false, true]) {
    testWidgets('${ios ? 'iPhone' : 'Android'}: menu › order cards: the last answer, the quantity, sent', (
      WidgetTester tester,
    ) async {
      final TestApp app = await TestApp.create(isIos: ios, user: Payloads.cardManager(), nfc: FakeNfcRelay());
      Map<String, Object?> order(String status, int quantity, [String? reason]) => <String, Object?>{
        'id': 'o-$quantity',
        'quantity': quantity,
        'status': status,
        'decline_reason': reason,
      };
      app.backend
        ..on(
          'GET',
          '/card-orders',
          FakeReply(200, <String, Object?>{
            'data': <Object?>[order('declined', 500, 'Please 100, as agreed.')],
          }),
        )
        ..on('POST', '/card-orders', FakeReply(201, <String, Object?>{'data': order('requested', 100)}));
      await pumpWaiterApp(tester, app);

      await tester.tap(find.bySemanticsLabel(RegExp('^${en.topBarMenu('Mia Manager')}')).first);
      await settle(tester);
      await tester.tap(text(en.menuCardsOrder));
      await settle(tester, 12);
      expect(find.byType(OrderCardsScreen), findsOneWidget);
      expect(text(en.cardsOrderDeclined('Please 100, as agreed.')), findsOneWidget);

      await typeDigits(tester, '1001');
      expect(text('100'), findsOneWidget, reason: 'more than 1,000 cards are not typed');
      await tester.tap(primary(en.cardsOrderSubmit(100)));
      await settle(tester, 12);

      expect(app.backend.to('POST', '/card-orders').single.body, <String, Object?>{'quantity': 100});
      expect(text(en.cardsOrderDone), findsOneWidget);
      await tester.tap(primary(en.commonDone));
      await settle(tester, 12);
      expect(find.byType(OrderCardsScreen), findsNothing);
      await finishApp(tester, app);
    });
  }

  testWidgets('order cards: three open orders say so, nothing else happens', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(user: Payloads.cardManager(), nfc: FakeNfcRelay());
    app.backend
      ..on('GET', '/card-orders', FakeReply(200, <String, Object?>{'data': <Object?>[]}))
      ..on(
        'POST',
        '/card-orders',
        FakeReply(422, Payloads.error('CARD_ORDER_NOT_POSSIBLE', <String, Object?>{'reason': 'too_many_open'})),
      );
    await pumpWaiterApp(tester, app);
    await tester.tap(find.bySemanticsLabel(RegExp('^${en.topBarMenu('Mia Manager')}')).first);
    await settle(tester);
    await tester.tap(text(en.menuCardsOrder));
    await settle(tester, 12);
    await typeDigits(tester, '50');
    await tester.tap(primary(en.cardsOrderSubmit(50)));
    await settle(tester, 12);
    expect(text(en.cardsOrderTooMany), findsOneWidget);
    expect(text(en.cardsOrderDone), findsNothing);
    await finishApp(tester, app);
  });

  testWidgets('menu: confirm a delivery and find a card', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(user: Payloads.cardManager(), nfc: FakeNfcRelay());
    app.backend
      ..on('GET', '/card-batches', FakeReply(200, Payloads.cardBatches()))
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly(state: 'delivered')))
      ..on(
        'POST',
        '/card-batches/b-1/receipt',
        FakeReply(200, <String, Object?>{
          'data': <String, Object?>{'status': 'on_hold'},
        }),
      )
      ..on('GET', '/cards/B-2026-0001-0007', FakeReply(200, Payloads.cardInfo()))
      ..on('POST', '/cards/B-2026-0001-0007/suspend', FakeReply(200, Payloads.cardInfo(state: 'suspended')));
    await pumpWaiterApp(tester, app);

    await tester.tap(find.bySemanticsLabel(RegExp('^${en.topBarMenu('Mia Manager')}')).first);
    await settle(tester);
    await tester.tap(text(en.menuCardsReceive));
    await settle(tester, 12);
    expect(find.byType(ReceiveDeliveryScreen), findsOneWidget);
    await tester.tap(text('B-2026-0001'));
    await settle(tester);
    await typeDigits(tester, '48');
    await tester.tap(primary(en.cardsReceiveContinue(48)));
    await settle(tester, 20);
    expect(text(en.cardsReceiveHold), findsOneWidget);
    await tester.tap(primary(en.commonDone));
    await settle(tester, 12);

    await tester.tap(find.bySemanticsLabel(RegExp('^${en.topBarMenu('Mia Manager')}')).first);
    await settle(tester);
    await tester.tap(text(en.menuCardsFind));
    await settle(tester, 12);
    expect(find.byType(CardLookupScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'B-2026-0001-0007');
    await tester.tap(text(en.cardsFindAction));
    await settle(tester, 12);
    expect(text(en.cardsStateActive), findsOneWidget);
    await tester.tap(text(en.cardsSuspend));
    await settle(tester, 12);
    await tester.tap(text(en.cardsReasonLost));
    await settle(tester, 12);
    expect(text(en.cardsSuspendDone), findsOneWidget);
    expect(text(en.cardsResume), findsOneWidget);

    // A manager replaces only a card that is at hand; lost or stolen is the owner's call.
    await tester.tap(text(en.cardsReplace));
    await settle(tester, 12);
    expect(text(en.cardsReasonDamaged), findsOneWidget);
    expect(text(en.cardsReasonStolen), findsNothing);
    expect(text(en.cardsReplaceOwnerOnly), findsOneWidget);
    await finishApp(tester, app);
  });

  // Decision 2026-10-05: a delivery that arrived shows on the home screen at once, not only in the menu.
  for (final bool ios in <bool>[false, true]) {
    testWidgets('${ios ? 'iPhone' : 'Android'}: an arrived delivery is on the home screen and opens straight to the count', (
      WidgetTester tester,
    ) async {
      final TestApp app = await TestApp.create(isIos: ios, user: Payloads.cardManager(), nfc: FakeNfcRelay());
      app.backend
        ..on('GET', '/card-batches', FakeReply(200, Payloads.cardBatches()))
        ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
        ..on('POST', complete, FakeReply(200, Payloads.cardOnly(state: 'delivered')))
        ..on('POST', '/card-batches/b-1/receipt', FakeReply(200, <String, Object?>{'data': <String, Object?>{'status': 'in_service'}}));
      await pumpWaiterApp(tester, app);
      await settle(tester, 12);

      expect(text(en.readyDeliveryTitle), findsOneWidget);
      expect(text(en.readyDeliveryBody('B-2026-0001', en.cardsReceiveBatch(50))), findsOneWidget);
      await tester.tap(text(en.readyDeliveryAction));
      await settle(tester, 12);
      expect(find.byType(ReceiveDeliveryScreen), findsOneWidget);
      // The one delivery is chosen already: the count comes first, no list.
      await typeDigits(tester, '50');
      await tester.tap(primary(en.cardsReceiveContinue(50)));
      await settle(tester, 20);

      // Received: the notice is gone when the screen closes.
      app.backend.only('GET', '/card-batches', FakeReply(200, <String, Object?>{'data': <Object?>[]}));
      await tester.tap(primary(en.commonDone));
      await settle(tester, 12);
      expect(find.byType(ReceiveDeliveryScreen), findsNothing);
      expect(text(en.readyDeliveryTitle), findsNothing);
      await finishApp(tester, app);
    });
  }

  testWidgets('two deliveries: the notice counts them and opens the list', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(user: Payloads.cardManager(), nfc: FakeNfcRelay());
    final Map<String, Object?> two = Payloads.cardBatches();
    (two['data']! as List<Object?>).add(<String, Object?>{
      'id': 'b-3', 'batch_code': 'B-2026-0003', 'status': 'shipped', 'quantity_ordered': 3,
      'counts': <String, Object?>{'in_transit': 3, 'available': 0},
    });
    app.backend.on('GET', '/card-batches', FakeReply(200, two));
    await pumpWaiterApp(tester, app);
    await settle(tester, 12);

    expect(text(en.readyDeliveryBodyMany(2)), findsOneWidget);
    await tester.tap(text(en.readyDeliveryAction));
    await settle(tester, 12);
    expect(text('B-2026-0001'), findsOneWidget);
    expect(text('B-2026-0003'), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets('waiters never see the notice and the phone never asks', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(user: Payloads.manager(role: 'waiter'), nfc: FakeNfcRelay());
    app.backend.on('GET', '/card-batches', FakeReply(200, Payloads.cardBatches()));
    await pumpWaiterApp(tester, app);
    await settle(tester, 12);
    expect(text(en.readyDeliveryTitle), findsNothing);
    expect(app.backend.to('GET', '/card-batches'), isEmpty);
    await finishApp(tester, app);
  });
}
