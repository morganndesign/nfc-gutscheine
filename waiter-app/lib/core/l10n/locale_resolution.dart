import 'dart:ui' show Locale;

import '../../l10n/app_localizations.dart';
import 'ui_language.dart';

/// Locales the app declares to the platform (09 §6.5): `de`, `en`, `bs` and
/// the generated BHS copies `hr` and `sr`, so that system locale matching
/// (iOS preferred languages, Android 13+ per-app language) lists all five.
const List<Locale> supportedLocales = AppLocalizations.supportedLocales;

/// Locale the app loads for each UI language.
///
/// All BHS phones resolve to `bs`: the strings of `hr`/`sr` are identical
/// copies, and `bs` keeps the Flutter framework strings (text selection
/// menu, etc.) in Latin script — `sr` would give Cyrillic framework strings,
/// which 12 §1.2 rules out (BHS = Latin).
const Map<UiLanguage, Locale> appLocaleOf = <UiLanguage, Locale>{
  UiLanguage.de: Locale('de'),
  UiLanguage.en: Locale('en'),
  UiLanguage.bhs: Locale('bs'),
};

/// Resolves the app locale from the phone language (09 §6.5, brief §7):
/// `de*` → `de`, `en*` → `en`, `bs`/`hr`/`sr` in any script or region → `bs`,
/// anything else (or no locale) → `en`.
///
/// Only the phone's primary language counts ("the app follows the phone
/// language", brief §7); a secondary preferred language is not consulted.
Locale resolveAppLocale(Locale? phoneLocale) =>
    appLocaleOf[uiLanguageOf(phoneLocale)]!;

/// UI language for a (phone or app) locale; see [UiLanguage.fromLanguageCode].
UiLanguage uiLanguageOf(Locale? locale) =>
    UiLanguage.fromLanguageCode(locale?.languageCode);

/// For `WidgetsApp.localeListResolutionCallback`: resolves from the first
/// preferred locale only (see [resolveAppLocale]).
Locale localeListResolutionCallback(
  List<Locale>? locales,
  Iterable<Locale> supported,
) =>
    resolveAppLocale(locales == null || locales.isEmpty ? null : locales.first);

/// For `WidgetsApp.localeResolutionCallback` (single-locale platforms).
Locale localeResolutionCallback(Locale? locale, Iterable<Locale> supported) =>
    resolveAppLocale(locale);

/// The app locale for the signed-in account's language (`de`, `en`, `bs`); null = follow the phone.
Locale? accountLocale(String? language) => language == null ? null : resolveAppLocale(Locale(language));
