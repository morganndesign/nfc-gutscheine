import 'package:flutter/widgets.dart';

import '../core/platform/nfc_service.dart';
import '../l10n/app_localizations.dart';

/// The localised texts of the iPhone system NFC sheet (09 §7.2, 12 §5.7).
IosSheetTexts iosSheetTextsOf(BuildContext context) {
  final AppLocalizations l = AppLocalizations.of(context);
  return IosSheetTexts(
    alert: l.iosSheetAlert,
    found: l.iosSheetFound,
    multiple: l.iosSheetMultiple,
    readFailed: l.iosSheetReadFailed,
    timeoutSoon: l.iosSheetTimeoutSoon,
    notCard: l.scanNotCard,
  );
}
