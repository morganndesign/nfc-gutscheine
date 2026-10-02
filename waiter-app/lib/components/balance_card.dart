import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/api/models.dart' show VoucherStatus;
import '../core/format/format.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'money_context.dart';
import 'skeleton.dart';
import 'status_badge.dart';
import 'support/shape.dart';

/// Presentation of the [BalanceCard] (05 §3.1, 13 · R11).
enum BalanceCardDensity {
  /// ID-1 ratio (width ÷ 1.586), max 220 pt, `radius.xl`, padding 24.
  full,

  /// `BalanceCard / compact`: the 88-pt strip, `radius.l`, padding 12.
  compact;

  /// The density for a card slot: compact when the ID-1 card would be
  /// shorter than 136 pt (`availableHeight`) or at a font scale of 130 % and
  /// more. Otherwise the guest's card is shown as a card (ID-1), also on
  /// small phones with the keypad: it is what the waiter recognises.
  /// Chosen when S07 opens; the screen keeps it while typing.
  static BalanceCardDensity choose(
    BuildContext context, {
    required double availableHeight,
  }) {
    final WaiterLayout layout = context.layout;
    final double idOne = WaiterLayout.idOneCardHeight(layout.contentWidth);
    final bool tooShort =
        availableHeight < BalanceCardTokens.minFullHeight ||
        idOne < BalanceCardTokens.minFullHeight;
    final bool largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
    return tooShort || largeText
        ? BalanceCardDensity.compact
        : BalanceCardDensity.full;
  }
}

/// Card data shown by a [BalanceCard].
@immutable
class BalanceCardData {
  /// Creates the data.
  const BalanceCardData({
    required this.restaurantName,
    required this.balanceCents,
    required this.last4,
    required this.status,
    this.expiresAt,
    this.brandColor,
    this.logo,
  });

  /// Restaurant name as configured (not uppercased).
  final String restaurantName;

  /// Balance in cents.
  final int balanceCents;

  /// Last four digits of the voucher number.
  final String last4;

  /// Stored status (expired also when the date has passed).
  final VoucherStatus status;

  /// Expiry date (restaurant-local), `null` = no expiry.
  final CalendarDate? expiresAt;

  /// Restaurant `brand_color` (`#RRGGBB`), `null` = `color.brand.ink`.
  final String? brandColor;

  /// The restaurant's logo (PNG), shown instead of the name on the full card; `null` = the name.
  final Uint8List? logo;

  /// The badge shown on the card: none for an active voucher with a balance;
  /// "used up" for a zero balance (05 §3.1 states).
  BadgeStatus? get badge => switch (status) {
    VoucherStatus.active => balanceCents == 0 ? BadgeStatus.usedUp : null,
    VoucherStatus.blocked => BadgeStatus.blocked,
    VoucherStatus.expired => BadgeStatus.expired,
  };

  /// Blocked and expired render 40 % desaturated.
  bool get desaturated => isDesaturatedVoucherStatus(status.name);

