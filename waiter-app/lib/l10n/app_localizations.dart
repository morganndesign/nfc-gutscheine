import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bs.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hr.dart';
import 'app_localizations_sr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bs'),
    Locale('de'),
    Locale('en'),
    Locale('hr'),
    Locale('sr'),
  ];

  /// Spec key: app.name (12 §5.1) · Max: 16 · Notes: 12 · launcher label, not translated
  ///
  /// In en, this message translates to:
  /// **'GiftCard Waiter'**
  String get appName;

  /// Spec key: common.cancel (12 §5.1) · Max: 12 · Notes: 03a/03b
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Spec key: common.close (12 §5.1) · Max: 12 · Notes: 03a (a11y on ✕) / 12 (button)
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Spec key: common.back (12 §5.1) · Max: — · Notes: 03a · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Spec key: common.done (12 §5.1) · Max: 12 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// Spec key: common.tryAgain (12 §5.1) · Max: 24 · Notes: 03b · §2.7
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// Spec key: common.scanAgain (12 §5.1) · Max: 24 · Notes: 03b · §2.7
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get commonScanAgain;

  /// Spec key: common.tapAgain (12 §5.1) · Max: 24 · Notes: Phase 4
  ///
  /// In en, this message translates to:
  /// **'Tap card again'**
  String get commonTapAgain;

  /// Spec key: common.openSettings (12 §5.1) · Max: 24 · Notes: 12 · = camera.denied.action (alias)
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get commonOpenSettings;

  /// Spec key: common.backToSignIn (12 §5.1) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get commonBackToSignIn;

  /// Spec key: common.checkAgain (12 §5.1) · Max: 24 · Notes: 12 · alias suspended.retry (03a)
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get commonCheckAgain;

  /// Spec key: common.supportCode (12 §5.1) · Max: 12 · Notes: 12 · alias problem.supportCode (03b) · §2.5
  ///
  /// In en, this message translates to:
  /// **'Code {code}'**
  String commonSupportCode(String code);

  /// Spec key: common.supportCode.a11y (12 §5.1) · Max: — · Notes: (a11y) · characters read singly
  ///
  /// In en, this message translates to:
  /// **'Support code {code}'**
  String commonSupportCodeA11y(String code);

  /// Spec key: common.copied (12 §5.1) · Max: 24 · Notes: 03b · snackbar after long-press on the code
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// Spec key: redeem.nothingBooked (12 §5.1) · Max: 28 · Notes: 03b · harmonised (DE full sentence)
  ///
  /// In en, this message translates to:
  /// **'Nothing was booked.'**
  String get redeemNothingBooked;

  /// Spec key: getManager (12 §5.1) · Max: 28 · Notes: B · always ends with "." when used in a body
  ///
  /// In en, this message translates to:
  /// **'Please get a manager'**
  String get getManager;

  /// Spec key: splash.loading (12 §5.2) · Max: — · Notes: 03a · (a11y), only if splash > 1 s
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get splashLoading;

  /// Spec key: startup.offline.title (12 §5.2) · Max: 32 · Notes: 12 · startup problem (signed out, server unreachable at launch)
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get startupOfflineTitle;

  /// Spec key: startup.offline.body (12 §5.2) · Max: 90 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'This phone is offline. Turn on Wi-Fi or mobile data, then try again.'**
  String get startupOfflineBody;

  /// Spec key: startup.hostNotFound.title (12 §5.2) · Max: 32 · Notes: 12 · DNS: the host name does not exist
  ///
  /// In en, this message translates to:
  /// **'Server not found'**
  String get startupHostNotFoundTitle;

  /// Spec key: startup.hostNotFound.body (12 §5.2) · Max: 90 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'The address {host} does not exist. Check the server address.'**
  String startupHostNotFoundBody(String host);

  /// Spec key: startup.refused.title (12 §5.2) · Max: 32 · Notes: 12 · connection refused
  ///
  /// In en, this message translates to:
  /// **'Server not running'**
  String get startupRefusedTitle;

  /// Spec key: startup.refused.body (12 §5.2) · Max: 90 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'Nothing answers at {host}. Check that the server is running and the address is right.'**
  String startupRefusedBody(String host);

  /// Spec key: startup.timeout.title (12 §5.2) · Max: 32 · Notes: 12 · timeout / no route
  ///
  /// In en, this message translates to:
  /// **'Server not responding'**
  String get startupTimeoutTitle;

  /// Spec key: startup.timeout.body (12 §5.2) · Max: 90 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'{host} did not answer in time. Check the network, then try again.'**
  String startupTimeoutBody(String host);

  /// Spec key: startup.tls.title (12 §5.2) · Max: 32 · Notes: 12 · TLS certificate rejected
  ///
  /// In en, this message translates to:
  /// **'No secure connection'**
  String get startupTlsTitle;

  /// Spec key: startup.tls.body (12 §5.2) · Max: 90 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'The certificate of {host} was rejected. Check the phone\'s date and time.'**
  String startupTlsBody(String host);

  /// Spec key: startup.serverError.title (12 §5.2) · Max: 32 · Notes: 12 · 5xx
  ///
  /// In en, this message translates to:
  /// **'Server problem'**
  String get startupServerErrorTitle;

  /// Spec key: startup.serverError.body (12 §5.2) · Max: 90 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'{host} reports a problem (status {status}). Try again later.'**
  String startupServerErrorBody(String host, String status);

  /// Spec key: startup.invalidResponse.title (12 §5.2) · Max: 32 · Notes: 12 · 404, HTML, redirect, unexpected JSON
  ///
  /// In en, this message translates to:
  /// **'Wrong server address'**
  String get startupInvalidResponseTitle;

  /// Spec key: startup.invalidResponse.body (12 §5.2) · Max: 90 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'{host} is not a GiftCard Pro server. Check the server address.'**
  String startupInvalidResponseBody(String host);

  /// Spec key: startup.configuration.title (12 §5.2) · Max: 32 · Notes: 12 · build without a valid API address
  ///
  /// In en, this message translates to:
  /// **'App not set up correctly'**
  String get startupConfigurationTitle;

  /// Spec key: startup.configuration.body (12 §5.2) · Max: 90 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'This version of the app has no valid server address. Please get a manager.'**
  String get startupConfigurationBody;

  /// Spec key: startup.storage.title (12 §5.2) · Max: 32 · Notes: 12 · secure storage (Keystore / Keychain) failed
  ///
  /// In en, this message translates to:
  /// **'Protected storage unavailable'**
  String get startupStorageTitle;

  /// Spec key: startup.storage.body (12 §5.2) · Max: 100 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'The app cannot open its protected storage. Restart the phone, then try again.'**
  String get startupStorageBody;

  /// Spec key: startup.unknown.title (12 §5.2) · Max: 32 · Notes: 12 · anything else, start watchdog
  ///
  /// In en, this message translates to:
  /// **'The app could not start'**
  String get startupUnknownTitle;

  /// Spec key: startup.unknown.body (12 §5.2) · Max: 90 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'Try again. If it happens again, please get a manager.'**
  String get startupUnknownBody;

  /// Spec key: startup.server (12 §5.2) · Max: — · Notes: 12 · small print below the actions
  ///
  /// In en, this message translates to:
  /// **'Server: {url}'**
  String startupServer(String url);

  /// Spec key: startup.detail (12 §5.2) · Max: — · Notes: 12 · technical reason, not translated
  ///
  /// In en, this message translates to:
  /// **'Details: {detail}'**
  String startupDetail(String detail);

  /// Spec key: startup.environment (12 §5.2) · Max: — · Notes: 12 · development and staging builds only
  ///
  /// In en, this message translates to:
  /// **'Environment: {name}'**
  String startupEnvironment(String name);

  /// Spec key: startup.changeServer (12 §5.2) · Max: 24 · Notes: 12 · development and staging builds only
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get startupChangeServer;

  /// Spec key: env.development (12 §5.2) · Max: 16 · Notes: 12 · environment name
  ///
  /// In en, this message translates to:
  /// **'Development'**
  String get envDevelopment;

  /// Spec key: env.staging (12 §5.2) · Max: 16 · Notes: 12 · environment name
  ///
  /// In en, this message translates to:
  /// **'Staging'**
  String get envStaging;

  /// Spec key: env.production (12 §5.2) · Max: 16 · Notes: 12 · environment name
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get envProduction;

  /// Spec key: env.badge.development (12 §5.2) · Max: 8 · Notes: 12 · corner badge, development builds
  ///
  /// In en, this message translates to:
  /// **'DEV'**
  String get envBadgeDevelopment;

  /// Spec key: env.badge.staging (12 §5.2) · Max: 8 · Notes: 12 · corner badge, staging builds
  ///
  /// In en, this message translates to:
  /// **'STAGING'**
  String get envBadgeStaging;

  /// Spec key: env.badge.a11y (12 §5.2) · Max: — · Notes: 12 · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Test environment {name}, server {host}. Long-press to change the server.'**
  String envBadgeA11y(String name, String host);

  /// Spec key: server.title (12 §5.2) · Max: 32 · Notes: 12 · server sheet (development and staging builds)
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverTitle;

  /// Spec key: server.label (12 §5.2) · Max: 24 · Notes: 12 · field label
  ///
  /// In en, this message translates to:
  /// **'API address'**
  String get serverLabel;

  /// Spec key: server.help (12 §5.2) · Max: 90 · Notes: 12 · helper text
  ///
  /// In en, this message translates to:
  /// **'For example http://192.168.1.20:8000 (/api/v1 is added).'**
  String get serverHelp;

  /// Spec key: server.default (12 §5.2) · Max: — · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'Default of this app: {url}'**
  String serverDefault(String url);

  /// Spec key: server.save (12 §5.2) · Max: 24 · Notes: 12 · signs out, then connects
  ///
  /// In en, this message translates to:
  /// **'Save and connect'**
  String get serverSave;

  /// Spec key: server.reset (12 §5.2) · Max: 24 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'Use default'**
  String get serverReset;

  /// Spec key: server.invalid (12 §5.2) · Max: 90 · Notes: 12 · field error
  ///
  /// In en, this message translates to:
  /// **'Not a valid address. Start with http:// or https://.'**
  String get serverInvalid;

  /// Spec key: server.httpsRequired (12 §5.2) · Max: 90 · Notes: 12 · field error (staging)
  ///
  /// In en, this message translates to:
  /// **'This version only allows https addresses.'**
  String get serverHttpsRequired;

  /// Spec key: server.wrongPath (12 §5.2) · Max: 90 · Notes: 12 · field error
  ///
  /// In en, this message translates to:
  /// **'The address must end in /api/v1.'**
  String get serverWrongPath;

  /// Spec key: signIn.title (12 §5.3) · Max: 32 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// Spec key: signIn.subtitle (12 §5.3) · Max: 48 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Use your staff account'**
  String get signInSubtitle;

  /// Spec key: signIn.email.label (12 §5.3) · Max: 20 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get signInEmailLabel;

  /// Spec key: signIn.email.placeholder (12 §5.3) · Max: 28 · Notes: 12 · example domains only
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get signInEmailPlaceholder;

  /// Spec key: signIn.password.label (12 §5.3) · Max: 20 · Notes: 03a · also used in the S15 session sheet
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get signInPasswordLabel;

  /// Spec key: signIn.password.show (12 §5.3) · Max: — · Notes: 03a · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get signInPasswordShow;

  /// Spec key: signIn.password.hide (12 §5.3) · Max: — · Notes: 03a · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get signInPasswordHide;

  /// Spec key: signIn.forgot (12 §5.3) · Max: 24 · Notes: 03a · harmonised (no "?" on buttons, §1.7)
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get signInForgot;

  /// Spec key: signIn.submit (12 §5.3) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInSubmit;

  /// Spec key: signIn.loading (12 §5.3) · Max: — · Notes: 03a · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Signing in'**
  String get signInLoading;

  /// Spec key: signIn.noAccess (12 §5.3) · Max: 90 · Notes: 12 · caption
  ///
  /// In en, this message translates to:
  /// **'No login? A manager creates it in the dashboard.'**
  String get signInNoAccess;

  /// Spec key: signIn.error.required (12 §5.3) · Max: 24 · Notes: 12 · inline
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get signInErrorRequired;

  /// Spec key: signIn.error.emailFormat (12 §5.3) · Max: 32 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Check the e-mail address'**
  String get signInErrorEmailFormat;

  /// Spec key: signIn.error.invalid (12 §5.3) · Max: 120 · Notes: 03a · ADR-002: one answer for wrong and locked (audit S4)
  ///
  /// In en, this message translates to:
  /// **'E-mail or password is incorrect. After too many attempts, sign-in is paused for a few minutes.'**
  String get signInErrorInvalid;

  /// Spec key: signIn.error.noPermission (12 §5.3) · Max: 90 · Notes: 03a · A02
  ///
  /// In en, this message translates to:
  /// **'This account can\'t redeem vouchers. Please get a manager.'**
  String get signInErrorNoPermission;

  /// Spec key: signIn.error.throttled (12 §5.3) · Max: 48 · Notes: 03a · A08
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {time}.'**
  String signInErrorThrottled(String time);

  /// Spec key: signIn.retryIn (12 §5.3) · Max: 24 · Notes: 03a · disabled sign-in button during the 429 wait (S02, S15 sheet)
  ///
  /// In en, this message translates to:
  /// **'Try again in {time}'**
  String signInRetryIn(String time);

  /// Spec key: signIn.available (12 §5.3) · Max: — · Notes: 03a · (a11y) end of the wait
  ///
  /// In en, this message translates to:
  /// **'You can sign in again'**
  String get signInAvailable;

  /// Spec key: signIn.error.server (12 §5.3) · Max: 90 · Notes: 03a · A09 · support code below
  ///
  /// In en, this message translates to:
  /// **'Can\'t sign in right now. Try again in a moment.'**
  String get signInErrorServer;

  /// Spec key: signIn.offline.body (12 §5.3) · Max: 48 · Notes: 03a · A09
  ///
  /// In en, this message translates to:
  /// **'Signing in needs a connection.'**
  String get signInOfflineBody;

  /// Spec key: biometrics.title.faceId (12 §5.4) · Max: 32 · Notes: 03a · question allowed (offer screen)
  ///
  /// In en, this message translates to:
  /// **'Unlock with Face ID?'**
  String get biometricsTitleFaceId;

  /// Spec key: biometrics.title.touchId (12 §5.4) · Max: 32 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Unlock with Touch ID?'**
  String get biometricsTitleTouchId;

  /// Spec key: biometrics.title.android (12 §5.4) · Max: 32 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics?'**
  String get biometricsTitleAndroid;

  /// Spec key: biometrics.body (12 §5.4) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'A faster start to every shift. Your password still works as a fallback.'**
  String get biometricsBody;

  /// Spec key: biometrics.enable.faceId (12 §5.4) · Max: 24 · Notes: 03a · B wording
  ///
  /// In en, this message translates to:
  /// **'Use Face ID'**
  String get biometricsEnableFaceId;

  /// Spec key: biometrics.enable.touchId (12 §5.4) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Use Touch ID'**
  String get biometricsEnableTouchId;

  /// Spec key: biometrics.enable.android (12 §5.4) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get biometricsEnableAndroid;

  /// Spec key: biometrics.notNow (12 §5.4) · Max: 24 · Notes: 03a · B wording
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get biometricsNotNow;

  /// Spec key: biometrics.reason (12 §5.4) · Max: 48 · Notes: 03a · iOS reason / Android prompt title
  ///
  /// In en, this message translates to:
  /// **'To unlock GiftCard Waiter'**
  String get biometricsReason;

  /// Spec key: biometrics.promptSubtitle.android (12 §5.4) · Max: 48 · Notes: 12 · BiometricPrompt subtitle
  ///
  /// In en, this message translates to:
  /// **'For service at {restaurant}'**
  String biometricsPromptSubtitleAndroid(String restaurant);

  /// Spec key: biometrics.failed (12 §5.4) · Max: 48 · Notes: 03a · P11
  ///
  /// In en, this message translates to:
  /// **'Not confirmed. Try again.'**
  String get biometricsFailed;

  /// Spec key: biometrics.notEnrolled.faceId (12 §5.4) · Max: 90 · Notes: 12 · P10 snackbar
  ///
  /// In en, this message translates to:
  /// **'Face ID is not set up. Set it up in Settings.'**
  String get biometricsNotEnrolledFaceId;

  /// Spec key: biometrics.notEnrolled.touchId (12 §5.4) · Max: 90 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'Touch ID is not set up. Set it up in Settings.'**
  String get biometricsNotEnrolledTouchId;

  /// Spec key: biometrics.notEnrolled.android (12 §5.4) · Max: 90 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'No biometrics set up. Set them up in Settings.'**
  String get biometricsNotEnrolledAndroid;

  /// Spec key: unlock.button.faceId (12 §5.5) · Max: 28 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Unlock with Face ID'**
  String get unlockButtonFaceId;

  /// Spec key: unlock.button.touchId (12 §5.5) · Max: 28 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Unlock with Touch ID'**
  String get unlockButtonTouchId;

  /// Spec key: unlock.button.android (12 §5.5) · Max: 28 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockButtonAndroid;

  /// Spec key: unlock.usePassword (12 §5.5) · Max: 24 · Notes: 03a · B wording
  ///
  /// In en, this message translates to:
  /// **'Use password'**
  String get unlockUsePassword;

  /// Spec key: unlock.changed (12 §5.5) · Max: 90 · Notes: 03a · P13
  ///
  /// In en, this message translates to:
  /// **'Biometrics changed on this device. Sign in with your password.'**
  String get unlockChanged;

  /// Spec key: unlock.lockedOut (12 §5.5) · Max: 48 · Notes: 12 · P12
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Use the password.'**
  String get unlockLockedOut;

  /// Spec key: topBar.recent (12 §5.6) · Max: — · Notes: 03a · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get topBarRecent;

  /// Spec key: topBar.menu (12 §5.6) · Max: — · Notes: 03a · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Menu, {name}'**
  String topBarMenu(String name);

  /// Spec key: ready.title (12 §5.6) · Max: 32 · Notes: ADR-002
  ///
  /// In en, this message translates to:
  /// **'Scan the voucher'**
  String get readyTitle;

  /// Spec key: ready.hint (12 §5.6) · Max: 90 · Notes: ADR-002
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the voucher\'s QR code – printed or on the guest\'s phone.'**
  String get readyHint;

  /// Spec key: ready.scan (12 §5.6) · Max: 24 · Notes: ADR-002 · primary
  ///
  /// In en, this message translates to:
  /// **'Scan voucher'**
  String get readyScan;

  /// Spec key: ready.tapCard (12 §5.6) · Max: 24 · Notes: Phase 4 · secondary, only with NFC
  ///
  /// In en, this message translates to:
  /// **'Tap card'**
  String get readyTapCard;

  /// Spec key: ready.sell (12 §5.6) · Max: 24 · Notes: ADR-002 · opens S20; only with vouchers.sell
  ///
  /// In en, this message translates to:
  /// **'Sell voucher'**
  String get readySell;

  /// Spec key: ready.pending.title (12 §5.6) · Max: 32 · Notes: ADR-002 · banner while an attempt is unresolved (audit M1, M2, M6)
  ///
  /// In en, this message translates to:
  /// **'Redemption not confirmed yet'**
  String get readyPendingTitle;

  /// Spec key: ready.pending.body (12 §5.6) · Max: 90 · Notes: ADR-002
  ///
  /// In en, this message translates to:
  /// **'{amount} on voucher •••• {last4}. Checked automatically – nothing is ever booked twice.'**
  String readyPendingBody(String amount, String last4);

  /// Spec key: ready.pending.booked (12 §5.6) · Max: 60 · Notes: ADR-002 · snackbar; the row appears in Recent
  ///
  /// In en, this message translates to:
  /// **'The unconfirmed redemption of {amount} was booked.'**
  String readyPendingBooked(String amount);

  /// Spec key: ready.pending.notBooked (12 §5.6) · Max: 60 · Notes: ADR-002 · snackbar
  ///
  /// In en, this message translates to:
  /// **'The unconfirmed redemption of {amount} was not booked.'**
  String readyPendingNotBooked(String amount);

  /// Spec key: ready.online (12 §5.6) · Max: 32 · Notes: 03a · snackbar / announcement
  ///
  /// In en, this message translates to:
  /// **'Connected again'**
  String get readyOnline;

  /// Spec key: offline.title (12 §5.6) · Max: 28 · Notes: B · also S10 network title
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get offlineTitle;

  /// Spec key: offline.body (12 §5.6) · Max: 90 · Notes: B
  ///
  /// In en, this message translates to:
  /// **'Redeeming needs a connection so nothing is ever booked twice.'**
  String get offlineBody;

  /// Spec key: maintenance.default (12 §5.6) · Max: 90 · Notes: 03a · A12 fallback when the server text is missing
  ///
  /// In en, this message translates to:
  /// **'Scheduled maintenance: redeeming may be briefly unavailable.'**
  String get maintenanceDefault;

  /// Spec key: maintenance.dismiss (12 §5.6) · Max: — · Notes: 03a · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Dismiss notice'**
  String get maintenanceDismiss;

  /// Spec key: scan.detected (12 §5.7) · Max: — · Notes: 03a · (a11y) announcement
  ///
  /// In en, this message translates to:
  /// **'Voucher detected'**
  String get scanDetected;

  /// Spec key: scan.lookingUp (12 §5.7) · Max: 32 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Checking voucher …'**
  String get scanLookingUp;

  /// Spec key: scan.slow (12 §5.7) · Max: 32 · Notes: 03a · L08 · alias lookup.stillLooking (03b)
  ///
  /// In en, this message translates to:
  /// **'Still checking …'**
  String get scanSlow;

  /// Spec key: card.title (12 §5.7) · Max: 24 · Notes: Phase 4 · S11 title
  ///
  /// In en, this message translates to:
  /// **'Tap card'**
  String get cardTitle;

  /// Spec key: card.waiting (12 §5.7) · Max: 64 · Notes: Phase 4 · S11 and the iPhone sheet
  ///
  /// In en, this message translates to:
  /// **'Hold the guest\'s card to the top of the phone.'**
  String get cardWaiting;

  /// Spec key: card.checking (12 §5.7) · Max: 32 · Notes: Phase 4 · card on the phone, server challenge
  ///
  /// In en, this message translates to:
  /// **'Checking the card …'**
  String get cardChecking;

  /// Spec key: card.slow (12 §5.7) · Max: 48 · Notes: Phase 4 · after 3 s
  ///
  /// In en, this message translates to:
  /// **'Still checking – keep the card on the phone.'**
  String get cardSlow;

  /// Spec key: card.done (12 §5.7) · Max: 24 · Notes: Phase 4 · iPhone sheet, success
  ///
  /// In en, this message translates to:
  /// **'Card checked'**
  String get cardDone;

  /// Spec key: card.failed (12 §5.7) · Max: 48 · Notes: Phase 4 · iPhone sheet, failure
  ///
  /// In en, this message translates to:
  /// **'The card could not be checked.'**
  String get cardFailed;

  /// Spec key: balanceCard.overline (12 §5.8) · Max: 16 · Notes: 12 · uppercased by style · ADR-002
  ///
  /// In en, this message translates to:
  /// **'Voucher'**
  String get balanceCardOverline;

  /// Spec key: balanceCard.validUntil (12 §5.8) · Max: 24 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String balanceCardValidUntil(String date);

  /// Spec key: balanceCard.noExpiry (12 §5.8) · Max: 24 · Notes: 12 · expires_at null
  ///
  /// In en, this message translates to:
  /// **'No expiry date'**
  String get balanceCardNoExpiry;

  /// Spec key: balanceCard.masked (12 §5.8) · Max: 9 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'•••• {last4}'**
  String balanceCardMasked(String last4);

  /// Spec key: balanceCard.a11y (12 §5.8) · Max: — · Notes: 12 · (a11y) · validity and status appended
  ///
  /// In en, this message translates to:
  /// **'Voucher {restaurant}. Balance {spokenAmount}. Voucher ending {last4}.'**
  String balanceCardA11y(String restaurant, String spokenAmount, String last4);

  /// Spec key: charge.voucherNumber.a11y (12 §5.8) · Max: — · Notes: 12 · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Voucher number {number}'**
  String chargeVoucherNumberA11y(String number);

  /// Spec key: a11y.charge.close (12 §5.8) · Max: — · Notes: 03b · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Close voucher'**
  String get a11yChargeClose;

  /// Spec key: a11y.amount (12 §5.8) · Max: — · Notes: 03b · (a11y) AmountDisplay
  ///
  /// In en, this message translates to:
  /// **'Amount {spokenAmount}'**
  String a11yAmount(String spokenAmount);

  /// Spec key: charge.enterAmount (12 §5.8) · Max: 24 · Notes: 03b · disabled button at € 0,00
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get chargeEnterAmount;

  /// Spec key: charge.redeem (12 §5.8) · Max: 26+amt · Notes: B (§4.2 clarification)
  ///
  /// In en, this message translates to:
  /// **'Redeem {amount}'**
  String chargeRedeem(String amount);

  /// Spec key: charge.redeemFull (12 §5.8) · Max: 26+amt · Notes: B · breaks at " · "
  ///
  /// In en, this message translates to:
  /// **'Redeem full balance · {amount}'**
  String chargeRedeemFull(String amount);

  /// Spec key: charge.hold (12 §5.8) · Max: 26 · Notes: B · HoldButton hint ≥ holdToConfirmThresholdCents
  ///
  /// In en, this message translates to:
  /// **'Hold to redeem'**
  String get chargeHold;

  /// Spec key: a11y.hold.hint (12 §5.8) · Max: — · Notes: 03b · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Double-tap and hold to redeem'**
  String get a11yHoldHint;

  /// Spec key: charge.redeeming (12 §5.8) · Max: 26+amt · Notes: 03b · S08 button label
  ///
  /// In en, this message translates to:
  /// **'Redeeming {amount} …'**
  String chargeRedeeming(String amount);

  /// Spec key: charge.overBalance (12 §5.8) · Max: 40 · Notes: B
  ///
  /// In en, this message translates to:
  /// **'{diff} more than the balance'**
  String chargeOverBalance(String diff);

  /// Spec key: a11y.overBalance (12 §5.8) · Max: — · Notes: 03b · (a11y)
  ///
  /// In en, this message translates to:
  /// **'{diff} more than the balance. Redeem not available.'**
  String a11yOverBalance(String diff);

  /// Spec key: charge.useBalance (12 §5.8) · Max: 20+amt · Notes: B · QuickAmountChip
  ///
  /// In en, this message translates to:
  /// **'Use balance · {amount}'**
  String chargeUseBalance(String amount);

  /// Spec key: charge.useMax (12 §5.8) · Max: 20+amt · Notes: 03b · R10
  ///
  /// In en, this message translates to:
  /// **'Use maximum · {amount}'**
  String chargeUseMax(String amount);

  /// Spec key: charge.maxSingle (12 §5.8) · Max: 40 · Notes: 03b · R10
  ///
  /// In en, this message translates to:
  /// **'Max. {amount} per redemption'**
  String chargeMaxSingle(String amount);

  /// Spec key: charge.fullOnly (12 §5.8) · Max: 90 · Notes: 03b · partial disabled, R11
  ///
  /// In en, this message translates to:
  /// **'Only the full balance can be redeemed here.'**
  String get chargeFullOnly;

  /// Spec key: charge.velocity.title (12 §5.8) · Max: 32 · Notes: 03b · R14
  ///
  /// In en, this message translates to:
  /// **'Limit for this voucher reached'**
  String get chargeVelocityTitle;

  /// Spec key: charge.velocity.bodyTime (12 §5.8) · Max: 90 · Notes: 03b · harmonised ("min" without period)
  ///
  /// In en, this message translates to:
  /// **'Possible again in {minutes} min. Or get a manager.'**
  String chargeVelocityBodyTime(int minutes);

  /// Spec key: charge.rateLimited (12 §5.8) · Max: 60 · Notes: 03b · R15 · harmonised (EN en dash)
  ///
  /// In en, this message translates to:
  /// **'Too many requests – possible again in {seconds} s'**
  String chargeRateLimited(int seconds);

  /// Spec key: charge.dailyLimit (12 §5.8) · Max: 60 · Notes: ADR-002 · per-day limit of the restaurant
  ///
  /// In en, this message translates to:
  /// **'At most {amount} more with this voucher today'**
  String chargeDailyLimit(String amount);

  /// Spec key: charge.presentment.expired (12 §5.8) · Max: 60 · Notes: ADR-002 · the 60-s proof ran out; the amount is kept
  ///
  /// In en, this message translates to:
  /// **'Scan the voucher again to redeem.'**
  String get chargePresentmentExpired;

  /// Spec key: charge.pending.title (12 §5.8) · Max: 36 · Notes: ADR-002 · an unresolved attempt on this voucher
  ///
  /// In en, this message translates to:
  /// **'Checking an earlier redemption'**
  String get chargePendingTitle;

  /// Spec key: charge.pending.body (12 §5.8) · Max: 90 · Notes: ADR-002
  ///
  /// In en, this message translates to:
  /// **'{amount} may already have been redeemed. Redeeming is possible once this is checked.'**
  String chargePendingBody(String amount);

  /// Spec key: charge.earlierBooked (12 §5.8) · Max: 90 · Notes: ADR-002
  ///
  /// In en, this message translates to:
  /// **'The earlier redemption of {amount} was booked. Balance updated.'**
  String chargeEarlierBooked(String amount);

  /// Spec key: keypad.doubleZero (12 §5.8) · Max: — · Notes: 03a · (a11y) · alias a11y.keypad.doubleZero (03b)
  ///
  /// In en, this message translates to:
  /// **'Double zero'**
  String get keypadDoubleZero;

  /// Spec key: keypad.delete (12 §5.8) · Max: — · Notes: 03a · (a11y) · alias a11y.keypad.delete (03b)
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get keypadDelete;

  /// Spec key: keypad.delete.hint (12 §5.8) · Max: — · Notes: 03a · (a11y) · alias a11y.keypad.deleteHint (03b)
  ///
  /// In en, this message translates to:
  /// **'Long press to clear'**
  String get keypadDeleteHint;

  /// Spec key: keypad.cleared (12 §5.8) · Max: — · Notes: 12 · (a11y) announcement
  ///
  /// In en, this message translates to:
  /// **'Amount cleared'**
  String get keypadCleared;

  /// Spec key: keypad.maxReached (12 §5.8) · Max: — · Notes: 12 · (a11y) · 7 digits
  ///
  /// In en, this message translates to:
  /// **'Maximum amount reached'**
  String get keypadMaxReached;

  /// Spec key: badge.active (12 §5.9) · Max: 16 · Notes: 12 · a11y only (active cards show no badge)
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get badgeActive;

  /// Spec key: badge.usedUp (12 §5.9) · Max: 16 · Notes: 12 · status redeemed or balance 0
  ///
  /// In en, this message translates to:
  /// **'Used up'**
  String get badgeUsedUp;

  /// Spec key: badge.blocked (12 §5.9) · Max: 16 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get badgeBlocked;

  /// Spec key: badge.expired (12 §5.9) · Max: 16 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get badgeExpired;

  /// Spec key: voucher.blocked (12 §5.9) · Max: 28 · Notes: B · danger · body = getManager
  ///
  /// In en, this message translates to:
  /// **'Voucher blocked'**
  String get voucherBlocked;

  /// Spec key: voucher.blocked.reason (12 §5.9) · Max: 90 · Notes: 03b · only if blocked_reason present
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String voucherBlockedReason(String reason);

  /// Spec key: voucher.expired (12 §5.9) · Max: 28 · Notes: B · warning
  ///
  /// In en, this message translates to:
  /// **'Voucher expired'**
  String get voucherExpired;

  /// Spec key: voucher.expired.body (12 §5.9) · Max: 90 · Notes: 03b · harmonised (escalation wording §2.6)
  ///
  /// In en, this message translates to:
  /// **'Expired on {date}. Please get a manager.'**
  String voucherExpiredBody(String date);

  /// Spec key: voucher.empty (12 §5.9) · Max: 28 · Notes: B · warning
  ///
  /// In en, this message translates to:
  /// **'No balance left'**
  String get voucherEmpty;

  /// Spec key: voucher.empty.body (12 §5.9) · Max: 90 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'This voucher has been fully used.'**
  String get voucherEmptyBody;

  /// Spec key: redeem.slow (12 §5.10) · Max: 36 · Notes: 03b · R02 · harmonised (EN en dash)
  ///
  /// In en, this message translates to:
  /// **'Connection slow – retrying'**
  String get redeemSlow;

  /// Spec key: uncertain.title (12 §5.10) · Max: 28 · Notes: B · R03/R04
  ///
  /// In en, this message translates to:
  /// **'Connection interrupted'**
  String get uncertainTitle;

  /// Spec key: uncertain.body (12 §5.10) · Max: 90 · Notes: B · also the helper in R02
  ///
  /// In en, this message translates to:
  /// **'Checking … Nothing is ever booked twice.'**
  String get uncertainBody;

  /// Spec key: uncertain.retrying (12 §5.10) · Max: 20 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'Attempt {n} of 3'**
  String uncertainRetrying(int n);

  /// Spec key: uncertain.guestHint (12 §5.10) · Max: 90 · Notes: 03b · harmonised (never "Zahlung / payment / plaćanje", §1.3)
  ///
  /// In en, this message translates to:
  /// **'Tell the guest: \"One moment please, the redemption is being confirmed.\"'**
  String get uncertainGuestHint;

  /// Spec key: uncertain.failedBody (12 §5.10) · Max: 90 · Notes: 03b · R04 · ADR-002: "Check again" resends the same key
  ///
  /// In en, this message translates to:
  /// **'Not confirmed yet. Check again – nothing is ever booked twice.'**
  String get uncertainFailedBody;

  /// Spec key: uncertain.cancelled (12 §5.10) · Max: 120 · Notes: 03b · R05 · ADR-002 · snackbar on S05 after Cancel
  ///
  /// In en, this message translates to:
  /// **'Not confirmed. It is checked automatically before this voucher can be redeemed again.'**
  String get uncertainCancelled;

  /// Spec key: uncertain.cancelledGuestHint (12 §5.10) · Max: 120 · Notes: 03b · harmonised (vocabulary); 3 lines allowed (quoted speech)
  ///
  /// In en, this message translates to:
  /// **'Tell the guest: \"The redemption isn\'t confirmed yet. We\'ll check it before redeeming again.\"'**
  String get uncertainCancelledGuestHint;

  /// Spec key: redeem.balanceChanged (12 §5.10) · Max: 48 · Notes: 03b · R06
  ///
  /// In en, this message translates to:
  /// **'Balance changed: now {amount}'**
  String redeemBalanceChanged(String amount);

  /// Spec key: success.title (12 §5.11) · Max: 20 · Notes: B
  ///
  /// In en, this message translates to:
  /// **'Redeemed'**
  String get successTitle;

  /// Spec key: success.remaining (12 §5.11) · Max: 36 · Notes: B
  ///
  /// In en, this message translates to:
  /// **'Remaining balance {amount}'**
  String successRemaining(String amount);

  /// Spec key: success.empty (12 §5.11) · Max: 28 · Notes: 03b · replaces the remaining line at 0
  ///
  /// In en, this message translates to:
  /// **'Voucher is now empty'**
  String get successEmpty;

  /// Spec key: success.next (12 §5.11) · Max: 24 · Notes: B · ADR-002 wording
  ///
  /// In en, this message translates to:
  /// **'Scan next voucher'**
  String get successNext;

  /// Spec key: success.showGuest (12 §5.11) · Max: 24 · Notes: 03b · presentation mode
  ///
  /// In en, this message translates to:
  /// **'Show guest'**
  String get successShowGuest;

  /// Spec key: success.card (12 §5.11) · Max: 20 · Notes: 12 · caption
  ///
  /// In en, this message translates to:
  /// **'Voucher •••• {last4}'**
  String successCard(String last4);

  /// Spec key: guest.remaining.label (12 §5.11) · Max: 20 · Notes: 03b · Show-guest mode
  ///
  /// In en, this message translates to:
  /// **'Remaining balance'**
  String get guestRemainingLabel;

  /// Spec key: a11y.success (12 §5.11) · Max: — · Notes: 03b · (a11y) assertive; amounts in spoken form
  ///
  /// In en, this message translates to:
  /// **'Redeemed {amount}, remaining balance {balance}'**
  String a11ySuccess(String amount, String balance);

  /// Spec key: problem.notRecognized.title (12 §5.12) · Max: 32 · Notes: ADR-002 · unknown, revoked or foreign code
  ///
  /// In en, this message translates to:
  /// **'Not a voucher of this restaurant'**
  String get problemNotRecognizedTitle;

  /// Spec key: problem.notRecognized.body (12 §5.12) · Max: 90 · Notes: ADR-002
  ///
  /// In en, this message translates to:
  /// **'This code is not valid here. Ask the guest for another voucher or get a manager.'**
  String get problemNotRecognizedBody;

  /// Spec key: problem.cardNotRecognized.title (12 §5.12) · Max: 32 · Notes: Phase 4 · not a card of this restaurant, copied or unverifiable
  ///
  /// In en, this message translates to:
  /// **'Card not accepted'**
  String get problemCardNotRecognizedTitle;

  /// Spec key: problem.cardNotRecognized.body (12 §5.12) · Max: 90 · Notes: Phase 4
  ///
  /// In en, this message translates to:
  /// **'This card could not be confirmed as a voucher of this restaurant. Get a manager.'**
  String get problemCardNotRecognizedBody;

  /// Spec key: problem.cardNotUsable.title (12 §5.12) · Max: 32 · Notes: Phase 4 · CARD_NOT_USABLE
  ///
  /// In en, this message translates to:
  /// **'This card cannot pay'**
  String get problemCardNotUsableTitle;

  /// Spec key: problem.cardNotUsable.notActive (12 §5.12) · Max: 90 · Notes: Phase 4 · available, bound
  ///
  /// In en, this message translates to:
  /// **'The card is not activated yet.'**
  String get problemCardNotUsableNotActive;

  /// Spec key: problem.cardNotUsable.suspended (12 §5.12) · Max: 90 · Notes: Phase 4 · suspended
  ///
  /// In en, this message translates to:
  /// **'The card is temporarily blocked. A manager can help.'**
  String get problemCardNotUsableSuspended;

  /// Spec key: problem.cardNotUsable.invalid (12 §5.12) · Max: 90 · Notes: Phase 4 · replaced, revoked, lost, not bound
  ///
  /// In en, this message translates to:
  /// **'The card is no longer valid. A manager can help.'**
  String get problemCardNotUsableInvalid;

  /// Spec key: problem.cardNotUsable.otherRestaurant (12 §5.12) · Max: 90 · Notes: Phase 4
  ///
  /// In en, this message translates to:
  /// **'This card belongs to another restaurant.'**
  String get problemCardNotUsableOtherRestaurant;

  /// Spec key: problem.cardMoved.title (12 §5.12) · Max: 32 · Notes: Phase 4 · tag lost
  ///
  /// In en, this message translates to:
  /// **'Card moved away'**
  String get problemCardMovedTitle;

  /// Spec key: problem.cardMoved.body (12 §5.12) · Max: 90 · Notes: Phase 4
  ///
  /// In en, this message translates to:
  /// **'Hold the card still on the phone until it is checked.'**
  String get problemCardMovedBody;

  /// Spec key: problem.nfcOff.title (12 §5.12) · Max: 32 · Notes: Phase 4 · Android
  ///
  /// In en, this message translates to:
  /// **'NFC is off'**
  String get problemNfcOffTitle;

  /// Spec key: problem.nfcOff.body (12 §5.12) · Max: 90 · Notes: Phase 4
  ///
  /// In en, this message translates to:
  /// **'Switch on NFC in the phone\'s settings to read cards.'**
  String get problemNfcOffBody;

  /// Spec key: problem.nfcUnsupported.title (12 §5.12) · Max: 32 · Notes: Phase 4
  ///
  /// In en, this message translates to:
  /// **'This phone cannot read cards'**
  String get problemNfcUnsupportedTitle;

  /// Spec key: problem.nfcUnsupported.body (12 §5.12) · Max: 90 · Notes: Phase 4
  ///
  /// In en, this message translates to:
  /// **'Scan QR vouchers, or use a phone with NFC for cards.'**
  String get problemNfcUnsupportedBody;

  /// Spec key: problem.throttled.title (12 §5.12) · Max: 32 · Notes: 03b · L05
  ///
  /// In en, this message translates to:
  /// **'Too many scans'**
  String get problemThrottledTitle;

  /// Spec key: problem.throttled.body (12 §5.12) · Max: 90 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'Scanning is possible again shortly.'**
  String get problemThrottledBody;

  /// Spec key: problem.scanAgainIn (12 §5.12) · Max: 24 · Notes: 03b · disabled countdown button
  ///
  /// In en, this message translates to:
  /// **'Scan again · {time}'**
  String problemScanAgainIn(String time);

  /// Spec key: problem.network.body (12 §5.12) · Max: 90 · Notes: 03b · L06 (title = offline.title)
  ///
  /// In en, this message translates to:
  /// **'The voucher could not be checked. Check Wi-Fi or mobile data, then try again.'**
  String get problemNetworkBody;

  /// Spec key: problem.server.title (12 §5.12) · Max: 32 · Notes: 03b · harmonised (title states what happened, §2.1)
  ///
  /// In en, this message translates to:
  /// **'Service not available right now'**
  String get problemServerTitle;

  /// Spec key: problem.server.body (12 §5.12) · Max: 90 · Notes: 03b · harmonised (no "wir/uns" in the UI, §1.2)
  ///
  /// In en, this message translates to:
  /// **'The problem is not the voucher. Try again in a moment.'**
  String get problemServerBody;

  /// Spec key: sale.title (12 §5.13) · Max: 24 · Notes: ADR-002 · screen title
  ///
  /// In en, this message translates to:
  /// **'Sell voucher'**
  String get saleTitle;

  /// Spec key: sale.amount.label (12 §5.13) · Max: 24 · Notes: ADR-002 · above the amount
  ///
  /// In en, this message translates to:
  /// **'Voucher value'**
  String get saleAmountLabel;

  /// Spec key: sale.amount.range (12 §5.13) · Max: 60 · Notes: ADR-002 · restaurant limits / INVALID_AMOUNT
  ///
  /// In en, this message translates to:
  /// **'The value must be between {min} and {max}.'**
  String saleAmountRange(String min, String max);

  /// Spec key: sale.continue (12 §5.13) · Max: 24+amt · Notes: ADR-002 · amount step → payment step
  ///
  /// In en, this message translates to:
  /// **'Continue · {amount}'**
  String saleContinue(String amount);

  /// Spec key: sale.payment.label (12 §5.13) · Max: 24 · Notes: ADR-002 · the guest pays for the voucher (§1.3 "payment" rule is about redeeming)
  ///
  /// In en, this message translates to:
  /// **'Paid with'**
  String get salePaymentLabel;

  /// Spec key: sale.payment.cash (12 §5.13) · Max: 16 · Notes: ADR-002 · choice
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get salePaymentCash;

  /// Spec key: sale.payment.cardTerminal (12 §5.13) · Max: 16 · Notes: ADR-002 · choice
  ///
  /// In en, this message translates to:
  /// **'Card terminal'**
  String get salePaymentCardTerminal;

  /// Spec key: sale.payment.bankTransfer (12 §5.13) · Max: 16 · Notes: ADR-002 · choice
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get salePaymentBankTransfer;

  /// Spec key: sale.payment.complimentary (12 §5.13) · Max: 16 · Notes: ADR-002 · choice · only with vouchers.sell_complimentary
  ///
  /// In en, this message translates to:
  /// **'Complimentary'**
  String get salePaymentComplimentary;

  /// Spec key: sale.reference.label (12 §5.13) · Max: 32 · Notes: ADR-002 · card terminal / bank transfer
  ///
  /// In en, this message translates to:
  /// **'Receipt or reference number'**
  String get saleReferenceLabel;

  /// Spec key: sale.reference.required (12 §5.13) · Max: 60 · Notes: ADR-002 · field error
  ///
  /// In en, this message translates to:
  /// **'Enter the receipt or reference number.'**
  String get saleReferenceRequired;

  /// Spec key: sale.reason.label (12 §5.13) · Max: 24 · Notes: ADR-002 · complimentary
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get saleReasonLabel;

  /// Spec key: sale.reason.required (12 §5.13) · Max: 60 · Notes: ADR-002 · field error
  ///
  /// In en, this message translates to:
  /// **'Enter a reason (at least 3 characters).'**
  String get saleReasonRequired;

  /// Spec key: sale.email.label (12 §5.13) · Max: 32 · Notes: ADR-002
  ///
  /// In en, this message translates to:
  /// **'Guest e-mail (optional)'**
  String get saleEmailLabel;

  /// Spec key: sale.email.helper (12 §5.13) · Max: 60 · Notes: ADR-002 · when the restaurant sends guest e-mails
  ///
  /// In en, this message translates to:
  /// **'The guest receives a confirmation.'**
  String get saleEmailHelper;

  /// Spec key: sale.email.helperNoMail (12 §5.13) · Max: 60 · Notes: ADR-002 · when it does not
  ///
  /// In en, this message translates to:
  /// **'Saved with the voucher.'**
  String get saleEmailHelperNoMail;

  /// Spec key: sale.email.invalid (12 §5.13) · Max: 60 · Notes: ADR-002 · field error
  ///
  /// In en, this message translates to:
  /// **'Enter a valid e-mail address.'**
  String get saleEmailInvalid;

  /// Spec key: sale.submit (12 §5.13) · Max: 24+amt · Notes: ADR-002 · primary
  ///
  /// In en, this message translates to:
  /// **'Sell voucher · {amount}'**
  String saleSubmit(String amount);

  /// Spec key: sale.submitting (12 §5.13) · Max: 32 · Notes: ADR-002 · button progress
  ///
  /// In en, this message translates to:
  /// **'Selling voucher …'**
  String get saleSubmitting;

  /// Spec key: sale.failed.title (12 §5.13) · Max: 28 · Notes: ADR-002 · definitive answer
  ///
  /// In en, this message translates to:
  /// **'Voucher not sold'**
  String get saleFailedTitle;

  /// Spec key: sale.failed.body (12 §5.13) · Max: 90 · Notes: ADR-002
  ///
  /// In en, this message translates to:
  /// **'No voucher was sold. Check the connection and try again.'**
  String get saleFailedBody;

  /// Spec key: sale.uncertain.title (12 §5.13) · Max: 28 · Notes: ADR-002 · no answer
  ///
  /// In en, this message translates to:
  /// **'Sale not confirmed'**
  String get saleUncertainTitle;

  /// Spec key: sale.uncertain.body (12 §5.13) · Max: 90 · Notes: ADR-002 · same idempotency key
  ///
  /// In en, this message translates to:
  /// **'The answer did not arrive. Try again – the voucher will not be sold twice.'**
  String get saleUncertainBody;

  /// Spec key: sale.notAllowed.title (12 §5.13) · Max: 28 · Notes: ADR-002 · 403
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get saleNotAllowedTitle;

  /// Spec key: sale.notAllowed.body (12 §5.13) · Max: 90 · Notes: ADR-002 · 403
  ///
  /// In en, this message translates to:
  /// **'This account cannot sell vouchers on this phone. Please get a manager.'**
  String get saleNotAllowedBody;

  /// Spec key: sale.done.title (12 §5.13) · Max: 28 · Notes: ADR-002
  ///
  /// In en, this message translates to:
  /// **'Voucher sold'**
  String get saleDoneTitle;

  /// Spec key: sale.done.value (12 §5.13) · Max: 32 · Notes: ADR-002
  ///
  /// In en, this message translates to:
  /// **'Value {amount}'**
  String saleDoneValue(String amount);

  /// Spec key: sale.done.body (12 §5.13) · Max: 90 · Notes: ADR-002 · the QR is returned once
  ///
  /// In en, this message translates to:
  /// **'Print the QR code for the guest. It is shown only now.'**
  String get saleDoneBody;

  /// Spec key: sale.print (12 §5.13) · Max: 24 · Notes: ADR-002 · primary · system print dialog
  ///
  /// In en, this message translates to:
  /// **'Print voucher'**
  String get salePrint;

  /// Spec key: sale.printed (12 §5.13) · Max: 32 · Notes: ADR-002 · after the print dialog finished
  ///
  /// In en, this message translates to:
  /// **'Sent to the printer'**
  String get salePrinted;

  /// Spec key: sale.printFailed (12 §5.13) · Max: 60 · Notes: ADR-002
  ///
  /// In en, this message translates to:
  /// **'Printing did not work. Try again.'**
  String get salePrintFailed;

  /// Spec key: sale.another (12 §5.13) · Max: 28 · Notes: ADR-002 · secondary
  ///
  /// In en, this message translates to:
  /// **'Sell another voucher'**
  String get saleAnother;

  /// Spec key: sale.leave.title (12 §5.13) · Max: 28 · Notes: ADR-002 · Dialog
  ///
  /// In en, this message translates to:
  /// **'Close without printing?'**
  String get saleLeaveTitle;

  /// Spec key: sale.leave.body (12 §5.13) · Max: 120 · Notes: ADR-002 · Dialog
  ///
  /// In en, this message translates to:
  /// **'The QR code cannot be shown again. Without it the guest cannot redeem the voucher.'**
  String get saleLeaveBody;

  /// Spec key: sale.leave.confirm (12 §5.13) · Max: 24 · Notes: ADR-002 · DangerButton (cancel = common.cancel)
  ///
  /// In en, this message translates to:
  /// **'Close anyway'**
  String get saleLeaveConfirm;

  /// Spec key: sale.leaveUncertain.title (12 §5.13) · Max: 36 · Notes: ADR-002 · Dialog · the last request got no answer
  ///
  /// In en, this message translates to:
  /// **'Sale open – close anyway?'**
  String get saleLeaveUncertainTitle;

  /// Spec key: sale.leaveUncertain.body (12 §5.13) · Max: 120 · Notes: ADR-002 · Dialog (confirm = sale.leave.confirm, cancel = common.cancel)
  ///
  /// In en, this message translates to:
  /// **'The voucher may already have been sold. Only “Try again” finds out without selling it twice.'**
  String get saleLeaveUncertainBody;

  /// Spec key: sale.noQr.title (12 §5.13) · Max: 28 · Notes: ADR-002 · retry answered with the earlier sale, QR no longer available
  ///
  /// In en, this message translates to:
  /// **'Voucher already sold'**
  String get saleNoQrTitle;

  /// Spec key: sale.noQr.body (12 §5.13) · Max: 140 · Notes: ADR-002 · same advice as the dashboard
  ///
  /// In en, this message translates to:
  /// **'Its QR code can no longer be shown. If the guest has no printed voucher, block it in the dashboard and sell a new one.'**
  String get saleNoQrBody;

  /// Spec key: sale.qr.a11y (12 §5.13) · Max: — · Notes: ADR-002 · (a11y)
  ///
  /// In en, this message translates to:
  /// **'QR code of the voucher'**
  String get saleQrA11y;

  /// Spec key: sale.form.title (12 §5.13) · Max: 28 · Notes: Cards · first step when the phone reads cards
  ///
  /// In en, this message translates to:
  /// **'What are you selling?'**
  String get saleFormTitle;

  /// Spec key: sale.form.printable (12 §5.13) · Max: 28 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Printed voucher'**
  String get saleFormPrintable;

  /// Spec key: sale.form.printable.caption (12 §5.13) · Max: 48 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'With a QR code to print'**
  String get saleFormPrintableCaption;

  /// Spec key: sale.form.card (12 §5.13) · Max: 28 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Gift card'**
  String get saleFormCard;

  /// Spec key: sale.form.card.caption (12 §5.13) · Max: 60 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'A card from stock, activated at the sale'**
  String get saleFormCardCaption;

  /// Spec key: sale.card.submit (12 §5.13) · Max: 32 · Notes: Cards · PrimaryButton of a card sale
  ///
  /// In en, this message translates to:
  /// **'Tap card · {amount}'**
  String saleCardSubmit(String amount);

  /// Spec key: sale.card.tap (12 §5.13) · Max: 64 · Notes: Cards · also the iPhone sheet
  ///
  /// In en, this message translates to:
  /// **'Hold the card to the phone to activate it.'**
  String get saleCardTap;

  /// Spec key: sale.card.done.title (12 §5.13) · Max: 28 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Card activated'**
  String get saleCardDoneTitle;

  /// Spec key: sale.card.done.body (12 §5.13) · Max: 48 · Notes: Cards · inventory number
  ///
  /// In en, this message translates to:
  /// **'Card {number} is active.'**
  String saleCardDoneBody(String number);

  /// Spec key: sale.card.failed.title (12 §5.13) · Max: 32 · Notes: Cards · nothing was sold
  ///
  /// In en, this message translates to:
  /// **'Card not activated'**
  String get saleCardFailedTitle;

  /// Spec key: sale.card.notUsable (12 §5.13) · Max: 90 · Notes: Cards · not in stock, other restaurant
  ///
  /// In en, this message translates to:
  /// **'This card cannot be sold. Take another card from stock.'**
  String get saleCardNotUsable;

  /// Spec key: reload.ready (12 §5.13) · Max: 24 · Notes: Reload · S05 button; only with vouchers.reload and a card reader
  ///
  /// In en, this message translates to:
  /// **'Top up card'**
  String get reloadReady;

  /// Spec key: reload.title (12 §5.13) · Max: 28 · Notes: Reload · TopBar
  ///
  /// In en, this message translates to:
  /// **'Top up card'**
  String get reloadTitle;

  /// Spec key: reload.tap (12 §5.13) · Max: 64 · Notes: Reload · step 1, also the iPhone sheet
  ///
  /// In en, this message translates to:
  /// **'Hold the guest\'s card to the phone.'**
  String get reloadTap;

  /// Spec key: reload.tapAgain (12 §5.13) · Max: 64 · Notes: Reload · the first tap is older than its 60 s validity
  ///
  /// In en, this message translates to:
  /// **'Hold the card to the phone again to confirm.'**
  String get reloadTapAgain;

  /// Spec key: reload.amount.label (12 §5.13) · Max: 24 · Notes: Reload · above the amount
  ///
  /// In en, this message translates to:
  /// **'Top-up amount'**
  String get reloadAmountLabel;

  /// Spec key: reload.amount.max (12 §5.13) · Max: 60 · Notes: Reload · BALANCE_LIMIT_EXCEEDED
  ///
  /// In en, this message translates to:
  /// **'At most {max}, or the balance limit is exceeded.'**
  String reloadAmountMax(String max);

  /// Spec key: reload.submit (12 §5.13) · Max: 32 · Notes: Reload · PrimaryButton
  ///
  /// In en, this message translates to:
  /// **'Top up {amount}'**
  String reloadSubmit(String amount);

  /// Spec key: reload.submitting (12 §5.13) · Max: 32 · Notes: Reload · loading label
  ///
  /// In en, this message translates to:
  /// **'Topping up …'**
  String get reloadSubmitting;

  /// Spec key: reload.done.title (12 §5.13) · Max: 28 · Notes: Reload · also the iPhone sheet after the tap
  ///
  /// In en, this message translates to:
  /// **'Card topped up'**
  String get reloadDoneTitle;

  /// Spec key: reload.done.body (12 §5.13) · Max: 48 · Notes: Reload
  ///
  /// In en, this message translates to:
  /// **'+{amount} · new balance {balance}'**
  String reloadDoneBody(String amount, String balance);

  /// Spec key: reload.another (12 §5.13) · Max: 32 · Notes: Reload · TertiaryButton
  ///
  /// In en, this message translates to:
  /// **'Top up another card'**
  String get reloadAnother;

  /// Spec key: reload.failed.title (12 §5.13) · Max: 32 · Notes: Reload · nothing was booked; also the iPhone sheet
  ///
  /// In en, this message translates to:
  /// **'Not topped up'**
  String get reloadFailedTitle;

  /// Spec key: reload.failed.body (12 §5.13) · Max: 90 · Notes: Reload
  ///
  /// In en, this message translates to:
  /// **'Nothing was booked. Please try again.'**
  String get reloadFailedBody;

  /// Spec key: reload.uncertain.title (12 §5.13) · Max: 32 · Notes: Reload · no answer
  ///
  /// In en, this message translates to:
  /// **'Top-up unclear'**
  String get reloadUncertainTitle;

  /// Spec key: reload.uncertain.body (12 §5.13) · Max: 140 · Notes: Reload · the same key
  ///
  /// In en, this message translates to:
  /// **'No answer from the server. “Try again” finds out whether it was topped up without booking twice.'**
  String get reloadUncertainBody;

  /// Spec key: reload.notAllowed.title (12 §5.13) · Max: 32 · Notes: Reload · 403 or RELOAD_NOT_ALLOWED
  ///
  /// In en, this message translates to:
  /// **'Cannot top up'**
  String get reloadNotAllowedTitle;

  /// Spec key: reload.notAllowed.body (12 §5.13) · Max: 120 · Notes: Reload
  ///
  /// In en, this message translates to:
  /// **'This sign-in may not top up cards, or the restaurant does not allow top-ups.'**
  String get reloadNotAllowedBody;

  /// Spec key: reload.card.replaced (12 §5.13) · Max: 90 · Notes: Reload · CARD_NOT_USABLE state replaced (suspended, other restaurant: problem.cardNotUsable.*)
  ///
  /// In en, this message translates to:
  /// **'This card was replaced. Hold the guest\'s new card to the phone.'**
  String get reloadCardReplaced;

  /// Spec key: reload.card.revoked (12 §5.13) · Max: 90 · Notes: Reload · state revoked, destroyed
  ///
  /// In en, this message translates to:
  /// **'This card is out of service and cannot be topped up.'**
  String get reloadCardRevoked;

  /// Spec key: reload.card.lost (12 §5.13) · Max: 90 · Notes: Reload · state lost
  ///
  /// In en, this message translates to:
  /// **'This card is reported lost. A manager can help.'**
  String get reloadCardLost;

  /// Spec key: reload.card.notInStock (12 §5.13) · Max: 90 · Notes: Reload · state shipped, delivered
  ///
  /// In en, this message translates to:
  /// **'This card is not in stock yet. Confirm the delivery first.'**
  String get reloadCardNotInStock;

  /// Spec key: reload.card.otherCard (12 §5.13) · Max: 90 · Notes: Reload · the confirming tap found another card
  ///
  /// In en, this message translates to:
  /// **'This is a different card. Hold the same card to the phone to confirm.'**
  String get reloadCardOtherCard;

  /// Spec key: reload.newCard.title (12 §5.13) · Max: 36 · Notes: Reload · a card from stock was tapped: it is sold (card voucher)
  ///
  /// In en, this message translates to:
  /// **'New card – load a balance'**
  String get reloadNewCardTitle;

  /// Spec key: reload.newCard.body (12 §5.13) · Max: 90 · Notes: Reload · inventory number; range message sale.amount.range
  ///
  /// In en, this message translates to:
  /// **'Card {number} from stock. With this amount it is sold and activated.'**
  String reloadNewCardBody(String number);

  /// Spec key: reload.newCard.done.body (12 §5.13) · Max: 60 · Notes: Reload · title sale.card.done.title
  ///
  /// In en, this message translates to:
  /// **'Card {number} is active · balance {balance}'**
  String reloadNewCardDoneBody(String number, String balance);

  /// Spec key: reload.newCard.notAllowed.body (12 §5.13) · Max: 90 · Notes: Reload · no vouchers.sell / cards.bind, or 403 on the sale; title sale.card.failed.title
  ///
  /// In en, this message translates to:
  /// **'This is a new card. Someone who may sell vouchers activates it.'**
  String get reloadNewCardNotAllowedBody;

  /// Spec key: reload.leaveUncertain.title (12 §5.13) · Max: 36 · Notes: Reload · Dialog
  ///
  /// In en, this message translates to:
  /// **'Top-up open – close anyway?'**
  String get reloadLeaveUncertainTitle;

  /// Spec key: reload.leaveUncertain.body (12 §5.13) · Max: 120 · Notes: Reload · Dialog (confirm = sale.leave.confirm)
  ///
  /// In en, this message translates to:
  /// **'It may already have been topped up. Only “Try again” finds out without booking twice.'**
  String get reloadLeaveUncertainBody;

  /// Spec key: qr.title (12 §5.14) · Max: 28 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Scan voucher'**
  String get qrTitle;

  /// Spec key: qr.hint (12 §5.14) · Max: 48 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the voucher\'s QR code'**
  String get qrHint;

  /// Spec key: qr.notVoucher (12 §5.14) · Max: 48 · Notes: 03a · ADR-002 · L10
  ///
  /// In en, this message translates to:
  /// **'This QR code isn\'t a voucher'**
  String get qrNotVoucher;

  /// Spec key: qr.dark (12 §5.14) · Max: 32 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Too dark? Turn on the light.'**
  String get qrDark;

  /// Spec key: qr.torchOn (12 §5.14) · Max: — · Notes: 03a · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Turn on light'**
  String get qrTorchOn;

  /// Spec key: qr.torchOff (12 §5.14) · Max: — · Notes: 03a · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Turn off light'**
  String get qrTorchOff;

  /// Spec key: recent.title (12 §5.15) · Max: 28 · Notes: 03b · harmonised (DE = topBar.recent)
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentTitle;

  /// Spec key: recent.summary (12 §5.15) · Max: 40 · Notes: 03b · HistoryCard
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} redemption} other {{count} redemptions}} · {amount} today'**
  String recentSummary(int count, String amount);

  /// Spec key: recent.row.remaining (12 §5.15) · Max: 20 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'Left {amount}'**
  String recentRowRemaining(String amount);

  /// Spec key: recent.row.empty (12 §5.15) · Max: 20 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'Voucher now empty'**
  String get recentRowEmpty;

  /// Spec key: recent.row.a11y (12 §5.15) · Max: — · Notes: 12 · (a11y)
  ///
  /// In en, this message translates to:
  /// **'{time}, voucher ending {last4}, {amount} redeemed, remaining balance {balance}'**
  String recentRowA11y(
    String time,
    String last4,
    String amount,
    String balance,
  );

  /// Spec key: recent.empty.title (12 §5.15) · Max: 32 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'No redemptions yet'**
  String get recentEmptyTitle;

  /// Spec key: recent.empty.body (12 §5.15) · Max: 90 · Notes: 03b · harmonised (time format §1.5)
  ///
  /// In en, this message translates to:
  /// **'Redemptions from this phone appear here until 04:00.'**
  String get recentEmptyBody;

  /// Spec key: recent.footer (12 §5.15) · Max: 48 · Notes: 03b · harmonised (time format)
  ///
  /// In en, this message translates to:
  /// **'This phone only · cleared at 04:00'**
  String get recentFooter;

  /// Spec key: recent.limit (12 §5.15) · Max: 40 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'Latest 200 redemptions'**
  String get recentLimit;

  /// Spec key: recent.detail.title (12 §5.15) · Max: 28 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'Redemption'**
  String get recentDetailTitle;

  /// Spec key: recent.detail.time (12 §5.15) · Max: 20 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get recentDetailTime;

  /// Spec key: recent.detail.voucher (12 §5.15) · Max: 20 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'Voucher'**
  String get recentDetailVoucher;

  /// Spec key: recent.detail.amount (12 §5.15) · Max: 20 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get recentDetailAmount;

  /// Spec key: recent.detail.remaining (12 §5.15) · Max: 20 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'Remaining balance'**
  String get recentDetailRemaining;

  /// Spec key: recent.detail.transaction (12 §5.15) · Max: 20 · Notes: 03b · value: last 6 chars of the transaction id
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get recentDetailTransaction;

  /// Spec key: recent.detail.supportCode (12 §5.15) · Max: 20 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'Support code'**
  String get recentDetailSupportCode;

  /// Spec key: recent.detail.reverseHint (12 §5.15) · Max: 90 · Notes: 03b · B (EN from brief §1) · harmonised BHS ("dashboard", §1.3)
  ///
  /// In en, this message translates to:
  /// **'Wrong amount? A manager can reverse it in the dashboard.'**
  String get recentDetailReverseHint;

  /// Spec key: menu.close (12 §5.16) · Max: — · Notes: 03a · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Close menu'**
  String get menuClose;

  /// Spec key: menu.account (12 §5.16) · Max: 24 · Notes: 12 · value: name and e-mail
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get menuAccount;

  /// Spec key: menu.restaurant (12 §5.16) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get menuRestaurant;

  /// Spec key: menu.device (12 §5.16) · Max: 24 · Notes: 03a · value: device name
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get menuDevice;

  /// Spec key: menu.section.settings (12 §5.16) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get menuSectionSettings;

  /// Spec key: menu.language (12 §5.16) · Max: 24 · Notes: Account language, the same in the dashboard (options are endonyms, not translated)
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get menuLanguage;

  /// Spec key: menu.languageFailed (12 §5.16) · Max: 60 · Notes: Snackbar
  ///
  /// In en, this message translates to:
  /// **'Language not changed. Please try again.'**
  String get menuLanguageFailed;

  /// Spec key: menu.theme (12 §5.16) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get menuTheme;

  /// Spec key: menu.theme.system (12 §5.16) · Max: 14 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Match system'**
  String get menuThemeSystem;

  /// Spec key: menu.theme.light (12 §5.16) · Max: 10 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get menuThemeLight;

  /// Spec key: menu.theme.dark (12 §5.16) · Max: 10 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get menuThemeDark;

  /// Spec key: menu.sunlightTip (12 §5.16) · Max: 60 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Outdoors, the light theme is easier to read.'**
  String get menuSunlightTip;

  /// Spec key: menu.sound (12 §5.16) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get menuSound;

  /// Spec key: menu.haptics (12 §5.16) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get menuHaptics;

  /// Spec key: menu.haptics.unavailable (12 §5.16) · Max: 40 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Not available on this device'**
  String get menuHapticsUnavailable;

  /// Spec key: menu.keepScreenOn (12 §5.16) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Keep screen on'**
  String get menuKeepScreenOn;

  /// Spec key: menu.keepScreenOn.caption (12 §5.16) · Max: 40 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'While scanning and redeeming'**
  String get menuKeepScreenOnCaption;

  /// Spec key: menu.help (12 §5.16) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get menuHelp;

  /// Spec key: menu.version (12 §5.16) · Max: 32 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String menuVersion(String version);

  /// Spec key: menu.signOut (12 §5.16) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get menuSignOut;

  /// Spec key: menu.signOut.confirm.title (12 §5.16) · Max: 28 · Notes: 03a · Dialog
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get menuSignOutConfirmTitle;

  /// Spec key: menu.signOut.confirm.body (12 §5.16) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'The shift history on this device will be deleted.'**
  String get menuSignOutConfirmBody;

  /// Spec key: menu.signOut.confirm.action (12 §5.16) · Max: 24 · Notes: 12 · DangerButton (cancel = common.cancel)
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get menuSignOutConfirmAction;

  /// Spec key: menu.cards (12 §5.16) · Max: 24 · Notes: Cards · section header
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get menuCards;

  /// Spec key: menu.cards.receive (12 §5.16) · Max: 28 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Confirm a delivery'**
  String get menuCardsReceive;

  /// Spec key: menu.cards.find (12 §5.16) · Max: 28 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Find a card'**
  String get menuCardsFind;

  /// Spec key: cards.receive.none (12 §5.16) · Max: 48 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'No delivery waiting.'**
  String get cardsReceiveNone;

  /// Spec key: cards.receive.batch (12 §5.16) · Max: 24 · Notes: Cards · list row value
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} card} other {{count} cards}}'**
  String cardsReceiveBatch(int count);

  /// Spec key: cards.receive.onHold (12 §5.16) · Max: 60 · Notes: Cards · batch on hold
  ///
  /// In en, this message translates to:
  /// **'Being checked – the count did not match.'**
  String get cardsReceiveOnHold;

  /// Spec key: cards.receive.count (12 §5.16) · Max: 48 · Notes: Cards · count step
  ///
  /// In en, this message translates to:
  /// **'How many cards are in the parcel?'**
  String get cardsReceiveCount;

  /// Spec key: cards.receive.continue (12 §5.16) · Max: 28 · Notes: Cards · {count} digits
  ///
  /// In en, this message translates to:
  /// **'Continue with {count}'**
  String cardsReceiveContinue(int count);

  /// Spec key: cards.receive.tap (12 §5.16) · Max: 64 · Notes: Cards · also the iPhone sheet
  ///
  /// In en, this message translates to:
  /// **'Hold one card from the parcel to the phone.'**
  String get cardsReceiveTap;

  /// Spec key: cards.receive.done (12 §5.16) · Max: 80 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Delivery confirmed – the cards are ready to sell.'**
  String get cardsReceiveDone;

  /// Spec key: cards.receive.hold (12 §5.16) · Max: 80 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'The count does not match. GiftCard Pro checks the delivery.'**
  String get cardsReceiveHold;

  /// Spec key: cards.receive.wrongCard (12 §5.16) · Max: 64 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'This card is not from this delivery.'**
  String get cardsReceiveWrongCard;

  /// Spec key: cards.find.label (12 §5.16) · Max: 24 · Notes: Cards · TextField
  ///
  /// In en, this message translates to:
  /// **'Card number'**
  String get cardsFindLabel;

  /// Spec key: cards.find.helper (12 §5.16) · Max: 80 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Shown with the voucher in the dashboard, e.g. B-2026-0001-0042'**
  String get cardsFindHelper;

  /// Spec key: cards.find.action (12 §5.16) · Max: 16 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get cardsFindAction;

  /// Spec key: cards.find.notFound (12 §5.16) · Max: 48 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'No card with this number.'**
  String get cardsFindNotFound;

  /// Spec key: cards.state.active (12 §5.16) · Max: 16 · Notes: Cards · StatusBadge
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get cardsStateActive;

  /// Spec key: cards.state.suspended (12 §5.16) · Max: 16 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get cardsStateSuspended;

  /// Spec key: cards.state.replaced (12 §5.16) · Max: 16 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Replaced'**
  String get cardsStateReplaced;

  /// Spec key: cards.state.available (12 §5.16) · Max: 16 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get cardsStateAvailable;

  /// Spec key: cards.state.other (12 §5.16) · Max: 24 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Not in use'**
  String get cardsStateOther;

  /// Spec key: cards.balance (12 §5.16) · Max: 32 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Balance {amount}'**
  String cardsBalance(String amount);

  /// Spec key: cards.suspend (12 §5.16) · Max: 24 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Suspend card'**
  String get cardsSuspend;

  /// Spec key: cards.resume (12 §5.16) · Max: 24 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Resume card'**
  String get cardsResume;

  /// Spec key: cards.replace (12 §5.16) · Max: 24 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Replace card'**
  String get cardsReplace;

  /// Spec key: cards.reason.title (12 §5.16) · Max: 16 · Notes: Cards · section label
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get cardsReasonTitle;

  /// Spec key: cards.reason.lost (12 §5.16) · Max: 16 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get cardsReasonLost;

  /// Spec key: cards.reason.stolen (12 §5.16) · Max: 16 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Stolen'**
  String get cardsReasonStolen;

  /// Spec key: cards.reason.damaged (12 §5.16) · Max: 16 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get cardsReasonDamaged;

  /// Spec key: cards.reason.found (12 §5.16) · Max: 16 · Notes: Cards · resume
  ///
  /// In en, this message translates to:
  /// **'Found again'**
  String get cardsReasonFound;

  /// Spec key: cards.replace.tap (12 §5.16) · Max: 90 · Notes: Cards · also the iPhone sheet
  ///
  /// In en, this message translates to:
  /// **'Hold a new card from stock to the phone. The balance moves to it.'**
  String get cardsReplaceTap;

  /// Spec key: cards.replace.tapOld (12 §5.16) · Max: 60 · Notes: Cards · also the iPhone sheet
  ///
  /// In en, this message translates to:
  /// **'Hold the guest\'s old card to the phone.'**
  String get cardsReplaceTapOld;

  /// Spec key: cards.replace.ownerOnly (12 §5.16) · Max: 120 · Notes: Cards · replace sheet footnote
  ///
  /// In en, this message translates to:
  /// **'Only the owner can replace a lost or stolen card. Suspend it now so it stops paying.'**
  String get cardsReplaceOwnerOnly;

  /// Spec key: cards.replace.done (12 §5.16) · Max: 80 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Replaced by {number}. The old card no longer works.'**
  String cardsReplaceDone(String number);

  /// Spec key: cards.suspend.done (12 §5.16) · Max: 60 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Suspended – the card no longer pays.'**
  String get cardsSuspendDone;

  /// Spec key: cards.resume.done (12 §5.16) · Max: 60 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'Resumed – the card pays again.'**
  String get cardsResumeDone;

  /// Spec key: cards.failed (12 §5.16) · Max: 60 · Notes: Cards
  ///
  /// In en, this message translates to:
  /// **'That did not work. Try again.'**
  String get cardsFailed;

  /// Spec key: session.expired (12 §5.17) · Max: 28 · Notes: B · A01
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get sessionExpired;

  /// Spec key: session.expired.body (12 §5.17) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Sign in again to continue.'**
  String get sessionExpiredBody;

  /// Spec key: session.expired.action (12 §5.17) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get sessionExpiredAction;

  /// Spec key: forbidden.title (12 §5.17) · Max: 32 · Notes: 12 · A03
  ///
  /// In en, this message translates to:
  /// **'No permission to redeem'**
  String get forbiddenTitle;

  /// Spec key: forbidden.body (12 §5.17) · Max: 90 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'This account can no longer redeem vouchers. Please get a manager.'**
  String get forbiddenBody;

  /// Spec key: deviceRevoked.title (12 §5.17) · Max: 32 · Notes: 03a · A04
  ///
  /// In en, this message translates to:
  /// **'This device was removed'**
  String get deviceRevokedTitle;

  /// Spec key: deviceRevoked.body (12 §5.17) · Max: 90 · Notes: 03a · harmonised (escalation wording §2.6)
  ///
  /// In en, this message translates to:
  /// **'It\'s no longer allowed for this restaurant. Please get a manager.'**
  String get deviceRevokedBody;

  /// Spec key: deviceRevoked.action (12 §5.17) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get deviceRevokedAction;

  /// Spec key: suspended.title (12 §5.17) · Max: 32 · Notes: 03a · A05
  ///
  /// In en, this message translates to:
  /// **'Redeeming is paused'**
  String get suspendedTitle;

  /// Spec key: suspended.body (12 §5.17) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'The restaurant\'s account is paused. Please get a manager.'**
  String get suspendedBody;

  /// Spec key: deactivated.title (12 §5.17) · Max: 32 · Notes: 03a · A10
  ///
  /// In en, this message translates to:
  /// **'Account deactivated'**
  String get deactivatedTitle;

  /// Spec key: deactivated.body (12 §5.17) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'This account can no longer be used. Please get a manager.'**
  String get deactivatedBody;

  /// Spec key: update.title (12 §5.17) · Max: 32 · Notes: 03a · A11
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateTitle;

  /// Spec key: update.body (12 §5.17) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'This version is no longer supported. Update to keep redeeming.'**
  String get updateBody;

  /// Spec key: update.action (12 §5.17) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateAction;

  /// Spec key: camera.denied.title (12 §5.18) · Max: 32 · Notes: 03a · P03
  ///
  /// In en, this message translates to:
  /// **'Camera access is off'**
  String get cameraDeniedTitle;

  /// Spec key: camera.denied.body (12 §5.18) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Allow camera access in Settings to scan QR codes.'**
  String get cameraDeniedBody;

  /// Spec key: camera.denied.action (12 §5.18) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get cameraDeniedAction;

  /// Spec key: camera.restricted.body (12 §5.18) · Max: 90 · Notes: 03a · P04
  ///
  /// In en, this message translates to:
  /// **'The camera is restricted on this device. Please get a manager.'**
  String get cameraRestrictedBody;

  /// Spec key: camera.unavailable.title (12 §5.18) · Max: 32 · Notes: 12 · P05
  ///
  /// In en, this message translates to:
  /// **'Camera not available'**
  String get cameraUnavailableTitle;

  /// Spec key: camera.unavailable.body (12 §5.18) · Max: 90 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'Close other apps using the camera, then try again.'**
  String get cameraUnavailableBody;

  /// Spec key: intro.skip (12 §5.19) · Max: 16 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get introSkip;

  /// Spec key: intro.next (12 §5.19) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get introNext;

  /// Spec key: intro.start (12 §5.19) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get introStart;

  /// Spec key: intro.page (12 §5.19) · Max: — · Notes: 03a · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Page {n} of 3'**
  String introPage(int n);

  /// Spec key: intro.1.title (12 §5.19) · Max: 28 · Notes: ADR-002
  ///
  /// In en, this message translates to:
  /// **'Scan the voucher'**
  String get intro1Title;

  /// Spec key: intro.1.body (12 §5.19) · Max: 90 · Notes: ADR-002
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code. The balance appears right away.'**
  String get intro1Body;

  /// Spec key: intro.2.title (12 §5.19) · Max: 32 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Type the amount, redeem'**
  String get intro2Title;

  /// Spec key: intro.2.body (12 §5.19) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'See the balance, type the amount, done. From {threshold}, press and hold to confirm.'**
  String intro2Body(String threshold);

  /// Spec key: intro.3.title (12 §5.19) · Max: 28 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Never booked twice'**
  String get intro3Title;

  /// Spec key: intro.3.body (12 §5.19) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Redeeming only works online. Your shift\'s redemptions are under \"Recent\".'**
  String get intro3Body;

  /// Spec key: station.title (12 §5.19) · Max: 28 · Notes: Station · S21 title
  ///
  /// In en, this message translates to:
  /// **'Personalise cards'**
  String get stationTitle;

  /// Spec key: station.choose (12 §5.19) · Max: 28 · Notes: Station · batch list
  ///
  /// In en, this message translates to:
  /// **'Choose a batch'**
  String get stationChoose;

  /// Spec key: station.empty (12 §5.19) · Max: 60 · Notes: Station · empty list
  ///
  /// In en, this message translates to:
  /// **'No batch is waiting for personalisation.'**
  String get stationEmpty;

  /// Spec key: station.batch (12 §5.19) · Max: 28 · Notes: Station · list row subtitle
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} card done} other {{count} cards done}}'**
  String stationBatch(int count);

  /// Spec key: station.waiting (12 §5.19) · Max: 48 · Notes: Station · also the iPhone sheet
  ///
  /// In en, this message translates to:
  /// **'Hold a blank card to the phone.'**
  String get stationWaiting;

  /// Spec key: station.working (12 §5.19) · Max: 48 · Notes: Station · rounds running
  ///
  /// In en, this message translates to:
  /// **'Personalising – keep the card still.'**
  String get stationWorking;

  /// Spec key: station.done (12 §5.19) · Max: 40 · Notes: Station · {number} = inventory number
  ///
  /// In en, this message translates to:
  /// **'Card {number} done'**
  String stationDone(String number);

  /// Spec key: station.failed (12 §5.19) · Max: 48 · Notes: Station · resumable failure
  ///
  /// In en, this message translates to:
  /// **'Card not finished. Hold it again.'**
  String get stationFailed;

  /// Spec key: station.rejected (12 §5.19) · Max: 80 · Notes: Station · other_batch, already_personalized
  ///
  /// In en, this message translates to:
  /// **'Card is not from this batch or is already done.'**
  String get stationRejected;

  /// Spec key: station.unknownChip (12 §5.19) · Max: 48 · Notes: Station · keys unknown (auth:91AE)
  ///
  /// In en, this message translates to:
  /// **'Unknown card – set it aside.'**
  String get stationUnknownChip;

  /// Spec key: station.finish (12 §5.19) · Max: 24 · Notes: Station · back to the list
  ///
  /// In en, this message translates to:
  /// **'Finish batch'**
  String get stationFinish;

  /// Spec key: a11y.spokenAmount (12 §5.20) · Politeness: — · Notes: 12 · cents omitted when 0; "{cents} Cent / cents / centi" when euros = 0 (§1.4)
  ///
  /// In en, this message translates to:
  /// **'{euros, plural, one {{euros} euro} other {{euros} euros}} {cents}'**
  String a11ySpokenAmount(int euros, String cents);

  /// Spec key: a11y.voucherLoaded (12 §5.20) · Politeness: assertive · Notes: 12 · S07 opened; status appended if not active
  ///
  /// In en, this message translates to:
  /// **'{restaurant}. Balance {spokenAmount}.'**
  String a11yVoucherLoaded(String restaurant, String spokenAmount);

  /// Spec key: a11y.problem (12 §5.20) · Politeness: assertive · Notes: 12 · every S10/S15 screen and banner
  ///
  /// In en, this message translates to:
  /// **'{title}. {body}'**
  String a11yProblem(String title, String body);

  /// Spec key: a11y.ready (12 §5.20) · Politeness: polite · Notes: 12 · return to S05
  ///
  /// In en, this message translates to:
  /// **'Ready for the next voucher'**
  String get a11yReady;

  /// Spec key: a11y.scanAvailable (12 §5.20) · Politeness: polite · Notes: 12 · throttle end (03b §5.2)
  ///
  /// In en, this message translates to:
  /// **'Scanning available again'**
  String get a11yScanAvailable;

  /// Spec key: a11y.redeemAvailable (12 §5.20) · Politeness: polite · Notes: 12 · rate/velocity countdown end
  ///
  /// In en, this message translates to:
  /// **'Redeem available again'**
  String get a11yRedeemAvailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bs', 'de', 'en', 'hr', 'sr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bs':
      return AppLocalizationsBs();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'hr':
      return AppLocalizationsHr();
    case 'sr':
      return AppLocalizationsSr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
