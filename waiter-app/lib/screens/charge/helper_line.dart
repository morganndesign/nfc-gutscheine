import 'package:flutter/widgets.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

/// Tone of the S07 helper line (03b §2.7).
enum HelperTone {
  /// `color.danger` with the `circle-alert` icon (over balance, max single,
  /// balance changed) — status is never carried by colour alone (AC-S07-12).
  danger,

  /// `color.fg.secondary` (full-only, tap again, slow, still looking).
  info,
}

/// One helper message.
@immutable
class HelperMessage {
  /// Creates a message.
  const HelperMessage(this.text, this.tone);

  /// Visible text.
  final String text;

  /// Tone.
  final HelperTone tone;

  @override
  bool operator ==(Object other) =>
      other is HelperMessage && other.text == text && other.tone == tone;

  @override
  int get hashCode => Object.hash(text, tone);
}

/// The reserved helper line under the AmountDisplay (03b §2.3–2.4):
/// `type.body.m` (600 with Increase contrast), centred, one line — two at
/// 150 % text. A new message fades in with a 4-pt rise (06 M14, fast,
/// decelerate); fades only under Reduce Motion. The row keeps its height
/// when empty so the card never resizes.
class ChargeHelperLine extends StatelessWidget {
  /// Creates the line.
  const ChargeHelperLine({required this.message, super.key});

  /// Current message, `null` = empty.
  final HelperMessage? message;

  static const double _rise = 4;

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final WaiterColors c = theme.colors;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final HelperMessage? message = this.message;
    Widget content = const SizedBox.shrink();
    if (message != null) {
      final Color color = message.tone == HelperTone.danger
          ? c.danger
          : c.fgSecondary;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (message.tone == HelperTone.danger) ...<Widget>[
            ExcludeSemantics(
              child: WaiterIconView(
                WaiterIcon.circleAlert,
                size: IconSize.s16,
                color: color,
              ),
            ),
            const SizedBox(width: AmountDisplayTokens.messageIconGap),
          ],
          Flexible(
            child: ScaledText.rich(
              (ScaledStyles s) => TextSpan(
                text: message.text,
                style: s(
                  TypeTokens.bodyM,
                  color: color,
                ).copyWith(fontWeight: theme.statusBannerBody.fontWeight),
              ),
              type: TypeTokens.bodyM,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: Motion.durationFast,
      reverseDuration: Motion.durationInstant,
      switchInCurve: Motion.easeDecelerate,
      switchOutCurve: Motion.easeAccelerate,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(
            opacity: animation,
            child: reduceMotion
                ? child
                : AnimatedBuilder(
                    animation: animation,
                    builder: (BuildContext context, Widget? child) =>
                        Transform.translate(
                          offset: Offset(0, _rise * (1 - animation.value)),
                          child: child,
                        ),
                    child: child,
                  ),
          ),
      child: Center(key: ValueKey<HelperMessage?>(message), child: content),
    );
  }
}
