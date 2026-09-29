import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:giftcard_waiter/app/app_scope.dart';
import 'package:giftcard_waiter/app/money.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/components/support/announce.dart';
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/platform/feedback_scope.dart';
import 'package:giftcard_waiter/core/state/loop_controller.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/storage/pending_redemptions.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';

import 'charge/card_region.dart';
import 'charge/charge_metrics.dart';
import 'charge/entrance.dart';
import 'charge/helper_line.dart';
import 'charge/support_code_line.dart';
import 'charge/uncertain_panel.dart';
import 'charge/voucher_data.dart';
import 'charge/voucher_state_banner.dart';

/// S07 Charge and its in-place S08 Redeeming states (03b §2–§3).
///
/// Renders the loop's [ChargeState]. All decisions —
/// guards, attempts, retries, feedback of the loop events — live in the
/// [LoopController]; this screen maps state to layout, plays the motion
/// and posts the screen-reader announcements of 07 §5.6.
class ChargeScreen extends StatefulWidget {
  /// Creates the screen.
  const ChargeScreen({super.key});

  @override
  State<ChargeScreen> createState() => _ChargeScreenState();
}

/// Which limit the typed amount exceeds (03b §2.11, §2.16).
enum _Limit { none, balance, max }

class _ChargeScreenState extends State<ChargeScreen> {
  LoopController? _loopOrNull;
  LoopController get _loop => _loopOrNull!;

  /// The state on screen. Kept while the page leaves so it animates out
  /// unchanged.
  ChargeState? _shown;
  bool _leaving = false;

  final GlobalKey _cardKey = GlobalKey(debugLabel: 'BalanceCard');
  final ShakeController _shake = ShakeController();
  double? _arrivalScale;

  /// The notice whose 4-s helper (balance changed, nothing booked) shows.
  ChargeNotice? _transient;
  Timer? _transientTimer;

  /// Keypad dims only when a submission is still running after 150 ms
  /// (06 M17).
  bool _dimLocked = false;
  Timer? _dimTimer;

  /// Rate/velocity countdown (03b §2.17).
  Timer? _ticker;
  bool _countdownRunning = false;

  /// 06 M08 arrival scale: the voucher rises from the QR scanner.
  static const double _arrival = 0.6;

  /// 03b §2.13 / §2.16: the 4-s helper after a definitive rejection.
  static const Duration _transientHelper = Duration(seconds: 4);

  /// 06 M08: the action region follows the card by 40 ms, rising 16 pt.
  static const Duration _actionDelay = Duration(milliseconds: 40);

