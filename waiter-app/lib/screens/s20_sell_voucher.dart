import 'dart:async';

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/app_scope.dart';
import '../app/money.dart';
import '../components/components.dart';
import '../core/api/models.dart';
import '../core/cards/card_presenter.dart';
import '../core/format/format.dart';
import '../core/platform/voucher_printer.dart';
import '../core/sale/sale_controller.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'cards/card_tap_view.dart';
import 'charge/voucher_data.dart';
import 'payment_method_row.dart';
import 'scan/sheet_rows.dart';

/// S20 · Sell voucher — managers and owners (`vouchers.sell`), on Android and
/// iPhone alike; the server checks role and sign-in on every request. With
/// [cards] (the phone reads cards and the role may bind them) the first step
/// asks: printed voucher or gift card.
Future<void> openSellVoucher(BuildContext context, {bool cards = false}) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => SellVoucherScreen(cards: cards)));

/// Side of the QR on the done step.
const double _qrSide = 200;

class SellVoucherScreen extends StatefulWidget {
  const SellVoucherScreen({super.key, this.cards = false});

  /// Offer the gift card form.
  final bool cards;

  @override
  State<SellVoucherScreen> createState() => _SellVoucherScreenState();
}

class _SellVoucherScreenState extends State<SellVoucherScreen> {
  SaleController? _controller;
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _email = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null && !widget.cards) _start(SaleForm.printable);
  }

  /// The form is chosen (or there is only one): the sale starts.
  void _start(SaleForm form) {
    final AppServices s = context.services;
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() {
      _controller = SaleController(
        api: s.api,
        session: s.session,
        printer: s.voucherPrinter,
        form: form,
        cards: CardPresenter(api: s.api, nfc: s.nfc),
        cardTexts: (prompt: l10n.saleCardTap, checking: l10n.cardChecking, done: l10n.saleCardDoneTitle, failed: l10n.saleCardFailedTitle),
      );
    });
  }

  @override
  void dispose() {
    // Closed without "✕" (signed out, blocked): a reader still waiting for the stock card is stopped.
    unawaited(_controller?.cancelTap());
    _controller?.dispose();
    _reference.dispose();
    _reason.dispose();
    _email.dispose();
    super.dispose();
  }

  SaleController get _c => _controller!;

  /// Leaving asks first when something would be lost: an unprinted QR (it
  /// cannot be shown again) or a sale whose answer never arrived (only "Try
  /// again" with the same key finds out without selling twice).
  Future<void> _close() async {
    final SaleState s = _c.state;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final (String, String)? ask = _c.uncertain
        ? (l10n.saleLeaveUncertainTitle, l10n.saleLeaveUncertainBody)
        : (s is SaleDone && s.hasQr && !s.printed)
        ? (l10n.saleLeaveTitle, l10n.saleLeaveBody)
        : null;
    if (ask != null) {
      final DialogChoice choice = await showWaiterDialog(
        context: context,
        title: ask.$1,
        body: ask.$2,
        confirmLabel: l10n.saleLeaveConfirm,
        cancelLabel: l10n.commonCancel,
        destructive: true,
      );
      if (choice != DialogChoice.confirm || !mounted) return;
    }
    await _controller?.cancelTap();
    if (mounted) Navigator.of(context).pop();
  }

  void _feedback(EntryOutcome outcome) {
    if (outcome == EntryOutcome.rejectedAtLimit) context.services.feedback.haptic(HapticToken.warning);
  }

  void _startOver() {
    _reference.clear();
    _reason.clear();
    _email.clear();
    _c.startOver();
  }

  PrintableVoucher _sheet(SoldVoucher sold) {
    final Restaurant? restaurant = context.services.session.user?.restaurant;
    return PrintableVoucher(
      payload: sold.printablePayload!,
      restaurantName: restaurant?.name ?? '',
      restaurantLocale: restaurant?.locale ?? 'de_AT',
      value: sold.value,
      currency: sold.currency,
      brandColor: restaurant?.settings.brandColor,
      expiresOn: restaurantDateOf(context, sold.expiresAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_controller == null) return _formChoice(context, l10n);
    return ListenableBuilder(
      listenable: _c,
      builder: (BuildContext context, _) {
        final SaleState state = _c.state;
        final Widget body = switch (state) {
          SaleAmount() => _amount(context, l10n, state),
          SaleDetails() => _details(context, l10n, state),
          SaleTapCard(:final bool checking) => CardTapView(instruction: l10n.saleCardTap, checking: checking),
          SaleProblem() => _problem(l10n, state),
          SaleDone() => _done(context, l10n, state),
        };
        final bool busy = (state is SaleDetails && state.submitting) || (state is SaleTapCard && state.checking);
        return PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (didPop || busy) return;
            if (state is SaleDetails) {
              _c.backToAmount();
            } else {
              unawaited(_close());
            }
          },
          child: ColoredBox(
            color: context.colors.bgCanvas,
            child: Column(
              children: <Widget>[
                if (state is! SaleProblem)
                  TopBar.task(onClose: busy ? null : () => unawaited(_close()), title: l10n.saleTitle),
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

  // ------------------------------------------------------------------ amount

  Widget _amount(BuildContext context, AppLocalizations l10n, SaleAmount s) {
    final MoneyContext money = context.money;
    final String? range = s.outOfRange
        ? l10n.saleAmountRange(money.format(s.rangeMin!), money.format(s.rangeMax!))
        : null;
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
                          ScaledText(
                            l10n.saleAmountLabel,
                            type: TypeTokens.caption,
                            color: context.colors.fgSecondary,
                            textAlign: TextAlign.center,
                          ),
                          AmountDisplay(
                            digits: s.amount.digits,
                            money: money,
                            state: range == null ? AmountDisplayState.entering : AmountDisplayState.overLimit,
                            message: range,
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

  Widget _details(BuildContext context, AppLocalizations l10n, SaleDetails s) {
    final WaiterColors c = context.colors;
    final String amount = context.money.format(s.amount.cents);
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
                        child: ScaledText(
                          l10n.salePaymentLabel,
                          type: TypeTokens.caption,
                          color: c.fgSecondary,
                        ),
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
                      const SizedBox(height: Space.s6),
                      WaiterTextField(
                        kind: TextFieldKind.email,
                        label: l10n.saleEmailLabel,
                        controller: _email,
                        enabled: !s.submitting,
                        helperText: _c.sendsGuestEmail ? l10n.saleEmailHelper : l10n.saleEmailHelperNoMail,
                        errorText: s.emailInvalid ? l10n.saleEmailInvalid : null,
                        onChanged: _c.setEmail,
                      ),
                      const SizedBox(height: Space.s4),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.s4),
              PrimaryButton(
                label: _c.form == SaleForm.card ? l10n.saleCardSubmit(amount) : l10n.saleSubmit(amount),
                icon: _c.form == SaleForm.card ? WaiterIcon.nfcArcs : null,
                loadingLabel: l10n.saleSubmitting,
                status: s.submitting ? ButtonStatus.loading : ButtonStatus.idle,
                onPressed: s.submitting ? null : () => unawaited(_c.sell()),
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

  Widget _problem(AppLocalizations l10n, SaleProblem s) {
    final String? code = s.requestId == null ? null : SupportCode.fromRequestId(s.requestId!);
    final bool hasCode = code != null && code.isNotEmpty;
    return switch (s.kind) {
      SaleProblemKind.failed => ProblemScreen(
        family: ProblemFamily.server,
        title: l10n.saleFailedTitle,
        body: l10n.saleFailedBody,
        primary: ProblemAction(l10n.commonTryAgain, () => unawaited(_c.sell())),
        secondary: ProblemAction(l10n.commonBack, _c.backToDetails),
        onClose: () => unawaited(_close()),
        supportCode: hasCode ? code : null,
        requestId: hasCode ? s.requestId : null,
      ),
      // Only "Try again" (the same key) or leaving: never a second sale.
      SaleProblemKind.uncertain => ProblemScreen(
        family: ProblemFamily.network,
        title: l10n.saleUncertainTitle,
        body: l10n.saleUncertainBody,
        primary: ProblemAction(l10n.commonTryAgain, () => unawaited(_c.sell())),
        onClose: () => unawaited(_close()),
        supportCode: hasCode ? code : null,
        requestId: hasCode ? s.requestId : null,
      ),
      SaleProblemKind.card => _cardProblem(l10n, s),
      SaleProblemKind.notAllowed => ProblemScreen(
        family: ProblemFamily.account,
        title: l10n.saleNotAllowedTitle,
        body: l10n.saleNotAllowedBody,
        primary: ProblemAction(l10n.commonBack, _c.backToDetails),
        secondary: ProblemAction(l10n.commonClose, () => unawaited(_close())),
        onClose: () => unawaited(_close()),
        supportCode: hasCode ? code : null,
        requestId: hasCode ? s.requestId : null,
      ),
    };
  }

  /// Why a tapped card cannot be sold, so staff know what to do (found in the first iPhone test, 2026-10-04: an
  /// already sold card only said "cannot be sold").
  static String _notUsableBody(AppLocalizations l10n, String? state) => switch (state) {
    'active' => l10n.saleCardAlreadySold,
    'shipped' || 'delivered' => l10n.reloadCardNotInStock,
    'suspended' => l10n.problemCardNotUsableSuspended,
    'lost' => l10n.reloadCardLost,
    'other_restaurant' => l10n.problemCardNotUsableOtherRestaurant,
    _ => l10n.saleCardNotUsable,
  };

  /// The tapped card could not be sold: nothing was booked; hold the card again or take another one.
  Widget _cardProblem(AppLocalizations l10n, SaleProblem s) {
    final ({ProblemFamily family, String title, String body}) t = cardFailureTexts(
      l10n,
      s.card!,
      notUsableTitle: l10n.saleCardFailedTitle,
      notUsableBody: _notUsableBody(l10n, s.card!.cardState),
    );
    return ProblemScreen(
      family: t.family,
      title: t.title,
      body: t.body,
      primary: ProblemAction(l10n.commonTapAgain, () => unawaited(_c.sell())),
      secondary: ProblemAction(l10n.commonBack, _c.backToDetails),
      onClose: () => unawaited(_close()),
    );
  }

  // ------------------------------------------------------------------ form

  /// First step when the phone reads cards: a printed QR voucher or a gift card from stock.
  Widget _formChoice(BuildContext context, AppLocalizations l10n) {
    final WaiterColors c = context.colors;
    return ColoredBox(
      color: c.bgCanvas,
      child: Column(
        children: <Widget>[
          TopBar.task(onClose: () => Navigator.of(context).pop(), title: l10n.saleTitle),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: LayoutTokens.maxForm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.layout.margin),
                      child: Semantics(
                        header: true,
                        child: ScaledText(l10n.saleFormTitle, type: TypeTokens.titleM),
                      ),
                    ),
                    const SizedBox(height: Space.s4),
                    SheetRow(
                      label: l10n.saleFormPrintable,
                      caption: l10n.saleFormPrintableCaption,
                      trailing: WaiterIconView(WaiterIcon.ticket, size: IconSize.s20, color: c.fgSecondary),
                      onPressed: () => _start(SaleForm.printable),
                    ),
                    SheetRow(
                      label: l10n.saleFormCard,
                      caption: l10n.saleFormCardCaption,
                      trailing: WaiterIconView(WaiterIcon.nfcArcs, size: IconSize.s20, color: c.fgSecondary),
                      onPressed: () => _start(SaleForm.card),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ done

  Widget _done(BuildContext context, AppLocalizations l10n, SaleDone s) {
    final WaiterColors c = context.colors;
    final String value = context.moneyFor(s.voucher.currency).format(s.voucher.value);
    final String? card = s.voucher.cardNumber;
    if (card != null) return _doneCard(context, l10n, value, card);
    if (!s.hasQr) return _doneWithoutQr(context, l10n, value);
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
                        Semantics(
                          liveRegion: true,
                          header: true,
                          child: ScaledText(l10n.saleDoneTitle, type: TypeTokens.titleL, textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: Space.s2),
                        ScaledText(
                          l10n.saleDoneValue(value),
                          type: TypeTokens.bodyL,
                          color: c.fgSecondary,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Space.s6),
                        _VoucherQr(payload: s.voucher.printablePayload!, label: l10n.saleQrA11y),
                        const SizedBox(height: Space.s6),
                        ScaledText(
                          s.printFailed
                              ? l10n.salePrintFailed
                              : s.printed
                              ? l10n.salePrinted
                              : l10n.saleDoneBody,
                          type: TypeTokens.bodyM,
                          color: s.printFailed ? c.warning : (s.printed ? c.success : c.fgSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.s4),
              if (s.printed)
                PrimaryButton(label: l10n.commonDone, onPressed: () => unawaited(_close()))
              else
                PrimaryButton(
                  label: l10n.salePrint,
                  icon: WaiterIcon.printer,
                  status: s.printing ? ButtonStatus.loading : ButtonStatus.idle,
                  onPressed: s.printing ? null : () => unawaited(_c.print(_sheet)),
                ),
              const SizedBox(height: Space.s2),
              if (s.printed)
                SecondaryButton(
                  label: l10n.salePrint,
                  icon: WaiterIcon.printer,
                  onPressed: s.printing ? null : () => unawaited(_c.print(_sheet)),
                )
              else
                SecondaryButton(label: l10n.commonDone, onPressed: s.printing ? null : () => unawaited(_close())),
              const SizedBox(height: Space.s2),
              TertiaryButton(
                label: l10n.saleAnother,
                large: true,
                onPressed: s.printing || !s.printed ? null : _startOver,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A card sale: the card is active; nothing to print.
  Widget _doneCard(BuildContext context, AppLocalizations l10n, String value, String number) {
    final WaiterColors c = context.colors;
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
                          child: ScaledText(l10n.saleCardDoneTitle, type: TypeTokens.titleL, textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: Space.s2),
                        ScaledText(l10n.saleDoneValue(value), type: TypeTokens.bodyL, color: c.fgSecondary, textAlign: TextAlign.center),
                        const SizedBox(height: Space.s2),
                        ScaledText(l10n.saleCardDoneBody(number), type: TypeTokens.bodyM, color: c.fgSecondary, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.s4),
              PrimaryButton(label: l10n.commonDone, onPressed: () => unawaited(_close())),
              const SizedBox(height: Space.s2),
              TertiaryButton(label: l10n.saleAnother, large: true, onPressed: _startOver),
            ],
          ),
        ),
      ),
    );
  }

  /// A retry answered with an earlier sale whose QR can no longer be issued
  /// (sale window passed, or sold on another phone). Same advice as the
  /// dashboard: block it there and sell a new one if the guest has nothing.
  Widget _doneWithoutQr(BuildContext context, AppLocalizations l10n, String value) {
    final WaiterColors c = context.colors;
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
                        Semantics(
                          liveRegion: true,
                          header: true,
                          child: ScaledText(l10n.saleNoQrTitle, type: TypeTokens.titleL, textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: Space.s2),
                        ScaledText(
                          l10n.saleDoneValue(value),
                          type: TypeTokens.bodyL,
                          color: c.fgSecondary,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Space.s6),
                        ScaledText(l10n.saleNoQrBody, type: TypeTokens.bodyM, color: c.warning, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.s4),
              PrimaryButton(label: l10n.commonDone, onPressed: () => unawaited(_close())),
              const SizedBox(height: Space.s2),
              TertiaryButton(label: l10n.saleAnother, large: true, onPressed: _startOver),
            ],
          ),
        ),
      ),
    );
  }
}

/// The voucher's QR, drawn on-device from the payload (never fetched, never
/// stored). Always dark on white so any camera reads it.
class _VoucherQr extends StatelessWidget {
  const _VoucherQr({required this.payload, required this.label});

  final String payload;
  final String label;

  @override
  Widget build(BuildContext context) {
    final String svg = Barcode.qrCode(
      errorCorrectLevel: BarcodeQRCorrectionLevel.medium,
    ).toSvg(payload, width: _qrSide, height: _qrSide, color: 0x000000);
    return Semantics(
      image: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.all(Space.s3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(Radii.m),
        ),
        child: SvgPicture.string(svg, width: _qrSide, height: _qrSide),
      ),
    );
  }
}
