import 'dart:async';

import 'package:flutter/widgets.dart';

import '../components/components.dart';
import '../components/support/announce.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';

/// S01 · Splash (03a §1, 06 M01, 10 §2.3): a continuation of the OS launch
/// screen — the 96-pt app mark centred on `bg.canvas`, pixel-identical to
/// the native launch frame. Routing runs in the session controller; this
/// screen only covers slow starts.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// The mark of the native launch screen: 96 pt with a 5-pt stroke
/// (10 §2.3; iOS `launch-mark.pdf`, Android legacy 96 dp bitmap).
const double _markSize = 96;
const double _markStroke = 5;

/// The Spinner appears only when routing takes longer than this (03a §1).
const Duration _slowAfter = Duration(milliseconds: 1000);

/// Exit (03a §1 Animations): the mark scales 1.00 → 0.96 and fades out
/// during the first 120 ms of the route's reverse run.
const double _exitScale = 0.96;
const Duration _exitFade = Duration(milliseconds: 120);

class _SplashScreenState extends State<SplashScreen> {
  Timer? _slowTimer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _slowTimer = Timer(_slowAfter, () {
      if (!mounted) return;
      setState(() => _slow = true);
      announce(context, AppLocalizations.of(context).splashLoading);
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    final WaiterLayout layout = context.layout;
    final Animation<double>? route = ModalRoute.of(context)?.animation;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget mark = WaiterIconView.mark(
      WaiterIcon.cardArcs,
      dimension: _markSize,
      strokeWidth: _markStroke,
      color: c.fgPrimary,
      accentColor: c.accentSaffron,
    );
    if (route != null && !reduceMotion) {
      mark = AnimatedBuilder(
        animation: route,
        builder: (BuildContext context, Widget? child) {
          if (route.status != AnimationStatus.reverse) return child!;
          final double t = route.value;
          final double fadeShare = _exitFade.inMicroseconds / Motion.durationFast.inMicroseconds;
          return Opacity(
            opacity: ((t - (1 - fadeShare)) / fadeShare).clamp(0.0, 1.0),
            child: Transform.scale(scale: _exitScale + (1 - _exitScale) * t, child: child),
          );
        },
        child: mark,
      );
    }

    return ColoredBox(
      color: c.bgCanvas,
      child: Stack(
        children: <Widget>[
          Center(
            child: Semantics(image: true, label: AppLocalizations.of(context).splashLoading, child: mark),
          ),
          if (_slow)
            Positioned(
              left: 0,
              right: 0,
              // Centre y = height − bottom inset − 56 (03a §1).
              bottom: layout.viewPadding.bottom + Sizes.targetMin - Sizes.spinnerS / 2,
              child: Center(
                // crossfade-state in (03a §1).
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Motion.durationFast,
                  curve: Motion.easeStandard,
                  builder: (BuildContext context, double opacity, Widget? child) =>
                      Opacity(opacity: opacity, child: child),
                  child: Spinner(color: c.fgTertiary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
