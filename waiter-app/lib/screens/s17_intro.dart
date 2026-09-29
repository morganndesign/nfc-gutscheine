import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../app/money.dart';
import '../components/components.dart';
import '../components/support/announce.dart';
import '../core/platform/feedback_scope.dart';
import '../core/state/loop_controller.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';

/// S17 · First-run intro (03a §12 as resolved in 13 · R04 / F-01): three
/// cards with the 160-pt line illustrations of 10 §4.4 (120 pt at compact
/// height). Skip stays in place on every card; the top row and the bottom
/// area stay fixed while the middle block pages.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

const int _pageCount = 3;

/// Text of one card and its illustration slot.
@immutable
class _Card {
  const _Card({required this.title, required this.body, this.illustration, this.icon});

  final String title;
  final String body;
  final WaiterIllustration? illustration;

  /// Card 1: `scan-qr-code` at `icon.48` instead of an illustration.
  final WaiterIcon? icon;
}

/// Vertical metrics of the middle block (03a §12 vertical budget).
@immutable
class _Metrics {
  const _Metrics({required this.above, required this.slot, required this.gap});

  /// Space between the top row and the illustration (88 / 32 pt).
  final double above;

  /// Illustration size; `null` hides the slot (200 % text on compact height).
  final double? slot;

  /// Illustration → title (32 / 24 pt).
  final double gap;

  static _Metrics of(BuildContext context) {
    final bool compact = context.layout.heightClass.isCompact;
    final double text = MediaQuery.textScalerOf(context).scale(1);
    // Dynamic Type: 120 pt from 150 %; hidden from 200 % on compact height
    // (the slot collapses, `space.8` remains above the title).
    if (compact && text >= _hideIllustrationScale) {
      return const _Metrics(above: Space.s8, slot: null, gap: 0);
    }
    final double slot = compact || text >= _smallIllustrationScale
        ? IllustrationTokens.introCompact
        : IllustrationTokens.intro;
    return compact
        ? _Metrics(above: Space.s8, slot: slot, gap: Space.s6)
        : _Metrics(above: Space.s16 + Space.s6, slot: slot, gap: Space.s8);
  }
}

/// 03a §12 Dynamic Type: 120 pt from 150 % text, hidden from 200 % on
/// compact height.
const double _smallIllustrationScale = 1.5;
const double _hideIllustrationScale = 2;

/// A swipe this far past the last card counts as "Start".
const double _swipePastStart = Space.s12;

/// Landscape tablets: illustration left, text right, inside 720 pt.
const double _landscapeWidth = 720;

