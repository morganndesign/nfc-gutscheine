import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/cards/card_order.dart';

import '../../support/app_harness.dart';

/// Ordering cards (Android and iPhone alike): an order whose answer was lost is sent again with the same key, so
/// the platform returns the order that was placed instead of a second one (audit K5).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  Map<String, Object?> order() => <String, Object?>{
    'data': <String, Object?>{
      'id': 'o-1',
      'quantity': 50,
      'status': 'requested',
      'created_at': '2026-10-06T10:00:00+00:00',
    },
  };

  testWidgets('a retried order sends the same key; a new quantity is a new order', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(user: Payloads.cardManager());
    unawaited(app.session.start());
    await settle(tester);
    app.backend
      ..on('POST', '/card-orders', FakeReply.transport())
      ..on('POST', '/card-orders', FakeReply(201, order()))
      ..on('POST', '/card-orders', FakeReply(201, order()));
    final CardOrderController c = CardOrderController(api: app.services.api, session: app.session);
    c
      ..digit(5)
      ..digit(0);
    unawaited(c.submit());
    await settle(tester);
    expect(c.requestFailed, isTrue);

    unawaited(c.submit());
    await settle(tester);
    expect(c.sent, isNotNull);
    final List<String?> keys = app.backend
        .to('POST', '/card-orders')
        .map((RecordedRequest r) => r.header('Idempotency-Key'))
        .toList();
    expect(keys, hasLength(2));
    expect(keys.first, isNotNull);
    expect(keys.first, keys.last, reason: 'the retry is the same order');

    c.backspace();
    c.digit(1);
    unawaited(c.submit());
    await settle(tester);
    final RecordedRequest third = app.backend.to('POST', '/card-orders').last;
    expect(third.header('Idempotency-Key'), isNot(keys.first), reason: 'a new order after an answered one');
    c.dispose();
    app.dispose();
    await tester.pump(const Duration(minutes: 2));
  });
}
