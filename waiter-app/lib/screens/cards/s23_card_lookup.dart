import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../app/money.dart';
import '../../components/components.dart';
import '../../core/api/models.dart';
import '../../core/cards/card_desk.dart';
import '../../core/cards/card_presenter.dart';
import '../../core/theme/theme.dart';
import '../../l10n/app_localizations.dart';
import '../scan/sheet_rows.dart';
import 'card_tap_view.dart';

/// S23 · Find a card (managers and owners): the inventory number shown with the voucher in the dashboard → the
/// card's state and balance → suspend it (lost, stolen), resume it (found), or replace it with a stock card held
/// to the phone (the balance moves to the new card). Android and iPhone alike.
class CardLookupScreen extends StatefulWidget {
  const CardLookupScreen({super.key});

  @override
  State<CardLookupScreen> createState() => _CardLookupScreenState();
}

class _CardLookupScreenState extends State<CardLookupScreen> {
  CardLookupController? _controller;
  final TextEditingController _number = TextEditingController(text: 'B-');

  CardLookupController get _c => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final AppServices s = context.services;
    final AppLocalizations l10n = AppLocalizations.of(context);
    _controller = CardLookupController(
      api: s.api,
      cards: CardPresenter(api: s.api, nfc: s.nfc),
      session: s.session,
      texts: (prompt: l10n.cardsReplaceTap, checking: l10n.cardChecking, done: l10n.cardDone, failed: l10n.cardFailed),
      oldCardTexts: (
        prompt: l10n.cardsReplaceTapOld,
        checking: l10n.cardChecking,
        done: l10n.cardDone,
        failed: l10n.cardFailed,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_controller?.cancelTap());
    _controller?.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _c.cancelTap();
    if (mounted) Navigator.of(context).pop();
  }

