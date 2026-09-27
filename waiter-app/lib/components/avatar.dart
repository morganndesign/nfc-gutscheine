import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';
import 'support/text_emphasis.dart';

/// Avatar sizes (05 §5.2).
enum AvatarSize {
  /// 40 pt, `type.label` 600 — TopBar.
  medium(Sizes.avatarM, TypeTokens.label),

  /// 56 pt, `type.title.m` 600 — Menu header.
  large(Sizes.avatarL, TypeTokens.titleM),

  /// 72 pt, `type.title.m` 600 — S04 Unlock identity (03a S04 "Avatar 72
  /// variant"; 56 pt at compact height, use [large] there).
  extraLarge(_avatarXl, TypeTokens.titleM);

  const AvatarSize(this.diameter, this.type);

  /// Diameter in pt.
  final double diameter;

  /// Initials style.
  final TypeSpec type;
}

/// S04 avatar diameter (03a §4 wireframe "Avatar 72").
const double _avatarXl = 72;

/// BHS digraphs that count as one letter (05 §5.2).
const List<String> _digraphs = <String>['dž', 'lj', 'nj'];

final RegExp _latinLetter = RegExp(r'\p{Script=Latin}', unicode: true);

/// The initial of one name part: its first letter, or a BHS digraph as
/// written ("Lj"); `null` when it does not start with a Latin letter.
String? _initialOf(String part) {
  final String lower = part.toLowerCase();
  for (final String d in _digraphs) {
    if (lower.startsWith(d)) {
      final String written = part.substring(0, d.length);
      return written[0].toUpperCase() + written.substring(1).toLowerCase();
    }
  }
  final String first = String.fromCharCode(part.runes.first);
  return _latinLetter.hasMatch(first) ? first.toUpperCase() : null;
}

/// Initials for [name] (05 §5.2): first letter of the first given name +
/// first letter of the last family name; one name → one letter; BHS
/// digraphs "Lj", "Nj", "Dž" are one letter rendered as written, and when
/// both initials are digraphs only the first is shown. `null` for empty or
/// non-Latin names (the `user` icon is shown instead).
String? avatarInitials(String name) {
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;
  final String? first = _initialOf(parts.first);
  if (first == null) return null;
  if (parts.length == 1) return first;
  final String? last = _initialOf(parts.last);
  if (last == null) return first;
  if (first.length > 1 && last.length > 1) return first;
  return '$first$last';
}

/// Who is signed in, by initials (05 §5.2): a `bg.key` circle with
/// `fg.primary` initials (1-pt `border.control` in high contrast), or the
/// `user` icon in `fg.secondary`. Non-interactive and hidden from assistive
/// technology (included in the TopBar / Menu header label).
class Avatar extends StatelessWidget {
  /// Creates an avatar for [name] (display name from `/auth/me`).
  const Avatar({required this.name, super.key, this.size = AvatarSize.medium});

  /// Display name.
  final String name;

  /// Size.
  final AvatarSize size;

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final WaiterColors c = theme.colors;
    final String? initials = avatarInitials(name);
    return ExcludeSemantics(
      child: Container(
        width: size.diameter,
        height: size.diameter,
        decoration: BoxDecoration(
          color: c.bgKey,
          shape: BoxShape.circle,
          border: theme.outlinesControls
              ? Border.all(color: c.borderControl)
              : null,
        ),
        alignment: Alignment.center,
        child: initials == null
            ? WaiterIconView(
                WaiterIcon.user,
                size: IconSize.s20,
                color: c.fgSecondary,
              )
            : ScaledText.rich(
                (ScaledStyles s) => TextSpan(
                  text: initials,
                  style: s(size.type).semiBold(boldText: theme.boldText),
                ),
                type: size.type,
                // The circle is fixed geometry; initials stop growing at
                // the key cap (04 §3.7 fixed-geometry rule).
                maxScale: TypeTokens.key.maxScale,
                maxLines: 1,
                softWrap: false,
              ),
      ),
    );
  }
}
