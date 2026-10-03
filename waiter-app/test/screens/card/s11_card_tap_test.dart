import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/platform/nfc_relay.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/theme/waiter_icons.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/s07_charge.dart';
import 'package:giftcard_waiter/screens/s11_card_tap.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';

/// S05 "Tap card" → S11 → S07, and the S10 card variants, identical on Android and iPhone.
void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  Finder text(String value) => find.text(value, findRichText: true);

  for (final bool ios in <bool>[false, true]) {
    final String platform = ios ? 'iPhone' : 'Android';

    testWidgets('$platform: tap card from S05 to S07', (WidgetTester tester) async {
      final FakeNfcRelay nfc = FakeNfcRelay()..card = null;
      final TestApp app = await TestApp.create(isIos: ios, nfc: nfc);
      app.backend
        ..on('POST', '/presentments/cards', FakeReply(200, Payloads.cardChallenge()))
        ..on('POST', '/presentments/cards/${Payloads.cardAuthentication}', FakeReply(201, Payloads.cardPresentment()));
      await pumpWaiterApp(tester, app);

      await tester.tap(text(en.readyTapCard));
      await settle(tester);
      expect(find.byType(CardTapScreen), findsOneWidget);
      expect(text(en.cardWaiting), findsOneWidget);
      expect(nfc.prompts.single, en.cardWaiting, reason: 'the iPhone sheet shows the same instruction');

      // Nobody taps: closing S11 ends the session.
      await tester.tap(find.bySemanticsLabel(en.commonClose).first);
      await settle(tester, 20);
      expect(find.byType(CardTapScreen), findsNothing);
      expect(nfc.cancels, 1, reason: 'the reader (Android reader mode, iPhone sheet) is stopped');

      nfc.card = FakeCard();
      await tester.tap(text(en.readyTapCard));
      await settle(tester, 20);
      expect(find.byType(ChargeScreen), findsOneWidget);
      expect(nfc.closed.last.message, en.cardDone);
      await finishApp(tester, app);
    });
  }

  // Found in the first iPhone test (2026-10-03): after a card payment the next action opened the QR camera.
  testWidgets('after a card payment the next action is the next card, not the QR camera', (WidgetTester tester) async {
    final FakeNfcRelay nfc = FakeNfcRelay()..card = FakeCard();
    final TestApp app = await TestApp.create(nfc: nfc);
    app.backend
      ..on('POST', '/presentments/cards', FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', '/presentments/cards/${Payloads.cardAuthentication}', FakeReply(201, Payloads.cardPresentment()))
      ..on(
        'POST',
        '/vouchers/${Payloads.voucherId}/redemptions',
        FakeReply(201, Payloads.redeemed(amount: 100, balanceAfter: 4900)),
      );
    await pumpWaiterApp(tester, app);

    expect(text('Pay with card'), findsOneWidget, reason: 'the button names the action: top-up taps the card too');
    await tester.tap(text(en.readyTapCard));
    await settle(tester, 20);
    expect(find.byType(ChargeScreen), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(Keypad), matching: text('1')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.descendant(of: find.byType(Keypad), matching: text('00')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find.ancestor(of: find.textContaining('Redeem', findRichText: true), matching: find.byType(PrimaryButton)).first,
    );
    await settle(tester);
    expect(app.loop.state, isA<SuccessState>());
    await tester.pump(const Duration(milliseconds: 600));

    final PrimaryButton next = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(next.label, en.successNextCard);
    expect(next.icon, WaiterIcon.nfcArcs);
    await tester.tap(find.byType(PrimaryButton));
    await settle(tester, 20);
    expect(app.loop.state, isNot(isA<QrScanState>()));
    expect(nfc.prompts.length, 2, reason: 'the card reader opens again');
    await finishApp(tester, app);
  });

  testWidgets('no "Tap card" on a phone without NFC', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(nfc: FakeNfcRelay(available: NfcAvailability.unsupported));
    await pumpWaiterApp(tester, app);
    expect(text(en.readyTapCard), findsNothing);
    expect(text(en.readyScan), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets('S10: a blocked card, a card moved away, NFC off', (WidgetTester tester) async {
    final FakeNfcRelay nfc = FakeNfcRelay()..card = (FakeCard()..loseOn = '9071');
    final TestApp app = await TestApp.create(nfc: nfc);
    app.backend.on(
      'POST',
      '/presentments/cards',
      FakeReply(422, Payloads.error('CARD_NOT_USABLE', <String, Object?>{'reason': 'state', 'state': 'suspended'})),
    );
    await pumpWaiterApp(tester, app);

    await tester.tap(text(en.readyTapCard));
    await settle(tester, 20);
    expect(text(en.problemCardMovedTitle), findsOneWidget);
    expect(find.byWidgetPredicate((Widget w) => w is PrimaryButton && w.label == en.commonTapAgain), findsOneWidget);

    nfc.card = FakeCard();
    await tester.tap(text(en.commonTapAgain));
    await settle(tester, 20);
    expect(text(en.problemCardNotUsableTitle), findsOneWidget);
    expect(text(en.problemCardNotUsableSuspended), findsOneWidget);

    await tester.tap(text(en.commonDone));
    await settle(tester, 20);
    nfc.startFailure = NfcFailure.disabled;
    await tester.tap(text(en.readyTapCard));
    await settle(tester, 20);
    expect(text(en.problemNfcOffTitle), findsOneWidget);
    await finishApp(tester, app);
  });
}
