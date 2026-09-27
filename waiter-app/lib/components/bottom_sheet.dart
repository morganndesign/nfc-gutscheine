import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'icon_button.dart';
import 'support/hairline.dart';
import 'support/shape.dart';

/// Drag physics of 06 M24.
abstract final class _SheetPhysics {
  /// Resistance above the largest detent.
  static const double rubberBand = 0.55;

  /// Maximum upward displacement.
  static const double rubberBandMax = 24;

  /// Resistance of a locked (non-dismissible) sheet dragged down.
  static const double lockedFactor = 0.3;

  /// Maximum downward displacement of a locked sheet.
  static const double lockedMax = 16;

  /// Resting point projection: position + velocity × 0.2 s.
  static const double projection = 0.2;

  /// Dismiss when the projected position passes this share of the height.
  static const double dismissShare = 0.5;

  /// Dismiss on a downward fling faster than this (pt/s).
  static const double dismissVelocity = 1000;
}

/// The frame of a bottom sheet (05 §4.2): top corners `radius.sheet`
/// (continuous on iOS), 36 × 5 grabber 8 pt from the top in a 24-pt handle
/// area (not focusable), 56-pt header with ✕ leading, a centred
/// `type.title.m` title (header, initial focus) and an optional trailing
/// control, a hairline under the header once content scrolls. Fill
/// `bg.surface` (a stacked sheet is `bg.raised` in dark theme); light theme
/// casts `elev.3` upward, dark theme a 1-px `border.subtle` edge.
/// Named `WaiterBottomSheet` because Material's `BottomSheet` would collide.
class WaiterBottomSheet extends StatefulWidget {
  /// Creates the frame around [child].
  const WaiterBottomSheet({
    required this.title,
    required this.child,
    required this.onClose,
    super.key,
    this.trailing,
    this.stacked = false,
  });

  /// Sheet title.
  final String title;

  /// Content.
  final Widget child;

  /// ✕ action; `null` hides ✕ (a sheet that needs its own action).
  final VoidCallback? onClose;

  /// Optional trailing IconButton.
  final Widget? trailing;

  /// Whether this sheet sits on another sheet.
  final bool stacked;

  @override
  State<WaiterBottomSheet> createState() => _WaiterBottomSheetState();
}

class _WaiterBottomSheetState extends State<WaiterBottomSheet> {
  bool _scrolled = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final bool scrolled = n.metrics.pixels > n.metrics.minScrollExtent;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final WaiterColors c = theme.colors;
    final bool dark = theme.brightness == Brightness.dark;
    final double margin = context.layout.margin;
    const BorderRadius radius = BorderRadius.vertical(
      top: Radius.circular(SheetTokens.radius),
    );
    final VoidCallback? onClose = widget.onClose;

