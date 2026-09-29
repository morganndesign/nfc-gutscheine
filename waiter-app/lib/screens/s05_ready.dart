import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../app/money.dart';
import '../components/components.dart';
import '../components/support/announce.dart';
import '../core/api/models.dart';
import '../core/platform/nfc_relay.dart';
import '../core/state/loop_controller.dart';
import '../core/state/loop_state.dart';
import '../core/storage/pending_redemptions.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'card_texts.dart';
import 's13_recent.dart';
import 's14_menu.dart';
import 's20_sell_voucher.dart';
import 'scan/focus_helpers.dart';

/// `ready.online` stays 2 s.
const Duration _onlineSnackbar = Duration(seconds: 2);

/// The maintenance notice shows at most 2 lines.
const int _maintenanceLines = 2;

/// Offline is entered after this much confirmed loss.
const Duration _offlineAfter = Duration(seconds: 2);

/// QR plate: 160 pt, glyph 72; 200 pt on tablets.
const double _qrPlate = 160;
const double _qrPlateTablet = 200;
const double _qrGlyph = 72;

/// Smallest decorative size at large text.
const double _plateMin = 120;

/// S05 · Ready (Home): scan a voucher's QR, sell a voucher (managers and
/// owners), and the state of earlier unconfirmed redemptions. Identical on
/// Android and iPhone.
///
/// Renders from [LoopController] and the session; only presentation timers
/// live here: the 2-s offline confirmation and focus/announcement bookkeeping.
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
  bool _offline = false;
  Timer? _offlineTimer;

  /// Cards are offered only on phones that can read them (NFC switched off still shows the button: S10 says how
  /// to switch it on).
  bool _cardReader = false;

  final FocusNode _scanFocus = FocusNode(debugLabel: 'S05 scan voucher', skipTraversal: true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services = context.services;
    if (_loop == null) {
      final LoopController loop = _services.loop;
      _loop = loop;
      _state = Listenable.merge(<Listenable>[loop, _services.session, _services.pending]);
      _previous = loop.state;
      loop.addListener(_onLoop);
      _syncConnectivity(loop);
      unawaited(
        loop.cardReaderAvailability().then((NfcAvailability availability) {
          if (mounted) setState(() => _cardReader = availability != NfcAvailability.unsupported);
        }),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showOutcomes();
      });
    }
  }

  @override
  void dispose() {
    _loop?.removeListener(_onLoop);
    _offlineTimer?.cancel();
    _scanFocus.dispose();
    super.dispose();
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  void _onLoop() {
    final LoopController loop = _loop!;
    final LoopState state = loop.state;
    final LoopState previous = _previous;
    _previous = state;
    _syncConnectivity(loop);
    if (state is ReadyState) _showOutcomes();
    if (state is ReadyState && (previous is ChargeState || previous is SuccessState || previous is ProblemState)) {
      // Back on S05 the scan button takes focus.
      announce(context, _l10n.a11yReady);
      focusFirstIn(_scanFocus);
    }
  }

  /// Snackbars for "Cancel" in the uncertain state and for earlier attempts
  /// whose outcome became known.
  void _showOutcomes() {
    final LoopController loop = _loop!;
    final SnackbarController? host = SnackbarHost.maybeOf(context);
    if (host == null) return;
    if (loop.takeUncertainCancelled()) {
      host.show(SnackbarData(message: _l10n.uncertainCancelled));
    }
    for (final PendingResolution r in loop.takeResolutions()) {
      final String amount = context.moneyFor(r.currency).format(r.amount);
      host.show(SnackbarData(message: r.booked ? _l10n.readyPendingBooked(amount) : _l10n.readyPendingNotBooked(amount)));
    }
  }

  /// Offline after 2 s of confirmed loss; back online at once with the
  /// `ready.online` snackbar.
  void _syncConnectivity(LoopController loop) {
    if (loop.isOnline) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      if (_offline) {
        setState(() => _offline = false);
        SnackbarHost.maybeOf(context)?.show(SnackbarData(message: _l10n.readyOnline, duration: _onlineSnackbar));
      }
      return;
    }
    if (_offline || _offlineTimer != null) return;
    _offlineTimer = Timer(_offlineAfter, () {
      _offlineTimer = null;
      if (!mounted || _loop!.isOnline) return;
      setState(() => _offline = true);
      announce(context, _l10n.a11yProblem(_l10n.offlineTitle, _l10n.offlineBody));
    });
  }

  void _scan() {
    if (!_offline) _loop!.openQr();
  }

  void _tapCard() {
    if (!_offline) _loop!.openCardTap(texts: cardTexts(_l10n));
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = _services;
    return ListenableBuilder(
      listenable: _state,
      builder: (BuildContext context, _) {
        final LoopController loop = services.loop;
        final SessionUser? user = services.session.user;
        final List<PendingRedemption> pending = loop.pendingRedemptions;
        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.enter): _scan,
            const SingleActivator(LogicalKeyboardKey.numpadEnter): _scan,
          },
          child: Focus(
            autofocus: true,
            skipTraversal: true,
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
                    pending: pending.isEmpty ? null : pending.first,
                  ),
                  Expanded(child: _body(context, user)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, SessionUser? user) {
    final WaiterLayout layout = context.layout;
    final AppLocalizations l10n = _l10n;
    final String? offlineReason = _offline ? l10n.offlineTitle : null;
    final Widget block = _InstructionBlock(
      plate: _plateSize(context),
      title: _offline ? l10n.offlineTitle : l10n.readyTitle,
      hint: _offline ? l10n.offlineBody : l10n.readyHint,
      offline: _offline,
    );
    final Widget actions = _Stacked(
      children: <Widget>[
        Focus(
          focusNode: _scanFocus,
          child: PrimaryButton(
            label: l10n.readyScan,
            icon: WaiterIcon.scanQrCode,
            onPressed: _offline ? null : _scan,
            disabledReason: offlineReason,
          ),
        ),
        if (_cardReader)
          SecondaryButton(
            label: l10n.readyTapCard,
            icon: WaiterIcon.nfcArcs,
            onPressed: _offline ? null : _tapCard,
            disabledReason: offlineReason,
          ),
        // S20: shown to managers and owners; the server checks every sale.
        if (user?.canSell ?? false)
          SecondaryButton(
            label: l10n.readySell,
            icon: WaiterIcon.ticket,
            onPressed: _offline ? null : () => unawaited(openSellVoucher(context)),
            disabledReason: offlineReason,
          ),
      ],
    );

    if (layout.widthClass.isTablet) return _TabletColumn(block: block, actions: actions);

    return Column(
      children: <Widget>[
        Expanded(child: _CentredRegion(child: block)),
        Padding(
          padding: EdgeInsets.fromLTRB(
            layout.margin,
            Space.s4,
            layout.margin,
            layout.viewPadding.bottom + layout.ctaBottomPadding,
          ),
          child: actions,
        ),
      ],
    );
  }

  /// The decorative plate shrinks first at large text (to 120 pt at 200 %).
  static double _plateSize(BuildContext context) {
    final double base = context.layout.widthClass.isTablet ? _qrPlateTablet : _qrPlate;
    final double scale = MediaQuery.textScalerOf(context).scale(1);
    if (scale <= 1) return base;
    return lerpDouble(base, _plateMin, (scale - 1).clamp(0.0, 1.0))!;
  }
}

