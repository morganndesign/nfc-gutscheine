import 'package:flutter/widgets.dart';

import '../core/platform/feedback_scope.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'buttons.dart';
import 'spinner.dart';
import 'support/announce.dart';
import 'support/text_emphasis.dart';

/// Tone of a [StatusBanner] or [WaiterBanner] (05 §3.3, §4.4).
enum BannerTone {
  /// `color.info` / `info.bg`, icon `info`.
  info,

  /// `color.warning` / `warning.bg`, icon `triangle-alert`.
  warning,

  /// `color.danger` / `danger.bg`, icon `circle-alert`.
  danger,

  /// `color.success` / `success.bg`, icon `circle-check` (reserved in v1).
  success;

  /// Tone colour (icon, dark-theme outline).
  Color color(WaiterColors c) => switch (this) {
    BannerTone.info => c.info,
    BannerTone.warning => c.warning,
    BannerTone.danger => c.danger,
    BannerTone.success => c.success,
  };

  /// Tone fill.
  Color fill(WaiterColors c) => switch (this) {
    BannerTone.info => c.infoBg,
    BannerTone.warning => c.warningBg,
    BannerTone.danger => c.dangerBg,
    BannerTone.success => c.successBg,
  };

  /// Default icon.
  WaiterIcon get icon => switch (this) {
    BannerTone.info => WaiterIcon.info,
    BannerTone.warning => WaiterIcon.triangleAlert,
    BannerTone.danger => WaiterIcon.circleAlert,
    BannerTone.success => WaiterIcon.circleCheck,
  };

  /// Whether the appearance is announced assertively (07 §5.6).
  bool get assertive => this == BannerTone.warning || this == BannerTone.danger;
}

/// In-content message about the current card or operation, below the
/// BalanceCard on S07/S08 (05 §3.3): what happened + what to do.
///
/// `radius.m`, padding 16, min 56 pt, tone fill (dark theme: 1-px tone
/// outline at 24 %); `icon.24` in the tone colour (or a Spinner in
/// `color.warning` while [busy] — "Redemption uncertain"); title
/// `type.body.l` 600 `fg.primary`, body `type.body.m` `fg.secondary`
/// (600 in high contrast), optional TertiaryButton on the text column.
/// Not dismissible. Announced on appearance, on tone changes and — unless
/// [announceTextChanges] is off — on text changes ("{title}. {body}",
/// assertive for warning/danger); state changes
/// cross-fade over 160 ms. [appearHaptic]/[appearSound] play once on
/// appearance (the screen picks them per 11 §3.3–3.4).
class StatusBanner extends StatefulWidget {
  /// Creates a banner.
  const StatusBanner({
    required this.tone,
    required this.title,
    super.key,
    this.body,
    this.bodyMaxLines,
    this.icon,
    this.busy = false,
    this.actionLabel,
    this.onAction,
    this.appearHaptic,
    this.appearSound,
    this.announceTextChanges = true,
  });

  /// Tone.
  final BannerTone tone;

  /// What happened (≤ 28 characters).
  final String title;

  /// What to do or why.
  final String? body;

  /// Line cap for server text (`blocked_reason`: 3, then ellipsis); `null`
  /// never truncates.
  final int? bodyMaxLines;

  /// Icon override (card blocked: `ban`).
  final WaiterIcon? icon;

  /// Shows a Spinner in `color.warning` instead of the icon.
  final bool busy;

  /// Optional TertiaryButton label.
  final String? actionLabel;

  /// Optional TertiaryButton action.
  final VoidCallback? onAction;

  /// Haptic played once on appearance.
  final HapticToken? appearHaptic;

  /// Sound played once on appearance.
  final SoundToken? appearSound;

  /// Whether a new title/body is announced. `false` for text that ticks
  /// (countdowns): the banner then speaks on appearance and on a tone
  /// change only, so a screen reader is not interrupted every second
  /// (07 §5.6: countdowns are announced at start and end, not per tick).
  final bool announceTextChanges;

