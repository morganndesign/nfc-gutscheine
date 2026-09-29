import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../components/components.dart';
import '../../core/api/models.dart';
import '../../core/cards/card_desk.dart';
import '../../core/cards/card_presenter.dart';
import '../../core/theme/theme.dart';
import '../../l10n/app_localizations.dart';
import '../scan/sheet_rows.dart';
import 'card_tap_view.dart';

/// S22 · Confirm a card delivery (managers and owners, Android and iPhone alike): the delivered batch, the number
/// of cards counted in the parcel, one card of the parcel held to the phone.
class ReceiveDeliveryScreen extends StatefulWidget {
  const ReceiveDeliveryScreen({super.key});

  @override
  State<ReceiveDeliveryScreen> createState() => _ReceiveDeliveryScreenState();
}

class _ReceiveDeliveryScreenState extends State<ReceiveDeliveryScreen> {
  ReceiveDeliveryController? _controller;

  ReceiveDeliveryController get _c => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final AppServices s = context.services;
    final AppLocalizations l10n = AppLocalizations.of(context);
    _controller = ReceiveDeliveryController(
      api: s.api,
      cards: CardPresenter(api: s.api, nfc: s.nfc),
      session: s.session,
      texts: (prompt: l10n.cardsReceiveTap, checking: l10n.cardChecking, done: l10n.cardDone, failed: l10n.cardFailed),
    );
    unawaited(_c.load());
  }

  @override
  void dispose() {
    unawaited(_controller?.cancelTap());
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _c.cancelTap();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (BuildContext context, _) {
        final CardBatchSummary? batch = _c.batch;
        final bool tapping = _c.phase == DeskPhase.tapping || _c.phase == DeskPhase.checking;
        final Widget body = tapping
            ? CardTapView(instruction: l10n.cardsReceiveTap, checking: _c.phase == DeskPhase.checking)
            : _c.result != null
            ? _result(context, l10n)
            : batch == null
            ? _list(context, l10n)
            : _count(context, l10n, batch);
        return PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (didPop || _c.phase == DeskPhase.checking || _c.phase == DeskPhase.busy) return;
            if (_c.batch != null && _c.result == null && !tapping) {
              _c.back();
            } else {
              unawaited(_close());
            }
          },
          child: ColoredBox(
            color: context.colors.bgCanvas,
            child: Column(
              children: <Widget>[
                TopBar.task(
                  onClose: _c.phase == DeskPhase.checking || _c.phase == DeskPhase.busy
                      ? null
                      : () => unawaited(_close()),
                  title: l10n.menuCardsReceive,
                ),
                if (_c.cardFailure case final CardPresentException failure) _failure(l10n, failure),
                if (_c.requestFailed) StatusBanner(tone: BannerTone.warning, title: l10n.cardsFailed),
                if (_c.wrongCard) StatusBanner(tone: BannerTone.danger, title: l10n.cardsReceiveWrongCard),
                Expanded(child: body),
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
      notUsableBody: l10n.cardsReceiveWrongCard,
    );
    return StatusBanner(tone: BannerTone.warning, title: t.title, body: t.body);
  }

  Widget _list(BuildContext context, AppLocalizations l10n) {
    final List<CardBatchSummary>? batches = _c.batches;
    if (batches == null) {
      return const Center(child: Spinner());
    }
    if (batches.isEmpty) {
      return Center(
        child: ScaledText(l10n.cardsReceiveNone, type: TypeTokens.bodyM, color: context.colors.fgSecondary),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Space.s4),
      children: <Widget>[
        for (final CardBatchSummary b in batches)
          SheetRow(
            label: b.batchCode,
            caption: b.status == 'on_hold' ? l10n.cardsReceiveOnHold : null,
            value: l10n.cardsReceiveBatch(b.inTransit),
            onPressed: b.status == 'delivered' ? () => _c.choose(b) : null,
            showDivider: b != batches.last,
          ),
      ],
    );
  }

  Widget _count(BuildContext context, AppLocalizations l10n, CardBatchSummary batch) {
    final WaiterLayout layout = context.layout;
    final bool busy = _c.phase != DeskPhase.idle;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.margin,
        0,
        layout.margin,
        layout.viewPadding.bottom + layout.ctaBottomPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LayoutTokens.maxForm),
          child: Column(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ScaledText(batch.batchCode, type: TypeTokens.caption, color: context.colors.fgSecondary),
                      const SizedBox(height: Space.s2),
                      ScaledText(l10n.cardsReceiveCount, type: TypeTokens.bodyL, textAlign: TextAlign.center),
                      const SizedBox(height: Space.s4),
                      Semantics(
                        liveRegion: true,
                        child: ScaledText(_c.count.isEmpty ? '0' : _c.count, type: TypeTokens.amountL),
                      ),
                    ],
                  ),
                ),
              ),
              Keypad(
                variant: KeypadVariant.cardNumber,
                enabled: !busy,
                onDigit: _c.digit,
                onBackspace: _c.backspace,
                onClear: _c.clearCount,
              ),
              const SizedBox(height: Space.s4),
              PrimaryButton(
                label: _c.count.isEmpty ? l10n.cardsReceiveCount : l10n.cardsReceiveContinue(int.parse(_c.count)),
                icon: WaiterIcon.nfcArcs,
                status: _c.phase == DeskPhase.busy ? ButtonStatus.loading : ButtonStatus.idle,
                onPressed: busy || _c.count.isEmpty ? null : () => unawaited(_c.confirm()),
              ),
              const SizedBox(height: Space.s2),
              TertiaryButton(label: l10n.commonBack, large: true, onPressed: busy ? null : _c.back),
            ],
          ),
        ),
      ),
    );
  }

  Widget _result(BuildContext context, AppLocalizations l10n) {
    final bool inService = _c.result == 'in_service';
    final WaiterLayout layout = context.layout;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.margin,
        0,
        layout.margin,
        layout.viewPadding.bottom + layout.ctaBottomPadding,
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (inService) const SuccessMark(),
                  const SizedBox(height: Space.s6),
                  Semantics(
                    liveRegion: true,
                    child: ScaledText(
                      inService ? l10n.cardsReceiveDone : l10n.cardsReceiveHold,
                      type: TypeTokens.bodyL,
                      textAlign: TextAlign.center,
                      color: inService ? null : context.colors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PrimaryButton(label: l10n.commonDone, onPressed: () => unawaited(_close())),
        ],
      ),
    );
  }
}
