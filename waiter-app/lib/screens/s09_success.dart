import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:giftcard_waiter/app/app_scope.dart';
import 'package:giftcard_waiter/app/money.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/components/support/announce.dart';
import 'package:giftcard_waiter/core/api/models.dart';
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/state/loop_controller.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/storage/recent_store.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';

import 'card_texts.dart';
import 'charge/entrance.dart';
import 'charge/money_text.dart';

/// S09 Success and its "Show guest" presentation mode (03b §4).
///
/// Amounts are the server's (`transaction.amount`, `balance_after`,
/// AC-S09-7). The loop controller plays `haptic.success` + `sound.success`
/// at the response and returns to Ready after 4 s unless the guest view is
/// open; this screen draws the mark (M18), the countdown (M19), announces
/// the result and offers the next step: "Scan next voucher" and "Show
/// guest", the same on Android and iPhone. A tap anywhere outside the
/// buttons returns to Ready at once.
class SuccessScreen extends StatefulWidget {
  /// Creates the screen.
  const SuccessScreen({super.key});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  LoopController? _loopOrNull;
  LoopController get _loop => _loopOrNull!;

  /// The success on screen; kept while the page leaves.
  SuccessState? _shown;
  bool _leaving = false;
  Timer? _guestTimer;

  /// 03b §4.8: the guest view closes by itself after 20 s (AC-S09-11).
  static const Duration _guestReturn = Duration(seconds: 20);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loopOrNull != null) return;
    final LoopController loop = _loopOrNull = context.services.loop;
    loop.addListener(_onLoop);
    final LoopState state = loop.state;
    if (state is! SuccessState) return;
    _shown = state;
    // 03b §4.4: with a screen reader the return waits 10.52 s.
    if (MediaQuery.accessibleNavigationOf(context)) {
      loop.extendSuccessForScreenReader();
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MoneyContext money = context.moneyFor(state.entry.currency);
    final String message = _spokenResult(l10n, money, state.entry);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) announce(context, message, assertive: true);
    });
  }

  @override
  void dispose() {
    _loopOrNull?.removeListener(_onLoop);
    _guestTimer?.cancel();
    super.dispose();
  }

  void _onLoop() {
    final LoopState next = _loop.state;
    if (next is! SuccessState) {
      _guestTimer?.cancel();
      if (!_leaving) setState(() => _leaving = true);
      return;
    }
    if (next.presenting && !(_shown?.presenting ?? false)) {
      _guestTimer?.cancel();
      _guestTimer = Timer(_guestReturn, _loop.finishSuccess);
    }
    setState(() {
      _shown = next;
      _leaving = false;
    });
  }

  /// "Redeemed 24 euro 90, remaining balance 8 euro 60" — or "… Voucher is
  /// now empty." for a full redemption (03b §4.4–4.5, 12 §5.11).
  static String _spokenResult(
    AppLocalizations l10n,
    MoneyContext money,
    RecentEntry entry,
  ) {
    if (entry.balanceAfter == 0) {
      return '${l10n.successTitle} ${money.spoken(entry.amount)}. '
          '${l10n.successEmpty}.';
    }
    return l10n.a11ySuccess(
      money.spoken(entry.amount),
      money.spoken(entry.balanceAfter),
    );
  }

  void _finish() => _loop.finishSuccess();

  /// Straight to the QR scanner for the next voucher.
  /// A card voucher can only be spent with a tap, so the next guest most likely holds a card too.
  bool get _paidByCard => _shown?.voucher.kind == VoucherKind.card;

  void _scanNext() =>
      _paidByCard ? _loop.openCardTap(texts: cardTexts(AppLocalizations.of(context))) : _loop.openQr();

  @override
  Widget build(BuildContext context) {
    final SuccessState? s = _shown;
    if (s == null) return ColoredBox(color: context.colors.bgCanvas);
    final MoneyContext money = context.moneyFor(s.entry.currency);
    return ColoredBox(
      color: context.colors.bgCanvas,
      child: IgnorePointer(
        ignoring: _leaving,
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Motion.durationFast
              : Motion.durationBase,
          switchInCurve: Motion.easeStandard,
          switchOutCurve: Motion.easeStandard,
          child: s.presenting
              ? _GuestView(
                  key: const ValueKey<String>('guest'),
                  entry: s.entry,
                  money: money,
                  spoken: _spokenResult(
                    AppLocalizations.of(context),
                    money,
                    s.entry,
                  ),
                  onClose: _finish,
                )
              : _SuccessView(
                  key: const ValueKey<String>('success'),
                  entry: s.entry,
                  money: money,
                  hairline: _Hairline(loop: _loop, onFinished: _finish),
                  onFinish: _finish,
                  onShowGuest: () => _loop.presentToGuest(true),
                  onScanNext: _scanNext,
                  nextIsCard: _paidByCard,
                ),
        ),
      ),
    );
  }
}

