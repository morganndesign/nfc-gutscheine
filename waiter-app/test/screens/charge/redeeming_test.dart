import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/screens/charge/uncertain_panel.dart';
import 'package:giftcard_waiter/screens/s05_ready.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'charge_harness.dart';

/// S08 in-place states (03b §3) and the S07 notices after a definitive
/// answer to `POST /vouchers/{id}/redemptions` (12 §3.2 R05–R16).
void main() {
  Future<TestApp> typed(
    WidgetTester tester,
    List<FakeReply> replies, {
    String digits = '2490',
    Map<String, Object?>? presentment,
  }) async {
    final TestApp app = await openCharge(tester, presentment: presentment);
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

  /// Runs the automatic retries out to the final uncertain state.
  Future<void> toFinal(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
    }
  }

  Finder checkAgain() => find.ancestor(
    of: rich('Check again'),
    matching: find.byType(PrimaryButton),
  );

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
      final RecordedRequest redeem = app.backend.to('POST', redeemPath).single;
      expect(redeem.body, <String, Object?>{
        'amount': 2490,
        'presentment_id': Payloads.presentmentId,
      });
      expect(redeem.header('Idempotency-Key'), isNotNull);
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
      expect(rich('Nothing is ever booked twice.'), findsOne);

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

    testWidgets('final: "Check again" and "Cancel"; Cancel returns to S05 and '
        'keeps the attempt (AC-S08-8/10/11)', (WidgetTester tester) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply.transport(),
      ]);
      final List<(String, bool)> said = recordAnnouncements(tester);
      await tapRedeem(tester);
      await settle(tester);
      expect(chargeOf(app).phase, RedeemPhase.uncertainAuto);
      await toFinal(tester);
      expect(chargeOf(app).phase, RedeemPhase.uncertainFinal);
      expect(rich('Not confirmed yet. Check again'), findsOneWidget);
      expect(rich('Code '), findsOneWidget);
      expect(checkAgain(), findsOneWidget);
      expect(rich('Cancel'), findsOneWidget);
      expect(
        said.where(((String, bool) a) => a.$1.startsWith('Connection')),
        isNotEmpty,
      );
      expect(rich('nothing was charged'), findsNothing);
      final String key = app.pending.entries.single.key;

      // Asked about in the background once S05 shows: still possibly
      // running, so it stays stored.
      app.backend.on(
        'GET',
        '$redeemPath/$key',
        FakeReply(200, Payloads.outcome()),
      );
      await tester.tap(rich('Cancel'));
      await settle(tester);
      expect(app.loop.state, isA<ReadyState>());
      expect(find.byType(ReadyScreen), findsOneWidget);
      expect(rich('Not confirmed. It is checked automatically'), findsOne);
      expect(app.pending.entries.single.key, key, reason: 'kept');
      expect(app.pending.entries.single.amount, 2490);
      expect(keys(app).toSet(), <String>{key});
      await finishApp(tester, app);
    });

    testWidgets('final: "Check again" re-sends with the same key and lands on '
        'S09', (WidgetTester tester) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply.transport(),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      await toFinal(tester);
      expect(chargeOf(app).phase, RedeemPhase.uncertainFinal);
      final int sent = keys(app).length;

      app.backend.only(
        'POST',
        redeemPath,
        FakeReply(
          200,
          Payloads.redeemed(amount: 2490, balanceAfter: 2510, replayed: true),
        ),
      );
      await tester.tap(checkAgain());
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(app.loop.state, isA<SuccessState>());
      expect(keys(app), hasLength(sent + 1));
      expect(keys(app).toSet(), hasLength(1));
      expect(app.backend.to('POST', redeemPath).last.body, <String, Object?>{
        'amount': 2490,
        'presentment_id': Payloads.presentmentId,
      });
      expect(app.pending.entries, isEmpty);
      await finishApp(tester, app);
    });

    testWidgets('idempotency conflict: the key is asked about, never a new key '
        '(R13, AC-S08-13)', (WidgetTester tester) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(409, Payloads.error('IDEMPOTENCY_CONFLICT')),
      ]);
      app.backend.onPrefix(
        'GET',
        '$redeemPath/',
        FakeReply(200, Payloads.outcome(amount: 1000, balanceAfter: 4000)),
      );
      await tapRedeem(tester);
      await settle(tester);
      expect(app.backend.requests.where((RecordedRequest r) => r.method == 'GET' && r.path.startsWith('$redeemPath/')), isNotEmpty, reason: 'resolved by asking');
      expect(chargeOf(app).phase, RedeemPhase.entering);
      expect(chargeOf(app).notice, isA<EarlierBookedNotice>());
      expect(chargeOf(app).voucher.balance, 4000);
      expect(app.pending.entries, isEmpty);
      await tester.pump(const Duration(seconds: 5));
      expect(app.backend.to('POST', redeemPath), hasLength(1), reason: 'never a second debit');
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
      expect(chargeOf(app).voucher.balance, 2000);
      expect(rich('Balance changed: now € 20,00'), findsOneWidget);
      expect(rich('Use balance · € 20,00'), findsOneWidget);
      expect(
        said.map(((String, bool) a) => a.$1),
        contains(
          'Balance changed: now 20 euros. '
          '4 euros 90 more than the balance. Redeem not available.',
        ),
      );
      expect(app.pending.entries, isEmpty);
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      expect(rich('Balance changed'), findsNothing);
      expect(rich('€ 4,90 more than the balance'), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('max per redemption from the server: message, "Use '
        'maximum", checked client-side afterwards (R10)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(
          422,
          Payloads.error('DEBIT_LIMIT_EXCEEDED', <String, Object?>{
            'limit': 'per_transaction',
            'max': 1500,
          }),
        ),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      expect(chargeOf(app).notice, isA<MaxSingleNotice>());
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

    testWidgets('daily limit of the voucher: what is left today (R10)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(
          422,
          Payloads.error('DEBIT_LIMIT_EXCEEDED', <String, Object?>{
            'limit': 'per_voucher_per_day',
            'max': 10000,
            'remaining': 1000,
          }),
        ),
      ]);
      final List<(String, bool)> said = recordAnnouncements(tester);
      await tapRedeem(tester);
      await settle(tester);
      expect(chargeOf(app).notice, isA<DailyLimitNotice>());
      expect(
        rich('At most € 10,00 more with this voucher today'),
        findsOneWidget,
      );
      expect(
        said,
        contains(('At most 10 euros more with this voucher today', true)),
      );
      expect(chargeOf(app).amount, 2490, reason: 'the amount stays');
      expect(app.pending.entries, isEmpty);
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

    testWidgets('voucher blocked meanwhile: blocked variant with "Nothing was '
        'booked." (R07)', (WidgetTester tester) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(422, Payloads.error('VOUCHER_BLOCKED')),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      expect(chargeOf(app).condition, VoucherCondition.blocked);
      expect(rich('Nothing was booked.'), findsOneWidget);
      expect(rich('Voucher blocked'), findsOneWidget);
      expect(rich('Reason:'), findsNothing, reason: 'AC-S07-22');
      expect(find.byType(Keypad), findsNothing);
      expect(soundCount(app, 'gcw_error'), 1);
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      expect(rich('Nothing was booked.'), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('voucher expired meanwhile: expired variant (R07)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(422, Payloads.error('VOUCHER_EXPIRED')),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      expect(chargeOf(app).condition, VoucherCondition.expired);
      expect(rich('Nothing was booked.'), findsOneWidget);
      expect(rich('Voucher expired'), findsOneWidget);
      expect(find.byType(Keypad), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('voucher no longer redeemable without a status: empty '
        'variant (R07)', (WidgetTester tester) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(422, Payloads.error('VOUCHER_NOT_REDEEMABLE')),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      expect(chargeOf(app).condition, VoucherCondition.empty);
      expect(rich('Nothing was booked.'), findsOneWidget);
      expect(rich('No balance left'), findsOneWidget);
      await tester.tap(rich('Done'));
      await settle(tester);
      expect(app.loop.state, isA<ReadyState>());
      await finishApp(tester, app);
    });

    testWidgets('refused presentment: "Nothing was booked." and "Scan '
        'again" with the amount kept', (WidgetTester tester) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(
          422,
          Payloads.error('PRESENTMENT_INVALID', <String, Object?>{
            'reason': 'expired',
          }),
        ),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      expect(chargeOf(app).presentmentExpired, isTrue);
      expect(
        rich('Nothing was booked. Scan the voucher again to redeem.'),
        findsOneWidget,
      );
      final PrimaryButton rescan = tester.widget(find.byType(PrimaryButton));
      expect(rescan.label, 'Scan again');
      expect(app.pending.entries, isEmpty);

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
      expect(chargeOf(app).amount, 2490);
      expect(chargeOf(app).presentmentId, 'p-2');
      expect(rich('Redeem € 24,90'), findsOneWidget);
      expect(app.backend.to('POST', redeemPath), hasLength(1));
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

    testWidgets('velocity limit without a time: banner with "Please get a '
        'manager" (R14)', (WidgetTester tester) async {
      final TestApp app = await typed(tester, <FakeReply>[
        FakeReply(429, Payloads.error('VELOCITY_LIMIT_EXCEEDED')),
      ]);
      await tapRedeem(tester);
      await settle(tester);
      expect(find.byType(StatusBanner), findsOneWidget);
      expect(rich('Limit for this voucher reached'), findsOneWidget);
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
      final TestApp app = await typed(
        tester,
        <FakeReply>[
          FakeReply(
            429,
            Payloads.error('VELOCITY_LIMIT_EXCEEDED', <String, Object?>{
              'retry_after': 720,
            }),
          ),
        ],
        // Long enough that the countdown, not the presentment, decides.
        presentment: Payloads.presentment(expiresIn: 3600),
      );
      await tapRedeem(tester);
      await settle(tester);
      expect(rich('Possible again in 12'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      expect(rich('Possible again in 11'), findsOneWidget);
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
      expect(rich('possible again in 30'), findsOneWidget);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 10));
      expect(rich('possible again in 20'), findsOneWidget);

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
