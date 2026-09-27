import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/screens/s12_qr_scan.dart';
import 'package:giftcard_waiter/screens/scan/qr_camera.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'scan_harness.dart';

/// S12 on the real controllers with a scripted camera.
Future<(TestApp, FakeQrCamera)> _hosted(
  WidgetTester tester, {
  QrCameraStatus status = QrCameraStatus.running,
  Size size = iphoneFrame,
  Locale locale = const Locale('en'),
  ThemeMode theme = ThemeMode.light,
}) async {
  final TestApp app = await TestApp.create();
  final FakeQrCamera camera = FakeQrCamera(status: status);
  app.loop.openQr();
  await pumpHosted(
    tester,
    app,
    QrScanScreen(cameraFactory: ({required bool torch}) => camera),
    size: size,
    locale: locale,
    theme: theme,
  );
  return (app, camera);
}

Future<void> _finish(WidgetTester tester, TestApp app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  app.dispose();
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  testWidgets('searching: title, hint, torch, "Enter card number"', (
    WidgetTester tester,
  ) async {
    final (TestApp app, FakeQrCamera camera) = await _hosted(tester);
    expect(text('Scan QR code'), findsOneWidget);
    expect(text('Point the camera at the QR code on the card'), findsOneWidget);
    expect(text('Enter card number'), findsOneWidget);
    expect(find.bySemanticsLabel('Turn on light'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Turn on light'));
    await tester.pump();
    expect(camera.calls, contains('torch'));
    expect(find.bySemanticsLabel('Turn off light'), findsOneWidget);
    await _finish(tester, app);
  });

  testWidgets(
    'not a gift card: warning line for 2.5 s, same payload ignored for 3 s, no request',
    (WidgetTester tester) async {
      final (TestApp app, FakeQrCamera camera) = await _hosted(tester);
      final int hapticsBefore = hapticCount(app);
      camera.detect(foreignUrl);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(text("This QR code isn't a gift card"), findsOneWidget);
      expect(hapticCount(app), hapticsBefore + 1);

      camera.detect(foreignUrl);
      await tester.pump();
      expect(
        hapticCount(app),
        hapticsBefore + 1,
        reason: 'same payload ignored for 3 s',
      );
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        text('Point the camera at the QR code on the card'),
        findsOneWidget,
      );
      expect(app.backend.to('POST', '/scan'), isEmpty);
      expect(app.loop.state, isA<QrScanState>());
      await _finish(tester, app);
    },
  );

  testWidgets(
    'valid card: one request (method qr), preview freezes, looking up → slow → Cancel',
    (WidgetTester tester) async {
      final (TestApp app, FakeQrCamera camera) = await _hosted(tester);
      app.backend.on(
        'POST',
        '/scan',
        FakeReply.hang(const Duration(seconds: 30)),
      );
      camera
        ..detect(Payloads.cardUrl())
        ..detect(Payloads.cardUrl());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(app.backend.to('POST', '/scan'), hasLength(1));
      expect(app.backend.to('POST', '/scan').single.body!['method'], 'qr');
      expect(camera.calls, contains('pause'));
      expect(text('Looking up card …'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 200));
      expect(text('Still looking …'), findsOneWidget);
      expect(text('Cancel'), findsOneWidget);
      expect(text('Enter card number'), findsNothing);
      await tester.tap(text('Cancel'));
      await tester.pump();
      expect(
        app.loop.state,
        isA<QrScanState>(),
        reason: 'Cancel resumes scanning on S12',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(camera.calls.last, 'start', reason: 'the frozen preview resumes');
      expect(
        text('Point the camera at the QR code on the card'),
        findsOneWidget,
      );
      await _finish(tester, app);
    },
  );

  testWidgets('"Enter card number" replaces S12 with S11', (
    WidgetTester tester,
  ) async {
    final (TestApp app, _) = await _hosted(tester);
    await tester.tap(text('Enter card number'));
    await tester.pump();
    expect(app.loop.state, isA<ManualEntryState>());
    await _finish(tester, app);
  });

  testWidgets('offline pauses detection with the offline caption', (
    WidgetTester tester,
  ) async {
    final (TestApp app, FakeQrCamera camera) = await _hosted(tester);
    app.connectivity.setOnline(false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(text('No connection'), findsOneWidget);
    camera.detect(Payloads.cardUrl());
    await tester.pump();
    expect(app.backend.to('POST', '/scan'), isEmpty);
    await _finish(tester, app);
  });

  testWidgets('camera unavailable (P05): only "Enter card number"', (
    WidgetTester tester,
  ) async {
    final (TestApp app, _) = await _hosted(
      tester,
      status: QrCameraStatus.unavailable,
    );
    expect(text('Camera not available'), findsOneWidget);
    expect(
      text('Close other apps using the camera or enter the card number.'),
      findsOneWidget,
    );
    expect(text('Open Settings'), findsNothing);
    expect(find.bySemanticsLabel('Turn on light'), findsNothing);
    await _finish(tester, app);
  });

  testWidgets(
    'camera denied on the real app path (mobile_scanner answers "denied")',
    (WidgetTester tester) async {
      mockDeniedCamera();
      final TestApp app = await TestApp.create();
      final List<MethodCall> system = recordSystemChannel();
      await pumpWaiterApp(tester, app);
      await tester.tap(text('QR code'));
      await settle(tester, 10);
      expect(find.byType(QrScanScreen), findsOneWidget);
      expect(text('Camera access is off'), findsOneWidget);
      expect(
        text('Allow camera access in Settings to scan QR codes.'),
        findsOneWidget,
      );

      await tester.tap(text('Open Settings'));
      await settle(tester);
      expect(
        system.map((MethodCall c) => c.method),
        contains('openAppSettings'),
      );

      await tester.tap(text('Enter card number'));
      await settle(tester);
      expect(app.loop.state, isA<ManualEntryState>());
      await finishApp(tester, app);
    },
  );

  testWidgets(
    'always dark values and light status bar content, also in the light theme',
    (WidgetTester tester) async {
      final (TestApp app, _) = await _hosted(tester);
      final BuildContext hint = tester.element(
        text('Point the camera at the QR code on the card'),
      );
      expect(hint.waiter.brightness, Brightness.dark);
      final AnnotatedRegion<SystemUiOverlayStyle> region = tester.widget(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(region.value, SystemUiOverlayStyle.light);
      await _finish(tester, app);
    },
  );

  testWidgets('German copy', (WidgetTester tester) async {
    final (TestApp app, _) = await _hosted(tester, locale: const Locale('de'));
    expect(text('QR-Code scannen'), findsOneWidget);
    expect(text('Kamera auf den QR-Code der Karte richten'), findsOneWidget);
    expect(text('Kartennummer eingeben'), findsOneWidget);
    await _finish(tester, app);
  });

  for (final (String name, Size size, double scale) in <(String, Size, double)>[
    ('compact', compactFrame, 1),
    ('compact at 200 % text', compactFrame, 2),
    ('tablet landscape', tabletLandscape, 1),
  ]) {
    testWidgets(
      '$name lays out without overflow; "Enter card number" in the thumb zone',
      (WidgetTester tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final (TestApp app, _) = await _hosted(tester, size: size);
        expect(tester.takeException(), isNull);
        final Rect button = tester.getRect(
          find.ancestor(
            of: text('Enter card number'),
            matching: find.byType(SecondaryButton),
          ),
        );
        expect(button.top, greaterThan(size.height * 0.55));
        await _finish(tester, app);
      },
    );
  }

  testWidgets('the camera is released when S12 leaves', (
    WidgetTester tester,
  ) async {
    final (TestApp app, FakeQrCamera camera) = await _hosted(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(camera.calls, contains('dispose'));
    app.dispose();
    await tester.pump(const Duration(seconds: 1));
  });
}
