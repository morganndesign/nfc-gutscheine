import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/app/app_scope.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/l10n/l10n.dart';
import 'package:giftcard_waiter/core/platform/channels.dart';
import 'package:giftcard_waiter/core/platform/feedback_scope.dart';
import 'package:giftcard_waiter/core/platform/nfc_service.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/screens/scan/qr_camera.dart';

import '../../support/app_harness.dart';

/// Phone frames of 03a §0.1 and the tablet landscape frame of 08 §4.2.
const Size iphoneFrame = Size(393, 852);
const Size androidFrame = Size(412, 915);
const Size compactFrame = Size(375, 667);
const Size tabletLandscape = Size(1180, 820);

/// A card URL of another domain (bank / transit cards land here, L10).
const String foreignUrl = 'https://bank.example.com/pay/1234';

/// UID of the sample NTAG.
const String sampleUid = '04:A2:3F:1B:6C:80:12';

/// Android: a card is held to the phone and read completely.
void tapCard(TestApp app, {String? url, String uid = sampleUid}) =>
    app.nfc.emit(NfcTagRead(uid: uid, url: url ?? Payloads.cardUrl()));

/// Records method calls on the app's system channel (open app settings).
List<MethodCall> recordSystemChannel() {
  final List<MethodCall> calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(WaiterChannels.system, (MethodCall call) async {
        calls.add(call);
        return null;
      });
  return calls;
}

/// Makes the `mobile_scanner` plugin answer like a device whose camera
/// permission was declined (the plugin channels are absent in widget tests).
void mockDeniedCamera() {
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const MethodChannel method = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/method',
  );
  messenger.setMockMethodCallHandler(method, (MethodCall call) async {
    switch (call.method) {
      case 'state':
        return 2;
      case 'request':
        return false;
    }
    return null;
  });
  for (final String name in <String>[
    'dev.steenbakker.mobile_scanner/scanner/event',
    'dev.steenbakker.mobile_scanner/scanner/deviceOrientation',
  ]) {
    messenger.setMockStreamHandler(
      EventChannel(name),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  }
  addTearDown(() {
    messenger.setMockMethodCallHandler(method, null);
  });
}

/// A scriptable [QrCamera] for S12 widget tests.
class FakeQrCamera extends ChangeNotifier implements QrCamera {
  FakeQrCamera({
    QrCameraStatus status = QrCameraStatus.running,
    this.torchAvailable = true,
    bool torch = false,
  }) : _status = status,
       _torch = torch;

  QrCameraStatus _status;
  bool _torch;
  final StreamController<QrDetection> _detections =
      StreamController<QrDetection>.broadcast();
  final List<String> calls = <String>[];

  @override
  final bool torchAvailable;

  @override
  QrCameraStatus get status => _status;

  set status(QrCameraStatus value) {
    _status = value;
    notifyListeners();
  }

  @override
  bool get torchOn => _torch;

  @override
  Stream<QrDetection> get detections => _detections.stream;

  /// The camera decoded [raw].
  void detect(String raw) => _detections.add(
    QrDetection(
      raw: raw,
      corners: const <Offset>[
        Offset(100, 100),
        Offset(300, 100),
        Offset(300, 300),
        Offset(100, 300),
      ],
      imageSize: const Size(480, 640),
    ),
  );

  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(color: Color(0xFF334155));

  @override
  Future<void> start() async {
    calls.add('start');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> toggleTorch() async {
    calls.add('torch');
    _torch = !_torch;
    notifyListeners();
  }

  @override
  Future<void> focusAt(Offset point) async {
    calls.add('focus');
  }

  @override
  void dispose() {
    calls.add('dispose');
    unawaited(_detections.close());
    super.dispose();
  }
}

/// Hosts [screen] with the same scaffolding as the app root (theme scope,
/// localisation, feedback, snackbars) on the real controllers of [app] —
/// for screens that need an injected platform edge (the S12 camera).
Future<void> pumpHosted(
  WidgetTester tester,
  TestApp app,
  Widget screen, {
  Locale locale = const Locale('en'),
  Size size = iphoneFrame,
  ThemeMode theme = ThemeMode.light,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  tester.platformDispatcher.localesTestValue = <Locale>[locale];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.pumpWidget(
    AppScope(
      services: app.services,
      child: FeedbackScope(
        service: app.services.feedback,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: waiterThemeData(Brightness.light),
          darkTheme: waiterThemeData(Brightness.dark),
          themeMode: theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: supportedLocales,
          localeListResolutionCallback: localeListResolutionCallback,
          builder: (BuildContext context, Widget? child) => WaiterThemeScope(
            mode: theme,
            child: SnackbarHost(child: child!),
          ),
          home: screen,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

/// The haptic calls recorded on the feedback channel.
int hapticCount(TestApp app) =>
    app.feedbackCalls.where((MethodCall c) => c.method == 'haptic').length;

/// Text finder that also matches the `RichText` painted by `ScaledText`.
Finder text(String value) => find.text(value, findRichText: true);
