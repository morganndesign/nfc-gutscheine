import 'dart:async';

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../app/money.dart';
import '../../components/components.dart';
import '../../core/api/models.dart';
import '../../core/cards/card_presenter.dart';
import '../../core/format/format.dart';
import '../../core/reload/reload_controller.dart';
import '../../core/theme/theme.dart';
import '../../l10n/app_localizations.dart';
import '../payment_method_row.dart';
import '../charge/voucher_data.dart';
import 'card_tap_view.dart';

/// S24 · Top up card — managers and owners (`vouchers.reload`) on a phone that reads cards, Android and iPhone
/// alike: tap the guest's card → amount → how the guest paid → booked. The server checks role, tap and limits.
Future<void> openReload(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const ReloadScreen()));

class ReloadScreen extends StatefulWidget {
  const ReloadScreen({super.key});

  @override
  State<ReloadScreen> createState() => _ReloadScreenState();
}

class _ReloadScreenState extends State<ReloadScreen> {
  ReloadController? _controller;
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _reason = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final AppServices s = context.services;
    final AppLocalizations l10n = AppLocalizations.of(context);
    _controller = ReloadController(
      api: s.api,
      session: s.session,
      cards: CardPresenter(api: s.api, nfc: s.nfc),
      texts: (
        prompt: l10n.reloadTap,
        again: l10n.reloadTapAgain,
        checking: l10n.cardChecking,
        done: l10n.reloadDoneTitle,
        failed: l10n.reloadFailedTitle,
      ),
    );
    unawaited(_controller!.tap());
  }

  @override
  void dispose() {
    unawaited(_controller?.cancelTap());
    _controller?.dispose();
    _reference.dispose();
    _reason.dispose();
    super.dispose();
  }

  ReloadController get _c => _controller!;

  /// Leaving asks first only when a top-up's answer never arrived.
  Future<void> _close() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_c.uncertain) {
      final DialogChoice choice = await showWaiterDialog(
        context: context,
        title: l10n.reloadLeaveUncertainTitle,
        body: l10n.reloadLeaveUncertainBody,
        confirmLabel: l10n.saleLeaveConfirm,
        cancelLabel: l10n.commonCancel,
        destructive: true,
      );
      if (choice != DialogChoice.confirm || !mounted) return;
    }
    await _c.cancelTap();
    if (mounted) Navigator.of(context).pop();
  }

  void _feedback(EntryOutcome outcome) {
    if (outcome == EntryOutcome.rejectedAtLimit) context.services.feedback.haptic(HapticToken.warning);
  }

  void _startOver() {
    _reference.clear();
    _reason.clear();
    _c.startOver();
    unawaited(_c.tap());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (BuildContext context, _) {
        final ReloadState state = _c.state;
        final Widget body = switch (state) {
          ReloadTapCard(:final bool again, :final bool checking) => _tap(l10n, again: again, checking: checking),
          ReloadAmount() => _amount(context, l10n, state),
          ReloadDetails() => _details(context, l10n, state),
          ReloadProblem() => _problem(l10n, state),
          ReloadDone() => _done(context, l10n, state),
        };
        final bool busy = (state is ReloadDetails && state.submitting) || (state is ReloadTapCard && state.checking);
        return PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (didPop || busy) return;
            if (state is ReloadDetails) {
              _c.backToAmount();
            } else {
              unawaited(_close());
            }
          },
          child: ColoredBox(
            color: context.colors.bgCanvas,
            child: Column(
              children: <Widget>[
                if (state is! ReloadProblem)
                  TopBar.task(onClose: busy ? null : () => unawaited(_close()), title: l10n.reloadTitle),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }

  EdgeInsets _pagePadding(WaiterLayout layout) =>
      EdgeInsets.fromLTRB(layout.margin, 0, layout.margin, layout.viewPadding.bottom + layout.ctaBottomPadding);

  // ------------------------------------------------------------------ tap

  /// On Android the reader waits on this view; on iPhone the system sheet covers it, and closing that sheet
  /// leaves "Tap card again" here.
  Widget _tap(AppLocalizations l10n, {required bool again, required bool checking}) => Padding(
    padding: _pagePadding(context.layout),
    child: Column(
      children: <Widget>[
        Expanded(
          child: CardTapView(instruction: again ? l10n.reloadTapAgain : l10n.reloadTap, checking: checking),
        ),
      ],
    ),
  );

  // ------------------------------------------------------------------ amount

  Widget _amount(BuildContext context, AppLocalizations l10n, ReloadAmount s) {
    final MoneyContext money = context.moneyFor(s.voucher.currency);
    final String? limit = s.max == null ? null : l10n.reloadAmountMax(money.format(s.max!));
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): _c.continueToDetails,
      },
      child: Padding(
        padding: _pagePadding(context.layout),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: LayoutTokens.maxForm),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // The guest's card with its balance now, as at the till.
                          BalanceCard(data: balanceCardDataOf(context, s.voucher), money: money, maxHeight: 160),
                          const SizedBox(height: Space.s5),
                          ScaledText(
                            l10n.reloadAmountLabel,
                            type: TypeTokens.caption,
                            color: context.colors.fgSecondary,
                            textAlign: TextAlign.center,
                          ),
                          AmountDisplay(
                            digits: s.amount.digits,
                            money: money,
                            state: limit == null ? AmountDisplayState.entering : AmountDisplayState.overLimit,
                            message: limit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.s4),
                Keypad(
                  autofocus: true,
                  onDigit: (int d) {
                    final EntryOutcome o = _c.digit(d);
                    _feedback(o);
                    return o;
                  },
                  onDoubleZero: () {
                    final EntryOutcome o = _c.doubleZero();
                    _feedback(o);
                    return o;
                  },
                  onBackspace: _c.backspace,
                  onClear: _c.clear,
                ),
                const SizedBox(height: Space.s4),
                PrimaryButton(
                  label: s.amount.isEmpty ? l10n.chargeEnterAmount : l10n.saleContinue(money.format(s.amount.cents)),
                  onPressed: _c.canContinue ? _c.continueToDetails : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ details

  Widget _details(BuildContext context, AppLocalizations l10n, ReloadDetails s) {
    final WaiterColors c = context.colors;
    final String amount = context.moneyFor(s.voucher.currency).format(s.amount.cents);
    return Padding(
      padding: _pagePadding(context.layout),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LayoutTokens.maxForm),
          child: Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: Space.s4),
                      Semantics(
                        header: true,
                        child: ScaledText(l10n.salePaymentLabel, type: TypeTokens.caption, color: c.fgSecondary),
                      ),
                      const SizedBox(height: Space.s2),
                      for (final PaymentMethod m in _c.methods)
                        PaymentMethodRow(
                          label: paymentMethodLabel(l10n, m),
                          selected: m == s.method,
                          enabled: !s.submitting,
                          onSelected: () => _c.chooseMethod(m),
                        ),
                      if (s.method.needsReference) ...<Widget>[
                        const SizedBox(height: Space.s4),
                        WaiterTextField(
                          kind: TextFieldKind.text,
                          label: l10n.saleReferenceLabel,
                          controller: _reference,
                          maxLength: 120,
                          enabled: !s.submitting,
                          errorText: s.referenceMissing ? l10n.saleReferenceRequired : null,
                          onChanged: _c.setReference,
                        ),
                      ],
                      if (s.method.needsReason) ...<Widget>[
                        const SizedBox(height: Space.s4),
                        WaiterTextField(
                          kind: TextFieldKind.text,
                          label: l10n.saleReasonLabel,
                          controller: _reason,
                          maxLength: 500,
                          enabled: !s.submitting,
                          errorText: s.reasonMissing ? l10n.saleReasonRequired : null,
                          onChanged: _c.setReason,
                        ),
                      ],
                      const SizedBox(height: Space.s4),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.s4),
              PrimaryButton(
                label: l10n.reloadSubmit(amount),
                loadingLabel: l10n.reloadSubmitting,
                status: s.submitting ? ButtonStatus.loading : ButtonStatus.idle,
                onPressed: s.submitting ? null : () => unawaited(_c.submit()),
              ),
              const SizedBox(height: Space.s2),
              TertiaryButton(label: l10n.commonBack, large: true, onPressed: s.submitting ? null : _c.backToAmount),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ problem

  Widget _problem(AppLocalizations l10n, ReloadProblem s) {
    final String? code = s.requestId == null ? null : SupportCode.fromRequestId(s.requestId!);
    final bool hasCode = code != null && code.isNotEmpty;
    final ProblemAction back = ProblemAction(l10n.commonBack, _c.back);
    final ProblemAction close = ProblemAction(l10n.commonClose, () => unawaited(_close()));
    return switch (s.kind) {
      ReloadProblemKind.card => () {
        final ({ProblemFamily family, String title, String body}) t = cardFailureTexts(
          l10n,
          s.card!,
          notUsableTitle: l10n.reloadFailedTitle,
          notUsableBody: l10n.reloadCardNotUsable,
        );
        return ProblemScreen(
          family: t.family,
          title: t.title,
          body: t.body,
          // Before the amount: tap again; after it: confirm the top-up with the card.
          primary: ProblemAction(l10n.commonTapAgain, () => unawaited(s.details == null ? _c.tap() : _c.submit())),
          secondary: s.details == null ? close : back,
          onClose: () => unawaited(_close()),
          supportCode: hasCode ? code : null,
          requestId: hasCode ? s.requestId : null,
        );
      }(),
      ReloadProblemKind.failed => ProblemScreen(
        family: ProblemFamily.server,
        title: l10n.reloadFailedTitle,
        body: l10n.reloadFailedBody,
        primary: ProblemAction(l10n.commonTryAgain, () => unawaited(_c.submit())),
        secondary: back,
        onClose: () => unawaited(_close()),
        supportCode: hasCode ? code : null,
        requestId: hasCode ? s.requestId : null,
      ),
      // Only "Try again" (the same key) or leaving: never a second booking.
      ReloadProblemKind.uncertain => ProblemScreen(
        family: ProblemFamily.network,
        title: l10n.reloadUncertainTitle,
        body: l10n.reloadUncertainBody,
        primary: ProblemAction(l10n.commonTryAgain, () => unawaited(_c.submit())),
        onClose: () => unawaited(_close()),
        supportCode: hasCode ? code : null,
        requestId: hasCode ? s.requestId : null,
      ),
      ReloadProblemKind.notAllowed => ProblemScreen(
        family: ProblemFamily.account,
        title: l10n.reloadNotAllowedTitle,
        body: l10n.reloadNotAllowedBody,
        primary: back,
        secondary: close,
        onClose: () => unawaited(_close()),
        supportCode: hasCode ? code : null,
        requestId: hasCode ? s.requestId : null,
      ),
    };
  }

  // ------------------------------------------------------------------ done

  Widget _done(BuildContext context, AppLocalizations l10n, ReloadDone s) {
    final MoneyContext money = context.moneyFor(s.result.currency);
    return Padding(
      padding: _pagePadding(context.layout),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LayoutTokens.maxForm),
          child: Column(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SuccessMark(),
                        const SizedBox(height: Space.s6),
                        Semantics(
                          liveRegion: true,
                          header: true,
                          child: ScaledText(l10n.reloadDoneTitle, type: TypeTokens.titleL, textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: Space.s2),
                        ScaledText(
                          l10n.reloadDoneBody(money.format(s.result.amount), money.format(s.result.balance)),
                          type: TypeTokens.bodyL,
                          color: context.colors.fgSecondary,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.s4),
              PrimaryButton(label: l10n.commonDone, onPressed: () => unawaited(_close())),
              const SizedBox(height: Space.s2),
              TertiaryButton(label: l10n.reloadAnother, large: true, onPressed: _startOver),
            ],
          ),
        ),
      ),
    );
  }
}
