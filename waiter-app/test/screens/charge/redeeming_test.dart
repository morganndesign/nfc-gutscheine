import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/screens/charge/uncertain_panel.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'charge_harness.dart';

/// S08 in-place states (03b §3) and the S07 notices after a definitive
/// answer (12 §3.2 R05–R16).
void main() {
  Future<TestApp> typed(
    WidgetTester tester,
    List<FakeReply> replies, {
    String digits = '2490',
    Map<String, Object?>? scan,
  }) async {
    final TestApp app = await openCharge(tester, scan: scan);
    for (final FakeReply reply in replies) {
      app.backend.on('POST', redeemPath, reply);
    }
    await typeDigits(tester, digits);
    return app;
  }

  Future<void> tapRedeem(WidgetTester tester) async {
    await tester.tap(rich('Redeem €'));
    await tester.pump();
  }

  List<String?> keys(TestApp app) => app.backend
      .to('POST', redeemPath)
      .map((RecordedRequest r) => r.header('Idempotency-Key'))
      .toList();

  group('S08 Redeeming', () {
    testWidgets('submitting: label kept for 150 ms, then the spinner; keypad, '
        'chip and ✕ locked (AC-S08-1/3)', (WidgetTester tester) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(
          201,
          Payloads.redeemed(amount: 2490, balanceAfter: 2510),
          const Duration(seconds: 1),
        ),
      ]);
      final List<(String, bool)> said = recordAnnouncements(tester);
      await tapRedeem(tester);
      expect(chargeOf(app).phase, RedeemPhase.submitting);
      expect(find.byType(Spinner), findsNothing);
      expect(rich('Redeem € 24,90'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(Spinner), findsOneWidget);
      expect(said, contains(('Redeeming 24 euros 90 …', true)));

      await tester.tap(key('5'), warnIfMissed: false);
      await tester.tap(closeButton);
      await tester.pump(const Duration(milliseconds: 50));
      expect(chargeOf(app).amount, 2490, reason: 'input locked');
      expect(app.loop.state, isA<ChargeState>(), reason: '✕ locked');
      expect(tester.widget<Keypad>(find.byType(Keypad)).enabled, isFalse);

      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(app.loop.state, isA<SuccessState>());
      expect(app.backend.to('POST', redeemPath), hasLength(1));
      await finishApp(tester, app);
    });

    testWidgets('slow after 8 s, then the uncertain panel with the attempt '
        'counter; a success still lands on S09 (AC-S08-4/5/7)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply.hang(const Duration(seconds: 30)),
        FakeReply.hang(const Duration(seconds: 30)),
        FakeReply(
          200,
          Payloads.redeemed(amount: 2490, balanceAfter: 2510, replayed: true),
        ),
      ]);
      await tapRedeem(tester);
      await tester.pump(const Duration(seconds: 8));
      await settle(tester);
      expect(chargeOf(app).phase, RedeemPhase.slow);
      expect(rich('Connection slow – retrying'), findsOneWidget);
      expect(rich('Checking … Nothing is ever booked twice.'), findsOne);

      await tester.pump(const Duration(seconds: 8));
      await settle(tester);
      expect(chargeOf(app).phase, RedeemPhase.uncertainAuto);
      expect(find.byType(UncertainPanel), findsOneWidget);
      expect(find.byType(Keypad), findsNothing);
      expect(rich('Connection interrupted'), findsOneWidget);
      expect(rich('Attempt 1 of 3'), findsOneWidget);
      expect(rich('Tell the guest'), findsOneWidget);
      expect(
        rich('50,00'),
        findsWidgets,
        reason: 'AC-S08-6: no optimistic balance',
      );

      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(app.loop.state, isA<SuccessState>());
      expect(keys(app).toSet(), hasLength(1));
      await finishApp(tester, app);
    });

    testWidgets('final: "Try again" reuses the key, "Cancel" keeps card and '
        'amount with the unconfirmed banner (AC-S08-8/10/11)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply.transport(),
      ]);
      final List<(String, bool)> said = recordAnnouncements(tester);
      await tapRedeem(tester);
      await settle(tester);
      expect(chargeOf(app).phase, RedeemPhase.uncertainAuto);
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 2));
        await settle(tester);
      }
      expect(chargeOf(app).phase, RedeemPhase.uncertainFinal);
      expect(rich('Not confirmed yet. Try again'), findsOneWidget);
      expect(rich('Code '), findsOneWidget);
      expect(rich('Try again'), findsWidgets);
      expect(rich('Cancel'), findsOneWidget);
      expect(
        said.where(((String, bool) a) => a.$1.startsWith('Connection')),
        isNotEmpty,
      );
      expect(rich('nothing was charged'), findsNothing);

      await tester.tap(rich('Cancel'));
      await settle(tester);
      expect(chargeOf(app).phase, RedeemPhase.entering);
      expect(chargeOf(app).amount, 2490);
      expect(chargeOf(app).card.balance, 5000);
      expect(rich('Not confirmed. Scan the card again'), findsOneWidget);
      expect(find.byType(Keypad), findsOneWidget);

      // Redeem again with the same amount: same key; this time "Try again".
      await tapRedeem(tester);
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 2));
        await settle(tester);
      }
      expect(chargeOf(app).phase, RedeemPhase.uncertainFinal);
      app.backend.on(
        'POST',
        redeemPath,
        FakeReply(201, Payloads.redeemed(amount: 2490, balanceAfter: 2510)),
      );
      await tester.tap(
        find.ancestor(
          of: rich('Try again'),
          matching: find.byType(PrimaryButton),
        ),
      );
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(app.loop.state, isA<SuccessState>());
      expect(keys(app).toSet(), hasLength(1));
      await finishApp(tester, app);
    });
  });

  group('notices', () {
    testWidgets('balance changed: new balance, 4-s helper, then over '
        'balance (R06, AC-S08-14)', (WidgetTester tester) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(
          422,
          Payloads.error('INSUFFICIENT_BALANCE', <String, Object?>{
            'balance': 2000,
          }),
        ),
      ]);
      final List<(String, bool)> said = recordAnnouncements(tester);
      await tapRedeem(tester);
      await settle(tester);
      expect(chargeOf(app).card.balance, 2000);
      expect(rich('Balance changed: now € 20,00'), findsOneWidget);
      expect(rich('Use balance · € 20,00'), findsOneWidget);
      expect(
        said.map(((String, bool) a) => a.$1),
        contains(
          'Balance changed: now 20 euros. '
          '4 euros 90 more than the balance. Redeem not available.',
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      expect(rich('Balance changed'), findsNothing);
      expect(rich('€ 4,90 more than the balance'), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('max single redemption from the server: message, "Use '
        'maximum", checked client-side afterwards (R10)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(
          422,
          Payloads.error('INVALID_AMOUNT', <String, Object?>{
            'max_single_redemption': 1500,
          }),
        ),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      expect(rich('Max. € 15,00 per redemption'), findsOneWidget);
      expect(rich('Use maximum · € 15,00'), findsOneWidget);
      await tester.tap(find.byType(QuickAmountChip));
      await settle(tester);
      expect(chargeOf(app).amount, 1500);
      await typeDigits(tester, '1');
      expect(rich('Max. € 15,00 per redemption'), findsOneWidget);
      expect(app.backend.to('POST', redeemPath), hasLength(1));
      await finishApp(tester, app);
    });

    testWidgets('full-only rule changed meanwhile: "Nothing was booked." '
        'for 4 s, then the full-only layout (R11)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(
          422,
          Payloads.error('INVALID_AMOUNT', <String, Object?>{'balance': 5000}),
        ),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      expect(chargeOf(app).fullOnly, isTrue);
      expect(find.byType(Keypad), findsNothing);
      expect(rich('Nothing was booked.'), findsOneWidget);
      expect(rich('Redeem full balance'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      expect(rich('Only the full balance can be redeemed here.'), findsOne);
      await finishApp(tester, app);
    });

    testWidgets('card blocked meanwhile: blocked variant with "Nothing was '
        'booked." (R07)', (WidgetTester tester) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(422, Payloads.error('CARD_BLOCKED')),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      expect(chargeOf(app).condition, CardCondition.blocked);
      expect(rich('Nothing was booked.'), findsOneWidget);
      expect(rich('Card blocked'), findsOneWidget);
      expect(rich('Reason:'), findsNothing, reason: 'AC-S07-22');
      expect(find.byType(Keypad), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      expect(rich('Nothing was booked.'), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('client defect: generic line with support code (R12)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(422, Payloads.error('VALIDATION_FAILED')),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      expect(rich('Service not available right now'), findsOneWidget);
      expect(rich('Code '), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('idempotency conflict: "Please tap Redeem again." and no '
        'resubmit (R13, AC-S08-13)', (WidgetTester tester) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(409, Payloads.error('IDEMPOTENCY_CONFLICT')),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      expect(rich('Please tap Redeem again.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(app.backend.to('POST', redeemPath), hasLength(1));
      await finishApp(tester, app);
    });

    testWidgets('velocity limit without a time: banner with "Please get a '
        'manager" (R14)', (WidgetTester tester) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(429, Payloads.error('VELOCITY_LIMIT_EXCEEDED')),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      expect(find.byType(StatusBanner), findsOneWidget);
      expect(rich('Limit for this card reached'), findsOneWidget);
      expect(rich('Please get a manager'), findsOneWidget);
      expect(rich('fraud'), findsNothing, reason: 'AC-S07-30');
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNotNull,
        reason: 'AC-S07-29: no retry time → Redeem stays enabled',
      );
      await finishApp(tester, app);
    });

    testWidgets('velocity limit with a time counts in minutes (R14)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(
          429,
          Payloads.error('VELOCITY_LIMIT_EXCEEDED', <String, Object?>{
            'retry_after': 720,
          }),
        ),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      expect(rich('Possible again in 12 min'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      expect(rich('Possible again in 11 min'), findsOneWidget);
      await tester.pump(const Duration(minutes: 11));
      await settle(tester);
      expect(find.byType(StatusBanner), findsNothing);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNotNull,
      );
      await finishApp(tester, app);
    });

    testWidgets('rate limit counts down, then Redeem is available again '
        '(R15, 03b §2.17)', (WidgetTester tester) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(
          429,
          Payloads.error('TOO_MANY_REQUESTS', <String, Object?>{
            'retry_after': 30,
          }),
        ),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      expect(rich('possible again in 30 s'), findsOneWidget);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 10));
      expect(rich('possible again in 20 s'), findsOneWidget);

      final List<(String, bool)> said = recordAnnouncements(tester);
      await tester.pump(const Duration(seconds: 20));
      await settle(tester);
      expect(find.byType(StatusBanner), findsNothing);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNotNull,
      );
      expect(
        said.map(((String, bool) a) => a.$1),
        contains('Redeem available again'),
      );
      await finishApp(tester, app);
    });
  });
}