    final Widget header = SizedBox(
      height: SheetTokens.header,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: margin - IconButtonTokens.marginInset,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: IconButtonTokens.target,
              child: onClose == null
                  ? null
                  : WaiterIconButton(
                      icon: WaiterIcon.x,
                      semanticLabel: AppLocalizations.of(context).commonClose,
                      onPressed: onClose,
                    ),
            ),
            Expanded(
              child: Focus(
                autofocus: true,
                child: Semantics(
                  container: true,
                  header: true,
                  child: ScaledText(
                    widget.title,
                    type: TypeTokens.titleM,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ),
            ),
            SizedBox(width: IconButtonTokens.target, child: widget.trailing),
          ],
        ),
      ),
    );

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: widget.title,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: dark && widget.stacked ? c.bgRaised : c.bgSurface,
          shape: waiterShape(
            context,
            radius,
            side: innerSide(dark ? c.borderSubtle : null, width: 0),
          ),
          shadows: theme.elevation.level3Upward.shadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExcludeSemantics(
              child: SizedBox(
                height: SheetTokens.handleArea,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: SheetTokens.grabberTop),
                    child: Container(
                      width: Sizes.grabberWidth,
                      height: Sizes.grabberHeight,
                      decoration: BoxDecoration(
                        color: c.borderStrong,
                        borderRadius: BorderRadius.circular(Radii.full),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            header,
            AnimatedOpacity(
              opacity: _scrolled ? 1 : 0,
              duration: Motion.durationFast,
              child: Hairline(color: c.borderSubtle),
            ),
            Flexible(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Presents a content-fit sheet (Menu S14, session expired S15, Recent
/// detail S13) with the custom sheet route (05 §4.2, 06 M24).
///
/// Height = content, capped at the large detent (window − top safe area −
/// 12 pt); content scrolls inside. Opens with `motion.spring.soft` and a
/// scrim fade; drags 1:1 with rubber-banding above; dismisses on ✕, scrim
/// tap, Android back or a drag/fling down (projected past half the height
/// or faster than 1000 pt/s). [dismissible] false locks it (S15): no scrim
/// or drag dismissal, no ✕, back is blocked. Opening from inside a sheet
/// stacks it (second scrim at 32 %). Content gets the screen margin
/// horizontally unless [edgeToEdge] (rows that draw their own insets);
/// bottom padding = safe area + 16. [barrierLabel] names the scrim for
/// screen readers (default `common.close`; S14 `menu.close`).
Future<T?> showWaiterSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  bool dismissible = true,
  bool edgeToEdge = false,
  Widget? trailing,
  String? barrierLabel,
}) {
  final bool stacked = ModalRoute.of(context) is _SheetRoute;
  return Navigator.of(context).push<T>(
    _SheetRoute<T>(
      scrim: stacked ? SheetTokens.stackedScrim : context.colors.scrim,
      dismissible: dismissible,
      barrierLabel: barrierLabel ?? AppLocalizations.of(context).commonClose,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      builder: (BuildContext sheetContext) => _DraggableSheet(
        dismissible: dismissible,
        child: WaiterBottomSheet(
          title: title,
          stacked: stacked,
          trailing: trailing,
          onClose: dismissible ? () => Navigator.of(sheetContext).pop() : null,
          child: _SheetContent(
            edgeToEdge: edgeToEdge,
            child: builder(sheetContext),
          ),
        ),
      ),
    ),
  );
}

/// Builds sheet content around the sheet's [ScrollController].
typedef SheetScrollBuilder =
    Widget Function(BuildContext context, ScrollController controller);

/// Presents a sheet with detents (S13 Recent): opens at the medium detent
/// (50 % of the window) — at the large detent on compact-height windows,
/// where medium would show fewer than 3 rows (08 §3.8) — drags between the
/// detents (large = window − top safe area − 12 pt) and down to dismiss; the list scrolls inside and hands
/// over to the sheet drag at its top (05 §4.2, 06 M24). [builder] must use
/// the given controller for its scrollable.
Future<T?> showWaiterScrollSheet<T>({
  required BuildContext context,
  required String title,
  required SheetScrollBuilder builder,
  Widget? trailing,
  String? barrierLabel,
}) {
  final bool stacked = ModalRoute.of(context) is _SheetRoute;
  return Navigator.of(context).push<T>(
    _SheetRoute<T>(
      scrim: stacked ? SheetTokens.stackedScrim : context.colors.scrim,
      dismissible: true,
      barrierLabel: barrierLabel ?? AppLocalizations.of(context).commonClose,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      builder: (BuildContext sheetContext) => _DetentSheet(
        builder: (BuildContext context, ScrollController controller) =>
            WaiterBottomSheet(
              title: title,
              stacked: stacked,
              trailing: trailing,
              onClose: () => Navigator.of(sheetContext).pop(),
              child: builder(context, controller),
            ),
      ),
    ),
  );
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({required this.edgeToEdge, required this.child});

  final bool edgeToEdge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final WaiterLayout layout = context.layout;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: edgeToEdge ? 0 : layout.margin,
        right: edgeToEdge ? 0 : layout.margin,
        bottom: layout.viewPadding.bottom + Space.s4,
      ),
      child: child,
    );
  }
}

/// Large detent height for the window of [context].
double _largeDetent(BuildContext context) {
  final WaiterLayout layout = context.layout;
  return layout.size.height - layout.viewPadding.top - SheetTokens.largeTopGap;
}

class _SheetRoute<T> extends PopupRoute<T> {
  _SheetRoute({
    required this.scrim,
    required this.dismissible,
    required this.barrierLabel,
    required this.reduceMotion,
    required this.builder,
  });

