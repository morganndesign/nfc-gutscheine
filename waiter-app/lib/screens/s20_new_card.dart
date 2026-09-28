import 'dart:async';

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../app/money.dart';
import '../components/components.dart';
import '../core/format/amount_entry.dart';
import '../core/issue/card_programmer.dart';
import '../core/issue/issue_controller.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';

/// S20 · New gift card — managers and owners only (the S05 button is only shown to them; the server checks
/// role and sign-in on every request). Amount (+ optional guest e-mail) → `POST /cards` → the tag is
/// written, read back and verified (`CardProgrammer`) → card number and balance.
///
/// Card reading is paused while S20 is open (like the menu sheet), so a tag held to the phone is never
/// looked up or redeemed.
Future<void> openNewCard(BuildContext context) async {
  final AppServices services = context.services;
  services.loop.setSheetOpen(true);
  try {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const NewCardScreen()));
  } finally {
    services.loop.setSheetOpen(false);
  }
}

class NewCardScreen extends StatefulWidget {
  const NewCardScreen({super.key});

  @override
  State<NewCardScreen> createState() => _NewCardScreenState();
}

class _NewCardScreenState extends State<NewCardScreen> {
  IssueController? _controller;
  final TextEditingController _email = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final AppServices s = context.services;
      _controller = IssueController(api: s.api, writer: s.writer, nfc: s.nfc, session: s.session);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _email.dispose();
    super.dispose();
  }

  IssueController get _c => _controller!;

  void _close() => Navigator.of(context).maybePop();

  void _feedback(EntryOutcome outcome) {
    if (outcome == EntryOutcome.rejectedAtLimit) context.services.feedback.haptic(HapticToken.warning);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (BuildContext context, _) {
        final IssueState state = _c.state;
        final Widget body = switch (state) {
          IssueEntry() => _entry(context, l10n, state),
          IssueCreateProblem() => _createProblem(l10n, state),
          IssueProgramming() => _programming(context, l10n, state),
          IssueTagProblem() => _tagProblem(l10n, state),
          IssueDone() => _done(context, l10n, state),
        };
        final bool showBar = state is IssueEntry || state is IssueProgramming || state is IssueDone;
        return PopScope<Object?>(
          // Leaving while the tag is written would abandon it half way: "Program later" is the way out.
          canPop: state is! IssueProgramming && !(state is IssueEntry && state.creating),
          child: ColoredBox(
            color: context.colors.bgCanvas,
            child: Column(
              children: <Widget>[
                if (showBar)
                  TopBar.task(
                    onClose: switch (state) {
                      IssueProgramming() => null,
                      IssueEntry(creating: true) => null,
                      _ => _close,
                    },
                    title: l10n.issueTitle,
                  ),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ entry

  Widget _entry(BuildContext context, AppLocalizations l10n, IssueEntry s) {
    final WaiterLayout layout = context.layout;
    final String amount = context.money.format(s.amount.cents);
    final String? rangeMessage = s.rangeMin != null && s.rangeMax != null
        ? l10n.issueAmountRange(context.money.format(s.rangeMin!), context.money.format(s.rangeMax!))
        : null;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): () => unawaited(_c.create()),
      },
      child: Padding(
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
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SizedBox(height: Space.s4),
                        ScaledText(
                          l10n.issueAmountLabel,
                          type: TypeTokens.caption,
                          color: context.colors.fgSecondary,
                          textAlign: TextAlign.center,
                        ),
                        AmountDisplay(
                          digits: s.amount.digits,
                          money: context.money,
                          state: rangeMessage == null ? AmountDisplayState.entering : AmountDisplayState.overLimit,
                          message: rangeMessage,
                        ),
                        const SizedBox(height: Space.s4),
                        WaiterTextField(
                          kind: TextFieldKind.email,
                          label: l10n.issueEmailLabel,
                          controller: _email,
                          enabled: !s.creating,
                          helperText: l10n.issueEmailHelper,
                          errorText: s.emailInvalid ? l10n.issueEmailInvalid : null,
                          onChanged: _c.setEmail,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Space.s4),
                Keypad(
                  enabled: !s.creating,
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
                  label: l10n.issueCreate(amount),
                  loadingLabel: l10n.issueCreating,
                  status: s.creating ? ButtonStatus.loading : ButtonStatus.idle,
                  onPressed: _c.canCreate ? () => unawaited(_c.create()) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _createProblem(AppLocalizations l10n, IssueCreateProblem s) {
    final String? code = _supportCode(s.requestId);
    final (String title, String body) = switch (s.kind) {
      CreateProblemKind.failed => (l10n.issueCreateFailedTitle, l10n.issueCreateFailedBody),
      CreateProblemKind.uncertain => (l10n.issueCreateFailedTitle, l10n.issueCreateUncertainBody),
      CreateProblemKind.notAllowed => (l10n.issueNotAllowedTitle, l10n.issueNotAllowedBody),
    };
    final bool retry = s.kind != CreateProblemKind.notAllowed;
    return ProblemScreen(
      family: s.kind == CreateProblemKind.notAllowed ? ProblemFamily.account : ProblemFamily.server,
      title: title,
      body: body,
      primary: retry
          ? ProblemAction(l10n.commonTryAgain, () => unawaited(_c.create()))
          : ProblemAction(l10n.commonClose, _close),
      secondary: retry ? ProblemAction(l10n.commonCancel, _close) : null,
      onClose: _close,
      supportCode: code,
      requestId: code == null ? null : s.requestId,
    );
  }

  // ------------------------------------------------------------------ programming

  Widget _programming(BuildContext context, AppLocalizations l10n, IssueProgramming s) {
    final WaiterColors c = context.colors;
    final WaiterLayout layout = context.layout;
    final ProgramStep step = s.progress.step;
    final List<(ProgramStep, String)> steps = <(ProgramStep, String)>[
      (ProgramStep.checking, l10n.issueStepCheck),
      (ProgramStep.writing, l10n.issueStepWrite),
      (ProgramStep.verifying, l10n.issueStepVerify),
      (ProgramStep.saving, l10n.issueStepSave),
    ];
    final int current = step == ProgramStep.locking
        ? steps.length
        : steps.indexWhere(((ProgramStep, String) e) => e.$1 == step);
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: Space.s4),
                  ScaledText(
                    l10n.issueCard(s.card.cardNumber),
                    type: TypeTokens.cardNumber,
                    color: c.fgSecondary,
                    textAlign: TextAlign.center,
                  ),
                  ScaledText(
                    l10n.issueSuccessBalance(context.moneyFor(s.card.currency).format(s.card.balance)),
                    type: TypeTokens.caption,
                    color: c.fgTertiary,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.s6),
                  Center(
                    child: SizedBox.square(
                      dimension: 160,
                      child: NfcScanAnimation(
                        state: s.nfcOff
                            ? NfcScanState.idle
                            : step == ProgramStep.waiting
                            ? NfcScanState.listening
                            : NfcScanState.reading,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.s6),
                  Semantics(
                    liveRegion: true,
                    child: ScaledText(
                      s.nfcOff ? l10n.issueNfcOff : l10n.issueProgramTitle,
                      type: TypeTokens.titleM,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: Space.s2),
                  if (!s.nfcOff)
                    ScaledText(
                      s.progress.retap ? l10n.issueProgramRetap : l10n.issueProgramBody,
                      type: TypeTokens.bodyM,
                      color: s.progress.retap ? c.warning : c.fgSecondary,
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: Space.s6),
                  if (!s.nfcOff)
                    for (int i = 0; i < steps.length; i++)
                      _StepRow(label: steps[i].$2, done: current > i, active: current == i),
                ],
              ),
            ),
          ),
          if (s.nfcOff) ...<Widget>[
            PrimaryButton(
              label: l10n.nfcOffAction,
              icon: WaiterIcon.settings,
              onPressed: () => unawaited(context.services.nfc.openSettings()),
            ),
            const SizedBox(height: Space.s2),
          ],
          TertiaryButton(label: l10n.issueLater, large: true, onPressed: () => unawaited(_c.programLater())),
        ],
      ),
    );
  }

  Widget _tagProblem(AppLocalizations l10n, IssueTagProblem s) {
    final ProgrammingException e = s.error;
    final String body = switch (e.code) {
      _ when e.conflictCardNumber != null => l10n.issueTagOtherCard(e.conflictCardNumber!),
      'TAG_LINKED_TO_OTHER_CARD' ||
      'TAG_CARRIES_OTHER_CARD' ||
      'TAG_OF_OTHER_BUSINESS' ||
      'TAG_REFUSED' ||
      'CARD_ALREADY_PROGRAMMED' ||
      'CARD_CLOSED' ||
      'URL_OUTDATED' => l10n.issueTagRefused,
      'TAG_UNSUPPORTED' || 'TAG_TOO_SMALL' => l10n.issueTagUnsupported,
      'TAG_READ_ONLY' => l10n.issueTagReadOnly,
      'TAG_SWAPPED' || 'URL_MISMATCH' => l10n.issueTagVerifyFailed,
      'NETWORK' => l10n.issueTagNetwork,
      'FORBIDDEN' => l10n.issueNotAllowedBody,
      _ => l10n.issueTagMoved,
    };
    final String? code = _supportCode(e.requestId);
    return ProblemScreen(
      family: e.code == 'NETWORK' ? ProblemFamily.network : ProblemFamily.verification,
      title: l10n.issueTagFailedTitle,
      body: body,
      caption: l10n.issueCard(s.card.cardNumber),
      primary: ProblemAction(l10n.commonTryAgain, () => unawaited(_c.retryTag())),
      secondary: ProblemAction(l10n.issueLater, () => unawaited(_c.programLater())),
      supportCode: code,
      requestId: code == null ? null : e.requestId,
    );
  }

  // ------------------------------------------------------------------ done

  Widget _done(BuildContext context, AppLocalizations l10n, IssueDone s) {
    final WaiterColors c = context.colors;
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (s.programmed) const SizedBox.square(dimension: 96, child: FittedBox(child: SuccessMark())),
                    const SizedBox(height: Space.s6),
                    Semantics(
                      liveRegion: true,
                      child: ScaledText(l10n.issueSuccessTitle, type: TypeTokens.titleL, textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: Space.s4),
                    ScaledText(
                      s.card.cardNumber,
                      type: TypeTokens.cardNumber,
                      textAlign: TextAlign.center,
                      semanticsLabel: l10n.issueCard(s.card.cardNumber),
                    ),
                    const SizedBox(height: Space.s2),
                    ScaledText(
                      l10n.issueSuccessBalance(context.moneyFor(s.card.currency).format(s.card.balance)),
                      type: TypeTokens.bodyL,
                      color: c.fgSecondary,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Space.s4),
                    ScaledText(
                      s.programmed ? l10n.issueSuccessVerified : l10n.issueSuccessNoTag,
                      type: TypeTokens.caption,
                      color: s.programmed ? c.success : c.warning,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          PrimaryButton(label: l10n.commonDone, onPressed: _close),
          const SizedBox(height: Space.s2),
          SecondaryButton(
            label: l10n.issueSuccessAnother,
            onPressed: () {
              _email.clear();
              _c.startOver();
            },
          ),
        ],
      ),
    );
  }

  static String? _supportCode(String? requestId) {
    if (requestId == null) return null;
    final String hex = requestId.replaceAll('-', '').toUpperCase();
    return hex.length < 6 ? null : hex.substring(hex.length - 6);
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.done, required this.active});

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s1),
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: IconSize.s20.size,
            child: done
                ? WaiterIconView(WaiterIcon.circleCheck, size: IconSize.s20, color: c.success)
                : active
                ? const Spinner()
                : WaiterIconView(WaiterIcon.circleDashed, size: IconSize.s20, color: c.fgTertiary),
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: ScaledText(label, type: TypeTokens.bodyM, color: done || active ? c.fgPrimary : c.fgTertiary),
          ),
        ],
      ),
    );
  }
}
