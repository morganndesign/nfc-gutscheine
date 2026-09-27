import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../components/components.dart';
import '../core/api/models.dart';
import '../core/platform/biometrics_service.dart';
import '../core/state/session_controller.dart';
import '../core/state/session_state.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'access/access_layout.dart';
import 'access/biometric_copy.dart';

/// S04 · Unlock (03a §4; P11–P13 of 12 §3.4; 06 M03). The OS prompt opens
/// by itself when the screen becomes active — never while the app is
/// inactive — and never re-opens by itself after a cancel. Unlocking is
/// local and works offline.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> with WidgetsBindingObserver {
  bool _prompting = false;

  /// When the OS prompt is dismissed, focus moves to the PrimaryButton.
  final FocusNode _unlockFocus = FocusNode();

  /// The app was in the background: prompt again once it is active.
  bool _promptOnResume = false;

  BiometricResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Requested on the first rendered frame (≤ 100 ms after appear).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) {
        unawaited(_prompt());
      } else {
        _promptOnResume = true;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unlockFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_promptOnResume) {
          _promptOnResume = false;
          unawaited(_prompt());
        }
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        if (!_prompting) _promptOnResume = true;
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _prompt() async {
    if (_prompting) return;
    final SessionController session = context.services.session;
    setState(() {
      _prompting = true;
      _result = null;
    });
    final BiometricResult result = await session.unlock(
      biometricPromptTexts(AppLocalizations.of(context), session.user),
    );
    // Success and changed biometrics leave S04 through the session phase.
    if (!mounted || session.phase != AccessPhase.locked) return;
    setState(() {
      _prompting = false;
      _result = result;
    });
    _unlockFocus.requestFocus();
  }

  String? _caption(AppLocalizations l, BiometricKind kind) => switch (_result) {
    BiometricResult.failed => l.biometricsFailed,
    BiometricResult.lockedOut => l.unlockLockedOut,
    BiometricResult.notEnrolled => kind.notEnrolled(l),
    BiometricResult.success || null => null,
  };

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: context.services.session, builder: (BuildContext context, _) => _content(context));

  Widget _content(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final SessionController session = context.services.session;
    final BiometricKind kind = session.biometricKind;
    final SessionUser? user = session.user;
    final String name = user?.name ?? '';
    final String restaurant = user?.restaurant?.name ?? '';

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 72 pt; 56 pt at compact height (03a §4).
        Avatar(name: name, size: context.layout.heightClass.isCompact ? AvatarSize.large : AvatarSize.extraLarge),
        const SizedBox(height: Space.s4),
        // Read together: "Lukas Gruber, Gasthaus Zum Goldenen Hirschen".
        Semantics(
          header: true,
          container: true,
          label: restaurant.isEmpty ? name : '$name, $restaurant',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ScaledText(
                name,
                type: TypeTokens.titleM,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (restaurant.isNotEmpty) ...<Widget>[
                const SizedBox(height: Space.s1),
                ScaledText(
                  restaurant,
                  type: TypeTokens.bodyM,
                  color: c.fgSecondary,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        InlineErrorCaption(text: _caption(l, kind)),
      ],
    );

    final Widget actions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (session.hasPendingLink) ...<Widget>[
          StatusBanner(tone: BannerTone.info, title: l.unlockPendingCard),
          const SizedBox(height: Space.s4),
        ],
        // Not interactive while the OS prompt is up (no double prompts).
        AbsorbPointer(
          absorbing: _prompting,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PrimaryButton(
                label: kind.unlock(l),
                icon: kind.glyph,
                focusNode: _unlockFocus,
                onPressed: () => unawaited(_prompt()),
              ),
              const SizedBox(height: Space.s2),
              TertiaryButton(
                label: l.unlockUsePassword,
                large: true,
                onPressed: () => unawaited(session.usePassword()),
              ),
            ],
          ),
        ),
      ],
    );

    return CenteredAccessLayout(content: content, actions: actions);
  }
}
