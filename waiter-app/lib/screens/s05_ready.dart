import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../app/money.dart';
import '../components/components.dart';
import '../components/support/announce.dart';
import '../components/support/delayed_presence.dart';
import '../core/api/models.dart';
import '../core/platform/nfc_service.dart';
import '../core/state/loop_controller.dart';
import '../core/state/loop_state.dart';
import '../core/state/session_controller.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'ios_sheet_texts.dart';
import 's13_recent.dart';
import 's14_menu.dart';
import 'scan/card_slot.dart';
import 'scan/focus_helpers.dart';

/// Layout variants of S05 (03a §5.7). V3 (reading / looking up) is layered
/// on V1/V2; V7 (maintenance banner) and V9 (keep screen on) combine with
/// every variant.
enum _Variant {
  /// V1 · Android, NFC on, online.
  listening,

  /// V2 · iPhone, NFC reading available, online.
  iosReady,

  /// V4 · Android, NFC adapter present but switched off (S16 P01).
  nfcOff,

  /// V5 · no NFC hardware, iPad (S16 P02).
  noNfc,

  /// V6 · no connectivity for ≥ 2 s (A13).
  offline,
}

/// How long a [ReadyNotice] replaces the instruction (03a §5.7 V10, §6.1;
/// 03a V6 `ready.offline.tap`).
Duration _noticeLifetime(ReadyNotice notice) => switch (notice) {
  ReadyNotice.iosTimeout => const Duration(seconds: 6),
  ReadyNotice.offlineRead => const Duration(milliseconds: 2500),
  ReadyNotice.readFailed || ReadyNotice.notCard => const Duration(seconds: 2),
};

/// `ready.online` stays 2 s (03a §5.7 V6).
const Duration _onlineSnackbar = Duration(seconds: 2);

/// The maintenance notice shows at most 2 lines (03a §5.7 V7).
const int _maintenanceLines = 2;

/// Offline is entered after this much confirmed loss (03a §5.7 V6).
const Duration _offlineAfter = Duration(seconds: 2);

/// Reference box of the NfcScanAnimation slot: the 176 × 120 canvas plus its
/// 96-pt glow fit a 200-pt square with the emitter at its centre (03a §5.1).
const double _motifReference = 200;

/// NfcScanAnimation slot sizes (03a §0.1, §5.1, §5.2, §5.13, §5.15).
const double _motifIos = 200;
const double _motifIosCompact = 160;
const double _motifAndroid = 240;
const double _motifAndroidCompact = 176;
const double _motifTablet = 280;

/// Smallest decorative size at large text (03a §5.12).
const double _motifMin = 120;

/// QR plate of V5 (03a §5.7): 160 pt, glyph 72.
const double _qrPlate = 160;
const double _qrGlyph = 72;

/// Diameter of the knock-out behind the offline glyph on the arcs.
const double _glyphKnockout = 32;

/// Android flex split above / below the instruction block (03a §5.2).
const int _androidFlexAbove = 45;
const int _androidFlexBelow = 55;

/// S05 · Ready (Home) with the inline S06 reading / looking-up states
/// (03a §5, §6.1, §6.4) and the S16 NFC variants (03a §11.1–11.2).
///
/// Renders from [LoopController] and [SessionController] state
/// (09 §4.1 rule 2); only presentation timers live here: the 2-s offline
/// confirmation, the notice lifetimes and focus/announcement bookkeeping.
class ReadyScreen extends StatefulWidget {
  /// Creates the screen.
  const ReadyScreen({super.key});

