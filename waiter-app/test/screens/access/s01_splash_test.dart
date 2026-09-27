import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/s01_splash.dart';
import 'package:giftcard_waiter/screens/s02_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'access_support.dart';

/// Holds the launch decision (the biometric capability query) until
/// [release] completes, so S01 stays visible.
Completer<bool> _holdLaunch(TestApp app) {
  final Completer<bool> release = Completer<bool>();
  when(app.localAuth.isDeviceSupported).thenAnswer((_) => release.future);
  return release;
}

Finder get _mark => find.byWidgetPredicate((Widget w) => w is WaiterIconView && w.icon == WaiterIcon.cardArcs);

void main() {
  testWidgets('shows only the 96-pt mark; the spinner and announcement come after 1 s', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final TestApp app = await TestApp.create(signedIn: false);
    final Completer<bool> release = _holdLaunch(app);
    await pumpWaiterApp(tester, app);

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(_mark, findsOneWidget);
    final WaiterIconView mark = tester.widget<WaiterIconView>(_mark);
    expect(mark.dimension, 96);
    expect(mark.strokeWidth, 5);
    expect(tester.getCenter(_mark), const Offset(393 / 2, 852 / 2));
    expect(find.byType(Spinner), findsNothing);
    expect(find.byType(Text), findsNothing);
    expect(find.bySemanticsLabel(en.splashLoading), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(Spinner), findsOneWidget);
    expect(tester.getCenter(find.byType(Spinner)).dy, 852 - 56);

    release.complete(true);
    await settle(tester);
    expect(app.session.phase, AccessPhase.signedOut);
    expect(find.byType(SignInScreen), findsOneWidget);
    semantics.dispose();
    await finishApp(tester, app);
  });

  testWidgets('a fast start never shows the spinner', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false);
    await pumpWaiterApp(tester, app);
    expect(find.byType(Spinner), findsNothing);
    expect(find.byType(SplashScreen), findsNothing);
    await finishApp(tester, app);
  });

  testWidgets('dark theme uses the dark canvas and mark colours', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false, prefs: const <String, Object>{'theme': 'dark'});
    final Completer<bool> release = _holdLaunch(app);
    await pumpWaiterApp(tester, app, size: const Size(375, 667));

    final ColoredBox canvas = tester.widget<ColoredBox>(
      find.descendant(of: find.byType(SplashScreen), matching: find.byType(ColoredBox)).first,
    );
    expect(canvas.color, const Color(0xFF0A0A0C));
    expect(tester.widget<WaiterIconView>(_mark).color, const Color(0xFFF4F4F5));
    release.complete(true);
    await settle(tester);
    await finishApp(tester, app);
  });

  testWidgets('the loading label is localised', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final TestApp app = await TestApp.create(signedIn: false);
    final Completer<bool> release = _holdLaunch(app);
    await pumpWaiterApp(tester, app, locale: const Locale('de'));
    expect(find.bySemanticsLabel(lookupAppLocalizations(const Locale('de')).splashLoading), findsOneWidget);
    release.complete(true);
    await settle(tester);
    semantics.dispose();
    await finishApp(tester, app);
  });
}
