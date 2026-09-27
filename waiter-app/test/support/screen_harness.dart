import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/app/waiter_app.dart';
import 'package:mocktail/mocktail.dart';

import 'app_harness.dart';

class _MockAppLinks extends Mock implements AppLinks {}

/// Pumps the whole app (real navigator, real controllers, fake platform
/// edges) in [locale] and lets the start-up settle. Screens are reached by
/// driving the app like a waiter would (NFC events, taps, scripted backend).
///
/// Always finish a test with [finishApp] so no timer outlives it.
Future<StreamController<Uri>> pumpWaiterApp(
  WidgetTester tester,
  TestApp app, {
  Locale locale = const Locale('en'),
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  tester.platformDispatcher.localesTestValue = <Locale>[locale];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  final StreamController<Uri> links = StreamController<Uri>.broadcast();
  final _MockAppLinks appLinks = _MockAppLinks();
  when(() => appLinks.uriLinkStream).thenAnswer((_) => links.stream);

  await tester.pumpWidget(WaiterApp(services: app.services, appLinks: appLinks));
  await settle(tester);
  return links;
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