  @override
  State<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends State<ReadyScreen> {
  LoopController? _loop;
  late AppServices _services;
  late Listenable _state;

  LoopState _previous = const ReadyState();
  NfcAvailability? _availability;
  bool _offline = false;
  Timer? _offlineTimer;
  Timer? _noticeTimer;
  ReadyNotice? _timedNotice;
  bool _wasSlow = false;

  final FocusNode _instructionFocus = FocusNode(
    debugLabel: 'S05 instruction',
    skipTraversal: true,
  );
  final FocusNode _scanFocus = FocusNode(
    debugLabel: 'S05 scan card',
    skipTraversal: true,
  );
  final FocusNode _cancelFocus = FocusNode(
    debugLabel: 'S05 cancel lookup',
    skipTraversal: true,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services = context.services;
    if (_loop == null) {
      final LoopController loop = _services.loop;
      _loop = loop;
      _state = Listenable.merge(<Listenable>[loop, _services.session]);
      _previous = loop.state;
      _availability = loop.nfcAvailability;
      loop.addListener(_onLoop);
      _syncConnectivity(loop);
    }
  }

  @override
  void dispose() {
    _loop?.removeListener(_onLoop);
    _offlineTimer?.cancel();
    _noticeTimer?.cancel();
    _instructionFocus.dispose();
    _scanFocus.dispose();
    _cancelFocus.dispose();
    super.dispose();
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  // --------------------------------------------------------------- listener

  void _onLoop() {
    final LoopController loop = _loop!;
    final LoopState state = loop.state;
    final LoopState previous = _previous;
    _previous = state;

    if (loop.takeScanUnavailable()) {
      // P09: snackbar; the loop already played `haptic.warning`.
      SnackbarHost.maybeOf(
        context,
      )?.show(SnackbarData(message: _l10n.scanUnavailable));
    }
    _syncConnectivity(loop);
    _syncAvailability(loop);
    _syncNotice(state);

    if (state is LookingUpState && state.origin == LookupOrigin.ready) {
      if (previous is ReadyState && !loop.isIos) {
        // 07 §5.6: "Card detected" after a successful Android read.
        announce(context, _l10n.scanDetected);
      }
      if (state.slow && !_wasSlow) {
        announce(context, _l10n.scanSlow);
        focusFirstIn(_cancelFocus);
      }
      _wasSlow = state.slow;
    } else {
      _wasSlow = false;
    }

    if (state is ReadyState &&
        (previous is ChargeState ||
            previous is SuccessState ||
            previous is ProblemState)) {
      // 03a §5.12 / 07 §5.7: back on S05 the scan affordance takes focus.
      announce(context, _l10n.a11yReady);
      if (loop.isIos) {
        focusFirstIn(_scanFocus);
      } else {
        focusAfterFrame(_instructionFocus);
      }
    }
  }

  /// A13: offline after 2 s of confirmed loss; back online at once with the
  /// `ready.online` snackbar (03a §5.7 V6).
  void _syncConnectivity(LoopController loop) {
    if (loop.isOnline) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      if (_offline) {
        setState(() => _offline = false);
        SnackbarHost.maybeOf(context)?.show(
          SnackbarData(message: _l10n.readyOnline, duration: _onlineSnackbar),
        );
      }
      return;
    }
    if (_offline || _offlineTimer != null) return;
    _offlineTimer = Timer(_offlineAfter, () {
      _offlineTimer = null;
      if (!mounted || _loop!.isOnline) return;
      setState(() => _offline = true);
      announce(
        context,
        _l10n.a11yProblem(_l10n.offlineTitle, _l10n.offlineBody),
      );
    });
  }

  /// S16: NFC switched off / on while S05 is visible (03a §11.1).
  void _syncAvailability(LoopController loop) {
    final NfcAvailability now = loop.nfcAvailability;
    final NfcAvailability? before = _availability;
    _availability = now;
    if (before == now || loop.isIos) return;
    if (before == NfcAvailability.disabled && now == NfcAvailability.enabled) {
      _services.feedback.haptic(HapticToken.select);
      announce(context, _l10n.nfcOffOn);
    } else if (now == NfcAvailability.disabled) {
      announce(context, _l10n.a11yProblem(_l10n.nfcOffTitle, _l10n.nfcOffBody));
    }
  }

  /// One-off hints return to the instruction after their lifetime.
  void _syncNotice(LoopState state) {
    final ReadyNotice? notice = state is ReadyState ? state.notice : null;
    if (notice == _timedNotice) return;
    _timedNotice = notice;
    _noticeTimer?.cancel();
    _noticeTimer = null;
    if (notice == null) return;
    _noticeTimer = Timer(_noticeLifetime(notice), _loop!.clearReadyNotice);
    switch (notice) {
      case ReadyNotice.readFailed:
        announce(context, _l10n.scanReadFailedTitle, assertive: true);
      case ReadyNotice.notCard:
        announce(context, _l10n.scanNotCard, assertive: true);
      case ReadyNotice.iosTimeout:
        announce(context, _l10n.readyIosTimeout);
      case ReadyNotice.offlineRead:
        announce(context, _l10n.readyOfflineTap);
    }
  }

  // ---------------------------------------------------------------- actions

  void _scanCard() => unawaited(_loop!.startScan(iosSheetTextsOf(context)));

  void _openNfcSettings() => unawaited(_services.nfc.openSettings());

  /// Hardware Return on S05: the primary action of the variant (08 §7).
  void _primaryAction(_Variant variant) {
    switch (variant) {
      case _Variant.iosReady:
        if (_loop!.state is ReadyState) _scanCard();
      case _Variant.noNfc:
        if (!_offline) _loop!.openQr();
      case _Variant.nfcOff:
        _openNfcSettings();
      case _Variant.listening || _Variant.offline:
        break;
    }
  }

  // ------------------------------------------------------------------ build

  _Variant _variantOf(LoopController loop) {
    final NfcAvailability nfc = loop.nfcAvailability;
    if (nfc == NfcAvailability.unsupported ||
        (nfc == NfcAvailability.disabled && loop.isIos)) {
      return _Variant.noNfc;
    }
    if (nfc == NfcAvailability.disabled) return _Variant.nfcOff;
    if (_offline) return _Variant.offline;
    return loop.isIos ? _Variant.iosReady : _Variant.listening;
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = _services;
    return ListenableBuilder(
      listenable: _state,
      builder: (BuildContext context, _) {
        final LoopController loop = services.loop;
        final _Variant variant = _variantOf(loop);
        final LoopState state = loop.state;
        final bool lookingUp =
            state is LookingUpState &&
            state.origin == LookupOrigin.ready &&
            (variant == _Variant.listening || variant == _Variant.iosReady);
        final SessionUser? user = services.session.user;

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.enter): () =>
                _primaryAction(variant),
            const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
                _primaryAction(variant),
          },
          child: Focus(
            autofocus: true,
            skipTraversal: true,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) {
                // V10: the timeout hint yields to the next tap anywhere.
                if (state case ReadyState(notice: ReadyNotice.iosTimeout)) {
                  loop.clearReadyNotice();
                }
              },
              child: ColoredBox(
                color: context.colors.bgCanvas,
                child: Column(
                  children: <Widget>[
                    TopBar.home(
                      restaurantName: user?.restaurant?.name ?? '',
                      userName: user?.name ?? '',
                      onRecent: () => unawaited(showRecentSheet(context)),
                      onMenu: () => unawaited(showMenuSheet(context)),
                    ),
                    _BannerSlot(
                      notice: services.session.maintenanceNotice,
                      onDismissNotice: services.session.dismissMaintenance,
                      offline:
                          _offline &&
                          (variant == _Variant.nfcOff ||
                              variant == _Variant.noNfc),
                    ),
                    Expanded(
                      child: DelayedPresence(
                        active: lookingUp,
                        builder: (BuildContext context, bool skeleton) => _body(
                          context,
                          loop: loop,
                          variant: variant,
                          lookingUp: lookingUp,
                          skeleton: skeleton,
                          slow: state is LookingUpState && state.slow,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context, {
    required LoopController loop,
    required _Variant variant,
    required bool lookingUp,
    required bool skeleton,
    required bool slow,
  }) {
    final WaiterLayout layout = context.layout;
    final bool tablet = layout.widthClass.isTablet;
    // Focus target on return to S05: the instruction (03a §5.12).
    final Widget block = Focus(
      focusNode: _instructionFocus,
      child: AnimatedSwitcher(
        duration: Motion.durationFast,
        switchInCurve: Motion.easeStandard,
        switchOutCurve: Motion.easeStandard,
        child: KeyedSubtree(
          key: ValueKey<_Variant>(variant),
          child: _block(
            context,
            loop: loop,
            variant: variant,
            lookingUp: lookingUp,
          ),
        ),
      ),
    );
    final Widget actions = _Hideable(
      hidden: lookingUp,
      child: _actions(context, loop: loop, variant: variant, tablet: tablet),
    );
    final Widget cancel = AnimatedSwitcher(
      duration: Motion.durationFast,
      child: lookingUp && slow
          ? Focus(
              focusNode: _cancelFocus,
              child: TertiaryButton(
                label: _l10n.commonCancel,
                large: true,
                onPressed: loop.back,
              ),
            )
          : const SizedBox.shrink(),
    );
    final Widget lookup = _LookupView(slow: slow);

    if (tablet) {
      return AnimatedSwitcher(
        duration: Motion.durationFast,
        child: skeleton
            ? KeyedSubtree(
                key: const ValueKey<String>('lookup'),
                child: Column(
                  children: <Widget>[
                    Expanded(child: lookup),
                    cancel,
                    SizedBox(
                      height:
                          layout.viewPadding.bottom + layout.ctaBottomPadding,
                    ),
                  ],
                ),
              )
            : KeyedSubtree(
                key: const ValueKey<String>('ready'),
                child: _TabletColumn(block: block, actions: actions),
              ),
      );
    }

    final bool android =
        variant == _Variant.listening ||
        (variant == _Variant.offline && !loop.isIos);
    return Column(
      children: <Widget>[
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.durationFast,
            child: skeleton
                ? KeyedSubtree(
                    key: const ValueKey<String>('lookup'),
                    child: lookup,
                  )
                : KeyedSubtree(
                    key: const ValueKey<String>('ready'),
                    child: _CentredRegion(
                      flexAbove: android ? _androidFlexAbove : 1,
                      flexBelow: android ? _androidFlexBelow : 1,
                      child: block,
                    ),
                  ),
          ),
        ),
        if (android) const SizedBox(height: Space.s4),
        Padding(
          padding: EdgeInsets.fromLTRB(
            layout.margin,
            0,
            layout.margin,
            layout.viewPadding.bottom + layout.ctaBottomPadding,
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[actions, cancel],
          ),
        ),
      ],
    );
  }

  /// The instruction block: motif or plate, title, hint (03a §5.1, §5.2, V4–V6).
  Widget _block(
    BuildContext context, {
    required LoopController loop,
    required _Variant variant,
    required bool lookingUp,
  }) {
    final AppLocalizations l10n = _l10n;
    final WaiterColors c = context.colors;
    final ReadyNotice? notice = switch (loop.state) {
      ReadyState(:final ReadyNotice? notice) => notice,
      _ => null,
    };
    final double motif = _motifSize(context, ios: loop.isIos);

    switch (variant) {
      case _Variant.listening:
        final bool failed =
            notice == ReadyNotice.readFailed || notice == ReadyNotice.notCard;
        return _InstructionBlock(
          graphic: _NfcMotif(
            size: motif,
            state: lookingUp
                ? NfcScanState.success
                : failed
                ? NfcScanState.error
                : NfcScanState.listening,
          ),
          title: switch (notice) {
            _ when lookingUp => l10n.scanLookingUp,
            ReadyNotice.readFailed => l10n.scanReadFailedTitle,
            ReadyNotice.notCard => l10n.scanNotCard,
            _ => l10n.readyAndroidTitle,
          },
          titleWarning: !lookingUp && failed,
          hint: switch (notice) {
            _ when lookingUp => null,
            ReadyNotice.readFailed => _HintText(l10n.scanReadFailedBody),
            ReadyNotice.notCard => null,
            ReadyNotice.offlineRead => _HintText(
              l10n.readyOfflineTap,
              info: true,
            ),
            // V8: the first-card tip replaces the hint until the first
            // successful read of the business day.
            _ when loop.showFirstCardTip => _HintText(
              l10n.readyFirstCardTipAndroid,
              info: true,
            ),
            _ => _HintText(l10n.readyAndroidHint),
          },
        );
      case _Variant.iosReady:
        return _InstructionBlock(
          graphic: TickerMode(
            // 06 M27: the motif rests while Apple's sheet is up.
            enabled: loop.state is! ScanningState,
            child: _NfcMotif(size: motif, state: NfcScanState.idle),
          ),
          hint: notice == ReadyNotice.iosTimeout
              ? _HintText(l10n.readyIosTimeout)
              : loop.showFirstCardTip
              ? _HintText(l10n.readyFirstCardTipIos, info: true)
              : _HintText(l10n.readyIosHint),
        );
      case _Variant.nfcOff:
        return _InstructionBlock(
          graphic: _NfcMotif(size: motif, state: NfcScanState.disabled),
          title: l10n.nfcOffTitle,
          hint: _HintText(l10n.nfcOffBody),
        );
      case _Variant.noNfc:
        return _InstructionBlock(
          graphic: _QrPlate(size: _plateSize(context)),
          title: l10n.readyNoNfcTitle,
          hint: _HintText(l10n.readyNoNfcHint),
        );
      case _Variant.offline:
        return _InstructionBlock(
          graphic: _NfcMotif(
            size: motif,
            state: NfcScanState.disabled,
            glyph: WaiterIconView(WaiterIcon.wifiOff, color: c.fgTertiary),
          ),
          title: l10n.offlineTitle,
          hint: _HintText(
            notice == ReadyNotice.offlineRead
                ? l10n.readyOfflineTap
                : l10n.offlineBody,
          ),
        );
    }
  }

  /// The bottom action stack of each variant (03a §5.1, §5.2, V4–V6; 08 §5).
  Widget _actions(
    BuildContext context, {
    required LoopController loop,
    required _Variant variant,
    required bool tablet,
  }) {
    final AppLocalizations l10n = _l10n;
    final bool online = !_offline;
    final String? offlineReason = online ? null : l10n.offlineTitle;
    final Widget alternatives = _AlternativeInputs(
      onManual: online ? loop.openManual : null,
      onQr: online ? loop.openQr : null,
      disabledReason: offlineReason,
    );

    switch (variant) {
      case _Variant.listening:
        return alternatives;
      case _Variant.iosReady || _Variant.offline:
        if (!loop.isIos) return alternatives;
        return _Stacked(
          children: <Widget>[
            Focus(
              focusNode: _scanFocus,
              child: PrimaryButton(
                label: l10n.readyIosButton,
                icon: WaiterIcon.nfcArcs,
                // One session at a time (03a §5.9, §6.9).
                onPressed:
                    variant == _Variant.iosReady && loop.state is ReadyState
                    ? _scanCard
                    : null,
                disabledReason: offlineReason,
              ),
            ),
            alternatives,
          ],
        );
      case _Variant.nfcOff:
        return _Stacked(
          children: <Widget>[
            PrimaryButton(
              label: l10n.nfcOffAction,
              icon: WaiterIcon.settings,
              onPressed: _openNfcSettings,
            ),
            alternatives,
          ],
        );
      case _Variant.noNfc:
        final Widget qr = PrimaryButton(
          label: l10n.readyNoNfcButton,
          icon: WaiterIcon.scanQrCode,
          onPressed: online ? loop.openQr : null,
          disabledReason: offlineReason,
        );
        final Widget manual = SecondaryButton(
          label: l10n.readyManual,
          icon: WaiterIcon.keyboard,
          onPressed: online ? loop.openManual : null,
          disabledReason: offlineReason,
        );
        // 08 §5: on tablets the card-number button sits directly above the
        // primary; phones follow 03a V5 (primary first).
        return _Stacked(
          children: tablet ? <Widget>[manual, qr] : <Widget>[qr, manual],
        );
    }
  }

  double _motifSize(BuildContext context, {required bool ios}) {
    final WaiterLayout layout = context.layout;
    final double base = layout.widthClass.isTablet
        ? _motifTablet
        : layout.heightClass.isCompact
        ? (ios ? _motifIosCompact : _motifAndroidCompact)
        : (ios ? _motifIos : _motifAndroid);
    return _shrinkForText(context, base);
  }

  double _plateSize(BuildContext context) => _shrinkForText(context, _qrPlate);

  /// 03a §5.12: the decorative graphic shrinks first (to 120 pt at 200 %).
  static double _shrinkForText(BuildContext context, double base) {
    final double scale = MediaQuery.textScalerOf(context).scale(1);
    if (scale <= 1) return base;
    return lerpDouble(base, _motifMin, (scale - 1).clamp(0.0, 1.0))!;
  }
}

/// Maintenance (A12) and — over the hardware variants — offline banners
/// (03a §5.7 V7, 08 §3.1). They push the centred block down, never the
/// bottom-anchored actions.
class _BannerSlot extends StatelessWidget {
  const _BannerSlot({
    required this.notice,
    required this.onDismissNotice,
    required this.offline,
  });

  final String? notice;
  final VoidCallback onDismissNotice;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? text = notice;
    final WaiterLayout layout = context.layout;
    return AnimatedSize(
      duration: Motion.durationFast,
      curve: Motion.easeAccelerate,
      alignment: Alignment.topCenter,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: layout.widthClass.isTablet
                ? LayoutTokens.textMeasureTablet
                : double.infinity,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (offline)
                WaiterBanner(
                  tone: BannerTone.info,
                  icon: WaiterIcon.wifiOff,
                  title: l10n.offlineTitle,
                  body: l10n.offlineBody,
                ),
              if (text != null)
                WaiterBanner(
                  key: ValueKey<String>(text),
                  tone: BannerTone.warning,
                  icon: WaiterIcon.wrench,
                  title: text.trim().isEmpty ? l10n.maintenanceDefault : text,
                  maxLines: _maintenanceLines,
                  onDismiss: onDismissNotice,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertically centres [child] between the banner and the actions with the
/// given flex split; scrolls only as a last resort at large text (03a §5.12).
class _CentredRegion extends StatelessWidget {
  const _CentredRegion({
    required this.flexAbove,
    required this.flexBelow,
    required this.child,
  });

  final int flexAbove;
  final int flexBelow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double margin = context.layout.margin;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: margin),
                  child: Column(
                    children: <Widget>[
                      Spacer(flex: flexAbove),
                      child,
                      Spacer(flex: flexBelow),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

/// Tablets: one centred column, max 480 pt, buttons below the text block
/// (03a §5.13, 08 §3.1, §4.3).
class _TabletColumn extends StatelessWidget {
  const _TabletColumn({required this.block, required this.actions});

  final Widget block;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final WaiterLayout layout = context.layout;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          layout.margin,
          Space.s4,
          layout.margin,
          layout.viewPadding.bottom + layout.ctaBottomPadding,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: LayoutTokens.textMeasureTablet,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              block,
              const SizedBox(height: Space.s10),
              actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// Graphic, title (`type.title.l`) and hint (`type.body.m`) of S05.
class _InstructionBlock extends StatelessWidget {
  const _InstructionBlock({
    required this.graphic,
    this.title,
    this.titleWarning = false,
    this.hint,
  });

  final Widget graphic;
  final String? title;

  /// Read failed / not a card: warning glyph before the title (03a §6.7).
  final bool titleWarning;

  final Widget? hint;

  @override
  Widget build(BuildContext context) {
    final String? heading = title;
    final Widget? line = hint;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        graphic,
        const SizedBox(height: Space.s6),
        if (heading != null)
          _Crossfade(
            id: '$heading$titleWarning',
            child: Semantics(
              container: true,
              header: true,
              liveRegion: true,
              child: _Title(heading, warning: titleWarning),
            ),
          ),
        if (heading != null && line != null) const SizedBox(height: Space.s2),
        _Crossfade(
          id: line is _HintText ? line.text : '',
          child: line ?? const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, {required this.warning});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final Widget label = ScaledText(
      text,
      type: TypeTokens.titleL,
      textAlign: TextAlign.center,
    );
    if (!warning) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        WaiterIconView(WaiterIcon.triangleAlert, color: context.colors.warning),
        const SizedBox(width: Space.s2),
        Flexible(child: label),
      ],
    );
  }
}

/// Hint / tip line: `type.body.m` `fg.secondary`, or `color.info` with the
/// info glyph for the offline-read line (L09).
class _HintText extends StatelessWidget {
  const _HintText(this.text, {this.info = false});

  final String text;
  final bool info;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    final Widget label = ScaledText(
      text,
      type: TypeTokens.bodyM,
      color: info ? c.info : c.fgSecondary,
      textAlign: TextAlign.center,
    );
    if (!info) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        WaiterIconView(WaiterIcon.info, size: IconSize.s16, color: c.info),
        const SizedBox(width: Space.s2),
        Flexible(child: label),
      ],
    );
  }
}

/// `crossfade-state` for text swaps (03a §0.3, 06 M07).
class _Crossfade extends StatelessWidget {
  const _Crossfade({required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.durationFast,
    switchInCurve: Motion.easeStandard,
    switchOutCurve: Motion.easeStandard,
    child: KeyedSubtree(key: ValueKey<String>(id), child: child),
  );
}

/// NfcScanAnimation in a square slot of [size], emitter at the centre;
/// [glyph] replaces the emitter dot (offline).
class _NfcMotif extends StatelessWidget {
  const _NfcMotif({required this.size, required this.state, this.glyph});

  final double size;
  final NfcScanState state;
  final Widget? glyph;

  @override
  Widget build(BuildContext context) {
    final Widget? centre = glyph;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: FittedBox(
          child: SizedBox.square(
            dimension: _motifReference,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: <Widget>[
                Positioned(
                  top: _motifReference / 2 - NfcScanTokens.centerY,
                  child: NfcScanAnimation(state: state),
                ),
                if (centre != null)
                  Positioned(
                    top: (_motifReference - _glyphKnockout) / 2,
                    child: Container(
                      width: _glyphKnockout,
                      height: _glyphKnockout,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.colors.bgCanvas,
                        shape: BoxShape.circle,
                      ),
                      child: centre,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// V5 QR plate: `radius.xl`, `color.bg.key`, QR glyph 72 (03a §5.7).
class _QrPlate extends StatelessWidget {
  const _QrPlate({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final double glyph = _qrGlyph * size / _qrPlate;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.bgKey,
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
        child: WaiterIconView.mark(
          WaiterIcon.scanQrCode,
          dimension: glyph,
          strokeWidth: IconSize.s48.stroke * glyph / IconSize.s48.size,
        ),
      ),
    );
  }
}

/// "Card number" and "QR code" (03a §5.6): SecondaryButtons 56 side by side
/// with a 12-pt gap, stacked full width when a label no longer fits on one
/// line (03a §5.12).
class _AlternativeInputs extends StatelessWidget {
  const _AlternativeInputs({
    required this.onManual,
    required this.onQr,
    this.disabledReason,
  });

  final VoidCallback? onManual;
  final VoidCallback? onQr;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Widget manual = SecondaryButton(
      label: l10n.readyManual,
      icon: WaiterIcon.keyboard,
      onPressed: onManual,
      disabledReason: disabledReason,
    );
    final Widget qr = SecondaryButton(
      label: l10n.readyQr,
      icon: WaiterIcon.scanQrCode,
      onPressed: onQr,
      disabledReason: disabledReason,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double half =
            (constraints.maxWidth - ButtonTokens.sideBySideGap) / 2;
        final bool fits =
            _fitsOneLine(context, l10n.readyManual, half) &&
            _fitsOneLine(context, l10n.readyQr, half);
        if (!fits) {
          return _Stacked(
            gap: ButtonTokens.sideBySideGap,
            children: <Widget>[manual, qr],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: manual),
            const SizedBox(width: ButtonTokens.sideBySideGap),
            Expanded(child: qr),
          ],
        );
      },
    );
  }

  static bool _fitsOneLine(BuildContext context, String label, double width) {
    const TypeSpec type = TypeTokens.label;
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: label,
        style: context.textStyles.at(type, scaledFontSize(context, type)),
      ),
      textDirection: Directionality.of(context),
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
    final double needed =
        painter.width +
        IconSize.s20.size +
        ButtonTokens.regularIconGap +
        2 * ButtonTokens.regularPaddingHorizontal;
    painter.dispose();
    return needed <= width;
  }
}

/// A vertical button stack (default gap `space.4`, 03a §5.1).
class _Stacked extends StatelessWidget {
  const _Stacked({required this.children, this.gap = Space.s4});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (int i = 0; i < children.length; i++) ...<Widget>[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ],
  );
}

/// Hidden, not disabled (03a §6.4): invisible, inert and out of the
/// accessibility tree while keeping its layout.
class _Hideable extends StatelessWidget {
  const _Hideable({required this.hidden, required this.child});

  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: hidden,
    child: ExcludeSemantics(
      excluding: hidden,
      child: AnimatedOpacity(
        opacity: hidden ? 0 : 1,
        duration: Motion.durationFast,
        curve: Motion.easeStandard,
        child: child,
      ),
    ),
  );
}

/// S06 looking-up state on S05 (03a §6.4): the BalanceCard skeleton in the
/// exact S07 card slot, Spinner + `scan.lookingUp` / `scan.slow` below.
class _LookupView extends StatelessWidget {
  const _LookupView({required this.slow});

  final bool slow;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final ChargeCardSlot slot = ChargeCardSlot.of(context);
    final Widget card = SizedBox(
      width: slot.width,
      child: BalanceCard(
        data: null,
        money: context.money,
        density: slot.density,
        skeletonBrandColor:
            context.services.session.user?.restaurant?.settings.brandColor,
      ),
    );
    final Widget status = Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Spinner(color: c.fgTertiary),
          const SizedBox(width: Space.s2),
          Flexible(
            child: _Crossfade(
              id: slow ? 'slow' : 'looking',
              child: ScaledText(
                slow ? l10n.scanSlow : l10n.scanLookingUp,
                type: TypeTokens.bodyM,
                color: c.fgSecondary,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
    final Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        card,
        const SizedBox(height: Space.s6),
        status,
      ],
    );
    final double? start = slot.start;
    if (start != null) {
      return Padding(
        padding: EdgeInsetsDirectional.only(start: start),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(width: slot.width, child: column),
        ),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: slot.top,
        left: context.layout.margin,
        right: context.layout.margin,
      ),
      child: Center(child: column),
    );
  }
}
