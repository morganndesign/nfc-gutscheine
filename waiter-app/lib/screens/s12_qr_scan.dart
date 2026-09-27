import 'dart:async';

import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../components/components.dart';
import '../components/support/announce.dart';
import '../components/support/delayed_presence.dart';
import '../core/state/loop_controller.dart';
import '../core/state/loop_state.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'scan/qr_camera.dart';
import 'scan/viewfinder.dart';

/// Viewfinder window sizes (03a §8): 256 on phones, 224 compact or at large
/// text, 320 on tablets.
const double _window = 256;
const double _windowCompact = 224;
const double _windowTablet = 320;

/// Window centre at 42 % of the screen height on phones (03a §8); centred
/// on tablets (08 §4.3).
const double _windowCentrePhone = 0.42;
const double _windowCentreTablet = 0.5;

/// The hint wraps to 3 lines at large text; the window shrinks from here on.
const double _largeText = 1.3;

/// "Not a gift card" stays for 2.5 s; the same payload is ignored for 3 s.
const Duration _notCardLifetime = Duration(milliseconds: 2500);
const Duration _ignoreSamePayload = Duration(seconds: 3);

/// Spinner in the window while the camera starts, after 500 ms.
const Duration _startingSpinnerDelay = Duration(milliseconds: 500);

/// Icon plate of the camera states (S16 §11.3): 96 pt, glyph 48.
const double _plate = 96;

/// S12 · QR scan (03a §8) with the S16 camera states (03a §11.3, 12
/// P03–P05). Always rendered with dark-theme values over the live camera
/// (light status bar content, 09 §6.4).
///
/// [cameraFactory] creates the camera; production uses `mobile_scanner`
/// ([MobileScannerQrCamera]).
class QrScanScreen extends StatefulWidget {
  /// Creates the screen.
  const QrScanScreen({
    super.key,
    this.cameraFactory = MobileScannerQrCamera.new,
  });

  /// Creates the camera this screen owns.
  final QrCameraFactory cameraFactory;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with WidgetsBindingObserver {
  /// The torch state is remembered for the app session (03a §8).
  static bool _torchRemembered = false;

  late final QrCamera _camera = widget.cameraFactory(torch: _torchRemembered);
  StreamSubscription<QrDetection>? _detections;
  LoopController? _loop;

  Rect? _codeBounds;
  bool _notCard = false;
  String? _ignoredPayload;
  Timer? _notCardTimer;
  Timer? _ignoreTimer;
  bool _wasSlow = false;
  Size _view = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detections = _camera.detections.listen(_onDetection);
    _camera.addListener(_onCamera);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loop == null) {
      final LoopController loop = context.services.loop;
      _loop = loop;
      loop.addListener(_onLoop);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loop?.removeListener(_onLoop);
    _camera.removeListener(_onCamera);
    unawaited(_detections?.cancel());
    _camera.dispose();
    _notCardTimer?.cancel();
    _ignoreTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from Settings with permission granted starts the camera
    // without a tap (03a §11.3).
    if (state == AppLifecycleState.resumed &&
        _camera.status == QrCameraStatus.denied) {
      unawaited(_camera.start());
    }
  }

  bool get _lookingUp => switch (_loop!.state) {
    LookingUpState(:final LookupOrigin origin) => origin == LookupOrigin.qr,
    _ => false,
  };

  void _onCamera() {
    // A page rebuilt for a lookup in flight keeps the preview frozen.
    if (_camera.status == QrCameraStatus.running && _lookingUp) {
      unawaited(_camera.pause());
    }
    _torchRemembered = _camera.torchOn;
    setState(() {});
  }

  void _onLoop() {
    final LoopState state = _loop!.state;
    final bool slow = state is LookingUpState && state.slow;
    if (slow && !_wasSlow) {
      announce(context, AppLocalizations.of(context).scanSlow);
    }
    _wasSlow = slow;
    // Cancel during the lookup: unfreeze and resume searching (03a §8).
    if (state is QrScanState && _codeBounds != null) {
      setState(() => _codeBounds = null);
      unawaited(_camera.start());
    }
  }

  /// One detection = one request (03a §8): a valid card freezes the preview;
  /// anything else shows `qr.notCard` and is ignored for 3 s.
  void _onDetection(QrDetection detection) {
    final LoopController loop = _loop!;
    if (loop.state is! QrScanState || !loop.isOnline) return;
    if (detection.raw == _ignoredPayload) return;
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (loop.qrDetected(detection.raw)) {
      setState(() {
        _notCard = false;
        _codeBounds = detection.boundsIn(_view);
      });
      unawaited(_camera.pause());
      announce(context, l10n.scanDetected);
      return;
    }
    _ignoredPayload = detection.raw;
    _ignoreTimer?.cancel();
    _ignoreTimer = Timer(_ignoreSamePayload, () => _ignoredPayload = null);
    _notCardTimer?.cancel();
    _notCardTimer = Timer(_notCardLifetime, () {
      if (mounted) setState(() => _notCard = false);
    });
    setState(() => _notCard = true);
    announce(context, l10n.qrNotCard, assertive: true);
  }

