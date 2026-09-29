import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/s17_intro.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'access_support.dart';

/// First sign-in on this install without biometrics to offer → S17.
Future<TestApp> _openIntro(
  WidgetTester tester, {
  bool isIos = false,
  Locale locale = const Locale('en'),
  Size size = const Size(393, 852),
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  final TestApp app = await TestApp.create(signedIn: false, introDone: false, isIos: isIos, prefs: prefs);
  app.backend
    ..on('POST', '/auth/token', FakeReply(201, Payloads.token()))
    ..on('GET', '/auth/me', meReply());
  await pumpWaiterApp(tester, app, locale: locale, size: size);
  await tester.enterText(find.byType(TextField).at(0), 'anna@example.at');
  await tester.enterText(find.byType(TextField).at(1), 'secret');
  await tester.pump();
  await tester.tap(find.byType(PrimaryButton));
  await settle(tester);
  expect(find.byType(IntroScreen), findsOneWidget);
  return app;
}

Finder get _button => find.byType(PrimaryButton);

/// Card 1's `scan-qr-code` icon (no illustration).
Finder get _qrIcon => find.byWidgetPredicate((Widget w) => w is WaiterIconView && w.icon == WaiterIcon.scanQrCode);

/// The square slot card 1's icon sits in (160 pt, 120 pt compact).
Finder get _slot => find.ancestor(of: _qrIcon, matching: find.byType(SizedBox)).first;

String _label(WidgetTester tester) => tester.widget<PrimaryButton>(_button).label;

int _haptics(TestApp app) => app.feedbackCalls.where((MethodCall c) => c.method == 'haptic').length;

Future<void> _next(WidgetTester tester) async {
  await tester.tap(_button);
  await settle(tester, 10);
}

void main() {
  testWidgets('three cards, Next → Next → Start', (WidgetTester tester) async {
    final TestApp app = await _openIntro(tester);

    // The "shown" flag is written as soon as card 1 renders.
    expect(app.services.settings.introDone, isTrue);
    expect(app.session.phase, AccessPhase.onboardingIntro);
    expect(text(en.intro1Title), findsOneWidget);
    expect(text(en.intro1Body), findsOneWidget);
    expect(text(en.introSkip), findsOneWidget);
    expect(_label(tester), en.introNext);
    expect(find.byType(IllustrationView), findsNothing, reason: 'card 1 has the scan-QR icon, no illustration');
    expect(_qrIcon, findsOneWidget);
    expect(tester.widget<WaiterIconView>(_qrIcon).dimension, IconSize.s48.size);
    expect(tester.getSize(_slot), const Size(160, 160));

    final int haptics = _haptics(app);
    await _next(tester);
    expect(text(en.intro2Title), findsOneWidget);
    expect(find.textContaining('100,00', findRichText: true), findsOneWidget);
    expect(tester.widget<IllustrationView>(find.byType(IllustrationView)).illustration, WaiterIllustration.introAmount);
    expect(tester.getSize(find.byType(IllustrationView)), const Size(160, 160));
    expect(_haptics(app), haptics + 1);

    await _next(tester);
    expect(text(en.intro3Title), findsOneWidget);
    expect(_label(tester), en.introStart);

    await _next(tester);
    expect(app.session.phase, AccessPhase.active);
    expect(app.services.settings.introDone, isTrue);
    await finishApp(tester, app);
  });

  testWidgets('Skip exits from any card in one tap', (WidgetTester tester) async {
    final TestApp app = await _openIntro(tester);
    await _next(tester);
    await tester.tap(text(en.introSkip));
    await settle(tester);
    expect(app.session.phase, AccessPhase.active);
    expect(app.services.settings.introDone, isTrue);
    await finishApp(tester, app);
  });

  testWidgets('swiping pages; swiping past the last card starts', (WidgetTester tester) async {
    final TestApp app = await _openIntro(tester);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await settle(tester, 20);
    expect(text(en.intro2Title), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await settle(tester, 20);
    expect(_label(tester), en.introStart);

    await tester.drag(find.byType(PageView), const Offset(-200, 0));
    await settle(tester, 20);
    expect(app.session.phase, AccessPhase.active);
    await finishApp(tester, app);
  });

  testWidgets('Android back: previous card, on card 1 it acts as Skip', (WidgetTester tester) async {
    final TestApp app = await _openIntro(tester);
    await _next(tester);
    expect(text(en.intro2Title), findsOneWidget);

    unawaited(tester.binding.handlePopRoute());
    await settle(tester, 10);
    expect(text(en.intro1Title), findsOneWidget);
    expect(app.session.phase, AccessPhase.onboardingIntro);

    unawaited(tester.binding.handlePopRoute());
    await settle(tester);
    expect(app.session.phase, AccessPhase.active);
    await finishApp(tester, app);
  });

  testWidgets('iPhone: the same card 1 with the scan-QR icon', (WidgetTester tester) async {
    final TestApp app = await _openIntro(tester, isIos: true);
    expect(text(en.intro1Title), findsOneWidget);
    expect(text(en.intro1Body), findsOneWidget);
    expect(_qrIcon, findsOneWidget);
    expect(find.byType(IllustrationView), findsNothing);
    expect(find.textContaining('NFC', findRichText: true), findsNothing);
    await finishApp(tester, app);
  });

  testWidgets('each card is one group "Page n of 3. Title. Body."', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final TestApp app = await _openIntro(tester);
    expect(
      find.bySemanticsLabel('${en.introPage(1)}. ${en.intro1Title}. ${en.intro1Body}'),
      findsOneWidget,
    );
    await _next(tester);
    expect(find.bySemanticsLabel(RegExp('^${RegExp.escape(en.introPage(2))}')), findsOneWidget);
    semantics.dispose();
    await finishApp(tester, app);
  });

  testWidgets('iPhone SE: 120-pt art, everything fits, button in the thumb zone', (WidgetTester tester) async {
    final TestApp app = await _openIntro(tester, size: const Size(375, 667));
    expect(tester.getSize(_slot), const Size(120, 120));
    expect(tester.getSize(_button).height, 56);
    // Bottom padding 20 without a home indicator (04 §4.4).
    expect(tester.getTopLeft(_button).dy, 667 - 20 - 56);
    final ScrollableState card = tester.state<ScrollableState>(
      find.descendant(of: find.byType(PageView), matching: find.byType(Scrollable)).at(1),
    );
    expect(card.position.maxScrollExtent, 0);
    for (int i = 0; i < 2; i++) {
      await _next(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(IllustrationView)), const Size(120, 120));
    }
    await finishApp(tester, app);
  });

  testWidgets('150 % text uses the 120-pt art; 200 % on compact hides it', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final TestApp app = await _openIntro(tester);
    expect(tester.getSize(_slot), const Size(120, 120));
    await _next(tester);
    expect(tester.getSize(find.byType(IllustrationView)), const Size(120, 120));
    await finishApp(tester, app);

    tester.platformDispatcher.textScaleFactorTestValue = 2;
    final TestApp compact = await _openIntro(tester, size: const Size(375, 667));
    expect(_qrIcon, findsNothing);
    expect(tester.takeException(), isNull);
    await _next(tester);
    expect(find.byType(IllustrationView), findsNothing);
    expect(tester.takeException(), isNull);
    await _next(tester);
    expect(tester.takeException(), isNull);
    await finishApp(tester, compact);
  });

  testWidgets('Reduce Motion: paging cross-fades without a PageView', (WidgetTester tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final TestApp app = await _openIntro(tester);
    expect(find.byType(PageView), findsNothing);
    await _next(tester);
    expect(text(en.intro2Title), findsOneWidget);
    await tester.fling(find.byType(IntroScreen), const Offset(300, 0), 1000);
    await settle(tester);
    expect(text(en.intro1Title), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets('tablet landscape: icon / illustration left, text right', (WidgetTester tester) async {
    final TestApp app = await _openIntro(tester, size: const Size(1180, 820));
    final Rect art = tester.getRect(_slot);
    final Rect title = tester.getRect(text(en.intro1Title));
    expect(art.size, const Size(160, 160));
    expect(art.right, lessThan(title.left));
    expect(tester.getRect(_button).left, greaterThanOrEqualTo(art.right));
    await _next(tester);
    final Rect illustration = tester.getRect(find.byType(IllustrationView));
    expect(illustration.size, const Size(160, 160));
    expect(illustration.right, lessThan(tester.getRect(text(en.intro2Title)).left));
    expect(tester.takeException(), isNull);
    await finishApp(tester, app);
  });

  for (final Locale locale in const <Locale>[Locale('de'), Locale('bs')]) {
    testWidgets('renders in ${locale.languageCode} (dark)', (WidgetTester tester) async {
      final AppLocalizations l = lookupAppLocalizations(locale);
      final TestApp app = await _openIntro(tester, locale: locale, prefs: const <String, Object>{'theme': 'dark'});
      expect(text(l.intro1Title), findsOneWidget);
      expect(text(l.introSkip), findsOneWidget);
      expect(_label(tester), l.introNext);
      await _next(tester);
      expect(find.textContaining('100,00', findRichText: true), findsOneWidget);
      await finishApp(tester, app);
    });
  }
}
