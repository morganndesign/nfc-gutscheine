import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/screens/s10_problem.dart';
import 'package:giftcard_waiter/screens/s12_qr_scan.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'charge_harness.dart';

/// S10 variants when a scanned QR gave no voucher (03b §5, 12 §3.1).
void main() {
  Future<TestApp> problem(
    WidgetTester tester,
    FakeReply reply, {
    FakeReply? then,
    Locale locale = const Locale('en'),
  }) async {
    final TestApp app = await startApp(tester, locale: locale);
    app.backend.on('POST', '/presentments', reply);
    if (then != null) app.backend.on('POST', '/presentments', then);
    await scanVoucher(tester, app);
    expect(app.loop.state, isA<ProblemState>());
    expect(find.byType(ProblemPage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    return app;
  }

  FakeReply notRecognized() =>
      FakeReply(422, Payloads.error('VOUCHER_NOT_RECOGNIZED'));

  Finder primary() => find.byType(PrimaryButton);

  VoidCallback? onPrimary(WidgetTester tester) =>
      tester.widget<PrimaryButton>(primary()).onPressed;

  testWidgets('not recognized: "Scan again" / "Done", support code, error '
      'feedback once (L01)', (WidgetTester tester) async {
    final TestApp app = await problem(tester, notRecognized());
    expect((app.loop.state as ProblemState).kind, ProblemKind.notRecognized);
    expect(rich('Not a voucher of this restaurant'), findsOneWidget);
    expect(rich('This code is not valid here.'), findsOneWidget);
    expect(rich('Scan again'), findsOneWidget);
    expect(rich('Done'), findsOneWidget);
    expect(rich('Try again'), findsNothing, reason: 'the same code again');
    expect(
      find.textContaining(RegExp(r'^Code [0-9A-F]{6}$'), findRichText: true),
      findsOneWidget,
    );
    expect(soundCount(app, 'gcw_error'), 1, reason: 'E25 once');

    await tester.tap(rich('Scan again'));
    await settle(tester);
    expect(app.loop.state, isA<QrScanState>());
    expect(find.byType(QrScanScreen), findsOneWidget);
    expect(app.backend.to('POST', '/presentments'), hasLength(1));
    await finishApp(tester, app);
  });

  testWidgets('not recognized: "Done" returns to Ready', (
    WidgetTester tester,
  ) async {
    final TestApp app = await problem(tester, notRecognized());
    await tester.tap(rich('Done'));
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    await finishApp(tester, app);
  });

  testWidgets('throttled: disabled countdown button enables at 0 '
      '(L05, AC-S10-4)', (WidgetTester tester) async {
    final TestApp app = await problem(
      tester,
      FakeReply(
        429,
        Payloads.error('PRESENTMENT_THROTTLED', <String, Object?>{
          'retry_after': 42,
        }),
      ),
    );
    expect(rich('Too many scans'), findsOneWidget);
    expect(rich('Scan again · 0:42'), findsOneWidget);
    expect(onPrimary(tester), isNull);
    expect(rich('Code '), findsNothing, reason: '12 §2.5');
    final List<(String, bool)> said = recordAnnouncements(tester);

    await tester.pump(const Duration(seconds: 10));
    expect(rich('Scan again · 0:32'), findsOneWidget);
    await tester.pump(const Duration(seconds: 32));
    await settle(tester);
    expect(rich('Scan again · '), findsNothing);
    expect(onPrimary(tester), isNotNull);
    expect(
      said.map(((String, bool) a) => a.$1),
      contains('Scanning available again'),
    );
    await tester.tap(primary());
    await settle(tester);
    expect(app.loop.state, isA<QrScanState>());
    await finishApp(tester, app);
  });

  testWidgets('network: "Try again" re-sends the same QR for a new '
      'presentment and keeps S10 busy until the result (L06, 03b §5.1)', (
    WidgetTester tester,
  ) async {
    final TestApp app = await problem(
      tester,
      FakeReply.transport(),
      then: FakeReply(201, Payloads.presentment(), const Duration(seconds: 1)),
    );
    expect(rich('No connection'), findsOneWidget);
    expect(rich('The voucher could not be checked.'), findsOneWidget);
    expect(rich('Code '), findsNothing);
    expect(soundCount(app, 'gcw_warning'), 1, reason: 'E26 once');
    await tester.tap(rich('Try again'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.loop.state, isA<PresentingState>());
    expect(find.byType(ProblemPage), findsOneWidget);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).status,
      ButtonStatus.loading,
    );
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(app.loop.state, isA<ChargeState>());
    final List<RecordedRequest> presents = app.backend.to(
      'POST',
      '/presentments',
    );
    expect(presents, hasLength(2));
    expect(presents.last.body!['credential'], Payloads.qr);
    await finishApp(tester, app);
  });

  testWidgets('server error: "Try again" with support code (L07)', (
    WidgetTester tester,
  ) async {
    final TestApp app = await problem(
      tester,
      FakeReply(503, Payloads.error('SERVICE_UNAVAILABLE')),
      then: FakeReply(201, Payloads.presentment()),
    );
    expect(rich('Service not available right now'), findsOneWidget);
    expect(rich('The problem is not the voucher.'), findsOneWidget);
    expect(find.text('Try again', findRichText: true), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Code '), findRichText: true),
      findsOne,
    );
    await tester.tap(primary());
    await settle(tester);
    expect(app.loop.state, isA<ChargeState>());
    await finishApp(tester, app);
  });

  testWidgets('long-press on the support code copies the full request id '
      '(AC-S10-6)', (WidgetTester tester) async {
    final List<String> copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(
            (call.arguments as Map<Object?, Object?>)['text']! as String,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final TestApp app = await problem(tester, notRecognized());
    final String code = (app.loop.state as ProblemState).supportCode!;
    await tester.longPress(rich('Code $code'));
    await settle(tester);
    expect(copied, hasLength(1));
    expect(copied.single.length, greaterThan(code.length));
    expect(copied.single.replaceAll('-', '').toUpperCase(), endsWith(code));
    await finishApp(tester, app);
  });

  testWidgets('✕ returns to Ready', (WidgetTester tester) async {
    final TestApp app = await problem(tester, notRecognized());
    await tester.tap(closeButton);
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    await finishApp(tester, app);
  });

  testWidgets('German and BHS copy', (WidgetTester tester) async {
    TestApp app = await problem(
      tester,
      notRecognized(),
      locale: const Locale('de'),
    );
    expect(rich('Kein Gutschein dieses Lokals'), findsOneWidget);
    await finishApp(tester, app);

    app = await problem(tester, notRecognized(), locale: const Locale('bs'));
    expect(rich('Nije vaučer ovog restorana'), findsOneWidget);
    await finishApp(tester, app);
  });
}
