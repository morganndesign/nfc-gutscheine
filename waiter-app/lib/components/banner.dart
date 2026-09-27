import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'buttons.dart';
import 'icon_button.dart';
import 'status_banner.dart';
import 'support/announce.dart';
import 'support/hairline.dart';
import 'support/text_emphasis.dart';

/// A persistent app or network condition under the TopBar — offline,
/// maintenance (05 §4.4, 06 M26). Named `WaiterBanner` because Flutter's
/// `Banner` widget would collide.
///
/// Full-bleed, content inset = screen margin, min 48 pt (56 with an
/// action), padding 12 vertical, `icon.20` in the tone colour, title
/// `type.body.m` 600 `fg.primary` (optionally capped at [maxLines]) with an
/// optional second line, optional TertiaryButton ("Details") and/or ✕
/// ([onDismiss]), tone fill, bottom hairline in the tone
/// colour at 24 %, radius 0. Pushes content down; enters by growing from
/// beneath the TopBar with a fade (240 ms decelerate; fade only under
/// Reduce Motion). Announced politely on appearance.
class WaiterBanner extends StatefulWidget {
  /// Creates a banner.
  const WaiterBanner({
    required this.tone,
    required this.icon,
    required this.title,
    super.key,
    this.body,
    this.actionLabel,
    this.onAction,
    this.maxLines,
    this.onDismiss,
  });

  /// `info` for offline, `warning` for maintenance.
  final BannerTone tone;

  /// `wifi-off` (offline), `wrench` (maintenance).
  final WaiterIcon icon;

  /// `offline.title` or the maintenance notice (max 2 lines).
  final String title;

  /// Second line (`offline.body` on S07).
  final String? body;

  /// Optional action label ("Details").
  final String? actionLabel;

  /// Optional action.
  final VoidCallback? onAction;

  /// Line cap of [title] with a tail ellipsis (maintenance notice: 2,
  /// 03a V7); the full text stays in the accessibility label. `null`
  /// never truncates.
  final int? maxLines;

  /// Shows a trailing ✕ (IconButton 56, `maintenance.dismiss`) that calls
  /// this — the dismissible maintenance notice (03a V7, 12 A12).
  final VoidCallback? onDismiss;

  @override
  State<WaiterBanner> createState() => _WaiterBannerState();
}

class _WaiterBannerState extends State<WaiterBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: Motion.durationBase,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _enter,
    curve: Motion.easeDecelerate,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final String? body = widget.body;
      announce(
        context,
        body == null
            ? widget.title
            : AppLocalizations.of(context).a11yProblem(widget.title, body),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_enter.isDismissed) {
      _enter.duration = MediaQuery.disableAnimationsOf(context)
          ? Motion.durationFast
          : Motion.durationBase;
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final WaiterColors c = theme.colors;
    final Color toneColor = widget.tone.color(c);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final String? body = widget.body;
    final String? actionLabel = widget.actionLabel;
    final VoidCallback? onDismiss = widget.onDismiss;
    final bool hasControl = actionLabel != null || onDismiss != null;
    final Animation<double> curve = _curve;
    final double margin = context.layout.margin;

    final Widget content = Container(
      constraints: BoxConstraints(
        minHeight: hasControl
            ? BannerTokens.minHeightWithAction
            : BannerTokens.minHeight,
        minWidth: double.infinity,
      ),
      color: widget.tone.fill(c),
      padding: EdgeInsetsDirectional.only(
        start: margin,
        end: onDismiss == null ? margin : margin - IconButtonTokens.marginInset,
        top: hasControl ? 0 : BannerTokens.paddingVertical,
        bottom: hasControl ? 0 : BannerTokens.paddingVertical,
      ),
      child: Row(
        children: <Widget>[
          WaiterIconView(widget.icon, size: IconSize.s20, color: toneColor),
          const SizedBox(width: BannerTokens.iconGap),
          Expanded(
            child: Semantics(
              container: true,
              label: body == null ? widget.title : '${widget.title}. $body',
              excludeSemantics: true,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: hasControl ? BannerTokens.paddingVertical : 0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ScaledText.rich(
                      (ScaledStyles s) => TextSpan(
                        text: widget.title,
                        style: s(
                          TypeTokens.bodyM,
                        ).semiBold(boldText: theme.boldText),
                      ),
                      type: TypeTokens.bodyM,
                      maxLines: widget.maxLines,
                      overflow: widget.maxLines == null
                          ? TextOverflow.clip
                          : TextOverflow.ellipsis,
                    ),
                    if (body != null) ScaledText(body, type: TypeTokens.bodyM),
                  ],
                ),
              ),
            ),
          ),
          if (actionLabel != null)
            TertiaryButton(label: actionLabel, onPressed: widget.onAction),
          if (onDismiss != null)
            WaiterIconButton(
              icon: WaiterIcon.x,
              semanticLabel: AppLocalizations.of(context).maintenanceDismiss,
              onPressed: onDismiss,
            ),
        ],
      ),
    );

    final Widget banner = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        content,
        Hairline(color: toneColor.withValues(alpha: BannerTokens.edgeOpacity)),
      ],
    );

    return Semantics(
      container: true,
      child: FadeTransition(
        opacity: curve,
        child: reduceMotion
            ? banner
            : SizeTransition(
                sizeFactor: curve,
                alignment: Alignment.bottomCenter,
                child: banner,
              ),
      ),
    );
  }
}
