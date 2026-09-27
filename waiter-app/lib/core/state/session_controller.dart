import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_failure.dart';
import '../api/models.dart';
import '../api/waiter_api.dart';
import '../diagnostics/diagnostic_log.dart';
import '../format/support_code.dart';
import '../platform/biometrics_service.dart';
import '../platform/feedback_service.dart';
import '../storage/recent_store.dart';
import '../storage/secure_store.dart';
import '../storage/settings_store.dart';
import '../tokens/tokens.dart';
import 'business_calendar.dart';
import 'client_identity.dart';
import 'clock.dart';
import 'session_state.dart';
import 'startup_problem.dart';

/// Signals from the access layer to the loop.
enum SessionSignal {
  /// Token and Recent are gone; the loop returns to its initial state.
  signedOut,

  /// Background > 15 min (N9) or business-day rollover: card context and
  /// pending attempts are dropped.
  contextDropped,

  /// The waiter signed in again on the S15 session sheet.
  reauthenticated,
}

/// Texts of the OS biometric prompt (`biometrics.reason`, Android subtitle).
typedef BiometricPromptTexts = ({String reason, String androidTitle, String androidSubtitle});

/// Access, session and account state (02 §4.3, §4.5; 03a S01–S04, S15, S17;
/// 09 §7.5–§7.6; 12 §3.3). Global handlers for 401, device revoked,
/// restaurant suspended, forbidden, locked and deactivated live here and can
/// interrupt any state of the loop.
class SessionController extends ChangeNotifier {
  SessionController({
    required WaiterApi api,
    required SecretStore secrets,
    required SettingsStore settings,
    required RecentStore recent,
    required BiometricsService biometrics,
    required FeedbackService feedback,
    required AppClientIdentity identity,
    required MonotonicClock clock,
    required BusinessCalendar calendar,
    required String appVersion,
    required String platform,
    required String deviceName,
    DiagnosticLog? log,
  })  : _api = api,
        _secrets = secrets,
        _settings = settings,
        _recent = recent,
        _biometrics = biometrics,
        _feedback = feedback,
        _identity = identity,
        _clock = clock,
        _calendar = calendar,
        _appVersion = appVersion,
        _platform = platform,
        _deviceName = deviceName,
        _log = log;

  static const String _tokenKey = 'token';
  static const String _profileKey = 'profile';
  static const String _enrollmentKey = 'biometric_enrollment';

  /// Background longer than this discards the layer stack (N9).
  static const Duration backgroundLimit = Duration(minutes: 15);

  /// `/app/config` is refreshed at most this often on resume (09 §9.2).
  static const Duration configInterval = Duration(minutes: 5);

  /// A link opened while signed out or locked is kept this long (02 §4.3).
  static const Duration pendingLinkLifetime = Duration(seconds: 120);

  final WaiterApi _api;
  final SecretStore _secrets;
  final SettingsStore _settings;
  final RecentStore _recent;
  final BiometricsService _biometrics;
  final FeedbackService _feedback;
  final AppClientIdentity _identity;
  final MonotonicClock _clock;
  final BusinessCalendar _calendar;
  final String _appVersion;
  final String _platform;
  final String _deviceName;
  final DiagnosticLog? _log;

  final StreamController<SessionSignal> _signals = StreamController<SessionSignal>.broadcast();
  Stream<SessionSignal> get signals => _signals.stream;

  AccessPhase _phase = AccessPhase.launching;
  AccessPhase get phase => _phase;

  SessionUser? _user;
  SessionUser? get user => _user;

  BlockedKind? _blocked;
  BlockedKind? get blocked => _blocked;

  String? _blockedSupportCode;
  String? get blockedSupportCode => _blockedSupportCode;

  String? _blockedRequestId;

  /// Full `X-Request-Id` behind [blockedSupportCode] (long-press copy).
  String? get blockedRequestId => _blockedRequestId;

  Duration? _lockedUntil;

  /// A06 countdown end (monotonic); null when not locked.
  Duration? get lockedUntil => _lockedUntil;

  SessionContext? _expired;

  /// Non-null while the S15 session sheet is shown over the current layer.
  SessionContext? get expired => _expired;

  String? _maintenanceNotice;
  bool _maintenanceDismissed = false;