/// SuccessMark size: 96, 72 at compact height, 120 on tablets (08 §3.3).
double _markSize(WaiterLayout layout) {
  if (layout.widthClass.isTablet) return _markTablet;
  return layout.heightClass.isCompact ? _markCompact : SuccessMarkTokens.size;
}

const double _markCompact = 72;
const double _markTablet = 120;

/// 03b §4.4, 08 §3.3: the content column on tablets.
const double _successColumn = 440;

/// 06 M18 stagger after the response (t = 0).
const Duration _titleAt = Duration(milliseconds: 80);
const Duration _amountAt = Duration(milliseconds: 120);
const Duration _remainingAt = Duration(milliseconds: 200);
const Duration _actionsAt = Duration(milliseconds: 280);

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.entry,
    required this.money,
    required this.hairline,
    required this.onFinish,
    required this.onShowGuest,
    required this.onScanNext,
    required this.nextIsCard,
    super.key,
  });

  final RecentEntry entry;
  final MoneyContext money;
  final Widget hairline;
  final VoidCallback onFinish;
  final VoidCallback onShowGuest;
  final VoidCallback onScanNext;
  final bool nextIsCard;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final WaiterLayout layout = context.layout;
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final double markSize = _markSize(layout);
    final bool empty = entry.balanceAfter == 0;
    final double gapScale = layout.heightClass.isCompact ? _compactGaps : 1;

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox.square(
          dimension: markSize,
          child: const FittedBox(child: SuccessMark(playFeedback: false)),
        ),
        SizedBox(height: Space.s6 * gapScale),
        Semantics(
          container: true,
          header: true,
          label: '${l10n.successTitle}, ${money.spoken(entry.amount)}',
          excludeSemantics: true,
          child: Column(
            children: <Widget>[
              Entrance(
                delay: _titleAt,
                rise: Space.s2,
                child: ScaledText(
                  l10n.successTitle,
                  type: TypeTokens.titleM,
                  color: c.success,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: Space.s1 * gapScale),
              Entrance(
                delay: _amountAt,
                rise: Space.s2,
                child: MoneyText(
                  cents: entry.amount,
                  money: money,
                  type: TypeTokens.amountL,
                  symbolType: TypeTokens.currencyL,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Space.s4 * gapScale),
        Entrance(
          delay: _remainingAt,
          rise: Space.s1,
          child: Column(
            children: <Widget>[
              Semantics(
                label: empty
                    ? l10n.successEmpty
                    : l10n.successRemaining(money.spoken(entry.balanceAfter)),
                excludeSemantics: true,
                child: ScaledText(
                  empty
                      ? l10n.successEmpty
                      : l10n.successRemaining(money.format(entry.balanceAfter)),
                  type: TypeTokens.titleM,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Space.s1),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Space.s2,
                runSpacing: Space.s1,
                children: <Widget>[
                  Semantics(
                    label: l10n.successCard(Spoken.characters(entry.last4)),
                    excludeSemantics: true,
                    child: ScaledText(
                      l10n.successCard(entry.last4),
                      type: TypeTokens.caption,
                      color: c.fgTertiary,
                    ),
                  ),
                  if (empty) const StatusBadge(status: BadgeStatus.usedUp),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final Widget actions = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TertiaryButton(label: l10n.successShowGuest, large: true, onPressed: onShowGuest),
        const SizedBox(height: Space.s2),
        PrimaryButton(
          label: nextIsCard ? l10n.successNextCard : l10n.successNext,
          icon: nextIsCard ? WaiterIcon.nfcArcs : WaiterIcon.scanQrCode,
          onPressed: onScanNext,
        ),
      ],
    );

    final double width = layout.widthClass.isTablet
        ? _successColumn
        : layout.contentWidth;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onFinish,
      child: Column(
        children: <Widget>[
          SizedBox(height: padding.top),
          hairline,
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) =>
                  SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Center(
                        child: SizedBox(
                          width: width,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: Space.s4,
                            ),
                            child: content,
                          ),
                        ),
                      ),
                    ),
                  ),
            ),
          ),
          Center(
            child: SizedBox(
              width: width,
              child: Entrance(
                delay: _actionsAt,
                rise: Space.s2,
                child: actions,
              ),
            ),
          ),
          SizedBox(height: padding.bottom + layout.ctaBottomPadding),
        ],
      ),
    );
  }

  /// 08 §3.3: gaps −25 % at compact height.
  static const double _compactGaps = 0.75;
}

