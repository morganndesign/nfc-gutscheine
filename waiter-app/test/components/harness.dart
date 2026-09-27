import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/money_context.dart';
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/platform/channels.dart';
import 'package:giftcard_waiter/core/platform/feedback_scope.dart';
import 'package:giftcard_waiter/core/platform/feedback_service.dart';
import 'package:giftcard_waiter/core/storage/settings_store.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

/// Formatting context used by the component tests (de-AT, English UI).
const MoneyContext testMoney = MoneyContext(
  currency: 'EUR',
  language: UiLanguage.en,
  restaurantLocale: RestaurantLocale.deAT,
);

/// Loads the bundled Geist families so text metrics match the device.
Future<void> loadWaiterFonts() async {
  final FontLoader geist = FontLoader('Geist');
  for (final String w in <String>['Regular', 'Medium', 'SemiBold', 'Bold']) {
    geist.addFont(rootBundle.load('assets/fonts/Geist-$w.ttf'));
  }
  final FontLoader mono = FontLoader('GeistMono')
    ..addFont(rootBundle.load('assets/fonts/GeistMono-Medium.ttf'));
  await Future.wait(<Future<void>>[geist.load(), mono.load()]);
}

class _Settings extends Mock implements SettingsStore {}

/// Records every call on the feedback channel (haptics and sounds).
class FeedbackRecorder {
  /// Installs the mock handler; call [dispose] in `tearDown`.
  FeedbackRecorder() {
    final _Settings settings = _Settings();
    when(() => settings.haptics).thenReturn(true);
    when(() => settings.sound).thenReturn(true);
    int tick = 0;
    service = FeedbackService(
      settings: settings,
      // Every call one second apart: the coalescing rules (11 T5/T6) are
      // tested with the service, not here.
      monotonicNow: () => Duration(seconds: ++tick),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WaiterChannels.feedback, (MethodCall call) {
          calls.add(call);
          return Future<Object?>.value();
        });
  }

  /// The service handed to [FeedbackScope].
  late final FeedbackService service;

  /// Recorded calls.
  final List<MethodCall> calls = <MethodCall>[];

  /// Android constants of the recorded haptics, e.g. `KEYBOARD_TAP`,
  /// or `waveform` for waveform-only tokens.
  List<String> get haptics => <String>[
    for (final MethodCall c in calls)
      if (c.method == 'haptic') _describe(c.arguments as Map<Object?, Object?>),
  ];

  static String _describe(Map<Object?, Object?> args) {
    final Map<Object?, Object?> api30 = args['api30']! as Map<Object?, Object?>;
    return (api30['constant'] as String?) ?? 'waveform';
  }

  /// Removes the mock handler.
  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WaiterChannels.feedback, null);
  }
}

/// Pumps [child] inside the app's theme and localisations.
Future<void> pumpComponent(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  bool highContrast = false,
  double textScale = 1,
  bool reduceMotion = false,
  bool accessibleNavigation = false,
  Size size = const Size(390, 844),
  TargetPlatform platform = TargetPlatform.android,
  FeedbackService? feedback,
  Locale locale = const Locale('en'),
  bool center = true,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final ThemeData theme = waiterThemeData(
    brightness,
    highContrast: highContrast,
  ).copyWith(platform: platform);
  Widget body = child;
  if (feedback != null) body = FeedbackScope(service: feedback, child: body);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
          highContrast: highContrast,
          accessibleNavigation: accessibleNavigation,
        ),
        child: app!,
      ),
      home: Material(
        type: MaterialType.canvas,
        color: theme.scaffoldBackgroundColor,
        child: center
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LayoutTokens.marginCompact,
                  ),
                  child: body,
                ),
              )
            : body,
      ),
    ),
  );
}

/// The two themes every component is rendered in.
const List<Brightness> bothThemes = <Brightness>[
  Brightness.light,
  Brightness.dark,
];
