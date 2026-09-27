import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import 'pseudo_app_localizations.g.dart';

/// Pseudo-localisation build flag (09 §6.5):
/// `flutter run --dart-define=PSEUDO_L10N=true`.
// Never in release builds, whatever is defined.
const bool pseudoL10nEnabled =
    !kReleaseMode && bool.fromEnvironment('PSEUDO_L10N');

/// Loads the real [AppLocalizations] for a locale and wraps it in
/// [PseudoAppLocalizations] (+40 % length, accented letters, placeholders
/// untouched). Registered instead of `AppLocalizations.delegate` when
/// [pseudoL10nEnabled] is set; `AppLocalizations.of(context)` keeps working.
class PseudoLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  /// Creates the delegate.
  const PseudoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.delegate.isSupported(locale);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      // SynchronousFuture.then stays synchronous, so the first frame is not
      // delayed.
      AppLocalizations.delegate.load(locale).then(PseudoAppLocalizations.new);

  @override
  bool shouldReload(PseudoLocalizationsDelegate old) => false;
}
