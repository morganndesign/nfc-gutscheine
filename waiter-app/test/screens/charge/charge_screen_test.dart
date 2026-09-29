import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/storage/pending_redemptions.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/screens/s07_charge.dart';
import 'package:giftcard_waiter/screens/s09_success.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'charge_harness.dart';

/// S07 Charge (03b §2): entry, limits, hold, voucher states, an earlier
/// unresolved attempt, presentment expiry, layouts and accessibility — driven
/// through the real app (QR → presentment → S07).
void main() {
  group('amount entry', () {
    testWidgets('typed digits shift in and the button repeats the amount in '
        'the same frame (AC-S07-1)', (WidgetTester tester) async {
      final TestApp app = await openCharge(tester);
      expect(find.byType(ChargeScreen), findsOneWidget);
      expect(rich('Enter amount'), findsOneWidget);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull,
        reason: 'AC-S07-9: disabled at 0',
      );

      await tester.tap(key('2'));
      await tester.pump();
      expect(rich('Redeem € 0,02'), findsOneWidget);
      await typeDigits(tester, '490');
      expect(chargeOf(app).amount, 2490);
      expect(rich('Redeem € 24,90'), findsOneWidget);
      final AmountDisplay display = tester.widget(find.byType(AmountDisplay));
      expect(display.digits, '2490');

      await tester.tap(key('00'));
      await settle(tester, 2);
      expect(chargeOf(app).amount, 249000);
      await finishApp(tester, app);
    });

    testWidgets('⌫ deletes, a long press clears (AC-S07-7)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await openCharge(tester);
      await typeDigits(tester, '2490');
      await tester.tap(deleteKey);
      await settle(tester, 2);
      expect(chargeOf(app).amount, 249);

      await clearAmount(tester);
      expect(chargeOf(app).amount, 0);
      expect(rich('Enter amount'), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('the 8th digit is ignored with the limit nudge (AC-S07-6)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await openCharge(
        tester,
        presentment: Payloads.presentment(balance: 9999999),
      );
      final List<(String, bool)> said = recordAnnouncements(tester);
      await typeDigits(tester, '12345678');
      expect(chargeOf(app).amount, 1234567);
      expect(
        said.map(((String, bool) a) => a.$1),
        contains('Maximum amount reached'),
      );
      await finishApp(tester, app);
    });
  });

  group('limits', () {
    testWidgets('over balance: red message, chip, button disabled; the chip '
        'sets the balance (AC-S07-10/11)', (WidgetTester tester) async {
      final TestApp app = await openCharge(
        tester,
        presentment: Payloads.presentment(balance: 3250),
      );
      final List<(String, bool)> said = recordAnnouncements(tester);
      await typeDigits(tester, '3251');
      expect(rich('€ 0,01 more than the balance'), findsOneWidget);
      expect(find.byType(QuickAmountChip), findsOneWidget);
      expect(rich('Use balance · € 32,50'), findsOneWidget);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull,
      );
      expect(
        said,
        contains(('1 cent more than the balance. Redeem not available.', true)),
      );
      final AmountDisplay display = tester.widget(find.byType(AmountDisplay));
      expect(display.state, AmountDisplayState.overBalance);

      await tester.tap(find.byType(QuickAmountChip));
      await settle(tester);
      expect(chargeOf(app).amount, 3250);
      expect(find.byType(QuickAmountChip), findsNothing);
      expect(rich('more than the balance'), findsNothing);
      expect(rich('Redeem € 32,50'), findsOneWidget);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNotNull,
      );
      await finishApp(tester, app);
    });

    testWidgets('a known maximum single redemption is checked client-side '
        'with "Use maximum" (03b §2.16)', (WidgetTester tester) async {
      final TestApp app = await openCharge(
        tester,
        user: Payloads.user(maxSingle: 1500),
      );
      await typeDigits(tester, '2000');
      expect(rich('Max. € 15,00 per redemption'), findsOneWidget);
      expect(rich('Use maximum · € 15,00'), findsOneWidget);
      await tester.tap(find.byType(QuickAmountChip));
      await settle(tester);
      expect(chargeOf(app).amount, 1500);
      expect(app.backend.to('POST', redeemPath), isEmpty);
      await finishApp(tester, app);
    });
  });

  group('hold to redeem', () {
    testWidgets('€ 99,99 is a tap, € 100,00 needs the 600 ms hold '
        '(AC-S07-13/14/15)', (WidgetTester tester) async {
      final TestApp app = await openCharge(
        tester,
        presentment: Payloads.presentment(balance: 20000),
      );
      app.backend.on(
        'POST',
        redeemPath,
        FakeReply(201, Payloads.redeemed(amount: 12400, balanceAfter: 7600)),
      );
      await typeDigits(tester, '9999');
      expect(find.byType(HoldButton), findsNothing);
      await clearAmount(tester);
      await typeDigits(tester, '12400');
      expect(find.byType(HoldButton), findsOneWidget);
      expect(rich('Hold to redeem'), findsOneWidget);

      // Released at 590 ms: nothing is sent, the ring drains.
      TestGesture hold = await tester.startGesture(
        tester.getCenter(find.byType(HoldButton)),
      );
      for (int i = 0; i < 59; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await hold.up();
      await settle(tester);
      expect(app.backend.to('POST', redeemPath), isEmpty);

      hold = await tester.startGesture(
        tester.getCenter(find.byType(HoldButton)),
      );
      for (int i = 0; i < 62; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(app.backend.to('POST', redeemPath), hasLength(1));
      await hold.up();
      await settle(tester);
      expect(app.loop.state, isA<SuccessState>());
      await finishApp(tester, app);
    });
  });

  group('partial redemption disabled', () {
    testWidgets('no keypad or chip; "Redeem full balance" with the balance '
        '(AC-S07-17/18/19)', (WidgetTester tester) async {
      final TestApp app = await openCharge(
        tester,
        presentment: Payloads.presentment(balance: 3250, partial: false),
      );
      expect(find.byType(Keypad), findsNothing);
      expect(find.byType(QuickAmountChip), findsNothing);
      expect(rich('Only the full balance can be redeemed here.'), findsOne);
      expect(rich('Redeem full balance'), findsOneWidget);
      expect(rich('€ 32,50'), findsWidgets);
      final AmountDisplay display = tester.widget(find.byType(AmountDisplay));
      expect(display.state, AmountDisplayState.fixed);
      await finishApp(tester, app);
    });

    testWidgets('≥ € 100 uses the HoldButton', (WidgetTester tester) async {
      final TestApp app = await openCharge(
        tester,
        presentment: Payloads.presentment(balance: 15000, partial: false),
      );
      expect(find.byType(HoldButton), findsOneWidget);
      await finishApp(tester, app);
    });
  });

  group('voucher states (03b §2.14)', () {
    Future<void> expectState(
      WidgetTester tester, {
      required String status,
      required String title,
      required String body,
      int balance = 5000,
    }) async {
      final TestApp app = await startApp(tester);
      app.backend.on(
        'POST',
        '/presentments',
        FakeReply(201, Payloads.presentment(status: status, balance: balance)),
      );
      final List<(String, bool)> said = recordAnnouncements(tester);
      await scanVoucher(tester, app);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ChargeScreen), findsOneWidget);
      expect(find.byType(StatusBanner), findsOneWidget);
      expect(rich(title), findsOneWidget);
      expect(rich(body), findsOneWidget);
      expect(find.byType(Keypad), findsNothing, reason: 'AC-S07-21');
      expect(find.byType(AmountDisplay), findsNothing);
      expect(find.byType(BalanceCard), findsOneWidget);
      expect(rich('Code '), findsNothing, reason: '12 §2.5');
      expect(
        soundCount(app, 'gcw_error') + soundCount(app, 'gcw_warning'),
        1,
        reason: 'the controller plays E22–E24 once',
      );
      expect(said.any(((String, bool) a) => a.$1.contains(title)), isTrue);

      await tester.tap(rich('Done'));
      await settle(tester);
      expect(app.loop.state, isA<ReadyState>());
      expect(app.backend.to('POST', redeemPath), isEmpty);
      await finishApp(tester, app);
    }

    testWidgets('blocked with reason', (WidgetTester tester) async {
      await expectState(
        tester,
        status: 'blocked',
        title: 'Voucher blocked',
        body: 'Reason: Reported lost',
      );
    });

    testWidgets('expired with the date', (WidgetTester tester) async {
      await expectState(
        tester,
        status: 'expired',
        title: 'Voucher expired',
        body: 'Expired on 26 Sep 2029',
      );
    });

    testWidgets('zero balance', (WidgetTester tester) async {
      await expectState(
        tester,
        status: 'active',
        balance: 0,
        title: 'No balance left',
        body: 'This voucher has been fully used.',
      );
    });
  });

  group('feedback plays once (11 §3.4)', () {
    testWidgets('chip tap: one haptic.select (E35); 8th digit: one '
        'haptic.warning (E33); crossing the balance: key + warning (E30/E34)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await openCharge(
        tester,
        presentment: Payloads.presentment(balance: 3250),
      );
      await typeDigits(tester, '325');
      await realPause(tester);
      int before = hapticCount(app);
      await tester.tap(key('1'));
      await settle(tester, 2);
      expect(hapticCount(app) - before, 2, reason: 'key + over-balance');

      await realPause(tester);
      before = hapticCount(app);
      await tester.tap(find.byType(QuickAmountChip));
      await settle(tester, 2);
      expect(hapticCount(app) - before, 1);

      await typeDigits(tester, '99');
      await realPause(tester);
      before = hapticCount(app);
      await tester.tap(key('9'));
      await settle(tester, 2);
      expect(chargeOf(app).entry.digits.length, 7);
      expect(hapticCount(app) - before, 1);

      await realPause(tester);
      before = hapticCount(app);
      await clearAmount(tester);
      expect(
        hapticCount(app) - before,
        2,
        reason: 'delete at touch-down + clear',
      );
      await finishApp(tester, app);
    });

    testWidgets('client-side max crossing: one haptic', (
      WidgetTester tester,
    ) async {
      final TestApp app = await openCharge(
        tester,
        user: Payloads.user(maxSingle: 1500),
      );
      await typeDigits(tester, '150');
      await realPause(tester);
      final int before = hapticCount(app);
      await tester.tap(key('1'));
      await settle(tester, 2);
      expect(
        hapticCount(app) - before,
        1,
        reason: 'the crossing warning wins over the key (11 §4 T6)',
      );
      await finishApp(tester, app);
    });
  });

  group('connection', () {
    testWidgets('offline: banner and Redeem disabled (12 R16)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await openCharge(tester);
      await typeDigits(tester, '2490');
      app.connectivity.setOnline(false);
      await settle(tester);
      expect(rich('No connection'), findsOneWidget);
      expect(rich('Redeeming needs a connection'), findsOneWidget);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull,
      );
      app.connectivity.setOnline(true);
      await settle(tester);
      expect(rich('No connection'), findsNothing);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNotNull,
      );
      await finishApp(tester, app);
    });
  });

  group('earlier unresolved attempt (resolving)', () {
    /// App on S05 with an unresolved attempt of € 15 on the sample voucher;
    /// returns the attempt's outcome path.
    Future<(TestApp, String)> withPending(WidgetTester tester) async {
      final TestApp app = await startApp(tester);
      final PendingRedemption pending = await app.pending.open(
        voucherId: Payloads.voucherId,
        amount: 1500,
        currency: 'EUR',
        last4: '6488',
        restaurantName: 'Trattoria Bella Vista',
      );
      app.backend.on(
        'POST',
        '/presentments',
        FakeReply(201, Payloads.presentment()),
      );
      return (app, '$redeemPath/${pending.key}');
    }

    PrimaryButton button(WidgetTester tester) =>
        tester.widget<PrimaryButton>(find.byType(PrimaryButton));

    testWidgets('banner and "Check again" instead of the keypad; a booked '
        'answer updates the balance with the 4-s helper', (
      WidgetTester tester,
    ) async {
      final (TestApp app, String outcome) = await withPending(tester);
      app.backend
        ..on('GET', outcome, FakeReply(200, Payloads.outcome()))
        ..on(
          'GET',
          outcome,
          FakeReply(200, Payloads.outcome(amount: 1500, balanceAfter: 3500)),
        );
      final List<(String, bool)> said = recordAnnouncements(tester);
      await scanVoucher(tester, app);
      await tester.pump(const Duration(milliseconds: 400));

      expect(chargeOf(app).phase, RedeemPhase.resolving);
      expect(
        app.backend.to('GET', outcome),
        hasLength(1),
        reason: 'asked at once',
      );
      expect(rich('Checking an earlier redemption'), findsOneWidget);
      expect(rich('€ 15,00 may already have been redeemed'), findsOneWidget);
      expect(find.byType(Keypad), findsNothing);
      expect(find.byType(AmountDisplay), findsNothing);
      expect(button(tester).label, 'Check again');
      expect(button(tester).onPressed, isNotNull);
      expect(
        said,
        contains((
          'Trattoria Bella Vista. Balance 50 euros. '
              'Checking an earlier redemption.',
          false,
        )),
      );
      expect(app.loop.canRedeem(chargeOf(app)), isFalse);

      await tester.tap(find.byType(PrimaryButton));
      await settle(tester);
      expect(app.backend.to('GET', outcome), hasLength(2));
      expect(chargeOf(app).phase, RedeemPhase.entering);
      expect(chargeOf(app).voucher.balance, 3500);
      expect(chargeOf(app).notice, isA<EarlierBookedNotice>());
      expect(
        rich('The earlier redemption of € 15,00 was booked. Balance updated.'),
        findsOneWidget,
      );
      expect(find.byType(Keypad), findsOneWidget);
      expect(app.pending.entries, isEmpty);
      expect(app.services.recent.entries.single.amount, 1500);
      expect(
        app.backend.to('POST', redeemPath),
        isEmpty,
        reason: 'asking never re-sends the debit',
      );
      expect(
        said.map(((String, bool) a) => a.$1),
        contains(
          'The earlier redemption of 15 euros was booked. Balance updated.',
        ),
      );

      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      expect(rich('The earlier redemption'), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('"Check again" is disabled offline; ✕ leaves and keeps the '
        'attempt', (WidgetTester tester) async {
      final (TestApp app, String outcome) = await withPending(tester);
      app.backend.on('GET', outcome, FakeReply(200, Payloads.outcome()));
      await scanVoucher(tester, app);
      expect(chargeOf(app).phase, RedeemPhase.resolving);

      app.connectivity.setOnline(false);
      await settle(tester);
      expect(button(tester).onPressed, isNull);
      expect(rich('No connection'), findsOneWidget);
      app.connectivity.setOnline(true);
      await settle(tester);
      expect(button(tester).onPressed, isNotNull);

      await tester.tap(closeButton);
      await settle(tester);
      expect(app.loop.state, isA<ReadyState>());
      expect(app.pending.entries, hasLength(1));
      expect(app.backend.to('POST', redeemPath), isEmpty);
      await finishApp(tester, app);
    });
  });

  group('presentment expiry', () {
    testWidgets('the presentment runs out: "Scan again" replaces Redeem and '
        'the amount is kept for the same voucher', (WidgetTester tester) async {
      final TestApp app = await openCharge(
        tester,
        presentment: Payloads.presentment(expiresIn: 60),
      );
      await typeDigits(tester, '1800');
      expect(rich('Redeem € 18,00'), findsOneWidget);
      final List<(String, bool)> said = recordAnnouncements(tester);

      await tester.pump(const Duration(seconds: 57));
      await settle(tester);
      expect(chargeOf(app).presentmentExpired, isTrue);
      expect(rich('Scan the voucher again to redeem.'), findsOneWidget);
      expect(rich('Redeem € 18,00'), findsNothing);
      final PrimaryButton rescan = tester.widget(find.byType(PrimaryButton));
      expect(rescan.label, 'Scan again');
      expect(rescan.onPressed, isNotNull);
      expect(said, contains(('Scan the voucher again to redeem.', true)));
      expect(app.backend.to('POST', redeemPath), isEmpty);

      app.backend.only(
        'POST',
        '/presentments',
        FakeReply(201, Payloads.presentment(id: 'p-2')),
      );
      await tester.tap(find.byType(PrimaryButton));
      await settle(tester);
      expect(app.loop.state, isA<QrScanState>());

      app.loop.qrDetected(Payloads.qr);
      await settle(tester);
      expect(find.byType(ChargeScreen), findsOneWidget);
      expect(chargeOf(app).presentmentId, 'p-2');
      expect(chargeOf(app).amount, 1800);
      expect(rich('Redeem € 18,00'), findsOneWidget);
      expect(rich('Scan the voucher again'), findsNothing);
      await finishApp(tester, app);
    });
  });

  group('layout', () {
    testWidgets('reference phone: ID-1 card, button 8 pt above the bottom '
        '(AC-S07-3/8)', (WidgetTester tester) async {
      final TestApp app = await openCharge(tester);
      await tester.pump(const Duration(seconds: 1));
      final BalanceCard card = tester.widget(find.byType(BalanceCard));
      expect(card.density, BalanceCardDensity.full);
      final Size size = tester.getSize(find.byType(BalanceCard));
      expect(size.width / size.height, closeTo(1.586, 0.01));
      final Rect button = tester.getRect(find.byType(PrimaryButton));
      expect(852 - button.bottom, 16, reason: 'no safe area: space.4');
      expect(button.center.dy, greaterThan(852 * 0.55));
      expect(tester.getSize(find.byType(Keypad)).height, 4 * 72 + 3 * 8);
      await finishApp(tester, app);
    });

    testWidgets('375 × 667 compact: strip card, 64-pt keys, no overflow', (
      WidgetTester tester,
    ) async {
      final TestApp app = await openCharge(tester, size: const Size(375, 667));
      final BalanceCard card = tester.widget(find.byType(BalanceCard));
      expect(card.density, BalanceCardDensity.compact);
      expect(tester.getSize(find.byType(BalanceCard)).height, 88);
      await typeDigits(tester, '6000');
      expect(rich('Use balance'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getSize(find.byType(Keypad)).height, 4 * 64 + 3 * 8);
      final Rect button = tester.getRect(find.byType(PrimaryButton));
      expect(button.bottom, lessThanOrEqualTo(667 - 16));
      await finishApp(tester, app);
    });

    testWidgets('text scale 200 %: strip card and nothing overflows', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final TestApp app = await openCharge(tester, size: const Size(375, 667));
      await typeDigits(tester, '6000');
      expect(rich('Use balance'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // The action region stays; the card region scrolls (07 §6.1).
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, 400),
      );
      await settle(tester);
      final BalanceCard card = tester.widget(find.byType(BalanceCard));
      expect(card.density, BalanceCardDensity.compact);
      await finishApp(tester, app);
    });

    testWidgets('dark theme renders', (WidgetTester tester) async {
      final TestApp app = await openCharge(
        tester,
        prefs: const <String, Object>{'theme': 'dark'},
      );
      await typeDigits(tester, '6000');
      final BuildContext context = tester.element(find.byType(ChargeScreen));
      expect(context.waiter.brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });

    testWidgets('tablet landscape: two panes, card left of the keypad', (
      WidgetTester tester,
    ) async {
      final TestApp app = await openCharge(tester, size: const Size(1180, 820));
      final Rect card = tester.getRect(find.byType(BalanceCard));
      final Rect keypad = tester.getRect(find.byType(Keypad));
      expect(card.right, lessThan(keypad.left));
      expect(keypad.width, 400);
      await finishApp(tester, app);
    });

    testWidgets('German and BHS labels', (WidgetTester tester) async {
      TestApp app = await openCharge(tester, locale: const Locale('de'));
      await typeDigits(tester, '2490');
      expect(rich('€ 24,90 einlösen'), findsOneWidget);
      await finishApp(tester, app);

      app = await openCharge(tester, locale: const Locale('bs'));
      await typeDigits(tester, '2490');
      expect(rich('Iskoristi'), findsOneWidget);
      expect(rich('24,90'), findsWidgets);
      await finishApp(tester, app);
    });
  });

  group('accessibility (07 §5)', () {
    testWidgets('voucher, amount, keys and button carry spoken labels; the '
        'voucher is announced on entry', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final TestApp app = await startApp(tester);
      app.backend.on(
        'POST',
        '/presentments',
        FakeReply(201, Payloads.presentment()),
      );
      final List<(String, bool)> said = recordAnnouncements(tester);
      await scanVoucher(tester, app);
      expect(
        said,
        contains(('Trattoria Bella Vista. Balance 50 euros.', true)),
      );
      expect(find.bySemanticsLabel('Close voucher'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Voucher Trattoria Bella Vista')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('^Voucher number 5 2 8 5')),
        findsOne,
      );
      expect(find.bySemanticsLabel('Double zero'), findsOneWidget);

      await typeDigits(tester, '2490');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.bySemanticsLabel('Amount 24 euros 90'), findsOneWidget);
      expect(find.bySemanticsLabel('Redeem 24 euros 90'), findsOneWidget);
      semantics.dispose();
      await finishApp(tester, app);
    });

    testWidgets('Return redeems below € 100 (hardware keyboard)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await openCharge(tester);
      app.backend.on(
        'POST',
        redeemPath,
        FakeReply(201, Payloads.redeemed(amount: 2490, balanceAfter: 2510)),
      );
      await typeDigits(tester, '2490');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.byType(SuccessScreen), findsOneWidget);
      await finishApp(tester, app);
    });
  });

  testWidgets('✕ closes without booking (N6)', (WidgetTester tester) async {
    final TestApp app = await openCharge(tester);
    await typeDigits(tester, '2490');
    await tester.tap(closeButton);
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    expect(app.backend.to('POST', redeemPath), isEmpty);
    await finishApp(tester, app);
  });
}
