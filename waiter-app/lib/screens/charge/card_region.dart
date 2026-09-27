import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

import 'charge_metrics.dart';

/// Where the card sits in its region.
enum CardAnchor {
  /// Leftover space above the card, close to the keypad (03b §2.4, 08 §3.2).
  bottom,

  /// Vertically centred (tablet landscape left pane, 08 §4.2).
  centre,

  /// Card first, [ChargeCardSliver.trailing] below (card-state variants,
  /// 03b §2.14).
  top,
}

/// Builds the BalanceCard for the density and height cap the slot chose.
typedef CardSlotBuilder =
    Widget Function(
      BuildContext context,
      BalanceCardDensity density,
      double maxHeight,
    );

/// The BalanceCard slot of S07 as a sliver (03b §2.4, 08 §3.2).
///
/// The card takes the viewport height the slivers before it leave: the
/// fixed action block below it (a reversed scroll view lays that block out
/// first) or nothing. It renders the ID-1 card up to [maxHeight], or
/// `BalanceCard / compact` when that height is below 136 pt or at large
/// text (13 · R11, `BalanceCardDensity.choose`). Because the density
/// follows the available height, it never changes while typing — every
/// row below the card has a fixed height. When the viewport is shorter than
/// its content the scroll view scrolls this informational part; the action
/// block stays anchored (07 §6.1).
class ChargeCardSliver extends StatelessWidget {
  /// Creates the slot.
  const ChargeCardSliver({
    required this.card,
    required this.horizontalInset,
    required this.anchor,
    super.key,
    this.trailing = const <Widget>[],
    this.topGap = 0,
    this.maxHeight = Sizes.balanceCardMaxHeight,
    this.withKeypad = true,
  });

  /// Height cap of the ID-1 card ([cardMaxHeight]).
  final double maxHeight;

  /// Whether the keypad shares the screen (`BalanceCardDensity.choose`).
  final bool withKeypad;

  /// The card for the chosen density.
  final CardSlotBuilder card;

  /// Side inset of the card and [trailing] (screen margin or 0 in a pane).
  final double horizontalInset;

  /// Card placement.
  final CardAnchor anchor;

  /// Content below the card with [CardAnchor.top], inset like the card.
  final List<Widget> trailing;

  /// Gap above the card (TopRow → card).
  final double topGap;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (BuildContext context, SliverConstraints constraints) {
        final double available = math.max(
          0,
          constraints.viewportMainAxisExtent -
              constraints.precedingScrollExtent -
              topGap,
        );
        final double maxWidth = math.max(
          0,
          constraints.crossAxisExtent - 2 * horizontalInset,
        );
        final BalanceCardDensity density = BalanceCardDensity.choose(
          context,
          availableHeight: available,
          withKeypad: withKeypad,
        );
        final Size size = ChargeMetrics.cardSize(
          density,
          maxWidth: maxWidth,
          availableHeight: available,
          maxHeight: maxHeight,
        );
        final Widget slot = Padding(
          padding: EdgeInsets.only(top: topGap),
          child: SizedBox.fromSize(
            size: size,
            child: card(context, density, maxHeight),
          ),
        );
        if (anchor == CardAnchor.top) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalInset),
              child: Column(children: <Widget>[slot, ...trailing]),
            ),
          );
        }
        return SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: anchor == CardAnchor.bottom
                ? Alignment.bottomCenter
                : Alignment.center,
            child: slot,
          ),
        );
      },
    );
  }
}