  /// 06 M25 / 03b §2.14: the card-state banner follows the card.
  static const Duration _bannerDelay = Duration(milliseconds: 120);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loopOrNull != null) return;
    final LoopController loop = _loopOrNull = context.services.loop;
    loop.addListener(_onLoop);
    final LoopState state = loop.state;
    if (state is! ChargeState) return;
    _shown = state;
    // 06 M08: the voucher rises from the scanner.
    _arrivalScale = _arrival;
    _onCharge(null, state);
  }

  @override
  void dispose() {
    _loopOrNull?.removeListener(_onLoop);
    _transientTimer?.cancel();
    _dimTimer?.cancel();
    _ticker?.cancel();
    _shake.dispose();
    super.dispose();
  }

  ChargeState? get _charge => _shown;

  // ------------------------------------------------------------ state flow

  void _onLoop() {
    final LoopState next = _loop.state;
    if (next is! ChargeState) {
      _ticker?.cancel();
      if (!_leaving) setState(() => _leaving = true);
      return;
    }
    final ChargeState? previous = _shown;
    _onCharge(previous, next);
    setState(() {
      _shown = next;
      _leaving = false;
    });
  }

  /// Transitions of 03b §2–§3 that need a screen-level reaction.
  void _onCharge(ChargeState? before, ChargeState next) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MoneyContext money = context.moneyFor(next.voucher.currency);

    if (before == null || before.voucher.id != next.voucher.id) {
      _announceVoucher(next, l10n, money);
    }
    if (next.presentmentExpired && !(before?.presentmentExpired ?? false)) {
      _announceAfterFrame(l10n.chargePresentmentExpired, assertive: true);
    }
    if (!identical(before?.notice, next.notice)) {
      _onNotice(next, l10n, money);
    }
    if (before != null &&
        _limitOf(before) != _Limit.max &&
        _limitOf(next) == _Limit.max &&
        next.notice is! MaxSingleNotice) {
      // Client-side crossing of a known cap: as over balance (03b §2.16,
      // 11 E34) — the AmountDisplay plays it only for the balance.
      context.haptic(HapticToken.warning);
      _shake.shake();
      _announceAfterFrame(
        l10n.chargeMaxSingle(money.spoken(next.maxSingle!)),
        assertive: true,
      );
    }
    _onPhase(before, next, l10n, money);
    _syncCountdown(next);
  }

  void _announceVoucher(ChargeState s, AppLocalizations l10n, MoneyContext money) {
    final String loaded = l10n.a11yVoucherLoaded(
      s.voucher.restaurantName,
      money.spoken(s.voucher.balance),
    );
    if (s.phase == RedeemPhase.resolving) {
      _announceAfterFrame('$loaded ${l10n.chargePendingTitle}.');
      return;
    }
    if (s.condition != VoucherCondition.redeemable) {
      // The voucher-state banner announces itself assertively (03b §2.14).
      _announceAfterFrame(loaded);
      return;
    }
    _announceAfterFrame(loaded, assertive: true);
    if (s.fullOnly) _announceAfterFrame(l10n.chargeFullOnly);
  }

  void _onNotice(ChargeState s, AppLocalizations l10n, MoneyContext money) {
    final ChargeNotice? notice = s.notice;
    switch (notice) {
      case BalanceChangedNotice():
        // Announced with the over-balance crossing (AmountDisplay).
        _startTransient(notice);
      case NothingBookedNotice():
        _startTransient(notice);
        _announceAfterFrame(l10n.redeemNothingBooked);
      case FullOnlyNotice():
        _startTransient(notice);
        _announceAfterFrame(
          '${l10n.redeemNothingBooked} ${l10n.chargeFullOnly}',
        );
      case MaxSingleNotice(:final int max):
        _shake.shake();
        _announceAfterFrame(
          l10n.chargeMaxSingle(money.spoken(max)),
          assertive: true,
        );
      case DailyLimitNotice(:final int remaining):
        _shake.shake();
        _announceAfterFrame(l10n.chargeDailyLimit(money.spoken(remaining)), assertive: true);
      case EarlierBookedNotice(:final int amount):
        _startTransient(notice);
        _announceAfterFrame(l10n.chargeEarlierBooked(money.spoken(amount)), assertive: true);
      case ServerFaultNotice(:final String supportCode):
        _announceAfterFrame(
          '${l10n.problemServerTitle}. '
          '${l10n.commonSupportCodeA11y(SupportCode.spoken(supportCode))}',
        );
      case VelocityNotice() || RateLimitNotice() || null:
        // Banners announce themselves (05 §3.3).
        break;
    }
  }

  void _startTransient(ChargeNotice notice) {
    _transientTimer?.cancel();
    _transient = notice;
    _transientTimer = Timer(_transientHelper, () {
      if (mounted) setState(() => _transient = null);
    });
  }

  void _onPhase(
    ChargeState? before,
    ChargeState next,
    AppLocalizations l10n,
    MoneyContext money,
  ) {
    final RedeemPhase from = before?.phase ?? RedeemPhase.entering;
    final RedeemPhase to = next.phase;
    if (next.isLocked && !(before?.isLocked ?? false)) {
      _dimTimer?.cancel();
      _dimTimer = Timer(Times.feedbackDelay, () {
        if (mounted) setState(() => _dimLocked = true);
      });
    } else if (!next.isLocked) {
      _dimTimer?.cancel();
      _dimLocked = false;
    }
    if (from == to) {
      if (to == RedeemPhase.uncertainAuto &&
          before != null &&
          before.attempt != next.attempt &&
          next.attempt > 0) {
        _announceAfterFrame(l10n.uncertainRetrying(next.attempt));
      }
      return;
    }
    switch (to) {
      case RedeemPhase.submitting:
        _announceAfterFrame(
          l10n.chargeRedeeming(money.spoken(next.amount)),
          assertive: true,
        );
      case RedeemPhase.slow:
        _announceAfterFrame(
          l10n.a11yProblem(l10n.redeemSlow, l10n.uncertainBody),
        );
      case RedeemPhase.uncertainAuto:
        _announceAfterFrame(
          l10n.a11yProblem(l10n.uncertainTitle, l10n.uncertainBody),
          assertive: true,
        );
      case RedeemPhase.uncertainFinal:
        _announceAfterFrame(
          l10n.a11yProblem(l10n.uncertainTitle, l10n.uncertainFailedBody),
          assertive: true,
        );
      case RedeemPhase.entering || RedeemPhase.resolving:
        break;
    }
  }

  void _announceAfterFrame(String message, {bool assertive = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) announce(context, message, assertive: assertive);
    });
  }

  // ---------------------------------------------------- rate / velocity

  /// The end of the known wait of a rate or velocity notice.
  static Duration? _countdownEnd(ChargeNotice? notice) => switch (notice) {
    RateLimitNotice(:final Duration until) => until,
    VelocityNotice(:final Duration? until) => until,
    _ => null,
  };

  /// Ticks the countdown once a second (the banner does not re-announce
  /// the ticks, 03b §2.17); at 0 the banner goes and Redeem re-enables with
  /// `haptic.select` and `a11y.redeemAvailable`.
  void _syncCountdown(ChargeState s) {
    final Duration? end = _countdownEnd(s.notice);
    final bool running = end != null && _loop.now() < end;
    if (running && !_countdownRunning) {
      _countdownRunning = true;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else if (!running && _countdownRunning) {
      _countdownRunning = false;
      _ticker?.cancel();
      if (end != null) {
        context.haptic(HapticToken.select);
        _announceAfterFrame(AppLocalizations.of(context).a11yRedeemAvailable);
      }
    }
  }

  void _tick() {
    final ChargeState? s = _charge;
    if (!mounted || s == null) return;
    setState(() {});
    _syncCountdown(s);
  }

  // ----------------------------------------------------------------- input

  bool _editable(ChargeState s) =>
      !_leaving &&
      !s.isLocked &&
      !s.fullOnly &&
      s.condition == VoucherCondition.redeemable;

  /// Applies a key through the loop controller and hands the Keypad the
  /// outcome for its feedback (05 §2.1): the pure preview on the current
  /// entry is exactly what the controller applies.
  EntryOutcome _input(
    EntryChange<AmountEntry> Function(AmountEntry entry) preview,
    VoidCallback apply,
  ) {
    final ChargeState? s = _charge;
    if (s == null || !_editable(s)) return EntryOutcome.ignored;
    final EntryOutcome outcome = preview(s.entry).outcome;
    apply();
    if (outcome == EntryOutcome.rejectedAtLimit) _shake.nudge();
    return outcome;
  }

  EntryOutcome _digit(int digit) =>
      _input((AmountEntry e) => e.digit(digit), () => _loop.key(digit));

  EntryOutcome _doubleZero() =>
      _input((AmountEntry e) => e.doubleZero(), _loop.doubleZero);

  EntryOutcome _backspace() =>
      _input((AmountEntry e) => e.backspace(), _loop.backspace);

  EntryOutcome _clear() =>
      _input((AmountEntry e) => e.clear(), _loop.clearAmount);

  void _redeem() => unawaited(_loop.redeem());

  void _tryAgain() => unawaited(_loop.tryAgain());

  // ---------------------------------------------------------------- limits

  static _Limit _limitOf(ChargeState s) {
    final int? max = s.maxSingle;
    if (s.isOverMax && (max! < s.voucher.balance || !s.isOverBalance)) {
      return _Limit.max;
    }
    return s.isOverBalance ? _Limit.balance : _Limit.none;
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final ChargeState? shown = _shown;
    final Widget body = shown == null ? const SizedBox.shrink() : _ChargeBody(state: this, s: shown);
    return ColoredBox(
      color: context.colors.bgCanvas,
      child: IgnorePointer(ignoring: _leaving, child: body),
    );
  }
}

