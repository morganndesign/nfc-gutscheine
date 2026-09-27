import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_scope.dart';
import '../components/components.dart';
import '../components/support/announce.dart';
import '../core/format/format.dart';
import '../core/state/session_controller.dart';
import '../core/state/session_state.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'access/countdown.dart';
import 'access/forgot_password.dart';
import 'access/sign_in_banner.dart';

// ---------------------------------------------------------------- 10.1 sheet

/// S15 · 10.1 Session expired (03a §10.1, 12 A01, 06 M24): the content and
/// frame of the non-dismissible sheet that `SessionSheetHost` places at the
/// bottom of the screen over a scrim. The e-mail is shown, the password is
/// entered again; errors behave like S02. The layer underneath is kept.
class SessionExpiredSheet extends StatefulWidget {
  const SessionExpiredSheet({super.key});

  @override
  State<SessionExpiredSheet> createState() => _SessionExpiredSheetState();
}

class _SessionExpiredSheetState extends State<SessionExpiredSheet> {
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  final ShakeController _shake = ShakeController();

  late final AppServices _services = context.services;

  SignInIssue? _issue;
  bool _busy = false;
  bool _listening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listening) return;
    _listening = true;
    _services.connectivity.addListener(_onConnectivity);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) announce(context, AppLocalizations.of(context).sessionExpired, assertive: true);
    });
  }

  @override
  void dispose() {
    _services.connectivity.removeListener(_onConnectivity);
    _password.dispose();
    _passwordFocus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onConnectivity() {
    setState(() {
      if (_services.connectivity.isOnline && _issue is SignInOfflineIssue) _issue = null;
    });
  }

  bool get _throttled => _issue is SignInThrottledIssue;

  bool get _canSubmit => !_busy && !_throttled && _services.connectivity.isOnline && _password.text.isNotEmpty;

  void _edited() {
    _shake.settle();
    setState(() {
      if (!_throttled) _issue = null;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _issue = null;
    });
    final SignInOutcome outcome = await _services.session.reauthenticate(_password.text);
    if (!mounted || outcome is SignInSucceeded || outcome is SignInBlocked) return;
    setState(() {
      _busy = false;
      _issue = SignInIssue.of(outcome);
    });
    if (outcome is SignInInvalid) {
      _password.clear();
      _passwordFocus.requestFocus();
      _shake.shake();
    }
  }

  void _throttleOver() {
    if (!_throttled) return;
    announce(context, AppLocalizations.of(context).lockedOver);
    setState(() => _issue = null);
  }

  @override
  Widget build(BuildContext context) {
    final SignInIssue? issue = _issue;
    if (issue is SignInThrottledIssue) {
      return MonotonicCountdown(
        until: issue.until,
        now: _services.loop.now,
        onFinished: _throttleOver,
        builder: _sheet,
      );
    }
    return _sheet(context, Duration.zero);
  }

  Widget _sheet(BuildContext context, Duration remaining) {
    final AppLocalizations l = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final WaiterLayout layout = context.layout;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final SessionController session = _services.session;
    final String email = session.lastEmail ?? session.user?.email ?? '';
    final SignInIssue? shown = _services.connectivity.isOnline || _throttled ? _issue : const SignInOfflineIssue();

    // While signing in the field is read-only, not greyed (as on S02).
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ScaledText(l.sessionExpiredBody, type: TypeTokens.bodyM, color: c.fgSecondary, textAlign: TextAlign.center),
        const SizedBox(height: Space.s6),
        SignInBannerSlot(issue: shown, remaining: remaining),
        if (email.isNotEmpty) ...<Widget>[
          Semantics(
            container: true,
            label: '${l.signInEmailLabel}, $email',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ScaledText(l.signInEmailLabel, type: TypeTokens.caption, color: c.fgSecondary),
                const SizedBox(height: TextFieldTokens.labelGap),
                ScaledText(email, type: TypeTokens.bodyL, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(height: Space.s3),
        ],
        AutofillGroup(
          child: WaiterTextField(
            kind: TextFieldKind.password,
            label: l.signInPasswordLabel,
            controller: _password,
            focusNode: _passwordFocus,
            readOnly: _busy,
            shakeController: _shake,
            onChanged: (_) => _edited(),
            onSubmitted: (_) => unawaited(_submit()),
          ),
        ),
        const SizedBox(height: Space.s6),
        PrimaryButton(
          label: _throttled ? l.lockedButton(DateTimeFormat.countdown(remaining)) : l.sessionExpiredAction,
          semanticLabel: _busy ? l.signInLoading : null,
          status: _busy ? ButtonStatus.loading : ButtonStatus.idle,
          onPressed: _canSubmit ? () => unawaited(_submit()) : null,
        ),
      ],
    );

    // Content height, capped at the large detent above the keyboard.
    final double maxHeight = layout.size.height - layout.viewPadding.top - SheetTokens.largeTopGap - keyboard;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: layout.widthClass.isTablet ? LayoutTokens.maxSheet : double.infinity,
          ),
          child: WaiterBottomSheet(
            title: l.sessionExpired,
            onClose: null,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                layout.margin,
                0,
                layout.margin,
                (keyboard > 0 ? 0 : layout.viewPadding.bottom) + Space.s4,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------- 10.2–10.5 full screens

/// "Check again" can be tapped at most once per 3 s (03a §10 Micro-interactions).
const Duration _recheckSpacing = Duration(seconds: 3);

/// S15 full-screen account states (03a §10.2–10.5; 12 A03–A06, A10) on the
/// ProblemScreen template (05 §4.6): forbidden, device revoked, restaurant
/// suspended, account locked (live countdown on the monotonic clock) and
/// account deactivated. No back into Ready; the only ways on are the
/// actions.
class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  /// Kept while the page fades out after the session left S15.
  BlockedKind? _kind;
  String? _supportCode;
  String? _requestId;

  bool _checking = false;

  /// "Check again" found no connection: `offline.title` below the button.
  bool _offline = false;
  Duration? _lastCheck;

  /// Full wait of the current lock (the countdown ring's 100 %).
  Duration? _lockedUntil;
  Duration _lockTotal = Duration.zero;

  Future<void> _recheck(String body) async {
    final AppServices services = context.services;
    final Duration now = services.loop.now();
    final Duration? last = _lastCheck;
    if (_checking || (last != null && now - last < _recheckSpacing)) return;
    _lastCheck = now;
    setState(() {
      _checking = true;
      _offline = false;
    });
    final RecheckOutcome outcome = await services.session.recheck();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _offline = outcome == RecheckOutcome.offline;
    });
    // Still blocked: the body is announced again (the session plays
    // haptic.warning); offline: the caption announces itself.
    if (outcome == RecheckOutcome.stillBlocked) announce(context, body, assertive: true);
  }

  void _leave() => unawaited(context.services.session.leaveBlocked());

  void _lockOver() {
    announce(context, AppLocalizations.of(context).lockedOver);
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.services;
    return ListenableBuilder(
      listenable: services.session,
      builder: (BuildContext context, _) {
        final SessionController session = services.session;
        final BlockedKind? kind = session.blocked;
        if (kind != null) {
          _kind = kind;
          _supportCode = session.blockedSupportCode;
          _requestId = session.blockedRequestId;
        }
        final BlockedKind? shown = _kind;
        if (shown == null) return ColoredBox(color: context.colors.bgCanvas);
        final AppLocalizations l = AppLocalizations.of(context);
        final ProblemAction backToSignIn = ProblemAction(l.commonBackToSignIn, _leave);
        return switch (shown) {
          BlockedKind.locked => _locked(context, session.lockedUntil ?? services.loop.now()),
          BlockedKind.forbidden => _problem(
            shown,
            l.forbiddenTitle,
            l.forbiddenBody,
            _checkAgain(l, l.forbiddenBody),
            backToSignIn,
          ),
          BlockedKind.deviceRevoked => _problem(
            shown,
            l.deviceRevokedTitle,
            l.deviceRevokedBody,
            ProblemAction(l.deviceRevokedAction, _leave),
          ),
          BlockedKind.suspended => _problem(
            shown,
            l.suspendedTitle,
            l.suspendedBody,
            _checkAgain(l, l.suspendedBody),
            ProblemAction(l.menuSignOut, _leave),
          ),
          BlockedKind.deactivated => _problem(shown, l.deactivatedTitle, l.deactivatedBody, backToSignIn),
        };
      },
    );
  }

  Widget _problem(BlockedKind kind, String title, String body, ProblemAction primary, [ProblemAction? tertiary]) {
    final String? code = _requestId == null ? null : _supportCode;
    return ProblemScreen(
      key: ValueKey<BlockedKind>(kind),
      family: ProblemFamily.account,
      visual: const ProblemVisual.illustration(WaiterIllustration.cardLocked),
      title: title,
      body: body,
      primary: primary,
      tertiary: tertiary,
      supportCode: code,
      requestId: _requestId,
      caption: _offline ? AppLocalizations.of(context).offlineTitle : null,
    );
  }

  ProblemAction _checkAgain(AppLocalizations l, String body) => ProblemAction(
    l.commonCheckAgain,
    () => unawaited(_recheck(body)),
    status: _checking ? ButtonStatus.loading : ButtonStatus.idle,
  );

  /// 10.4 / A06: countdown from `lockedUntil`; at 0 `locked.over` is
  /// announced and the waiter is back on S02.
  Widget _locked(BuildContext context, Duration until) {
    final AppServices services = context.services;
    if (_lockedUntil != until) {
      _lockedUntil = until;
      final Duration left = until - services.loop.now();
      _lockTotal = left.isNegative ? Duration.zero : left;
    }
    return MonotonicCountdown(
      until: until,
      now: services.loop.now,
      onFinished: _lockOver,
      builder: (BuildContext context, Duration remaining) {
        final AppLocalizations l = AppLocalizations.of(context);
        final String time = DateTimeFormat.countdown(remaining);
        return ProblemScreen(
          key: const ValueKey<BlockedKind>(BlockedKind.locked),
          family: ProblemFamily.account,
          visual: const ProblemVisual.illustration(WaiterIllustration.wait),
          countdown: ProblemCountdown(remaining: remaining, total: _lockTotal),
          title: l.lockedTitle,
          body: l.lockedBody(time),
          primary: ProblemAction(l.lockedButton(time), null),
          // Resetting the password is the way out.
          tertiary: ProblemAction(l.signInForgot, () => unawaited(openForgotPassword(context))),
        );
      },
    );
  }
}

