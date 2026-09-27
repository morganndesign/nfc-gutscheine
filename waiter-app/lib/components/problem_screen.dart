import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/format/format.dart';
import '../core/platform/feedback_scope.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'buttons.dart';
import 'progress_ring.dart';
import 'snackbar.dart';
import 'support/announce.dart';
import 'top_bar.dart';
import 'support/text_emphasis.dart';

/// Problem families of the ProblemScreen (05 §4.6 tone table, 13 · R03 /
/// R16): tone, default visual and the feedback played on appearance.
enum ProblemFamily {
  /// Card not found — danger, `ill_card_not_found`, error haptic + sound.
  notFound,

  /// Card of another restaurant — danger, `ill_wrong_restaurant`, error.
  foreign,

  /// Server error — danger, `circle-alert`, warning haptic + sound.
  server,

  /// Verification failed — calm warning tone (never red),
  /// `ill_verify_failed`, error haptic + sound (13 · R03).
  verification,

  /// Scan throttled / velocity — warning, `ill_wait` (pass the ring as
  /// `ProblemScreen.countdown`), warning haptic + sound.
  throttled,

  /// Network error — info, `ill_offline`, warning haptic + sound.
  network,

  /// Account, device, restaurant, update and permission states (S15,
  /// S16) — neutral `fg.secondary`, no feedback.
  account;

  /// Colour of the icon (the tone lives only in the visual, 05 §4.6).
  Color toneColor(WaiterColors c) => switch (this) {
    ProblemFamily.notFound ||
    ProblemFamily.foreign ||
    ProblemFamily.server => c.danger,
    ProblemFamily.verification || ProblemFamily.throttled => c.warning,
    ProblemFamily.network => c.info,
    ProblemFamily.account => c.fgSecondary,
  };

  /// Default visual.
  ProblemVisual? get defaultVisual => switch (this) {
    ProblemFamily.notFound => const ProblemVisual.illustration(
      WaiterIllustration.cardNotFound,
    ),
    ProblemFamily.foreign => const ProblemVisual.illustration(
      WaiterIllustration.wrongRestaurant,
    ),
    ProblemFamily.server => const ProblemVisual.icon(WaiterIcon.circleAlert),
    ProblemFamily.verification => const ProblemVisual.illustration(
      WaiterIllustration.verifyFailed,
    ),
    ProblemFamily.network => const ProblemVisual.illustration(
      WaiterIllustration.offline,
    ),
    ProblemFamily.throttled => const ProblemVisual.illustration(
      WaiterIllustration.wait,
    ),
    ProblemFamily.account => null,
  };

  /// Haptic on appearance.
  HapticToken? get haptic => switch (this) {
    ProblemFamily.notFound ||
    ProblemFamily.foreign ||
    ProblemFamily.verification => HapticToken.error,
    ProblemFamily.server ||
    ProblemFamily.throttled ||
    ProblemFamily.network => HapticToken.warning,
    ProblemFamily.account => null,
  };

  /// Sound on appearance.
  SoundToken? get sound => switch (this) {
    ProblemFamily.notFound ||
    ProblemFamily.foreign ||
    ProblemFamily.verification => SoundToken.error,
    ProblemFamily.server ||
    ProblemFamily.throttled ||
    ProblemFamily.network => SoundToken.warning,
    ProblemFamily.account => null,
  };
}

/// The status visual ② of a ProblemScreen.
@immutable
class ProblemVisual {
  /// A 120-pt illustration (96 at compact height), hidden at text ≥ 150 %.
  const ProblemVisual.illustration(WaiterIllustration this.illustration)
    : icon = null,
      remaining = null,
      total = null,
      finishedAnnouncement = null;

  /// An `icon.48` in the family's tone colour.
  const ProblemVisual.icon(WaiterIcon this.icon)
    : illustration = null,
      remaining = null,
      total = null,
      finishedAnnouncement = null;

  /// A 48-pt countdown ring as the only visual (icon-sized variant of
  /// 05 §4.6); with `ill_wait` use `ProblemScreen.countdown` instead.
  const ProblemVisual.countdown({
    required Duration this.remaining,
    required Duration this.total,
    this.finishedAnnouncement,
  }) : illustration = null,
       icon = null;

  /// Illustration.
  final WaiterIllustration? illustration;

  /// Icon.
  final WaiterIcon? icon;

  /// Countdown time left.
  final Duration? remaining;

  /// Countdown full wait.
  final Duration? total;

  /// Announced when the countdown ends.
  final String? finishedAnnouncement;
}

/// The live countdown of a wait (scan throttled, account locked): a 48-pt
/// ProgressRing rendered below the body — the `ill_wait` illustration
/// above does not contain it (10 §4.4 #4).
@immutable
class ProblemCountdown {
  /// Creates a countdown.
  const ProblemCountdown({
    required this.remaining,
    required this.total,
    this.finishedAnnouncement,
  });

  /// Time left.
  final Duration remaining;

  /// Full wait.
  final Duration total;

