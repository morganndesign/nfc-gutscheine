import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import '../scan/scan_harness.dart' show mockDeniedCamera;

/// Redemption endpoint of the sample voucher.
const String redeemPath = '/vouchers/${Payloads.voucherId}/redemptions';

/// A running app on S05.
Future<TestApp> startApp(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Size size = const Size(393, 852),
  Map<String, Object> prefs = const <String, Object>{},
  Map<String, Object?>? user,
}) async {
  final TestApp app = await TestApp.create(prefs: prefs, user: user);
  await pumpWaiterApp(tester, app, locale: locale, size: size);
  return app;
}

/// Scans the sample voucher's QR (the camera itself is not under test here).
Future<void> scanVoucher(WidgetTester tester, TestApp app) async {
  mockDeniedCamera();
  app.loop.openQr();
  await settle(tester, 2);
  app.loop.qrDetected(Payloads.qr);
  await settle(tester);
}

/// App on S07 for a voucher answered with [presentment].
Future<TestApp> openCharge(
  WidgetTester tester, {
  Map<String, Object?>? presentment,
  Locale locale = const Locale('en'),
  Size size = const Size(393, 852),
  Map<String, Object> prefs = const <String, Object>{},
  Map<String, Object?>? user,
}) async {
  final TestApp app = await startApp(tester, locale: locale, size: size, prefs: prefs, user: user);
  app.backend.on('POST', '/presentments', FakeReply(201, presentment ?? Payloads.presentment()));
  await scanVoucher(tester, app);
  expect(app.loop.state, isA<ChargeState>());
  return app;
}

/// Finds a keypad key by its label.
Finder key(String label) => find.descendant(
  of: find.byType(Keypad),
  matching: find.text(label, findRichText: true),
);

/// Types [digits] on the keypad.
Future<void> typeDigits(WidgetTester tester, String digits) async {
  for (final String d in digits.split('')) {
    await tester.tap(key(d));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await settle(tester, 2);
}

/// The keypad's ⌫ key.
Finder get deleteKey => find.descendant(
  of: find.byType(Keypad),
  matching: find.byType(WaiterIconView),
);

/// Long-presses ⌫ (500 ms) to clear the amount.
Future<void> clearAmount(WidgetTester tester) async {
  final TestGesture press = await tester.startGesture(
    tester.getCenter(deleteKey),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await press.up();
  await settle(tester, 2);
}

/// ✕ in the TopRow.
Finder get closeButton => find.byType(WaiterIconButton).first;

/// Rich text containing [text].
Finder rich(String text) => find.textContaining(text, findRichText: true);

/// The current S07 state.
ChargeState chargeOf(TestApp app) => app.loop.state as ChargeState;

/// Screen-reader announcements posted from now on (message, assertive).
List<(String, bool)> recordAnnouncements(WidgetTester tester) {
  final List<(String, bool)> log = <(String, bool)>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (Object? message) async {
      final Map<Object?, Object?> event = message! as Map<Object?, Object?>;
      if (event['type'] == 'announce') {
        final Map<Object?, Object?> data =
            event['data']! as Map<Object?, Object?>;
        log.add((data['message']! as String, data['assertiveness'] == 1));
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return log;
}

/// Sounds of [file] played so far.
int soundCount(TestApp app, String file) =>
    app.sounds.where((String s) => s == file).length;

/// Haptic calls so far.
int hapticCount(TestApp app) =>
    app.feedbackCalls.where((MethodCall c) => c.method == 'haptic').length;

/// Lets real time pass: the feedback service spaces different haptics by
/// wall-clock time (11 §4 T6), which fake time does not advance.
Future<void> realPause(WidgetTester tester) => tester.runAsync(
  () => Future<void>.delayed(const Duration(milliseconds: 100)),
);