/// Maintenance notice and unconfirmed redemptions. They push the centred
/// block down, never the bottom-anchored actions.
class _BannerSlot extends StatelessWidget {
  const _BannerSlot({required this.notice, required this.onDismissNotice, required this.pending});

  final String? notice;
  final VoidCallback onDismissNotice;

  /// The oldest unresolved attempt, if any.
  final PendingRedemption? pending;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? text = notice;
    final PendingRedemption? open = pending;
    final WaiterLayout layout = context.layout;
    return AnimatedSize(
      duration: Motion.durationFast,
      curve: Motion.easeAccelerate,
      alignment: Alignment.topCenter,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: layout.widthClass.isTablet ? LayoutTokens.textMeasureTablet : double.infinity,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (open != null)
                WaiterBanner(
                  key: ValueKey<String>(open.key),
                  tone: BannerTone.warning,
                  icon: WaiterIcon.clock,
                  title: l10n.readyPendingTitle,
                  body: l10n.readyPendingBody(context.moneyFor(open.currency).format(open.amount), open.last4),
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

/// Vertically centres [child] between the banners and the actions; scrolls
/// only as a last resort at large text.
class _CentredRegion extends StatelessWidget {
  const _CentredRegion({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double margin = context.layout.margin;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// Tablets: one centred column, max 480 pt, buttons below the text block.
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
          constraints: const BoxConstraints(maxWidth: LayoutTokens.textMeasureTablet),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[block, const SizedBox(height: Space.s10), actions],
          ),
        ),
      ),
    );
  }
}

/// QR plate, title (`type.title.l`) and hint (`type.body.m`).
class _InstructionBlock extends StatelessWidget {
  const _InstructionBlock({required this.plate, required this.title, required this.hint, required this.offline});

  final double plate;
  final String title;
  final String hint;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _QrPlate(size: plate, offline: offline),
        const SizedBox(height: Space.s6),
        _Crossfade(
          id: title,
          child: Semantics(
            container: true,
            header: true,
            liveRegion: true,
            child: ScaledText(title, type: TypeTokens.titleL, textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: Space.s2),
        _Crossfade(
          id: hint,
          child: ScaledText(hint, type: TypeTokens.bodyM, color: c.fgSecondary, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

/// `crossfade-state` for text swaps.
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

/// QR plate: `radius.xl`, `color.bg.key`, QR glyph (Wi-Fi-off glyph offline).
class _QrPlate extends StatelessWidget {
  const _QrPlate({required this.size, required this.offline});

  final double size;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final double glyph = _qrGlyph * size / _qrPlate;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: context.colors.bgKey, borderRadius: BorderRadius.circular(Radii.xl)),
        child: offline
            ? WaiterIconView(WaiterIcon.wifiOff, size: IconSize.s48, color: context.colors.fgTertiary)
            : WaiterIconView.mark(
                WaiterIcon.scanQrCode,
                dimension: glyph,
                strokeWidth: IconSize.s48.stroke * glyph / IconSize.s48.size,
              ),
      ),
    );
  }
}

/// A vertical button stack (gap `space.4`).
class _Stacked extends StatelessWidget {
  const _Stacked({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (int i = 0; i < children.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(height: Space.s4),
        children[i],
      ],
    ],
  );
}
