// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'GiftCard Waiter';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonDone => 'Done';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonScanAgain => 'Scan again';

  @override
  String get commonEnterNumber => 'Enter card number';

  @override
  String get commonEditNumber => 'Edit number';

  @override
  String get commonOpenSettings => 'Open Settings';

  @override
  String get commonBackToSignIn => 'Back to sign in';

  @override
  String get commonCheckAgain => 'Check again';

  @override
  String commonSupportCode(String code) {
    return 'Code $code';
  }

  @override
  String commonSupportCodeA11y(String code) {
    return 'Support code $code';
  }

  @override
  String get commonCopied => 'Copied';

  @override
  String get redeemNothingBooked => 'Nothing was booked.';

  @override
  String get getManager => 'Please get a manager';

  @override
  String get splashLoading => 'Loading';

  @override
  String get startupOfflineTitle => 'No internet connection';

  @override
  String get startupOfflineBody =>
      'This phone is offline. Turn on Wi-Fi or mobile data, then try again.';

  @override
  String get startupHostNotFoundTitle => 'Server not found';

  @override
  String startupHostNotFoundBody(String host) {
    return 'The address $host does not exist. Check the server address.';
  }

  @override
  String get startupRefusedTitle => 'Server not running';

  @override
  String startupRefusedBody(String host) {
    return 'Nothing answers at $host. Check that the server is running and the address is right.';
  }

  @override
  String get startupTimeoutTitle => 'Server not responding';

  @override
  String startupTimeoutBody(String host) {
    return '$host did not answer in time. Check the network, then try again.';
  }

  @override
  String get startupTlsTitle => 'No secure connection';

  @override
  String startupTlsBody(String host) {
    return 'The certificate of $host was rejected. Check the phone\'s date and time.';
  }

  @override
  String get startupServerErrorTitle => 'Server problem';

  @override
  String startupServerErrorBody(String host, String status) {
    return '$host reports a problem (status $status). Try again later.';
  }

  @override
  String get startupInvalidResponseTitle => 'Wrong server address';

  @override
  String startupInvalidResponseBody(String host) {
    return '$host is not a GiftCard Pro server. Check the server address.';
  }

  @override
  String get startupConfigurationTitle => 'App not set up correctly';

  @override
  String get startupConfigurationBody =>
      'This version of the app has no valid server address. Please get a manager.';

  @override
  String get startupStorageTitle => 'Protected storage unavailable';

  @override
  String get startupStorageBody =>
      'The app cannot open its protected storage. Restart the phone, then try again.';

  @override
  String get startupUnknownTitle => 'The app could not start';

  @override
  String get startupUnknownBody =>
      'Try again. If it happens again, please get a manager.';

  @override
  String startupServer(String url) {
    return 'Server: $url';
  }

  @override
  String startupDetail(String detail) {
    return 'Details: $detail';
  }

  @override
  String startupEnvironment(String name) {
    return 'Environment: $name';
  }

  @override
  String get startupChangeServer => 'Change server';

  @override
  String get envDevelopment => 'Development';

  @override
  String get envStaging => 'Staging';

  @override
  String get envProduction => 'Production';

  @override
  String get envBadgeDevelopment => 'DEV';

  @override
  String get envBadgeStaging => 'STAGING';

  @override
  String envBadgeA11y(String name, String host) {
    return 'Test environment $name, server $host. Long-press to change the server.';
  }

  @override
  String get serverTitle => 'Server address';

  @override
  String get serverLabel => 'API address';

  @override
  String get serverHelp =>
      'For example http://192.168.1.20:8000 (/api/v1 is added).';

  @override
  String serverDefault(String url) {
    return 'Default of this app: $url';
  }

  @override
  String get serverSave => 'Save and connect';

  @override
  String get serverReset => 'Use default';

  @override
  String get serverInvalid =>
      'Not a valid address. Start with http:// or https://.';

  @override
  String get serverHttpsRequired => 'This version only allows https addresses.';

  @override
  String get serverWrongPath => 'The address must end in /api/v1.';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInSubtitle => 'Use your staff account';

  @override
  String get signInEmailLabel => 'E-mail';

  @override
  String get signInEmailPlaceholder => 'name@example.com';

  @override
  String get signInPasswordLabel => 'Password';

  @override
  String get signInPasswordShow => 'Show password';

  @override
  String get signInPasswordHide => 'Hide password';

  @override
  String get signInForgot => 'Forgot password';

  @override
  String get signInSubmit => 'Sign in';

  @override
  String get signInLoading => 'Signing in';

  @override
  String get signInNoAccess =>
      'No login? A manager creates it in the dashboard.';

  @override
  String get signInErrorRequired => 'Required';

  @override
  String get signInErrorEmailFormat => 'Check the e-mail address';

  @override
  String get signInErrorInvalid =>
      'E-mail or password is incorrect. Check both and try again.';

  @override
  String get signInErrorNoPermission =>
      'This account can\'t redeem cards. Please get a manager.';

  @override
  String signInErrorThrottled(String time) {
    return 'Too many attempts. Try again in $time.';
  }

  @override
  String get signInErrorServer =>
      'Can\'t sign in right now. Try again in a moment.';

  @override
  String get signInOfflineBody => 'Signing in needs a connection.';

  @override
  String get biometricsTitleFaceId => 'Unlock with Face ID?';

  @override
  String get biometricsTitleTouchId => 'Unlock with Touch ID?';

  @override
  String get biometricsTitleAndroid => 'Unlock with biometrics?';

  @override
  String get biometricsBody =>
      'A faster start to every shift. Your password still works as a fallback.';

  @override
  String get biometricsEnableFaceId => 'Use Face ID';

  @override
  String get biometricsEnableTouchId => 'Use Touch ID';

  @override
  String get biometricsEnableAndroid => 'Use biometrics';

  @override
  String get biometricsNotNow => 'Not now';

  @override
  String get biometricsReason => 'To unlock GiftCard Waiter';

  @override
  String biometricsPromptSubtitleAndroid(String restaurant) {
    return 'For service at $restaurant';
  }

  @override
  String get biometricsFailed => 'Not confirmed. Try again.';

  @override
  String get biometricsNotEnrolledFaceId =>
      'Face ID is not set up. Set it up in Settings.';

  @override
  String get biometricsNotEnrolledTouchId =>
      'Touch ID is not set up. Set it up in Settings.';

  @override
  String get biometricsNotEnrolledAndroid =>
      'No biometrics set up. Set them up in Settings.';

  @override
  String get unlockButtonFaceId => 'Unlock with Face ID';

  @override
  String get unlockButtonTouchId => 'Unlock with Touch ID';

  @override
  String get unlockButtonAndroid => 'Unlock';

  @override
  String get unlockUsePassword => 'Use password';

  @override
  String get unlockChanged =>
      'Biometrics changed on this device. Sign in with your password.';

  @override
  String get unlockLockedOut => 'Too many attempts. Use the password.';

  @override
  String get unlockPendingCard => 'The card opens after unlocking.';

  @override
  String get topBarRecent => 'Recent';

  @override
  String topBarMenu(String name) {
    return 'Menu, $name';
  }

  @override
  String get readyAndroidTitle => 'Hold the card to the phone';

  @override
  String get readyAndroidHint => 'The card is detected automatically';

  @override
  String get readyIosButton => 'Scan card';

  @override
  String get readyIosHint =>
      'After tapping, hold the card near the top of the iPhone';

  @override
  String get readyIosTimeout =>
      'No card detected. Tap \"Scan card\" to try again.';

  @override
  String get readyManual => 'Card number';

  @override
  String get readyQr => 'QR code';

  @override
  String get readyFirstCardTipAndroid =>
      'Tip: the NFC antenna is usually at the top of the back, near the camera.';

  @override
  String get readyFirstCardTipIos =>
      'Tip: hold the card flat against the top edge, near the camera.';

  @override
  String get readyNoNfcTitle => 'Scan the QR code on the card';

  @override
  String get readyNoNfcHint =>
      'This device has no NFC. Use the QR code or the card number.';

  @override
  String get readyNoNfcButton => 'Scan QR code';

  @override
  String get readyOfflineTap => 'No connection – the card can\'t be checked';

  @override
  String get readyOnline => 'Connected again';

  @override
  String get offlineTitle => 'No connection';

  @override
  String get offlineBody =>
      'Redeeming needs a connection so nothing is ever booked twice.';

  @override
  String get maintenanceDefault =>
      'Scheduled maintenance: redeeming may be briefly unavailable.';

  @override
  String get maintenanceDismiss => 'Dismiss notice';

  @override
  String get readyNewCard => 'New gift card';

  @override
  String get issueTitle => 'New gift card';

  @override
  String get issueAmountLabel => 'Card value';

  @override
  String get issueEmailLabel => 'Guest e-mail (optional)';

  @override
  String get issueEmailHelper => 'The guest receives a confirmation.';

  @override
  String get issueEmailInvalid => 'Enter a valid e-mail address.';

  @override
  String issueAmountRange(String min, String max) {
    return 'The card value must be between $min and $max.';
  }

  @override
  String issueCreate(String amount) {
    return 'Create card · $amount';
  }

  @override
  String get issueCreating => 'Creating card …';

  @override
  String get issueProgramTitle => 'Hold a blank card to the phone';

  @override
  String get issueProgramBody =>
      'Keep it still on the back of the phone until the check mark appears.';

  @override
  String get issueProgramRetap =>
      'Lift the card and hold it to the phone again.';

  @override
  String get issueStepCheck => 'Check tag';

  @override
  String get issueStepWrite => 'Write card link';

  @override
  String get issueStepVerify => 'Read back and verify';

  @override
  String get issueStepSave => 'Save chip to card';

  @override
  String issueCard(String number) {
    return 'Card $number';
  }

  @override
  String get issueSuccessTitle => 'Card ready';

  @override
  String issueSuccessBalance(String amount) {
    return 'Balance $amount';
  }

  @override
  String get issueSuccessVerified => 'NFC tag written and verified';

  @override
  String get issueSuccessNoTag =>
      'No tag yet. Program it later in the dashboard.';

  @override
  String get issueSuccessAnother => 'Sell another card';

  @override
  String get issueLater => 'Program later';

  @override
  String get issueNfcOff => 'Turn on NFC to program the tag.';

  @override
  String get issueCreateFailedTitle => 'Card not created';

  @override
  String get issueCreateFailedBody =>
      'No card was created. Check the connection and try again.';

  @override
  String get issueCreateUncertainBody =>
      'The answer did not arrive. Try again, the card will not be created twice.';

  @override
  String get issueNotAllowedTitle => 'Not allowed';

  @override
  String get issueNotAllowedBody =>
      'This account cannot sell cards on this phone. Sign out and in again, or use the dashboard.';

  @override
  String get issueTagFailedTitle => 'Tag not programmed';

  @override
  String issueTagOtherCard(String number) {
    return 'This tag belongs to card $number. Use a blank tag.';
  }

  @override
  String get issueTagRefused =>
      'This tag cannot be used for this card. Use a blank tag.';

  @override
  String get issueTagUnsupported =>
      'This tag type is not supported. Use NTAG213, 215 or 216.';

  @override
  String get issueTagReadOnly => 'This tag is locked and cannot be written.';

  @override
  String get issueTagMoved =>
      'The tag moved away. Hold it still and try again.';

  @override
  String get issueTagVerifyFailed =>
      'The tag could not be verified. Try again with the same tag.';

  @override
  String get issueTagNetwork => 'No connection to the server. Try again.';

  @override
  String get iosSheetAlert => 'Hold the card near the top of the iPhone';

  @override
  String get iosSheetFound => 'Card found';

  @override
  String get iosSheetReadFailed => 'Couldn\'t read the card. Try again.';

  @override
  String get iosSheetMultiple => 'More than one card detected. Hold only one.';

  @override
  String get iosSheetTimeoutSoon =>
      'No card yet. Hold it flat near the top of the iPhone.';

  @override
  String get scanNotCard => 'This is not a gift card';

  @override
  String get scanReadFailedTitle => 'Couldn\'t read the card';

  @override
  String get scanReadFailedBody => 'Hold it still for a second.';

  @override
  String get scanDetected => 'Card detected';

  @override
  String get scanLookingUp => 'Looking up card …';

  @override
  String get scanSlow => 'Still looking …';

  @override
  String get scanUnavailable =>
      'NFC isn\'t available right now. Use the card number or QR code.';

  @override
  String get balanceCardOverline => 'Gift card';

  @override
  String balanceCardValidUntil(String date) {
    return 'Valid until $date';
  }

  @override
  String get balanceCardNoExpiry => 'No expiry date';

  @override
  String balanceCardMasked(String last4) {
    return '•••• $last4';
  }

  @override
  String balanceCardA11y(String restaurant, String spokenAmount, String last4) {
    return 'Gift card $restaurant. Balance $spokenAmount. Card ending $last4.';
  }

  @override
  String chargeCardNumberA11y(String number) {
    return 'Card number $number';
  }

  @override
  String get a11yChargeClose => 'Close card';

  @override
  String a11yAmount(String spokenAmount) {
    return 'Amount $spokenAmount';
  }

  @override
  String get chargeEnterAmount => 'Enter amount';

  @override
  String chargeRedeem(String amount) {
    return 'Redeem $amount';
  }

  @override
  String chargeRedeemFull(String amount) {
    return 'Redeem full balance · $amount';
  }

  @override
  String get chargeHold => 'Hold to redeem';

  @override
  String get a11yHoldHint => 'Double-tap and hold to redeem';

  @override
  String chargeRedeeming(String amount) {
    return 'Redeeming $amount …';
  }

  @override
  String chargeOverBalance(String diff) {
    return '$diff more than the balance';
  }

  @override
  String a11yOverBalance(String diff) {
    return '$diff more than the balance. Redeem not available.';
  }

  @override
  String chargeUseBalance(String amount) {
    return 'Use balance · $amount';
  }

  @override
  String chargeUseMax(String amount) {
    return 'Use maximum · $amount';
  }

  @override
  String chargeMaxSingle(String amount) {
    return 'Max. $amount per redemption';
  }

  @override
  String get chargeFullOnly => 'Only the full balance can be redeemed here.';

  @override
  String get chargeVelocityTitle => 'Limit for this card reached';

  @override
  String chargeVelocityBodyTime(int minutes) {
    return 'Possible again in $minutes min. Or get a manager.';
  }

  @override
  String chargeRateLimited(int seconds) {
    return 'Too many requests – possible again in $seconds s';
  }

  @override
  String get chargeSwitchCardMessage => 'Different card detected – Switch?';

  @override
  String get chargeSwitchCardAction => 'Switch';

  @override
  String get chargeSwitchCardKeep => 'Keep';

  @override
  String get chargeSwitchCardDialogTitle => 'Different card detected';

  @override
  String get keypadDoubleZero => 'Double zero';

  @override
  String get keypadDelete => 'Delete';

  @override
  String get keypadDeleteHint => 'Long press to clear';

  @override
  String get keypadCleared => 'Amount cleared';

  @override
  String get keypadMaxReached => 'Maximum amount reached';

  @override
  String get badgeActive => 'Active';

  @override
  String get badgeInactive => 'Not activated';

  @override
  String get badgeRedeemed => 'Used up';

  @override
  String get badgeBlocked => 'Blocked';

  @override
  String get badgeExpired => 'Expired';

  @override
  String get badgeReplaced => 'Replaced';

  @override
  String get cardBlocked => 'Card blocked';

  @override
  String cardBlockedReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get cardExpired => 'Card expired';

  @override
  String cardExpiredBody(String date) {
    return 'Expired on $date. Please get a manager.';
  }

  @override
  String get cardInactive => 'Card not activated yet';

  @override
  String get cardInactiveBody =>
      'It can be redeemed once activated. Please get a manager.';

  @override
  String get cardReplaced => 'Card was replaced';

  @override
  String get cardReplacedBody =>
      'The balance is on the new card. Ask the guest for the new card.';

  @override
  String get cardEmpty => 'No balance left';

  @override
  String get cardEmptyBody => 'This card has been fully used.';

  @override
  String get redeemSlow => 'Connection slow – retrying';

  @override
  String get uncertainTitle => 'Connection interrupted';

  @override
  String get uncertainBody => 'Checking … Nothing is ever booked twice.';

  @override
  String uncertainRetrying(int n) {
    return 'Attempt $n of 3';
  }

  @override
  String get uncertainGuestHint =>
      'Tell the guest: \"One moment please, the redemption is being confirmed.\"';

  @override
  String get uncertainFailedBody =>
      'Not confirmed yet. Try again – nothing is ever booked twice.';

  @override
  String get uncertainCancelled =>
      'Not confirmed. Scan the card again before redeeming.';

  @override
  String get uncertainCancelledGuestHint =>
      'Tell the guest: \"The redemption isn\'t confirmed yet. We\'ll check the balance before redeeming again.\"';

  @override
  String redeemBalanceChanged(String amount) {
    return 'Balance changed: now $amount';
  }

  @override
  String get redeemTapAgain => 'Please tap Redeem again.';

  @override
  String get successTitle => 'Redeemed';

  @override
  String successRemaining(String amount) {
    return 'Remaining balance $amount';
  }

  @override
  String get successEmpty => 'Card is now empty';

  @override
  String get successNextIos => 'Scan next card';

  @override
  String get successNextAndroid => 'Just tap the next card';

  @override
  String get successShowGuest => 'Show guest';

  @override
  String successCard(String last4) {
    return 'Card •••• $last4';
  }

  @override
  String get guestRemainingLabel => 'Remaining balance';

  @override
  String a11ySuccess(String amount, String balance) {
    return 'Redeemed $amount, remaining balance $balance';
  }

  @override
  String get problemNotFoundTitle => 'Card not found';

  @override
  String get problemNotFoundBody =>
      'This card is not in the system. Check the card or ask the guest for another one.';

  @override
  String get problemNotFoundBodyManual =>
      'No card with this number. Check the digits.';

  @override
  String get problemForeignTitle => 'Card from another restaurant';

  @override
  String get problemForeignBody =>
      'It can only be redeemed at the restaurant that issued it.';

  @override
  String get problemVerifyTitle => 'Card could not be verified';

  @override
  String get problemVerifyBody =>
      'Do not accept this card for now. Please get a manager.';

  @override
  String get problemThrottledTitle => 'Too many scans';

  @override
  String get problemThrottledBody => 'Scanning is possible again shortly.';

  @override
  String problemScanAgainIn(String time) {
    return 'Scan again · $time';
  }

  @override
  String get problemNetworkBody =>
      'The card could not be checked. Check Wi-Fi or mobile data, then try again.';

  @override
  String get problemServerTitle => 'Service not available right now';

  @override
  String get problemServerBody =>
      'The problem is not the card. Try again in a moment.';

  @override
  String get manualTitle => 'Card number';

  @override
  String get manualHelper => '16 digits on the back of the card';

  @override
  String manualCounter(int count) {
    return '$count of 16';
  }

  @override
  String get manualSubmit => 'Look up card';

  @override
  String get manualErrorInvalid => 'Check the card number';

  @override
  String get manualErrorPaste => 'No valid card number to paste';

  @override
  String get qrTitle => 'Scan QR code';

  @override
  String get qrHint => 'Point the camera at the QR code on the card';

  @override
  String get qrNotCard => 'This QR code isn\'t a gift card';

  @override
  String get qrDark => 'Too dark? Turn on the light.';

  @override
  String get qrTorchOn => 'Turn on light';

  @override
  String get qrTorchOff => 'Turn off light';

  @override
  String get qrManual => 'Enter card number';

  @override
  String get recentTitle => 'Recent';

  @override
  String recentSummary(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count redemptions',
      one: '$count redemption',
    );
    return '$_temp0 · $amount today';
  }

  @override
  String recentRowRemaining(String amount) {
    return 'Left $amount';
  }

  @override
  String get recentRowEmpty => 'Card now empty';

  @override
  String recentRowA11y(
    String time,
    String last4,
    String amount,
    String balance,
  ) {
    return '$time, card ending $last4, $amount redeemed, remaining balance $balance';
  }

  @override
  String get recentEmptyTitle => 'No redemptions yet';

  @override
  String get recentEmptyBody =>
      'Redemptions from this phone appear here until 04:00.';

  @override
  String get recentFooter => 'This phone only · cleared at 04:00';

  @override
  String get recentLimit => 'Latest 200 redemptions';

  @override
  String get recentDetailTitle => 'Redemption';

  @override
  String get recentDetailTime => 'Time';

  @override
  String get recentDetailCard => 'Card';

  @override
  String get recentDetailAmount => 'Amount';

  @override
  String get recentDetailRemaining => 'Remaining balance';

  @override
  String get recentDetailTransaction => 'Transaction';

  @override
  String get recentDetailSupportCode => 'Support code';

  @override
  String get recentDetailReverseHint =>
      'Wrong amount? A manager can reverse it in the dashboard.';

  @override
  String get menuClose => 'Close menu';

  @override
  String get menuAccount => 'Account';

  @override
  String get menuRestaurant => 'Restaurant';

  @override
  String get menuDevice => 'Device';

  @override
  String get menuSectionSettings => 'Settings';

  @override
  String get menuTheme => 'Appearance';

  @override
  String get menuThemeSystem => 'Match system';

  @override
  String get menuThemeLight => 'Light';

  @override
  String get menuThemeDark => 'Dark';

  @override
  String get menuSunlightTip => 'Outdoors, the light theme is easier to read.';

  @override
  String get menuSound => 'Sounds';

  @override
  String get menuHaptics => 'Haptics';

  @override
  String get menuHapticsUnavailable => 'Not available on this device';

  @override
  String get menuKeepScreenOn => 'Keep screen on';

  @override
  String get menuKeepScreenOnCaption => 'While scanning and redeeming';

  @override
  String get menuHelp => 'Help';

  @override
  String menuVersion(String version) {
    return 'Version $version';
  }

  @override
  String get menuSignOut => 'Sign out';

  @override
  String get menuSignOutConfirmTitle => 'Sign out?';

  @override
  String get menuSignOutConfirmBody =>
      'The shift history on this device will be deleted.';

  @override
  String get menuSignOutConfirmAction => 'Sign out';

  @override
  String get sessionExpired => 'Session expired';

  @override
  String get sessionExpiredBody => 'Sign in again to continue.';

  @override
  String get sessionExpiredAction => 'Sign in again';

  @override
  String get forbiddenTitle => 'No permission to redeem';

  @override
  String get forbiddenBody =>
      'This account can no longer redeem cards. Please get a manager.';

  @override
  String get deviceRevokedTitle => 'This device was removed';

  @override
  String get deviceRevokedBody =>
      'It\'s no longer allowed for this restaurant. Please get a manager.';

  @override
  String get deviceRevokedAction => 'Sign in';

  @override
  String get suspendedTitle => 'Redeeming is paused';

  @override
  String get suspendedBody =>
      'The restaurant\'s account is paused. Please get a manager.';

  @override
  String get lockedTitle => 'Account temporarily locked';

  @override
  String lockedBody(String time) {
    return 'Too many sign-in attempts. Try again in $time.';
  }

  @override
  String lockedButton(String time) {
    return 'Try again in $time';
  }

  @override
  String get lockedOver => 'You can sign in again';

  @override
  String get deactivatedTitle => 'Account deactivated';

  @override
  String get deactivatedBody =>
      'This account can no longer be used. Please get a manager.';

  @override
  String get updateTitle => 'Update required';

  @override
  String get updateBody =>
      'This version is no longer supported. Update to keep redeeming.';

  @override
  String get updateAction => 'Update now';

  @override
  String get nfcOffTitle => 'NFC is off';

  @override
  String get nfcOffBody => 'Turn on NFC to scan cards.';

  @override
  String get nfcOffAction => 'Turn on NFC';

  @override
  String get nfcOffOn => 'NFC is on. Ready to scan.';

  @override
  String get cameraDeniedTitle => 'Camera access is off';

  @override
  String get cameraDeniedBody =>
      'Allow camera access in Settings to scan QR codes.';

  @override
  String get cameraDeniedAction => 'Open Settings';

  @override
  String get cameraRestrictedBody =>
      'The camera is restricted on this device. Use the card number.';

  @override
  String get cameraUnavailableTitle => 'Camera not available';

  @override
  String get cameraUnavailableBody =>
      'Close other apps using the camera or enter the card number.';

  @override
  String get introSkip => 'Skip';

  @override
  String get introNext => 'Next';

  @override
  String get introStart => 'Start';

  @override
  String introPage(int n) {
    return 'Page $n of 3';
  }

  @override
  String get intro1TitleAndroid => 'Tap the card';

  @override
  String get intro1BodyAndroid =>
      'Hold the card to the back of the phone. The balance appears in under a second.';

  @override
  String get intro1TitleIos => 'Tap Scan, then hold the card';

  @override
  String get intro1BodyIos =>
      'Tap \"Scan card\", then hold the card near the top of the iPhone.';

  @override
  String get intro1TitleNoNfc => 'Scan the QR code';

  @override
  String get intro1BodyNoNfc =>
      'Point the camera at the QR code or type the card number.';

  @override
  String get intro2Title => 'Type the amount, redeem';

  @override
  String intro2Body(String threshold) {
    return 'See the balance, type the amount, done. From $threshold, press and hold to confirm.';
  }

  @override
  String get intro3Title => 'Never booked twice';

  @override
  String get intro3Body =>
      'Redeeming only works online. Your shift\'s redemptions are under \"Recent\".';

  @override
  String a11ySpokenAmount(int euros, String cents) {
    String _temp0 = intl.Intl.pluralLogic(
      euros,
      locale: localeName,
      other: '$euros euros',
      one: '$euros euro',
    );
    return '$_temp0 $cents';
  }

  @override
  String a11yCardLoaded(String restaurant, String spokenAmount) {
    return '$restaurant. Balance $spokenAmount.';
  }

  @override
  String a11yProblem(String title, String body) {
    return '$title. $body';
  }

  @override
  String get a11yReady => 'Ready for the next card';

  @override
  String get a11yScanAvailable => 'Scanning available again';

  @override
  String get a11yRedeemAvailable => 'Redeem available again';
}
