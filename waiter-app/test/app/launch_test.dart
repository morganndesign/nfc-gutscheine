import 'dart:async';

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
  testWidgets('bootstrap that never completes → startup problem screen after the timeout', (WidgetTester tester) async {
    final Completer<AppServices> never = Completer<AppServices>();
    unawaited(launch(start: () => never.future, timeout: const Duration(seconds: 20)));
    await tester.pump(const Duration(seconds: 19));
    expect(find.byType(StartupFailureApp), findsNothing, reason: 'still starting before the timeout');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byType(StartupFailureApp), findsOneWidget);
    expect(find.textContaining('start did not finish within 20 s', findRichText: true), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // runApp was called outside pumpWidget: tear the app down
  });
}
