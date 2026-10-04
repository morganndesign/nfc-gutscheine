// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'GiftCard Waiter';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonTryAgain => 'Erneut versuchen';

  @override
  String get commonScanAgain => 'Erneut scannen';

  @override
  String get commonTapAgain => 'Karte erneut halten';

  @override
  String get commonOpenSettings => 'Einstellungen öffnen';

  @override
  String get commonBackToSignIn => 'Zur Anmeldung';

  @override
  String get commonCheckAgain => 'Erneut prüfen';

  @override
  String commonSupportCode(String code) {
    return 'Code $code';
  }

  @override
  String commonSupportCodeA11y(String code) {
    return 'Support-Code $code';
  }

  @override
  String get commonCopied => 'Kopiert';

  @override
  String get redeemNothingBooked => 'Es wurde nichts gebucht.';

  @override
  String get getManager => 'Bitte Betriebsleitung holen';

  @override
  String get splashLoading => 'Wird geladen';

  @override
  String get startupOfflineTitle => 'Keine Internetverbindung';

  @override
  String get startupOfflineBody =>
      'Das Handy ist offline. WLAN oder mobile Daten einschalten, dann erneut versuchen.';

  @override
  String get startupHostNotFoundTitle => 'Server nicht gefunden';

  @override
  String startupHostNotFoundBody(String host) {
    return 'Die Adresse $host existiert nicht. Server-Adresse prüfen.';
  }

  @override
  String get startupRefusedTitle => 'Server nicht gestartet';

  @override
  String startupRefusedBody(String host) {
    return 'Unter $host antwortet kein Server. Prüfen, ob er läuft und die Adresse stimmt.';
  }

  @override
  String get startupTimeoutTitle => 'Server antwortet nicht';

  @override
  String startupTimeoutBody(String host) {
    return '$host hat nicht rechtzeitig geantwortet. Netzwerk prüfen, dann erneut versuchen.';
  }

  @override
  String get startupTlsTitle => 'Keine sichere Verbindung';

  @override
  String startupTlsBody(String host) {
    return 'Das Zertifikat von $host wurde abgelehnt. Datum und Uhrzeit am Handy prüfen.';
  }

  @override
  String get startupServerErrorTitle => 'Server gestört';

  @override
  String startupServerErrorBody(String host, String status) {
    return '$host meldet ein Problem (Status $status). Später erneut versuchen.';
  }

  @override
  String get startupInvalidResponseTitle => 'Falsche Server-Adresse';

  @override
  String startupInvalidResponseBody(String host) {
    return 'Unter $host läuft kein GiftCard-Pro-Server. Server-Adresse prüfen.';
  }

  @override
  String get startupConfigurationTitle => 'App falsch eingerichtet';

  @override
  String get startupConfigurationBody =>
      'Diese App-Version hat keine gültige Server-Adresse. Bitte Betriebsleitung holen.';

  @override
  String get startupStorageTitle => 'Geschützter Speicher gesperrt';

  @override
  String get startupStorageBody =>
      'Die App kann ihren geschützten Speicher nicht öffnen. Handy neu starten, dann erneut versuchen.';

  @override
  String get startupUnknownTitle => 'App konnte nicht starten';

  @override
  String get startupUnknownBody =>
      'Erneut versuchen. Passiert es wieder, bitte Betriebsleitung holen.';

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
    return 'Umgebung: $name';
  }

  @override
  String get startupChangeServer => 'Server ändern';

  @override
  String get envDevelopment => 'Entwicklung';

  @override
  String get envStaging => 'Staging';

  @override
  String get envProduction => 'Produktion';

  @override
  String get envBadgeDevelopment => 'DEV';

  @override
  String get envBadgeStaging => 'STAGING';

  @override
  String envBadgeA11y(String name, String host) {
    return 'Testumgebung $name, Server $host. Lange drücken, um den Server zu ändern.';
  }

  @override
  String get serverTitle => 'Server-Adresse';

  @override
  String get serverLabel => 'API-Adresse';

  @override
  String get serverHelp =>
      'Zum Beispiel http://192.168.1.20:8000 (/api/v1 wird ergänzt).';

  @override
  String serverDefault(String url) {
    return 'Standard dieser App: $url';
  }

  @override
  String get serverSave => 'Speichern und verbinden';

  @override
  String get serverReset => 'Standard verwenden';

  @override
  String get serverInvalid =>
      'Keine gültige Adresse. Mit http:// oder https:// beginnen.';

  @override
  String get serverHttpsRequired =>
      'In dieser Version sind nur https-Adressen erlaubt.';

  @override
  String get serverWrongPath => 'Die Adresse muss auf /api/v1 enden.';

  @override
  String get signInTitle => 'Anmelden';

  @override
  String get signInSubtitle => 'Mit dem Mitarbeiterkonto anmelden';

  @override
  String get signInEmailLabel => 'E-Mail';

  @override
  String get signInEmailPlaceholder => 'name@beispiel.at';

  @override
  String get signInPasswordLabel => 'Passwort';

  @override
  String get signInPasswordShow => 'Passwort anzeigen';

  @override
  String get signInPasswordHide => 'Passwort verbergen';

  @override
  String get signInForgot => 'Passwort vergessen';

  @override
  String get signInSubmit => 'Anmelden';

  @override
  String get signInLoading => 'Anmeldung läuft';

  @override
  String get signInNoAccess =>
      'Kein Zugang? Die Betriebsleitung legt ihn im Dashboard an.';

  @override
  String get signInErrorRequired => 'Pflichtfeld';

  @override
  String get signInErrorEmailFormat => 'E-Mail-Adresse prüfen';

  @override
  String get signInErrorInvalid =>
      'E-Mail oder Passwort ist falsch. Nach zu vielen Versuchen ist die Anmeldung einige Minuten gesperrt.';

  @override
  String get signInErrorNoPermission =>
      'Dieses Konto kann keine Gutscheine einlösen. Bitte Betriebsleitung holen.';

  @override
  String signInErrorThrottled(String time) {
    return 'Zu viele Versuche. Erneut möglich in $time.';
  }

  @override
  String signInRetryIn(String time) {
    return 'Erneut in $time';
  }

  @override
  String get signInAvailable => 'Anmelden ist wieder möglich';

  @override
  String get signInErrorServer =>
      'Anmelden gerade nicht möglich. Gleich noch einmal versuchen.';

  @override
  String get signInOfflineBody => 'Anmelden braucht eine Internetverbindung.';

  @override
  String get biometricsTitleFaceId => 'Mit Face ID entsperren?';

  @override
  String get biometricsTitleTouchId => 'Mit Touch ID entsperren?';

  @override
  String get biometricsTitleAndroid => 'Mit Biometrie entsperren?';

  @override
  String get biometricsBody =>
      'Schneller Start in jede Schicht. Das Passwort bleibt als Alternative.';

  @override
  String get biometricsEnableFaceId => 'Face ID verwenden';

  @override
  String get biometricsEnableTouchId => 'Touch ID verwenden';

  @override
  String get biometricsEnableAndroid => 'Biometrie verwenden';

  @override
  String get biometricsNotNow => 'Jetzt nicht';

  @override
  String get biometricsReason => 'Zum Entsperren von GiftCard Waiter';

  @override
  String biometricsPromptSubtitleAndroid(String restaurant) {
    return 'Für den Dienst bei $restaurant';
  }

  @override
  String get biometricsFailed => 'Nicht bestätigt. Noch einmal versuchen.';

  @override
  String get biometricsNotEnrolledFaceId =>
      'Face ID ist nicht eingerichtet. In den Einstellungen einrichten.';

  @override
  String get biometricsNotEnrolledTouchId =>
      'Touch ID ist nicht eingerichtet. In den Einstellungen einrichten.';

  @override
  String get biometricsNotEnrolledAndroid =>
      'Keine Biometrie eingerichtet. In den Einstellungen einrichten.';

  @override
  String get unlockButtonFaceId => 'Mit Face ID entsperren';

  @override
  String get unlockButtonTouchId => 'Mit Touch ID entsperren';

  @override
  String get unlockButtonAndroid => 'Entsperren';

  @override
  String get unlockUsePassword => 'Passwort verwenden';

  @override
  String get unlockChanged =>
      'Biometrie wurde auf diesem Gerät geändert. Bitte mit Passwort anmelden.';

  @override
  String get unlockLockedOut => 'Zu viele Versuche. Passwort verwenden.';

  @override
  String get topBarRecent => 'Verlauf';

  @override
  String topBarMenu(String name) {
    return 'Menü, $name';
  }

  @override
  String get readyTitle => 'Gutschein scannen';

  @override
  String get readyHint =>
      'Kamera auf den QR-Code des Gutscheins richten – gedruckt oder am Handy des Gastes.';

  @override
  String get readyScan => 'Gutschein scannen';

  @override
  String get readyTapCard => 'Mit Karte bezahlen';

  @override
  String get readySell => 'Gutschein verkaufen';

  @override
  String get readyPendingTitle => 'Einlösung noch nicht bestätigt';

  @override
  String readyPendingBody(String amount, String last4) {
    return '$amount auf Gutschein •••• $last4. Wird automatisch geprüft – es wird nie doppelt gebucht.';
  }

  @override
  String readyPendingBooked(String amount) {
    return 'Die unbestätigte Einlösung über $amount wurde gebucht.';
  }

  @override
  String readyPendingNotBooked(String amount) {
    return 'Die unbestätigte Einlösung über $amount wurde nicht gebucht.';
  }

  @override
  String get readyOnline => 'Wieder verbunden';

  @override
  String get offlineTitle => 'Keine Verbindung';

  @override
  String get offlineBody =>
      'Einlösen braucht Internet, damit nie doppelt gebucht wird.';

  @override
  String get maintenanceDefault =>
      'Geplante Wartung: Einlösen kann kurz nicht möglich sein.';

  @override
  String get maintenanceDismiss => 'Hinweis schließen';

  @override
  String get scanDetected => 'Gutschein erkannt';

  @override
  String get scanLookingUp => 'Gutschein wird geprüft …';

  @override
  String get scanSlow => 'Prüfung dauert länger …';

  @override
  String get cardTitle => 'Karte ans Handy halten';

  @override
  String get cardWaiting => 'Die Karte des Gastes oben an das Handy halten.';

  @override
  String get cardChecking => 'Karte wird geprüft …';

  @override
  String get cardSlow => 'Noch einen Moment – Karte am Handy lassen.';

  @override
  String get cardDone => 'Karte geprüft';

  @override
  String get cardFailed => 'Die Karte konnte nicht geprüft werden.';

  @override
  String get balanceCardOverline => 'Gutschein';

  @override
  String balanceCardValidUntil(String date) {
    return 'Gültig bis $date';
  }

  @override
  String get balanceCardNoExpiry => 'Ohne Ablaufdatum';

  @override
  String balanceCardMasked(String last4) {
    return '•••• $last4';
  }

  @override
  String balanceCardA11y(String restaurant, String spokenAmount, String last4) {
    return 'Gutschein $restaurant. Guthaben $spokenAmount. Gutschein endet auf $last4.';
  }

  @override
  String chargeVoucherNumberA11y(String number) {
    return 'Gutscheinnummer $number';
  }

  @override
  String get a11yChargeClose => 'Gutschein schließen';

  @override
  String a11yAmount(String spokenAmount) {
    return 'Betrag $spokenAmount';
  }

  @override
  String get chargeEnterAmount => 'Betrag eingeben';

  @override
  String chargeRedeem(String amount) {
    return '$amount einlösen';
  }

  @override
  String chargeRedeemFull(String amount) {
    return 'Gesamtes Guthaben einlösen · $amount';
  }

  @override
  String get chargeHold => 'Halten zum Einlösen';

  @override
  String get a11yHoldHint => 'Doppeltippen und halten zum Einlösen';

  @override
  String chargeRedeeming(String amount) {
    return '$amount wird eingelöst …';
  }

  @override
  String chargeOverBalance(String diff) {
    return '$diff mehr als das Guthaben';
  }

  @override
  String a11yOverBalance(String diff) {
    return '$diff mehr als das Guthaben. Einlösen nicht möglich.';
  }

  @override
  String chargeUseBalance(String amount) {
    return 'Guthaben verwenden · $amount';
  }

  @override
  String chargeUseMax(String amount) {
    return 'Maximum verwenden · $amount';
  }

  @override
  String chargeMaxSingle(String amount) {
    return 'Max. $amount pro Einlösung';
  }

  @override
  String get chargeFullOnly => 'Hier ist nur das gesamte Guthaben einlösbar.';

  @override
  String get chargeVelocityTitle => 'Limit für diesen Gutschein erreicht';

  @override
  String chargeVelocityBodyTime(int minutes) {
    return 'Wieder möglich in $minutes min. Oder Betriebsleitung holen.';
  }

  @override
  String chargeRateLimited(int seconds) {
    return 'Zu viele Anfragen – wieder möglich in $seconds s';
  }

  @override
  String chargeDailyLimit(String amount) {
    return 'Heute noch höchstens $amount mit diesem Gutschein';
  }

  @override
  String get chargePresentmentExpired =>
      'Zum Einlösen den Gutschein erneut scannen.';

  @override
  String get chargePendingTitle => 'Frühere Einlösung wird geprüft';

  @override
  String chargePendingBody(String amount) {
    return '$amount wurde vielleicht schon eingelöst. Einlösen ist erst nach der Prüfung möglich.';
  }

  @override
  String chargeEarlierBooked(String amount) {
    return 'Die frühere Einlösung über $amount wurde gebucht. Guthaben aktualisiert.';
  }

  @override
  String get keypadDoubleZero => 'Doppelnull';

  @override
  String get keypadDelete => 'Löschen';

  @override
  String get keypadDeleteHint => 'Lange drücken, um alles zu löschen';

  @override
  String get keypadCleared => 'Betrag gelöscht';

  @override
  String get keypadMaxReached => 'Höchstbetrag erreicht';

  @override
  String get badgeActive => 'Aktiv';

  @override
  String get badgeUsedUp => 'Aufgebraucht';

  @override
  String get badgeBlocked => 'Gesperrt';

  @override
  String get badgeExpired => 'Abgelaufen';

  @override
  String get voucherBlocked => 'Gutschein gesperrt';

  @override
  String voucherBlockedReason(String reason) {
    return 'Grund: $reason';
  }

  @override
  String get voucherExpired => 'Gutschein abgelaufen';

  @override
  String voucherExpiredBody(String date) {
    return 'Abgelaufen am $date. Bitte Betriebsleitung holen.';
  }

  @override
  String get voucherEmpty => 'Kein Guthaben mehr';

  @override
  String get voucherEmptyBody => 'Dieser Gutschein ist vollständig eingelöst.';

  @override
  String get redeemSlow => 'Verbindung langsam – neuer Versuch';

  @override
  String get uncertainTitle => 'Verbindung unterbrochen';

  @override
  String get uncertainBody => 'Wird geprüft … Es wird nie doppelt gebucht.';

  @override
  String uncertainRetrying(int n) {
    return 'Versuch $n von 3';
  }

  @override
  String get uncertainGuestHint =>
      'Dem Gast sagen: „Einen Moment bitte, die Einlösung wird bestätigt.\"';

  @override
  String get uncertainFailedBody =>
      'Noch nicht bestätigt. Erneut prüfen – es wird nie doppelt gebucht.';

  @override
  String get uncertainCancelled =>
      'Nicht bestätigt. Wird automatisch geprüft, bevor dieser Gutschein wieder eingelöst werden kann.';

  @override
  String get uncertainCancelledGuestHint =>
      'Dem Gast sagen: „Die Einlösung ist noch nicht bestätigt. Wir prüfen das, bevor neu eingelöst wird.\"';

  @override
  String redeemBalanceChanged(String amount) {
    return 'Guthaben hat sich geändert: jetzt $amount';
  }

  @override
  String get successTitle => 'Eingelöst';

  @override
  String successRemaining(String amount) {
    return 'Restguthaben $amount';
  }

  @override
  String get successEmpty => 'Gutschein ist jetzt leer';

  @override
  String get successNext => 'Nächsten Gutschein scannen';

  @override
  String get successNextCard => 'Nächste Karte';

  @override
  String get successShowGuest => 'Dem Gast zeigen';

  @override
  String successCard(String last4) {
    return 'Gutschein •••• $last4';
  }

  @override
  String get guestRemainingLabel => 'Restguthaben';

  @override
  String a11ySuccess(String amount, String balance) {
    return 'Eingelöst $amount, Restguthaben $balance';
  }

  @override
  String get problemNotRecognizedTitle => 'Kein Gutschein dieses Lokals';

  @override
  String get problemNotRecognizedBody =>
      'Dieser Code gilt hier nicht. Den Gast nach einem anderen Gutschein fragen oder Betriebsleitung holen.';

  @override
  String get problemCardNotRecognizedTitle => 'Karte nicht angenommen';

  @override
  String get problemCardNotRecognizedBody =>
      'Diese Karte konnte nicht als Gutschein dieses Lokals bestätigt werden. Betriebsleitung holen.';

  @override
  String get problemCardNotUsableTitle => 'Mit dieser Karte nicht bezahlbar';

  @override
  String get problemCardNotUsableNotActive =>
      'Die Karte ist noch nicht aktiviert.';

  @override
  String get problemCardNotUsableSuspended =>
      'Die Karte ist vorübergehend gesperrt. Die Betriebsleitung kann helfen.';

  @override
  String get problemCardNotUsableInvalid =>
      'Die Karte ist nicht mehr gültig. Die Betriebsleitung kann helfen.';

  @override
  String get problemCardNotUsableOtherRestaurant =>
      'Diese Karte gehört zu einem anderen Lokal.';

  @override
  String get problemCardMovedTitle => 'Karte zu früh entfernt';

  @override
  String get problemCardMovedBody =>
      'Die Karte ruhig am Handy halten, bis sie geprüft ist.';

  @override
  String get problemNfcOffTitle => 'NFC ist ausgeschaltet';

  @override
  String get problemNfcOffBody =>
      'NFC in den Einstellungen des Handys einschalten, um Karten zu lesen.';

  @override
  String get problemNfcUnsupportedTitle => 'Dieses Handy liest keine Karten';

  @override
  String get problemNfcUnsupportedBody =>
      'QR-Gutscheine scannen oder für Karten ein Handy mit NFC verwenden.';

  @override
  String get problemThrottledTitle => 'Zu viele Scans';

  @override
  String get problemThrottledBody => 'Scannen ist in Kürze wieder möglich.';

  @override
  String problemScanAgainIn(String time) {
    return 'Erneut scannen · $time';
  }

  @override
  String get problemNetworkBody =>
      'Der Gutschein konnte nicht geprüft werden. WLAN oder mobile Daten prüfen, dann erneut versuchen.';

  @override
  String get problemServerTitle => 'Dienst gerade nicht erreichbar';

  @override
  String get problemServerBody =>
      'Das Problem liegt nicht am Gutschein. Gleich erneut versuchen.';

  @override
  String get saleTitle => 'Gutschein verkaufen';

  @override
  String get saleAmountLabel => 'Gutscheinwert';

  @override
  String saleAmountRange(String min, String max) {
    return 'Der Wert muss zwischen $min und $max liegen.';
  }

  @override
  String saleContinue(String amount) {
    return 'Weiter · $amount';
  }

  @override
  String get salePaymentLabel => 'Bezahlt mit';

  @override
  String get salePaymentCash => 'Bar';

  @override
  String get salePaymentCardTerminal => 'Kartenterminal';

  @override
  String get salePaymentBankTransfer => 'Überweisung';

  @override
  String get salePaymentComplimentary => 'Gratis';

  @override
  String get saleReferenceLabel => 'Beleg- oder Referenznummer';

  @override
  String get saleReferenceRequired => 'Beleg- oder Referenznummer eingeben.';

  @override
  String get saleReasonLabel => 'Grund';

  @override
  String get saleReasonRequired => 'Grund eingeben (mindestens 3 Zeichen).';

  @override
  String get saleEmailLabel => 'E-Mail des Gastes (optional)';

  @override
  String get saleEmailHelper => 'Der Gast erhält eine Bestätigung.';

  @override
  String get saleEmailHelperPdf =>
      'Der Gast erhält den Gutschein als PDF per E-Mail.';

  @override
  String get saleEmailHelperNoMail => 'Wird beim Gutschein gespeichert.';

  @override
  String get saleEmailInvalid => 'Bitte eine gültige E-Mail-Adresse eingeben.';

  @override
  String get saleRecipientLabel => 'Für wen? (optional)';

  @override
  String get saleMessageLabel => 'Persönliche Nachricht (optional)';

  @override
  String get saleMessageHelper =>
      'Steht auf dem Gutschein und im PDF, bis zu 300 Zeichen.';

  @override
  String saleSubmit(String amount) {
    return 'Gutschein verkaufen · $amount';
  }

  @override
  String get saleSubmitting => 'Gutschein wird verkauft …';

  @override
  String get saleFailedTitle => 'Gutschein nicht verkauft';

  @override
  String get saleFailedBody =>
      'Es wurde kein Gutschein verkauft. Verbindung prüfen und erneut versuchen.';

  @override
  String get saleUncertainTitle => 'Verkauf nicht bestätigt';

  @override
  String get saleUncertainBody =>
      'Die Antwort kam nicht an. Erneut versuchen – der Gutschein wird nicht doppelt verkauft.';

  @override
  String get saleNotAllowedTitle => 'Nicht erlaubt';

  @override
  String get saleNotAllowedBody =>
      'Dieses Konto kann auf diesem Handy keine Gutscheine verkaufen. Bitte Betriebsleitung holen.';

  @override
  String get saleDoneTitle => 'Gutschein verkauft';

  @override
  String saleDoneValue(String amount) {
    return 'Wert $amount';
  }

  @override
  String get saleDoneBody =>
      'Den QR-Code für den Gast drucken. Er wird nur jetzt angezeigt.';

  @override
  String get salePrint => 'Gutschein drucken';

  @override
  String get salePrinted => 'An den Drucker gesendet';

  @override
  String get salePrintFailed => 'Drucken hat nicht geklappt. Erneut versuchen.';

  @override
  String get saleAnother => 'Weiteren Gutschein verkaufen';

  @override
  String get saleLeaveTitle => 'Ohne Drucken schließen?';

  @override
  String get saleLeaveBody =>
      'Der QR-Code kann nicht erneut angezeigt werden. Ohne ihn kann der Gast den Gutschein nicht einlösen.';

  @override
  String get saleLeaveConfirm => 'Trotzdem schließen';

  @override
  String get saleLeaveUncertainTitle => 'Verkauf offen – trotzdem schließen?';

  @override
  String get saleLeaveUncertainBody =>
      'Vielleicht wurde der Gutschein bereits verkauft. Nur „Erneut versuchen“ klärt das, ohne doppelt zu verkaufen.';

  @override
  String get saleNoQrTitle => 'Gutschein bereits verkauft';

  @override
  String get saleNoQrBody =>
      'Der QR-Code kann nicht mehr angezeigt werden. Hat der Gast keinen gedruckten Gutschein, im Dashboard sperren und neu verkaufen.';

  @override
  String get saleQrA11y => 'QR-Code des Gutscheins';

  @override
  String get saleFormTitle => 'Was wird verkauft?';

  @override
  String get saleFormPrintable => 'Gedruckter Gutschein';

  @override
  String get saleFormPrintableCaption => 'Mit QR-Code zum Ausdrucken';

  @override
  String get saleFormCard => 'Geschenkkarte';

  @override
  String get saleFormCardCaption =>
      'Eine Karte aus dem Lager, beim Verkauf aktiviert';

  @override
  String saleCardSubmit(String amount) {
    return 'Karte antippen · $amount';
  }

  @override
  String get saleCardTap => 'Die Karte ans Handy halten, um sie zu aktivieren.';

  @override
  String get saleCardDoneTitle => 'Karte aktiviert';

  @override
  String saleCardDoneBody(String number) {
    return 'Karte $number ist aktiv.';
  }

  @override
  String get saleCardFailedTitle => 'Karte nicht aktiviert';

  @override
  String get saleCardNotUsable =>
      'Diese Karte kann nicht verkauft werden. Eine andere Karte aus dem Lager nehmen.';

  @override
  String get saleCardAlreadySold =>
      'Diese Karte ist schon verkauft. Zum Aufladen „Karte aufladen“ wählen.';

  @override
  String get reloadReady => 'Karte aufladen';

  @override
  String get reloadTitle => 'Karte aufladen';

  @override
  String get reloadTap => 'Die Karte des Gastes ans Handy halten.';

  @override
  String get reloadTapAgain =>
      'Zum Bestätigen die Karte noch einmal ans Handy halten.';

  @override
  String get reloadAmountLabel => 'Aufladebetrag';

  @override
  String reloadAmountMax(String max) {
    return 'Höchstens $max, sonst wird das Guthabenlimit überschritten.';
  }

  @override
  String reloadSubmit(String amount) {
    return '$amount aufladen';
  }

  @override
  String get reloadSubmitting => 'Wird aufgeladen …';

  @override
  String get reloadDoneTitle => 'Karte aufgeladen';

  @override
  String reloadDoneBody(String amount, String balance) {
    return '+$amount · neues Guthaben $balance';
  }

  @override
  String get reloadAnother => 'Weitere Karte aufladen';

  @override
  String get reloadFailedTitle => 'Nicht aufgeladen';

  @override
  String get reloadFailedBody =>
      'Es wurde nichts gebucht. Bitte erneut versuchen.';

  @override
  String get reloadUncertainTitle => 'Aufladung unklar';

  @override
  String get reloadUncertainBody =>
      'Keine Antwort vom Server. „Erneut versuchen“ klärt, ob aufgeladen wurde, ohne doppelt zu buchen.';

  @override
  String get reloadNotAllowedTitle => 'Aufladen nicht möglich';

  @override
  String get reloadNotAllowedBody =>
      'Diese Anmeldung darf keine Karten aufladen, oder das Restaurant erlaubt kein Aufladen.';

  @override
  String get reloadCardReplaced =>
      'Diese Karte wurde ersetzt. Die neue Karte des Gastes ans Handy halten.';

  @override
  String get reloadCardRevoked =>
      'Diese Karte ist außer Betrieb und kann nicht aufgeladen werden.';

  @override
  String get reloadCardLost =>
      'Diese Karte ist als verloren gemeldet. Die Betriebsleitung kann helfen.';

  @override
  String get reloadCardNotInStock =>
      'Diese Karte ist noch nicht im Lager. Zuerst die Lieferung bestätigen.';

  @override
  String get reloadCardOtherCard =>
      'Das ist eine andere Karte. Zum Bestätigen dieselbe Karte ans Handy halten.';

  @override
  String get reloadNewCardTitle => 'Neue Karte – Guthaben aufladen';

  @override
  String reloadNewCardBody(String number) {
    return 'Karte $number aus dem Lager. Mit dem Betrag wird sie verkauft und aktiviert.';
  }

  @override
  String reloadNewCardDoneBody(String number, String balance) {
    return 'Karte $number ist aktiv · Guthaben $balance';
  }

  @override
  String get reloadNewCardNotAllowedBody =>
      'Das ist eine neue Karte. Aktivieren kann sie, wer Gutscheine verkaufen darf.';

  @override
  String get reloadLeaveUncertainTitle =>
      'Aufladung offen – trotzdem schließen?';

  @override
  String get reloadLeaveUncertainBody =>
      'Vielleicht wurde bereits aufgeladen. Nur „Erneut versuchen“ klärt das, ohne doppelt zu buchen.';

  @override
  String get qrTitle => 'Gutschein scannen';

  @override
  String get qrHint => 'Kamera auf den QR-Code des Gutscheins richten';

  @override
  String get qrNotVoucher => 'Dieser QR-Code ist kein Gutschein';

  @override
  String get qrDark => 'Zu dunkel? Licht einschalten.';

  @override
  String get qrTorchOn => 'Licht einschalten';

  @override
  String get qrTorchOff => 'Licht ausschalten';

  @override
  String get recentTitle => 'Verlauf';

  @override
  String recentSummary(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einlösungen',
      one: '$count Einlösung',
    );
    return '$_temp0 · $amount heute';
  }

  @override
  String recentRowRemaining(String amount) {
    return 'Rest $amount';
  }

  @override
  String get recentRowEmpty => 'Gutschein jetzt leer';

  @override
  String recentRowA11y(
    String time,
    String last4,
    String amount,
    String balance,
  ) {
    return '$time, Gutschein endet auf $last4, $amount eingelöst, Restguthaben $balance';
  }

  @override
  String get recentEmptyTitle => 'Noch keine Einlösungen';

  @override
  String get recentEmptyBody =>
      'Einlösungen von diesem Handy erscheinen hier bis 04:00 Uhr.';

  @override
  String get recentFooter => 'Nur dieses Handy · wird um 04:00 Uhr geleert';

  @override
  String get recentLimit => 'Die letzten 200 Einlösungen';

  @override
  String get recentDetailTitle => 'Einlösung';

  @override
  String get recentDetailTime => 'Zeit';

  @override
  String get recentDetailVoucher => 'Gutschein';

  @override
  String get recentDetailAmount => 'Betrag';

  @override
  String get recentDetailRemaining => 'Restguthaben';

  @override
  String get recentDetailTransaction => 'Buchung';

  @override
  String get recentDetailSupportCode => 'Support-Code';

  @override
  String get recentDetailReverseHint =>
      'Falscher Betrag? Die Betriebsleitung kann ihn im Dashboard stornieren.';

  @override
  String get menuClose => 'Menü schließen';

  @override
  String get menuAccount => 'Konto';

  @override
  String get menuRestaurant => 'Lokal';

  @override
  String get menuDevice => 'Gerät';

  @override
  String get menuSectionSettings => 'Einstellungen';

  @override
  String get menuLanguage => 'Sprache';

  @override
  String get menuLanguageFailed =>
      'Sprache nicht geändert. Bitte erneut versuchen.';

  @override
  String get menuTheme => 'Darstellung';

  @override
  String get menuThemeSystem => 'Wie System';

  @override
  String get menuThemeLight => 'Hell';

  @override
  String get menuThemeDark => 'Dunkel';

  @override
  String get menuSunlightTip => 'Im Freien ist das helle Design besser lesbar.';

  @override
  String get menuSound => 'Töne';

  @override
  String get menuHaptics => 'Vibration';

  @override
  String get menuHapticsUnavailable => 'Auf diesem Gerät nicht verfügbar';

  @override
  String get menuKeepScreenOn => 'Bildschirm anlassen';

  @override
  String get menuKeepScreenOnCaption => 'Während Scannen und Einlösen';

  @override
  String get menuHelp => 'Hilfe';

  @override
  String menuVersion(String version) {
    return 'Version $version';
  }

  @override
  String get menuSignOut => 'Abmelden';

  @override
  String get menuSignOutConfirmTitle => 'Abmelden?';

  @override
  String get menuSignOutConfirmBody =>
      'Der Schichtverlauf wird von diesem Gerät gelöscht.';

  @override
  String get menuSignOutConfirmAction => 'Abmelden';

  @override
  String get menuCards => 'Karten';

  @override
  String get menuCardsReceive => 'Lieferung bestätigen';

  @override
  String get menuCardsFind => 'Karte suchen';

  @override
  String get menuCardsOrder => 'Karten bestellen';

  @override
  String get cardsReceiveNone => 'Keine Lieferung offen.';

  @override
  String cardsReceiveBatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten',
      one: '$count Karte',
    );
    return '$_temp0';
  }

  @override
  String get cardsReceiveOnHold => 'Wird geprüft – die Anzahl stimmte nicht.';

  @override
  String get cardsReceiveCount => 'Wie viele Karten sind im Paket?';

  @override
  String cardsReceiveContinue(int count) {
    return 'Weiter mit $count';
  }

  @override
  String get cardsReceiveTap => 'Eine Karte aus dem Paket ans Handy halten.';

  @override
  String get cardsReceiveDone =>
      'Lieferung bestätigt – die Karten sind verkaufsbereit.';

  @override
  String get cardsReceiveHold =>
      'Die Anzahl stimmt nicht. GiftCard Pro prüft die Lieferung.';

  @override
  String get cardsReceiveWrongCard =>
      'Diese Karte gehört nicht zu dieser Lieferung.';

  @override
  String get cardsOrderCount => 'Wie viele Karten werden gebraucht?';

  @override
  String get cardsOrderHint =>
      'Bis zu 1.000 Karten. GiftCard Pro bestätigt die Bestellung und sendet die Karten.';

  @override
  String cardsOrderSubmit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten bestellen',
      one: '$count Karte bestellen',
    );
    return '$_temp0';
  }

  @override
  String get cardsOrderDone =>
      'Bestellung gesendet. Sobald die Karten unterwegs sind, erscheinen sie unter „Lieferung bestätigen“.';

  @override
  String cardsOrderOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eine Bestellung über $count Karten wartet auf Antwort.',
      one: 'Eine Bestellung über $count Karte wartet auf Antwort.',
    );
    return '$_temp0';
  }

  @override
  String cardsOrderDeclined(String reason) {
    return 'Letzte Bestellung abgelehnt: $reason';
  }

  @override
  String get cardsOrderTooMany => 'Es warten schon 3 Bestellungen auf Antwort.';

  @override
  String get cardsFindLabel => 'Kartennummer';

  @override
  String get cardsFindHelper =>
      'Steht beim Gutschein im Dashboard, z. B. B-2026-0001-0042';

  @override
  String get cardsFindAction => 'Suchen';

  @override
  String get cardsFindNotFound => 'Keine Karte mit dieser Nummer.';

  @override
  String get cardsStateActive => 'Aktiv';

  @override
  String get cardsStateSuspended => 'Gesperrt';

  @override
  String get cardsStateReplaced => 'Ersetzt';

  @override
  String get cardsStateAvailable => 'Im Lager';

  @override
  String get cardsStateOther => 'Nicht in Verwendung';

  @override
  String cardsBalance(String amount) {
    return 'Guthaben $amount';
  }

  @override
  String get cardsSuspend => 'Karte sperren';

  @override
  String get cardsResume => 'Karte entsperren';

  @override
  String get cardsReplace => 'Karte ersetzen';

  @override
  String get cardsReasonTitle => 'Grund';

  @override
  String get cardsReasonLost => 'Verloren';

  @override
  String get cardsReasonStolen => 'Gestohlen';

  @override
  String get cardsReasonDamaged => 'Beschädigt';

  @override
  String get cardsReasonFound => 'Wiedergefunden';

  @override
  String get cardsReplaceTap =>
      'Neue Karte aus dem Lager ans Handy halten. Das Guthaben geht auf sie über.';

  @override
  String get cardsReplaceTapOld =>
      'Die alte Karte des Gastes ans Handy halten.';

  @override
  String get cardsReplaceOwnerOnly =>
      'Eine verlorene oder gestohlene Karte ersetzt nur der Inhaber. Sperren Sie sie jetzt – dann zahlt sie nicht mehr.';

  @override
  String cardsReplaceDone(String number) {
    return 'Ersetzt durch $number. Die alte Karte gilt nicht mehr.';
  }

  @override
  String get cardsSuspendDone => 'Gesperrt – die Karte zahlt nicht mehr.';

  @override
  String get cardsResumeDone => 'Entsperrt – die Karte zahlt wieder.';

  @override
  String get cardsFailed => 'Das hat nicht geklappt. Erneut versuchen.';

  @override
  String get sessionExpired => 'Sitzung abgelaufen';

  @override
  String get sessionExpiredBody => 'Zum Weitermachen erneut anmelden.';

  @override
  String get sessionExpiredAction => 'Erneut anmelden';

  @override
  String get forbiddenTitle => 'Keine Berechtigung zum Einlösen';

  @override
  String get forbiddenBody =>
      'Dieses Konto kann keine Gutscheine mehr einlösen. Bitte Betriebsleitung holen.';

  @override
  String get deviceRevokedTitle => 'Gerät wurde entfernt';

  @override
  String get deviceRevokedBody =>
      'Das Gerät ist nicht mehr für dieses Lokal freigegeben. Bitte Betriebsleitung holen.';

  @override
  String get deviceRevokedAction => 'Anmelden';

  @override
  String get suspendedTitle => 'Einlösen ist pausiert';

  @override
  String get suspendedBody =>
      'Das Konto des Lokals ist pausiert. Bitte Betriebsleitung holen.';

  @override
  String get deactivatedTitle => 'Konto deaktiviert';

  @override
  String get deactivatedBody =>
      'Dieses Konto kann nicht mehr verwendet werden. Bitte Betriebsleitung holen.';

  @override
  String get updateTitle => 'Update erforderlich';

  @override
  String get updateBody =>
      'Diese Version wird nicht mehr unterstützt. Zum Weiterarbeiten aktualisieren.';

  @override
  String get updateAction => 'Jetzt aktualisieren';

  @override
  String get cameraDeniedTitle => 'Kamerazugriff ist aus';

  @override
  String get cameraDeniedBody =>
      'Kamera in den Einstellungen erlauben, um QR-Codes zu scannen.';

  @override
  String get cameraDeniedAction => 'Einstellungen öffnen';

  @override
  String get cameraRestrictedBody =>
      'Die Kamera ist auf diesem Gerät gesperrt. Bitte Betriebsleitung holen.';

  @override
  String get cameraUnavailableTitle => 'Kamera nicht verfügbar';

  @override
  String get cameraUnavailableBody =>
      'Andere Apps mit Kamera schließen, dann erneut versuchen.';

  @override
  String get introSkip => 'Überspringen';

  @override
  String get introNext => 'Weiter';

  @override
  String get introStart => 'Loslegen';

  @override
  String introPage(int n) {
    return 'Seite $n von 3';
  }

  @override
  String get intro1Title => 'Gutschein scannen';

  @override
  String get intro1Body =>
      'Kamera auf den QR-Code richten. Das Guthaben erscheint sofort.';

  @override
  String get intro2Title => 'Betrag eingeben, einlösen';

  @override
  String intro2Body(String threshold) {
    return 'Guthaben sehen, Betrag tippen, fertig. Ab $threshold zum Bestätigen gedrückt halten.';
  }

  @override
  String get intro3Title => 'Nie doppelt gebucht';

  @override
  String get intro3Body =>
      'Eingelöst wird nur mit Verbindung. Alle Einlösungen der Schicht stehen unter „Verlauf\".';

  @override
  String get stationTitle => 'Karten personalisieren';

  @override
  String get stationChoose => 'Charge wählen';

  @override
  String get stationEmpty => 'Keine Charge wartet auf Personalisierung.';

  @override
  String stationBatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten fertig',
      one: '$count Karte fertig',
    );
    return '$_temp0';
  }

  @override
  String get stationWaiting => 'Leere Karte ans Handy halten.';

  @override
  String get stationWorking => 'Wird personalisiert – Karte nicht bewegen.';

  @override
  String stationDone(String number) {
    return 'Karte $number fertig';
  }

  @override
  String get stationFailed => 'Karte nicht fertig. Erneut anhalten.';

  @override
  String get stationRejected =>
      'Karte gehört nicht zu dieser Charge oder ist schon fertig.';

  @override
  String get stationUnknownChip => 'Unbekannte Karte – aussortieren.';

  @override
  String get stationFinish => 'Charge beenden';

  @override
  String a11ySpokenAmount(int euros, String cents) {
    return '$euros Euro $cents';
  }

  @override
  String a11yVoucherLoaded(String restaurant, String spokenAmount) {
    return '$restaurant. Guthaben $spokenAmount.';
  }

  @override
  String a11yProblem(String title, String body) {
    return '$title. $body';
  }

  @override
  String get a11yReady => 'Bereit für den nächsten Gutschein';

  @override
  String get a11yScanAvailable => 'Scannen wieder möglich';

  @override
  String get a11yRedeemAvailable => 'Einlösen wieder möglich';
}