  /// A12: server notice for the S05 banner (hidden until the next cold start
  /// once dismissed).
  String? get maintenanceNotice => _maintenanceDismissed ? null : _maintenanceNotice;

  SignInNotice? _signInNotice;
  SignInNotice? get signInNotice => _signInNotice;

  BiometricKind _biometricKind = BiometricKind.none;
  BiometricKind get biometricKind => _biometricKind;

  bool _deferredIntro = false;

  String? _pendingLink;
  Duration? _pendingLinkAt;

  Duration? _backgroundAt;
  Duration? _configAt;

  StartupProblem? _startupProblem;

  /// Why the server was not reachable at launch (phase `startupProblem`).
  StartupProblem? get startupProblem => _startupProblem;

  /// Counts launches, so a late result of an abandoned launch is ignored.
  int _launch = 0;

  /// A launch that has not decided after this long shows the startup problem
  /// screen instead of an endless splash (a platform call that never answers).
  static const Duration launchWatchdog = Duration(seconds: 20);
  Timer? _rolloverTimer;

  bool get isIos => _platform == 'ios';

  String? get lastEmail => _settings.lastEmail;

  bool get biometricsEnabled => _settings.biometricsEnabled;

  // ---------------------------------------------------------------- launch

  /// Launching (S01): token, cached profile and `/app/config` (≤ 2 s,
  /// non-blocking on failure when signed in), then the access decision of
  /// 02 §4.3. Signed out and the server unreachable → `startupProblem` with
  /// the reason. Never stays on the splash: any exception, and a launch that
  /// has not decided after [launchWatchdog], also end on that screen.
  Future<void> start() async {
    final int launch = ++_launch;
    _startupProblem = null;
    _log?.record('state', 'Launching');
    final Timer watchdog = _clock.timer(launchWatchdog, () {
      if (launch != _launch || _phase != AccessPhase.launching) return;
      _log?.record('launch.watchdog');
      _launch++;
      _startupProblem = const StartupProblem(StartupProblemKind.unknown, detail: 'start did not finish within 20 s');
      _go(AccessPhase.startupProblem);
    });
    try {
      await _decide(launch);
    } on Object catch (e) {
      _log?.record('launch.failed', '$e');
      if (launch == _launch && _phase == AccessPhase.launching) {
        _startupProblem = StartupProblem.fromError(e);
        _go(AccessPhase.startupProblem);
      }
    } finally {
      watchdog.cancel();
    }
  }

  Future<void> _decide(int launch) async {
    final Future<({AppConfigData? config, StartupProblem? problem})> config = _fetchConfig();
    _biometricKind = await _biometrics.kind(isIos: isIos);

    final String? token = await _secrets.read(_tokenKey);
    _identity.token = token;
    _user = await _readProfile();

    final ({AppConfigData? config, StartupProblem? problem}) result = await config;
    if (launch != _launch) return;
    final AppConfigData? cfg = result.config;
    if (cfg != null && cfg.updateRequired) {
      _go(AccessPhase.updateRequired);
      unawaited(_feedbackBlocked());
      return;
    }

    if (token == null || _user == null) {
      await _clearAccount();
      if (launch != _launch) return;
      if (result.problem != null) {
        _startupProblem = result.problem;
        _go(AccessPhase.startupProblem);
      } else {
        _go(AccessPhase.signedOut);
      }
      return;
    }

    await _loadRecent();
    if (launch != _launch) return;
    if (_settings.biometricsEnabled) {
      _go(AccessPhase.locked);
    } else {
      _go(AccessPhase.active);
      unawaited(refreshUser());
    }
  }

  /// "Try again" on the startup problem screen (also on foreground and when
  /// the network returns).
  Future<void> retryStart() async {
    if (_phase != AccessPhase.startupProblem) return;
    _go(AccessPhase.launching);
    await start();
  }

  /// The server was changed (development / staging): the session belongs to
  /// the old server, so sign out locally and launch again.
  Future<void> restartForNewServer() async {
    _launch++;
    _go(AccessPhase.launching);
    _configAt = null;
    _maintenanceNotice = null;
    await _clearAccount();
    await start();
  }

