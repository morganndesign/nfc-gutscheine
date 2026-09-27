import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/app_harness.dart';

/// English strings, for finding texts on screen.
final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

/// Finds rendered text, including the RichText of `ScaledText`.
Finder text(String value) => find.text(value, findRichText: true);

/// Registers mocktail fallbacks for [LocalAuthentication.authenticate].
void registerAuthFallbacks() {
  registerFallbackValue(const <AuthMessages>[]);
}

/// Scripts the OS biometric prompt: every call answers with [answer].
void stubPrompt(TestApp app, Future<bool> Function() answer) {
  when(
    () => app.localAuth.authenticate(
      localizedReason: any(named: 'localizedReason'),
      authMessages: any(named: 'authMessages'),
      persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
    ),
  ).thenAnswer((_) => answer());
}

/// Records every URL opened through url_launcher (and its launch mode).
List<Map<Object?, Object?>> recordLaunches() {
  final List<Map<Object?, Object?>> launches = <Map<Object?, Object?>>[];
  const MethodChannel channel = MethodChannel('plugins.flutter.io/url_launcher');
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
    if (call.method == 'launch') {
      launches.add(call.arguments as Map<Object?, Object?>);
    }
    return true;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return launches;
}

/// `GET /auth/me` answer for the signed-in waiter.
FakeReply meReply() => FakeReply(200, <String, Object?>{'data': Payloads.user()});