/// Page dots: 8 × 8 pt, `space.2` apart.
const double _dot = 8;

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pages = PageController();
  int _page = 0;
  double _overscroll = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // The "shown" flag is written when card 1 first renders, so a crash or
    // an app kill never replays the intro (03a §12).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.services.session.markIntroShown();
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    context.services.session.finishIntro();
  }

  void _pageChanged(int page, List<_Card> cards) {
    if (page == _page) return;
    setState(() => _page = page);
    context.haptic(HapticToken.select);
    announce(context, _cardLabel(AppLocalizations.of(context), page, cards[page]));
  }

  void _goTo(int page, List<_Card> cards) {
    if (MediaQuery.disableAnimationsOf(context) || !_pages.hasClients) {
      // Reduce Motion: paging is a 160 ms cross-fade.
      _pageChanged(page, cards);
      return;
    }
    unawaited(_pages.animateToPage(page, duration: Motion.durationBase, curve: Motion.easeStandard));
  }

  void _next(List<_Card> cards) {
    if (_page == _pageCount - 1) {
      _finish();
    } else {
      _goTo(_page + 1, cards);
    }
  }

  /// Android back: previous card; on card 1 it acts as Skip.
  void _back(List<_Card> cards) {
    if (_page == 0) {
      _finish();
    } else {
      _goTo(_page - 1, cards);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (_page != _pageCount - 1) return false;
    switch (n) {
      case ScrollStartNotification():
        _overscroll = 0;
      case OverscrollNotification(:final double overscroll) when n.dragDetails != null && overscroll > 0:
        _overscroll += overscroll;
      case ScrollUpdateNotification() when n.dragDetails != null:
        final double past = n.metrics.pixels - n.metrics.maxScrollExtent;
        if (past > _overscroll) _overscroll = past;
      default:
        break;
    }
    if (_overscroll > _swipePastStart) _finish();
    return false;
  }

  static String _cardLabel(AppLocalizations l, int page, _Card card) =>
      '${l.introPage(page + 1)}. ${card.title}. ${card.body}';

  List<_Card> _cards(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return <_Card>[
      _Card(title: l.intro1Title, body: l.intro1Body, icon: WaiterIcon.scanQrCode),
      _Card(
        title: l.intro2Title,
        body: l.intro2Body(context.money.format(LoopController.holdThreshold)),
        illustration: WaiterIllustration.introAmount,
      ),
      _Card(title: l.intro3Title, body: l.intro3Body, illustration: WaiterIllustration.introDone),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final WaiterLayout layout = context.layout;
    final List<_Card> cards = _cards(context);
    final bool landscape = layout.widthClass.isTablet && layout.size.width > layout.size.height;
    final _Metrics metrics = _Metrics.of(context);

    final Widget pager = _Pager(
      controller: _pages,
      page: _page,
      onScroll: _onScroll,
      onPageChanged: (int page) => _pageChanged(page, cards),
      onSwipe: (int page) => _goTo(page, cards),
      itemBuilder: (BuildContext context, int index) => _CardView(
        card: cards[index],
        label: _cardLabel(l, index, cards[index]),
        metrics: metrics,
        landscape: landscape,
      ),
    );

    final Widget bottom = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Dots(page: _page),
        const SizedBox(height: Space.s6),
        PrimaryButton(label: _page == _pageCount - 1 ? l.introStart : l.introNext, onPressed: () => _next(cards)),
      ],
    );

    final Widget skip = SizedBox(
      height: Sizes.targetMin,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          // The label aligns with the margin; the 56-pt target overlaps it.
          padding: EdgeInsetsDirectional.only(end: layout.margin - ButtonTokens.tertiaryPaddingHorizontal),
          child: TertiaryButton(label: l.introSkip, onPressed: _finish),
        ),
      ),
    );

    final EdgeInsets bottomPadding = EdgeInsets.fromLTRB(
      layout.margin,
      0,
      layout.margin,
      layout.viewPadding.bottom + layout.ctaBottomPadding,
    );

    final Widget body = landscape
        ? Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _landscapeWidth),
                child: Column(
                  children: <Widget>[
                    Expanded(child: pager),
                    Padding(
                      padding: bottomPadding,
                      child: Row(
                        children: <Widget>[
                          const SizedBox(width: IllustrationTokens.intro + Space.s8),
                          Expanded(child: bottom),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : Expanded(
            child: Column(
              children: <Widget>[
                Expanded(child: pager),
                Padding(
                  padding: bottomPadding,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
                      child: bottom,
                    ),
                  ),
                ),
              ],
            ),
          );

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _back(cards);
      },
      child: ColoredBox(
        color: context.colors.bgCanvas,
        child: Column(
          children: <Widget>[
            SizedBox(height: layout.viewPadding.top),
            skip,
            body,
          ],
        ),
      ),
    );
  }
}

/// The paging middle block: a PageView that follows the finger and settles
/// with `motion.spring.soft`; under Reduce Motion a 160 ms cross-fade
/// between cards, still paged by swipe and by the screen reader's scroll
/// gesture.
class _Pager extends StatelessWidget {
  const _Pager({
    required this.controller,
    required this.page,
    required this.onScroll,
    required this.onPageChanged,
    required this.onSwipe,
    required this.itemBuilder,
  });

