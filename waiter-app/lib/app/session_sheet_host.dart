import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';
import '../screens/s15_session.dart';
import 'app_scope.dart';

/// S15 "Session expired" (A01): a bottom sheet that is not dismissible and
/// may appear over any layer, including other sheets (N7). It lives above
/// the navigator so the layer stack underneath stays exactly as it was
/// (lookup → S05, redeem → S07 with the amount kept).
class SessionSheetHost extends StatelessWidget {
  const SessionSheetHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.services;
    return ListenableBuilder(
      listenable: services.session,
      builder: (BuildContext context, Widget? app) {
        final bool open = services.session.expired != null;
        final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
        final Duration duration = reduceMotion ? Motion.durationFast : Motion.durationBase;
        return Stack(
          children: <Widget>[
            ExcludeSemantics(excluding: open, child: app!),
            IgnorePointer(
              ignoring: !open,
              child: AnimatedOpacity(
                opacity: open ? 1 : 0,
                duration: duration,
                curve: Motion.easeStandard,
                child: ColoredBox(color: context.colors.scrim, child: const SizedBox.expand()),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                offset: open ? Offset.zero : const Offset(0, 1),
                duration: duration,
                curve: open ? Motion.easeDecelerate : Motion.easeAccelerate,
                child: open
                    // Its own overlay: text fields inside need one for selection handles.
                    ? Overlay(initialEntries: <OverlayEntry>[OverlayEntry(builder: (_) => const SessionExpiredSheet())])
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}