  Future<({AppConfigData? config, StartupProblem? problem})> _fetchConfig() async {
    try {
      final AppConfigData cfg = await _api.appConfig(platform: _platform, version: _appVersion);
      _configAt = _clock.now();
      _maintenanceNotice = cfg.maintenanceNotice;
      return (config: cfg, problem: null);
    } on ApiFailure catch (e) {
      _log?.record('config.failed', '$e');
      return (config: null, problem: StartupProblem.fromApiFailure(e));
    } on Object catch (e) {
      // A JSON object of another shape: not the GiftCard Pro API.
      _log?.record('config.invalid', '$e');
      return (config: null, problem: StartupProblem(StartupProblemKind.invalidResponse, detail: '$e'));
    }
  }

  Future<SessionUser?> _readProfile() async {
    final String? raw = await _secrets.read(_profileKey);
    if (raw == null) return null;
    try {
      return SessionUser.fromJson((jsonDecode(raw) as Map<Object?, Object?>).cast<String, Object?>());
    } on Object {
      return null;
    }
  }

  // --------------------------------------------------------------- sign-in

  /// S02 sign-in (`POST /auth/token`).
  Future<SignInOutcome> signIn(String email, String password) async {
    final SignInOutcome outcome = await _authenticate(email.trim(), password);
    if (outcome is! SignInSucceeded) return outcome;

    _signInNotice = null;
    if (!_settings.biometricsOffered && _biometricKind != BiometricKind.none) {
      _go(AccessPhase.onboardingBiometrics);
    } else {
      _afterBiometricsStep();
    }
    return outcome;
  }

  /// S15 session sheet: signs in again with the stored e-mail (A01). The layer
  /// stack underneath is kept (lookup → S05, redeem → S07 with amount).
  Future<SignInOutcome> reauthenticate(String password) async {
    final String email = _settings.lastEmail ?? _user?.email ?? '';
    final String? previousUser = _user?.id;
    final SignInOutcome outcome = await _authenticate(email, password);
    if (outcome is SignInSucceeded) {
      _expired = null;
      if (previousUser != _user?.id) {
        _signals.add(SessionSignal.signedOut);
      } else {
        _signals.add(SessionSignal.reauthenticated);
      }
      notifyListeners();
    }
    return outcome;
  }

  Future<SignInOutcome> _authenticate(String email, String password) async {
    try {
      final SignInResult result = await _api.signIn(
        email: email,
        password: password,
        deviceId: _identity.deviceId,
        deviceName: _deviceName,
        platform: _platform,
      );
      if (!result.user.canRedeem || result.user.restaurant == null) {
        _feedback.haptic(HapticToken.error);
        return const SignInNoPermission();
      }
      final bool userChanged = _user != null && _user!.id != result.user.id;
      _identity.token = result.token;
      _user = result.user;
      _settings.lastEmail = email;
      await _secrets.write(_tokenKey, result.token);
      await _secrets.write(_profileKey, jsonEncode(result.user.toJson()));
      if (userChanged) {
        await _recent.clear();
        _settings.biometricsEnabled = false;
      }
      await _loadRecent();
      _log?.record('auth.signedIn');
      return const SignInSucceeded();
    } on ApiUnauthorized catch (e) {
      if (e.isDeactivated) {
        _block(BlockedKind.deactivated, e.requestId, clear: true);
        return const SignInBlocked();
      }
      _feedback.haptic(HapticToken.error);
      return const SignInInvalid();
    } on ApiRejected catch (e) {
      switch (e.code) {
        case 'DEVICE_REVOKED':
          _block(BlockedKind.deviceRevoked, e.requestId, clear: true);
          return const SignInBlocked();
        case 'RESTAURANT_SUSPENDED':
          _block(BlockedKind.suspended, e.requestId);
          return const SignInBlocked();
        case 'ACCOUNT_LOCKED':
          _lockedUntil = _clock.now() + (e.retryAfter ?? const Duration(minutes: 15));
          _block(BlockedKind.locked, e.requestId);
          return const SignInBlocked();
        case 'FORBIDDEN':
          _feedback.haptic(HapticToken.error);
          return const SignInNoPermission();
      }
      if (e.status == 429) {
        _feedback.haptic(HapticToken.warning);
        return SignInThrottled(_clock.now() + (e.retryAfter ?? const Duration(seconds: 60)));
      }
      _feedback.haptic(HapticToken.error);
      return const SignInInvalid();
    } on ApiTransportFailure {
      _feedback.haptic(HapticToken.warning);
      return const SignInOffline();
    } on ApiFailure catch (e) {
      _feedback.haptic(HapticToken.warning);
      return SignInServerError(requestId: e.requestId);
    }
  }

