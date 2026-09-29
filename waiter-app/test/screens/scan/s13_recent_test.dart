import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/storage/recent_store.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'scan_harness.dart';

RecentEntry _entry(
  String id,
  String at, {
  int amount = 2490,
  int balance = 860,
  String last4 = '6488',
}) => RecentEntry(
  transactionId: id,
  createdAt: DateTime.parse(at),
  last4: last4,
  amount: amount,
  balanceAfter: balance,
  currency: 'EUR',
  restaurantName: 'Trattoria Bella Vista',
  businessDay: '2026-09-26',
  requestId: '0f1e2d3c-4b5a-4c6d-8e7f-4b1e9c7f3a9c',
);

/// Adds [rows] (newest first) once the session has loaded Recent.
Future<void> _addRows(
  WidgetTester tester,
  TestApp app,
  List<RecentEntry> rows,
) async {
  for (final RecentEntry row in rows.reversed) {
    unawaited(app.services.recent.add(row));
  }
  await settle(tester);
}

Future<void> _openRecent(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Recent'));
  // The sheet rises with motion.spring.soft (≈ 0.55 s).
  await settle(tester, 20);
}

void main() {
  testWidgets('empty: EmptyState, no HistoryCard', (WidgetTester tester) async {
    final TestApp app = await TestApp.create();
    await pumpWaiterApp(tester, app);
    await _openRecent(tester);
    expect(text('Recent'), findsOneWidget);
    expect(text('No redemptions yet'), findsOneWidget);
    expect(
      text('Redemptions from this phone appear here until 04:00.'),
      findsOneWidget,
    );
    expect(find.byType(HistoryCard), findsNothing);
    await finishApp(tester, app);
  });

  testWidgets(
    'rows: summary, hour groups in the restaurant zone, newest first, footer',
    (WidgetTester tester) async {
      final TestApp app = await TestApp.create();
      await pumpWaiterApp(tester, app);
      await _addRows(tester, app, <RecentEntry>[
        _entry(
          'tx-3-aaaaaa',
          '2026-09-26T17:42:07Z',
          amount: 2490,
          balance: 860,
        ),
        _entry(
          'tx-2-bbbbbb',
          '2026-09-26T17:05:00Z',
          amount: 3250,
          balance: 0,
          last4: '1123',
        ),
        _entry(
          'tx-1-cccccc',
          '2026-09-26T16:51:00Z',
          amount: 12000,
          balance: 3000,
          last4: '9034',
        ),
      ]);
      await _openRecent(tester);

      expect(find.byType(HistoryCard), findsOneWidget);
      expect(
        find.textContaining('3 redemptions', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('177,40', findRichText: true), findsOneWidget);
      // Vienna is UTC+2 in September: 17:42Z → 19:42.
      expect(text('19:42'), findsOneWidget);
      expect(text('19:00'), findsOneWidget);
      expect(text('18:00'), findsOneWidget);
      expect(text('Voucher now empty'), findsOneWidget);
      expect(
        tester.getTopLeft(text('19:42')).dy,
        lessThan(tester.getTopLeft(text('19:05')).dy),
      );
      expect(
        tester.getTopLeft(text('19:05')).dy,
        lessThan(tester.getTopLeft(text('18:51')).dy),
      );
      await tester.scrollUntilVisible(
        text('This phone only · cleared at 04:00'),
        200,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      // The footer closes the list (03b §6.3).
      expect(text('This phone only · cleared at 04:00'), findsOneWidget);
      await finishApp(tester, app);
    },
  );

  testWidgets(
    'detail: facts, reversal hint exactly once, no actions; long-press copies the id',
    (WidgetTester tester) async {
      final List<MethodCall> clipboard = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          clipboard.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final TestApp app = await TestApp.create();
      await pumpWaiterApp(tester, app);
      await _addRows(tester, app, <RecentEntry>[
        _entry('9b2c-44e1-5e12c0', '2026-09-26T17:42:07Z'),
      ]);
      await _openRecent(tester);
      await tester.tap(text('••••\u00a06488'));
      await settle(tester, 20);

      expect(text('Redemption'), findsOneWidget);
      expect(text('Remaining balance'), findsOneWidget);
      expect(text('Transaction'), findsOneWidget);
      expect(text('5E12C0'), findsOneWidget);
      expect(text('Support code'), findsOneWidget);
      expect(text('7F3A9C'), findsOneWidget);
      expect(
        text('Wrong amount? A manager can reverse it in the dashboard.'),
        findsOneWidget,
      );
      // No actions in the sheet (S05's own button stays underneath).
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).label, 'Scan voucher');

      await tester.longPress(text('5E12C0'));
      await settle(tester);
      final MethodCall copy = clipboard.firstWhere(
        (MethodCall c) => c.method == 'Clipboard.setData',
      );
      expect(
        (copy.arguments as Map<Object?, Object?>)['text'],
        '9b2c-44e1-5e12c0',
      );
      expect(text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await finishApp(tester, app);
    },
  );

  testWidgets('a 04:00 clear while open fades into the empty state', (
    WidgetTester tester,
  ) async {
    final TestApp app = await TestApp.create();
    await pumpWaiterApp(tester, app);
    await _addRows(tester, app, <RecentEntry>[
      _entry('tx-1', '2026-09-26T17:42:07Z'),
    ]);
    await _openRecent(tester);
    expect(find.byType(HistoryCard), findsOneWidget);
    unawaited(app.services.recent.keepOnly('2026-09-27'));
    await settle(tester, 10);
    expect(text('No redemptions yet'), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets(
    'empty state at 200 % text on a compact phone scrolls instead of overflowing',
    (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final TestApp app = await TestApp.create();
      await pumpWaiterApp(tester, app, size: compactFrame);
      await _openRecent(tester);
      expect(tester.takeException(), isNull);
      expect(text('No redemptions yet'), findsOneWidget);
      await finishApp(tester, app);
    },
  );

  testWidgets(
    'German copy, dark theme, 200 % text and tablet width without overflow',
    (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final TestApp app = await TestApp.create(
        prefs: const <String, Object>{'theme': 'dark'},
      );
      await pumpWaiterApp(
        tester,
        app,
        locale: const Locale('de'),
        size: tabletLandscape,
      );
      await _addRows(tester, app, <RecentEntry>[
        _entry('tx-1', '2026-09-26T17:42:07Z'),
      ]);
      await tester.tap(find.bySemanticsLabel('Verlauf'));
      await settle(tester, 20);
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('1 Einlösung', findRichText: true),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(HistoryCard)).width,
        lessThanOrEqualTo(560),
      );
      await finishApp(tester, app);
    },
  );

  testWidgets(
    'row semantics speak the time, the voucher ending and both amounts',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final TestApp app = await TestApp.create();
      await pumpWaiterApp(tester, app);
      await _addRows(tester, app, <RecentEntry>[
        _entry('tx-1', '2026-09-26T17:42:07Z'),
      ]);
      await _openRecent(tester);
      expect(
        find.bySemanticsLabel(
          RegExp(r'^19:42, voucher ending 6 4 8 8, 24 euros 90 redeemed'),
        ),
        findsOneWidget,
      );
      await finishApp(tester, app);
      handle.dispose();
    },
  );
}
