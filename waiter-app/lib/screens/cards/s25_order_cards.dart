import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../components/components.dart';
import '../../core/api/models.dart';
import '../../core/cards/card_desk.dart';
import '../../core/cards/card_order.dart';
import '../../core/theme/theme.dart';
import '../../l10n/app_localizations.dart';

/// S25 · Order cards (managers and owners, Android and iPhone alike): how many cards, sent to the platform. The
/// latest order's state is shown on top; an accepted order arrives later under "Confirm a delivery".
class OrderCardsScreen extends StatefulWidget {
  const OrderCardsScreen({super.key});

  @override
  State<OrderCardsScreen> createState() => _OrderCardsScreenState();
}

class _OrderCardsScreenState extends State<OrderCardsScreen> {
  CardOrderController? _controller;

  CardOrderController get _c => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final AppServices s = context.services;
    _controller = CardOrderController(api: s.api, session: s.session);
    unawaited(_c.load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (BuildContext context, _) {
        final bool busy = _c.phase == DeskPhase.busy;
        final CardOrderInfo? latest = _c.sent == null ? _c.latest : null;
        return ColoredBox(
          color: context.colors.bgCanvas,
          child: Column(
            children: <Widget>[
              TopBar.task(onClose: busy ? null : _close, title: l10n.menuCardsOrder),
              if (_c.tooMany) StatusBanner(tone: BannerTone.warning, title: l10n.cardsOrderTooMany),
              if (_c.requestFailed) StatusBanner(tone: BannerTone.warning, title: l10n.cardsFailed),
              if (latest != null && latest.status == 'requested')
                StatusBanner(tone: BannerTone.info, title: l10n.cardsOrderOpen(latest.quantity)),
              if (latest != null && latest.status == 'declined')
                StatusBanner(tone: BannerTone.warning, title: l10n.cardsOrderDeclined(latest.declineReason ?? '—')),
              Expanded(child: _c.sent != null ? _done(context, l10n) : _form(context, l10n, busy)),
            ],
          ),
        );
      },
    );
  }

  Widget _form(BuildContext context, AppLocalizations l10n, bool busy) {
    final WaiterLayout layout = context.layout;
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
                      ScaledText(l10n.cardsOrderCount, type: TypeTokens.bodyL, textAlign: TextAlign.center),
                      const SizedBox(height: Space.s4),
                      Semantics(
                        liveRegion: true,
                        child: ScaledText(_c.count.isEmpty ? '0' : _c.count, type: TypeTokens.amountL),
                      ),
                      const SizedBox(height: Space.s2),
                      ScaledText(
                        l10n.cardsOrderHint,
                        type: TypeTokens.caption,
                        textAlign: TextAlign.center,
                        color: context.colors.fgSecondary,
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
                onClear: _c.clear,
              ),
              const SizedBox(height: Space.s4),
              PrimaryButton(
                label: _c.count.isEmpty ? l10n.cardsOrderCount : l10n.cardsOrderSubmit(_c.quantity),
                status: busy ? ButtonStatus.loading : ButtonStatus.idle,
                onPressed: busy || _c.count.isEmpty ? null : () => unawaited(_c.submit()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _done(BuildContext context, AppLocalizations l10n) {
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
                  const SuccessMark(),
                  const SizedBox(height: Space.s6),
                  Semantics(
                    liveRegion: true,
                    child: ScaledText(l10n.cardsOrderDone, type: TypeTokens.bodyL, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ),
          PrimaryButton(label: l10n.commonDone, onPressed: _close),
        ],
      ),
    );
  }
}
