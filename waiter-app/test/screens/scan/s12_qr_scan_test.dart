import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/s05_ready.dart';
import 'package:giftcard_waiter/screens/s12_qr_scan.dart';
import 'package:giftcard_waiter/screens/scan/qr_camera.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'scan_harness.dart';

final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

/// Printed card links, card numbers and other codes are not voucher QRs.
const String _foreign = 'https://cards.example.at/c/9f1c7a0e-3b2d-4c1a-9e8f-0a1b2c3d4e5f';

/// S12 on the real controllers with a scripted camera.
Future<(TestApp, FakeQrCamera)> _hosted(
  WidgetTester tester, {
  QrCameraStatus status = QrCameraStatus.running,
  bool torchAvailable = true,
  Size size = iphoneFrame,
  Locale locale = const Locale('en'),
  ThemeMode theme = ThemeMode.light,
}) async {
  final TestApp app = await TestApp.create();
  final FakeQrCamera camera = FakeQrCamera(status: status, torchAvailable: torchAvailable);
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
  testWidgets('searching: title, hint, torch; no "Enter card number"', (WidgetTester tester) async {
    final (TestApp app, FakeQrCamera camera) = await _hosted(tester);
    expect(text(en.qrTitle), findsOneWidget);
    expect(text(en.qrHint), findsOneWidget);
    expect(text('Enter card number'), findsNothing);
    expect(find.byType(SecondaryButton), findsNothing);
    expect(find.byType(PrimaryButton), findsNothing);
    expect(find.bySemanticsLabel(en.qrTorchOn), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(en.qrTorchOn));
    await tester.pump();
    expect(camera.calls, contains('torch'));
    expect(find.bySemanticsLabel(en.qrTorchOff), findsOneWidget);
    await _finish(tester, app);
  });

  testWidgets('no torch button when the camera has no light', (WidgetTester tester) async {
    final (TestApp app, _) = await _hosted(tester, torchAvailable: false);
    expect(find.bySemanticsLabel(en.qrTorchOn), findsNothing);
    await _finish(tester, app);
  });

  testWidgets('not a voucher: warning line for 2.5 s, same payload ignored for 3 s, no request', (
    WidgetTester tester,
  ) async {
    final (TestApp app, FakeQrCamera camera) = await _hosted(tester);
    final int hapticsBefore = hapticCount(app);
    camera.detect(_foreign);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(text(en.qrNotVoucher), findsOneWidget);
    expect(hapticCount(app), hapticsBefore + 1);

    camera.detect(_foreign);
    await tester.pump();
    expect(hapticCount(app), hapticsBefore + 1, reason: 'same payload ignored for 3 s');
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 200));
    expect(text(en.qrHint), findsOneWidget);
    expect(app.backend.requests.where((RecordedRequest r) => r.path == '/presentments'), isEmpty);
    expect(app.loop.state, isA<QrScanState>());
    await _finish(tester, app);
  });

  testWidgets('card numbers, card links and near-miss voucher texts are all "not a voucher"', (
    WidgetTester tester,
  ) async {
    final (TestApp app, FakeQrCamera camera) = await _hosted(tester);
    for (final String raw in <String>[
      _foreign,
      '5285105870986488',
      'GCPV1.short',
      'GCPV2.AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_AbCdE',
    ]) {
      camera.detect(raw);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(text(en.qrNotVoucher), findsOneWidget, reason: raw);
    }
    expect(app.backend.to('POST', '/presentments'), isEmpty);
    expect(app.loop.state, isA<QrScanState>());
    await _finish(tester, app);
  });

  testWidgets('voucher QR: one request, preview freezes, checking → slow → Cancel resumes', (
    WidgetTester tester,
  ) async {
    final (TestApp app, FakeQrCamera camera) = await _hosted(tester);
    app.backend.on('POST', '/presentments', FakeReply.hang(const Duration(seconds: 30)));
    camera
      ..detect(Payloads.qr)
      ..detect(Payloads.qr);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(app.backend.to('POST', '/presentments'), hasLength(1));
    expect(app.backend.to('POST', '/presentments').single.body, <String, Object?>{
      'purpose': 'spend',
      'method': 'printable_qr',
      'credential': Payloads.qr,
    });
    expect(app.loop.state, isA<PresentingState>());
    expect(camera.calls, contains('pause'));
    expect(text(en.scanLookingUp), findsOneWidget);
    expect(text(en.commonCancel), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));
    expect(text(en.scanSlow), findsOneWidget);
    expect(text(en.commonCancel), findsOneWidget);
    await tester.tap(text(en.commonCancel));
    await tester.pump();
    expect(app.loop.state, isA<QrScanState>(), reason: 'Cancel resumes scanning on S12');
    await tester.pump(const Duration(milliseconds: 200));
    expect(camera.calls.last, 'start', reason: 'the frozen preview resumes');
    expect(text(en.qrHint), findsOneWidget);
    await _finish(tester, app);
  });

  testWidgets('surrounding whitespace is trimmed before sending', (WidgetTester tester) async {
    final (TestApp app, FakeQrCamera camera) = await _hosted(tester);
    app.backend.on('POST', '/presentments', FakeReply.hang(const Duration(seconds: 30)));
    camera.detect(' ${Payloads.qr}\n');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(app.backend.to('POST', '/presentments').single.body!['credential'], Payloads.qr);
    await _finish(tester, app);
  });

  testWidgets('offline pauses detection with the offline caption', (WidgetTester tester) async {
    final (TestApp app, FakeQrCamera camera) = await _hosted(tester);
    app.connectivity.setOnline(false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(text(en.offlineTitle), findsOneWidget);
    camera.detect(Payloads.qr);
    await tester.pump();
    expect(app.backend.to('POST', '/presentments'), isEmpty);
    expect(app.loop.state, isA<QrScanState>());
    await _finish(tester, app);
  });

  testWidgets('✕ returns to S05', (WidgetTester tester) async {
    final (TestApp app, _) = await _hosted(tester);
    await tester.tap(find.byType(WaiterIconButton).first);
    await tester.pump();
    expect(app.loop.state, isA<ReadyState>());
    await _finish(tester, app);
  });

  testWidgets('camera unavailable (P05): body and "Close" back to S05', (WidgetTester tester) async {
    final (TestApp app, _) = await _hosted(tester, status: QrCameraStatus.unavailable);
    expect(text(en.cameraUnavailableTitle), findsOneWidget);
    expect(text(en.cameraUnavailableBody), findsOneWidget);
    expect(text(en.cameraDeniedAction), findsNothing);
    expect(text('Enter card number'), findsNothing);
    expect(find.bySemanticsLabel(en.qrTorchOn), findsNothing);

    await tester.tap(find.ancestor(of: text(en.commonClose), matching: find.byType(SecondaryButton)));
    await tester.pump();
    expect(app.loop.state, isA<ReadyState>());
    await _finish(tester, app);
  });

  testWidgets('camera denied (scripted): "Open Settings", restarts on resume', (WidgetTester tester) async {
    final (TestApp app, FakeQrCamera camera) = await _hosted(tester, status: QrCameraStatus.denied);
    final List<MethodCall> system = recordSystemChannel();
    expect(text(en.cameraDeniedTitle), findsOneWidget);
    expect(text(en.cameraDeniedBody), findsOneWidget);
    expect(find.ancestor(of: text(en.commonClose), matching: find.byType(SecondaryButton)), findsNothing);

    await tester.tap(text(en.cameraDeniedAction));
    await tester.pump();
    expect(system.map((MethodCall c) => c.method), contains('openAppSettings'));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(camera.calls, contains('start'));
    await _finish(tester, app);
  });

  testWidgets('camera denied on the real app path (mobile_scanner answers "denied")', (WidgetTester tester) async {
    mockDeniedCamera();
    final TestApp app = await TestApp.create();
    final List<MethodCall> system = recordSystemChannel();
    await pumpWaiterApp(tester, app);
    await tester.tap(find.ancestor(of: text(en.readyScan), matching: find.byType(PrimaryButton)));
    await settle(tester, 10);
    expect(find.byType(QrScanScreen), findsOneWidget);
    expect(text(en.cameraDeniedTitle), findsOneWidget);
    expect(text(en.cameraDeniedBody), findsOneWidget);

    await tester.tap(text(en.cameraDeniedAction));
    await settle(tester);
    expect(system.map((MethodCall c) => c.method), contains('openAppSettings'));

    app.loop.back();
    await settle(tester, 10);
    expect(find.byType(ReadyScreen), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets('always dark values and light status bar content, also in the light theme', (
    WidgetTester tester,
  ) async {
    final (TestApp app, _) = await _hosted(tester);
    final BuildContext hint = tester.element(text(en.qrHint));
    expect(hint.waiter.brightness, Brightness.dark);
    final AnnotatedRegion<SystemUiOverlayStyle> region = tester.widget(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
    );
    expect(region.value, SystemUiOverlayStyle.light);
    await _finish(tester, app);
  });

  testWidgets('German copy', (WidgetTester tester) async {
    final (TestApp app, FakeQrCamera camera) = await _hosted(tester, locale: const Locale('de'));
    expect(text('Gutschein scannen'), findsOneWidget);
    expect(text('Kamera auf den QR-Code des Gutscheins richten'), findsOneWidget);
    camera.detect(_foreign);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(text('Dieser QR-Code ist kein Gutschein'), findsOneWidget);
    await _finish(tester, app);
  });

  for (final (String name, Size size, double scale) in <(String, Size, double)>[
    ('compact', compactFrame, 1),
    ('compact at 200 % text', compactFrame, 2),
    ('tablet landscape', tabletLandscape, 1),
  ]) {
    testWidgets('$name lays out without overflow', (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (TestApp app, _) = await _hosted(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(text(en.qrHint), findsOneWidget);
      await _finish(tester, app);
    });

    testWidgets('$name: camera problem lays out without overflow', (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (TestApp app, _) = await _hosted(tester, size: size, status: QrCameraStatus.denied);
      expect(tester.takeException(), isNull);
      expect(text(en.cameraDeniedAction), findsOneWidget);
      await _finish(tester, app);
    });
  }

  testWidgets('the camera is released when S12 leaves', (WidgetTester tester) async {
    final (TestApp app, FakeQrCamera camera) = await _hosted(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(camera.calls, contains('dispose'));
    app.dispose();
    await tester.pump(const Duration(seconds: 1));
  });
}
