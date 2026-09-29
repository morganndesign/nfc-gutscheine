import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/storage/pending_redemptions.dart';
import 'package:giftcard_waiter/core/storage/secure_store.dart';

/// Unresolved redemption attempts (audit M1, M2, M6): stored before the first
/// request, kept per user across sign-out and restart, one per voucher.
void main() {
  DateTime now = DateTime.utc(2026, 9, 26, 12);
  late MemorySecretStore secrets;
  late PendingRedemptionStore store;

  setUp(() {
    now = DateTime.utc(2026, 9, 26, 12);
    secrets = MemorySecretStore();
    store = PendingRedemptionStore(secrets, now: () => now);
  });

  Future<PendingRedemption> open(String voucher, int amount) =>
      store.open(voucherId: voucher, amount: amount, currency: 'EUR', last4: '6488', restaurantName: 'Bella Vista');

  test('an attempt is written to protected storage when it is opened', () async {
    await store.load('u-1');
    final PendingRedemption p = await open('v-1', 2490);
    final Map<String, Object?> stored = (jsonDecode(secrets.values['pending_redemptions_v1']!) as Map<String, Object?>);
    expect((stored['u-1']! as List<Object?>).single, containsPair('key', p.key));
    expect(store.forVoucher('v-1')?.amount, 2490);
    expect(store.forVoucher('v-2'), isNull);
  });

  test('one attempt per voucher; a new one replaces the resolved slot only', () async {
    await store.load('u-1');
    await open('v-1', 1000);
    await open('v-2', 500);
    final PendingRedemption again = await open('v-1', 1200);
    expect(store.entries, hasLength(2));
    expect(store.forVoucher('v-1')?.key, again.key);
  });

  test('survives a restart and belongs to the user who sent it', () async {
    await store.load('u-1');
    final PendingRedemption p = await open('v-1', 1000);
    store.detach();
    expect(store.entries, isEmpty, reason: 'signed out: nothing shown');

    final PendingRedemptionStore restarted = PendingRedemptionStore(secrets, now: () => now);
    await restarted.load('u-2');
    expect(restarted.entries, isEmpty, reason: 'another waiter never sees it');
    await restarted.load('u-1');
    expect(restarted.entries.single.key, p.key);
  });

  test('"not booked" is final only after the server ceiling', () async {
    await store.load('u-1');
    PendingRedemption p = await open('v-1', 1000);
    expect(store.notBookedIsFinal(p), isFalse);
    now = now.add(const Duration(seconds: 45));
    p = await store.resend(p);
    now = now.add(const Duration(seconds: 59));
    expect(store.notBookedIsFinal(p), isFalse, reason: 'counted from the last request');
    now = now.add(const Duration(seconds: 1));
    expect(store.notBookedIsFinal(p), isTrue);
  });

  test('resolving removes it and clears the storage key when empty', () async {
    await store.load('u-1');
    final PendingRedemption p = await open('v-1', 1000);
    await store.resolve(p);
    expect(store.entries, isEmpty);
    expect(secrets.values.containsKey('pending_redemptions_v1'), isFalse);
  });

  test('unreadable storage starts empty instead of failing', () async {
    secrets.values['pending_redemptions_v1'] = '{not json';
    await store.load('u-1');
    expect(store.entries, isEmpty);
  });
}