  /// The card's one accessibility label (05 §3.1, 07 §5.1): "Voucher
  /// {restaurant}. Balance {spoken}. Voucher ending {6 4 8 8}. Valid until
  /// {long date}. {Status}."
  String semanticsLabel(AppLocalizations l10n, MoneyContext money) {
    final StringBuffer label = StringBuffer(
      l10n.balanceCardA11y(
        restaurantName,
        money.spoken(balanceCents),
        Spoken.characters(last4),
      ),
    );
    final CalendarDate? expiry = expiresAt;
    label
      ..write(' ')
      ..write(
        expiry == null
            ? l10n.balanceCardNoExpiry
            : l10n.balanceCardValidUntil(money.longDate(expiry)),
      )
      ..write('.');
    final BadgeStatus? status = badge;
    if (status != null) label.write(' ${statusBadgeLabel(l10n, status)}.');
    return label.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is BalanceCardData &&
      other.restaurantName == restaurantName &&
      other.balanceCents == balanceCents &&
      other.last4 == last4 &&
      other.status == status &&
      other.expiresAt == expiresAt &&
      other.brandColor == brandColor &&
      identical(other.logo, logo);

  @override
  int get hashCode => Object.hash(
    restaurantName,
    balanceCents,
    last4,
    status,
    expiresAt,
    brandColor,
    logo,
  );
}

/// The digital twin of the guest's gift card (05 §3.1, 04 §8.6).
///
/// - Fill: `brand_color` with a 6 % sheen (flat in high contrast), text
///   colour and contrast fallback from `resolveBrandCardColors`; blocked,
///   expired are 40 % desaturated; light theme glow
///   `elev.card-brand` (`elev.2` when desaturated), dark theme a 1-px
///   `color.card.borderDark` outline. Continuous corners on iOS.
/// - [data] `null` shows the card skeleton (brand colour known from the
///   session, text-colour bars at 16 %, sweep at 8 %).
/// - Motion: with [arrivalScale] the card springs in on first build
///   (`motion.spring.card`, opacity over 160 ms; fade only under Reduce
///   Motion, 06 M08); a different card cross-fades over 300 ms
///   (`time.cardSwap`, 06 M21); skeleton → content over 160 ms (06 M09).
/// - Not interactive. One accessibility element: "Gift card {restaurant}.
///   Balance {spoken}. Card ending {6 4 8 8}. Valid until {date}.
///   {status}". Text inside scales to 130 % at most.
class BalanceCard extends StatefulWidget {
  /// Creates a card.
  const BalanceCard({
    required this.data,
    required this.money,
    super.key,
    this.density = BalanceCardDensity.full,
    this.skeletonBrandColor,
    this.arrivalScale,
    this.onContrastFallback,
    this.maxHeight = Sizes.balanceCardMaxHeight,
  });

  /// Card data; `null` = loading skeleton.
  final BalanceCardData? data;

  /// Formatting context.
  final MoneyContext money;

  /// Full or compact.
  final BalanceCardDensity density;

  /// Height cap of the full card: 220 pt on phones (brief), the slot
  /// height when it is 136–219 pt (the card keeps its ratio and narrows,
  /// 08 §3.2), 277 pt single-column tablets and 303 pt in the tablet
  /// two-pane (08 §3.3, §4.2). The width follows at 1.586 : 1, centred.
  /// Ignored by the compact strip (88 pt).
  final double maxHeight;

  /// Brand colour for the skeleton (from the session).
  final String? skeletonBrandColor;

  /// Arrival start scale (06 M08: 0.40 from the Android NFC / QR origin,
  /// 0.60 iPhone / S11); `null` = no arrival animation.
  final double? arrivalScale;

