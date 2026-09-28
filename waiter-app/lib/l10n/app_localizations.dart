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

  /// Spec key: common.enterNumber (12 §5.1) · Max: 24 · Notes: 03b · opens S11
  ///
  /// In en, this message translates to:
  /// **'Enter card number'**
  String get commonEnterNumber;

  /// Spec key: common.editNumber (12 §5.1) · Max: 24 · Notes: 03b · S11 prefilled
  ///
  /// In en, this message translates to:
  /// **'Edit number'**
  String get commonEditNumber;

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

  /// Spec key: signIn.error.invalid (12 §5.3) · Max: 90 · Notes: 03a · A07
  ///
  /// In en, this message translates to:
  /// **'E-mail or password is incorrect. Check both and try again.'**
  String get signInErrorInvalid;

  /// Spec key: signIn.error.noPermission (12 §5.3) · Max: 90 · Notes: 03a · A02
  ///
  /// In en, this message translates to:
  /// **'This account can\'t redeem cards. Please get a manager.'**
  String get signInErrorNoPermission;

  /// Spec key: signIn.error.throttled (12 §5.3) · Max: 48 · Notes: 03a · A08
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {time}.'**
  String signInErrorThrottled(String time);

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

  /// Spec key: unlock.pendingCard (12 §5.5) · Max: 48 · Notes: 03a · deep link waiting
  ///
  /// In en, this message translates to:
  /// **'The card opens after unlocking.'**
  String get unlockPendingCard;

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

  /// Spec key: ready.android.title (12 §5.6) · Max: 32 · Notes: B
  ///
  /// In en, this message translates to:
  /// **'Hold the card to the phone'**
  String get readyAndroidTitle;

  /// Spec key: ready.android.hint (12 §5.6) · Max: 40 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'The card is detected automatically'**
  String get readyAndroidHint;

  /// Spec key: ready.ios.button (12 §5.6) · Max: 24 · Notes: B
  ///
  /// In en, this message translates to:
  /// **'Scan card'**
  String get readyIosButton;

  /// Spec key: ready.ios.hint (12 §5.6) · Max: 60 · Notes: 03a · 2 lines
  ///
  /// In en, this message translates to:
  /// **'After tapping, hold the card near the top of the iPhone'**
  String get readyIosHint;

  /// Spec key: ready.ios.timeout (12 §5.6) · Max: 90 · Notes: 03a · P08
  ///
  /// In en, this message translates to:
  /// **'No card detected. Tap \"Scan card\" to try again.'**
  String get readyIosTimeout;

  /// Spec key: ready.manual (12 §5.6) · Max: 16 · Notes: 03a · icon + noun (exception to verb + object, §1.2)
  ///
  /// In en, this message translates to:
  /// **'Card number'**
  String get readyManual;

  /// Spec key: ready.qr (12 §5.6) · Max: 16 · Notes: 03a · icon + noun
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get readyQr;

  /// Spec key: ready.firstCardTip.android (12 §5.6) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Tip: the NFC antenna is usually at the top of the back, near the camera.'**
  String get readyFirstCardTipAndroid;

  /// Spec key: ready.firstCardTip.ios (12 §5.6) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Tip: hold the card flat against the top edge, near the camera.'**
  String get readyFirstCardTipIos;

  /// Spec key: ready.noNfc.title (12 §5.6) · Max: 32 · Notes: 03a · P02
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code on the card'**
  String get readyNoNfcTitle;

  /// Spec key: ready.noNfc.hint (12 §5.6) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'This device has no NFC. Use the QR code or the card number.'**
  String get readyNoNfcHint;

  /// Spec key: ready.noNfc.button (12 §5.6) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get readyNoNfcButton;

  /// Spec key: ready.offline.tap (12 §5.6) · Max: 60 · Notes: 03a · L09 · harmonised (EN en dash)
  ///
  /// In en, this message translates to:
  /// **'No connection – the card can\'t be checked'**
  String get readyOfflineTap;

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

  /// Spec key: ready.newCard (12 §5.6) · Max: 24 · Notes: S20 · managers and owners only · button on S05
  ///
  /// In en, this message translates to:
  /// **'New gift card'**
  String get readyNewCard;

  /// Spec key: issue.title (12 §5.6) · Max: 24 · Notes: S20 · screen title
  ///
  /// In en, this message translates to:
  /// **'New gift card'**
  String get issueTitle;

  /// Spec key: issue.amount.label (12 §5.6) · Max: 24 · Notes: S20 · above the amount
  ///
  /// In en, this message translates to:
  /// **'Card value'**
  String get issueAmountLabel;

  /// Spec key: issue.email.label (12 §5.6) · Max: 32 · Notes: S20
  ///
  /// In en, this message translates to:
  /// **'Guest e-mail (optional)'**
  String get issueEmailLabel;

  /// Spec key: issue.email.helper (12 §5.6) · Max: 60 · Notes: S20
  ///
  /// In en, this message translates to:
  /// **'The guest receives a confirmation.'**
  String get issueEmailHelper;

  /// Spec key: issue.email.invalid (12 §5.6) · Max: 60 · Notes: S20 · field error
  ///
  /// In en, this message translates to:
  /// **'Enter a valid e-mail address.'**
  String get issueEmailInvalid;

  /// Spec key: issue.amount.range (12 §5.6) · Max: 60 · Notes: S20 · server INVALID_AMOUNT
  ///
  /// In en, this message translates to:
  /// **'The card value must be between {min} and {max}.'**
  String issueAmountRange(String min, String max);

  /// Spec key: issue.create (12 §5.6) · Max: 32 · Notes: S20 · primary
  ///
  /// In en, this message translates to:
  /// **'Create card · {amount}'**
  String issueCreate(String amount);

  /// Spec key: issue.creating (12 §5.6) · Max: 32 · Notes: S20 · button progress
  ///
  /// In en, this message translates to:
  /// **'Creating card …'**
  String get issueCreating;

  /// Spec key: issue.program.title (12 §5.6) · Max: 36 · Notes: S20 · programming
  ///
  /// In en, this message translates to:
  /// **'Hold a blank card to the phone'**
  String get issueProgramTitle;

  /// Spec key: issue.program.body (12 §5.6) · Max: 90 · Notes: S20
  ///
  /// In en, this message translates to:
  /// **'Keep it still on the back of the phone until the check mark appears.'**
  String get issueProgramBody;

  /// Spec key: issue.program.retap (12 §5.6) · Max: 60 · Notes: S20 · hint
  ///
  /// In en, this message translates to:
  /// **'Lift the card and hold it to the phone again.'**
  String get issueProgramRetap;

  /// Spec key: issue.step.check (12 §5.6) · Max: 24 · Notes: S20 · step
  ///
  /// In en, this message translates to:
  /// **'Check tag'**
  String get issueStepCheck;

  /// Spec key: issue.step.write (12 §5.6) · Max: 24 · Notes: S20 · step
  ///
  /// In en, this message translates to:
  /// **'Write card link'**
  String get issueStepWrite;

  /// Spec key: issue.step.verify (12 §5.6) · Max: 24 · Notes: S20 · step
  ///
  /// In en, this message translates to:
  /// **'Read back and verify'**
  String get issueStepVerify;

  /// Spec key: issue.step.save (12 §5.6) · Max: 28 · Notes: S20 · step
  ///
  /// In en, this message translates to:
  /// **'Save chip to card'**
  String get issueStepSave;

  /// Spec key: issue.card (12 §5.6) · Max: 32 · Notes: S20 · card number, grouped
  ///
  /// In en, this message translates to:
  /// **'Card {number}'**
  String issueCard(String number);

  /// Spec key: issue.success.title (12 §5.6) · Max: 20 · Notes: S20
  ///
  /// In en, this message translates to:
  /// **'Card ready'**
  String get issueSuccessTitle;

  /// Spec key: issue.success.balance (12 §5.6) · Max: 32 · Notes: S20
  ///
  /// In en, this message translates to:
  /// **'Balance {amount}'**
  String issueSuccessBalance(String amount);

  /// Spec key: issue.success.verified (12 §5.6) · Max: 40 · Notes: S20
  ///
  /// In en, this message translates to:
  /// **'NFC tag written and verified'**
  String get issueSuccessVerified;

  /// Spec key: issue.success.noTag (12 §5.6) · Max: 60 · Notes: S20 · after “Program later”
  ///
  /// In en, this message translates to:
  /// **'No tag yet. Program it later in the dashboard.'**
  String get issueSuccessNoTag;

  /// Spec key: issue.success.another (12 §5.6) · Max: 28 · Notes: S20 · secondary
  ///
  /// In en, this message translates to:
  /// **'Sell another card'**
  String get issueSuccessAnother;

  /// Spec key: issue.later (12 §5.6) · Max: 24 · Notes: S20 · keeps the card without a tag
  ///
  /// In en, this message translates to:
  /// **'Program later'**
  String get issueLater;

  /// Spec key: issue.nfcOff (12 §5.6) · Max: 60 · Notes: S20
  ///
  /// In en, this message translates to:
  /// **'Turn on NFC to program the tag.'**
  String get issueNfcOff;

  /// Spec key: issue.createFailed.title (12 §5.6) · Max: 28 · Notes: S20
  ///
  /// In en, this message translates to:
  /// **'Card not created'**
  String get issueCreateFailedTitle;

  /// Spec key: issue.createFailed.body (12 §5.6) · Max: 90 · Notes: S20 · definitive answer
  ///
  /// In en, this message translates to:
  /// **'No card was created. Check the connection and try again.'**
  String get issueCreateFailedBody;

  /// Spec key: issue.createUncertain.body (12 §5.6) · Max: 90 · Notes: S20 · same idempotency key
  ///
  /// In en, this message translates to:
  /// **'The answer did not arrive. Try again, the card will not be created twice.'**
  String get issueCreateUncertainBody;

  /// Spec key: issue.notAllowed.title (12 §5.6) · Max: 28 · Notes: S20 · 403
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get issueNotAllowedTitle;

  /// Spec key: issue.notAllowed.body (12 §5.6) · Max: 120 · Notes: S20 · 403
  ///
  /// In en, this message translates to:
  /// **'This account cannot sell cards on this phone. Sign out and in again, or use the dashboard.'**
  String get issueNotAllowedBody;

  /// Spec key: issue.tagFailed.title (12 §5.6) · Max: 28 · Notes: S20 · the card exists, nothing was saved to it
  ///
  /// In en, this message translates to:
  /// **'Tag not programmed'**
  String get issueTagFailedTitle;

  /// Spec key: issue.tag.otherCard (12 §5.6) · Max: 90 · Notes: S20 · check refused, conflict
  ///
  /// In en, this message translates to:
  /// **'This tag belongs to card {number}. Use a blank tag.'**
  String issueTagOtherCard(String number);

  /// Spec key: issue.tag.refused (12 §5.6) · Max: 90 · Notes: S20 · check refused
  ///
  /// In en, this message translates to:
  /// **'This tag cannot be used for this card. Use a blank tag.'**
  String get issueTagRefused;

  /// Spec key: issue.tag.unsupported (12 §5.6) · Max: 90 · Notes: S20
  ///
  /// In en, this message translates to:
  /// **'This tag type is not supported. Use NTAG213, 215 or 216.'**
  String get issueTagUnsupported;

  /// Spec key: issue.tag.readOnly (12 §5.6) · Max: 90 · Notes: S20
  ///
  /// In en, this message translates to:
  /// **'This tag is locked and cannot be written.'**
  String get issueTagReadOnly;

  /// Spec key: issue.tag.moved (12 §5.6) · Max: 90 · Notes: S20 · write / read failed, timeout
  ///
  /// In en, this message translates to:
  /// **'The tag moved away. Hold it still and try again.'**
  String get issueTagMoved;

  /// Spec key: issue.tag.verifyFailed (12 §5.6) · Max: 90 · Notes: S20 · read-back mismatch
  ///
  /// In en, this message translates to:
  /// **'The tag could not be verified. Try again with the same tag.'**
  String get issueTagVerifyFailed;

  /// Spec key: issue.tag.network (12 §5.6) · Max: 90 · Notes: S20 · check / save without answer
  ///
  /// In en, this message translates to:
  /// **'No connection to the server. Try again.'**
  String get issueTagNetwork;

  /// Spec key: ios.sheet.alert (12 §5.7) · Max: 48 · Notes: B
  ///
  /// In en, this message translates to:
  /// **'Hold the card near the top of the iPhone'**
  String get iosSheetAlert;

  /// Spec key: ios.sheet.found (12 §5.7) · Max: 48 · Notes: 03a · B wording
  ///
  /// In en, this message translates to:
  /// **'Card found'**
  String get iosSheetFound;

  /// Spec key: ios.sheet.readFailed (12 §5.7) · Max: 48 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the card. Try again.'**
  String get iosSheetReadFailed;

  /// Spec key: ios.sheet.multiple (12 §5.7) · Max: 48 · Notes: 03a · P06
  ///
  /// In en, this message translates to:
  /// **'More than one card detected. Hold only one.'**
  String get iosSheetMultiple;

  /// Spec key: ios.sheet.timeoutSoon (12 §5.7) · Max: 60 · Notes: 03a · P07
  ///
  /// In en, this message translates to:
  /// **'No card yet. Hold it flat near the top of the iPhone.'**
  String get iosSheetTimeoutSoon;

  /// Spec key: scan.notCard (12 §5.7) · Max: 32 · Notes: 03a · harmonised ("Gutscheinkarte", "poklon kartica", §1.3) · L10
  ///
  /// In en, this message translates to:
  /// **'This is not a gift card'**
  String get scanNotCard;

  /// Spec key: scan.readFailed.title (12 §5.7) · Max: 32 · Notes: 03a · L11
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the card'**
  String get scanReadFailedTitle;

  /// Spec key: scan.readFailed.body (12 §5.7) · Max: 48 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Hold it still for a second.'**
  String get scanReadFailedBody;

  /// Spec key: scan.detected (12 §5.7) · Max: — · Notes: 03a · (a11y) announcement
  ///
  /// In en, this message translates to:
  /// **'Card detected'**
  String get scanDetected;

  /// Spec key: scan.lookingUp (12 §5.7) · Max: 32 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Looking up card …'**
  String get scanLookingUp;

  /// Spec key: scan.slow (12 §5.7) · Max: 32 · Notes: 03a · L08 · alias lookup.stillLooking (03b)
  ///
  /// In en, this message translates to:
  /// **'Still looking …'**
  String get scanSlow;

  /// Spec key: scan.unavailable (12 §5.7) · Max: 90 · Notes: 03a · P09
  ///
  /// In en, this message translates to:
  /// **'NFC isn\'t available right now. Use the card number or QR code.'**
  String get scanUnavailable;

  /// Spec key: balanceCard.overline (12 §5.8) · Max: 16 · Notes: 12 · uppercased by style
  ///
  /// In en, this message translates to:
  /// **'Gift card'**
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
  /// **'Gift card {restaurant}. Balance {spokenAmount}. Card ending {last4}.'**
  String balanceCardA11y(String restaurant, String spokenAmount, String last4);

  /// Spec key: charge.cardNumber.a11y (12 §5.8) · Max: — · Notes: 12 · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Card number {number}'**
  String chargeCardNumberA11y(String number);

  /// Spec key: a11y.charge.close (12 §5.8) · Max: — · Notes: 03b · (a11y)
  ///
  /// In en, this message translates to:
  /// **'Close card'**
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
  /// **'Limit for this card reached'**
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

  /// Spec key: charge.switchCard.message (12 §5.8) · Max: 48 · Notes: 03b · B EN wording (brief §2) · P14
  ///
  /// In en, this message translates to:
  /// **'Different card detected – Switch?'**
  String get chargeSwitchCardMessage;

  /// Spec key: charge.switchCard.action (12 §5.8) · Max: 12 · Notes: 03b · B
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get chargeSwitchCardAction;

  /// Spec key: charge.switchCard.keep (12 §5.8) · Max: 12 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get chargeSwitchCardKeep;

  /// Spec key: charge.switchCard.dialogTitle (12 §5.8) · Max: 32 · Notes: 12 · Dialog fallback with screen reader (03b §2.18)
  ///
  /// In en, this message translates to:
  /// **'Different card detected'**
  String get chargeSwitchCardDialogTitle;

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

  /// Spec key: badge.inactive (12 §5.9) · Max: 16 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'Not activated'**
  String get badgeInactive;

  /// Spec key: badge.redeemed (12 §5.9) · Max: 16 · Notes: 12 · status redeemed or balance 0
  ///
  /// In en, this message translates to:
  /// **'Used up'**
  String get badgeRedeemed;

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

  /// Spec key: badge.replaced (12 §5.9) · Max: 16 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'Replaced'**
  String get badgeReplaced;

  /// Spec key: card.blocked (12 §5.9) · Max: 28 · Notes: B · danger · body = getManager
  ///
  /// In en, this message translates to:
  /// **'Card blocked'**
  String get cardBlocked;

  /// Spec key: card.blocked.reason (12 §5.9) · Max: 90 · Notes: 03b · only if blocked_reason present
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String cardBlockedReason(String reason);

  /// Spec key: card.expired (12 §5.9) · Max: 28 · Notes: B · warning
  ///
  /// In en, this message translates to:
  /// **'Card expired'**
  String get cardExpired;

  /// Spec key: card.expired.body (12 §5.9) · Max: 90 · Notes: 03b · harmonised (escalation wording §2.6)
  ///
  /// In en, this message translates to:
  /// **'Expired on {date}. Please get a manager.'**
  String cardExpiredBody(String date);

  /// Spec key: card.inactive (12 §5.9) · Max: 28 · Notes: B · warning
  ///
  /// In en, this message translates to:
  /// **'Card not activated yet'**
  String get cardInactive;

  /// Spec key: card.inactive.body (12 §5.9) · Max: 90 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'It can be redeemed once activated. Please get a manager.'**
  String get cardInactiveBody;

  /// Spec key: card.replaced (12 §5.9) · Max: 28 · Notes: B · warning
  ///
  /// In en, this message translates to:
  /// **'Card was replaced'**
  String get cardReplaced;

  /// Spec key: card.replaced.body (12 §5.9) · Max: 90 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'The balance is on the new card. Ask the guest for the new card.'**
  String get cardReplacedBody;

  /// Spec key: card.empty (12 §5.9) · Max: 28 · Notes: B · warning
  ///
  /// In en, this message translates to:
  /// **'No balance left'**
  String get cardEmpty;

  /// Spec key: card.empty.body (12 §5.9) · Max: 90 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'This card has been fully used.'**
  String get cardEmptyBody;

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

  /// Spec key: uncertain.failedBody (12 §5.10) · Max: 90 · Notes: 03b · R04
  ///
  /// In en, this message translates to:
  /// **'Not confirmed yet. Try again – nothing is ever booked twice.'**
  String get uncertainFailedBody;

  /// Spec key: uncertain.cancelled (12 §5.10) · Max: 90 · Notes: 03b · R05 · harmonised (no "charging / terećenje")
  ///
  /// In en, this message translates to:
  /// **'Not confirmed. Scan the card again before redeeming.'**
  String get uncertainCancelled;

  /// Spec key: uncertain.cancelledGuestHint (12 §5.10) · Max: 120 · Notes: 03b · harmonised (vocabulary); 3 lines allowed (quoted speech)
  ///
  /// In en, this message translates to:
  /// **'Tell the guest: \"The redemption isn\'t confirmed yet. We\'ll check the balance before redeeming again.\"'**
  String get uncertainCancelledGuestHint;

  /// Spec key: redeem.balanceChanged (12 §5.10) · Max: 48 · Notes: 03b · R06
  ///
  /// In en, this message translates to:
  /// **'Balance changed: now {amount}'**
  String redeemBalanceChanged(String amount);

  /// Spec key: redeem.tapAgain (12 §5.10) · Max: 48 · Notes: 03b · R13
  ///
  /// In en, this message translates to:
  /// **'Please tap Redeem again.'**
  String get redeemTapAgain;

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
  /// **'Card is now empty'**
  String get successEmpty;

  /// Spec key: success.next.ios (12 §5.11) · Max: 24 · Notes: B
  ///
  /// In en, this message translates to:
  /// **'Scan next card'**
  String get successNextIos;

  /// Spec key: success.next.android (12 §5.11) · Max: 32 · Notes: B
  ///
  /// In en, this message translates to:
  /// **'Just tap the next card'**
  String get successNextAndroid;

  /// Spec key: success.showGuest (12 §5.11) · Max: 24 · Notes: 03b · presentation mode
  ///
  /// In en, this message translates to:
  /// **'Show guest'**
  String get successShowGuest;

  /// Spec key: success.card (12 §5.11) · Max: 20 · Notes: 12 · caption
  ///
  /// In en, this message translates to:
  /// **'Card •••• {last4}'**
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

  /// Spec key: problem.notFound.title (12 §5.12) · Max: 32 · Notes: B · L01/L02
  ///
  /// In en, this message translates to:
  /// **'Card not found'**
  String get problemNotFoundTitle;

  /// Spec key: problem.notFound.body (12 §5.12) · Max: 90 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'This card is not in the system. Check the card or ask the guest for another one.'**
  String get problemNotFoundBody;

  /// Spec key: problem.notFound.bodyManual (12 §5.12) · Max: 90 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'No card with this number. Check the digits.'**
  String get problemNotFoundBodyManual;

  /// Spec key: problem.foreign.title (12 §5.12) · Max: 32 · Notes: B · L03
  ///
  /// In en, this message translates to:
  /// **'Card from another restaurant'**
  String get problemForeignTitle;

  /// Spec key: problem.foreign.body (12 §5.12) · Max: 90 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'It can only be redeemed at the restaurant that issued it.'**
  String get problemForeignBody;

  /// Spec key: problem.verify.title (12 §5.12) · Max: 32 (2 lines) · Notes: B · L04
  ///
  /// In en, this message translates to:
  /// **'Card could not be verified'**
  String get problemVerifyTitle;

  /// Spec key: problem.verify.body (12 §5.12) · Max: 90 · Notes: 03b · harmonised (escalation wording §2.6)
  ///
  /// In en, this message translates to:
  /// **'Do not accept this card for now. Please get a manager.'**
  String get problemVerifyBody;

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
  /// **'The card could not be checked. Check Wi-Fi or mobile data, then try again.'**
  String get problemNetworkBody;

  /// Spec key: problem.server.title (12 §5.12) · Max: 32 · Notes: 03b · harmonised (title states what happened, §2.1)
  ///
  /// In en, this message translates to:
  /// **'Service not available right now'**
  String get problemServerTitle;

  /// Spec key: problem.server.body (12 §5.12) · Max: 90 · Notes: 03b · harmonised (no "wir/uns" in the UI, §1.2)
  ///
  /// In en, this message translates to:
  /// **'The problem is not the card. Try again in a moment.'**
  String get problemServerBody;

  /// Spec key: manual.title (12 §5.13) · Max: 28 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Card number'**
  String get manualTitle;

  /// Spec key: manual.helper (12 §5.13) · Max: 40 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'16 digits on the back of the card'**
  String get manualHelper;

  /// Spec key: manual.counter (12 §5.13) · Max: 12 · Notes: 03a · tabular figures
  ///
  /// In en, this message translates to:
  /// **'{count} of 16'**
  String manualCounter(int count);

  /// Spec key: manual.submit (12 §5.13) · Max: 24 · Notes: 03a · enabled at 16 digits
  ///
  /// In en, this message translates to:
  /// **'Look up card'**
  String get manualSubmit;

  /// Spec key: manual.error.invalid (12 §5.13) · Max: 32 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Check the card number'**
  String get manualErrorInvalid;

  /// Spec key: manual.error.paste (12 §5.13) · Max: 48 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'No valid card number to paste'**
  String get manualErrorPaste;

  /// Spec key: qr.title (12 §5.14) · Max: 28 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get qrTitle;

  /// Spec key: qr.hint (12 §5.14) · Max: 48 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code on the card'**
  String get qrHint;

  /// Spec key: qr.notCard (12 §5.14) · Max: 48 · Notes: 03a · harmonised (vocabulary) · L10
  ///
  /// In en, this message translates to:
  /// **'This QR code isn\'t a gift card'**
  String get qrNotCard;

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

  /// Spec key: qr.manual (12 §5.14) · Max: 24 · Notes: 03a · = common.enterNumber (alias)
  ///
  /// In en, this message translates to:
  /// **'Enter card number'**
  String get qrManual;

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
  /// **'Card now empty'**
  String get recentRowEmpty;

  /// Spec key: recent.row.a11y (12 §5.15) · Max: — · Notes: 12 · (a11y)
  ///
  /// In en, this message translates to:
  /// **'{time}, card ending {last4}, {amount} redeemed, remaining balance {balance}'**
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

  /// Spec key: recent.detail.card (12 §5.15) · Max: 20 · Notes: 03b
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get recentDetailCard;

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
  /// **'This account can no longer redeem cards. Please get a manager.'**
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

  /// Spec key: locked.title (12 §5.17) · Max: 32 · Notes: 03a · A06
  ///
  /// In en, this message translates to:
  /// **'Account temporarily locked'**
  String get lockedTitle;

  /// Spec key: locked.body (12 §5.17) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Too many sign-in attempts. Try again in {time}.'**
  String lockedBody(String time);

  /// Spec key: locked.button (12 §5.17) · Max: 24 · Notes: 03a · disabled
  ///
  /// In en, this message translates to:
  /// **'Try again in {time}'**
  String lockedButton(String time);

  /// Spec key: locked.over (12 §5.17) · Max: — · Notes: 03a · (a11y)
  ///
  /// In en, this message translates to:
  /// **'You can sign in again'**
  String get lockedOver;

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

  /// Spec key: nfcOff.title (12 §5.18) · Max: 32 · Notes: 03a · P01
  ///
  /// In en, this message translates to:
  /// **'NFC is off'**
  String get nfcOffTitle;

  /// Spec key: nfcOff.body (12 §5.18) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Turn on NFC to scan cards.'**
  String get nfcOffBody;

  /// Spec key: nfcOff.action (12 §5.18) · Max: 24 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Turn on NFC'**
  String get nfcOffAction;

  /// Spec key: nfcOff.on (12 §5.18) · Max: — · Notes: 03a · (a11y)
  ///
  /// In en, this message translates to:
  /// **'NFC is on. Ready to scan.'**
  String get nfcOffOn;

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
  /// **'The camera is restricted on this device. Use the card number.'**
  String get cameraRestrictedBody;

  /// Spec key: camera.unavailable.title (12 §5.18) · Max: 32 · Notes: 12 · P05
  ///
  /// In en, this message translates to:
  /// **'Camera not available'**
  String get cameraUnavailableTitle;

  /// Spec key: camera.unavailable.body (12 §5.18) · Max: 90 · Notes: 12
  ///
  /// In en, this message translates to:
  /// **'Close other apps using the camera or enter the card number.'**
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

  /// Spec key: intro.1.title.android (12 §5.19) · Max: 28 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Tap the card'**
  String get intro1TitleAndroid;

  /// Spec key: intro.1.body.android (12 §5.19) · Max: 90 · Notes: 03a · harmonised (brand guide: "unter einer Sekunde" instead of "sofort")
  ///
  /// In en, this message translates to:
  /// **'Hold the card to the back of the phone. The balance appears in under a second.'**
  String get intro1BodyAndroid;

  /// Spec key: intro.1.title.ios (12 §5.19) · Max: 32 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Tap Scan, then hold the card'**
  String get intro1TitleIos;

  /// Spec key: intro.1.body.ios (12 §5.19) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Tap \"Scan card\", then hold the card near the top of the iPhone.'**
  String get intro1BodyIos;

  /// Spec key: intro.1.title.noNfc (12 §5.19) · Max: 28 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code'**
  String get intro1TitleNoNfc;

  /// Spec key: intro.1.body.noNfc (12 §5.19) · Max: 90 · Notes: 03a
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code or type the card number.'**
  String get intro1BodyNoNfc;

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

  /// Spec key: a11y.spokenAmount (12 §5.20) · Politeness: — · Notes: 12 · cents omitted when 0; "{cents} Cent / cents / centi" when euros = 0 (§1.4)
  ///
  /// In en, this message translates to:
  /// **'{euros, plural, one {{euros} euro} other {{euros} euros}} {cents}'**
  String a11ySpokenAmount(int euros, String cents);

  /// Spec key: a11y.cardLoaded (12 §5.20) · Politeness: assertive · Notes: 12 · S07 opened; status appended if not active
  ///
  /// In en, this message translates to:
  /// **'{restaurant}. Balance {spokenAmount}.'**
  String a11yCardLoaded(String restaurant, String spokenAmount);

  /// Spec key: a11y.problem (12 §5.20) · Politeness: assertive · Notes: 12 · every S10/S15 screen and banner
  ///
  /// In en, this message translates to:
  /// **'{title}. {body}'**
  String a11yProblem(String title, String body);

  /// Spec key: a11y.ready (12 §5.20) · Politeness: polite · Notes: 12 · return to S05
  ///
  /// In en, this message translates to:
  /// **'Ready for the next card'**
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
