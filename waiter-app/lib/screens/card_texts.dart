import '../l10n/app_localizations.dart';

/// The texts of the iPhone card sheet in the UI language (Android shows S11 itself).
({String prompt, String checking, String done, String failed}) cardTexts(AppLocalizations l10n) =>
    (prompt: l10n.cardWaiting, checking: l10n.cardChecking, done: l10n.cardDone, failed: l10n.cardFailed);