  /// Called after a build that fell back to `color.brand.ink` for contrast;
  /// the screen logs `brand_color_contrast_fallback` once per restaurant.
  final VoidCallback? onContrastFallback;

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard>
    with TickerProviderStateMixin {
  AnimationController? _spring;
  AnimationController? _fadeIn;
  CurvedAnimation? _fadeCurve;
  late final AnimationController _swap = AnimationController(
    vsync: this,
    value: 1,
  );
  late final CurvedAnimation _swapCurve = CurvedAnimation(
    parent: _swap,
    curve: Motion.easeStandard,
  );

  /// The face fading out during a swap; `_hasOutgoing` false = none.
  BalanceCardData? _outgoing;
  bool _hasOutgoing = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final double? from = widget.arrivalScale;
    if (from != null) {
      final AnimationController fade = _fadeIn = AnimationController(
        vsync: this,
        duration: Motion.durationFast,
      )..forward();
      _fadeCurve = CurvedAnimation(parent: fade, curve: Motion.easeDecelerate);
      _spring = AnimationController.unbounded(vsync: this, value: from)
        ..animateWith(SpringSimulation(Motion.springCard, from, 1, 0));
    }
    _swap.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && _hasOutgoing && mounted) {
        setState(() {
          _hasOutgoing = false;
          _outgoing = null;
        });
      }
    });
  }

  @override
  void didUpdateWidget(BalanceCard old) {
    super.didUpdateWidget(old);
    final bool swapped =
        old.data?.last4 != widget.data?.last4 ||
        (old.data == null) != (widget.data == null);
    if (!swapped) return;
    // 06 M09: skeleton → content 160 ms; M21: card → card 300 ms.
    _swap.duration = old.data == null || widget.data == null
        ? Motion.durationFast
        : Times.cardSwap;
    _outgoing = old.data;
    _hasOutgoing = true;
    _generation++;
    _swap.forward(from: 0);
  }

  @override
  void dispose() {
    _spring?.dispose();
    _fadeCurve?.dispose();
    _fadeIn?.dispose();
    _swapCurve.dispose();
    _swap.dispose();
    super.dispose();
  }

  Widget _face(BalanceCardData? data) => data == null
      ? _CardSkeleton(
          brandColor: widget.skeletonBrandColor,
          density: widget.density,
          maxHeight: widget.maxHeight,
        )
      : _CardFace(
          data: data,
          money: widget.money,
          density: widget.density,
          maxHeight: widget.maxHeight,
          onContrastFallback: widget.onContrastFallback,
        );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BalanceCardData? data = widget.data;
    Widget card = Stack(
      alignment: Alignment.topCenter,
      children: <Widget>[
        if (_hasOutgoing)
          KeyedSubtree(
            key: ValueKey<int>(-_generation),
            child: FadeTransition(
              opacity: ReverseAnimation(_swapCurve),
              child: _face(_outgoing),
            ),
          ),
        KeyedSubtree(
          key: ValueKey<int>(_generation),
          child: FadeTransition(opacity: _swapCurve, child: _face(data)),
        ),
      ],
    );

    final AnimationController? spring = _spring;
    final CurvedAnimation? fade = _fadeCurve;
    if (spring != null && fade != null) {
      final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
      card = FadeTransition(
        opacity: fade,
        child: reduceMotion
            ? card
            : AnimatedBuilder(
                animation: spring,
                builder: (BuildContext context, Widget? child) =>
                    Transform.scale(scale: spring.value, child: child),
                child: card,
              ),
      );
    }
    return Semantics(
      container: true,
      label: data == null
          ? l10n.scanLookingUp
          : data.semanticsLabel(l10n, widget.money),
      excludeSemantics: true,
      child: card,
    );
  }
}

/// Card size in a slot [maxWidth] wide: the strip spans the width at
/// 88 pt; the full card keeps 1.586 : 1 within [maxWidth] × [maxHeight].
Size _cardSize(BalanceCardDensity density, double maxWidth, double maxHeight) {
  if (density == BalanceCardDensity.compact) {
    return Size(maxWidth, BalanceCardTokens.compactHeight);
  }
  final double height = math.min(
    maxWidth / BalanceCardTokens.aspectRatio,
    maxHeight,
  );
  return Size(height * BalanceCardTokens.aspectRatio, height);
}

/// A real ID-1 card: 3.18 mm corners on 85.6 mm, so the corner grows with the card instead of a fixed, much
/// rounder radius. The compact strip is no card and keeps its token radius.
BorderRadius _cardRadius(BalanceCardDensity density, double width) => BorderRadius.circular(
  density == BalanceCardDensity.compact ? BalanceCardTokens.compactRadius : width * _cornerPerWidth,
);

const double _cornerPerWidth = 3.18 / 85.6;

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.density,
    required this.maxHeight,
    required this.colors,
    required this.child,
  });

  final BalanceCardDensity density;
  final double maxHeight;
  final BrandCardColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool flat = context.waiter.isHighContrast;
    final double padding = density == BalanceCardDensity.compact
        ? BalanceCardTokens.compactPadding
        : BalanceCardTokens.padding;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = _cardSize(density, constraints.maxWidth, maxHeight);
        Widget face = Padding(
          padding: EdgeInsets.all(padding),
          // Text is capped at 130 %; at the largest sizes the screen
          // uses the compact strip (05 §3.1). Anything that still does
          // not fit is clipped by the card, never laid out outside it.
          child: ClipRect(child: child),
        );
        // A smaller card is the same card, scaled: laid out at the phone size and shrunk as a whole, so name,
        // balance and number never collide on a small screen.
        if (density == BalanceCardDensity.full &&
            size.height < _referenceHeight) {
          face = FittedBox(
            child: SizedBox(
              width: _referenceHeight * BalanceCardTokens.aspectRatio,
              height: _referenceHeight,
              child: face,
            ),
          );
        }
        return Center(
          heightFactor: 1,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: WaiterSurface(
              radius: _cardRadius(density, size.width),
              color: colors.fill,
              gradient: flat ? null : colors.sheen,
              outline: colors.outline,
              clip: true,
              child: face,
            ),
          ),
        );
      },
    );
  }
}

