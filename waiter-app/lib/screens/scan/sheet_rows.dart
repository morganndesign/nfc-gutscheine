import 'package:flutter/material.dart' show Material, MaterialType, Switch;
import 'package:flutter/widgets.dart';

import '../../components/support/focus_ring.dart';
import '../../components/support/hairline.dart';
import '../../components/support/pressable.dart';
import '../../components/support/shape.dart';
import '../../components/support/text_emphasis.dart';
import '../../core/theme/theme.dart';

/// Minimum height of a fact row in the Recent detail (03b §6.5).
const double _factRowHeight = 48;

/// A read-only fact in the Recent detail (03b §6.5): label `type.body.m`
/// `fg.tertiary`, value `type.body.l` `fg.primary` right-aligned, 48 pt,
/// `border.subtle` divider. One accessibility element "label, value";
/// [onLongPress] copies the full value (support code / transaction id).
class FactRow extends StatelessWidget {
  /// Creates a row.
  const FactRow({
    required this.label,
    required this.value,
    super.key,
    this.spokenValue,
    this.showDivider = true,
    this.onLongPress,
  });

  /// Label.
  final String label;

  /// Visible value.
  final String value;

  /// Spoken value when it differs (amounts, digits).
  final String? spokenValue;

  /// Divider below the row.
  final bool showDivider;

  /// Long-press action.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    return Semantics(
      container: true,
      label: '$label, ${spokenValue ?? value}',
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: Column(
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _factRowHeight),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: ScaledText(
                      label,
                      type: TypeTokens.bodyM,
                      color: c.fgTertiary,
                    ),
                  ),
                  const SizedBox(width: Space.s4),
                  Flexible(
                    child: ScaledText(
                      value,
                      type: TypeTokens.bodyL,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
            if (showDivider) Hairline(color: c.borderSubtle),
          ],
        ),
      ),
    );
  }
}

/// A full-bleed row of the Menu sheet (03a §9): text inset by the screen
/// margin, min 56 pt (grows with text), pressed `bg.keyPressed` highlight
/// with `radius.m`, no scale; hairline divider inset by the margin.
///
/// [trailing] is a value text, chevron, external-link glyph or switch.
/// When [toggled] is set the row is a toggle (switch) announced "label, on".
class SheetRow extends StatelessWidget {
  /// Creates a row.
  const SheetRow({
    required this.label,
    super.key,
    this.caption,
    this.value,
    this.trailing,
    this.onPressed,
    this.toggled,
    this.labelColor,
    this.emphasised = false,
    this.showDivider = true,
    this.isLink = false,
  });

  /// Row label (`type.body.l`).
  final String label;

  /// Caption under the label (`type.caption`, `fg.tertiary`).
  final String? caption;

  /// Value (`type.body.m`, `fg.secondary`); moves below the label when it
  /// does not fit beside it (03a §9 Dynamic Type).
  final String? value;

  /// Trailing control or glyph.
  final Widget? trailing;

  /// Action; `null` = read-only row.
  final VoidCallback? onPressed;

  /// Switch state for toggle rows.
  final bool? toggled;

  /// Label colour (`color.danger` for Sign out).
  final Color? labelColor;

  /// Label weight 600 (Sign out).
  final bool emphasised;

  /// Divider below the row.
  final bool showDivider;

  /// Role link (opens a web page).
  final bool isLink;

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final WaiterColors c = theme.colors;
    final double margin = context.layout.margin;
    final String? rowValue = value;
    final String? rowCaption = caption;
    final Widget? end = trailing;
    const BorderRadius radius = BorderRadius.all(Radius.circular(Radii.m));

    Widget content(PressVisual? visual) {
      final Widget text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ScaledText.rich((ScaledStyles s) {
            final TextStyle style = s(
              TypeTokens.bodyL,
              color: labelColor ?? c.fgPrimary,
            );
            return TextSpan(
              text: label,
              style: emphasised
                  ? style.semiBold(boldText: theme.boldText)
                  : style,
            );
          }, type: TypeTokens.bodyL),
          if (rowCaption != null)
            ScaledText(
              rowCaption,
              type: TypeTokens.caption,
              color: c.fgTertiary,
            ),
        ],
      );
      final Widget row = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sizes.targetMin),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: margin, vertical: Space.s2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: rowValue == null
                    ? text
                    : Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: Space.s4,
                        children: <Widget>[
                          text,
                          ScaledText(
                            rowValue,
                            type: TypeTokens.bodyM,
                            color: c.fgSecondary,
                          ),
                        ],
                      ),
              ),
              if (end != null) ...<Widget>[
                const SizedBox(width: Space.s2),
                end,
              ],
            ],
          ),
        ),
      );
      final Widget highlighted = visual == null
          ? row
          : Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s2),
                    child: FocusRing(
                      visible: visual.focused,
                      radius: radius,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: Color.lerp(
                            c.bgKeyPressed.withValues(alpha: 0),
                            c.bgKeyPressed,
                            visual.pressAmount,
                          ),
                          shape: waiterShape(context, radius),
                        ),
                      ),
                    ),
                  ),
                ),
                row,
              ],
            );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          highlighted,
          if (showDivider)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: Hairline(color: c.borderSubtle),
            ),
        ],
      );
    }

    final VoidCallback? action = onPressed;
    if (action == null && toggled == null) {
      return Semantics(
        container: true,
        label: rowValue == null ? label : '$label, $rowValue',
        excludeSemantics: true,
        child: content(null),
      );
    }
    return Pressable(
      onPressed: action,
      isLink: isLink,
      semanticsLabel: rowCaption == null ? label : '$label, $rowCaption',
      semanticsValue: rowValue,
      semanticsToggled: toggled,
      builder: (BuildContext context, PressVisual visual) => content(visual),
    );
  }
}

/// The platform switch tinted with the tokens (03a §9): on-track
/// `color.action.primary`. The row carries the semantics and the tap.
class SheetSwitch extends StatelessWidget {
  /// Creates the switch visual.
  const SheetSwitch({required this.value, super.key});

  /// On / off.
  final bool value;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: Switch.adaptive(
            value: value,
            onChanged: (_) {},
            activeTrackColor: c.actionPrimary,
            activeThumbColor: c.fgOnAccent,
            inactiveTrackColor: c.bgKey,
            inactiveThumbColor: c.borderControl,
            trackOutlineColor: WidgetStatePropertyAll<Color>(
              value ? c.actionPrimary : c.borderControl,
            ),
          ),
        ),
      ),
    );
  }
}
