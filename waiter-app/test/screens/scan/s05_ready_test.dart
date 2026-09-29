import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/s05_ready.dart';
import 'package:giftcard_waiter/screens/s12_qr_scan.dart';
import 'package:giftcard_waiter/screens/s20_sell_voucher.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import '../charge/charge_harness.dart' show openCharge, redeemPath, typeDigits;
import 'scan_harness.dart';

final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
final AppLocalizations de = lookupAppLocalizations(const Locale('de'));

/// The signed-in app, before it is pumped. [manager] signs in a user with
/// `vouchers.sell`; [pending] stores unresolved attempts of the waiter
/// (`u-1`) as a previous run of the app would have left them.
Future<TestApp> _app({
  bool manager = false,
  bool isIos = false,
  Map<String, Object> prefs = const <String, Object>{},
  List<Map<String, Object?>> pending = const <Map<String, Object?>>[],
}) async {
  final TestApp app = await TestApp.create(
    isIos: isIos,
    prefs: prefs,
    user: manager ? Payloads.manager() : null,
  );
  if (pending.isNotEmpty) {
    app.secrets.values['pending_redemptions_v1'] = jsonEncode(<String, Object?>{'u-1': pending});
  }
  return app;
}

/// One stored, unresolved attempt; [sentAgo] ≥ 60 s makes "not booked" final.
Map<String, Object?> _attempt({
  String key = 'k-1',
  int amount = 2490,
  Duration sentAgo = Duration.zero,
}) => <String, Object?>{
  'key': key,
  'voucher': Payloads.voucherId,
  'amount': amount,
  'currency': 'EUR',
  'last4': '6488',
  'restaurant': 'Trattoria Bella Vista',
  'sent': clock.now().subtract(sentAgo).toUtc().toIso8601String(),
};

Finder _primary(String label) => find.ancestor(of: text(label), matching: find.byType(PrimaryButton));

Finder _secondary(String label) => find.ancestor(of: text(label), matching: find.byType(SecondaryButton));

Future<void> _goOffline(WidgetTester tester, TestApp app) async {
  app.connectivity.setOnline(false);
  await tester.pump(const Duration(seconds: 2));
  await settle(tester);
}