/// Height at which the full card is laid out; smaller cards scale this layout down.
const double _referenceHeight = Sizes.balanceCardMaxHeight;

/// Text scale cap for everything inside the card (04 §3.7).
const double _cardTextScale = 1.3;

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.data,
    required this.money,
    required this.density,
    required this.maxHeight,
    required this.onContrastFallback,
  });

  final double maxHeight;

  final BalanceCardData data;
  final MoneyContext money;
  final BalanceCardDensity density;
  final VoidCallback? onContrastFallback;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterTheme theme = context.waiter;
    final BrandCardColors colors = resolveBrandCardColors(
      brandColor: data.brandColor,
      colors: theme.colors,
      elevation: theme.elevation,
      desaturated: data.desaturated,
    );
    final VoidCallback? fallback = onContrastFallback;
    if (colors.isContrastFallback && fallback != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => fallback());
    }
    final bool compact = density == BalanceCardDensity.compact;
    final BadgeStatus? badgeStatus = data.badge;
    final Widget? badge = badgeStatus == null
        ? null
        : StatusBadge(status: badgeStatus, cardOutline: colors.badgeOutline);
    final Widget glyph = WaiterIconView.mark(
      WaiterIcon.nfcArcs,
      dimension: compact
          ? BalanceCardTokens.compactGlyphSize
          : BalanceCardTokens.glyphSize,
      strokeWidth: IconSize.s32.stroke,
      color: colors.nfcGlyph,
    );
    final Widget name = ScaledText(
      data.restaurantName,
      type: compact ? TypeTokens.caption : TypeTokens.titleM,
      color: colors.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      maxScale: _cardTextScale,
    );
    final Widget balance = _Balance(
      parts: money.parts(data.balanceCents),
      color: colors.text,
    );

    final Widget content;
    if (compact) {
      content = _Centred(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: name),
              glyph,
            ],
          ),
          const SizedBox(height: BalanceCardTokens.compactRowGap),
          Row(
            children: <Widget>[
              Expanded(child: balance),
              ?badge,
            ],
          ),
        ],
      );
    } else {
      final CalendarDate? expiry = data.expiresAt;
      final String masked = l10n.balanceCardMasked(data.last4);
      final String meta = expiry == null
          ? masked
          : '$masked · ${l10n.balanceCardValidUntil(money.date(expiry))}';
      content = _TopBottom(
        top: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ScaledText(
                    l10n.balanceCardOverline,
                    type: TypeTokens.overline,
                    color: colors.secondaryText,
                    maxLines: 1,
                    maxScale: _cardTextScale,
                  ),
                  const SizedBox(height: BalanceCardTokens.overlineGap),
                  if (data.logo != null)
                    _Logo(bytes: data.logo!, label: data.restaurantName)
                  else
                    name,
                ],
              ),
            ),
            const SizedBox(
              width:
                  BalanceCardTokens.nameGlyphClearance -
                  BalanceCardTokens.glyphSize,
            ),
            glyph,
          ],
        ),
        bottom: <Widget>[
          balance,
          const SizedBox(height: BalanceCardTokens.metaGap),
          ScaledText(
            meta,
            type: TypeTokens.caption,
            color: colors.secondaryText,
            maxLines: 1,
            softWrap: false,
            maxScale: _cardTextScale,
          ),
          if (badge != null) ...<Widget>[
            const SizedBox(height: BalanceCardTokens.badgeGap),
            badge,
          ],
        ],
      );
    }

    return _CardShell(
      density: density,
      maxHeight: maxHeight,
      colors: colors,
      child: content,
    );
  }
}

/// The restaurant's logo on a white plate (any logo stays readable on any card colour).
class _Logo extends StatelessWidget {
  const _Logo({required this.bytes, required this.label});

  final Uint8List bytes;
  final String label;

