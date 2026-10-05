import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

import 'harness.dart';

/// A host with a SnackbarHost above a button that runs [onTap].
class _Host extends StatelessWidget {
  const _Host({required this.onTap, this.paused = false});

  final void Function(BuildContext context) onTap;
  final bool paused;

  @override
  Widget build(BuildContext context) => SnackbarHost(
    paused: paused,
    child: Builder(
      builder: (BuildContext context) => Center(
        child: SecondaryButton(
          label: 'Open',
          fullWidth: false,
          onPressed: () => onTap(context),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadWaiterFonts);

  group('Snackbar', () {
    for (final Brightness b in bothThemes) {
      testWidgets('shows, then auto-dismisses after 4 s ($b)', (
        WidgetTester tester,
      ) async {
        await pumpComponent(
          tester,
          _Host(
            onTap: (BuildContext c) =>
                SnackbarHost.of(c).show(const SnackbarData(message: 'Copied')),
          ),
          brightness: b,
          center: false,
        );
        await tester.tap(find.text('Open', findRichText: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));
        expect(find.text('Copied', findRichText: true), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 3700));
        expect(find.text('Copied', findRichText: true), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Copied', findRichText: true), findsNothing);
      });
    }

    testWidgets('one action; activating it dismisses; 56-pt target', (
      WidgetTester tester,
    ) async {
      int switched = 0;
      await pumpComponent(
        tester,
        _Host(
          onTap: (BuildContext c) => SnackbarHost.of(c).show(
            SnackbarData(
              message: 'Different card detected – Switch?',
              actionLabel: 'Switch',
              onAction: () => switched++,
            ),
          ),
        ),
        center: false,
      );
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pump(const Duration(milliseconds: 300));
      final Finder action = find.ancestor(
        of: find.text('Switch', findRichText: true),
        matching: find.byType(ConstrainedBox),
      );
      expect(
        tester.getSize(action.first).height,
        greaterThanOrEqualTo(Sizes.targetMin),
      );
      await tester.tap(find.text('Switch', findRichText: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(switched, 1);
      expect(
        find.text('Different card detected – Switch?', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('timer pauses while paused and with a screen reader', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        _Host(
          paused: true,
          onTap: (BuildContext c) =>
              SnackbarHost.of(c).show(const SnackbarData(message: 'Copied')),
        ),
        center: false,
      );
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Copied', findRichText: true), findsOneWidget);

      await pumpComponent(tester, const SizedBox());
      await pumpComponent(
        tester,
        _Host(
          onTap: (BuildContext c) =>
              SnackbarHost.of(c).show(const SnackbarData(message: 'Copied')),
        ),
        accessibleNavigation: true,
        center: false,
      );
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Copied', findRichText: true), findsOneWidget);
    });

    testWidgets('a new snackbar replaces the current one', (
      WidgetTester tester,
    ) async {
      int n = 0;
      await pumpComponent(
        tester,
        _Host(
          onTap: (BuildContext c) =>
              SnackbarHost.of(c).show(SnackbarData(message: 'Message ${++n}')),
        ),
        center: false,
      );
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Message 1', findRichText: true), findsNothing);
      expect(find.text('Message 2', findRichText: true), findsOneWidget);
    });
  });

  group('Dialog', () {
    for (final Brightness b in bothThemes) {
      testWidgets('sign-out: danger on top, safe below; confirm ($b)', (
        WidgetTester tester,
      ) async {
        DialogChoice? choice;
        await pumpComponent(
          tester,
          _Host(
            onTap: (BuildContext c) async {
              choice = await showWaiterDialog(
                context: c,
                title: 'Sign out?',
                body: 'The shift history on this device will be deleted.',
                confirmLabel: 'Sign out',
                cancelLabel: 'Cancel',
                destructive: true,
              );
            },
          ),
          brightness: b,
          center: false,
        );
        await tester.tap(find.text('Open', findRichText: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(DangerButton), findsOneWidget);
        final double danger = tester.getCenter(find.byType(DangerButton)).dy;
        final double safe = tester
            .getCenter(
              find.ancestor(
                of: find.text('Cancel', findRichText: true),
                matching: find.byType(SecondaryButton),
              ),
            )
            .dy;
        expect(danger, lessThan(safe), reason: 'safe action nearer the thumb');
        await tester.tap(find.byType(DangerButton));
        await tester.pump(const Duration(milliseconds: 300));
        expect(choice, DialogChoice.confirm);
      });
    }

    testWidgets('scrim tap = the safe action', (WidgetTester tester) async {
      DialogChoice? choice;
      await pumpComponent(
        tester,
        _Host(
          onTap: (BuildContext c) async {
            choice = await showWaiterDialog(
              context: c,
              title: 'Different card detected',
              body: 'Switch to card •••• 1234?',
              confirmLabel: 'Switch',
              cancelLabel: 'Keep',
            );
          },
        ),
        center: false,
      );
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PrimaryButton), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 300));
      expect(choice, DialogChoice.cancel);
    });

    testWidgets('opening a dialog dismisses the snackbar', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        _Host(
          onTap: (BuildContext c) {
            SnackbarHost.of(c).show(const SnackbarData(message: 'Copied'));
            unawaited(
              showWaiterDialog(
                context: c,
                title: 'Sign out?',
                body: 'Body',
                confirmLabel: 'Sign out',
                cancelLabel: 'Cancel',
                destructive: true,
              ),
            );
          },
        ),
        center: false,
      );
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Copied', findRichText: true), findsNothing);
    });
  });

  group('BottomSheet', () {
    for (final Brightness b in bothThemes) {
      testWidgets('content-fit sheet: grabber, header, ✕ closes ($b)', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpComponent(
          tester,
          _Host(
            onTap: (BuildContext c) => showWaiterSheet<void>(
              context: c,
              title: 'Menu',
              builder: (BuildContext _) => const SizedBox(height: 200),
            ),
          ),
          brightness: b,
          center: false,
        );
        await tester.tap(find.text('Open', findRichText: true));
        await tester.pumpAndSettle();
        expect(find.byType(WaiterBottomSheet), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel('Menu').last),
          isSemantics(isHeader: true),
        );
        final Finder close = find.byType(WaiterIconButton);
        expect(tester.getSize(close), const Size(56, 56));
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(find.byType(WaiterBottomSheet), findsNothing);
        handle.dispose();
      });
    }

    testWidgets('a sheet rises above the keyboard (T10)', (WidgetTester tester) async {
      await pumpComponent(
        tester,
        _Host(
          onTap: (BuildContext c) => showWaiterSheet<void>(
            context: c,
            title: 'Server',
            builder: (BuildContext _) => const SizedBox(height: 200),
          ),
        ),
        center: false,
      );
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pumpAndSettle();
      final double screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      tester.view.viewInsets = FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(WaiterBottomSheet)).bottom, lessThanOrEqualTo(screen - 300 + 0.5));
    });

    testWidgets('drag down dismisses; a locked sheet stays', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        _Host(
          onTap: (BuildContext c) => showWaiterSheet<void>(
            context: c,
            title: 'Menu',
            builder: (BuildContext _) => const SizedBox(height: 200),
          ),
        ),
        center: false,
      );
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(WaiterBottomSheet),
        const Offset(0, 300),
        1500,
      );
      await tester.pumpAndSettle();
      expect(find.byType(WaiterBottomSheet), findsNothing);

