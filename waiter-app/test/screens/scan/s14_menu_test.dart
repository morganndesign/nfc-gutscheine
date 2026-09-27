import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';
import 'package:giftcard_waiter/core/storage/settings_store.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/screens/s05_ready.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'scan_harness.dart';

Future<TestApp> _openMenu(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Size size = iphoneFrame,
  String menuLabel = 'Menu, Anna Berger',
  bool device = true,
}) async {
  final TestApp app = await TestApp.create();
  if (device) {
    app.backend.on(
      'GET',
      '/devices/current',
      FakeReply(200, <String, Object?>{
        'data': <String, Object?>{'name': 'Pixel 7 von Anna'},
      }),
    );
  }
  await pumpWaiterApp(tester, app, locale: locale, size: size);
  await tester.tap(find.bySemanticsLabel(menuLabel));
  // The sheet rises with motion.spring.soft (≈ 0.55 s).
  await settle(tester, 20);
  return app;
}

Iterable<MethodCall> _feedback(TestApp app, String method) =>
    app.feedbackCalls.where((MethodCall c) => c.method == method);

void main() {
  testWidgets('account, restaurant, device, settings, sign out, version', (
    WidgetTester tester,
  ) async {
    final TestApp app = await _openMenu(tester);
    expect(text('Anna Berger'), findsOneWidget);
    expect(text('anna@example.at'), findsOneWidget);
    expect(text('Restaurant'), findsOneWidget);
    expect(text('Trattoria Bella Vista'), findsWidgets);
    expect(text('Device'), findsOneWidget);
    expect(text('Pixel 7 von Anna'), findsOneWidget);
    expect(text('Appearance'), findsOneWidget);
    expect(text('Match system'), findsOneWidget);
    expect(text('Sounds'), findsOneWidget);
    expect(text('Haptics'), findsOneWidget);
    expect(text('Keep screen on'), findsOneWidget);
    expect(text('While scanning and redeeming'), findsOneWidget);
    expect(
      text('Outdoors, the light theme is easier to read.'),
      findsOneWidget,
    );
    expect(text('Sign out'), findsOneWidget);
    expect(text('Version 1.0.0 (1)'), findsOneWidget);
    expect(find.textContaining('Reload', findRichText: true), findsNothing);
    expect(
      app.loop.wantsReaderMode,
      isFalse,
      reason: 'reader mode pauses while a sheet is open',
    );
    await finishApp(tester, app);
  });

  testWidgets('the device row is left out when the name cannot be loaded', (
    WidgetTester tester,
  ) async {
    final TestApp app = await _openMenu(tester, device: false);
    expect(text('Device'), findsNothing);
    await finishApp(tester, app);
  });

  testWidgets(
    'Sounds off/on: select haptic, preview sample only when turned on',
    (WidgetTester tester) async {
      final TestApp app = await _openMenu(tester);
      final SettingsStore settings = app.services.settings;
      app.feedbackCalls.clear();

      await tester.tap(text('Sounds'));
      await settle(tester);
      expect(settings.sound, isFalse);
      expect(_feedback(app, 'sound'), isEmpty);
      expect(_feedback(app, 'haptic'), hasLength(1));

      await tester.tap(text('Sounds'));
      await settle(tester);
      expect(settings.sound, isTrue);
      expect(
        _feedback(app, 'sound'),
        hasLength(1),
        reason: 'E62 preview of sound.cardDetected',
      );
      await finishApp(tester, app);
    },
  );

  testWidgets(
    'Haptics on plays the preview, off plays nothing; Keep screen on toggles',
    (WidgetTester tester) async {
      final TestApp app = await _openMenu(tester);
      final SettingsStore settings = app.services.settings;
      app.feedbackCalls.clear();

      await tester.tap(text('Haptics'));
      await settle(tester);
      expect(settings.haptics, isFalse);
      expect(_feedback(app, 'haptic'), isEmpty);
      await tester.tap(text('Haptics'));
      await settle(tester);
      expect(settings.haptics, isTrue);
      expect(_feedback(app, 'haptic'), hasLength(1));

      await tester.tap(text('Keep screen on'));
      await settle(tester);
      expect(settings.keepScreenOn, isFalse);
      await finishApp(tester, app);
    },
  );

  testWidgets('Appearance: nested sheet, Dark applies without restart', (
    WidgetTester tester,
  ) async {
    final TestApp app = await _openMenu(tester);
    await tester.tap(text('Appearance'));
    await settle(tester, 20);
    expect(text('Light'), findsOneWidget);
    expect(text('Dark'), findsOneWidget);
    await tester.tap(text('Dark'));
    await settle(tester, 20);
    expect(app.services.settings.theme, ThemePreference.dark);
    expect(
      tester.element(find.byType(ReadyScreen)).waiter.brightness,
      Brightness.dark,
    );
    expect(
      text('Dark'),
      findsOneWidget,
      reason: 'the Appearance row shows the new value',
    );
    await finishApp(tester, app);
  });

  testWidgets('Sign out asks first; Cancel keeps the session', (
    WidgetTester tester,
  ) async {
    final TestApp app = await _openMenu(tester);
    await tester.tap(text('Sign out'));
    await settle(tester);
    expect(text('Sign out?'), findsOneWidget);
    expect(
      text('The shift history on this device will be deleted.'),
      findsOneWidget,
    );
    await tester.tap(text('Cancel'));
    await settle(tester);
    expect(app.session.phase, AccessPhase.active);
    await finishApp(tester, app);
  });

  testWidgets(
    'Sign out confirmed: token and Recent cleared, S02 — also offline',
    (WidgetTester tester) async {
      final TestApp app = await _openMenu(tester);
      app.backend.on('POST', '/auth/logout', FakeReply.transport());
      await tester.tap(text('Sign out'));
      await settle(tester);
      // The dialog's DangerButton is the last "Sign out" in the tree.
      await tester.tap(text('Sign out').last);
      await settle(tester, 20);
      expect(app.session.phase, AccessPhase.signedOut);
      expect(app.secrets.values['token'], isNull);
      expect(app.services.recent.entries, isEmpty);
      expect(app.loop.wantsReaderMode, isFalse);
      await finishApp(tester, app);
    },
  );

  testWidgets('German and BHS copy', (WidgetTester tester) async {
    final TestApp de = await _openMenu(
      tester,
      locale: const Locale('de'),
      menuLabel: 'Menü, Anna Berger',
    );
    expect(text('Lokal'), findsOneWidget);
    expect(text('Darstellung'), findsOneWidget);
    expect(text('Töne'), findsOneWidget);
    expect(text('Abmelden'), findsOneWidget);
    await finishApp(tester, de);

    final TestApp bs = await _openMenu(
      tester,
      locale: const Locale('bs'),
      menuLabel: 'Meni, Anna Berger',
    );
    expect(text('Izgled'), findsOneWidget);
    expect(text('Odjavi se'), findsOneWidget);
    await finishApp(tester, bs);
  });

  for (final (String name, Size size) in <(String, Size)>[
    ('compact phone', compactFrame),
    ('tablet landscape', tabletLandscape),
  ]) {
    testWidgets(
      '$name at 200 % text: no overflow, rows semantics expose state',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final TestApp app = await _openMenu(tester, size: size);
        expect(tester.takeException(), isNull);
        expect(
          tester.getSemantics(text('Sounds')),
          isSemantics(label: 'Sounds', isToggled: true, hasToggledState: true),
        );
        await finishApp(tester, app);
        handle.dispose();
      },
    );
  }
}
