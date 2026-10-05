import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../components/components.dart';
import '../../components/support/announce.dart';
import '../../core/state/session_state.dart';
import '../../core/theme/theme.dart';
import '../../l10n/app_localizations.dart';

/// Second step of every app sign-in (decision 2026-10-06), on S02 and the S15
/// session sheet: the 6-digit code from the e-mail, "Send a new code" and
/// "Back". A wrong code stays here with an inline error; an expired or locked
/// sign-in goes back to the password step, where [onRestart] shows why.
class SignInCodeForm extends StatefulWidget {
  const SignInCodeForm({required this.pending, required this.onRestart, super.key});

  final PendingSignInCode pending;

  /// Back on the password step, with the issue to show there (null = "Back").
  final ValueChanged<SignInOutcome?> onRestart;

  @override
  State<SignInCodeForm> createState() => _SignInCodeFormState();
}

class _SignInCodeFormState extends State<SignInCodeForm> {
  final TextEditingController _code = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ShakeController _shake = ShakeController();

  late final AppServices _services = context.services;

  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  bool get _complete => _code.text.length == 6;

  Future<void> _confirm() async {
    if (_busy || !_complete) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final SignInOutcome outcome = await _services.session.confirmSignInCode(_code.text);
    if (!mounted) return;
    final AppLocalizations l = AppLocalizations.of(context);
    switch (outcome) {
      case SignInSucceeded() || SignInBlocked():
        return;
      case SignInCodeWrong():
        _code.clear();
        _shake.shake();
        _focus.requestFocus();
        setState(() {
          _busy = false;
          _error = l.signInCodeWrong;
        });
      default:
        setState(() => _busy = false);
        widget.onRestart(outcome);
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() {
      _resending = true;
      _info = null;
    });
    final CodeResendOutcome outcome = await _services.session.resendSignInCode();
    if (!mounted) return;
    final AppLocalizations l = AppLocalizations.of(context);
    setState(() => _resending = false);
    switch (outcome) {
      case CodeResendOutcome.sent:
        _code.clear();
        setState(() {
          _error = null;
          _info = l.signInCodeSent;
        });
        announce(context, l.signInCodeSent);
      case CodeResendOutcome.wait:
        setState(() => _info = l.signInCodeWait);
      case CodeResendOutcome.expired:
        widget.onRestart(const SignInCodeExpired());
      case CodeResendOutcome.offline:
        setState(() => _info = l.signInOfflineBody);
      case CodeResendOutcome.failed:
        setState(() => _info = l.signInErrorServer);
    }
  }

  void _back() {
    _services.session.cancelSignInCode();
    widget.onRestart(null);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final String? info = _info;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ScaledText(l.signInCodeBody(widget.pending.maskedEmail), type: TypeTokens.bodyM, color: c.fgSecondary),
        const SizedBox(height: Space.s6),
        if (info != null) ...<Widget>[
          StatusBanner(tone: BannerTone.info, title: info),
          const SizedBox(height: Space.s4),
        ],
        WaiterTextField(
          kind: TextFieldKind.code,
          label: l.signInCodeLabel,
          controller: _code,
          focusNode: _focus,
          readOnly: _busy,
          errorText: _error,
          shakeController: _shake,
          textInputAction: TextInputAction.done,
          onChanged: (String value) {
            _shake.settle();
            setState(() => _error = null);
            // Six digits (typed or filled in from the e-mail) confirm at once.
            if (value.length == 6) unawaited(_confirm());
          },
          onSubmitted: (_) => unawaited(_confirm()),
        ),
        const SizedBox(height: Space.s6),
        PrimaryButton(
          label: l.signInCodeSubmit,
          semanticLabel: _busy ? l.signInLoading : null,
          status: _busy ? ButtonStatus.loading : ButtonStatus.idle,
          onPressed: _complete && !_busy ? () => unawaited(_confirm()) : null,
        ),
        const SizedBox(height: Space.s2),
        TertiaryButton(label: l.signInCodeResend, onPressed: _busy || _resending ? null : () => unawaited(_resend())),
        TertiaryButton(label: l.commonBack, onPressed: _busy ? null : _back),
      ],
    );
  }
}
