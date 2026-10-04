import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/platform/voucher_printer.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/s20_sell_voucher.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import '../charge/charge_harness.dart' show clearAmount, key, typeDigits;

/// S20 · Sell voucher: value → payment → sale → print, identical on Android
/// and iPhone; one idempotency key per sale; the QR only in memory.
void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

  Finder text(String value) => find.text(value, findRichText: true);

  Future<TestApp> openSale(WidgetTester tester, {String role = 'manager', Map<String, Object?>? user}) async {
    final TestApp app = await TestApp.create(user: user ?? Payloads.manager(role: role));
    await pumpWaiterApp(tester, app);
    await tester.tap(text(en.readySell));
    await settle(tester);
    expect(find.byType(SellVoucherScreen), findsOneWidget);
    return app;
  }

  Finder primary(String prefix) =>
      find.byWidgetPredicate((Widget w) => w is PrimaryButton && w.label.startsWith(prefix));

  Future<void> continueWith(WidgetTester tester, String digits) async {
    await typeDigits(tester, digits);
    expect(tester.widget<PrimaryButton>(primary('Continue')).label, en.saleContinue('€\u00A0${_money(digits)}'));
    await tester.tap(primary('Continue'));
    await settle(tester);
  }

  Finder field(String label) => find.descendant(
    of: find.byWidgetPredicate((Widget w) => w is WaiterTextField && w.label == label),
    matching: find.byType(TextField),
  );

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(primary('Sell voucher'));
    await settle(tester);
  }

  testWidgets('cash sale: request, QR on screen, print, done', (WidgetTester tester) async {
    final TestApp app = await openSale(tester);
    app.backend.on('POST', '/vouchers', FakeReply(201, Payloads.sold()));

    await continueWith(tester, '5000');
    expect(text(en.salePaymentLabel), findsOneWidget);
    for (final String method in <String>[en.salePaymentCash, en.salePaymentCardTerminal, en.salePaymentBankTransfer]) {
      expect(text(method), findsOneWidget);
    }
    expect(text(en.salePaymentComplimentary), findsNothing, reason: 'owners only');
    // Decision 2026-10-04: the guest's e-mail carries the printed voucher as a PDF.
    expect(text(en.saleEmailHelperPdf), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'klara@example.at');
    await tester.pump();
    await submit(tester);

    final RecordedRequest sale = app.backend.to('POST', '/vouchers').single;
    expect(sale.body, <String, Object?>{
      'value': 5000,
      'form': 'printable',
      'payment': <String, Object?>{'method': 'cash'},
      'customer': <String, Object?>{'email': 'klara@example.at'},
    });
    expect(sale.header('Idempotency-Key'), isNotNull);

    expect(text(en.saleDoneTitle), findsOneWidget);
    expect(find.bySemanticsLabel(en.saleQrA11y), findsOneWidget);
    expect(text(en.saleDoneBody), findsOneWidget);
    expect(text('5285 1058 7098 6488'), findsNothing);

    await tester.tap(primary(en.salePrint));
    await settle(tester);
    final PrintableVoucher job = app.printer.jobs.single;
    expect(job.payload, Payloads.qr);
    expect(job.restaurantName, 'Trattoria Bella Vista');
    expect(job.restaurantLocale, 'de_AT');
    expect(job.value, 5000);
    expect(job.currency, 'EUR');
    expect(text(en.salePrinted), findsOneWidget);

    await tester.tap(primary(en.commonDone));
    await settle(tester, 20);
    expect(find.byType(SellVoucherScreen), findsNothing);
    await finishApp(tester, app);
  });

  // Decision 2026-10-04: a voucher bought for someone else carries their name and the buyer's message.
  testWidgets('printed voucher for someone: name and message are sent and printed', (WidgetTester tester) async {
    final TestApp app = await openSale(tester);
    app.backend.on(
      'POST',
      '/vouchers',
      FakeReply(201, Payloads.sold(recipientName: 'Anna', giftMessage: 'Alles Gute!')),
    );

    await continueWith(tester, '3000');
    await tester.enterText(field(en.saleRecipientLabel), '  Anna ');
    await tester.enterText(field(en.saleMessageLabel), 'Alles Gute!');
    await tester.pump();
    await submit(tester);

    final Map<String, Object?> body = app.backend.to('POST', '/vouchers').single.body!;
    expect(body['recipient_name'], 'Anna');
    expect(body['gift_message'], 'Alles Gute!');

    await tester.tap(primary(en.salePrint));
    await settle(tester);
    final PrintableVoucher job = app.printer.jobs.single;
    expect(job.recipientName, 'Anna');
    expect(job.giftMessage, 'Alles Gute!');
    await finishApp(tester, app);
  });

  testWidgets('value outside the restaurant limits stays on the amount step', (WidgetTester tester) async {
    final TestApp app = await openSale(tester);
    await typeDigits(tester, '400');
    await tester.tap(find.byType(PrimaryButton));
    await settle(tester);
    expect(text(en.saleAmountRange('€ 5,00', '€ 500,00')), findsOneWidget);
    expect(text(en.salePaymentLabel), findsNothing);
    expect(app.backend.to('POST', '/vouchers'), isEmpty);
    await finishApp(tester, app);
  });

  testWidgets('card terminal needs a reference; the field error names it', (WidgetTester tester) async {
    final TestApp app = await openSale(tester);
    app.backend.on('POST', '/vouchers', FakeReply(201, Payloads.sold(value: 2500)));
    await continueWith(tester, '2500');
    await tester.tap(text(en.salePaymentCardTerminal));
    await settle(tester);
    await submit(tester);
    expect(text(en.saleReferenceRequired), findsOneWidget);
    expect(app.backend.to('POST', '/vouchers'), isEmpty);

    await tester.enterText(find.byType(TextField).first, 'TRM 88213');
    await tester.pump();
    await submit(tester);
    expect(app.backend.to('POST', '/vouchers').single.body!['payment'], <String, Object?>{
      'method': 'card_terminal',
      'reference': 'TRM 88213',
    });
    await finishApp(tester, app);
  });

  testWidgets('owners may record a complimentary voucher with a reason', (WidgetTester tester) async {
    final TestApp app = await openSale(tester, role: 'owner');
    app.backend.on('POST', '/vouchers', FakeReply(201, Payloads.sold(value: 1000)));
    await continueWith(tester, '1000');
    await tester.tap(text(en.salePaymentComplimentary));
    await settle(tester);
    await submit(tester);
    expect(text(en.saleReasonRequired), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Birthday of a regular');
    await tester.pump();
    await submit(tester);
    expect(app.backend.to('POST', '/vouchers').single.body!['payment'], <String, Object?>{
      'method': 'complimentary',
      'reason': 'Birthday of a regular',
    });
    await finishApp(tester, app);
  });

  testWidgets('no answer: "Try again" sends the same key and never sells twice', (WidgetTester tester) async {
    final TestApp app = await openSale(tester);
    app.backend
      ..on('POST', '/vouchers', FakeReply.transport())
      ..on('POST', '/vouchers', FakeReply(200, Payloads.sold(replayed: true)));
    await continueWith(tester, '5000');
    await submit(tester);
    expect(text(en.saleUncertainTitle), findsOneWidget);
    expect(text(en.saleUncertainBody), findsOneWidget);

    await tester.tap(text(en.commonTryAgain));
    await settle(tester);
    final List<RecordedRequest> sales = app.backend.to('POST', '/vouchers');
    expect(sales, hasLength(2));
    expect(sales.first.header('Idempotency-Key'), sales.last.header('Idempotency-Key'));
    expect(text(en.saleDoneTitle), findsOneWidget);
    await finishApp(tester, app);
  });

  for (final (int status, String code) in <(int, String)>[
    (403, 'FORBIDDEN'),
    (429, 'RATE_LIMITED'),
    (409, 'HTTP_409'),
  ]) {
    testWidgets('no answer, then $status: still unconfirmed with the same key', (WidgetTester tester) async {
      final TestApp app = await openSale(tester);
      app.backend
        ..on('POST', '/vouchers', FakeReply.transport())
        ..on('POST', '/vouchers', FakeReply(status, Payloads.error(code)))
        ..on('POST', '/vouchers', FakeReply(200, Payloads.sold(replayed: true)));
      await continueWith(tester, '5000');
      await submit(tester);
      await tester.tap(text(en.commonTryAgain));
      await settle(tester);
      expect(text(en.saleUncertainTitle), findsOneWidget, reason: '$status says nothing about the first request');
      expect(text(en.saleNotAllowedTitle), findsNothing);

      await tester.tap(text(en.commonTryAgain));
      await settle(tester);
      final List<RecordedRequest> sales = app.backend.to('POST', '/vouchers');
      expect(sales, hasLength(3));
      expect(sales.map((RecordedRequest r) => r.header('Idempotency-Key')).toSet(), hasLength(1));
      expect(text(en.saleDoneTitle), findsOneWidget);
      await finishApp(tester, app);
    });
  }

  testWidgets('no answer, then a sale code: definitive, a new sale gets a new key', (WidgetTester tester) async {
    final TestApp app = await openSale(tester);
    app.backend
      ..on('POST', '/vouchers', FakeReply.transport())
      ..on(
        'POST',
        '/vouchers',
        FakeReply(422, Payloads.error('INVALID_AMOUNT', <String, Object?>{'min': 500, 'max': 50000})),
      )
      ..on('POST', '/vouchers', FakeReply(201, Payloads.sold(value: 4000)));
    await continueWith(tester, '5000');
    await submit(tester);
    await tester.tap(text(en.commonTryAgain));
    await settle(tester);
    expect(text(en.saleAmountRange('€\u00A05,00', '€\u00A0500,00')), findsOneWidget);

    await clearAmount(tester);
    await continueWith(tester, '4000');
    await submit(tester);
    final List<RecordedRequest> sales = app.backend.to('POST', '/vouchers');
    expect(sales, hasLength(3));
    expect(sales[2].header('Idempotency-Key'), isNot(sales[0].header('Idempotency-Key')));
    await finishApp(tester, app);
  });

  testWidgets('closing while unconfirmed asks first', (WidgetTester tester) async {
    final TestApp app = await openSale(tester);
    app.backend.on('POST', '/vouchers', FakeReply.transport());
    await continueWith(tester, '5000');
    await submit(tester);
    expect(text(en.saleUncertainTitle), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(en.commonClose).first);
    await settle(tester);
    expect(text(en.saleLeaveUncertainTitle), findsOneWidget);
    await tester.tap(text(en.commonCancel));
    await settle(tester);
    expect(find.byType(SellVoucherScreen), findsOneWidget);
    expect(text(en.saleUncertainTitle), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(en.commonClose).first);
    await settle(tester);
    await tester.tap(text(en.saleLeaveConfirm));
    await settle(tester, 20);
    expect(find.byType(SellVoucherScreen), findsNothing);
    await finishApp(tester, app);
  });

  testWidgets('a retry answered without a QR says how to proceed', (WidgetTester tester) async {
    final TestApp app = await openSale(tester);
    app.backend
      ..on('POST', '/vouchers', FakeReply.transport())
      ..on('POST', '/vouchers', FakeReply(200, Payloads.sold(replayed: true, withQr: false)));
    await continueWith(tester, '5000');
    await submit(tester);
    await tester.tap(text(en.commonTryAgain));
    await settle(tester);

    expect(text(en.saleNoQrTitle), findsOneWidget);
    expect(text(en.saleNoQrBody), findsOneWidget);
    expect(find.bySemanticsLabel(en.saleQrA11y), findsNothing);
    expect(primary(en.salePrint), findsNothing);

    await tester.tap(primary(en.commonDone));
    await settle(tester, 20);
    expect(text(en.saleLeaveTitle), findsNothing, reason: 'nothing left to print');
    expect(find.byType(SellVoucherScreen), findsNothing);
    expect(app.printer.jobs, isEmpty);
    await finishApp(tester, app);
  });

  testWidgets('403: not allowed, back to the details', (WidgetTester tester) async {
    final TestApp app = await openSale(tester);
    app.backend.on('POST', '/vouchers', FakeReply(403, Payloads.error('FORBIDDEN')));
    await continueWith(tester, '5000');
    await submit(tester);
    expect(text(en.saleNotAllowedTitle), findsOneWidget);
    expect(app.session.blocked, isNull, reason: 'the app itself is not blocked');
    await finishApp(tester, app);
  });

  testWidgets('closing an unprinted sale asks first; printing can be retried', (WidgetTester tester) async {
    final TestApp app = await openSale(tester);
    app.backend.on('POST', '/vouchers', FakeReply(201, Payloads.sold()));
    await continueWith(tester, '5000');
    await submit(tester);

    app.printer.fail = true;
    await tester.tap(primary(en.salePrint));
    await settle(tester);
    expect(text(en.salePrintFailed), findsOneWidget);

    await tester.tap(find.byWidgetPredicate((Widget w) => w is SecondaryButton && w.label == en.commonDone));
    await settle(tester);
    expect(text(en.saleLeaveTitle), findsOneWidget);
    await tester.tap(text(en.commonCancel));
    await settle(tester);
    expect(find.byType(SellVoucherScreen), findsOneWidget);

    app.printer.fail = false;
    await tester.tap(primary(en.salePrint));
    await settle(tester);
    expect(app.printer.jobs, hasLength(2));
    expect(text(en.salePrinted), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets('signed out while the stock card is awaited: the screen closes and the reader stops', (
    WidgetTester tester,
  ) async {
    final TestApp app = await TestApp.create(user: Payloads.cardManager(), nfc: FakeNfcRelay()..card = null);
    app.backend.on('POST', '/auth/logout', FakeReply(200, <String, Object?>{'message': 'Logged out.'}));
    await pumpWaiterApp(tester, app);
    await tester.tap(text(en.readySell));
    await settle(tester);
    await tester.tap(text(en.saleFormCard));
    await settle(tester);
    await continueWith(tester, '5000');
    await tester.tap(primary(en.saleCardSubmit('€\u00A050.00').split(' ').first));
    await settle(tester);
    expect(app.nfc.prompts, hasLength(1), reason: 'the reader waits for the stock card');

    unawaited(app.session.signOut());
    await settle(tester, 20);
    expect(find.byType(SellVoucherScreen), findsNothing);
    expect(app.nfc.cancels, 1, reason: 'no reader mode or iPhone sheet left behind');
    expect(app.backend.to('POST', '/vouchers'), isEmpty);
    await finishApp(tester, app);
  });

  testWidgets('German copy', (WidgetTester tester) async {
    final AppLocalizations de = lookupAppLocalizations(const Locale('de'));
    final TestApp app = await TestApp.create(user: Payloads.manager());
    await pumpWaiterApp(tester, app, locale: const Locale('de'));
    await tester.tap(text(de.readySell));
    await settle(tester);
    expect(find.descendant(of: find.byType(SellVoucherScreen), matching: text(de.saleTitle)), findsOneWidget);
    expect(text(de.saleAmountLabel), findsOneWidget);
    expect(key('0'), findsOneWidget);
    await finishApp(tester, app);
  });
}

/// `5000` → `50,00` (German-locale restaurant formatting, no symbol).
String _money(String digits) {
  final String padded = digits.padLeft(3, '0');
  return '${padded.substring(0, padded.length - 2)},${padded.substring(padded.length - 2)}';
}