  /// Announced when the countdown ends (`a11y.scanAvailable`).
  final String? finishedAnnouncement;
}

/// One action of a ProblemScreen.
@immutable
class ProblemAction {
  /// Creates an action; `onPressed` `null` shows it disabled.
  const ProblemAction(this.label, this.onPressed, {this.status});

  /// Label.
  final String label;

  /// Action.
  final VoidCallback? onPressed;

  /// Progress (primary only; e.g. S15 "Check again").
  final ButtonStatus? status;
}

/// Full-screen problem template (05 §4.6): S10 variants, S15 account
/// states, S16 permissions.
///
/// Optional task TopBar (✕); the content block (visual, `type.title.l`
/// title, `type.body.l` `fg.secondary` body, optional support code in
/// `type.caption` `fg.tertiary`) in a centred 320-pt column biased 32 pt
/// upward; the bottom CTA block holds exactly one large PrimaryButton, an
/// optional SecondaryButton and an optional TertiaryButton. `bg.canvas`
/// background. Enters with the M22 stagger (icon, title +40, body +80,
/// actions +120 ms); no stagger under Reduce Motion. On appearance plays
/// the family's feedback, announces "{title}. {body}" assertively and moves
/// focus to the title. Long-pressing the support code copies the full
/// request id and confirms with the `common.copied` snackbar.
class ProblemScreen extends StatefulWidget {
  /// Creates the screen.
  const ProblemScreen({
    required this.family,
    required this.title,
    required this.body,
    required this.primary,
    super.key,
    this.visual,
    this.secondary,
    this.tertiary,
    this.onClose,
    this.supportCode,
    this.requestId,
    this.supportCodeTag,
    this.countdown,
    this.caption,
  }) : assert(
         supportCode == null || requestId != null,
         'The support code copies the full request id',
       );

  /// Problem family (tone, feedback, default visual).
  final ProblemFamily family;

  /// What happened.
  final String title;

  /// What to do (max 2 lines).
  final String body;

  /// Visual; defaults to [ProblemFamily.defaultVisual].
  final ProblemVisual? visual;

  /// The likeliest recovery (large PrimaryButton).
  final ProblemAction primary;

  /// A real alternative (SecondaryButton).
  final ProblemAction? secondary;

  /// A minor alternative (TertiaryButton).
  final ProblemAction? tertiary;

  /// ✕ in a task TopBar; `null` omits the TopBar (S15).
  final VoidCallback? onClose;

  /// Support code (last 6 characters of `X-Request-Id`, 12 §2.5).
  final String? supportCode;

  /// Full request id copied by a long press.
  final String? requestId;

  /// Neutral verification tag appended as " · UID" (12 §2.5).
  final String? supportCodeTag;

  /// Countdown ring below the body (throttled, locked).
  final ProblemCountdown? countdown;

  /// Status caption below the primary action, e.g. `offline.title` after a
  /// "Check again" that failed for lack of network (03a S15 10.3);
  /// announced politely when it appears or changes.
  final String? caption;

  @override
  State<ProblemScreen> createState() => _ProblemScreenState();
}

