import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../components/components.dart';
import '../core/config/environment.dart';
import '../core/config/environment_controller.dart';
import '../core/format/support_code.dart';
import '../core/state/session_state.dart';
import '../core/state/startup_problem.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';

/// Startup problem (12 §5.2): instead of an endless splash, the reason the app
/// could not start or reach its server — with the server address and the
/// technical detail in small print, "Try again" and, in development and
/// staging builds, "Change server".
class StartupProblemView extends StatelessWidget {
  const StartupProblemView({
    required this.problem,
    required this.environment,
    required this.onRetry,
    super.key,
    this.online = true,
    this.retrying = false,
    this.onChangeServer,
  });

  final StartupProblem problem;

  /// Null when the build configuration itself could not be read.
  final AppEnvironment? environment;

  /// False → the offline copy (a network problem is then the likely cause).
  final bool online;
  final bool retrying;
  final VoidCallback onRetry;
  final VoidCallback? onChangeServer;

  StartupProblemKind get _kind {
    final StartupProblemKind kind = problem.kind;
    final bool networkish = kind != StartupProblemKind.configuration && kind != StartupProblemKind.storage;
    return !online && networkish ? StartupProblemKind.offline : kind;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppEnvironment? env = environment;
    final String host = env?.apiHost ?? '—';
    final StartupProblemKind kind = _kind;

    final (String title, String body) = switch (kind) {
      StartupProblemKind.offline => (l.startupOfflineTitle, l.startupOfflineBody),
      StartupProblemKind.hostNotFound => (l.startupHostNotFoundTitle, l.startupHostNotFoundBody(host)),
      StartupProblemKind.refused => (l.startupRefusedTitle, l.startupRefusedBody(host)),
      StartupProblemKind.timeout => (l.startupTimeoutTitle, l.startupTimeoutBody(host)),
      StartupProblemKind.tls => (l.startupTlsTitle, l.startupTlsBody(host)),
      StartupProblemKind.serverError =>
        (l.startupServerErrorTitle, l.startupServerErrorBody(host, '${problem.status ?? '5xx'}')),
      StartupProblemKind.invalidResponse => (l.startupInvalidResponseTitle, l.startupInvalidResponseBody(host)),
      StartupProblemKind.configuration => (l.startupConfigurationTitle, l.startupConfigurationBody),
      StartupProblemKind.storage => (l.startupStorageTitle, l.startupStorageBody),
      StartupProblemKind.unknown => (l.startupUnknownTitle, l.startupUnknownBody),
    };

    final ProblemFamily family = switch (kind) {
      StartupProblemKind.offline ||
      StartupProblemKind.hostNotFound ||
      StartupProblemKind.refused ||
      StartupProblemKind.timeout =>
        ProblemFamily.network,
      StartupProblemKind.configuration || StartupProblemKind.storage => ProblemFamily.account,
      _ => ProblemFamily.server,
    };

    final List<String> smallPrint = <String>[
      if (env != null) l.startupServer(env.apiBaseUrl),
      if (problem.detail != null) l.startupDetail(problem.detail!),
      if (env != null && !env.isProduction) l.startupEnvironment(environmentName(l, env.flavor)),
    ];
    final String? requestId = problem.requestId;

    return ProblemScreen(
      family: family,
      visual: family == ProblemFamily.account ? const ProblemVisual.icon(WaiterIcon.triangleAlert) : null,
      title: title,
      body: body,
      primary: ProblemAction(
        l.commonTryAgain,
        retrying ? null : onRetry,
        status: retrying ? ButtonStatus.loading : ButtonStatus.idle,
      ),
      secondary: onChangeServer == null ? null : ProblemAction(l.startupChangeServer, onChangeServer),
      caption: smallPrint.isEmpty ? null : smallPrint.join('\n'),
      supportCode: requestId == null ? null : SupportCode.fromRequestId(requestId),
      requestId: requestId,
    );
  }
}

/// Localised name of an environment.
String environmentName(AppLocalizations l, AppFlavor flavor) => switch (flavor) {
      AppFlavor.development => l.envDevelopment,
      AppFlavor.staging => l.envStaging,
      AppFlavor.production => l.envProduction,
    };

/// The startup problem inside the running app (phase `startupProblem`):
/// retries on "Try again", when the network returns and on foreground.
class StartupProblemScreen extends StatefulWidget {
  const StartupProblemScreen({super.key});

  @override
  State<StartupProblemScreen> createState() => _StartupProblemScreenState();
}