/// "Show guest" (03b §4.8): what the guest reads at arm's length — mark,
/// amount, remaining balance, restaurant and voucher; no controls. One
/// accessibility element; a tap anywhere closes it.
class _GuestView extends StatefulWidget {
  const _GuestView({
    required this.entry,
    required this.money,
    required this.spoken,
    required this.onClose,
    super.key,
  });

  final RecentEntry entry;
  final MoneyContext money;
  final String spoken;
  final VoidCallback onClose;

  @override
  State<_GuestView> createState() => _GuestViewState();
}

class _GuestViewState extends State<_GuestView>
    with SingleTickerProviderStateMixin {
  /// 03b §4.8: the amount scales 0.9 → 1 with `motion.spring.soft`.
  static const double _amountFrom = 0.9;
  late final AnimationController _amount = AnimationController.unbounded(
    vsync: this,
    value: _amountFrom,
  );

  /// 03b §4.8: SuccessMark 64 pt in the guest view.
  static const double _mark = 64;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_amount.isAnimating || _amount.value == 1) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _amount.value = 1;
    } else {
      unawaited(
        _amount.animateWith(
          SpringSimulation(Motion.springSoft, _amountFrom, 1, 0),
        ),
      );
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final WaiterLayout layout = context.layout;
    final RecentEntry entry = widget.entry;
    final bool empty = entry.balanceAfter == 0;
    final EdgeInsets padding = MediaQuery.paddingOf(context);

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Already drawn on S09: shown without a second draw (static).
        MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: const SizedBox.square(
            dimension: _mark,
            child: FittedBox(child: SuccessMark(playFeedback: false)),
          ),
        ),
        const SizedBox(height: Space.s4),
        ScaledText(
          l10n.successTitle,
          type: TypeTokens.titleL,
          color: c.success,
          textAlign: TextAlign.center,
        ),
        AnimatedBuilder(
          animation: _amount,
          builder: (BuildContext context, Widget? child) =>
              Transform.scale(scale: _amount.value, child: child),
          child: MoneyText(
            cents: entry.amount,
            money: widget.money,
            type: TypeTokens.amountXl,
            symbolType: TypeTokens.currencyXl,
          ),
        ),
        const SizedBox(height: Space.s8),
        if (empty)
          ScaledText(
            l10n.successEmpty,
            type: TypeTokens.titleL,
            textAlign: TextAlign.center,
          )
        else ...<Widget>[
          ScaledText(
            l10n.guestRemainingLabel,
            type: TypeTokens.titleM,
            color: c.fgSecondary,
            textAlign: TextAlign.center,
          ),
          MoneyText(
            cents: entry.balanceAfter,
            money: widget.money,
            type: TypeTokens.balance,
            symbolType: TypeTokens.currencyBalance,
          ),
        ],
        const SizedBox(height: Space.s4),
        ScaledText(
          '${entry.restaurantName} · ${VoucherNumber.masked(entry.last4)}',
          type: TypeTokens.caption,
          color: c.fgTertiary,
          textAlign: TextAlign.center,
        ),
      ],
    );

    return Semantics(
      container: true,
      label: widget.spoken,
      onTap: widget.onClose,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClose,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) =>
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        layout.margin,
                        padding.top + Space.s4,
                        layout.margin,
                        padding.bottom + Space.s4,
                      ),
                      child: content,
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

/// The CountdownHairline of S09 (06 M19): it starts when the mark is
/// complete (t = 520 ms) and runs until the loop's automatic return
/// (`successAt` + `successTotal`: 4.52 s, 10.52 s with a screen reader).
class _Hairline extends StatefulWidget {
  const _Hairline({required this.loop, required this.onFinished});

  final LoopController loop;
  final VoidCallback onFinished;

  @override
  State<_Hairline> createState() => _HairlineState();
}

class _HairlineState extends State<_Hairline> {
  /// 06 M18/M19: the hairline starts at the end of the success envelope.
  static const Duration _startAt = Motion.durationEmphasis;

  Timer? _start;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    final LoopController loop = widget.loop;
    final Duration elapsed = loop.now() - (loop.successAt ?? loop.now());
    if (elapsed >= _startAt) {
      _begin();
    } else {
      _start = Timer(_startAt - elapsed, () {
        if (mounted) setState(_begin);
      });
    }
  }

  void _begin() {
    final LoopController loop = widget.loop;
    final Duration elapsed = loop.now() - (loop.successAt ?? loop.now());
    final Duration left = loop.successTotal - elapsed;
    _duration = left > Duration.zero ? left : Duration.zero;
  }

  @override
  void dispose() {
    _start?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Duration? duration = _duration;
    if (duration == null) {
      return const SizedBox(height: Sizes.hairlineCountdown);
    }
    return CountdownHairline(duration: duration, onFinished: widget.onFinished);
  }
}
