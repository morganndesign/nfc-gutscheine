import 'package:flutter/widgets.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';

import 'support_code_line.dart';

/// The S08 "Connection interrupted" panel that replaces helper, chip and
/// keypad while the outcome of a redemption is unknown (03b §3.4–3.5,
/// 12 R03/R04).
///
/// `color.warning.bg`, `radius.l`, padding `space.5` (dark theme: 1-px
/// `color.warning` outline at 24 %, like the StatusBanner). Automatic
/// retrying shows a Spinner in `color.warning`, `uncertain.body` and the
/// attempt counter; the final state shows `triangle-alert`,
/// `uncertain.failedBody` and the support code. Both end with the line the
/// waiter says to the guest. Title `type.title.m`, body `type.body.l`,
/// counter `type.caption`, guest hint `type.body.m` `fg.secondary`. The
/// panel scrolls inside its fixed area at large text sizes.
class UncertainPanel extends StatelessWidget {
  /// Creates the panel.
  const UncertainPanel({
    required this.finalState,
    required this.attempt,
    super.key,
    this.supportCode,
    this.requestId,
  });

  /// Retries are exhausted ("Try again" / "Cancel" are offered).
  final bool finalState;

  /// Automatic retry number (`uncertain.retrying`), 0 = none yet.
  final int attempt;

  /// Support code of the last attempt (final state, 12 §2.5).
  final String? supportCode;

  /// Full request id behind [supportCode].
  final String? requestId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterTheme theme = context.waiter;
    final WaiterColors c = theme.colors;
    final bool dark = theme.brightness == Brightness.dark;
    final String? code = supportCode;
    final String? id = requestId;

    final Widget leading = SizedBox(
      width: IconSize.s24.size,
      height: TypeTokens.titleM.lineHeight,
      child: Center(
        child: finalState
            ? WaiterIconView(WaiterIcon.triangleAlert, color: c.warning)
            : Spinner(color: c.warning),
      ),
    );

    final Widget text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          header: true,
          child: ScaledText(l10n.uncertainTitle, type: TypeTokens.titleM),
        ),
        const SizedBox(height: Space.s1),
        ScaledText(
          finalState ? l10n.uncertainFailedBody : l10n.uncertainBody,
          type: TypeTokens.bodyL,
        ),
        if (!finalState && attempt > 0) ...<Widget>[
          const SizedBox(height: Space.s1),
          ScaledText(
            l10n.uncertainRetrying(attempt),
            type: TypeTokens.caption,
            color: c.fgSecondary,
          ),
        ],
        const SizedBox(height: Space.s4),
        ScaledText(
          l10n.uncertainGuestHint,
          type: TypeTokens.bodyM,
          color: c.fgSecondary,
        ),
        if (finalState && code != null && id != null) ...<Widget>[
          const SizedBox(height: Space.s3),
          SupportCodeLine(
            code: code,
            requestId: id,
            textAlign: TextAlign.start,
          ),
        ],
      ],
    );

    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.warningBg,
          borderRadius: BorderRadius.circular(Radii.l),
          border: dark
              ? Border.all(
                  color: c.warning.withValues(
                    alpha: StatusBannerTokens.darkOutlineOpacity,
                  ),
                )
              : null,
        ),
        child: SizedBox.expand(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.s5),
            child: Row(
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