  // ------------------------------------------------------------ onboarding

  /// S03 "Enable": shows the OS prompt once; on success biometrics gate the
  /// app from now on.
  Future<BiometricResult> enableBiometrics(BiometricPromptTexts texts) async {
    final BiometricOutcome outcome = await _biometrics.authenticate(
      reason: texts.reason,
      androidTitle: texts.androidTitle,
      androidSubtitle: texts.androidSubtitle,
    );
    switch (outcome) {
      case BiometricOutcome.success:
        await _secrets.write(_enrollmentKey, await _biometrics.enrollment() ?? '');
        _settings
          ..biometricsEnabled = true
          ..biometricsOffered = true;
        _afterBiometricsStep();
        return BiometricResult.success;
      case BiometricOutcome.notEnrolled:
        return BiometricResult.notEnrolled;
      case BiometricOutcome.lockedOut:
        return BiometricResult.lockedOut;
      case BiometricOutcome.failed:
      case BiometricOutcome.enrollmentChanged:
        return BiometricResult.failed;
    }
  }

  /// S03 "Not now".
  void skipBiometrics() {
    _settings.biometricsOffered = true;
    _afterBiometricsStep();
  }

  void _afterBiometricsStep() {
    if (_settings.introDone) {
      _go(AccessPhase.active);
    } else if (hasPendingLink) {
      // 02 §4.3: S17 is deferred to the next time S05 is shown.
      _deferredIntro = true;
      _go(AccessPhase.active);
    } else {
      _go(AccessPhase.onboardingIntro);
    }
  }

  /// S17 done or skipped.
  void finishIntro() {
    _settings.introDone = true;
    _deferredIntro = false;
    _go(AccessPhase.active);
  }

  /// 03a S17: the intro counts as shown once its first card rendered.
  void markIntroShown() => _settings.introDone = true;

  /// Called by the loop whenever S05 becomes visible.
  void readyShown() {
    if (_deferredIntro && _phase == AccessPhase.active && !_settings.introDone) {
      _deferredIntro = false;
      _go(AccessPhase.onboardingIntro);
    }
  }

  // ---------------------------------------------------------------- unlock

  /// S04 — biometric prompt (shown automatically on entry).
  Future<BiometricResult> unlock(BiometricPromptTexts texts) async {
    final String? expected = await _secrets.read(_enrollmentKey);
    final BiometricOutcome outcome = await _biometrics.authenticate(
      reason: texts.reason,
      androidTitle: texts.androidTitle,
      androidSubtitle: texts.androidSubtitle,
      expectedEnrollment: expected,
    );
    switch (outcome) {
      case BiometricOutcome.success:
        _go(AccessPhase.active);
        unawaited(refreshUser());
        return BiometricResult.success;
      case BiometricOutcome.enrollmentChanged:
        // P13: a new face or finger was added — the password is required.
        _signInNotice = SignInNotice.biometricsChanged;
        _settings.biometricsEnabled = false;
        await _signOutLocally();
        return BiometricResult.failed;
      case BiometricOutcome.lockedOut:
        _feedback.haptic(HapticToken.warning);
        return BiometricResult.lockedOut;
      case BiometricOutcome.notEnrolled:
        return BiometricResult.notEnrolled;
      case BiometricOutcome.failed:
        return BiometricResult.failed;
    }
  }

  /// S04 "Use password" (Locked → SignedOut).
  Future<void> usePassword() => _signOutLocally();

  // -------------------------------------------------------------- sign-out

  /// S14 sign-out, confirmed in the dialog (E65). Token, Recent and pending
  /// attempts are deleted even if the request fails (09 §9.2).
  Future<void> signOut() async {
    try {
      await _api.signOut();
    } on ApiFailure catch (e) {
      _log?.record('signOut.failed', '$e');
    }
    _signInNotice = null;
    await _signOutLocally();
  }

