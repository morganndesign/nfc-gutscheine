import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/platform/nfc_relay.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import '../charge/charge_harness.dart' show typeDigits;

/// S24 · Top up card, Android and iPhone alike: the button shows for managers and owners on a phone that reads
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
        ..on('POST', complete, FakeReply(200, Payloads.presentment(balance: 2000)))
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
}
