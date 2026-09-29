import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/app/waiter_app.dart';

import 'app_harness.dart';

/// Pumps the whole app (real navigator, real controllers, fake platform
/// edges) in [locale] and lets the start-up settle. Screens are reached by
/// driving the app like a waiter would (QR detections, taps, scripted backend).
///
/// Always finish a test with [finishApp] so no timer outlives it.
Future<void> pumpWaiterApp(
  WidgetTester tester,
  TestApp app, {
  Locale locale = const Locale('en'),
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  tester.platformDispatcher.localesTestValue = <Locale>[locale];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  await tester.pumpWidget(WaiterApp(services: app.services));
  await settle(tester);
}

/// Lets requests, microtasks and short animations complete.
Future<void> settle(WidgetTester tester, [int frames = 6]) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Unmounts the app and cancels every controller timer.
Future<void> finishApp(WidgetTester tester, TestApp app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  app.dispose();
  await tester.pump(const Duration(seconds: 1));
}