  @override
  State<StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<StatusBanner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final HapticToken? haptic = widget.appearHaptic;
      final SoundToken? sound = widget.appearSound;
      if (haptic != null) context.haptic(haptic);
      if (sound != null) context.sound(sound);
      _announce();
    });
  }

  @override
  void didUpdateWidget(StatusBanner old) {
    super.didUpdateWidget(old);
    final bool toneChanged = old.tone != widget.tone || old.busy != widget.busy;
    final bool textChanged =
        old.title != widget.title || old.body != widget.body;
    if (toneChanged || (widget.announceTextChanges && textChanged)) {
      _announce();
    }
  }

  void _announce() {
    final String? body = widget.body;
    announce(
      context,
      body == null
          ? widget.title
          : AppLocalizations.of(context).a11yProblem(widget.title, body),
      assertive: widget.tone.assertive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final WaiterColors c = theme.colors;
    final bool dark = theme.brightness == Brightness.dark;
    final Color toneColor = widget.tone.color(c);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final String? body = widget.body;
    final String? actionLabel = widget.actionLabel;

    final Widget leading = SizedBox(
      width: IconSize.s24.size,
      height: TypeTokens.bodyL.lineHeight,
      child: Center(
        child: widget.busy
            ? Spinner(color: c.warning)
            : WaiterIconView(widget.icon ?? widget.tone.icon, color: toneColor),
      ),
    );

    final Widget text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ScaledText.rich(
          (ScaledStyles s) => TextSpan(
            text: widget.title,
            style: s(TypeTokens.bodyL).semiBold(boldText: theme.boldText),
          ),
          type: TypeTokens.bodyL,
        ),
        if (body != null) ...<Widget>[
          const SizedBox(height: StatusBannerTokens.titleBodyGap),
          ScaledText.rich(
            (ScaledStyles s) => TextSpan(
              text: body,
              style: s(
                TypeTokens.bodyM,
                color: c.fgSecondary,
              ).copyWith(fontWeight: theme.statusBannerBody.fontWeight),
            ),
            type: TypeTokens.bodyM,
            maxLines: widget.bodyMaxLines,
            overflow: widget.bodyMaxLines == null
                ? TextOverflow.clip
                : TextOverflow.ellipsis,
          ),
        ],
        if (actionLabel != null) ...<Widget>[
          const SizedBox(height: StatusBannerTokens.bodyActionGap),
          Transform.translate(
            // The 56-pt target overlaps the padding; its label sits on the
            // text column (05 §1.3 "aligns to the banner's text column").
            offset: Offset(
              Directionality.of(context) == TextDirection.ltr
                  ? -ButtonTokens.tertiaryPaddingHorizontal
                  : ButtonTokens.tertiaryPaddingHorizontal,
              0,
            ),
            child: TertiaryButton(
              label: actionLabel,
              onPressed: widget.onAction,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      container: true,
      child: AnimatedSize(
        duration: reduceMotion ? Duration.zero : Motion.durationBase,
        curve: Motion.easeStandard,
        child: AnimatedContainer(
          duration: Motion.durationFast,
          curve: Motion.easeStandard,
          constraints: const BoxConstraints(
            minHeight: StatusBannerTokens.minHeight,
            minWidth: double.infinity,
          ),
          padding: const EdgeInsets.all(StatusBannerTokens.padding),
          decoration: BoxDecoration(
            color: widget.tone.fill(c),
            borderRadius: BorderRadius.circular(StatusBannerTokens.radius),
            border: dark
                ? Border.all(
                    color: toneColor.withValues(
                      alpha: StatusBannerTokens.darkOutlineOpacity,
                    ),
                  )
                : null,
          ),
          child: AnimatedSwitcher(
            duration: Motion.durationFast,
            child: Row(
              key: ValueKey<Object>(
                Object.hash(widget.tone, widget.title, widget.busy),
              ),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ExcludeSemantics(child: leading),
                const SizedBox(width: StatusBannerTokens.iconGap),
                Expanded(child: text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