/// Places the S07 regions for the window (03b §2.3–2.4, §2.20; 08 §3.2,
/// §4.2): phones and tablet portrait in one column (tablets max 480 pt),
/// tablet landscape ≥ 856 pt in two panes. The offline banner sits under
/// the TopRow (06 M26).
///
/// With an [entry] block the fixed rows are anchored at the bottom and the
/// card takes what is left above them — a reversed scroll view lays the
/// fixed rows out first, so at extreme text sizes only the card scrolls
/// away (07 §6.1). Without one (card-state variants) the card leads, the
/// [trailing] banners follow and the action sits at the bottom.
class _ChargeFrame extends StatelessWidget {
  const _ChargeFrame({
    required this.topBar,
    required this.card,
    required this.action,
    this.entry,
    this.trailing = const <Widget>[],
    this.offlineBanner,
    this.cardGap,
    this.keypad = true,
  });

  /// Whether the keypad is on screen (card density, 08 §3.2).
  final bool keypad;

  final Widget topBar;

  /// Card → AmountDisplay; `space.6` for the full-only layout (03b §2.13),
  /// else the height-class gap of 03b §2.4.
  final double? cardGap;

  /// The BalanceCard for the density its slot chose.
  final CardSlotBuilder card;

  /// AmountDisplay block and keypad / panel; `null` for card-state
  /// variants.
  final Widget? entry;

