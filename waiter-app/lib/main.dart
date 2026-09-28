import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app/app_scope.dart';
import 'app/bootstrap.dart';
import 'app/startup_failure_app.dart';
import 'app/waiter_app.dart';
import 'core/config/environment.dart';
import 'core/state/startup_problem.dart';

/// Longest time the service setup may take before the startup problem
/// screen replaces the launch screen.
const Duration bootstrapTimeout = Duration(seconds: 20);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await launch();
}

/// Starts the app. Every failure ends on a screen with the reason and
/// "Try again" — never on a launch screen that does not go away.
/// [start] and [timeout] are replaced only in tests.
Future<void> launch({Future<AppServices> Function() start = bootstrap, Duration timeout = bootstrapTimeout}) async {
  Future<void> retry() => launch(start: start, timeout: timeout);
  try {
    runApp(WaiterApp(services: await start().timeout(timeout)));
  } on Object catch (error) {
    debugPrint('GiftCard Waiter could not start: $error');
    AppEnvironment? environment;
    try {
      environment = AppEnvironment.fromDefines();
    } on ConfigurationProblem {
      environment = null;
    }
    final StartupProblem problem = error is TimeoutException
        ? StartupProblem(StartupProblemKind.unknown, detail: 'start did not finish within ${timeout.inSeconds} s')
        : StartupProblem.fromError(error);
    runApp(StartupFailureApp(problem: problem, environment: environment, onRetry: retry));
  }
}
