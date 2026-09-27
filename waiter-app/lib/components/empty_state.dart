import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';
import 'buttons.dart';

/// Explains an empty list and what fills it — S13 Recent (05 §4.5).
///
/// 96-pt illustration (hidden from assistive technology), title
/// `type.title.m` centred (gap 24), body `type.body.m` `fg.secondary`
/// centred in a 320-pt column (gap 8), optional regular SecondaryButton
/// (hug, gap 24). Vertically centred in the available area, biased 24 pt
/// upward. Title and body read as one group.
class EmptyState extends StatelessWidget {
  /// Creates an empty state.
  const EmptyState({
    required this.illustration,
    required this.title,
    required this.body,
    super.key,
    this.knockoutColor,
    this.actionLabel,
    this.onAction,
  });

  /// Illustration (`recentEmpty`).
  final WaiterIllustration illustration;

  /// The fact, stated calmly.
  final String title;

  /// When content appears.
  final String body;

  /// Surface under the illustration (`bg.surface` inside a sheet).
  final Color? knockoutColor;

  /// Optional action label.
  final String? actionLabel;

  /// Optional action.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    final String? action = actionLabel;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: EmptyStateTokens.bias * 2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: EmptyStateTokens.column),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IllustrationView(illustration, knockoutColor: knockoutColor),
              const SizedBox(height: EmptyStateTokens.illustrationGap),
              MergeSemantics(
                child: Column(
                  children: <Widget>[
                    ScaledText(
                      title,
                      type: TypeTokens.titleM,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: EmptyStateTokens.titleBodyGap),
                    ScaledText(
                      body,
                      type: TypeTokens.bodyM,
                      color: c.fgSecondary,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: EmptyStateTokens.actionGap),
                SecondaryButton(
                  label: action,
                  onPressed: onAction,
                  fullWidth: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