  /// Content below the card of a card-state variant.
  final List<Widget> trailing;

  /// The button slot.
  final Widget action;

  final Widget? offlineBanner;

  @override
  Widget build(BuildContext context) {
    final WaiterLayout layout = context.layout;
    final ChargeMetrics metrics = ChargeMetrics.of(context);
    final Widget? entry = this.entry;
    final Widget bottom = SizedBox(
      height: metrics.bottomInset + metrics.bottomGap,
    );
    const ScrollPhysics physics = ClampingScrollPhysics();

    if (isTwoPane(layout)) {
      final double inner =
          layout.size.width -
          layout.viewPadding.left -
          layout.viewPadding.right -
          2 * layout.margin;
      final double left = (inner - twoPaneGutter - twoPaneRightWidth).clamp(
        twoPaneLeftMin,
        twoPaneLeftMax,
      );
      return Column(
        children: <Widget>[
          topBar,
          ?offlineBanner,
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: left,
                    child: CustomScrollView(
                      physics: physics,
                      slivers: <Widget>[
                        ChargeCardSliver(
                          card: card,
                          horizontalInset: 0,
                          topGap: metrics.topGap,
                          maxHeight: cardMaxHeight(layout, pane: true),
                          withKeypad: keypad && entry != null,
                          anchor: entry == null
                              ? CardAnchor.top
                              : CardAnchor.centre,
                          trailing: trailing,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: twoPaneGutter),
                  SizedBox(
                    width: twoPaneRightWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        ?entry,
                        SizedBox(height: metrics.rowGap),
                        action,
                        bottom,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final double columnWidth = layout.widthClass.isTablet
        ? math.min(layout.size.width, tabletColumnWidth + 2 * layout.margin)
        : layout.size.width;
    final EdgeInsets inset = EdgeInsets.symmetric(horizontal: layout.margin);
    final Widget column;
    if (entry == null) {
      column = Column(
        children: <Widget>[
          Expanded(
            child: CustomScrollView(
              physics: physics,
              slivers: <Widget>[
                ChargeCardSliver(
                  card: card,
                  horizontalInset: layout.margin,
                  topGap: metrics.topGap,
                  maxHeight: cardMaxHeight(layout, pane: false),
                  withKeypad: false,
                  anchor: CardAnchor.top,
                  trailing: trailing,
                ),
              ],
            ),
          ),
          SizedBox(height: metrics.rowGap),
          Padding(padding: inset, child: action),
          bottom,
        ],
      );
    } else {
      column = CustomScrollView(
        reverse: true,
        physics: physics,
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Column(
              children: <Widget>[
                SizedBox(height: cardGap ?? metrics.cardGap),
                Padding(padding: inset, child: entry),
                SizedBox(height: metrics.rowGap),
                Padding(padding: inset, child: action),
                bottom,
              ],
            ),
          ),
          ChargeCardSliver(
            card: card,
            horizontalInset: layout.margin,
            topGap: metrics.topGap,
            maxHeight: cardMaxHeight(layout, pane: false),
            withKeypad: keypad,
            anchor: CardAnchor.bottom,
          ),
        ],
      );
    }
    return Column(
      children: <Widget>[
        topBar,
        ?offlineBanner,
        Expanded(
          child: Center(
            child: SizedBox(width: columnWidth, child: column),
          ),
        ),
      ],
    );
  }
}

/// The offline Banner under the TopRow (06 M26, 12 R16).
Widget? _offlineBanner(LoopController loop, AppLocalizations l10n) =>
    loop.isOnline
    ? null
    : WaiterBanner(
        tone: BannerTone.info,
        icon: WaiterIcon.wifiOff,
        title: l10n.offlineTitle,
        body: l10n.offlineBody,
      );

class _ChargeBody extends StatelessWidget {
  const _ChargeBody({required this.state, required this.s});

  final _ChargeScreenState state;
  final ChargeState s;

  LoopController get _loop => state._loop;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MoneyContext money = context.moneyFor(s.voucher.currency);
    final ChargeMetrics metrics = ChargeMetrics.of(context);
    final BalanceCardData data = balanceCardDataOf(context, s.voucher);
    final bool redeemable = s.condition == VoucherCondition.redeemable;

    Widget card(
      BuildContext context,
      BalanceCardDensity density,
      double maxHeight,
    ) => BalanceCard(
      key: state._cardKey,
      data: data,
      money: money,
      density: density,
      maxHeight: maxHeight,
      skeletonBrandColor: data.brandColor,
      arrivalScale: state._arrivalScale,
      onContrastFallback: () => logContrastFallback(context),
    );

    final Widget topBar = TopBar.task(
      // Dimmed while money may be moving (03b §1.4, §3.2); an unresolved
      // earlier attempt can be left, it stays stored.
      onClose: s.isLocked && s.phase != RedeemPhase.resolving ? null : _loop.closeCharge,
      closeLabel: l10n.a11yChargeClose,
      voucherNumber: s.voucher.voucherNumber,
    );

    final Widget? offline = _offlineBanner(_loop, l10n);

    if (s.phase == RedeemPhase.resolving) {
      final PendingRedemption? pending = s.pending;
      final String? code = s.supportCode;
      return _ChargeFrame(
        topBar: topBar,
        offlineBanner: offline,
        card: card,
        trailing: <Widget>[
          const SizedBox(height: Space.s6),
          Entrance(
            delay: _ChargeScreenState._bannerDelay,
            rise: Space.s2,
            child: StatusBanner(
              tone: BannerTone.warning,
              icon: WaiterIcon.clock,
              title: l10n.chargePendingTitle,
              body: l10n.chargePendingBody(money.format(pending?.amount ?? 0)),
            ),
          ),
          if (code != null) ...<Widget>[
            const SizedBox(height: Space.s4),
            SupportCodeLine(code: code, requestId: s.requestId ?? ''),
          ],
        ],
        action: PrimaryButton(
          label: l10n.commonCheckAgain,
          loadingLabel: l10n.uncertainBody,
          status: s.checking ? ButtonStatus.loading : ButtonStatus.idle,
          onPressed: s.checking || !_loop.isOnline ? null : _loop.checkPending,
          disabledReason: _loop.isOnline ? null : l10n.offlineBody,
        ),
      );
    }

    if (!redeemable) {
      final bool nothingBooked =
          s.notice is NothingBookedNotice &&
          identical(state._transient, s.notice);
      return _ChargeFrame(
        topBar: topBar,
        offlineBanner: offline,
        card: card,
        trailing: <Widget>[
          const SizedBox(height: Space.s6),
          AnimatedSize(
            duration: Motion.durationBase,
            curve: Motion.easeStandard,
            child: nothingBooked
                ? Padding(
                    padding: const EdgeInsets.only(bottom: Space.s2),
                    child: ChargeHelperLine(
                      message: HelperMessage(
                        l10n.redeemNothingBooked,
                        HelperTone.info,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Entrance(
            key: ValueKey<VoucherCondition>(s.condition),
            delay: _ChargeScreenState._bannerDelay,
            rise: Space.s2,
            child: voucherStateBanner(
              l10n: l10n,
              condition: s.condition,
              voucher: s.voucher,
              expiry: data.expiresAt,
              money: money,
            ),
          ),
        ],
        action: PrimaryButton(
          label: l10n.commonDone,
          onPressed: _loop.closeCharge,
        ),
      );
    }

    final Widget entry = Entrance(
      delay: _ChargeScreenState._actionDelay,
      child: _EntryBlock(state: state, s: s, money: money, metrics: metrics),
    );
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Return activates the PrimaryButton, never a HoldButton (05 §2.1).
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (s.presentmentExpired) {
            _loop.rescan();
          } else if (s.amount < LoopController.holdThreshold && _loop.canRedeem(s)) {
            state._redeem();
          }
        },
      },
      child: _ChargeFrame(
        topBar: topBar,
        offlineBanner: offline,
        card: card,
        cardGap: s.fullOnly ? Space.s6 : null,
        keypad: !s.fullOnly,
        entry: entry,
        action: Entrance(
          delay: _ChargeScreenState._actionDelay,
          child: _ActionSlot(state: state, s: s, money: money),
        ),
      ),
    );
  }
}

/// AmountDisplay, helper line, assist row and keypad — or the uncertain
/// panel in their place (03b §2.3–2.4, §3.4).
class _EntryBlock extends StatelessWidget {
  const _EntryBlock({
    required this.state,
    required this.s,
    required this.money,
    required this.metrics,
  });

  final _ChargeScreenState state;
  final ChargeState s;
  final MoneyContext money;
  final ChargeMetrics metrics;

  /// The chip's 56-pt target reaches 8 pt below its 40-pt row (05 §2.3).
  static const double _chipOverhang =
      (ChipTokens.target - ChipTokens.height) / 2;

  AmountDisplayState get _displayState {
    if (s.phase != RedeemPhase.entering) return AmountDisplayState.locked;
    if (s.fullOnly) return AmountDisplayState.fixed;
    return switch (_ChargeScreenState._limitOf(s)) {
      _Limit.balance => AmountDisplayState.overBalance,
      _Limit.max => AmountDisplayState.overLimit,
      _Limit.none => AmountDisplayState.entering,
    };
  }

  HelperMessage? _helper(AppLocalizations l10n) {
    if (s.phase == RedeemPhase.slow) {
      return HelperMessage(l10n.uncertainBody, HelperTone.info);
    }
    final ChargeNotice? notice = s.notice;
    final bool transient = identical(state._transient, notice);
    if (s.presentmentExpired && s.phase == RedeemPhase.entering) {
      return HelperMessage(
        notice is NothingBookedNotice
            ? '${l10n.redeemNothingBooked} ${l10n.chargePresentmentExpired}'
            : l10n.chargePresentmentExpired,
        HelperTone.info,
      );
    }
    if (notice is EarlierBookedNotice && transient) {
      return HelperMessage(l10n.chargeEarlierBooked(money.format(notice.amount)), HelperTone.info);
    }
    if (notice is BalanceChangedNotice && transient) {
      return HelperMessage(
        l10n.redeemBalanceChanged(money.format(notice.balance)),
        HelperTone.danger,
      );
    }
    if (s.fullOnly) {
      return HelperMessage(
        notice is FullOnlyNotice && transient
            ? l10n.redeemNothingBooked
            : l10n.chargeFullOnly,
        HelperTone.info,
      );
    }
    switch (_ChargeScreenState._limitOf(s)) {
      case _Limit.max:
        return HelperMessage(
          l10n.chargeMaxSingle(money.format(s.maxSingle!)),
          HelperTone.danger,
        );
      case _Limit.balance:
        return HelperMessage(
          l10n.chargeOverBalance(money.format(s.amount - s.voucher.balance)),
          HelperTone.danger,
        );
      case _Limit.none:
        break;
    }
    return switch (notice) {
      DailyLimitNotice(:final int remaining) => HelperMessage(
        l10n.chargeDailyLimit(money.format(remaining)),
        HelperTone.danger,
      ),
      ServerFaultNotice() => HelperMessage(
        l10n.problemServerTitle,
        HelperTone.info,
      ),
      _ => null,
    };
  }

  /// A warning banner in the helper + assist rows (03b §2.17, §3.5 R05).
  Widget? _banner(AppLocalizations l10n) {
    final ChargeNotice? notice = s.notice;
    final Duration now = state._loop.now();
    switch (notice) {
      case VelocityNotice(:final Duration? until):
        if (until != null && now >= until) return null;
        return StatusBanner(
          tone: BannerTone.warning,
          icon: WaiterIcon.clock,
          // The countdown ticks silently (03b §2.17).
          announceTextChanges: false,
          title: l10n.chargeVelocityTitle,
          body: until == null
              ? l10n.getManager
              : l10n.chargeVelocityBodyTime(
                  DateTimeFormat.ceilMinutes(until - now),
                ),
        );
      case RateLimitNotice(:final Duration until):
        if (now >= until) return null;
        return StatusBanner(
          tone: BannerTone.warning,
          icon: WaiterIcon.clock,
          // The countdown ticks silently (03b §2.17).
          announceTextChanges: false,
          title: l10n.chargeRateLimited(
            DateTimeFormat.ceilSeconds(until - now),
          ),
        );
      default:
        return null;
    }
  }

  Widget? _assist() {
    final ChargeNotice? notice = s.notice;
    if (s.phase == RedeemPhase.entering && notice is ServerFaultNotice && notice.supportCode.isNotEmpty) {
      return SupportCodeLine(
        code: notice.supportCode,
        requestId: notice.requestId,
      );
    }
    if (s.phase != RedeemPhase.entering || s.fullOnly) return null;
    return switch (_ChargeScreenState._limitOf(s)) {
      _Limit.balance => QuickAmountChip(
        key: const ValueKey<QuickAmount>(QuickAmount.balance),
        cents: s.voucher.balance,
        money: money,
        onPressed: () => state._loop.useAmount(s.voucher.balance),
      ),
      _Limit.max => QuickAmountChip(
        key: const ValueKey<QuickAmount>(QuickAmount.maximum),
        cents: s.maxSingle!,
        money: money,
        kind: QuickAmount.maximum,
        onPressed: () => state._loop.useAmount(s.maxSingle!),
      ),
      _Limit.none => null,
    };
  }

  bool get _balanceChanged {
    final ChargeNotice? notice = s.notice;
    return notice is BalanceChangedNotice &&
        identical(state._transient, notice);
  }

  String _overBalanceAnnouncement(AppLocalizations l10n) {
    final String over = l10n.a11yOverBalance(
      money.spoken(math.max(0, s.amount - s.voucher.balance)),
    );
    final ChargeNotice? notice = s.notice;
    if (notice is BalanceChangedNotice && identical(state._transient, notice)) {
      return '${l10n.redeemBalanceChanged(money.spoken(notice.balance))}. $over';
    }
    return over;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double keypadHeight =
        4 * Keypad.keyHeightFor(context) + 3 * KeypadTokens.gap;
    final Widget amount = SizedBox(
      height: metrics.amountLine,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: AmountDisplay(
          digits: s.entry.digits,
          money: money,
          state: _displayState,
          overBalanceAnnouncement: _overBalanceAnnouncement(l10n),
          // 03b §3.8: the balance changed, not the amount — the controller
          // plays haptic.error and the display does not shake.
          overBalanceEntryFeedback: !_balanceChanged,
          shakeController: state._shake,
        ),
      ),
    );

    final Widget below;
    if (s.isUncertain) {
      // Same area as helper + assist row + keypad (03b §3.4); with the
      // full-only layout it takes that height from the card region.
      below = SizedBox(
        height: metrics.messageArea + metrics.rowGap + keypadHeight,
        child: UncertainPanel(
          finalState: s.phase == RedeemPhase.uncertainFinal,
          attempt: s.attempt,
          supportCode: s.supportCode,
          requestId: s.requestId,
        ),
      );
    } else {
      below = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _messageArea(l10n),
          if (!s.fullOnly) ...<Widget>[
            SizedBox(height: metrics.rowGap - _chipOverhang),
            IgnorePointer(
              ignoring: s.isLocked,
              child: Keypad(
                enabled: !(s.isLocked && state._dimLocked),
                autofocus: true,
                onDigit: state._digit,
                onDoubleZero: state._doubleZero,
                onBackspace: state._backspace,
                onClear: state._clear,
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        amount,
        AnimatedSwitcher(
          duration: Motion.durationBase,
          reverseDuration: Motion.durationFast,
          switchInCurve: Motion.easeDecelerate,
          switchOutCurve: Motion.easeStandard,
          transitionBuilder: (Widget child, Animation<double> animation) =>
              FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: _panelEnterScale,
                    end: 1,
                  ).animate(animation),
                  child: child,
                ),
              ),
          child: KeyedSubtree(key: ValueKey<bool>(s.isUncertain), child: below),
        ),
      ],
    );
  }

  /// 03b §3.4: the uncertain panel scales 0.98 → 1.
  static const double _panelEnterScale = 0.98;

  Widget _messageArea(AppLocalizations l10n) {
    final Widget? banner = _banner(l10n);
    if (banner != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: metrics.messageArea + _chipOverhang,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: _chipOverhang),
            child: banner,
          ),
        ),
      );
    }
    final Widget? assist = _assist();
    return SizedBox(
      height: metrics.messageArea + _chipOverhang,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: metrics.helperLine,
            child: ChargeHelperLine(message: _helper(l10n)),
          ),
          Positioned(
            top: metrics.helperLine + metrics.helperGap - _chipOverhang,
            left: 0,
            right: 0,
            height: ChipTokens.target,
            child: Center(
              child: AnimatedSwitcher(
                duration: Motion.durationFast,
                reverseDuration: Motion.durationInstant,
                child: assist ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The button slot: Redeem (PrimaryButton < € 100, HoldButton ≥ € 100),
/// empty while retrying, "Cancel" / "Check again" in the final uncertain
/// state, "Scan again" once the presentment ran out (03b §2.10–2.18, §3).
class _ActionSlot extends StatelessWidget {
  const _ActionSlot({
    required this.state,
    required this.s,
    required this.money,
  });

  final _ChargeScreenState state;
  final ChargeState s;
  final MoneyContext money;

  LoopController get _loop => state._loop;

  String? _disabledReason(AppLocalizations l10n) {
    if (!_loop.isOnline) return l10n.offlineBody;
    return switch (_ChargeScreenState._limitOf(s)) {
      _Limit.balance => l10n.chargeOverBalance(
        money.spoken(s.amount - s.voucher.balance),
      ),
      _Limit.max => l10n.chargeMaxSingle(money.spoken(s.maxSingle!)),
      _Limit.none => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double height = context.layout.largeButtonHeight;

    switch (s.phase) {
      case RedeemPhase.uncertainAuto:
        return SizedBox(height: height);
      case RedeemPhase.uncertainFinal:
        return Entrance(
          duration: Motion.durationFast,
          rise: 0,
          child: Row(
            children: <Widget>[
              Expanded(
                child: SecondaryButton(
                  label: l10n.commonCancel,
                  onPressed: _loop.cancelUncertain,
                ),
              ),
              const SizedBox(width: ButtonTokens.stackGap),
              Expanded(
                child: PrimaryButton(
                  label: l10n.commonCheckAgain,
                  size: ButtonSize.regular,
                  onPressed: state._tryAgain,
                ),
              ),
            ],
          ),
        );
      case RedeemPhase.entering || RedeemPhase.submitting || RedeemPhase.slow || RedeemPhase.resolving:
        break;
    }

    if (s.presentmentExpired && s.phase == RedeemPhase.entering) {
      return PrimaryButton(
        key: const ValueKey<String>('rescan'),
        label: l10n.commonScanAgain,
        icon: WaiterIcon.scanQrCode,
        onPressed: _loop.rescan,
      );
    }

    final bool busy = s.isLocked;
    final bool can = _loop.canRedeem(s);
    final bool hold = s.amount >= LoopController.holdThreshold;
    final String visible = money.format(s.amount);
    final String spoken = money.spoken(s.amount);
    final VoidCallback? action = busy || can ? state._redeem : null;

    final Widget button;
    if (s.amount == 0) {
      button = PrimaryButton(
        key: const ValueKey<String>('enter'),
        label: l10n.chargeEnterAmount,
        onPressed: null,
      );
    } else if (hold) {
      button = HoldButton(
        key: const ValueKey<String>('hold'),
        label: s.fullOnly
            ? l10n.chargeRedeemFull(visible)
            : l10n.chargeRedeem(visible),
        semanticLabel: _spokenLabel(l10n, spoken),
        redeemingCaption: l10n.chargeRedeeming(visible),
        onCommit: action,
        status: switch (s.phase) {
          RedeemPhase.submitting => HoldButtonStatus.redeeming,
          RedeemPhase.slow => HoldButtonStatus.slow,
          _ => HoldButtonStatus.idle,
        },
        disabledReason: _disabledReason(l10n),
      );
    } else {
      button = PrimaryButton(
        key: const ValueKey<String>('tap'),
        label: s.fullOnly
            ? l10n.chargeRedeemFull(visible)
            : l10n.chargeRedeem(visible),
        semanticLabel: busy
            ? l10n.chargeRedeeming(spoken)
            : _spokenLabel(l10n, spoken),
        loadingLabel: l10n.chargeRedeeming(visible),
        onPressed: action,
        status: switch (s.phase) {
          RedeemPhase.submitting => ButtonStatus.loading,
          RedeemPhase.slow => ButtonStatus.slow,
          _ => ButtonStatus.idle,
        },
        disabledReason: _disabledReason(l10n),
      );
    }

    return Listener(
      // Warms up the success haptic on touch-down (09 §7.8, 11 §4.1).
      onPointerDown: (_) {
        if (can) _loop.prepareRedeem();
      },
      child: AnimatedSwitcher(
        duration: Motion.durationFast,
        switchInCurve: Motion.easeStandard,
        switchOutCurve: Motion.easeStandard,
        child: button,
      ),
    );
  }

  String _spokenLabel(AppLocalizations l10n, String spoken) =>
      (s.fullOnly ? l10n.chargeRedeemFull(spoken) : l10n.chargeRedeem(spoken))
          .replaceFirst(labelAmountSeparator, ', ');
}