  /// Suspend and replace ask why; the reason goes to the card's history. [footnote] explains a missing choice.
  Future<void> _withReason(List<String> reasons, Future<void> Function(String reason) action, {String? footnote}) async {
    final String? reason = await showWaiterSheet<String>(
      context: context,
      title: AppLocalizations.of(context).cardsReasonTitle,
      builder: (BuildContext sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final String r in reasons)
            SheetRow(label: r, onPressed: () => Navigator.of(sheet).pop(r), showDivider: r != reasons.last),
          if (footnote != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.s3),
              child: ScaledText(footnote, type: TypeTokens.bodyM, color: sheet.colors.fgSecondary),
            ),
        ],
      ),
    );
    if (reason != null && mounted) await action(reason);
  }

  /// Replace: a damaged card is at hand and is tapped first; a lost or stolen one is not (owners only).
  Future<void> _replace(AppLocalizations l10n) {
    final bool owner = context.services.session.user?.canReplaceLostCards ?? false;
    return _withReason(
      <String>[l10n.cardsReasonDamaged, if (owner) ...<String>[l10n.cardsReasonLost, l10n.cardsReasonStolen]],
      (String reason) => _c.replace(reason, oldCardAtHand: reason == l10n.cardsReasonDamaged),
      footnote: owner ? null : l10n.cardsReplaceOwnerOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (BuildContext context, _) {
        final bool tapping = _c.phase == DeskPhase.tapping || _c.phase == DeskPhase.checking;
        final bool locked = _c.phase == DeskPhase.checking || _c.phase == DeskPhase.busy;
        return PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop && !locked) unawaited(_close());
          },
          child: ColoredBox(
            color: context.colors.bgCanvas,
            child: Column(
              children: <Widget>[
                TopBar.task(onClose: locked ? null : () => unawaited(_close()), title: l10n.menuCardsFind),
                if (_c.cardFailure case final CardPresentException failure) _failure(l10n, failure),
                if (_c.requestFailed) StatusBanner(tone: BannerTone.warning, title: l10n.cardsFailed),
                if (_c.done case final String done) _doneBanner(l10n, done),
                Expanded(
                  child: tapping
                      ? CardTapView(
                          instruction: _c.tappingOldCard ? l10n.cardsReplaceTapOld : l10n.cardsReplaceTap,
                          checking: _c.phase == DeskPhase.checking,
                        )
                      : _content(context, l10n),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _failure(AppLocalizations l10n, CardPresentException e) {
    final ({ProblemFamily family, String title, String body}) t = cardFailureTexts(
      l10n,
      e,
      notUsableTitle: l10n.cardsFailed,
      notUsableBody: l10n.saleCardNotUsable,
    );
    return StatusBanner(tone: BannerTone.warning, title: t.title, body: t.body);
  }

  Widget _doneBanner(AppLocalizations l10n, String done) => StatusBanner(
    tone: BannerTone.success,
    title: switch (done) {
      'suspended' => l10n.cardsSuspendDone,
      'resumed' => l10n.cardsResumeDone,
      _ => l10n.cardsReplaceDone(_c.card?.cardNumber ?? ''),
    },
  );

  Widget _content(BuildContext context, AppLocalizations l10n) {
    final WaiterLayout layout = context.layout;
    final CardInfo? card = _c.card;
    final bool busy = _c.phase != DeskPhase.idle;
    return ListView(
      padding: EdgeInsets.fromLTRB(layout.margin, Space.s4, layout.margin, layout.viewPadding.bottom + Space.s6),
      children: <Widget>[
        WaiterTextField(
          kind: TextFieldKind.text,
          label: l10n.cardsFindLabel,
          controller: _number,
          maxLength: 32,
          enabled: !busy,
          helperText: l10n.cardsFindHelper,
          errorText: _c.notFound ? l10n.cardsFindNotFound : null,
          onSubmitted: (String value) => unawaited(_c.find(value)),
        ),
        const SizedBox(height: Space.s2),
        SecondaryButton(
          label: l10n.cardsFindAction,
          status: _c.phase == DeskPhase.busy && card == null ? ButtonStatus.loading : ButtonStatus.idle,
          onPressed: busy ? null : () => unawaited(_c.find(_number.text)),
        ),
        if (card != null) ...<Widget>[
          const SizedBox(height: Space.s6),
          _cardSummary(context, l10n, card),
          const SizedBox(height: Space.s6),
          ..._actions(l10n, card, busy),
        ],
      ],
    );
  }

  Widget _cardSummary(BuildContext context, AppLocalizations l10n, CardInfo card) {
    final WaiterColors c = context.colors;
    final String state = switch (card.state) {
      'active' => l10n.cardsStateActive,
      'suspended' => l10n.cardsStateSuspended,
      'replaced' => l10n.cardsStateReplaced,
      'available' => l10n.cardsStateAvailable,
      _ => l10n.cardsStateOther,
    };
    final int? balance = card.voucherBalance;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ScaledText(card.cardNumber, type: TypeTokens.titleM),
          const SizedBox(height: Space.s1),
          ScaledText(state, type: TypeTokens.bodyM, color: card.state == 'active' ? c.success : c.fgSecondary),
          if (balance != null)
            ScaledText(
              l10n.cardsBalance(context.moneyFor(card.currency ?? 'EUR').format(balance)),
              type: TypeTokens.bodyL,
            ),
        ],
      ),
    );
  }

  List<Widget> _actions(AppLocalizations l10n, CardInfo card, bool busy) {
    final List<String> lossReasons = <String>[l10n.cardsReasonLost, l10n.cardsReasonStolen, l10n.cardsReasonDamaged];
    final bool replaceable = card.state == 'active' || card.state == 'suspended';
    return <Widget>[
      if (card.state == 'active')
        SecondaryButton(
          label: l10n.cardsSuspend,
          onPressed: busy ? null : () => unawaited(_withReason(lossReasons, _c.suspend)),
        ),
      if (card.state == 'suspended')
        SecondaryButton(
          label: l10n.cardsResume,
          onPressed: busy ? null : () => unawaited(_c.resume(l10n.cardsReasonFound)),
        ),
      if (replaceable) ...<Widget>[
        const SizedBox(height: Space.s2),
        PrimaryButton(
          label: l10n.cardsReplace,
          icon: WaiterIcon.nfcArcs,
          onPressed: busy ? null : () => unawaited(_replace(l10n)),
        ),
      ],
    ];
  }
}
