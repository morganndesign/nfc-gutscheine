import 'package:flutter/widgets.dart';

import '../../components/support/announce.dart';
import '../../core/theme/theme.dart';

/// Layout shared by S03 and S04 (03a §3–§4, 08 §3.10).
///
/// Phones: [content] is centred between the safe top and the top of the
/// action block minus `space.8`, and scrolls when text is large; [actions]
/// stay pinned to the bottom (16 pt above the home indicator).
/// Tablets: one column of max 480 pt, the actions directly below the
/// content with `space.10`, the block centred vertically.
class CenteredAccessLayout extends StatelessWidget {
  const CenteredAccessLayout({required this.content, required this.actions, super.key});

  final Widget content;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final WaiterLayout layout = context.layout;
    final EdgeInsets insets = layout.viewPadding;
    final double bottom = insets.bottom + layout.ctaBottomPadding;

    if (layout.widthClass.isTablet) {
      return ColoredBox(
        color: context.colors.bgCanvas,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(layout.margin, insets.top, layout.margin, bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - insets.top - bottom),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: LayoutTokens.textMeasureTablet),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      content,
                      const SizedBox(height: Space.s10),
                      actions,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: context.colors.bgCanvas,
      child: Padding(
        padding: EdgeInsets.fromLTRB(layout.margin, insets.top, layout.margin, bottom),
        child: Column(
          children: <Widget>[
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: Center(child: content),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.s8),
            actions,
          ],
        ),
      ),
    );
  }
}

/// Inline caption in `color.danger` with the ⚠ glyph under the text block
/// (03a §3 Error state, §4; 12 P11/P12). Appears with `crossfade-state`
/// (160 ms) and is announced politely.
class InlineErrorCaption extends StatefulWidget {
  const InlineErrorCaption({required this.text, super.key});

  /// Message; `null` collapses the caption.
  final String? text;

  @override
  State<InlineErrorCaption> createState() => _InlineErrorCaptionState();
}

class _InlineErrorCaptionState extends State<InlineErrorCaption> {
  @override
  void initState() {
    super.initState();
    _announce();
  }

  @override
  void didUpdateWidget(InlineErrorCaption old) {
    super.didUpdateWidget(old);
    if (widget.text != old.text) _announce();
  }

  void _announce() {
    final String? text = widget.text;
    if (text == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) announce(context, text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    final String? text = widget.text;
    return AnimatedSwitcher(
      duration: Motion.durationFast,
      switchInCurve: Motion.easeStandard,
      switchOutCurve: Motion.easeStandard,
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              key: ValueKey<String>(text),
              padding: const EdgeInsets.only(top: Space.s3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    height: TypeTokens.caption.lineHeight,
                    child: Center(
                      child: WaiterIconView(WaiterIcon.triangleAlert, size: IconSize.s16, color: c.danger),
                    ),
                  ),
                  const SizedBox(width: Space.s1),
                  Flexible(
                    child: ScaledText(text, type: TypeTokens.caption, color: c.danger, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
    );
  }
}
