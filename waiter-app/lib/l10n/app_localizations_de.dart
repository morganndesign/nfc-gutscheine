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
  String get commonEnterNumber => 'Kartennummer eingeben';

  @override
  String get commonEditNumber => 'Nummer bearbeiten';

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
      'E-Mail oder Passwort stimmt nicht. Bitte prüfen und erneut versuchen.';

  @override
  String get signInErrorNoPermission =>
      'Dieses Konto kann keine Karten einlösen. Bitte Betriebsleitung holen.';

  @override
  String signInErrorThrottled(String time) {
    return 'Zu viele Versuche. Erneut möglich in $time.';
  }

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
  String get unlockPendingCard =>
      'Die Karte wird nach dem Entsperren geöffnet.';

  @override
  String get topBarRecent => 'Verlauf';

  @override
  String topBarMenu(String name) {
    return 'Menü, $name';
  }

  @override
  String get readyAndroidTitle => 'Karte an das Handy halten';

  @override
  String get readyAndroidHint => 'Die Karte wird automatisch erkannt';

  @override
  String get readyIosButton => 'Karte scannen';

  @override
  String get readyIosHint =>
      'Nach dem Tippen die Karte oben an das iPhone halten';

  @override
  String get readyIosTimeout =>
      'Keine Karte erkannt. Zum Wiederholen „Karte scannen\" tippen.';

  @override
  String get readyManual => 'Kartennummer';

  @override
  String get readyQr => 'QR-Code';

  @override
  String get readyFirstCardTipAndroid =>
      'Tipp: Die NFC-Antenne sitzt meist hinten oben, nahe der Kamera.';

  @override
  String get readyFirstCardTipIos =>
      'Tipp: Die Karte flach an die Oberkante halten, nahe der Kamera.';

  @override
  String get readyNoNfcTitle => 'QR-Code auf der Karte scannen';

  @override
  String get readyNoNfcHint =>
      'Dieses Gerät hat kein NFC. QR-Code oder Kartennummer verwenden.';

  @override
  String get readyNoNfcButton => 'QR-Code scannen';

  @override
  String get readyOfflineTap =>
      'Keine Verbindung – Karte kann nicht geprüft werden';

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
  String get iosSheetAlert => 'Karte oben an das iPhone halten';

  @override
  String get iosSheetFound => 'Karte gefunden';

  @override
  String get iosSheetReadFailed => 'Karte nicht gelesen. Erneut versuchen.';

  @override
  String get iosSheetMultiple =>
      'Mehrere Karten erkannt. Nur eine Karte halten.';

  @override
  String get iosSheetTimeoutSoon =>
      'Noch keine Karte. Karte flach oben an das iPhone halten.';

  @override
  String get scanNotCard => 'Keine Gutscheinkarte';

  @override
  String get scanReadFailedTitle => 'Karte konnte nicht gelesen werden';

  @override
  String get scanReadFailedBody => 'Karte eine Sekunde ruhig halten.';

  @override
  String get scanDetected => 'Karte erkannt';

  @override
  String get scanLookingUp => 'Karte wird gesucht …';

  @override
  String get scanSlow => 'Suche dauert länger …';

  @override
  String get scanUnavailable =>
      'NFC gerade nicht verfügbar. Kartennummer oder QR-Code verwenden.';

  @override
  String get balanceCardOverline => 'Gutscheinkarte';

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
    return 'Gutscheinkarte $restaurant. Guthaben $spokenAmount. Karte endet auf $last4.';
  }

  @override
  String chargeCardNumberA11y(String number) {
    return 'Kartennummer $number';
  }

  @override
  String get a11yChargeClose => 'Karte schließen';

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
  String get chargeVelocityTitle => 'Limit für diese Karte erreicht';

  @override
  String chargeVelocityBodyTime(int minutes) {
    return 'Wieder möglich in $minutes min. Oder Betriebsleitung holen.';
  }

  @override
  String chargeRateLimited(int seconds) {
    return 'Zu viele Anfragen – wieder möglich in $seconds s';
  }

  @override
  String get chargeSwitchCardMessage => 'Andere Karte erkannt – wechseln?';

  @override
  String get chargeSwitchCardAction => 'Wechseln';

  @override
  String get chargeSwitchCardKeep => 'Behalten';

  @override
  String get chargeSwitchCardDialogTitle => 'Andere Karte erkannt';

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
  String get badgeInactive => 'Nicht aktiviert';

  @override
  String get badgeRedeemed => 'Aufgebraucht';

  @override
  String get badgeBlocked => 'Gesperrt';

  @override
  String get badgeExpired => 'Abgelaufen';

  @override
  String get badgeReplaced => 'Ersetzt';

  @override
  String get cardBlocked => 'Karte gesperrt';

  @override
  String cardBlockedReason(String reason) {
    return 'Grund: $reason';
  }

  @override
  String get cardExpired => 'Karte abgelaufen';

  @override
  String cardExpiredBody(String date) {
    return 'Abgelaufen am $date. Bitte Betriebsleitung holen.';
  }

  @override
  String get cardInactive => 'Karte noch nicht aktiviert';

  @override
  String get cardInactiveBody =>
      'Erst nach der Aktivierung einlösbar. Bitte Betriebsleitung holen.';

  @override
  String get cardReplaced => 'Karte wurde ersetzt';

  @override
  String get cardReplacedBody =>
      'Das Guthaben ist auf der neuen Karte. Gast nach der neuen Karte fragen.';

  @override
  String get cardEmpty => 'Kein Guthaben mehr';

  @override
  String get cardEmptyBody => 'Diese Karte ist vollständig eingelöst.';

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
      'Noch nicht bestätigt. Erneut versuchen – es wird nie doppelt gebucht.';

  @override
  String get uncertainCancelled =>
      'Nicht bestätigt. Vor dem nächsten Einlösen die Karte erneut scannen.';

  @override
  String get uncertainCancelledGuestHint =>
      'Dem Gast sagen: „Die Einlösung ist noch nicht bestätigt. Wir prüfen das Guthaben, bevor neu eingelöst wird.\"';

  @override
  String redeemBalanceChanged(String amount) {
    return 'Guthaben hat sich geändert: jetzt $amount';
  }

  @override
  String get redeemTapAgain => 'Bitte noch einmal einlösen.';

  @override
  String get successTitle => 'Eingelöst';

  @override
  String successRemaining(String amount) {
    return 'Restguthaben $amount';
  }

  @override
  String get successEmpty => 'Karte ist jetzt leer';

  @override
  String get successNextIos => 'Nächste Karte scannen';

  @override
  String get successNextAndroid => 'Nächste Karte einfach antippen';

  @override
  String get successShowGuest => 'Dem Gast zeigen';

  @override
  String successCard(String last4) {
    return 'Karte •••• $last4';
  }

  @override
  String get guestRemainingLabel => 'Restguthaben';

  @override
  String a11ySuccess(String amount, String balance) {
    return 'Eingelöst $amount, Restguthaben $balance';
  }

  @override
  String get problemNotFoundTitle => 'Karte nicht gefunden';

  @override
  String get problemNotFoundBody =>
      'Diese Karte ist nicht im System. Karte prüfen oder nach einer anderen fragen.';

  @override
  String get problemNotFoundBodyManual =>
      'Keine Karte mit dieser Nummer. Ziffern prüfen.';

  @override
  String get problemForeignTitle => 'Karte eines anderen Lokals';

  @override
  String get problemForeignBody =>
      'Sie ist nur im ausstellenden Lokal einlösbar.';

  @override
  String get problemVerifyTitle => 'Karte konnte nicht geprüft werden';

  @override
  String get problemVerifyBody =>
      'Karte vorerst nicht annehmen. Bitte Betriebsleitung holen.';

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
      'Karte konnte nicht geprüft werden. WLAN oder mobile Daten prüfen, dann erneut versuchen.';

  @override
  String get problemServerTitle => 'Dienst gerade nicht erreichbar';

  @override
  String get problemServerBody =>
      'Das Problem liegt nicht an der Karte. Gleich erneut versuchen.';

  @override
  String get manualTitle => 'Kartennummer';

  @override
  String get manualHelper => '16 Ziffern auf der Rückseite der Karte';

  @override
  String manualCounter(int count) {
    return '$count von 16';
  }

  @override
  String get manualSubmit => 'Karte suchen';

  @override
  String get manualErrorInvalid => 'Kartennummer prüfen';

  @override
  String get manualErrorPaste => 'Keine gültige Kartennummer zum Einfügen';

  @override
  String get qrTitle => 'QR-Code scannen';

  @override
  String get qrHint => 'Kamera auf den QR-Code der Karte richten';

  @override
  String get qrNotCard => 'Dieser QR-Code gehört zu keiner Gutscheinkarte';

  @override
  String get qrDark => 'Zu dunkel? Licht einschalten.';

  @override
  String get qrTorchOn => 'Licht einschalten';

  @override
  String get qrTorchOff => 'Licht ausschalten';

  @override
  String get qrManual => 'Kartennummer eingeben';

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
  String get recentRowEmpty => 'Karte jetzt leer';

  @override
  String recentRowA11y(
    String time,
    String last4,
    String amount,
    String balance,
  ) {
    return '$time, Karte endet auf $last4, $amount eingelöst, Restguthaben $balance';
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
  String get recentDetailCard => 'Karte';

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
  String get sessionExpired => 'Sitzung abgelaufen';

  @override
  String get sessionExpiredBody => 'Zum Weitermachen erneut anmelden.';

  @override
  String get sessionExpiredAction => 'Erneut anmelden';

  @override
  String get forbiddenTitle => 'Keine Berechtigung zum Einlösen';

  @override
  String get forbiddenBody =>
      'Dieses Konto kann keine Karten mehr einlösen. Bitte Betriebsleitung holen.';

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
  String get lockedTitle => 'Konto vorübergehend gesperrt';

  @override
  String lockedBody(String time) {
    return 'Zu viele Anmeldeversuche. Erneut möglich in $time.';
  }

  @override
  String lockedButton(String time) {
    return 'Erneut in $time';
  }

  @override
  String get lockedOver => 'Anmelden ist wieder möglich';

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
  String get nfcOffTitle => 'NFC ist aus';

  @override
  String get nfcOffBody => 'NFC einschalten, um Karten zu scannen.';

  @override
  String get nfcOffAction => 'NFC einschalten';

  @override
  String get nfcOffOn => 'NFC ist an. Bereit zum Scannen.';

  @override
  String get cameraDeniedTitle => 'Kamerazugriff ist aus';

  @override
  String get cameraDeniedBody =>
      'Kamera in den Einstellungen erlauben, um QR-Codes zu scannen.';

  @override
  String get cameraDeniedAction => 'Einstellungen öffnen';

  @override
  String get cameraRestrictedBody =>
      'Die Kamera ist auf diesem Gerät gesperrt. Kartennummer verwenden.';

  @override
  String get cameraUnavailableTitle => 'Kamera nicht verfügbar';

  @override
  String get cameraUnavailableBody =>
      'Andere Apps mit Kamera schließen oder Kartennummer eingeben.';

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
  String get intro1TitleAndroid => 'Karte antippen';

  @override
  String get intro1BodyAndroid =>
      'Die Karte an die Rückseite halten. Das Guthaben erscheint in unter einer Sekunde.';

  @override
  String get intro1TitleIos => 'Scannen, dann Karte halten';

  @override
  String get intro1BodyIos =>
      '„Karte scannen\" tippen, dann die Karte oben an das iPhone halten.';

  @override
  String get intro1TitleNoNfc => 'QR-Code scannen';

  @override
  String get intro1BodyNoNfc =>
      'Kamera auf den QR-Code richten oder die Kartennummer eingeben.';

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
  String a11ySpokenAmount(int euros, String cents) {
    return '$euros Euro $cents';
  }

  @override
  String a11yCardLoaded(String restaurant, String spokenAmount) {
    return '$restaurant. Guthaben $spokenAmount.';
  }

  @override
  String a11yProblem(String title, String body) {
    return '$title. $body';
  }

  @override
  String get a11yReady => 'Bereit für die nächste Karte';

  @override
  String get a11yScanAvailable => 'Scannen wieder möglich';

  @override
  String get a11yRedeemAvailable => 'Einlösen wieder möglich';
}
