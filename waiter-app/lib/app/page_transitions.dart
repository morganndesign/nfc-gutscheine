import 'package:flutter/widgets.dart';

import '../core/tokens/tokens.dart';

/// How a screen enters (06 M01, M03, M08, M20, M22): access screens and
/// returns fade with a small rise; task screens (Layer 1) rise from the scan
/// origin; Reduce Motion is a 160 ms fade for all.
enum PageMotion { access, task, problem }

/// A declarative page of the app navigator (02 §4.2: no horizontal pushes,
/// no back-stack metaphor). Back is routed through the loop, never by the
/// route itself.
class WaiterPage extends Page<void> {
  const WaiterPage({required LocalKey super.key, required this.child, this.motion = PageMotion.access, super.name});

  final Widget child;
  final PageMotion motion;

  @override
  Route<void> createRoute(BuildContext context) => _WaiterPageRoute(this);
}

class _WaiterPageRoute extends PageRoute<void> {
  _WaiterPageRoute(WaiterPage page) : super(settings: page);

  WaiterPage get _page => settings as WaiterPage;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => true;

  @override
  Duration get transitionDuration => Motion.durationBase;

  @override
  Duration get reverseTransitionDuration => Motion.durationFast;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      _page.child;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    final Curve curve = animation.status == AnimationStatus.reverse ? Motion.easeAccelerate : Motion.easeDecelerate;
    final CurvedAnimation curved = CurvedAnimation(parent: animation, curve: curve);
    final double rise = switch (_page.motion) {
      PageMotion.access => 8,
      PageMotion.problem => 16,
      PageMotion.task => 24,
    };
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (BuildContext context, Widget? child) => Transform.translate(
          offset: Offset(0, rise * (1 - curved.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}