  final PageController controller;
  final int page;
  final NotificationListenerCallback<ScrollNotification> onScroll;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onSwipe;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (!MediaQuery.disableAnimationsOf(context)) {
      return NotificationListener<ScrollNotification>(
        onNotification: onScroll,
        child: PageView.builder(
          controller: controller,
          physics: const _IntroPagePhysics(),
          itemCount: _pageCount,
          onPageChanged: onPageChanged,
          itemBuilder: itemBuilder,
        ),
      );
    }
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    void step(int delta) {
      final int target = page + delta;
      if (target >= 0 && target < _pageCount) onSwipe(target);
    }

    return Semantics(
      onScrollLeft: page < _pageCount - 1 ? () => step(rtl ? -1 : 1) : null,
      onScrollRight: page > 0 ? () => step(rtl ? 1 : -1) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (DragEndDetails d) {
          final double v = d.primaryVelocity ?? 0;
          if (v == 0) return;
          step((v < 0) != rtl ? 1 : -1);
        },
        child: AnimatedSwitcher(
          duration: Motion.durationFast,
          child: KeyedSubtree(key: ValueKey<int>(page), child: itemBuilder(context, page)),
        ),
      ),
    );
  }
}

/// Page physics whose release settles with `motion.spring.soft` (03a §12).
class _IntroPagePhysics extends PageScrollPhysics {
  const _IntroPagePhysics({super.parent});

  @override
  _IntroPagePhysics applyTo(ScrollPhysics? ancestor) => _IntroPagePhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => Motion.springSoft;
}

/// One card of the middle block, read as one group: "Page n of 3. Title.
/// Body." (`intro.page`). The illustration is decorative. Scrolls
/// vertically only as a last resort (very large text).
class _CardView extends StatelessWidget {
  const _CardView({required this.card, required this.label, required this.metrics, required this.landscape});

  final _Card card;
  final String label;
  final _Metrics metrics;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    final WaiterLayout layout = context.layout;
    final TextAlign align = landscape ? TextAlign.start : TextAlign.center;
    final double? slot = landscape ? IllustrationTokens.intro : metrics.slot;

    final Widget? visual = slot == null ? null : _visual(context, slot);
    final Widget text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: landscape ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: <Widget>[
        ScaledText(card.title, type: TypeTokens.titleL, textAlign: align),
        const SizedBox(height: Space.s3),
        ScaledText(card.body, type: TypeTokens.bodyL, color: c.fgSecondary, textAlign: align),
      ],
    );

    final Widget content = landscape
        ? Row(
            children: <Widget>[
              ?visual,
              const SizedBox(width: Space.s8),
              Expanded(child: text),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: metrics.above),
              if (visual != null) ...<Widget>[visual, SizedBox(height: metrics.gap)],
              text,
            ],
          );

    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) => SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: layout.margin),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: landscape ? box.maxHeight : 0),
            child: Align(
              alignment: landscape ? Alignment.center : Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: landscape ? _landscapeWidth : LayoutTokens.textMeasureTablet),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _visual(BuildContext context, double size) {
    final WaiterIllustration? illustration = card.illustration;
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: illustration != null
            ? IllustrationView(illustration, size: size)
            : WaiterIconView(card.icon!, size: IconSize.s48, color: context.colors.fgSecondary),
      ),
    );
  }
}

/// Page dots (indicators only, not interactive): active `fg.primary`,
/// inactive `border.strong`, cross-fading over `motion.duration.fast`.
class _Dots extends StatelessWidget {
  const _Dots({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (int i = 0; i < _pageCount; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: Space.s2),
            AnimatedContainer(
              duration: Motion.durationFast,
              curve: Motion.easeStandard,
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(shape: BoxShape.circle, color: i == page ? c.fgPrimary : c.borderStrong),
            ),
          ],
        ],
      ),
    );
  }
}