  final Color scrim;
  final bool dismissible;
  final bool reduceMotion;
  final WidgetBuilder builder;

  @override
  final String barrierLabel;

  @override
  Color get barrierColor => scrim;

  @override
  bool get barrierDismissible => dismissible;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Motion.durationFast : Motion.durationBase;

  @override
  Duration get reverseTransitionDuration => Motion.durationFast;

  @override
  Simulation? createSimulation({required bool forward}) {
    if (!forward || reduceMotion) return null;
    return SpringSimulation(Motion.springSoft, controller!.value, 1, 0);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return PopScope(
      canPop: dismissible,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: LayoutTokens.maxSheet,
            maxHeight: _largeDetent(context),
          ),
          child: Builder(builder: builder),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion) {
      // Fade + 8-pt rise only (06 M24 Reduce Motion).
      return FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) => Transform.translate(
            offset: Offset(0, Space.s2 * (1 - animation.value)),
            child: child,
          ),
          child: child,
        ),
      );
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final bool closing = animation.status == AnimationStatus.reverse;
        final double t = closing
            ? Motion.easeAccelerate.transform(animation.value)
            : animation.value;
        return FractionalTranslation(
          translation: Offset(0, 1 - t),
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Drag handling of content-fit sheets (06 M24).
class _DraggableSheet extends StatefulWidget {
  const _DraggableSheet({required this.dismissible, required this.child});

  final bool dismissible;
  final Widget child;

  @override
  State<_DraggableSheet> createState() => _DraggableSheetState();
}

class _DraggableSheetState extends State<_DraggableSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );
  double _raw = 0;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  double _resist(double raw) {
    if (raw < 0) {
      return math.max(
        raw * _SheetPhysics.rubberBand,
        -_SheetPhysics.rubberBandMax,
      );
    }
    if (!widget.dismissible) {
      return math.min(
        raw * _SheetPhysics.lockedFactor,
        _SheetPhysics.lockedMax,
      );
    }
    return raw;
  }

  void _update(DragUpdateDetails d) {
    _raw += d.delta.dy;
    _offset.value = _resist(_raw);
  }

  void _end(DragEndDetails d) {
    final double velocity = d.primaryVelocity ?? 0;
    final double height = context.size?.height ?? 0;
    final double projected =
        _offset.value + velocity * _SheetPhysics.projection;
    _raw = 0;
    if (widget.dismissible &&
        (projected > height * _SheetPhysics.dismissShare ||
            velocity > _SheetPhysics.dismissVelocity)) {
      Navigator.of(context).pop();
      return;
    }
    _offset.animateWith(
      SpringSimulation(Motion.springSoft, _offset.value, 0, velocity),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _update,
      onVerticalDragEnd: _end,
      child: AnimatedBuilder(
        animation: _offset,
        builder: (BuildContext context, Widget? child) =>
            Transform.translate(offset: Offset(0, _offset.value), child: child),
        child: widget.child,
      ),
    );
  }
}

/// Medium ↔ large detents with scroll hand-off.
class _DetentSheet extends StatefulWidget {
  const _DetentSheet({required this.builder});

  final SheetScrollBuilder builder;

  @override
  State<_DetentSheet> createState() => _DetentSheetState();
}

class _DetentSheetState extends State<_DetentSheet> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();
  bool _closing = false;

  /// Medium detent: 50 % of the window (05 §4.2).
  static const double _medium = 0.5;

  /// Below this size the sheet counts as dismissed.
  static const double _closed = 0.02;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSize);
  }

  void _onSize() {
    if (_closing || !_controller.isAttached) return;
    if (_controller.size <= _closed) {
      _closing = true;
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double window = context.layout.size.height;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The route caps the sheet at the large detent; sizes are fractions
        // of that height.
        final double large = constraints.maxHeight;
        final double medium = large <= 0
            ? 1
            : math.min(1, window * _medium / large);
        final bool startLarge = context.layout.heightClass.isCompact;
        return DraggableScrollableSheet(
          controller: _controller,
          initialChildSize: startLarge ? 1 : medium,
          minChildSize: 0,
          maxChildSize: 1,
          snap: true,
          snapSizes: medium < 1 ? <double>[medium] : null,
          builder: widget.builder,
        );
      },
    );
  }
}