      await pumpComponent(tester, const SizedBox());
      await pumpComponent(
        tester,
        _Host(
          onTap: (BuildContext c) => showWaiterSheet<void>(
            context: c,
            title: 'Session expired',
            dismissible: false,
            builder: (BuildContext _) => const SizedBox(height: 200),
          ),
        ),
        center: false,
      );
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(WaiterBottomSheet),
        const Offset(0, 300),
        1500,
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(WaiterBottomSheet), findsOneWidget);
      expect(find.byType(WaiterIconButton), findsNothing);
    });

    testWidgets('scroll sheet opens at the medium detent', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        _Host(
          onTap: (BuildContext c) => showWaiterScrollSheet<void>(
            context: c,
            title: 'Recent',
            builder: (BuildContext _, ScrollController controller) =>
                ListView.builder(
                  controller: controller,
                  itemCount: 50,
                  itemBuilder: (BuildContext _, int i) =>
                      SizedBox(height: 64, child: Text('Row $i')),
                ),
          ),
        ),
        center: false,
      );
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pumpAndSettle();
      final double top = tester.getTopLeft(find.byType(WaiterBottomSheet)).dy;
      expect(top, closeTo(844 / 2, 1));
    });
  });

  group('WaiterBanner', () {
    for (final Brightness b in bothThemes) {
      testWidgets('offline banner: full width, ≥ 48 pt ($b)', (
        WidgetTester tester,
      ) async {
        await pumpComponent(
          tester,
          const WaiterBanner(
            tone: BannerTone.info,
            icon: WaiterIcon.wifiOff,
            title: 'No connection',
            body:
                'Redeeming needs a connection so nothing is ever booked twice.',
          ),
          brightness: b,
          center: false,
        );
        await tester.pump(const Duration(milliseconds: 300));
        final Size size = tester.getSize(find.byType(WaiterBanner));
        expect(size.width, 390);
        expect(size.height, greaterThanOrEqualTo(48));
      });
    }

    testWidgets('with an action it is ≥ 56 pt', (WidgetTester tester) async {
      await pumpComponent(
        tester,
        WaiterBanner(
          tone: BannerTone.warning,
          icon: WaiterIcon.wrench,
          title: 'Scheduled maintenance',
          actionLabel: 'Details',
          onAction: () {},
        ),
        center: false,
        reduceMotion: true,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getSize(find.byType(WaiterBanner)).height,
        greaterThanOrEqualTo(56),
      );
    });
  });
}
