/// Localisation entry point (09 §6.5, 12 §1.2).
///
/// ```dart
/// WidgetsApp(
///   localizationsDelegates: appLocalizationsDelegates,
///   supportedLocales: supportedLocales,
///   localeListResolutionCallback: localeListResolutionCallback,
///   …
/// )
/// ```
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';
import 'pseudo_localization.dart';

export '../../l10n/app_localizations.dart';
export 'locale_resolution.dart';
export 'pseudo_localization.dart';
export 'pseudo_transform.dart' show pseudoLocalize;
export 'ui_language.dart';

/// App strings plus the framework localisations for de, en, bs, hr, sr.
/// Uses [PseudoLocalizationsDelegate] when built with
/// `--dart-define=PSEUDO_L10N=true`.
const List<LocalizationsDelegate<Object>> appLocalizationsDelegates =
    <LocalizationsDelegate<Object>>[
      pseudoL10nEnabled
          ? PseudoLocalizationsDelegate()
          : AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ];
