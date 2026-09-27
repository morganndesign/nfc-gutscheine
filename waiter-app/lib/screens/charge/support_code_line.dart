import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/platform/feedback_scope.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';

/// "Code 7F3A9C" on S07/S08 (12 §2.5): `type.caption` `fg.tertiary`,
/// read character by character; a long press copies the full request id
/// with `haptic.select` and the `common.copied` snackbar (03b §0).
class SupportCodeLine extends StatelessWidget {
  /// Creates the line.
  const SupportCodeLine({
    required this.code,
    required this.requestId,
    super.key,
    this.textAlign = TextAlign.center,
  });

  /// The 6-character support code.
  final String code;

  /// The full `X-Request-Id` copied by a long press.
  final String requestId;

  /// Alignment in its column.
  final TextAlign textAlign;

  void _copy(BuildContext context) {
    unawaited(Clipboard.setData(ClipboardData(text: requestId)));
    context.haptic(HapticToken.select);
    SnackbarHost.maybeOf(
      context,
    )?.show(SnackbarData(message: AppLocalizations.of(context).commonCopied));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.commonSupportCodeA11y(SupportCode.spoken(code)),
      excludeSemantics: true,
      onLongPress: () => _copy(context),
      child: GestureDetector(
        onLongPress: () => _copy(context),
        child: ScaledText(
          l10n.commonSupportCode(code),
          type: TypeTokens.caption,
          color: context.colors.fgTertiary,
          textAlign: textAlign,
        ),
      ),
    );
  }
}
