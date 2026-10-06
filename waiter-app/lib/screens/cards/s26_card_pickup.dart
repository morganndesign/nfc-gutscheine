import 'dart:async';

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../app/money.dart';
import '../../components/components.dart';
import '../../core/api/models.dart';
import '../../core/cards/card_desk.dart';
import '../../core/cards/card_pickup.dart';
import '../../core/cards/card_presenter.dart';
import '../../core/theme/theme.dart';
import '../../l10n/app_localizations.dart';
import '../scan/qr_camera.dart';
import 'card_tap_view.dart';
import 'qr_capture.dart';

/// S26 · Hand out an online card (managers and owners, Android and iPhone alike, online sales decision 2026-10-06):
/// scan the QR from the guest's e-mail, then hold a new card from stock to the phone. The card takes over the
/// voucher; the e-mailed QR stops working.
class CardPickupScreen extends StatefulWidget {
  const CardPickupScreen({super.key, this.cameraFactory = MobileScannerQrCamera.new});

  final QrCameraFactory cameraFactory;

  @override
  State<CardPickupScreen> createState() => _CardPickupScreenState();
}

class _CardPickupScreenState extends State<CardPickupScreen> {
  CardPickupController? _controller;

  CardPickupController get _c => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final AppServices s = context.services;
    final AppLocalizations l10n = AppLocalizations.of(context);
    _controller = CardPickupController(
      api: s.api,
      cards: CardPresenter(api: s.api, nfc: s.nfc),
      session: s.session,
      texts: (prompt: l10n.pickupTap, checking: l10n.cardChecking, done: l10n.cardDone, failed: l10n.cardFailed),
    );
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

  Future<void> _scan() async {
    final String? raw = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (BuildContext context) =>
            QrCaptureScreen(title: AppLocalizations.of(context).pickupScanTitle, cameraFactory: widget.cameraFactory),
      ),
    );
    if (raw != null && mounted) await _c.scanned(raw);
  }

  static String _date(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.day}.${d.month}. ${two(d.hour)}:${two(d.minute)}';
  }

  String? _problem(AppLocalizations l10n) => switch (_c.problem) {
    null => null,
    CardPickupProblem.notRecognized => l10n.pickupErrorNotRecognized,
    CardPickupProblem.notOnline => l10n.pickupErrorNotOnline,
    CardPickupProblem.noCardOrdered => l10n.pickupErrorNoCard,
    CardPickupProblem.pickedUp => l10n.pickupErrorPickedUp,
    CardPickupProblem.tooEarly => l10n.pickupErrorTooEarly(_c.availableFrom != null ? _date(_c.availableFrom!) : '—'),
    CardPickupProblem.scanAgain => l10n.pickupErrorScanAgain,
    CardPickupProblem.voucherNotUsable => l10n.pickupErrorNotUsable,
    CardPickupProblem.offline => l10n.offlineTitle,
    CardPickupProblem.failed => l10n.cardsFailed,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (BuildContext context, _) {
        final bool tapping = _c.phase == DeskPhase.tapping || _c.phase == DeskPhase.checking;
        final bool locked = _c.phase == DeskPhase.checking || _c.phase == DeskPhase.busy;
        final String? problem = _problem(l10n);
        return PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop && !locked) unawaited(_close());
          },
          child: ColoredBox(
            color: context.colors.bgCanvas,
            child: Column(
              children: <Widget>[
                TopBar.task(onClose: locked ? null : () => unawaited(_close()), title: l10n.menuCardsPickup),
                if (problem != null) StatusBanner(tone: BannerTone.warning, title: problem),
                if (_c.cardFailure case final CardPresentException failure) _failure(l10n, failure),
                Expanded(
                  child: tapping
                      ? CardTapView(instruction: l10n.pickupTap, checking: _c.phase == DeskPhase.checking)
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

  Widget _content(BuildContext context, AppLocalizations l10n) {
    final WaiterLayout layout = context.layout;
    final PickedUpCard? done = _c.done;
    final PresentedVoucher? voucher = _c.voucher;
    final bool busy = _c.phase != DeskPhase.idle;
    final Widget body;
    final Widget action;
    if (done != null) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SuccessMark(),
          const SizedBox(height: Space.s6),
          ScaledText(l10n.pickupDoneTitle, type: TypeTokens.titleL, textAlign: TextAlign.center),
          const SizedBox(height: Space.s2),
          Semantics(
            liveRegion: true,
            child: ScaledText(
              l10n.pickupDoneBody(done.cardNumber, context.moneyFor(done.currency).format(done.balance)),
              type: TypeTokens.bodyL,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
      action = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PrimaryButton(label: l10n.commonDone, onPressed: () => unawaited(_close())),
          const SizedBox(height: Space.s2),
          TertiaryButton(label: l10n.pickupNext, large: true, onPressed: _c.reset),
        ],
      );
    } else if (voucher != null) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ScaledText(
            l10n.pickupVoucher(context.moneyFor(voucher.currency).format(voucher.balance)),
            type: TypeTokens.titleM,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.s3),
          ScaledText(l10n.pickupTap, type: TypeTokens.bodyM, textAlign: TextAlign.center, color: context.colors.fgSecondary),
        ],
      );
      action = PrimaryButton(
        label: l10n.pickupTapAction,
        icon: WaiterIcon.nfcArcs,
        status: busy ? ButtonStatus.loading : ButtonStatus.idle,
        onPressed: busy ? null : () => unawaited(_c.handOut()),
      );
    } else {
      body = ScaledText(l10n.pickupScan, type: TypeTokens.bodyL, textAlign: TextAlign.center);
      action = PrimaryButton(
        label: l10n.pickupScanAction,
        icon: WaiterIcon.scanQrCode,
        status: busy ? ButtonStatus.loading : ButtonStatus.idle,
        onPressed: busy ? null : () => unawaited(_scan()),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(layout.margin, 0, layout.margin, layout.viewPadding.bottom + layout.ctaBottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: Center(child: body)),
          action,
        ],
      ),
    );
  }
}
