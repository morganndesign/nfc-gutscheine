import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/cards/s22_receive_delivery.dart';
import 'package:giftcard_waiter/screens/cards/s23_card_lookup.dart';
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
      await tester.tap(primary('Tap card'));
      await settle(tester, 20);

      expect(text(en.saleCardDoneTitle), findsOneWidget);
      expect(text(en.saleCardDoneBody('B-2026-0001-0007')), findsOneWidget);
      expect(app.nfc.prompts.single, en.saleCardTap);
      expect(app.backend.to('POST', '/vouchers').single.body!['form'], 'card');
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
    await finishApp(tester, app);
  });
}