  Future<void> _signOutLocally() async {
    await _clearAccount();
    _go(AccessPhase.signedOut);
  }

  Future<void> _clearAccount() async {
    _identity.token = null;
    _user = null;
    _expired = null;
    _rolloverTimer?.cancel();
    await _secrets.delete(_tokenKey);
    await _secrets.delete(_profileKey);
    await _recent.clear();
    await _settings.resetAccount();
    _signals.add(SessionSignal.signedOut);
  }

  // ---------------------------------------------------------------- blocked

  /// S15 "Check again" for forbidden / suspended (`GET /auth/me`).
  Future<RecheckOutcome> recheck() async {
    try {
      final SessionUser user = await _api.me();
      if (!user.canRedeem) {
        _feedback.haptic(HapticToken.warning);
        return RecheckOutcome.stillBlocked;
      }
      await _storeUser(user);
      _go(AccessPhase.active);
      return RecheckOutcome.cleared;
    } on ApiTransportFailure {
      return RecheckOutcome.offline;
    } on ApiFailure catch (e) {
      final BlockedKind? before = _blocked;
      handleFailure(e, SessionContext.lookup);
      if (_blocked == before) _feedback.haptic(HapticToken.warning);
      return RecheckOutcome.stillBlocked;
    }
  }

  /// S15 "Sign in" / "Back to sign in" (device revoked, locked over,
  /// deactivated, forbidden).
  Future<void> leaveBlocked() async {
    _blocked = null;
    _blockedSupportCode = null;
    _blockedRequestId = null;
    _lockedUntil = null;
    await _signOutLocally();
  }

  void _block(BlockedKind kind, String requestId, {bool clear = false}) {
    _blocked = kind;
    final bool withCode = kind != BlockedKind.locked && requestId.isNotEmpty;
    _blockedSupportCode = withCode ? SupportCode.fromRequestId(requestId) : null;
    _blockedRequestId = withCode ? requestId : null;
    _expired = null;
    // E03 / E08: account locked, revoked, suspended, forbidden, deactivated.
    _feedback.haptic(HapticToken.error);
    if (clear) {
      _identity.token = null;
      _rolloverTimer?.cancel();
      unawaited(_secrets.delete(_tokenKey));
      unawaited(_secrets.delete(_profileKey));
      unawaited(_recent.clear());
    }
    _signals.add(SessionSignal.signedOut);
    _go(AccessPhase.blocked);
  }

  /// Global handlers (02 §4.5.3, 12 §3.3). Returns true when the failure was
  /// an access problem and has been handled here.
  bool handleFailure(ApiFailure failure, SessionContext context) {
    switch (failure) {
      case ApiUnauthorized(:final bool isDeactivated, :final String requestId):
        if (isDeactivated) {
          _block(BlockedKind.deactivated, requestId, clear: true);
          return true;
        }
        if (_phase == AccessPhase.active || _phase == AccessPhase.locked) {
          if (_expired == null) {
            _expired = context;
            _feedback.haptic(HapticToken.warning);
            _log?.record('state', 'SessionExpired ${context.name}');
            notifyListeners();
          }
        }
        return true;
      case ApiRejected(:final String code, :final String requestId, :final Duration? retryAfter):
        switch (code) {
          case 'DEVICE_REVOKED':
            _block(BlockedKind.deviceRevoked, requestId, clear: true);
            return true;
          case 'RESTAURANT_SUSPENDED':
            _block(BlockedKind.suspended, requestId);
            return true;
          case 'FORBIDDEN':
            _block(BlockedKind.forbidden, requestId);
            return true;
          case 'ACCOUNT_LOCKED':
            _lockedUntil = _clock.now() + (retryAfter ?? const Duration(minutes: 15));
            _block(BlockedKind.locked, requestId);
            return true;
        }
        return false;
      case ApiServerFault() || ApiTransportFailure() || ApiCancelled():
        return false;
    }
  }

  Future<void> _feedbackBlocked() async => _feedback.haptic(HapticToken.error);

  // -------------------------------------------------------------- lifecycle

  void onBackground() {
    _backgroundAt = _clock.now();
  }

