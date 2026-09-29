import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/state/loop_controller.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';
import 'package:giftcard_waiter/core/storage/pending_redemptions.dart';

import '../../support/app_harness.dart';

/// The redeem loop with a scripted backend: QR → presentment → redemption,
/// and the money-safety rules for unknown outcomes (audit M1, M2, M6).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String redeemPath = '/vouchers/${Payloads.voucherId}/redemptions';

  late TestApp app;

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> started(WidgetTester tester) async {
    app = await TestApp.create();
    unawaited(app.session.start());
    await settle(tester);
    await settle(tester);
  }

  Future<void> scan(WidgetTester tester, [String raw = Payloads.qr]) async {
    app.loop.openQr();
    app.loop.qrDetected(raw);
    await settle(tester);
  }

  void typeAmount(int cents) {
    for (final String d in cents.toString().split('')) {
      app.loop.key(int.parse(d));
    }
  }

  ChargeState charge() => app.loop.state as ChargeState;

  String outcomePath(String key) => '$redeemPath/$key';

  Future<void> finish(WidgetTester tester) async {
    app.dispose();
    await tester.pump(const Duration(minutes: 2));
  }

  testWidgets('QR → presentment → charge → redeem → success → auto-return', (WidgetTester tester) async {
    await started(tester);
    expect(app.session.phase, AccessPhase.active);
    app.backend
      ..on('POST', '/presentments', FakeReply(201, Payloads.presentment()))
      ..on('POST', redeemPath, FakeReply(201, Payloads.redeemed(amount: 2490, balanceAfter: 2510)));

    await scan(tester);
    expect(app.loop.state, isA<ChargeState>());
    expect(app.backend.to('POST', '/presentments').single.body, <String, Object?>{
      'purpose': 'spend',
      'method': 'printable_qr',
      'credential': Payloads.qr,
    });

    typeAmount(2490);
    unawaited(app.loop.redeem());
    await settle(tester);

    final SuccessState success = app.loop.state as SuccessState;
    expect(success.entry.amount, 2490);
    expect(success.entry.balanceAfter, 2510, reason: 'from the server');
    expect(app.services.recent.entries.single.last4, '6488');
    expect(app.sounds, containsAllInOrder(<String>['gcw_card_detected', 'gcw_success']));
    expect(app.pending.entries, isEmpty, reason: 'resolved by the answer');

    final RecordedRequest redeem = app.backend.to('POST', redeemPath).single;
    expect(redeem.body, <String, Object?>{'amount': 2490, 'presentment_id': Payloads.presentmentId});
    expect(redeem.header('Idempotency-Key'), isNotNull);
    expect(redeem.header('X-Device-Id'), '00000000-0000-4000-8000-000000000001');

    await tester.pump(const Duration(seconds: 4));
    expect(app.loop.state, isA<SuccessState>());
    await tester.pump(const Duration(milliseconds: 520));
    expect(app.loop.state, isA<ReadyState>());
    await finish(tester);
  });

  testWidgets('Anything but a voucher QR is never sent', (WidgetTester tester) async {
    await started(tester);
    app.loop.openQr();
    for (final String raw in <String>[
      'https://cards.example.at/c/9f1c7a0e-3b2d-4c1a-9e8f-0a1b2c3d4e5f',
      '5285105870986488',
      'GCPV1.short',
      'GCPV2.AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_AbCdE',
    ]) {
      expect(app.loop.qrDetected(raw), isFalse, reason: raw);
    }
    await settle(tester);
    expect(app.backend.to('POST', '/presentments'), isEmpty);
    expect(app.loop.state, isA<QrScanState>());
    await finish(tester);
  });

  testWidgets('The attempt is stored before the request; slow and uncertain retries reuse its key', (
    WidgetTester tester,
  ) async {
    await started(tester);
    app.backend
      ..on('POST', '/presentments', FakeReply(201, Payloads.presentment()))
      ..on('POST', redeemPath, FakeReply.hang(const Duration(seconds: 30)))
      ..on('POST', redeemPath, FakeReply.transport())
      ..on('POST', redeemPath, FakeReply(200, Payloads.redeemed(amount: 1000, balanceAfter: 4000, replayed: true)));
    await scan(tester);
    typeAmount(1000);

    unawaited(app.loop.redeem());
    await settle(tester);
    expect(charge().phase, RedeemPhase.submitting);
    final PendingRedemption stored = app.pending.entries.single;
    expect(stored.amount, 1000);
    expect(app.secrets.values['pending_redemptions_v1'], contains(stored.key), reason: 'M6: survives a restart');
    expect(app.loop.back(), isTrue);
    expect(app.loop.state, isA<ChargeState>(), reason: 'no leaving while money may move');

    await tester.pump(const Duration(seconds: 8));
    await settle(tester);
    expect(charge().phase, RedeemPhase.uncertainAuto);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    expect(app.loop.state, isA<SuccessState>(), reason: 'a replay renders like 201');
    final List<RecordedRequest> attempts = app.backend.to('POST', redeemPath);
    expect(attempts, hasLength(3));
    expect(attempts.map((RecordedRequest r) => r.header('Idempotency-Key')).toSet(), <String>{stored.key});
    expect(attempts.map((RecordedRequest r) => r.header('X-Request-Id')).toSet(), hasLength(3));
    expect(app.pending.entries, isEmpty);
    await finish(tester);
  });

  testWidgets('M2: after Cancel the voucher takes no other amount until the earlier attempt is resolved', (
    WidgetTester tester,
  ) async {
    await started(tester);
    app.backend
      ..on('POST', '/presentments', FakeReply(201, Payloads.presentment()))
      ..on('POST', redeemPath, FakeReply(503, Payloads.error('SERVER')));
    await scan(tester);
    typeAmount(1500);
    unawaited(app.loop.redeem());
    await tester.pump(const Duration(seconds: 21));
    await settle(tester);
    expect(charge().phase, RedeemPhase.uncertainFinal);
    expect(charge().supportCode, hasLength(6));
    final String key = app.pending.entries.single.key;

    // Asked in the background at once (still possibly running → kept), then
    // again when the voucher is presented.
    app.backend
      ..on('GET', outcomePath(key), FakeReply(200, Payloads.outcome()))
      ..on('GET', outcomePath(key), FakeReply(200, Payloads.outcome(amount: 1500, balanceAfter: 3500)));
    app.loop.cancelUncertain();
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    expect(app.loop.takeUncertainCancelled(), isTrue);
    expect(app.pending.entries.single.key, key, reason: 'kept');

    // The same voucher again: the earlier attempt is asked about first.
    app.backend.only('POST', '/presentments', FakeReply(201, Payloads.presentment(balance: 3500, id: 'p-2')));
    await scan(tester);
    await settle(tester);
    expect(app.backend.to('GET', outcomePath(key)), isNotEmpty);
    expect(app.backend.to('POST', redeemPath), hasLength(greaterThan(0)));
    final int posts = app.backend.to('POST', redeemPath).length;
    expect(charge().phase, RedeemPhase.entering);
    expect(charge().voucher.balance, 3500);
    expect(charge().notice, isA<EarlierBookedNotice>());
    expect(app.pending.entries, isEmpty);
    expect(app.services.recent.entries.single.amount, 1500, reason: 'the booked attempt appears in Recent');
    expect(app.backend.to('POST', redeemPath), hasLength(posts), reason: 'asking never re-sends the debit');
    await finish(tester);
  });

  testWidgets('"Not booked" is final only once the attempt can no longer be running', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', '/presentments', FakeReply(201, Payloads.presentment()))
      ..on('POST', redeemPath, FakeReply(503, Payloads.error('SERVER')));
    await scan(tester);
    typeAmount(800);
    unawaited(app.loop.redeem());
    await tester.pump(const Duration(seconds: 21));
    await settle(tester);
    final String key = app.pending.entries.single.key;
    app.backend.only('GET', outcomePath(key), FakeReply(200, Payloads.outcome()));
    app.loop.cancelUncertain();
    await settle(tester);

    await scan(tester);
    await settle(tester);
    expect(charge().phase, RedeemPhase.resolving, reason: 'last request < 60 s ago');
    expect(app.loop.canRedeem(charge()), isFalse);
    typeAmount(5);
    expect(charge().amount, 0, reason: 'the amount is locked while resolving');

    await tester.pump(PendingRedemptionStore.serverCeiling);
    await settle(tester);
    expect(charge().phase, RedeemPhase.entering);
    expect(app.pending.entries, isEmpty);
    await finish(tester);
  });

  testWidgets('M6: unresolved attempts are resolved in the background and reported on S05', (
    WidgetTester tester,
  ) async {
    await started(tester);
    app.backend
      ..on('POST', '/presentments', FakeReply(201, Payloads.presentment()))
      ..on('POST', redeemPath, FakeReply.transport());
    await scan(tester);
    typeAmount(2000);
    unawaited(app.loop.redeem());
    await tester.pump(const Duration(seconds: 21));
    await settle(tester);
    final String key = app.pending.entries.single.key;

    app.backend.only('GET', outcomePath(key), FakeReply(200, Payloads.outcome(amount: 2000, balanceAfter: 3000)));
    app.loop.cancelUncertain();
    await settle(tester);
    expect(app.pending.entries, isEmpty);
    final List<PendingResolution> resolved = app.loop.takeResolutions();
    expect(resolved.single.booked, isTrue);
    expect(resolved.single.amount, 2000);
    expect(app.services.recent.entries.single.amount, 2000);
    await finish(tester);
  });

  for (final (int status, String code) in <(int, String)>[
    (429, 'TOO_MANY_REQUESTS'),
    (409, 'HTTP_409'),
    (400, 'BAD_REQUEST'),
    (404, 'NOT_FOUND'),
  ]) {
    testWidgets('A $status ($code) after an unanswered request never closes the attempt', (WidgetTester tester) async {
      await started(tester);
      app.backend
        ..on('POST', '/presentments', FakeReply(201, Payloads.presentment()))
        ..on('POST', redeemPath, FakeReply.transport())
        ..on('POST', redeemPath, FakeReply(status, Payloads.error(code)));
      await scan(tester);
      typeAmount(1200);
      unawaited(app.loop.redeem());
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(charge().phase, RedeemPhase.uncertainFinal);
      expect(app.pending.entries, hasLength(1));
      await finish(tester);
    });
  }

  testWidgets('A redemption code after an unanswered request is definitive', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', '/presentments', FakeReply(201, Payloads.presentment()))
      ..on('POST', redeemPath, FakeReply.transport())
      ..on('POST', redeemPath, FakeReply(422, Payloads.error('INSUFFICIENT_BALANCE', <String, Object?>{'balance': 900})));
    await scan(tester);
    typeAmount(1200);
    unawaited(app.loop.redeem());
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(charge().phase, RedeemPhase.entering);
    expect(charge().voucher.balance, 900);
    expect(app.pending.entries, isEmpty);
    await finish(tester);
  });

  testWidgets('The presentment runs out: Redeem stops, "Scan again" keeps the amount', (WidgetTester tester) async {
    await started(tester);
    app.backend.on('POST', '/presentments', FakeReply(201, Payloads.presentment(expiresIn: 60)));
    await scan(tester);
    typeAmount(1800);
    expect(app.loop.canRedeem(charge()), isTrue);

    await tester.pump(const Duration(seconds: 57));
    expect(charge().presentmentExpired, isTrue, reason: 'unused in its last 3 s');
    expect(app.loop.canRedeem(charge()), isFalse);

    app.backend.only('POST', '/presentments', FakeReply(201, Payloads.presentment(id: 'p-2')));
    app.loop.rescan();
    expect(app.loop.state, isA<QrScanState>());
    app.loop.qrDetected(Payloads.qr);
    await settle(tester);
    expect(charge().amount, 1800);
    expect(charge().presentmentId, 'p-2');
    expect(charge().presentmentExpired, isFalse);
    await finish(tester);
  });

  testWidgets('A refused presentment on redeem: nothing booked, scan again', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', '/presentments', FakeReply(201, Payloads.presentment()))
      ..on('POST', redeemPath, FakeReply(422, Payloads.error('PRESENTMENT_INVALID', <String, Object?>{'reason': 'expired'})));
    await scan(tester);
    typeAmount(900);
    unawaited(app.loop.redeem());
    await settle(tester);
    expect(charge().phase, RedeemPhase.entering);
    expect(charge().presentmentExpired, isTrue);
    expect(charge().notice, isA<NothingBookedNotice>());
    expect(app.pending.entries, isEmpty);
    await finish(tester);
  });

  testWidgets('Definitive answers: balance, limits and conflicts', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', '/presentments', FakeReply(201, Payloads.presentment()))
      ..on(
        'POST',
        redeemPath,
        FakeReply(422, Payloads.error('INSUFFICIENT_BALANCE', <String, Object?>{'balance': 1200})),
      )
      ..on(
        'POST',
        redeemPath,
        FakeReply(422, Payloads.error('DEBIT_LIMIT_EXCEEDED', <String, Object?>{'limit': 'per_transaction', 'max': 1000})),
      )
      ..on('POST', redeemPath, FakeReply(409, Payloads.error('IDEMPOTENCY_CONFLICT')))
      ..onPrefix('GET', '$redeemPath/', FakeReply(200, Payloads.outcome(amount: 400, balanceAfter: 800)));
    await scan(tester);
    typeAmount(2000);
    unawaited(app.loop.redeem());
    await settle(tester);
    expect(charge().voucher.balance, 1200);
    expect(charge().notice, isA<BalanceChangedNotice>());
    expect(app.pending.entries, isEmpty);
    expect(app.sounds.last, 'gcw_error');

    app.loop.clearAmount();
    typeAmount(1100);
    unawaited(app.loop.redeem());
    await settle(tester);
    expect(charge().notice, isA<MaxSingleNotice>());
    expect(charge().maxSingle, 1000);

    app.loop.clearAmount();
    typeAmount(900);
    unawaited(app.loop.redeem());
    await settle(tester);
    // A conflict is never answered with a new key: the key's outcome is asked.
    expect(charge().phase, RedeemPhase.entering);
    expect(charge().notice, isA<EarlierBookedNotice>());
    expect(charge().voucher.balance, 800);
    expect(app.pending.entries, isEmpty);
    await finish(tester);
  });

  testWidgets('No redemption request while offline', (WidgetTester tester) async {
    await started(tester);
    app.backend.on('POST', '/presentments', FakeReply(201, Payloads.presentment()));
    await scan(tester);
    typeAmount(500);
    app.connectivity.setOnline(false);
    unawaited(app.loop.redeem());
    await settle(tester);
    expect(app.backend.to('POST', redeemPath), isEmpty);
    expect(app.pending.entries, isEmpty);
    await finish(tester);
  });

  testWidgets('401 on the first request: nothing booked, the session sheet opens', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', '/presentments', FakeReply(201, Payloads.presentment()))
      ..on('POST', redeemPath, FakeReply(401, Payloads.error('UNAUTHENTICATED')));
    await scan(tester);
    typeAmount(700);
    unawaited(app.loop.redeem());
    await settle(tester);
    expect(app.session.expired, SessionContext.redeem);
    expect(charge().phase, RedeemPhase.entering);
    expect(charge().amount, 700);
    expect(app.pending.entries, isEmpty);
    await finish(tester);
  });

  testWidgets('Presentment problems: not recognized, throttled countdown, network retry', (WidgetTester tester) async {
    await started(tester);
    app.backend.on('POST', '/presentments', FakeReply(422, Payloads.error('MEDIUM_NOT_RECOGNIZED')));
    await scan(tester);
    expect((app.loop.state as ProblemState).kind, ProblemKind.notRecognized);
    expect((app.loop.state as ProblemState).supportCode, isNotNull);

    app.backend.only(
      'POST',
      '/presentments',
      FakeReply(429, <String, Object?>{'message': 'x', 'code': 'PRESENTMENT_THROTTLED', 'retry_after': 30}),
    );
    app.loop.scanAgain();
    app.loop.qrDetected(Payloads.qr);
    await settle(tester);
    expect((app.loop.state as ProblemState).kind, ProblemKind.throttled);
    app.loop.scanAgain();
    expect(app.loop.state, isA<ProblemState>(), reason: 'no scanning during the wait');
    await tester.pump(const Duration(seconds: 61));

    app.backend.only('POST', '/presentments', FakeReply.transport());
    app.loop.scanAgain();
    app.loop.qrDetected(Payloads.qr);
    await settle(tester);
    expect((app.loop.state as ProblemState).kind, ProblemKind.network);

    app.backend.only('POST', '/presentments', FakeReply(201, Payloads.presentment()));
    app.loop.retryPresent();
    await settle(tester);
    expect(app.loop.state, isA<ChargeState>());
    expect(app.backend.to('POST', '/presentments').last.body!['credential'], Payloads.qr);
    await finish(tester);
  });

  testWidgets('Device revoked while presenting blocks the app and clears the token', (WidgetTester tester) async {
    await started(tester);
    app.backend.on('POST', '/presentments', FakeReply(403, Payloads.error('DEVICE_REVOKED')));
    await scan(tester);
    expect(app.session.phase, AccessPhase.blocked);
    expect(app.session.blocked, BlockedKind.deviceRevoked);
    expect(app.secrets.values.containsKey('token'), isFalse);
    expect(app.loop.state, isA<ReadyState>());
    await finish(tester);
  });

  testWidgets('Voucher states: a blocked voucher cannot be redeemed and plays the error sound', (
    WidgetTester tester,
  ) async {
    await started(tester);
    app.backend.on('POST', '/presentments', FakeReply(201, Payloads.presentment(status: 'blocked')));
    await scan(tester);
    expect(charge().condition, VoucherCondition.blocked);
    typeAmount(100);
    expect(charge().amount, 0);
    expect(app.sounds.last, 'gcw_error');
    await finish(tester);
  });

  testWidgets('Partial redemption disabled: the amount is the full balance', (WidgetTester tester) async {
    await started(tester);
    app.backend.on('POST', '/presentments', FakeReply(201, Payloads.presentment(balance: 3200, partial: false)));
    await scan(tester);
    expect(charge().fullOnly, isTrue);
    expect(charge().amount, 3200);
    typeAmount(1);
    expect(charge().amount, 3200);
    await finish(tester);
  });
}
