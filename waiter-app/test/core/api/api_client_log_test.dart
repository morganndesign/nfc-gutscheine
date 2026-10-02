import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/api/api_client.dart';
import 'package:giftcard_waiter/core/api/waiter_api.dart';
import 'package:giftcard_waiter/core/diagnostics/diagnostic_log.dart';
import 'package:giftcard_waiter/core/state/client_identity.dart';

import '../../support/app_harness.dart';

/// The diagnostic log keeps the route of every request, never the values in its path (09 §4.1 rule 1: no card
/// data, no idempotency keys).
void main() {
  const String key = '3f0c1d2e-4b5a-4968-8776-655443322110';
  const String card = 'B-2026-0001-0007';

  test('idempotency keys, card numbers and ids never reach the log', () async {
    final DiagnosticLog log = DiagnosticLog();
    final FakeBackend backend = FakeBackend()
      ..on('GET', '/vouchers/${Payloads.voucherId}/redemptions/$key', FakeReply(200, Payloads.outcome()))
      ..on('GET', '/cards/$card', FakeReply(200, Payloads.cardInfo(number: card)))
      ..on('POST', '/presentments/cards/${Payloads.cardAuthentication}', FakeReply(201, Payloads.cardPresentment()));
    final WaiterApi api = WaiterApi(
      ApiClient(
        baseUrl: 'https://cards.example.at/api/v1',
        identity: AppClientIdentity(deviceId: 'd', userAgent: 'ua', language: 'en'),
        dio: Dio()..httpClientAdapter = backend,
        log: log,
      ),
    );

    await api.redemptionOutcome(voucherId: Payloads.voucherId, idempotencyKey: key);
    await api.card(card);
    await api.completeCardPresentment(Payloads.cardAuthentication, '9100');

    final String all = log.entries.join('\n');
    expect(all, isNot(contains(key)));
    expect(all, isNot(contains(card)));
    expect(all, isNot(contains(Payloads.voucherId)));
    expect(all, isNot(contains(Payloads.cardAuthentication)));
    expect(all, contains('GET /vouchers/*/redemptions/* '));
    expect(all, contains('GET /cards/* '));
    expect(all, contains('POST /presentments/cards/* '));
  });

  test('fixed routes stay readable', () {
    expect(ApiClient.loggablePath('/auth/me'), '/auth/me');
    expect(ApiClient.loggablePath('/admin/card-batches/b-1/personalizations'), '/admin/card-batches/*/personalizations');
    expect(ApiClient.loggablePath('/cards/B-1/suspend'), '/cards/*/suspend');
  });
}
