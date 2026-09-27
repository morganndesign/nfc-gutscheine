import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/platform/nfc_service.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/screens/s07_charge.dart';
import 'package:giftcard_waiter/screens/s09_success.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'charge_harness.dart';

/// S07 Charge (03b §2): entry, limits, hold, card states, switch, skeleton,
/// layouts and accessibility — driven through the real app.
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
        scan: Payloads.scan(balance: 9999999),
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
        scan: Payloads.scan(balance: 3250),
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
    testWidgets('€ 99,99 is a tap, € 100,00 needs the 600 ms hold '
        '(AC-S07-13/14/15)', (WidgetTester tester) async {
      final TestApp app = await openCharge(
        tester,
        scan: Payloads.scan(balance: 20000),
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
        scan: Payloads.scan(balance: 3250, partial: false),
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

    testWidgets('≥ € 100 uses the HoldButton', (WidgetTester tester) async {
      final TestApp app = await openCharge(
        tester,
        scan: Payloads.scan(balance: 15000, partial: false),
      );
      expect(find.byType(HoldButton), findsOneWidget);
      await finishApp(tester, app);
    });
  });

  group('card states (03b §2.14)', () {
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
        '/scan',
        FakeReply(200, Payloads.scan(status: status, balance: balance)),
      );
      final List<(String, bool)> said = recordAnnouncements(tester);
      await readCard(tester, app);
      await tester.pump(const Duration(milliseconds: 400));
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
      await finishApp(tester, app);
    }

    testWidgets('blocked with reason', (WidgetTester tester) async {
      await expectState(
        tester,
        status: 'blocked',
        title: 'Card blocked',
        body: 'Reason: Reported lost',
      );
    });

    testWidgets('expired with the date', (WidgetTester tester) async {
      await expectState(
        tester,
        status: 'expired',
        title: 'Card expired',
        body: 'Expired on 26 Sep 2029',
      );
    });

    testWidgets('replaced', (WidgetTester tester) async {
      await expectState(
        tester,
        status: 'replaced',
        title: 'Card was replaced',
        body: 'Ask the guest for the new card.',
      );
    });

    testWidgets('inactive', (WidgetTester tester) async {
      await expectState(
        tester,
        status: 'inactive',
        title: 'Card not activated yet',
        body: 'It can be redeemed once activated.',
      );
    });

    testWidgets('zero balance', (WidgetTester tester) async {
      await expectState(
        tester,
        status: 'active',
        balance: 0,
        title: 'No balance left',
        body: 'This card has been fully used.',
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
        scan: Payloads.scan(balance: 3250),
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

  group('connection and card switch', () {
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

    testWidgets('Android: a different card with an amount typed offers '
        '"Switch" and hides Redeem (AC-S07-31/32)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await openCharge(tester);
      await typeDigits(tester, '2490');
      app.nfc.emit(
        NfcTagRead(uid: '04:00:00:00:00:00:01', url: Payloads.cardUrl()),
      );
      await settle(tester);
      expect(chargeOf(app).pendingSwitch, isNotNull);
      expect(rich('Different card detected – Switch?'), findsOneWidget);
      final AnimatedOpacity slot = tester.widget(
        find
            .ancestor(
              of: find.byType(PrimaryButton),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(slot.opacity, 0);

      await tester.tap(rich('Switch').last);
      await settle(tester);
      expect(chargeOf(app).amount, 0);
      expect(app.backend.to('POST', '/scan'), hasLength(2));
      await finishApp(tester, app);
    });

    testWidgets('the switch snackbar times out as "Keep" (6 s)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await openCharge(tester);
      await typeDigits(tester, '2490');
      app.nfc.emit(
        NfcTagRead(uid: '04:00:00:00:00:00:01', url: Payloads.cardUrl()),
      );
      await settle(tester);
      expect(chargeOf(app).pendingSwitch, isNotNull);
      await tester.pump(const Duration(seconds: 7));
      await settle(tester);
      expect(chargeOf(app).pendingSwitch, isNull);
      expect(rich('Different card detected'), findsNothing);
      expect(chargeOf(app).amount, 2490);
      await finishApp(tester, app);
    });

    testWidgets('with a screen reader the switch offer is a dialog', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final TestApp app = await openCharge(tester);
      await typeDigits(tester, '2490');
      app.nfc.emit(
        NfcTagRead(uid: '04:00:00:00:00:00:01', url: Payloads.cardUrl()),
      );
      await settle(tester);
      expect(find.byType(WaiterDialog), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(find.byType(WaiterDialog), findsOneWidget, reason: 'no timeout');
      expect(chargeOf(app).pendingSwitch, isNotNull);
      await tester.tap(rich('Keep'));
      await settle(tester);
      expect(find.byType(WaiterDialog), findsNothing);
      expect(chargeOf(app).pendingSwitch, isNull);
      expect(chargeOf(app).amount, 2490);
      await finishApp(tester, app);
    });

    testWidgets('Android: a new card with amount 0 replaces the card', (
      WidgetTester tester,
    ) async {
      final TestApp app = await startApp(tester);
      app.backend
        ..on('POST', '/scan', FakeReply(200, Payloads.scan()))
        ..on('POST', '/scan', FakeReply(200, Payloads.scan(balance: 800)));
      await readCard(tester, app);
      expect(chargeOf(app).card.balance, 5000);
      app.nfc.emit(
        NfcTagRead(uid: '04:00:00:00:00:00:02', url: Payloads.cardUrl()),
      );
      await settle(tester);
      expect(chargeOf(app).card.balance, 800);
      expect(chargeOf(app).replacedCard, isTrue);
      expect(find.byType(ChargeScreen), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('a slow new-card lookup stays on S07 with the skeleton (M21)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await startApp(tester);
      app.backend
        ..on('POST', '/scan', FakeReply(200, Payloads.scan()))
        ..on(
          'POST',
          '/scan',
          FakeReply(
            200,
            Payloads.scan(balance: 800),
            const Duration(seconds: 1),
          ),
        );
      await readCard(tester, app);
      app.nfc.emit(
        NfcTagRead(uid: '04:00:00:00:00:00:02', url: Payloads.cardUrl()),
      );
      await settle(tester);
      expect(app.loop.state, isA<LookingUpState>());
      expect(find.byType(ChargeScreen), findsOneWidget);
      expect(tester.widget<BalanceCard>(find.byType(BalanceCard)).data, isNull);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(chargeOf(app).card.balance, 800);
      await finishApp(tester, app);
    });
  });

  group('card link skeleton (03b §2.19)', () {
    testWidgets('skeleton, "Still looking …" at 3 s, ✕ cancels', (
      WidgetTester tester,
    ) async {
      final (TestApp app, links) = await startAppWithLinks(tester);
      app.backend.on(
        'POST',
        '/scan',
        FakeReply.hang(const Duration(seconds: 30)),
      );
      links.add(Uri.parse(Payloads.cardUrl()));
      await settle(tester);
      expect(app.loop.state, isA<LookingUpState>());
      expect(find.byType(ChargeScreen), findsOneWidget);
      final BalanceCard card = tester.widget(find.byType(BalanceCard));
      expect(card.data, isNull);
      expect(tester.widget<Keypad>(find.byType(Keypad)).enabled, isFalse);
      expect(rich('Enter amount'), findsOneWidget);
      expect(rich('Still looking'), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(rich('Still looking'), findsOneWidget);

      await tester.tap(closeButton);
      await settle(tester);
      expect(app.loop.state, isA<ReadyState>());
      await finishApp(tester, app);
    });

    testWidgets('the skeleton turns into the card', (
      WidgetTester tester,
    ) async {
      final (TestApp app, links) = await startAppWithLinks(tester);
      app.backend.on(
        'POST',
        '/scan',
        FakeReply(200, Payloads.scan(), const Duration(milliseconds: 500)),
      );
      links.add(Uri.parse(Payloads.cardUrl()));
      await settle(tester);
      expect(tester.widget<BalanceCard>(find.byType(BalanceCard)).data, isNull);
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);
      expect(app.loop.state, isA<ChargeState>());
      expect(
        tester.widget<BalanceCard>(find.byType(BalanceCard)).data,
        isNotNull,
      );
      expect(tester.widget<Keypad>(find.byType(Keypad)).enabled, isTrue);
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
    testWidgets('card, amount, keys and button carry spoken labels; the card '
        'is announced on entry', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final TestApp app = await startApp(tester);
      app.backend.on('POST', '/scan', FakeReply(200, Payloads.scan()));
      final List<(String, bool)> said = recordAnnouncements(tester);
      await readCard(tester, app);
      expect(
        said,
        contains(('Trattoria Bella Vista. Balance 50 euros.', true)),
      );
      expect(find.bySemanticsLabel('Close card'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Gift card Trattoria Bella Vista')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('^Card number 5 2 8 5')), findsOne);
      expect(find.bySemanticsLabel('Double zero'), findsOneWidget);

      await typeDigits(tester, '2490');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.bySemanticsLabel('Amount 24 euros 90'), findsOneWidget);
      expect(find.bySemanticsLabel('Redeem 24 euros 90'), findsOneWidget);
      semantics.dispose();
      await finishApp(tester, app);
    });

    testWidgets('Return redeems below € 100 (hardware keyboard)', (
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