void main() {
  group('S05 · ready', () {
    testWidgets('TopBar, QR plate, title, hint and "Scan voucher" (EN)', (WidgetTester tester) async {
      final TestApp app = await _app();
      await pumpWaiterApp(tester, app, size: androidFrame);

      expect(find.byType(ReadyScreen), findsOneWidget);
      expect(app.loop.state, isA<ReadyState>());
      expect(text('Trattoria Bella Vista'), findsOneWidget);
      expect(find.bySemanticsLabel('Recent'), findsOneWidget);
      expect(find.bySemanticsLabel('Menu, Anna Berger'), findsOneWidget);
      expect(text(en.readyTitle), findsOneWidget);
      expect(text(en.readyHint), findsOneWidget);
      expect(_primary(en.readyScan), findsOneWidget);
      expect(
        find.byWidgetPredicate((Widget w) => w is WaiterIconView && w.icon == WaiterIcon.scanQrCode),
        findsWidgets,
        reason: 'QR plate and the button icon',
      );
      expect(find.byType(WaiterBanner), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('identical on iPhone', (WidgetTester tester) async {
      final TestApp app = await _app(isIos: true);
      await pumpWaiterApp(tester, app);
      expect(text(en.readyTitle), findsOneWidget);
      expect(text(en.readyHint), findsOneWidget);
      expect(_primary(en.readyScan), findsOneWidget);
      expect(text(en.readyTapCard), findsOneWidget, reason: 'cards on iPhone exactly as on Android');
      expect(text(en.readySell), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('German copy', (WidgetTester tester) async {
      final TestApp app = await _app(manager: true);
      await pumpWaiterApp(tester, app, locale: const Locale('de'), size: androidFrame);
      expect(text('Gutschein scannen'), findsNWidgets(2), reason: 'title and button');
      expect(
        text('Kamera auf den QR-Code des Gutscheins richten – gedruckt oder am Handy des Gastes.'),
        findsOneWidget,
      );
      expect(_primary(de.readyScan), findsOneWidget);
      expect(_secondary('Gutschein verkaufen'), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('"Scan voucher" opens S12', (WidgetTester tester) async {
      mockDeniedCamera();
      final TestApp app = await _app();
      await pumpWaiterApp(tester, app, size: androidFrame);
      await tester.tap(_primary(en.readyScan));
      await settle(tester, 10);
      expect(app.loop.state, isA<QrScanState>());
      expect(find.byType(QrScanScreen), findsOneWidget);

      app.loop.back();
      await settle(tester, 10);
      expect(app.loop.state, isA<ReadyState>());
      expect(find.byType(QrScanScreen), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('Enter on a hardware keyboard opens S12', (WidgetTester tester) async {
      mockDeniedCamera();
      final TestApp app = await _app();
      await pumpWaiterApp(tester, app, size: androidFrame);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester, 10);
      expect(app.loop.state, isA<QrScanState>());
      await finishApp(tester, app);
    });
  });

  group('S05 · sell voucher (S20)', () {
    testWidgets('waiters without vouchers.sell see no "Sell voucher"', (WidgetTester tester) async {
      final TestApp app = await _app();
      await pumpWaiterApp(tester, app, size: androidFrame);
      expect(text(en.readySell), findsNothing);
      expect(find.byType(SecondaryButton), findsOneWidget, reason: 'only "Tap card"');
      await finishApp(tester, app);
    });

    testWidgets('a manager without vouchers.sell sees no "Sell voucher"', (WidgetTester tester) async {
      final TestApp app = await TestApp.create(user: Payloads.manager(selling: false));
      await pumpWaiterApp(tester, app, size: androidFrame);
      expect(text(en.readySell), findsNothing);
      await finishApp(tester, app);
    });

    for (final String role in <String>['manager', 'owner']) {
      testWidgets('$role: "Sell voucher" below "Scan voucher" opens S20', (WidgetTester tester) async {
        final TestApp app = await TestApp.create(user: Payloads.manager(role: role));
        await pumpWaiterApp(tester, app, size: androidFrame);
        final Rect scan = tester.getRect(_primary(en.readyScan));
        final Rect sell = tester.getRect(_secondary(en.readySell));
        expect(sell.top, greaterThan(scan.bottom));

        await tester.tap(_secondary(en.readySell));
        await settle(tester, 10);
        expect(find.byType(SellVoucherScreen), findsOneWidget);
        expect(app.loop.state, isA<ReadyState>(), reason: 'selling is outside the redeem loop');
        await finishApp(tester, app);
      });
    }
  });

  group('S05 · offline', () {
    testWidgets('after 2 s: title, body, both buttons disabled; back with "Connected again"', (
      WidgetTester tester,
    ) async {
      mockDeniedCamera();
      final TestApp app = await _app(manager: true);
      await pumpWaiterApp(tester, app, size: androidFrame);

      app.connectivity.setOnline(false);
      await settle(tester);
      expect(text(en.offlineTitle), findsNothing, reason: 'offline needs 2 s of confirmed loss');
      expect(tester.widget<PrimaryButton>(_primary(en.readyScan)).onPressed, isNotNull);

      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(text(en.offlineTitle), findsOneWidget);
      expect(text(en.offlineBody), findsOneWidget);
      expect(text(en.readyTitle), findsNothing);
      expect(tester.widget<PrimaryButton>(_primary(en.readyScan)).onPressed, isNull);
      expect(tester.widget<SecondaryButton>(_secondary(en.readySell)).onPressed, isNull);

      await tester.tap(_primary(en.readyScan), warnIfMissed: false);
      await tester.tap(_secondary(en.readySell), warnIfMissed: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(app.loop.state, isA<ReadyState>());
      expect(find.byType(SellVoucherScreen), findsNothing);

      app.connectivity.setOnline(true);
      await settle(tester);
      expect(text(en.readyOnline), findsOneWidget);
      expect(text(en.readyTitle), findsOneWidget);
      expect(tester.widget<PrimaryButton>(_primary(en.readyScan)).onPressed, isNotNull);
      expect(tester.widget<SecondaryButton>(_secondary(en.readySell)).onPressed, isNotNull);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(text(en.readyOnline), findsNothing, reason: 'the snackbar stays 2 s');
      await finishApp(tester, app);
    });

    testWidgets('a short drop shows neither the offline state nor "Connected again"', (WidgetTester tester) async {
      final TestApp app = await _app();
      await pumpWaiterApp(tester, app, size: androidFrame);
      app.connectivity.setOnline(false);
      await tester.pump(const Duration(seconds: 1));
      app.connectivity.setOnline(true);
      await settle(tester);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(text(en.offlineTitle), findsNothing);
      expect(text(en.readyOnline), findsNothing);
      await finishApp(tester, app);
    });
  });

  group('S05 · banners', () {
    testWidgets('maintenance: server text, buttons stay put, dismissible', (WidgetTester tester) async {
      final TestApp app = await _app();
      app.backend.on('GET', '/app/config', FakeReply(200, Payloads.config(notice: 'Wartung heute 23:00–23:30.')));
      await pumpWaiterApp(tester, app, size: androidFrame);
      final double buttonBefore = tester.getRect(_primary(en.readyScan)).top;

      await tester.pump(const Duration(minutes: 6));
      unawaited(app.session.onForeground());
      await settle(tester);
      expect(text('Wartung heute 23:00–23:30.'), findsOneWidget);
      expect(tester.getRect(_primary(en.readyScan)).top, buttonBefore);

      await tester.tap(find.bySemanticsLabel(en.maintenanceDismiss));
      await settle(tester);
      expect(text('Wartung heute 23:00–23:30.'), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('an unresolved attempt shows the pending banner; not dismissible', (WidgetTester tester) async {
      final TestApp app = await _app(pending: <Map<String, Object?>>[_attempt()]);
      app.backend.on('GET', '$redeemPath/k-1', FakeReply(200, Payloads.outcome()));
      await pumpWaiterApp(tester, app, size: androidFrame);

      expect(app.backend.to('GET', '$redeemPath/k-1'), isNotEmpty, reason: 'asked about at once');
      expect(app.pending.entries, hasLength(1), reason: '"not booked" is not final within 60 s');
      expect(text(en.readyPendingTitle), findsOneWidget);
      expect(find.textContaining('24,90', findRichText: true), findsOneWidget);
      expect(find.textContaining('6488', findRichText: true), findsOneWidget);
      expect(find.bySemanticsLabel(en.maintenanceDismiss), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('the banner leaves with "not booked" once final (snackbar)', (WidgetTester tester) async {
      final TestApp app = await _app(pending: <Map<String, Object?>>[_attempt(sentAgo: const Duration(seconds: 30))]);
      app.backend.on('GET', '$redeemPath/k-1', FakeReply(200, Payloads.outcome()));
      await pumpWaiterApp(tester, app, size: androidFrame);
      expect(text(en.readyPendingTitle), findsOneWidget);

      // The next background check (20 s) is past the 60-s server ceiling.
      await tester.pump(const Duration(seconds: 40));
      await settle(tester);
      expect(app.pending.entries, isEmpty);
      expect(text(en.readyPendingTitle), findsNothing);
      expect(find.textContaining('was not booked', findRichText: true), findsOneWidget);
      expect(find.textContaining('24,90', findRichText: true), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await finishApp(tester, app);
    });

    testWidgets('an earlier attempt that was booked: snackbar, Recent updated, no banner', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _app(pending: <Map<String, Object?>>[_attempt()]);
      app.backend.on('GET', '$redeemPath/k-1', FakeReply(200, Payloads.outcome(amount: 2490, balanceAfter: 2510)));
      await pumpWaiterApp(tester, app, size: androidFrame);
      await settle(tester);

      expect(app.pending.entries, isEmpty);
      expect(text(en.readyPendingTitle), findsNothing);
      expect(find.textContaining('was booked', findRichText: true), findsOneWidget);
      expect(find.textContaining('24,90', findRichText: true), findsOneWidget);
      expect(app.services.recent.entries.single.amount, 2490);
      await tester.pump(const Duration(seconds: 6));
      await finishApp(tester, app);
    });

    testWidgets('pending and maintenance banners stack, pending first', (WidgetTester tester) async {
      final TestApp app = await _app(pending: <Map<String, Object?>>[_attempt()]);
      app.backend
        ..on('GET', '$redeemPath/k-1', FakeReply(200, Payloads.outcome()))
        ..only('GET', '/app/config', FakeReply(200, Payloads.config(notice: 'Wartung')));
      await pumpWaiterApp(tester, app, size: androidFrame);
      expect(find.byType(WaiterBanner), findsNWidgets(2));
      expect(
        tester.getRect(text(en.readyPendingTitle)).top,
        lessThan(tester.getRect(text('Wartung')).top),
      );
      await finishApp(tester, app);
    });
  });

  group('S05 · snackbars after the loop', () {
    testWidgets('Cancel in the uncertain state returns to S05 with "Not confirmed …"', (
      WidgetTester tester,
    ) async {
      final TestApp app = await openCharge(tester);
      app.backend.on('POST', redeemPath, FakeReply.transport());
      await typeDigits(tester, '2490');
      await tester.tap(find.textContaining('Redeem €', findRichText: true));
      await settle(tester);
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 2));
        await settle(tester);
      }
      expect((app.loop.state as ChargeState).phase, RedeemPhase.uncertainFinal);
      final String key = app.pending.entries.single.key;
      app.backend.on('GET', '$redeemPath/$key', FakeReply(200, Payloads.outcome()));

      await tester.tap(find.textContaining('Cancel', findRichText: true).last);
      await settle(tester);
      expect(find.byType(ReadyScreen), findsOneWidget);
      expect(text(en.uncertainCancelled), findsOneWidget);
      expect(text(en.readyPendingTitle), findsOneWidget, reason: 'the attempt stays open');
      await tester.pump(const Duration(seconds: 6));
      await finishApp(tester, app);
    });
  });

  group('S05 · layout, text size, theme, semantics', () {
    testWidgets('"Scan voucher" sits in the thumb zone', (WidgetTester tester) async {
      for (final Size frame in <Size>[iphoneFrame, compactFrame]) {
        final TestApp app = await _app();
        await pumpWaiterApp(tester, app, size: frame);
        final Rect button = tester.getRect(_primary(en.readyScan));
        expect(button.top, greaterThan(frame.height * 0.55));
        expect(button.height, frame.height < 700 ? 56 : 64);
        await finishApp(tester, app);
      }
    });

    for (final (String name, Size size) in <(String, Size)>[
      ('compact phone', compactFrame),
      ('Android phone', androidFrame),
      ('tablet landscape', tabletLandscape),
    ]) {
      testWidgets('$name at 200 % text lays out without overflow (manager, German)', (WidgetTester tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final TestApp app = await _app(manager: true);
        await pumpWaiterApp(tester, app, locale: const Locale('de'), size: size);
        expect(tester.takeException(), isNull);
        expect(_primary(de.readyScan), findsOneWidget);
        expect(_secondary(de.readySell), findsOneWidget);
        await finishApp(tester, app);
      });
    }

    testWidgets('tablet landscape: one centred column, max 480, buttons below the text', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _app(manager: true);
      await pumpWaiterApp(tester, app, size: tabletLandscape);
      final Rect scan = tester.getRect(_primary(en.readyScan));
      final Rect sell = tester.getRect(_secondary(en.readySell));
      final Rect hint = tester.getRect(text(en.readyHint));
      expect(scan.width, lessThanOrEqualTo(480));
      expect(scan.center.dx, closeTo(tabletLandscape.width / 2, 1));
      expect(sell.left, scan.left);
      expect(scan.top, greaterThan(hint.bottom));
      await finishApp(tester, app);
    });

    testWidgets('dark theme', (WidgetTester tester) async {
      final TestApp app = await _app(manager: true, prefs: const <String, Object>{'theme': 'dark'});
      await pumpWaiterApp(tester, app, size: androidFrame);
      final BuildContext context = tester.element(find.byType(ReadyScreen));
      expect(context.waiter.brightness, Brightness.dark);
      expect(text(en.readyTitle), findsOneWidget);
      expect(_secondary(en.readySell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });

    testWidgets('semantics: header + live-region title, labelled TopBar', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final TestApp app = await _app();
      await pumpWaiterApp(tester, app, size: androidFrame);
      expect(
        tester.getSemantics(text(en.readyTitle)),
        isSemantics(label: en.readyTitle, isHeader: true, isLiveRegion: true),
      );
      expect(tester.getSemantics(find.bySemanticsLabel('Recent')), isSemantics(isButton: true));
      expect(find.bySemanticsLabel('Trattoria Bella Vista'), findsOneWidget);
      await finishApp(tester, app);
      handle.dispose();
    });

    testWidgets('offline title is announced as a live region too', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final TestApp app = await _app();
      await pumpWaiterApp(tester, app, size: androidFrame);
      await _goOffline(tester, app);
      expect(
        tester.getSemantics(text(en.offlineTitle)),
        isSemantics(label: en.offlineTitle, isHeader: true, isLiveRegion: true),
      );
      await finishApp(tester, app);
      handle.dispose();
    });

    testWidgets('Reduce Motion: nothing animates on S05', (WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final TestApp app = await _app();
      await pumpWaiterApp(tester, app, size: androidFrame);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
      await finishApp(tester, app);
    });
  });
}
