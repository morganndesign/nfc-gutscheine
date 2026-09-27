import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/platform/nfc_service.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';

/// Redeem endpoint of the sample card.
const String redeemPath = '/cards/${Payloads.cardId}/redeem';

/// UID of the sample card's chip.
const String cardUid = '04:A2:3F:1B:6C:80:12';

/// iPhone sheet texts for tests that start a session directly.
const IosSheetTexts sheetTexts = IosSheetTexts(
  alert: 'alert',
  found: 'found',
  multiple: 'multiple',
  readFailed: 'readFailed',
  timeoutSoon: 'timeoutSoon',
  notCard: 'notCard',
);

/// A running app on S05 (Android unless [isIos]) and its card-link sink.
Future<(TestApp, Sink<Uri>)> startAppWithLinks(
  WidgetTester tester, {
  bool isIos = false,
  Locale locale = const Locale('en'),
  Size size = const Size(393, 852),
}) async {
  final TestApp app = await TestApp.create(isIos: isIos);
  final StreamController<Uri> links = await pumpWaiterApp(
    tester,
    app,
    locale: locale,
    size: size,
  );
  addTearDown(links.close);
  return (app, links);
}

/// A running app on S05 (Android unless [isIos]).
Future<TestApp> startApp(
  WidgetTester tester, {
  bool isIos = false,
  Locale locale = const Locale('en'),
  Size size = const Size(393, 852),
  Map<String, Object> prefs = const <String, Object>{},
  Map<String, Object?>? user,
}) async {
  final TestApp app = await TestApp.create(
    isIos: isIos,
    prefs: prefs,
    user: user,
  );
  final StreamController<Uri> links = await pumpWaiterApp(
    tester,
    app,
    locale: locale,
    size: size,
  );
  addTearDown(links.close);
  return app;
}

/// Reads the sample card: Android reader mode, or the iPhone sheet.
Future<void> readCard(
  WidgetTester tester,
  TestApp app, {
  String uid = cardUid,
}) async {
  if (app.loop.isIos) {
    unawaited(app.loop.startScan(sheetTexts));
    await settle(tester, 2);
  }
  app.nfc.emit(NfcTagRead(uid: uid, url: Payloads.cardUrl()));
  await settle(tester);
}

/// App on S07 for a card answered with [scan].
Future<TestApp> openCharge(
  WidgetTester tester, {
  Map<String, Object?>? scan,
  bool isIos = false,
  Locale locale = const Locale('en'),
  Size size = const Size(393, 852),
  Map<String, Object> prefs = const <String, Object>{},
  Map<String, Object?>? user,
}) async {
  final TestApp app = await startApp(
    tester,
    isIos: isIos,
    locale: locale,
    size: size,
    prefs: prefs,
    user: user,
  );
  app.backend.on('POST', '/scan', FakeReply(200, scan ?? Payloads.scan()));
  await readCard(tester, app);
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