class _StartupProblemScreenState extends State<StartupProblemScreen> {
  late final AppServices _services = context.services;
  bool _listening = false;
  bool _wasOnline = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listening) return;
    _listening = true;
    _wasOnline = _services.connectivity.isOnline;
    _services.connectivity.addListener(_onConnectivity);
  }

  @override
  void dispose() {
    _services.connectivity.removeListener(_onConnectivity);
    super.dispose();
  }

  void _onConnectivity() {
    final bool online = _services.connectivity.isOnline;
    if (online && !_wasOnline) unawaited(_services.session.retryStart());
    _wasOnline = online;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final EnvironmentController env = _services.environmentController;
    final StartupProblem problem =
        _services.session.startupProblem ?? const StartupProblem(StartupProblemKind.unknown);
    return StartupProblemView(
      problem: problem,
      environment: env.current,
      online: _services.connectivity.isOnline,
      retrying: _services.session.phase == AccessPhase.launching,
      onRetry: () => unawaited(_services.session.retryStart()),
      onChangeServer: env.build.allowsServerOverride ? () => unawaited(showServerSheet(context, _services)) : null,
    );
  }
}

/// Server address sheet (development and staging builds): saving signs out
/// and connects to the new server.
Future<void> showServerSheet(BuildContext context, AppServices services) => showWaiterSheet<void>(
      context: context,
      title: AppLocalizations.of(context).serverTitle,
      builder: (BuildContext sheetContext) => _ServerForm(services: services),
    );

class _ServerForm extends StatefulWidget {
  const _ServerForm({required this.services});

  final AppServices services;

  @override
  State<_ServerForm> createState() => _ServerFormState();
}

class _ServerFormState extends State<_ServerForm> {
  late final EnvironmentController _env = widget.services.environmentController;
  late final TextEditingController _url = TextEditingController(text: _env.current.apiBaseUrl);
  final ShakeController _shake = ShakeController();
  ApiUrlIssue? _issue;

  @override
  void dispose() {
    _url.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _apply(void Function() change) async {
    change();
    if (_issue != null) {
      _shake.shake();
      setState(() {});
      return;
    }
    Navigator.of(context).pop();
    await widget.services.session.restartForNewServer();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String? error = switch (_issue) {
      null => null,
      ApiUrlIssue.missing || ApiUrlIssue.malformed => l.serverInvalid,
      ApiUrlIssue.httpsRequired => l.serverHttpsRequired,
      ApiUrlIssue.wrongPath => l.serverWrongPath,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        WaiterTextField(
          kind: TextFieldKind.url,
          label: l.serverLabel,
          controller: _url,
          helperText: l.serverHelp,
          errorText: error,
          shakeController: _shake,
          onChanged: (_) => setState(() => _issue = null),
          onSubmitted: (_) => unawaited(_apply(() => _issue = _env.setServer(_url.text))),
        ),
        const SizedBox(height: Space.s3),
        ScaledText(
          l.serverDefault(_env.build.apiBaseUrl),
          type: TypeTokens.caption,
          color: context.colors.fgSecondary,
        ),
        const SizedBox(height: Space.s6),
        PrimaryButton(
          label: l.serverSave,
          onPressed: () => unawaited(_apply(() => _issue = _env.setServer(_url.text))),
        ),
        if (_env.current.usesOverride) ...<Widget>[
          const SizedBox(height: Space.s2),
          TertiaryButton(
            label: l.serverReset,
            onPressed: () => unawaited(_apply(() {
              _issue = null;
              _env.resetServer();
            })),
          ),
        ],
      ],
    );
  }
}

/// Corner badge of development and staging builds ("DEV" / "STAGING"); a
/// long press opens the server sheet. Taps pass through to the screen.
class EnvironmentBadge extends StatelessWidget {
  const EnvironmentBadge({required this.environment, required this.onLongPress, super.key});

  final AppEnvironment environment;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final String label = switch (environment.flavor) {
      AppFlavor.development => l.envBadgeDevelopment,
      AppFlavor.staging => l.envBadgeStaging,
      AppFlavor.production => '',
    };
    return Semantics(
      label: l.envBadgeA11y(environmentName(l, environment.flavor), environment.apiHost),
      onLongPress: onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(
            painter: _BadgePainter(
              label: label,
              color: environment.flavor == AppFlavor.development ? c.warning : c.info,
              textStyle: TextStyle(
                color: c.fgOnAccent,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter({required this.label, required this.color, required this.textStyle});

  final String label;
  final Color color;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    // Diagonal ribbon across the top-right corner.
    const double band = 16;
    final Path path = Path()
      ..moveTo(size.width - 2 * band, 0)
      ..lineTo(size.width - band, 0)
      ..lineTo(size.width, band)
      ..lineTo(size.width, 2 * band)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    final TextPainter text = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas
      ..save()
      ..translate(size.width - 1.5 * band / 2 - band / 2, band * 0.75)
      ..rotate(0.785398)
      ..translate(-text.width / 2, -text.height / 2);
    text.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.label != label || old.color != color;
}
