import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/cards/s26_card_pickup.dart';

import '../../support/app_harness.dart';
import '../scan/scan_harness.dart';

final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

/// S26 · Hand out an online card, on a scripted camera: scan, the voucher's amount, the tap, the card number.
void main() {
  const String begin = '/presentments/cards';
  const String complete = '/presentments/cards/${Payloads.cardAuthentication}';

  Map<String, Object?> pickupPresentment() {
    final Map<String, Object?> p = Payloads.presentment(balance: 5000);
    final Map<String, Object?> data = Map<String, Object?>.of(p['data']! as Map<String, Object?>);
    data['purpose'] = 'pickup';
    data['voucher'] = <String, Object?>{
      ...data['voucher']! as Map<String, Object?>,
      'card_pickup': <String, Object?>{'open': true, 'from': '2026-10-01T12:00:00Z'},
    };
    return <String, Object?>{'data': data};
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('scan the e-mailed QR, tap a stock card: the card number and the balance', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(user: Payloads.cardManager(), nfc: FakeNfcRelay());
    unawaited(app.session.start());
    await settle(tester);
    app.backend
      ..on('POST', '/presentments', FakeReply(201, pickupPresentment()))
      ..on('POST', begin, FakeReply(200, Payloads.cardChallenge()))
      ..on('POST', complete, FakeReply(200, Payloads.cardOnly(number: 'B-2026-0001-0042')))
      ..on(
        'POST',
        '/vouchers/${Payloads.voucherId}/card-pickup',
        FakeReply(200, <String, Object?>{
          'data': <String, Object?>{
            'id': Payloads.voucherId,
            'balance': 5000,
            'currency': 'EUR',
            'media': <Object?>[
              <String, Object?>{'type': 'nfc_card', 'status': 'active', 'card_number': 'B-2026-0001-0042'},
            ],
          },
        }),
      );
    final FakeQrCamera camera = FakeQrCamera();
    await pumpHosted(tester, app, CardPickupScreen(cameraFactory: ({required bool torch}) => camera));

    expect(text(en.menuCardsPickup), findsOneWidget);
    await tester.tap(text(en.pickupScanAction));
    await settle(tester);
    expect(text(en.pickupScanTitle), findsOneWidget);

    camera.detect(Payloads.qr);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(text(en.pickupScanTitle), findsNothing, reason: 'the camera closed with the first QR');
    expect(
      app.backend.requests.where((RecordedRequest r) => r.path == '/presentments').single.body,
      containsPair('purpose', 'pickup'),
    );
    expect(find.textContaining('50', findRichText: true), findsWidgets);
    expect(text(en.pickupTapAction), findsOneWidget);

    await tester.tap(text(en.pickupTapAction));
    await settle(tester);
    expect(text(en.pickupDoneTitle), findsOneWidget);
    expect(find.textContaining('B-2026-0001-0042', findRichText: true), findsOneWidget);
    expect(app.backend.requests.where((RecordedRequest r) => r.path.endsWith('/card-pickup')), hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
    await tester.pump(const Duration(minutes: 2));
  });
}