// --------------------------------------------------------- 10.6 update

/// S15 · 10.6 Update required (03a §10.6, 12 A11): blocking, no back, no
/// dismiss; "Update now" opens the store listing. If the store cannot be
/// opened the button stays and nothing else happens.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  Future<void> _openStore(AppServices services) async {
    final Uri? store = await _storeUri(services);
    if (store == null) {
      services.log.record('update.noStoreUrl');
      return;
    }
    try {
      if (!await launchUrl(store, mode: LaunchMode.externalApplication)) {
        services.log.record('update.notOpened', '$store');
      }
    } on PlatformException catch (e) {
      services.log.record('update.failed', '$e');
    }
  }

  /// iOS: the App Store product page from the build configuration; Android:
  /// the configured Play listing or the listing of this package.
  static Future<Uri?> _storeUri(AppServices services) async {
    if (services.session.isIos) {
      final String? appStore = services.environment.appStoreUrl;
      return appStore == null ? null : Uri.parse(appStore);
    }
    final String? playStore = services.environment.playStoreUrl;
    if (playStore != null) return Uri.parse(playStore);
    final PackageInfo package = await PackageInfo.fromPlatform();
    return Uri.https('play.google.com', '/store/apps/details', <String, String>{'id': package.packageName});
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppServices services = context.services;
    return ProblemScreen(
      family: ProblemFamily.account,
      visual: const ProblemVisual.icon(WaiterIcon.circleArrowUp),
      title: l.updateTitle,
      body: l.updateBody,
      primary: ProblemAction(l.updateAction, () => unawaited(_openStore(services))),
    );
  }
}
