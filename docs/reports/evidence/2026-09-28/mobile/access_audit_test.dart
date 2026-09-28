// AUDIT reproductions (not part of the product test suite).
// M1 (UI), M3, M4, M5, M9, M11.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/api/card_link.dart';
import 'package:giftcard_waiter/core/config/environment.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';
import 'package:giftcard_waiter/screens/s15_session.dart';

import '../screens/access/access_support.dart';
import '../screens/charge/charge_harness.dart';
import '../support/app_harness.dart';
import '../support/screen_harness.dart';

void main() {
  // ---------------------------------------------------------------- M1 UI
  testWidgets('M1-UI: retry after 8 s answered CARD_NOT_REDEEMABLE shows "Nothing was booked."', (WidgetTester tester) async {
    final TestApp app = await openCharge(tester);
    app.backend
      ..on('POST', redeemPath, FakeReply.hang(const Duration(seconds: 30)))
      ..on('POST', redeemPath, FakeReply(422, Payloads.error('CARD_NOT_REDEEMABLE', <String, Object?>{'status': 'redeemed'})));
    await typeDigits(tester, '5000');
    unawaited(app.loop.redeem());
    await settle(tester);
    await tester.pump(const Duration(seconds: 8));
    await settle(tester, 3);
    final bool shown = find.text(en.redeemNothingBooked, findRichText: true).evaluate().isNotEmpty;
    // ignore: avoid_print
    print('AUDIT M1-UI text "${en.redeemNothingBooked}" visible=$shown state=${(app.loop.state as ChargeState).phase}');
    expect(text(en.redeemNothingBooked), findsWidgets);
    await finishApp(tester, app);
  });

  // ---------------------------------------------------------------- M3
  for (final int ms in <int>[1900, 3000]) {
    testWidgets('M3: signed out, /app/config answers after $ms ms', (WidgetTester tester) async {
      final TestApp app = await TestApp.create(signedIn: false);
      app.backend.only('GET', '/app/config', FakeReply(200, Payloads.config(), Duration(milliseconds: ms)));
      unawaited(app.session.start());
      await tester.pump(Duration(milliseconds: ms + 100));
      await tester.pump(const Duration(milliseconds: 10));
      final AccessPhase first = app.session.phase;
      // ignore: avoid_print
      print('AUDIT M3[$ms ms] phase=$first problem=${app.session.startupProblem?.kind}');
      if (ms > 2000) {
        expect(first, AccessPhase.startupProblem);
        // "Try again" — same 2 s budget, same result.
        unawaited(app.session.retryStart());
        await tester.pump(Duration(milliseconds: ms + 100));
        await tester.pump(const Duration(milliseconds: 10));
        // ignore: avoid_print
        print('AUDIT M3[$ms ms] after Try again: phase=${app.session.phase} '
            'configRequests=${app.backend.to('GET', '/app/config').length}');
        expect(app.session.phase, AccessPhase.startupProblem);
      } else {
        expect(first, AccessPhase.signedOut);
      }
      app.dispose();
      await tester.pump(const Duration(seconds: 5));
    });
  }

  // ---------------------------------------------------------------- M4
  testWidgets('M4: iOS production build (config/production.json) — "Update now" opens nothing', (WidgetTester tester) async {
    final Map<String, String> prod = (jsonDecode(File('config/production.json').readAsStringSync()) as Map<String, Object?>)
        .map((String k, Object? v) => MapEntry<String, String>(k, '$v'));
    final AppEnvironment env = AppEnvironment.resolve(prod);
    // ignore: avoid_print
    print('AUDIT M4 production.json APP_STORE_URL="${prod['APP_STORE_URL']}" → appStoreUrl=${env.appStoreUrl}');
    expect(env.appStoreUrl, isNull);

    final List<Map<Object?, Object?>> launches = recordLaunches();
    final TestApp app = await TestApp.create(signedIn: false, isIos: true, environment: env);
    app.backend.only('GET', '/app/config', FakeReply(200, Payloads.config(updateRequired: true)));
    await pumpWaiterApp(tester, app);
    expect(app.session.phase, AccessPhase.updateRequired);
    await tester.tap(text(en.updateAction));
    await settle(tester);
    await tester.tap(text(en.updateAction));
    await settle(tester);
    final List<String> log = app.services.log.entries.map((e) => e.event).where((String e) => e.startsWith('update.')).toList();
    // ignore: avoid_print
    print('AUDIT M4 launches=${launches.length} log=$log screen=${find.byType(UpdateRequiredScreen).evaluate().length}');
    expect(launches, isEmpty);
    expect(log, <String>['update.noStoreUrl', 'update.noStoreUrl']);
    await finishApp(tester, app);
  });

  // ---------------------------------------------------------------- M5
  test('M5: no global error handler and no crash reporter in lib/ or pubspec', () {
    final List<String> hits = <String>[];
    for (final FileSystemEntity f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final String src = f.readAsStringSync();
      for (final String needle in <String>['FlutterError.onError', 'PlatformDispatcher.instance.onError', '.onError =', 'runZonedGuarded', 'Isolate.current.addErrorListener']) {
        if (src.contains(needle)) hits.add('${f.path}: $needle');
      }
    }
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final List<String> reporters = <String>['sentry', 'firebase_crashlytics', 'bugsnag', 'datadog', 'instabug', 'rollbar']
        .where(pubspec.contains)
        .toList();
    // ignore: avoid_print
    print('AUDIT M5 handler hits=$hits reporters=$reporters');
    expect(hits, isEmpty);
    expect(reporters, isEmpty);
  });

  testWidgets('M5b: an uncaught async error in the loop never reaches the DiagnosticLog', (WidgetTester tester) async {
    final List<Object> errors = <Object>[];
    late TestApp app;
    await runZonedGuarded(() async {
      app = await TestApp.create();
      unawaited(app.session.start());
    }, (Object e, StackTrace s) => errors.add(e));
    await settle(tester);
    app.backend.on('POST', '/scan', FakeReply(200, Payloads.scan(balance: 10000000, partial: false)));
    await readCard(tester, app);
    final List<String> logged = app.services.log.entries.map((e) => e.toString()).where((String e) => e.contains('RangeError')).toList();
    // ignore: avoid_print
    print('AUDIT M5b zone errors=${errors.map((Object e) => e.runtimeType).toList()} log mentions RangeError=${logged.length}');
    expect(errors, isNotEmpty);
    expect(logged, isEmpty);
    app.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  // ---------------------------------------------------------------- M9
  testWidgets('M9: after "Not now" biometrics are never offered again (not even after sign-out)', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false, biometricsOffered: false);
    app.backend
      ..on('POST', '/auth/token', FakeReply(201, Payloads.token()))
      ..on('POST', '/auth/logout', FakeReply(204, const <String, Object?>{}))
      ..on('GET', '/auth/me', FakeReply(200, <String, Object?>{'data': Payloads.user()}));
    unawaited(app.session.start());
    await settle(tester);
    expect(app.session.phase, AccessPhase.signedOut);
    unawaited(app.session.signIn('anna@example.at', 'Password123!'));
    await settle(tester);
    final AccessPhase firstOffer = app.session.phase;
    app.session.skipBiometrics();
    unawaited(app.session.signOut());
    await settle(tester);
    expect(app.session.phase, AccessPhase.signedOut);
    unawaited(app.session.signIn('anna@example.at', 'Password123!'));
    await settle(tester);
    final AccessPhase second = app.session.phase;
    final File menu = File('lib/screens/s14_menu.dart');
    final bool menuToggle = menu.readAsStringSync().toLowerCase().contains('biometr');
    // ignore: avoid_print
    print('AUDIT M9 first sign-in → $firstOffer; after Not now + sign-out + sign-in → $second; '
        'biometricsEnabled=${app.session.biometricsEnabled}; S14 menu mentions biometrics=$menuToggle');
    expect(firstOffer, AccessPhase.onboardingBiometrics);
    expect(second, isNot(AccessPhase.onboardingBiometrics));
    expect(menuToggle, isFalse);
    app.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  // ---------------------------------------------------------------- M11
  group('M11: CardLink.parse (release semantics: allowHttp=false)', () {
    const List<String> hosts = <String>['app.giftcardpro.at'];
    const String uuid = 'b8c1d2e3-f4a5-4b6c-8d7e-9f0a1b2c3d4e';
    final Map<String, bool> cases = <String, bool>{
      'https://app.giftcardpro.at/c/$uuid': true,
      'https://APP.GIFTCARDPRO.AT/c/$uuid': true,
      'https://app.giftcardpro.at/c/$uuid?picc=AA&cmac=BB': true,
      'http://app.giftcardpro.at/c/$uuid': false,
      'https://evil.example/c/$uuid': false,
      'https://app.giftcardpro.at.evil.example/c/$uuid': false,
      'https://evil.example@app.giftcardpro.at/c/$uuid': true, // userinfo, but host IS ours
      'https://app.giftcardpro.at@evil.example/c/$uuid': false,
      'https://app.giftcardpro.at%40evil.example/c/$uuid': false,
      'https://evil.example\\@app.giftcardpro.at/c/$uuid': false,
      'https://evil.example#@app.giftcardpro.at/c/$uuid': false,
      'https://app.giftcardpro.at:8443/c/$uuid': true, // non-default port accepted
      'https://app.giftcardpro.at./c/$uuid': false,
      'https://app.giftcardpro.at/x/c/$uuid': false,
      'https://app.giftcardpro.at/c/$uuid/extra': false,
      'https://app.giftcardpro.at/C/$uuid': false,
      'https://app.giftcardpro.at//c//$uuid': true, // empty segments dropped
      'https://app.giftcardpro.at/c/../c/$uuid': true, // dot-segments normalised to the canonical URL
      'https://app.giftcardpro.at/c/not-a-uuid': false,
      'https://app.giftcardpro.at/c/%62$uuid': false,
      'javascript://app.giftcardpro.at/c/$uuid': false,
      '  https://app.giftcardpro.at/c/$uuid  ': true,
      'https://app.giftcardpro.at/c/$uuid#frag': true,
    };
    for (final MapEntry<String, bool> c in cases.entries) {
      test(c.key, () {
        final CardLink? link = CardLink.parse(c.key, hosts, allowHttp: false);
        // ignore: avoid_print
        print('AUDIT M11 ${link == null ? 'REJECT' : 'ACCEPT'} ${jsonEncode(c.key)}${link == null ? '' : ' → sent as ${link.url}'}');
        expect(link != null, c.value);
      });
    }
  });
}