  void _toggleTorch() {
    context.services.feedback.haptic(HapticToken.select);
    unawaited(_camera.toggleTorch());
  }

  /// S12 → S11 replaces S12; back from S11 goes to S05 (03a §7).
  void _enterNumber() => _loop!.openManual();

  void _focusAt(Offset local) {
    if (_view.isEmpty) return;
    unawaited(
      _camera.focusAt(Offset(local.dx / _view.width, local.dy / _view.height)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WaiterTheme current = context.waiter;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: waiterThemeData(
          Brightness.dark,
          highContrast: current.isHighContrast,
          boldText: current.boldText,
        ),
        child: Builder(builder: _buildDark),
      ),
    );
  }

  Widget _buildDark(BuildContext context) {
    final LoopController loop = _loop!;
    return ListenableBuilder(
      listenable: loop,
      builder: (BuildContext context, _) {
        final AppLocalizations l10n = AppLocalizations.of(context);
        final WaiterColors c = context.colors;
        final QrCameraStatus status = _camera.status;
        final bool usable =
            status == QrCameraStatus.starting ||
            status == QrCameraStatus.running;
        final bool torch = usable && _camera.torchAvailable;

        return ColoredBox(
          color: c.bgCanvas,
          child: Stack(
            children: <Widget>[
              if (usable) Positioned.fill(child: _preview(context, loop)),
              Column(
                children: <Widget>[
                  TopBar.task(
                    onClose: loop.back,
                    title: l10n.qrTitle,
                    onCamera: true,
                    trailing: torch
                        ? WaiterIconButton(
                            icon: WaiterIcon.flashlight,
                            toggledIcon: WaiterIcon.flashlightOff,
                            semanticLabel: _camera.torchOn
                                ? l10n.qrTorchOff
                                : l10n.qrTorchOn,
                            toggled: _camera.torchOn,
                            variant: IconButtonVariant.onCamera,
                            onPressed: _toggleTorch,
                          )
                        : null,
                  ),
                  Expanded(
                    child: usable
                        ? const SizedBox.expand()
                        : _CameraProblem(
                            denied: status == QrCameraStatus.denied,
                            onOpenSettings: () => unawaited(
                              context.services.system.openAppSettings(),
                            ),
                            onEnterNumber: _enterNumber,
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Preview, scrim with the window, brackets, hint and the bottom action.
  Widget _preview(BuildContext context, LoopController loop) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final WaiterLayout layout = context.layout;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final LoopState state = loop.state;
    final bool lookingUp = _lookingUp;
    final bool slow = lookingUp && state is LookingUpState && state.slow;
    final bool online = loop.isOnline;

    final double side = layout.widthClass.isTablet
        ? _windowTablet
        : layout.heightClass.isCompact ||
              MediaQuery.textScalerOf(context).scale(1) >= _largeText
        ? _windowCompact
        : _window;
    final double centreY =
        layout.size.height *
        (layout.widthClass.isTablet ? _windowCentreTablet : _windowCentrePhone);
    final Rect window = Rect.fromCenter(
      center: Offset(layout.size.width / 2, centreY),
      width: side,
      height: side,
    );
    final Rect? code = _codeBounds;
    final Rect target = code == null || reduceMotion
        ? window
        : code.intersect(window.inflate(side / 2));

    final Widget hint = Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: Motion.durationFast,
        switchInCurve: Motion.easeStandard,
        switchOutCurve: Motion.easeStandard,
        child: _hint(l10n, c, online: online, lookingUp: lookingUp, slow: slow),
      ),
    );

    final Widget action = AnimatedSwitcher(
      duration: Motion.durationFast,
      child: slow
          ? TertiaryButton(
              key: const ValueKey<String>('cancel'),
              label: l10n.commonCancel,
              large: true,
              onPressed: loop.back,
            )
          : SecondaryButton(
              key: const ValueKey<String>('manual'),
              label: l10n.qrManual,
              icon: WaiterIcon.keyboard,
              onPressed: _enterNumber,
            ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _view = constraints.biggest;
        return Stack(
          children: <Widget>[
            Positioned.fill(child: _camera.buildPreview(context)),
            Positioned.fill(
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: target),
                duration: Motion.durationFast,
                curve: Motion.easeDecelerate,
                builder: (BuildContext context, Rect? brackets, _) =>
                    CustomPaint(
                      painter: ViewfinderPainter(
                        window: window,
                        brackets: brackets ?? window,
                        scrim: c.scrim,
                        bracketColor: _notCard ? c.warning : c.accentSaffron,
                      ),
                    ),
              ),
            ),
            Positioned.fromRect(
              rect: window,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (TapUpDetails d) =>
                    _focusAt(d.localPosition + window.topLeft),
                child: Center(
                  child: DelayedPresence(
                    active: _camera.status == QrCameraStatus.starting,
                    delay: _startingSpinnerDelay,
                    builder: (BuildContext context, bool visible) => visible
                        ? Spinner(color: c.fgPrimary)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: window.bottom + Space.s6,
              left: layout.margin,
              right: layout.margin,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: LayoutTokens.maxForm,
                  ),
                  child: hint,
                ),
              ),
            ),
            Positioned(
              left: layout.margin,
              right: layout.margin,
              bottom: layout.viewPadding.bottom + layout.ctaBottomPadding,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: LayoutTokens.maxForm,
                  ),
                  child: action,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _hint(
    AppLocalizations l10n,
    WaiterColors c, {
    required bool online,
    required bool lookingUp,
    required bool slow,
  }) {
    if (!online) {
      return Row(
        key: const ValueKey<String>('offline'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          WaiterIconView(WaiterIcon.wifiOff, size: IconSize.s20, color: c.info),
          const SizedBox(width: Space.s2),
          Flexible(
            child: ScaledText(
              l10n.offlineTitle,
              type: TypeTokens.bodyM,
              color: c.info,
            ),
          ),
        ],
      );
    }
    if (lookingUp) {
      return Row(
        key: ValueKey<bool>(slow),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Spinner(color: c.fgPrimary),
          const SizedBox(width: Space.s2),
          Flexible(
            child: ScaledText(
              slow ? l10n.scanSlow : l10n.scanLookingUp,
              type: TypeTokens.bodyM,
            ),
          ),
        ],
      );
    }
    if (_notCard) {
      return ScaledText(
        l10n.qrNotCard,
        key: const ValueKey<String>('notCard'),
        type: TypeTokens.bodyM,
        color: c.warning,
        textAlign: TextAlign.center,
      );
    }
    return ScaledText(
      l10n.qrHint,
      key: const ValueKey<String>('hint'),
      type: TypeTokens.bodyL,
      textAlign: TextAlign.center,
      maxLines: 3,
    );
  }
}

/// Camera denied (P03/P04) or unavailable (P05), in place of the preview
/// (03a §11.3): icon plate, title, body; "Open Settings" + "Enter card
/// number", or only "Enter card number" when Settings cannot help.
class _CameraProblem extends StatelessWidget {
  const _CameraProblem({
    required this.denied,
    required this.onOpenSettings,
    required this.onEnterNumber,
  });

  final bool denied;
  final VoidCallback onOpenSettings;
  final VoidCallback onEnterNumber;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final WaiterLayout layout = context.layout;
    final Widget manual = denied
        ? SecondaryButton(
            label: l10n.qrManual,
            icon: WaiterIcon.keyboard,
            onPressed: onEnterNumber,
          )
        : PrimaryButton(
            label: l10n.qrManual,
            icon: WaiterIcon.keyboard,
            onPressed: onEnterNumber,
          );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.margin,
        0,
        layout.margin,
        layout.viewPadding.bottom + layout.ctaBottomPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: LayoutTokens.textMeasureTablet,
          ),
          child: Column(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ExcludeSemantics(
                          child: Container(
                            width: _plate,
                            height: _plate,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.bgKey,
                              shape: BoxShape.circle,
                            ),
                            child: WaiterIconView(
                              WaiterIcon.settings,
                              size: IconSize.s48,
                              color: c.fgSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.s6),
                        Semantics(
                          header: true,
                          liveRegion: true,
                          child: ScaledText(
                            denied
                                ? l10n.cameraDeniedTitle
                                : l10n.cameraUnavailableTitle,
                            type: TypeTokens.titleL,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: Space.s3),
                        ScaledText(
                          denied
                              ? l10n.cameraDeniedBody
                              : l10n.cameraUnavailableBody,
                          type: TypeTokens.bodyL,
                          color: c.fgSecondary,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (denied) ...<Widget>[
                PrimaryButton(
                  label: l10n.cameraDeniedAction,
                  icon: WaiterIcon.settings,
                  onPressed: onOpenSettings,
                ),
                const SizedBox(height: Space.s4),
              ],
              manual,
            ],
          ),
        ),
      ),
    );
  }
}
