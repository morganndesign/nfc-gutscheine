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

/// Card workflows on the phone (Android and iPhone alike): selling a gift card, confirming a delivery, finding,
/// suspending and replacing a card.
void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  Finder text(String value) => find.text(value, findRichText: true);
  Finder primary(String prefix) =>
      find.byWidgetPredicate((Widget w) => w is PrimaryButton && w.label.startsWith(prefix));

  const String begin = '/presentments/cards';
  const String complete = '/presentments/cards/${Payloads.cardAuthentication}';

  for (final bool ios in <bool>[false, true]) {
    testWidgets('${ios ? 'iPhone' : 'Android'}: a gift card is sold by tapping it after payment', (
      WidgetTester tester,
    ) async {
      final TestApp app = await TestApp.create(isIos: ios, user: Payloads.cardManager(), nfc: FakeNfcRelay());
      app.backend
        ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
        ..on('POST', complete, FakeReply(200, Payloads.cardOnly()))
        ..on('POST', '/vouchers', FakeReply(201, Payloads.soldCard()));
      await pumpWaiterApp(tester, app);

      await tester.tap(text(en.readySell));
      await settle(tester);
      expect(text(en.saleFormTitle), findsOneWidget);
      await tester.tap(text(en.saleFormCard));
      await settle(tester);

      await typeDigits(tester, '5000');
      await tester.tap(primary('Continue'));
      await settle(tester);
      expect(text(en.saleEmailHelper), findsOneWidget, reason: 'a gift card has no QR: the e-mail is the confirmation');
      expect(text(en.saleEmailHelperPdf), findsNothing);
      await tester.tap(primary('Tap card'));
      await settle(tester, 20);

      expect(text(en.saleCardDoneTitle), findsOneWidget);
      expect(text(en.saleCardDoneBody('B-2026-0001-0007')), findsOneWidget);
      expect(app.nfc.prompts.single, en.saleCardTap);
      expect(app.backend.to('POST', '/vouchers').single.body!['form'], 'card');
      await finishApp(tester, app);
    });
  }

  // Found in the first iPhone test (2026-10-04): a sold card only said "cannot be sold"; staff need the reason.
  for (final (String state, String Function(AppLocalizations) body) c in <(String, String Function(AppLocalizations))>[
    ('active', (AppLocalizations l) => l.saleCardAlreadySold),
    ('shipped', (AppLocalizations l) => l.reloadCardNotInStock),
    ('suspended', (AppLocalizations l) => l.problemCardNotUsableSuspended),
    ('other_restaurant', (AppLocalizations l) => l.problemCardNotUsableOtherRestaurant),
    ('replaced', (AppLocalizations l) => l.saleCardNotUsable),
  ]) {
    testWidgets('a card that cannot be sold says why: ${c.$1}', (WidgetTester tester) async {
      final TestApp app = await TestApp.create(user: Payloads.cardManager(), nfc: FakeNfcRelay());
      final Map<String, Object?> context = c.$1 == 'other_restaurant'
          ? <String, Object?>{'reason': 'other_restaurant'}
          : <String, Object?>{'reason': 'state', 'state': c.$1};
      app.backend.on('POST', begin, FakeReply(422, Payloads.error('CARD_NOT_USABLE', context)));
      await pumpWaiterApp(tester, app);

      await tester.tap(text(en.readySell));
      await settle(tester);
      await tester.tap(text(en.saleFormCard));
      await settle(tester);
      await typeDigits(tester, '5000');
      await tester.tap(primary('Continue'));
      await settle(tester);
      await tester.tap(primary('Tap card'));
      await settle(tester, 20);

      expect(text(en.saleCardFailedTitle), findsOneWidget);
      expect(text(c.$2(en)), findsOneWidget);
      expect(app.backend.to('POST', '/vouchers'), isEmpty, reason: 'nothing is sold');
      await finishApp(tester, app);
    });
  }

  testWidgets('without card permissions the sale goes straight to the printed voucher', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(user: Payloads.manager(), nfc: FakeNfcRelay());
    await pumpWaiterApp(tester, app);
    await tester.tap(text(en.readySell));
    await settle(tester);
    expect(find.byType(SellVoucherScreen), findsOneWidget);
    expect(text(en.saleFormTitle), findsNothing);
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
}