class _ProblemScreenState extends State<ProblemScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: Motion.durationSlow,
  );
  final FocusNode _titleFocus = FocusNode();

  /// 06 M22: elements start 40 ms apart and each enters over 240 ms.
  static const int _stagger = 40;
  static const int _stages = 4;
  late final List<CurvedAnimation> _stageCurves = <CurvedAnimation>[
    for (int i = 0; i < _stages; i++)
      CurvedAnimation(
        parent: _enter,
        curve: Interval(
          i * _stagger / Motion.durationSlow.inMilliseconds,
          (i * _stagger + Motion.durationBase.inMilliseconds) /
              Motion.durationSlow.inMilliseconds,
          curve: Motion.easeDecelerate,
        ),
      ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final HapticToken? haptic = widget.family.haptic;
      final SoundToken? sound = widget.family.sound;
      if (haptic != null) context.haptic(haptic);
      if (sound != null) context.sound(sound);
      announce(
        context,
        AppLocalizations.of(context).a11yProblem(widget.title, widget.body),
        assertive: true,
      );
      _titleFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(ProblemScreen old) {
    super.didUpdateWidget(old);
    final String? caption = widget.caption;
    if (caption != null && caption != old.caption) announce(context, caption);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_enter.isDismissed) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _enter.value = 1;
      } else {
        _enter.forward();
      }
    }
  }

  @override
  void dispose() {
    for (final CurvedAnimation c in _stageCurves) {
      c.dispose();
    }
    _titleFocus.dispose();
    _enter.dispose();
    super.dispose();
  }

  Widget _stage(int index, double rise, Widget child) {
    final Animation<double> t = _stageCurves[index];
    return AnimatedBuilder(
      animation: t,
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: t.value,
        child: Transform.translate(
          offset: Offset(0, rise * (1 - t.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  void _copy() {
    final String? id = widget.requestId;
    if (id == null) return;
    unawaited(Clipboard.setData(ClipboardData(text: id)));
    SnackbarHost.maybeOf(
      context,
    )?.show(SnackbarData(message: AppLocalizations.of(context).commonCopied));
  }

  Widget? _visual(BuildContext context) {
    final WaiterColors c = context.colors;
    final ProblemVisual? visual = widget.visual ?? widget.family.defaultVisual;
    if (visual == null) return null;
    final WaiterIllustration? illustration = visual.illustration;
    if (illustration != null) {
      final bool largeText =
          MediaQuery.textScalerOf(context).scale(1) >=
          IllustrationTokens.hideAtTextScale;
      return largeText ? null : IllustrationView(illustration);
    }
    final WaiterIcon? icon = visual.icon;
    if (icon != null) {
      return WaiterIconView(
        icon,
        size: IconSize.s48,
        color: widget.family.toneColor(c),
      );
    }
    return ProgressRing.countdown(
      remaining: visual.remaining!,
      total: visual.total!,
      finishedAnnouncement: visual.finishedAnnouncement,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final WaiterLayout layout = context.layout;
    final bool largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final Widget? visual = _visual(context);
    final bool isIllustration =
        (widget.visual ?? widget.family.defaultVisual)?.illustration != null;
    final String? code = widget.supportCode;
    final String? tag = widget.supportCodeTag;
    final ProblemAction? secondary = widget.secondary;
    final ProblemAction? tertiary = widget.tertiary;
    final VoidCallback? onClose = widget.onClose;
    final ProblemCountdown? countdown = widget.countdown;
    final String? caption = widget.caption;

    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: ProblemScreenTokens.column),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (visual != null) ...<Widget>[
            _stage(0, -Space.s3, ExcludeSemantics(child: visual)),
            SizedBox(
              height: isIllustration
                  ? ProblemScreenTokens.illustrationGap
                  : ProblemScreenTokens.iconGap,
            ),
          ],
          _stage(
            1,
            Space.s2,
            Focus(
              focusNode: _titleFocus,
              child: Semantics(
                container: true,
                header: true,
                child: ScaledText(
                  widget.title,
                  type: TypeTokens.titleL,
                  textAlign: TextAlign.center,
                  maxLines: largeText ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(height: ProblemScreenTokens.titleBodyGap),
          _stage(
            2,
            Space.s2,
            ScaledText(
              widget.body,
              type: TypeTokens.bodyL,
              color: c.fgSecondary,
              textAlign: TextAlign.center,
            ),
          ),
          if (countdown != null) ...<Widget>[
            const SizedBox(height: ProblemScreenTokens.bodyCodeGap),
            _stage(
              2,
              Space.s2,
              ProgressRing.countdown(
                remaining: countdown.remaining,
                total: countdown.total,
                finishedAnnouncement: countdown.finishedAnnouncement,
              ),
            ),
          ],
          if (code != null) ...<Widget>[
            const SizedBox(height: ProblemScreenTokens.bodyCodeGap),
            _stage(
              2,
              Space.s2,
              Semantics(
                label: l10n.commonSupportCodeA11y(SupportCode.spoken(code)),
                excludeSemantics: true,
                onLongPress: _copy,
                child: GestureDetector(
                  onLongPress: _copy,
                  child: ScaledText.rich(
                    (ScaledStyles s) => TextSpan(
                      text: tag == null
                          ? l10n.commonSupportCode(code)
                          : '${l10n.commonSupportCode(code)} · $tag',
                      style: s(TypeTokens.caption, color: c.fgTertiary).tabular,
                    ),
                    type: TypeTokens.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final Widget actions = _stage(
      3,
      Space.s4,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PrimaryButton(
            label: widget.primary.label,
            onPressed: widget.primary.onPressed,
            status: widget.primary.status ?? ButtonStatus.idle,
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: Space.s2),
            ScaledText(
              caption,
              type: TypeTokens.caption,
              color: c.fgSecondary,
              textAlign: TextAlign.center,
            ),
          ],
          if (secondary != null) ...<Widget>[
            const SizedBox(height: ProblemScreenTokens.actionGap),
            SecondaryButton(
              label: secondary.label,
              onPressed: secondary.onPressed,
            ),
          ],
          if (tertiary != null) ...<Widget>[
            const SizedBox(height: ProblemScreenTokens.actionGap),
            TertiaryButton(
              label: tertiary.label,
              onPressed: tertiary.onPressed,
              large: true,
            ),
          ],
        ],
      ),
    );

    return ColoredBox(
      color: c.bgCanvas,
      child: Column(
        children: <Widget>[
          if (onClose != null)
            TopBar.task(onClose: onClose)
          else
            SizedBox(height: layout.viewPadding.top),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) =>
                  SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            layout.margin,
                            Space.s4,
                            layout.margin,
                            Space.s4 + ProblemScreenTokens.bias * 2,
                          ),
                          child: content,
                        ),
                      ),
                    ),
                  ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              layout.margin,
              0,
              layout.margin,
              layout.viewPadding.bottom + layout.ctaBottomPadding,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
                child: actions,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
