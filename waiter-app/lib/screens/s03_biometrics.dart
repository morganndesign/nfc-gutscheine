import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../components/components.dart';
import '../core/platform/biometrics_service.dart';
import '../core/platform/feedback_scope.dart';
import '../core/state/session_controller.dart';
import '../core/state/session_state.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'access/access_layout.dart';
import 'access/biometric_copy.dart';

/// S03 · Enable biometrics (03a §3; P10, P11 of 12 §3.4): offered once per
/// install right after the first sign-in. Glyph and strings follow the
/// device's capability (Face ID / Touch ID / Android).
class EnableBiometricsScreen extends StatefulWidget {
  const EnableBiometricsScreen({super.key});

  @override
  State<EnableBiometricsScreen> createState() => _EnableBiometricsScreenState();
}

class _EnableBiometricsScreenState extends State<EnableBiometricsScreen> {
  /// The OS prompt is up: both buttons are inert, the content stays static.
  bool _prompting = false;
  bool _failed = false;

  Future<void> _enable() async {
    if (_prompting) return;
    final AppServices services = context.services;
    final AppLocalizations l = AppLocalizations.of(context);
    final BiometricKind kind = services.session.biometricKind;
    final SnackbarController? snackbar = SnackbarHost.maybeOf(context);
    setState(() {
      _prompting = true;
      _failed = false;
    });
    final BiometricResult result = await services.session.enableBiometrics(
      biometricPromptTexts(l, services.session.user),
    );
    if (!mounted || result == BiometricResult.success) return;
    setState(() {
      _prompting = false;
      _failed = result != BiometricResult.notEnrolled;
    });
    if (result == BiometricResult.notEnrolled) {
      // P10: nothing enrolled — a snackbar, no feedback.
      snackbar?.show(SnackbarData(message: kind.notEnrolled(l)));
    } else {
      // No automatic re-prompt; a new tap is needed.
      context.haptic(HapticToken.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final SessionController session = context.services.session;
    final BiometricKind kind = session.biometricKind;
    final bool compact = context.layout.heightClass.isCompact;

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _GlyphPlate(icon: kind.glyph, compact: compact),
        const SizedBox(height: Space.s6),
        Semantics(
          header: true,
          child: ScaledText(kind.title(l), type: TypeTokens.titleL, textAlign: TextAlign.center),
        ),
        const SizedBox(height: Space.s3),
        ScaledText(l.biometricsBody, type: TypeTokens.bodyL, color: c.fgSecondary, textAlign: TextAlign.center),
        InlineErrorCaption(text: _failed ? l.biometricsFailed : null),
      ],
    );

    final Widget actions = AbsorbPointer(
      absorbing: _prompting,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PrimaryButton(label: kind.enable(l), icon: kind.glyph, onPressed: () => unawaited(_enable())),
          const SizedBox(height: Space.s2),
          TertiaryButton(label: l.biometricsNotNow, large: true, onPressed: session.skipBiometrics),
        ],
      ),
    );

    return CenteredAccessLayout(content: content, actions: actions);
  }
}

/// The static glyph plate (03a §3): a `bg.key` circle of 96 pt with a 48-pt
/// glyph; 72 / 36 pt at compact height. Decorative.
class _GlyphPlate extends StatelessWidget {
  const _GlyphPlate({required this.icon, required this.compact});

  final WaiterIcon icon;
  final bool compact;

  static const double _plate = 96;
  static const double _plateCompact = 72;
  static const double _glyphCompact = 36;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    return Container(
      width: compact ? _plateCompact : _plate,
      height: compact ? _plateCompact : _plate,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.bgKey, shape: BoxShape.circle),
      child: compact
          ? WaiterIconView.mark(icon, dimension: _glyphCompact, strokeWidth: IconSize.s32.stroke, color: c.fgPrimary)
          : WaiterIconView(icon, size: IconSize.s48, color: c.fgPrimary),
    );
  }
}
