import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/environment.dart';
import '../core/l10n/l10n.dart';
import '../core/state/startup_problem.dart';
import '../core/theme/theme.dart';
import '../screens/s01_startup_problem.dart';

/// Shown when [bootstrap] fails (invalid build configuration, secure storage
/// that cannot be opened, a start that does not finish): the startup problem
/// screen with "Try again", instead of a launch screen that never ends.
class StartupFailureApp extends StatefulWidget {
  const StartupFailureApp({required this.problem, required this.environment, required this.onRetry, super.key});

  final StartupProblem problem;

  /// Null when the build configuration could not be read.
  final AppEnvironment? environment;

  /// Runs the start again (replaces this app on success).
  final Future<void> Function() onRetry;

  @override
  State<StartupFailureApp> createState() => _StartupFailureAppState();
}

class _StartupFailureAppState extends State<StartupFailureApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await widget.onRetry();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (BuildContext context) => AppLocalizations.of(context).appName,
        theme: waiterThemeData(Brightness.light),
        darkTheme: waiterThemeData(Brightness.dark),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: supportedLocales,
        localeListResolutionCallback: localeListResolutionCallback,
        builder: (BuildContext context, Widget? child) => WaiterThemeScope(mode: ThemeMode.system, child: child!),
        home: Builder(
          builder: (BuildContext context) => StartupProblemView(
            problem: widget.problem,
            environment: widget.environment,
            retrying: _retrying,
            onRetry: () => unawaited(_retry()),
          ),
        ),
      );
}
