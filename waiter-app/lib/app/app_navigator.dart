import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/state/loop_state.dart';
import '../core/state/session_state.dart';
import '../screens/s01_splash.dart';
import '../screens/s01_startup_problem.dart';
import '../screens/s02_sign_in.dart';
import '../screens/s03_biometrics.dart';
import '../screens/s04_unlock.dart';
import '../screens/s05_ready.dart';
import '../screens/s07_charge.dart';
import '../screens/s09_success.dart';
import '../screens/s10_problem.dart';
import '../screens/s11_card_tap.dart';
import '../screens/s12_qr_scan.dart';
import '../screens/s15_session.dart';
import '../screens/s17_intro.dart';
import 'app_scope.dart';
import 'page_transitions.dart';

/// The app's root router: the layer stack is rendered from state (02 §4.2,
/// 09 §4.1 rule 2). The access phase decides the base screen; while active,
/// S05 is the root and at most one Layer 1 screen sits on it. Sheets (S13,
/// S14) and dialogs are pushed on top imperatively.
///
/// System back reaches the top route (a sheet, or a Layer 1 page whose
/// `PopScope` hands it to the loop); on S05 the system moves the app to the
/// background (N4). While the S15 session sheet is up, back is ignored.
class WaiterRouterDelegate extends RouterDelegate<Object> with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  WaiterRouterDelegate(this.services) {
    _listenable.addListener(notifyListeners);
  }

  final AppServices services;
  late final Listenable _listenable = Listenable.merge(<Listenable>[services.session, services.loop]);

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'app');

  @override
  Future<bool> popRoute() {
    if (services.session.expired != null) return SynchronousFuture<bool>(true);
    return super.popRoute();
  }

  @override
  Future<void> setNewRoutePath(Object configuration) => SynchronousFuture<void>(null);

  @override
  Widget build(BuildContext context) => Navigator(
        key: navigatorKey,
        pages: _pages(services),
        onDidRemovePage: (Page<Object?> page) {},
      );

  @override
  void dispose() {
    _listenable.removeListener(notifyListeners);
    super.dispose();
  }

  static const ValueKey<String> _ready = ValueKey<String>('S05');

  static List<Page<void>> _pages(AppServices services) {
    switch (services.session.phase) {
      case AccessPhase.launching:
        return const <Page<void>>[WaiterPage(key: ValueKey<String>('S01'), name: 'splash', child: SplashScreen())];
      case AccessPhase.startupProblem:
        return const <Page<void>>[
          WaiterPage(key: ValueKey<String>('S01-problem'), name: 'startupProblem', child: StartupProblemScreen()),
        ];
      case AccessPhase.signedOut:
        return const <Page<void>>[WaiterPage(key: ValueKey<String>('S02'), name: 'signIn', child: SignInScreen())];
      case AccessPhase.onboardingBiometrics:
        return const <Page<void>>[
          WaiterPage(key: ValueKey<String>('S03'), name: 'biometrics', child: EnableBiometricsScreen()),
        ];
      case AccessPhase.onboardingIntro:
        return const <Page<void>>[WaiterPage(key: ValueKey<String>('S17'), name: 'intro', child: IntroScreen())];
      case AccessPhase.locked:
        return const <Page<void>>[WaiterPage(key: ValueKey<String>('S04'), name: 'unlock', child: UnlockScreen())];
      case AccessPhase.blocked:
        return const <Page<void>>[WaiterPage(key: ValueKey<String>('S15'), name: 'blocked', child: BlockedScreen())];
      case AccessPhase.updateRequired:
        return const <Page<void>>[
          WaiterPage(key: ValueKey<String>('S15-update'), name: 'updateRequired', child: UpdateRequiredScreen()),
        ];
      case AccessPhase.active:
        final Page<void>? layer = _layer(services.loop.state);
        return <Page<void>>[
          const WaiterPage(key: _ready, name: 'ready', child: ReadyScreen()),
          ?layer,
        ];
    }
  }

  /// Layer 1 for the loop state (09 §5). A presentment stays on the screen it
  /// was started from: S12 with its own progress, S10 with a busy action.
  static Page<void>? _layer(LoopState state) => switch (state) {
        ReadyState() => null,
        PresentingState(:final PresentOrigin origin) => switch (origin) {
            PresentOrigin.qr => _task('S12', 'qr', const QrScanScreen()),
            PresentOrigin.problem => _problem,
          },
        QrScanState() => _task('S12', 'qr', const QrScanScreen()),
        CardTapState() => _task('S11', 'card', const CardTapScreen()),
        ChargeState() => _task('S07', 'charge', const ChargeScreen()),
        SuccessState() => _task('S09', 'success', const SuccessScreen()),
        ProblemState() => _problem,
      };

  static const Page<void> _problem = WaiterPage(
    key: ValueKey<String>('S10'),
    name: 'problem',
    motion: PageMotion.problem,
    child: _LoopBack(child: ProblemPage()),
  );

  static Page<void> _task(String id, String name, Widget child) =>
      WaiterPage(key: ValueKey<String>(id), name: name, motion: PageMotion.task, child: _LoopBack(child: child));
}

/// System back and the iOS back gesture on Layer 1 go through the loop
/// (N4–N6): exactly one layer, ignored while money may be moving.
class _LoopBack extends StatelessWidget {
  const _LoopBack({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop) context.services.loop.back();
        },
        child: child,
      );
}
