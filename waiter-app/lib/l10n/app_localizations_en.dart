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
  String get commonTapAgain => 'Tap card again';

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
      'E-mail or password is incorrect. After too many attempts, sign-in is paused for a few minutes.';

  @override
  String get signInErrorNoPermission =>
      'This account can\'t redeem vouchers. Please get a manager.';

  @override
  String signInErrorThrottled(String time) {
    return 'Too many attempts. Try again in $time.';
  }

  @override
  String signInRetryIn(String time) {
    return 'Try again in $time';
  }

  @override
  String get signInAvailable => 'You can sign in again';

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
  String get topBarRecent => 'Recent';

  @override
  String topBarMenu(String name) {
    return 'Menu, $name';
  }

  @override
  String get readyTitle => 'Scan the voucher';

  @override
  String get readyHint =>
      'Point the camera at the voucher\'s QR code – printed or on the guest\'s phone.';

  @override
  String get readyScan => 'Scan voucher';

  @override
  String get readyTapCard => 'Tap card';

  @override
  String get readySell => 'Sell voucher';

  @override
  String get readyPendingTitle => 'Redemption not confirmed yet';

  @override
  String readyPendingBody(String amount, String last4) {
    return '$amount on voucher •••• $last4. Checked automatically – nothing is ever booked twice.';
  }

  @override
  String readyPendingBooked(String amount) {
    return 'The unconfirmed redemption of $amount was booked.';
  }

  @override
  String readyPendingNotBooked(String amount) {
    return 'The unconfirmed redemption of $amount was not booked.';
  }

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
  String get scanDetected => 'Voucher detected';

  @override
  String get scanLookingUp => 'Checking voucher …';

  @override
  String get scanSlow => 'Still checking …';

  @override
  String get cardTitle => 'Tap card';

  @override
  String get cardWaiting => 'Hold the guest\'s card to the top of the phone.';

  @override
  String get cardChecking => 'Checking the card …';

  @override
  String get cardSlow => 'Still checking – keep the card on the phone.';

  @override
  String get cardDone => 'Card checked';

  @override
  String get cardFailed => 'The card could not be checked.';

  @override
  String get balanceCardOverline => 'Voucher';

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
    return 'Voucher $restaurant. Balance $spokenAmount. Voucher ending $last4.';
  }

  @override
  String chargeVoucherNumberA11y(String number) {
    return 'Voucher number $number';
  }

  @override
  String get a11yChargeClose => 'Close voucher';

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
  String get chargeVelocityTitle => 'Limit for this voucher reached';

  @override
  String chargeVelocityBodyTime(int minutes) {
    return 'Possible again in $minutes min. Or get a manager.';
  }

  @override
  String chargeRateLimited(int seconds) {
    return 'Too many requests – possible again in $seconds s';
  }

  @override
  String chargeDailyLimit(String amount) {
    return 'At most $amount more with this voucher today';
  }

  @override
  String get chargePresentmentExpired => 'Scan the voucher again to redeem.';

  @override
  String get chargePendingTitle => 'Checking an earlier redemption';

  @override
  String chargePendingBody(String amount) {
    return '$amount may already have been redeemed. Redeeming is possible once this is checked.';
  }

  @override
  String chargeEarlierBooked(String amount) {
    return 'The earlier redemption of $amount was booked. Balance updated.';
  }

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
  String get badgeUsedUp => 'Used up';

  @override
  String get badgeBlocked => 'Blocked';

  @override
  String get badgeExpired => 'Expired';

  @override
  String get voucherBlocked => 'Voucher blocked';

  @override
  String voucherBlockedReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get voucherExpired => 'Voucher expired';

  @override
  String voucherExpiredBody(String date) {
    return 'Expired on $date. Please get a manager.';
  }

  @override
  String get voucherEmpty => 'No balance left';

  @override
  String get voucherEmptyBody => 'This voucher has been fully used.';

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
      'Not confirmed yet. Check again – nothing is ever booked twice.';

  @override
  String get uncertainCancelled =>
      'Not confirmed. It is checked automatically before this voucher can be redeemed again.';

  @override
  String get uncertainCancelledGuestHint =>
      'Tell the guest: \"The redemption isn\'t confirmed yet. We\'ll check it before redeeming again.\"';

  @override
  String redeemBalanceChanged(String amount) {
    return 'Balance changed: now $amount';
  }

  @override
  String get successTitle => 'Redeemed';

  @override
  String successRemaining(String amount) {
    return 'Remaining balance $amount';
  }

  @override
  String get successEmpty => 'Voucher is now empty';

  @override
  String get successNext => 'Scan next voucher';

  @override
  String get successShowGuest => 'Show guest';

  @override
  String successCard(String last4) {
    return 'Voucher •••• $last4';
  }

  @override
  String get guestRemainingLabel => 'Remaining balance';

  @override
  String a11ySuccess(String amount, String balance) {
    return 'Redeemed $amount, remaining balance $balance';
  }

  @override
  String get problemNotRecognizedTitle => 'Not a voucher of this restaurant';

  @override
  String get problemNotRecognizedBody =>
      'This code is not valid here. Ask the guest for another voucher or get a manager.';

  @override
  String get problemCardNotRecognizedTitle => 'Card not accepted';

  @override
  String get problemCardNotRecognizedBody =>
      'This card could not be confirmed as a voucher of this restaurant. Get a manager.';

  @override
  String get problemCardNotUsableTitle => 'This card cannot pay';

  @override
  String get problemCardNotUsableNotActive => 'The card is not activated yet.';

  @override
  String get problemCardNotUsableSuspended =>
      'The card is temporarily blocked. A manager can help.';

  @override
  String get problemCardNotUsableInvalid =>
      'The card is no longer valid. A manager can help.';

  @override
  String get problemCardNotUsableOtherRestaurant =>
      'This card belongs to another restaurant.';

  @override
  String get problemCardMovedTitle => 'Card moved away';

  @override
  String get problemCardMovedBody =>
      'Hold the card still on the phone until it is checked.';

  @override
  String get problemNfcOffTitle => 'NFC is off';

  @override
  String get problemNfcOffBody =>
      'Switch on NFC in the phone\'s settings to read cards.';

  @override
  String get problemNfcUnsupportedTitle => 'This phone cannot read cards';

  @override
  String get problemNfcUnsupportedBody =>
      'Scan QR vouchers, or use a phone with NFC for cards.';

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
      'The voucher could not be checked. Check Wi-Fi or mobile data, then try again.';

  @override
  String get problemServerTitle => 'Service not available right now';

  @override
  String get problemServerBody =>
      'The problem is not the voucher. Try again in a moment.';

  @override
  String get saleTitle => 'Sell voucher';

  @override
  String get saleAmountLabel => 'Voucher value';

  @override
  String saleAmountRange(String min, String max) {
    return 'The value must be between $min and $max.';
  }

  @override
  String saleContinue(String amount) {
    return 'Continue · $amount';
  }

  @override
  String get salePaymentLabel => 'Paid with';

  @override
  String get salePaymentCash => 'Cash';

  @override
  String get salePaymentCardTerminal => 'Card terminal';

  @override
  String get salePaymentBankTransfer => 'Bank transfer';

  @override
  String get salePaymentComplimentary => 'Complimentary';

  @override
  String get saleReferenceLabel => 'Receipt or reference number';

  @override
  String get saleReferenceRequired => 'Enter the receipt or reference number.';

  @override
  String get saleReasonLabel => 'Reason';

  @override
  String get saleReasonRequired => 'Enter a reason (at least 3 characters).';

  @override
  String get saleEmailLabel => 'Guest e-mail (optional)';

  @override
  String get saleEmailHelper => 'The guest receives a confirmation.';

  @override
  String get saleEmailHelperNoMail => 'Saved with the voucher.';

  @override
  String get saleEmailInvalid => 'Enter a valid e-mail address.';

  @override
  String saleSubmit(String amount) {
    return 'Sell voucher · $amount';
  }

  @override
  String get saleSubmitting => 'Selling voucher …';

  @override
  String get saleFailedTitle => 'Voucher not sold';

  @override
  String get saleFailedBody =>
      'No voucher was sold. Check the connection and try again.';

  @override
  String get saleUncertainTitle => 'Sale not confirmed';

  @override
  String get saleUncertainBody =>
      'The answer did not arrive. Try again – the voucher will not be sold twice.';

  @override
  String get saleNotAllowedTitle => 'Not allowed';

  @override
  String get saleNotAllowedBody =>
      'This account cannot sell vouchers on this phone. Please get a manager.';

  @override
  String get saleDoneTitle => 'Voucher sold';

  @override
  String saleDoneValue(String amount) {
    return 'Value $amount';
  }

  @override
  String get saleDoneBody =>
      'Print the QR code for the guest. It is shown only now.';

  @override
  String get salePrint => 'Print voucher';

  @override
  String get salePrinted => 'Sent to the printer';

  @override
  String get salePrintFailed => 'Printing did not work. Try again.';

  @override
  String get saleAnother => 'Sell another voucher';

  @override
  String get saleLeaveTitle => 'Close without printing?';

  @override
  String get saleLeaveBody =>
      'The QR code cannot be shown again. Without it the guest cannot redeem the voucher.';

  @override
  String get saleLeaveConfirm => 'Close anyway';

  @override
  String get saleLeaveUncertainTitle => 'Sale open – close anyway?';

  @override
  String get saleLeaveUncertainBody =>
      'The voucher may already have been sold. Only “Try again” finds out without selling it twice.';

  @override
  String get saleNoQrTitle => 'Voucher already sold';

  @override
  String get saleNoQrBody =>
      'Its QR code can no longer be shown. If the guest has no printed voucher, block it in the dashboard and sell a new one.';

  @override
  String get saleQrA11y => 'QR code of the voucher';

  @override
  String get saleFormTitle => 'What are you selling?';

  @override
  String get saleFormPrintable => 'Printed voucher';

  @override
  String get saleFormPrintableCaption => 'With a QR code to print';

  @override
  String get saleFormCard => 'Gift card';

  @override
  String get saleFormCardCaption => 'A card from stock, activated at the sale';

  @override
  String saleCardSubmit(String amount) {
    return 'Tap card · $amount';
  }

  @override
  String get saleCardTap => 'Hold the card to the phone to activate it.';

  @override
  String get saleCardDoneTitle => 'Card activated';

  @override
  String saleCardDoneBody(String number) {
    return 'Card $number is active.';
  }

  @override
  String get saleCardFailedTitle => 'Card not activated';

  @override
  String get saleCardNotUsable =>
      'This card cannot be sold. Take another card from stock.';

  @override
  String get qrTitle => 'Scan voucher';

  @override
  String get qrHint => 'Point the camera at the voucher\'s QR code';

  @override
  String get qrNotVoucher => 'This QR code isn\'t a voucher';

  @override
  String get qrDark => 'Too dark? Turn on the light.';

  @override
  String get qrTorchOn => 'Turn on light';

  @override
  String get qrTorchOff => 'Turn off light';

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
  String get recentRowEmpty => 'Voucher now empty';

  @override
  String recentRowA11y(
    String time,
    String last4,
    String amount,
    String balance,
  ) {
    return '$time, voucher ending $last4, $amount redeemed, remaining balance $balance';
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
  String get recentDetailVoucher => 'Voucher';

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
  String get menuCards => 'Cards';

  @override
  String get menuCardsReceive => 'Confirm a delivery';

  @override
  String get menuCardsFind => 'Find a card';

  @override
  String get cardsReceiveNone => 'No delivery waiting.';

  @override
  String cardsReceiveBatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '$count card',
    );
    return '$_temp0';
  }

  @override
  String get cardsReceiveOnHold => 'Being checked – the count did not match.';

  @override
  String get cardsReceiveCount => 'How many cards are in the parcel?';

  @override
  String cardsReceiveContinue(int count) {
    return 'Continue with $count';
  }

  @override
  String get cardsReceiveTap => 'Hold one card from the parcel to the phone.';

  @override
  String get cardsReceiveDone =>
      'Delivery confirmed – the cards are ready to sell.';

  @override
  String get cardsReceiveHold =>
      'The count does not match. GiftCard Pro checks the delivery.';

  @override
  String get cardsReceiveWrongCard => 'This card is not from this delivery.';

  @override
  String get cardsFindLabel => 'Card number';

  @override
  String get cardsFindHelper =>
      'Shown with the voucher in the dashboard, e.g. B-2026-0001-0042';

  @override
  String get cardsFindAction => 'Look up';

  @override
  String get cardsFindNotFound => 'No card with this number.';

  @override
  String get cardsStateActive => 'Active';

  @override
  String get cardsStateSuspended => 'Suspended';

  @override
  String get cardsStateReplaced => 'Replaced';

  @override
  String get cardsStateAvailable => 'In stock';

  @override
  String get cardsStateOther => 'Not in use';

  @override
  String cardsBalance(String amount) {
    return 'Balance $amount';
  }

  @override
  String get cardsSuspend => 'Suspend card';

  @override
  String get cardsResume => 'Resume card';

  @override
  String get cardsReplace => 'Replace card';

  @override
  String get cardsReasonTitle => 'Reason';

  @override
  String get cardsReasonLost => 'Lost';

  @override
  String get cardsReasonStolen => 'Stolen';

  @override
  String get cardsReasonDamaged => 'Damaged';

  @override
  String get cardsReasonFound => 'Found again';

  @override
  String get cardsReplaceTap =>
      'Hold a new card from stock to the phone. The balance moves to it.';

  @override
  String get cardsReplaceTapOld => 'Hold the guest\'s old card to the phone.';

  @override
  String get cardsReplaceOwnerOnly =>
      'Only the owner can replace a lost or stolen card. Suspend it now so it stops paying.';

  @override
  String cardsReplaceDone(String number) {
    return 'Replaced by $number. The old card no longer works.';
  }

  @override
  String get cardsSuspendDone => 'Suspended – the card no longer pays.';

  @override
  String get cardsResumeDone => 'Resumed – the card pays again.';

  @override
  String get cardsFailed => 'That did not work. Try again.';

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
      'This account can no longer redeem vouchers. Please get a manager.';

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
  String get cameraDeniedTitle => 'Camera access is off';

  @override
  String get cameraDeniedBody =>
      'Allow camera access in Settings to scan QR codes.';

  @override
  String get cameraDeniedAction => 'Open Settings';

  @override
  String get cameraRestrictedBody =>
      'The camera is restricted on this device. Please get a manager.';

  @override
  String get cameraUnavailableTitle => 'Camera not available';

  @override
  String get cameraUnavailableBody =>
      'Close other apps using the camera, then try again.';

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
  String get intro1Title => 'Scan the voucher';

  @override
  String get intro1Body =>
      'Point the camera at the QR code. The balance appears right away.';

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
  String get stationTitle => 'Personalise cards';

  @override
  String get stationChoose => 'Choose a batch';

  @override
  String get stationEmpty => 'No batch is waiting for personalisation.';

  @override
  String stationBatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards done',
      one: '$count card done',
    );
    return '$_temp0';
  }

  @override
  String get stationWaiting => 'Hold a blank card to the phone.';

  @override
  String get stationWorking => 'Personalising – keep the card still.';

  @override
  String stationDone(String number) {
    return 'Card $number done';
  }

  @override
  String get stationFailed => 'Card not finished. Hold it again.';

  @override
  String get stationRejected =>
      'Card is not from this batch or is already done.';

  @override
  String get stationUnknownChip => 'Unknown card – set it aside.';

  @override
  String get stationFinish => 'Finish batch';

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
  String a11yVoucherLoaded(String restaurant, String spokenAmount) {
    return '$restaurant. Balance $spokenAmount.';
  }

  @override
  String a11yProblem(String title, String body) {
    return '$title. $body';
  }

  @override
  String get a11yReady => 'Ready for the next voucher';

  @override
  String get a11yScanAvailable => 'Scanning available again';

  @override
  String get a11yRedeemAvailable => 'Redeem available again';
}
