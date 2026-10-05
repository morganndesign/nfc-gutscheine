import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/platform/nfc_relay.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import '../charge/charge_harness.dart' show typeDigits;

/// S24 · Sell / top up card, Android and iPhone alike: the button shows for managers and owners on a phone that reads
/// cards; tap the guest's card → amount → payment → booked.
void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  Finder text(String value) => find.text(value, findRichText: true);
  Finder primary(String prefix) =>
      find.byWidgetPredicate((Widget w) => w is PrimaryButton && w.label.startsWith(prefix));

  const String begin = '/presentments/cards';
  const String complete = '/presentments/cards/${Payloads.cardAuthentication}';
  const String reloads = '/vouchers/${Payloads.voucherId}/reloads';

  for (final bool ios in <bool>[false, true]) {
    testWidgets('${ios ? 'iPhone' : 'Android'}: a manager taps the guest\'s card and tops it up', (
      WidgetTester tester,
    ) async {
      final TestApp app = await TestApp.create(isIos: ios, user: Payloads.reloadManager(), nfc: FakeNfcRelay());
      app.backend
        ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
        ..on('POST', complete, FakeReply(200, Payloads.cardPresentment(balance: 2000)))
        ..on('POST', reloads, FakeReply(201, Payloads.reloaded()));
      await pumpWaiterApp(tester, app);

      await tester.tap(text(en.reloadReady));
      await settle(tester, 20);
      expect(app.nfc.prompts.single, en.reloadTap);
      expect(find.byType(BalanceCard), findsOneWidget);

      await typeDigits(tester, '3000');
      await tester.tap(primary('Continue'));
      await settle(tester);
      await tester.tap(primary('Top up'));
      await settle(tester, 20);

      expect(text(en.reloadDoneTitle), findsOneWidget);
      expect(find.textContaining('new balance', findRichText: true), findsOneWidget);
      expect(app.backend.to('POST', begin).single.body!['purpose'], 'reload');
      expect(app.backend.to('POST', reloads).single.body!['presentment_id'], Payloads.presentmentId);
      await finishApp(tester, app);
    });
  }

  for (final bool ios in <bool>[false, true]) {
    testWidgets('${ios ? 'iPhone' : 'Android'}: a new card from stock is sold and activated', (
      WidgetTester tester,
    ) async {
      final TestApp app = await TestApp.create(isIos: ios, user: Payloads.reloadManager(), nfc: FakeNfcRelay());
      app.backend
        ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
        ..on('POST', complete, FakeReply(200, Payloads.cardOnly()))
        ..on('POST', '/vouchers', FakeReply(201, Payloads.soldCard(value: 3000)));
      await pumpWaiterApp(tester, app);

      await tester.tap(text(en.reloadReady));
      await settle(tester, 20);
      expect(text(en.reloadNewCardTitle), findsOneWidget);
      expect(text(en.reloadNewCardBody('B-2026-0001-0007')), findsOneWidget);
      expect(find.byType(BalanceCard), findsNothing);

      await typeDigits(tester, '3000');
      await tester.tap(primary('Continue'));
      await settle(tester);
      expect(text(en.reloadNewCardTitle), findsOneWidget);
      await tester.tap(primary('Top up'));
      await settle(tester, 20);

      expect(text(en.saleCardDoneTitle), findsOneWidget);
      expect(find.textContaining('B-2026-0001-0007 is active', findRichText: true), findsOneWidget);
      expect(app.backend.to('POST', '/vouchers').single.body!['presentment_id'], Payloads.bindPresentmentId);
      expect(app.backend.to('POST', '/vouchers/${Payloads.voucherId}/reloads'), isEmpty);
      await finishApp(tester, app);
    });

    testWidgets('${ios ? 'iPhone' : 'Android'}: a suspended card says so', (WidgetTester tester) async {
      final TestApp app = await TestApp.create(isIos: ios, user: Payloads.reloadManager(), nfc: FakeNfcRelay());
      app.backend
        ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
        ..on(
          'POST',
          complete,
          FakeReply(422, Payloads.error('CARD_NOT_USABLE', <String, Object?>{'reason': 'state', 'state': 'suspended'})),
        );
      await pumpWaiterApp(tester, app);

      await tester.tap(text(en.reloadReady));
      await settle(tester, 20);
      expect(text(en.problemCardNotUsableSuspended), findsOneWidget);
      await finishApp(tester, app);
    });
  }

  testWidgets('a sign-in that may not sell is told who activates a new card', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(
      user: <String, Object?>{
        ...Payloads.reloadManager(),
        'permissions': <String>['vouchers.redeem', 'vouchers.reload', 'cards.view'],
      },
      nfc: FakeNfcRelay(),
    );
    app.backend
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly()));
    await pumpWaiterApp(tester, app);

    await tester.tap(text(en.reloadReady));
    await settle(tester, 20);
    expect(text(en.reloadNewCardNotAllowedBody), findsOneWidget);
    expect(app.backend.to('POST', '/vouchers'), isEmpty);
    await finishApp(tester, app);
  });

  testWidgets('waiters and phones without a card reader see no top-up', (WidgetTester tester) async {
    final TestApp waiter = await TestApp.create(nfc: FakeNfcRelay());
    await pumpWaiterApp(tester, waiter);
    expect(text(en.reloadReady), findsNothing);
    await finishApp(tester, waiter);

    final TestApp noReader = await TestApp.create(
      user: Payloads.reloadManager(),
      nfc: FakeNfcRelay(available: NfcAvailability.unsupported),
    );
    await pumpWaiterApp(tester, noReader);
    expect(text(en.reloadReady), findsNothing);
    expect(text(en.readySell), findsOneWidget);
    await finishApp(tester, noReader);
  });

  // Moved from the voucher sale (2026-10-05): S24 is now the only place a card is sold.
  testWidgets('signed out while the card is awaited: the screen closes and the reader stops', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(user: Payloads.reloadManager(), nfc: FakeNfcRelay()..card = null);
    app.backend.on('POST', '/auth/logout', FakeReply(200, <String, Object?>{'message': 'Logged out.'}));
    await pumpWaiterApp(tester, app);
    await tester.tap(text(en.reloadReady));
    await settle(tester, 20);
    expect(app.nfc.prompts, hasLength(1), reason: 'the reader waits for the card');

    unawaited(app.session.signOut());
    await settle(tester, 20);
    expect(text(en.reloadTitle), findsNothing);
    expect(app.nfc.cancels, greaterThanOrEqualTo(1), reason: 'no reader mode or iPhone sheet left behind');
    await finishApp(tester, app);
  });

  // Decision 2026-10-05: the owner tops up a regular's card as loyalty — no payment, always with a reason.
  for (final bool ios in <bool>[false, true]) {
    testWidgets('${ios ? 'iPhone' : 'Android'}: an owner tops up a regular\'s card as loyalty', (WidgetTester tester) async {
      final Map<String, Object?> owner = <String, Object?>{
        ...Payloads.reloadManager(),
        'permissions': <String>[...(Payloads.reloadManager()['permissions']! as List<String>), 'vouchers.sell_complimentary'],
      };
      final TestApp app = await TestApp.create(isIos: ios, user: owner, nfc: FakeNfcRelay());
      app.backend
        ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
        ..on('POST', complete, FakeReply(200, Payloads.cardPresentment(balance: 2000)))
        ..on('POST', reloads, FakeReply(201, Payloads.reloaded(amount: 2000, balance: 4000)));
      await pumpWaiterApp(tester, app);

      await tester.tap(text(en.reloadReady));
      await settle(tester, 20);
      await typeDigits(tester, '2000');
      await tester.tap(primary('Continue'));
      await settle(tester);
      expect(en.salePaymentComplimentary, 'Loyalty');
      await tester.tap(text(en.salePaymentComplimentary));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'Stammgast Oktober');
      await tester.pump();
      await tester.tap(primary('Top up'));
      await settle(tester, 20);

      expect(text(en.reloadDoneTitle), findsOneWidget);
      expect(app.backend.to('POST', reloads).single.body!['payment'], <String, Object?>{'method': 'complimentary', 'reason': 'Stammgast Oktober'});
      await finishApp(tester, app);
    });
  }

  testWidgets('a manager is never offered loyalty', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(user: Payloads.reloadManager(), nfc: FakeNfcRelay());
    app.backend
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardPresentment(balance: 2000)));
    await pumpWaiterApp(tester, app);
    await tester.tap(text(en.reloadReady));
    await settle(tester, 20);
    await typeDigits(tester, '2000');
    await tester.tap(primary('Continue'));
    await settle(tester);
    expect(text(en.salePaymentComplimentary), findsNothing);
    await finishApp(tester, app);
  });
}
