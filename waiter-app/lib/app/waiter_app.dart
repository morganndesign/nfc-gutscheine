import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../components/components.dart';
import '../core/l10n/l10n.dart';
import '../core/platform/feedback_scope.dart';
import '../core/state/session_state.dart';
import '../core/storage/settings_store.dart';
import '../core/theme/theme.dart';
import '../screens/s01_startup_problem.dart';
import 'app_navigator.dart';
import 'app_scope.dart';
import 'session_sheet_host.dart';

/// Root widget: theme, localisation, feedback and snackbar hosts, and the
/// platform coordination that follows the app state — keep-screen-on and
/// lifecycle (09 §7).
class WaiterApp extends StatefulWidget {
  const WaiterApp({required this.services, super.key});

  final AppServices services;

  @override
  State<WaiterApp> createState() => _WaiterAppState();
}

class _WaiterAppState extends State<WaiterApp> with WidgetsBindingObserver {
  AppServices get _s => widget.services;

  late final WaiterRouterDelegate _router = WaiterRouterDelegate(_s);
  bool _resumed = true;
  bool? _awake;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final Listenable state = Listenable.merge(<Listenable>[_s.session, _s.loop, _s.settings]);
    state.addListener(_coordinate);
    unawaited(_s.session.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _resumed = true;
        unawaited(_s.session.onForeground());
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        if (_resumed) _s.session.onBackground();
        _resumed = false;
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
    _coordinate();
  }

  /// Keep-awake (09 §7.7) follows the state.
  void _coordinate() {
    final bool awake =
        _resumed && _s.settings.keepScreenOn && _s.session.phase == AccessPhase.active && _s.loop.wantsKeepAwake;
    if (awake != _awake) {
      _awake = awake;
      unawaited(WakelockPlus.toggle(enable: awake).catchError((Object e) => _s.log.record('wakelock', '$e')));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  ThemeMode get _themeMode => switch (_s.settings.theme) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      };

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: _s,
      child: FeedbackScope(
        service: _s.feedback,
        child: ListenableBuilder(
          // The account's language (shared with the dashboard) wins over the phone's once signed in.
          listenable: Listenable.merge(<Listenable>[_s.settings, _s.session]),
          builder: (BuildContext context, _) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (BuildContext context) => AppLocalizations.of(context).appName,
            theme: waiterThemeData(Brightness.light),
            darkTheme: waiterThemeData(Brightness.dark),
            themeMode: _themeMode,
            localizationsDelegates: appLocalizationsDelegates,
            locale: accountLocale(_s.session.user?.locale),
            supportedLocales: supportedLocales,
            localeListResolutionCallback: localeListResolutionCallback,
            builder: (BuildContext context, Widget? child) {
              _s.identity.language = uiLanguageOf(Localizations.localeOf(context)).apiCode;
              final Widget app = SnackbarHost(child: SessionSheetHost(child: child!));
              return WaiterThemeScope(
                mode: _themeMode,
                child: _s.environment.isProduction
                    ? app
                    : Stack(
                        children: <Widget>[
                          app,
                          Positioned(
                            top: 0,
                            right: 0,
                            child: EnvironmentBadge(
                              environment: _s.environment,
                              onLongPress: () {
                                final BuildContext? nav = _router.navigatorKey.currentContext;
                                if (nav != null) unawaited(showServerSheet(nav, _s));
                              },
                            ),
                          ),
                        ],
                      ),
              );
            },
            routerDelegate: _router,
            backButtonDispatcher: RootBackButtonDispatcher(),
          ),
        ),
      ),
    );
  }
}