  Future<void> onForeground() async {
    final Duration? since = _backgroundAt == null ? null : _clock.now() - _backgroundAt!;
    _backgroundAt = null;

    if (since != null && since > backgroundLimit) {
      _signals.add(SessionSignal.contextDropped);
      if (_phase == AccessPhase.active && _settings.biometricsEnabled) _go(AccessPhase.locked);
    }

    if (_phase == AccessPhase.startupProblem) {
      await retryStart();
      return;
    }

    if (_configAt == null || _clock.now() - _configAt! >= configInterval) {
      final AppConfigData? cfg = (await _fetchConfig()).config;
      if (cfg != null && cfg.updateRequired) {
        _go(AccessPhase.updateRequired);
        return;
      }
      notifyListeners();
    }

    if (_phase == AccessPhase.active) await refreshUser();
    await _rolloverIfNeeded();
  }

  /// `/auth/me` in the background: settings, permissions, restaurant.
  Future<void> refreshUser() async {
    try {
      final SessionUser user = await _api.me();
      if (!user.canRedeem) {
        _block(BlockedKind.forbidden, '');
        return;
      }
      await _storeUser(user);
      notifyListeners();
    } on ApiFailure catch (e) {
      handleFailure(e, SessionContext.lookup);
    }
  }

  Future<void> _storeUser(SessionUser user) async {
    _user = user;
    await _secrets.write(_profileKey, jsonEncode(user.toJson()));
  }

  /// S14: the device name as registered by the backend (renamed only in the
  /// dashboard). Null when it cannot be loaded right now.
  Future<String?> currentDeviceName() async {
    try {
      final String name = (await _api.currentDevice()).name;
      return name.isEmpty ? null : name;
    } on ApiFailure catch (e) {
      handleFailure(e, SessionContext.lookup);
      return null;
    }
  }

  void dismissMaintenance() {
    _maintenanceDismissed = true;
    notifyListeners();
  }

  // ------------------------------------------------------------------ links

  /// A card link while signed out or locked is kept for 120 s (02 §4.3).
  void keepLink(String url) {
    _pendingLink = url;
    _pendingLinkAt = _clock.now();
    notifyListeners();
  }

  bool get hasPendingLink =>
      _pendingLink != null && _pendingLinkAt != null && _clock.now() - _pendingLinkAt! <= pendingLinkLifetime;

  /// The pending link, once, if it is still fresh.
  String? takePendingLink() {
    final String? link = hasPendingLink ? _pendingLink : null;
    _pendingLink = null;
    _pendingLinkAt = null;
    return link;
  }

  // ------------------------------------------------------------ business day

  /// Current business-day key in the restaurant zone.
  String businessDayKey([DateTime? at]) =>
      _calendar.dayOf(_zone, (at ?? DateTime.now()).toUtc()).key;

  String get _zone => _user?.restaurant?.timezone ?? 'Europe/Vienna';

  BusinessCalendar get calendar => _calendar;

  Future<void> _loadRecent() async {
    final SessionUser? user = _user;
    if (user == null) return;
    await _recent.load(userId: user.id, businessDay: businessDayKey());
    _scheduleRollover();
  }

  void _scheduleRollover() {
    _rolloverTimer?.cancel();
    final DateTime now = DateTime.now().toUtc();
    final Duration until = _calendar.nextRollover(_zone, now).difference(now);
    _rolloverTimer = Timer(until + const Duration(seconds: 1), () => unawaited(_rolloverIfNeeded()));
  }

  /// 04:00 rollover (09 §4.5): Recent cleared, pending attempts discarded.
  Future<void> _rolloverIfNeeded() async {
    if (_user == null) return;
    final String day = businessDayKey();
    if (_recent.entries.any((RecentEntry e) => e.businessDay != day)) {
      await _recent.keepOnly(day);
      _signals.add(SessionSignal.contextDropped);
    }
    _scheduleRollover();
  }

  void _go(AccessPhase next) {
    if (next != AccessPhase.blocked) {
      _blocked = null;
      _blockedSupportCode = null;
      _blockedRequestId = null;
    }
    _phase = next;
    _log?.record('state', next.name);
    notifyListeners();
  }

  @override
  void dispose() {
    _rolloverTimer?.cancel();
    unawaited(_signals.close());
    super.dispose();
  }
}