  static const double _height = 40;

  @override
  Widget build(BuildContext context) => Container(
    height: _height,
    constraints: const BoxConstraints(maxWidth: 180),
    padding: const EdgeInsets.symmetric(
      horizontal: Space.s3,
      vertical: Space.s1,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(Radii.s),
    ),
    child: Image.memory(
      bytes,
      fit: BoxFit.contain,
      semanticLabel: label,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    ),
  );
}

/// Balance with the currency symbol at 60 % on the same baseline and the
/// locale gap (04 §3.4); never smaller than 40 pt.
class _Balance extends StatelessWidget {
  const _Balance({required this.parts, required this.color});

  final MoneyParts parts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ScaledText.rich(
        (ScaledStyles s) {
          final TextStyle digits = s(TypeTokens.balance, color: color);
          final TextStyle symbol = s(TypeTokens.currencyBalance, color: color);
          final double gap = s.scale(
            TypeTokens.balance.fontSize *
                (parts.spaced
                    ? TypeTokens.currencyGapSpaced
                    : TypeTokens.currencyGapTight),
          );
          final InlineSpan gapSpan = TextSpan(
            text: ' ',
            style: symbol.copyWith(letterSpacing: gap),
          );
          return TextSpan(
            children: parts.symbolLeading
                ? <InlineSpan>[
                    TextSpan(text: parts.symbol, style: symbol),
                    gapSpan,
                    TextSpan(text: parts.number, style: digits),
                  ]
                : <InlineSpan>[
                    TextSpan(text: parts.number, style: digits),
                    gapSpan,
                    TextSpan(text: parts.symbol, style: symbol),
                  ],
          );
        },
        type: TypeTokens.balance,
        maxScale: _cardTextScale,
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({
    required this.brandColor,
    required this.density,
    required this.maxHeight,
  });

  final double maxHeight;

  final String? brandColor;
  final BalanceCardDensity density;

  /// Bar sizes of 05 §3.6 (name, balance, meta).
  static const Size _nameBar = Size(160, 16);
  static const Size _balanceBar = Size(140, 28);
  static const Size _metaBar = Size(180, 10);

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final BrandCardColors colors = resolveBrandCardColors(
      brandColor: brandColor,
      colors: theme.colors,
      elevation: theme.elevation,
    );
    final Color base = colors.text.withValues(
      alpha: Opacities.skeletonPlaceholderCard,
    );
    final Color highlight = colors.text.withValues(
      alpha: Opacities.skeletonHighlight,
    );
    Widget bar(Size size) => SkeletonBox(
      width: size.width,
      height: size.height,
      radius: size.height / 2,
      baseColor: base,
      highlightColor: highlight,
    );
    final bool compact = density == BalanceCardDensity.compact;
    final Widget content = compact
        ? _Centred(
            children: <Widget>[
              bar(_nameBar),
              const SizedBox(height: Space.s2),
              bar(_balanceBar),
            ],
          )
        : _TopBottom(
            top: Padding(
              padding: EdgeInsets.only(
                top:
                    TypeTokens.overline.lineHeight +
                    BalanceCardTokens.overlineGap,
              ),
              child: bar(_nameBar),
            ),
            bottom: <Widget>[
              bar(_balanceBar),
              const SizedBox(height: Space.s3),
              bar(_metaBar),
            ],
          );
    return SkeletonGroup(
      child: _CardShell(
        density: density,
        maxHeight: maxHeight,
        colors: colors,
        child: content,
      ),
    );
  }
}

/// Full card layout: the top block anchored top, the bottom block anchored
/// bottom, free space between (05 §3.1 "Vertical distribution").
class _TopBottom extends StatelessWidget {
  const _TopBottom({required this.top, required this.bottom});

  final Widget top;
  final List<Widget> bottom;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      PositionedDirectional(start: 0, end: 0, top: 0, child: top),
      PositionedDirectional(
        start: 0,
        end: 0,
        bottom: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: bottom,
        ),
      ),
    ],
  );
}

/// Compact strip layout: rows centred as one block.
class _Centred extends StatelessWidget {
  const _Centred({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => OverflowBox(
    maxHeight: double.infinity,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}
