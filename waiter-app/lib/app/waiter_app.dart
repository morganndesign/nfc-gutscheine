import 'dart:async';

import 'package:app_links/app_links.dart';
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
/// platform coordination that follows the app state — Android reader mode,
/// keep-screen-on, lifecycle and incoming card links (09 §7).
class WaiterApp extends StatefulWidget {
  const WaiterApp({required this.services, this.appLinks, super.key});

  final AppServices services;

  /// Injected in tests; the real plugin otherwise.
  final AppLinks? appLinks;

  @override
  State<WaiterApp> createState() => _WaiterAppState();
}

class _WaiterAppState extends State<WaiterApp> with WidgetsBindingObserver {
  AppServices get _s => widget.services;

  late final WaiterRouterDelegate _router = WaiterRouterDelegate(_s);
  bool _resumed = true;
  bool? _readerMode;
  bool? _awake;
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final Listenable state = Listenable.merge(<Listenable>[_s.session, _s.loop, _s.settings]);
    state.addListener(_coordinate);
    unawaited(_listenForLinks());
    unawaited(_s.session.start());
  }

  Future<void> _listenForLinks() async {
    final AppLinks links = widget.appLinks ?? AppLinks();
    _links = links.uriLinkStream.listen((Uri uri) => _s.loop.openLink(uri.toString()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _resumed = true;
        unawaited(_s.session.onForeground());
        unawaited(_s.loop.refreshNfcAvailability());
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        if (_resumed) _s.session.onBackground();
        _resumed = false;
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
    _coordinate();
  }

  /// Reader mode (02 §4.5.2) and keep-awake (09 §7.7) follow the state.
  void _coordinate() {
    final bool reader = _resumed && _s.loop.wantsReaderMode;
    if (reader != _readerMode) {
      _readerMode = reader;
      unawaited(_s.nfc.setReaderMode(enabled: reader).catchError((Object e) => _s.log.record('nfc.readerMode', '$e')));
    }
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
    unawaited(_links?.cancel());
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
          listenable: _s.settings,
          builder: (BuildContext context, _) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (BuildContext context) => AppLocalizations.of(context).appName,
            theme: waiterThemeData(Brightness.light),
            darkTheme: waiterThemeData(Brightness.dark),
            themeMode: _themeMode,
            localizationsDelegates: appLocalizationsDelegates,
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
