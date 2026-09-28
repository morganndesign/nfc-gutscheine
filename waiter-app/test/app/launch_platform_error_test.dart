import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/app/app_scope.dart';
import 'package:giftcard_waiter/app/startup_failure_app.dart';
import 'package:giftcard_waiter/main.dart';

/// The launch screen stays until `runApp` draws the first frame. These tests pin
/// that `launch` always reaches a frame, whatever the service setup does
/// (1.4.1 awaited `bootstrap()` without try/timeout: one failing or unanswered
/// secure-storage call left the phone on the launch screen for ever).
void main() {
  testWidgets('the 1.4.1 failure (Keystore key needs a fingerprint) → problem screen, not the launch screen', (
    WidgetTester tester,
  ) async {
    int attempts = 0;
    Future<AppServices> failing() async {
      attempts++;
      throw PlatformException(
        code: 'Exception encountered',
        message: 'At least one fingerprint must be enrolled to create keys requiring user authentication for every use',
      );
    }

    unawaited(launch(start: failing));
    await tester.pump();
    await tester.pump();
    expect(find.byType(StartupFailureApp), findsOneWidget);
    expect(attempts, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
