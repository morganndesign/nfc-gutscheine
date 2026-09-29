import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../components/components.dart';
import '../components/support/announce.dart';
import '../core/format/format.dart';
import '../core/platform/feedback_scope.dart';
import '../core/state/session_state.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'access/countdown.dart';
import 'access/forgot_password.dart';
import 'access/sign_in_banner.dart';

/// S02 · Sign in (03a §2; errors A02, A07–A09 of 12 §3.3; layout widths
/// 08 §3.5). Two fields, one button; the restaurant comes from the account.
/// Navigation after the attempt follows the session phase (app navigator).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

/// Loose shape check on submit / blur (03a §2 Field rules); the server
/// decides the rest.
final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final ShakeController _emailShake = ShakeController();
  final ShakeController _passwordShake = ShakeController();

  late final AppServices _services = context.services;

  String? _emailError;
  SignInIssue? _issue;
  bool _noticeDismissed = false;
  bool _busy = false;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_onEmailFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    _services.connectivity.addListener(_onConnectivity);
    final String? last = _services.session.lastEmail;
    if (last != null && last.isNotEmpty) {
      // Prefilled from S04/S15: focus on the password, keyboard up.
      _email.text = last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _passwordFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _services.connectivity.removeListener(_onConnectivity);
    _emailFocus
      ..removeListener(_onEmailFocus)
      ..dispose();
    _passwordFocus.dispose();
    _email.dispose();
    _password.dispose();
    _emailShake.dispose();
    _passwordShake.dispose();
    super.dispose();
  }

  /// An offline banner raised by the attempt clears on reconnect.
  void _onConnectivity() {
    setState(() {
      if (_services.connectivity.isOnline && _issue is SignInOfflineIssue) _issue = null;
    });
  }

  /// Format is checked on blur only after a value was entered.
  void _onEmailFocus() {
    if (!_emailFocus.hasFocus && _email.text.trim().isNotEmpty && !_busy) _checkEmail();
  }

  bool _checkEmail() {
    if (_emailShape.hasMatch(_email.text.trim())) return true;
    if (_emailError == null) {
      // 11 E02: validation error → haptic.error with the M02 shake.
      context.haptic(HapticToken.error);
      _emailShake.shake();
    }
    setState(() => _emailError = AppLocalizations.of(context).signInErrorEmailFormat);
    return false;
  }

  void _edited({bool email = false}) {
    _emailShake.settle();
    _passwordShake.settle();
    setState(() {
      // The field's error stays until its value changes (06 M02).
      if (email) _emailError = null;
      _noticeDismissed = true;
      // banner-out on the next edit; a running countdown stays.
      if (_issue is! SignInThrottledIssue) _issue = null;
    });
  }

  bool get _throttled => _issue is SignInThrottledIssue;

  bool get _canSubmit =>
      !_busy &&
      !_throttled &&
      _services.connectivity.isOnline &&
      _email.text.trim().isNotEmpty &&
      _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit || !_checkEmail()) return;
    setState(() {
      _busy = true;
      _issue = null;
    });
    final SignInOutcome outcome = await _services.session.signIn(_email.text, _password.text);
    if (!mounted || outcome is SignInSucceeded || outcome is SignInBlocked) return;
    setState(() {
      _busy = false;
      _issue = SignInIssue.of(outcome);
    });
    if (outcome is SignInInvalid) {
      // A07: password cleared, e-mail kept and not re-validated.
      _password.clear();
      _passwordFocus.requestFocus();
      _passwordShake.shake();
    }
  }

  void _throttleOver() {
    if (!_throttled) return;
    announce(context, AppLocalizations.of(context).signInAvailable);
    setState(() => _issue = null);
  }

  /// Throttle countdown first, then the environment (offline), then the
  /// last attempt, then a notice from a forced sign-out.
  SignInIssue? _visibleIssue(SignInNotice? notice) {
    final SignInIssue? issue = _issue;
    if (issue is SignInThrottledIssue) return issue;
    if (!_services.connectivity.isOnline) return const SignInOfflineIssue();
    if (issue != null) return issue;
    if (notice != null && !_noticeDismissed) return SignInNoticeIssue(notice);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _services.session,
      builder: (BuildContext context, _) {
        final SignInIssue? issue = _issue;
        if (issue is SignInThrottledIssue) {
          return MonotonicCountdown(
            until: issue.until,
            now: _services.loop.now,
            onFinished: _throttleOver,
            builder: _layout,
          );
        }
        return _layout(context, Duration.zero);
      },
    );
  }

  Widget _layout(BuildContext context, Duration remaining) {
    final AppLocalizations l = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final WaiterLayout layout = context.layout;
    final bool tablet = layout.widthClass.isTablet;
    final bool compact = layout.heightClass.isCompact;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;

    final Widget button = PrimaryButton(
      label: _throttled ? l.signInRetryIn(DateTimeFormat.countdown(remaining)) : l.signInSubmit,
      semanticLabel: _busy ? l.signInLoading : null,
      status: _busy ? ButtonStatus.loading : ButtonStatus.idle,
      onPressed: _canSubmit ? _submit : null,
    );

    // While signing in the fields are read-only, not greyed (03a §2 Loading).
    final Widget form = AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!compact) const _BrandRow(),
          SizedBox(height: compact ? Space.s6 : Space.s8),
          Semantics(
            header: true,
            child: ScaledText(l.signInTitle, type: TypeTokens.titleL, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: Space.s2),
          ScaledText(l.signInSubtitle, type: TypeTokens.bodyM, color: c.fgSecondary),
          const SizedBox(height: Space.s8),
          SignInBannerSlot(issue: _visibleIssue(_services.session.signInNotice), remaining: remaining),
          WaiterTextField(
            kind: TextFieldKind.email,
            label: l.signInEmailLabel,
            controller: _email,
            focusNode: _emailFocus,
            readOnly: _busy,
            errorText: _emailError,
            shakeController: _emailShake,
            onChanged: (_) => _edited(email: true),
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: Space.s3),
          WaiterTextField(
            kind: TextFieldKind.password,
            label: l.signInPasswordLabel,
            controller: _password,
            focusNode: _passwordFocus,
            readOnly: _busy,
            shakeController: _passwordShake,
            onChanged: (_) => _edited(),
            onSubmitted: (_) => unawaited(_submit()),
          ),
          const SizedBox(height: Space.s2),
          Align(
            alignment: AlignmentDirectional.centerStart,
            // The 56-pt target overlaps the margin; its label aligns with
            // the fields.
            child: Transform.translate(
              offset: Offset(
                Directionality.of(context) == TextDirection.ltr
                    ? -ButtonTokens.tertiaryPaddingHorizontal
                    : ButtonTokens.tertiaryPaddingHorizontal,
                0,
              ),
              child: TertiaryButton(
                label: l.signInForgot,
                isLink: true,
                onPressed: () => unawaited(openForgotPassword(context)),
              ),
            ),
          ),
          if (tablet) ...<Widget>[const SizedBox(height: Space.s8), button],
        ],
      ),
    );

    final double bottom = keyboard > 0 ? keyboard + Space.s4 : layout.viewPadding.bottom + layout.ctaBottomPadding;

    return ColoredBox(
      color: c.bgCanvas,
      child: PopScope<Object?>(
        // Back gestures are ignored while signing in.
        canPop: !_busy,
        child: GestureDetector(
          // Tapping outside the fields dismisses the keyboard.
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: EdgeInsets.only(top: layout.viewPadding.top, bottom: tablet ? bottom : 0),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) => SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: layout.margin),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Align(
                          // Tablets centre the block (title → button) in the safe area.
                          alignment: tablet ? Alignment.center : Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: LayoutTokens.maxForm),
                            child: form,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!tablet)
                  Padding(padding: EdgeInsets.fromLTRB(layout.margin, Space.s4, layout.margin, bottom), child: button),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Brand row (03a §2): the 32-pt app mark, leading, centred in a 56-pt row.
class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Sizes.targetMin,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: WaiterIconView.mark(
          WaiterIcon.cardArcs,
          dimension: IconSize.s32.size,
          strokeWidth: IconSize.s32.stroke,
          accentColor: context.colors.accentSaffron,
        ),
      ),
    );
  }
}
