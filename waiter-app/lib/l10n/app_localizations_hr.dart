// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Croatian (`hr`).
class AppLocalizationsHr extends AppLocalizations {
  AppLocalizationsHr([String locale = 'hr']) : super(locale);

  @override
  String get appName => 'GiftCard Waiter';

  @override
  String get commonCancel => 'Otkaži';

  @override
  String get commonClose => 'Zatvori';

  @override
  String get commonBack => 'Nazad';

  @override
  String get commonDone => 'Gotovo';

  @override
  String get commonTryAgain => 'Pokušaj ponovo';

  @override
  String get commonScanAgain => 'Skeniraj ponovo';

  @override
  String get commonEnterNumber => 'Unesi broj kartice';

  @override
  String get commonEditNumber => 'Uredi broj';

  @override
  String get commonOpenSettings => 'Otvori postavke';

  @override
  String get commonBackToSignIn => 'Nazad na prijavu';

  @override
  String get commonCheckAgain => 'Provjeri ponovo';

  @override
  String commonSupportCode(String code) {
    return 'Kôd $code';
  }

  @override
  String commonSupportCodeA11y(String code) {
    return 'Kôd za podršku $code';
  }

  @override
  String get commonCopied => 'Kopirano';

  @override
  String get redeemNothingBooked => 'Ništa nije knjiženo.';

  @override
  String get getManager => 'Molimo pozovite menadžera';

  @override
  String get splashLoading => 'Učitavanje';

  @override
  String get startupOfflineTitle => 'Nema internet veze';

  @override
  String get startupOfflineBody =>
      'Telefon nije povezan. Uključite Wi-Fi ili mobilne podatke, pa pokušajte ponovo.';

  @override
  String get startupHostNotFoundTitle => 'Server nije pronađen';

  @override
  String startupHostNotFoundBody(String host) {
    return 'Adresa $host ne postoji. Provjerite adresu servera.';
  }

  @override
  String get startupRefusedTitle => 'Server nije pokrenut';

  @override
  String startupRefusedBody(String host) {
    return 'Na adresi $host ništa ne odgovara. Provjerite radi li server i je li adresa tačna.';
  }

  @override
  String get startupTimeoutTitle => 'Server ne odgovara';

  @override
  String startupTimeoutBody(String host) {
    return '$host nije odgovorio na vrijeme. Provjerite mrežu, pa pokušajte ponovo.';
  }

  @override
  String get startupTlsTitle => 'Nema sigurne veze';

  @override
  String startupTlsBody(String host) {
    return 'Certifikat servera $host je odbijen. Provjerite datum i vrijeme na telefonu.';
  }

  @override
  String get startupServerErrorTitle => 'Problem na serveru';

  @override
  String startupServerErrorBody(String host, String status) {
    return '$host javlja problem (status $status). Pokušajte ponovo kasnije.';
  }

  @override
  String get startupInvalidResponseTitle => 'Pogrešna adresa servera';

  @override
  String startupInvalidResponseBody(String host) {
    return 'Na adresi $host nije GiftCard Pro server. Provjerite adresu servera.';
  }

  @override
  String get startupConfigurationTitle => 'Aplikacija nije ispravno podešena';

  @override
  String get startupConfigurationBody =>
      'Ova verzija aplikacije nema važeću adresu servera. Molimo pozovite menadžera.';

  @override
  String get startupStorageTitle => 'Zaštićena pohrana nije dostupna';

  @override
  String get startupStorageBody =>
      'Aplikacija ne može otvoriti zaštićenu pohranu. Ponovo pokrenite telefon, pa pokušajte ponovo.';

  @override
  String get startupUnknownTitle => 'Aplikacija se nije pokrenula';

  @override
  String get startupUnknownBody =>
      'Pokušajte ponovo. Ako se ponovi, molimo pozovite menadžera.';

  @override
  String startupServer(String url) {
    return 'Server: $url';
  }

  @override
  String startupDetail(String detail) {
    return 'Detalji: $detail';
  }

  @override
  String startupEnvironment(String name) {
    return 'Okruženje: $name';
  }

  @override
  String get startupChangeServer => 'Promijeni server';

  @override
  String get envDevelopment => 'Razvoj';

  @override
  String get envStaging => 'Staging';

  @override
  String get envProduction => 'Produkcija';

  @override
  String get envBadgeDevelopment => 'DEV';

  @override
  String get envBadgeStaging => 'STAGING';

  @override
  String envBadgeA11y(String name, String host) {
    return 'Testno okruženje $name, server $host. Dugo pritisnite za promjenu servera.';
  }

  @override
  String get serverTitle => 'Adresa servera';

  @override
  String get serverLabel => 'Adresa API-ja';

  @override
  String get serverHelp =>
      'Na primjer http://192.168.1.20:8000 (/api/v1 se dodaje).';

  @override
  String serverDefault(String url) {
    return 'Zadano u ovoj aplikaciji: $url';
  }

  @override
  String get serverSave => 'Sačuvaj i poveži';

  @override
  String get serverReset => 'Koristi zadano';

  @override
  String get serverInvalid =>
      'Adresa nije važeća. Počnite s http:// ili https://.';

  @override
  String get serverHttpsRequired => 'Ova verzija dozvoljava samo https adrese.';

  @override
  String get serverWrongPath => 'Adresa mora završavati s /api/v1.';

  @override
  String get signInTitle => 'Prijava';

  @override
  String get signInSubtitle => 'Prijavite se računom zaposlenika';

  @override
  String get signInEmailLabel => 'E-mail';

  @override
  String get signInEmailPlaceholder => 'ime@primjer.ba';

  @override
  String get signInPasswordLabel => 'Lozinka';

  @override
  String get signInPasswordShow => 'Prikaži lozinku';

  @override
  String get signInPasswordHide => 'Sakrij lozinku';

  @override
  String get signInForgot => 'Zaboravljena lozinka';

  @override
  String get signInSubmit => 'Prijavi se';

  @override
  String get signInLoading => 'Prijava u toku';

  @override
  String get signInNoAccess =>
      'Nemate pristup? Menadžer ga kreira u dashboardu.';

  @override
  String get signInErrorRequired => 'Obavezno polje';

  @override
  String get signInErrorEmailFormat => 'Provjerite e-mail adresu';

  @override
  String get signInErrorInvalid =>
      'E-mail ili lozinka nisu ispravni. Provjerite i pokušajte ponovo.';

  @override
  String get signInErrorNoPermission =>
      'Ovaj račun ne može iskorištavati kartice. Molimo pozovite menadžera.';

  @override
  String signInErrorThrottled(String time) {
    return 'Previše pokušaja. Ponovo za $time.';
  }

  @override
  String get signInErrorServer =>
      'Prijava trenutno nije moguća. Pokušajte ponovo za trenutak.';

  @override
  String get signInOfflineBody => 'Za prijavu je potrebna veza.';

  @override
  String get biometricsTitleFaceId => 'Otključavati pomoću Face ID-a?';

  @override
  String get biometricsTitleTouchId => 'Otključavati pomoću Touch ID-a?';

  @override
  String get biometricsTitleAndroid => 'Otključavati biometrijom?';

  @override
  String get biometricsBody =>
      'Brži početak svake smjene. Lozinka ostaje kao zamjena.';

  @override
  String get biometricsEnableFaceId => 'Koristi Face ID';

  @override
  String get biometricsEnableTouchId => 'Koristi Touch ID';

  @override
  String get biometricsEnableAndroid => 'Koristi biometriju';

  @override
  String get biometricsNotNow => 'Ne sada';

  @override
  String get biometricsReason => 'Za otključavanje aplikacije GiftCard Waiter';

  @override
  String biometricsPromptSubtitleAndroid(String restaurant) {
    return 'Za smjenu u restoranu $restaurant';
  }

  @override
  String get biometricsFailed => 'Nije potvrđeno. Pokušajte ponovo.';

  @override
  String get biometricsNotEnrolledFaceId =>
      'Face ID nije podešen. Podesite ga u postavkama.';

  @override
  String get biometricsNotEnrolledTouchId =>
      'Touch ID nije podešen. Podesite ga u postavkama.';

  @override
  String get biometricsNotEnrolledAndroid =>
      'Biometrija nije podešena. Podesite je u postavkama.';

  @override
  String get unlockButtonFaceId => 'Otključaj pomoću Face ID-a';

  @override
  String get unlockButtonTouchId => 'Otključaj pomoću Touch ID-a';

  @override
  String get unlockButtonAndroid => 'Otključaj';

  @override
  String get unlockUsePassword => 'Koristi lozinku';

  @override
  String get unlockChanged =>
      'Biometrija je promijenjena na ovom uređaju. Prijavite se lozinkom.';

  @override
  String get unlockLockedOut => 'Previše pokušaja. Koristite lozinku.';

  @override
  String get unlockPendingCard => 'Kartica se otvara nakon otključavanja.';

  @override
  String get topBarRecent => 'Nedavno';

  @override
  String topBarMenu(String name) {
    return 'Meni, $name';
  }

  @override
  String get readyAndroidTitle => 'Prislonite karticu uz telefon';

  @override
  String get readyAndroidHint => 'Kartica se automatski prepoznaje';

  @override
  String get readyIosButton => 'Skeniraj karticu';

  @override
  String get readyIosHint => 'Nakon dodira prislonite karticu na vrh iPhonea';

  @override
  String get readyIosTimeout =>
      'Kartica nije prepoznata. Dodirnite „Skeniraj karticu\" za novi pokušaj.';

  @override
  String get readyManual => 'Broj kartice';

  @override
  String get readyQr => 'QR kôd';

  @override
  String get readyFirstCardTipAndroid =>
      'Savjet: NFC antena je obično gore na poleđini, blizu kamere.';

  @override
  String get readyFirstCardTipIos =>
      'Savjet: držite karticu ravno uz gornji rub, blizu kamere.';

  @override
  String get readyNoNfcTitle => 'Skenirajte QR kôd na kartici';

  @override
  String get readyNoNfcHint =>
      'Ovaj uređaj nema NFC. Koristite QR kôd ili broj kartice.';

  @override
  String get readyNoNfcButton => 'Skeniraj QR kôd';

  @override
  String get readyOfflineTap => 'Nema veze – kartica se ne može provjeriti';

  @override
  String get readyOnline => 'Veza je ponovo uspostavljena';

  @override
  String get offlineTitle => 'Nema veze';

  @override
  String get offlineBody =>
      'Za iskorištavanje je potrebna veza, da se ništa ne knjiži dvaput.';

  @override
  String get maintenanceDefault =>
      'Planirano održavanje: iskorištavanje može kratko biti nedostupno.';

  @override
  String get maintenanceDismiss => 'Zatvori obavijest';

  @override
  String get iosSheetAlert => 'Prislonite karticu na vrh iPhonea';

  @override
  String get iosSheetFound => 'Kartica pronađena';

  @override
  String get iosSheetReadFailed => 'Kartica nije pročitana. Pokušajte ponovo.';

  @override
  String get iosSheetMultiple => 'Prepoznato više kartica. Držite samo jednu.';

  @override
  String get iosSheetTimeoutSoon =>
      'Još nema kartice. Prislonite je ravno na vrh iPhonea.';

  @override
  String get scanNotCard => 'Ovo nije poklon kartica';

  @override
  String get scanReadFailedTitle => 'Kartica nije pročitana';

  @override
  String get scanReadFailedBody => 'Držite je mirno jednu sekundu.';

  @override
  String get scanDetected => 'Kartica prepoznata';

  @override
  String get scanLookingUp => 'Tražimo karticu …';

  @override
  String get scanSlow => 'Još tražimo …';

  @override
  String get scanUnavailable =>
      'NFC trenutno nije dostupan. Koristite broj kartice ili QR kôd.';

  @override
  String get balanceCardOverline => 'Poklon kartica';

  @override
  String balanceCardValidUntil(String date) {
    return 'Vrijedi do $date';
  }

  @override
  String get balanceCardNoExpiry => 'Bez roka važenja';

  @override
  String balanceCardMasked(String last4) {
    return '•••• $last4';
  }

  @override
  String balanceCardA11y(String restaurant, String spokenAmount, String last4) {
    return 'Poklon kartica $restaurant. Stanje $spokenAmount. Kartica završava na $last4.';
  }

  @override
  String chargeCardNumberA11y(String number) {
    return 'Broj kartice $number';
  }

  @override
  String get a11yChargeClose => 'Zatvori karticu';

  @override
  String a11yAmount(String spokenAmount) {
    return 'Iznos $spokenAmount';
  }

  @override
  String get chargeEnterAmount => 'Unesi iznos';

  @override
  String chargeRedeem(String amount) {
    return 'Iskoristi $amount';
  }

  @override
  String chargeRedeemFull(String amount) {
    return 'Iskoristi cijeli iznos · $amount';
  }

  @override
  String get chargeHold => 'Držite za iskorištavanje';

  @override
  String get a11yHoldHint => 'Dvaput dodirnite i držite za iskorištavanje';

  @override
  String chargeRedeeming(String amount) {
    return 'Iskorištava se $amount …';
  }

  @override
  String chargeOverBalance(String diff) {
    return '$diff više od stanja';
  }

  @override
  String a11yOverBalance(String diff) {
    return '$diff više od stanja. Iskorištavanje nije moguće.';
  }

  @override
  String chargeUseBalance(String amount) {
    return 'Iskoristi stanje · $amount';
  }

  @override
  String chargeUseMax(String amount) {
    return 'Iskoristi maksimum · $amount';
  }

  @override
  String chargeMaxSingle(String amount) {
    return 'Najviše $amount po iskorištavanju';
  }

  @override
  String get chargeFullOnly => 'Ovdje se može iskoristiti samo cijelo stanje.';

  @override
  String get chargeVelocityTitle => 'Dosegnut je limit za ovu karticu';

  @override
  String chargeVelocityBodyTime(int minutes) {
    return 'Ponovo moguće za $minutes min. Ili pozovite menadžera.';
  }

  @override
  String chargeRateLimited(int seconds) {
    return 'Previše zahtjeva – ponovo moguće za $seconds s';
  }

  @override
  String get chargeSwitchCardMessage =>
      'Prepoznata je druga kartica – zamijeniti?';

  @override
  String get chargeSwitchCardAction => 'Zamijeni';

  @override
  String get chargeSwitchCardKeep => 'Zadrži';

  @override
  String get chargeSwitchCardDialogTitle => 'Prepoznata je druga kartica';

  @override
  String get keypadDoubleZero => 'Dvije nule';

  @override
  String get keypadDelete => 'Obriši';

  @override
  String get keypadDeleteHint => 'Dugo pritisnite za brisanje svega';

  @override
  String get keypadCleared => 'Iznos obrisan';

  @override
  String get keypadMaxReached => 'Dosegnut najveći iznos';

  @override
  String get badgeActive => 'Aktivna';

  @override
  String get badgeInactive => 'Nije aktivirana';

  @override
  String get badgeRedeemed => 'Potrošena';

  @override
  String get badgeBlocked => 'Blokirana';

  @override
  String get badgeExpired => 'Istekla';

  @override
  String get badgeReplaced => 'Zamijenjena';

  @override
  String get cardBlocked => 'Kartica blokirana';

  @override
  String cardBlockedReason(String reason) {
    return 'Razlog: $reason';
  }

  @override
  String get cardExpired => 'Kartica istekla';

  @override
  String cardExpiredBody(String date) {
    return 'Istekla $date. Molimo pozovite menadžera.';
  }

  @override
  String get cardInactive => 'Kartica još nije aktivirana';

  @override
  String get cardInactiveBody =>
      'Može se iskoristiti tek nakon aktivacije. Molimo pozovite menadžera.';

  @override
  String get cardReplaced => 'Kartica je zamijenjena';

  @override
  String get cardReplacedBody =>
      'Stanje je na novoj kartici. Zamolite gosta za novu karticu.';

  @override
  String get cardEmpty => 'Nema više stanja';

  @override
  String get cardEmptyBody => 'Ova kartica je potpuno iskorištena.';

  @override
  String get redeemSlow => 'Spora veza – ponovni pokušaj';

  @override
  String get uncertainTitle => 'Veza prekinuta';

  @override
  String get uncertainBody => 'Provjeravamo … Ništa se ne knjiži dvaput.';

  @override
  String uncertainRetrying(int n) {
    return 'Pokušaj $n od 3';
  }

  @override
  String get uncertainGuestHint =>
      'Recite gostu: „Trenutak, molim, iskorištavanje se potvrđuje.\"';

  @override
  String get uncertainFailedBody =>
      'Još nije potvrđeno. Pokušajte ponovo – ništa se ne knjiži dvaput.';

  @override
  String get uncertainCancelled =>
      'Nije potvrđeno. Prije novog iskorištavanja ponovo skenirajte karticu.';

  @override
  String get uncertainCancelledGuestHint =>
      'Recite gostu: „Iskorištavanje još nije potvrđeno. Provjerit ćemo stanje prije novog iskorištavanja.\"';

  @override
  String redeemBalanceChanged(String amount) {
    return 'Stanje se promijenilo: sada $amount';
  }

  @override
  String get redeemTapAgain => 'Molimo ponovo dodirnite Iskoristi.';

  @override
  String get successTitle => 'Iskorišteno';

  @override
  String successRemaining(String amount) {
    return 'Preostalo stanje $amount';
  }

  @override
  String get successEmpty => 'Kartica je sada prazna';

  @override
  String get successNextIos => 'Skeniraj sljedeću karticu';

  @override
  String get successNextAndroid => 'Samo prislonite sljedeću karticu';

  @override
  String get successShowGuest => 'Pokaži gostu';

  @override
  String successCard(String last4) {
    return 'Kartica •••• $last4';
  }

  @override
  String get guestRemainingLabel => 'Preostalo stanje';

  @override
  String a11ySuccess(String amount, String balance) {
    return 'Iskorišteno $amount, preostalo stanje $balance';
  }

  @override
  String get problemNotFoundTitle => 'Kartica nije pronađena';

  @override
  String get problemNotFoundBody =>
      'Ova kartica nije u sistemu. Provjerite karticu ili zamolite drugu.';

  @override
  String get problemNotFoundBodyManual =>
      'Nema kartice s ovim brojem. Provjerite cifre.';

  @override
  String get problemForeignTitle => 'Kartica drugog restorana';

  @override
  String get problemForeignBody =>
      'Može se iskoristiti samo u restoranu koji ju je izdao.';

  @override
  String get problemVerifyTitle => 'Kartica nije mogla biti provjerena';

  @override
  String get problemVerifyBody =>
      'Zasad ne prihvatajte ovu karticu. Molimo pozovite menadžera.';

  @override
  String get problemThrottledTitle => 'Previše skeniranja';

  @override
  String get problemThrottledBody => 'Skeniranje će uskoro ponovo biti moguće.';

  @override
  String problemScanAgainIn(String time) {
    return 'Skeniraj ponovo · $time';
  }

  @override
  String get problemNetworkBody =>
      'Kartica nije provjerena. Provjerite Wi-Fi ili mobilne podatke, pa pokušajte ponovo.';

  @override
  String get problemServerTitle => 'Servis trenutno nije dostupan';

  @override
  String get problemServerBody =>
      'Problem nije do kartice. Pokušajte ponovo za trenutak.';

  @override
  String get manualTitle => 'Broj kartice';

  @override
  String get manualHelper => '16 cifara na poleđini kartice';

  @override
  String manualCounter(int count) {
    return '$count od 16';
  }

  @override
  String get manualSubmit => 'Pronađi karticu';

  @override
  String get manualErrorInvalid => 'Provjerite broj kartice';

  @override
  String get manualErrorPaste => 'Nema ispravnog broja kartice za lijepljenje';

  @override
  String get qrTitle => 'Skeniraj QR kôd';

  @override
  String get qrHint => 'Usmjerite kameru na QR kôd kartice';

  @override
  String get qrNotCard => 'Ovaj QR kôd nije poklon kartica';

  @override
  String get qrDark => 'Pretamno? Uključite svjetlo.';

  @override
  String get qrTorchOn => 'Uključi svjetlo';

  @override
  String get qrTorchOff => 'Isključi svjetlo';

  @override
  String get qrManual => 'Unesi broj kartice';

  @override
  String get recentTitle => 'Nedavno';

  @override
  String recentSummary(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count iskorištavanja',
      few: '$count iskorištavanja',
      one: '$count iskorištavanje',
    );
    return '$_temp0 · $amount danas';
  }

  @override
  String recentRowRemaining(String amount) {
    return 'Ostatak $amount';
  }

  @override
  String get recentRowEmpty => 'Kartica sada prazna';

  @override
  String recentRowA11y(
    String time,
    String last4,
    String amount,
    String balance,
  ) {
    return '$time, kartica završava na $last4, iskorišteno $amount, preostalo stanje $balance';
  }

  @override
  String get recentEmptyTitle => 'Još nema iskorištavanja';

  @override
  String get recentEmptyBody =>
      'Iskorištavanja s ovog telefona prikazuju se ovdje do 04:00 h.';

  @override
  String get recentFooter => 'Samo ovaj telefon · briše se u 04:00 h';

  @override
  String get recentLimit => 'Posljednjih 200 iskorištavanja';

  @override
  String get recentDetailTitle => 'Iskorištavanje';

  @override
  String get recentDetailTime => 'Vrijeme';

  @override
  String get recentDetailCard => 'Kartica';

  @override
  String get recentDetailAmount => 'Iznos';

  @override
  String get recentDetailRemaining => 'Preostalo stanje';

  @override
  String get recentDetailTransaction => 'Transakcija';

  @override
  String get recentDetailSupportCode => 'Kôd za podršku';

  @override
  String get recentDetailReverseHint =>
      'Pogrešan iznos? Menadžer ga može stornirati u dashboardu.';

  @override
  String get menuClose => 'Zatvori meni';

  @override
  String get menuAccount => 'Račun';

  @override
  String get menuRestaurant => 'Restoran';

  @override
  String get menuDevice => 'Uređaj';

  @override
  String get menuSectionSettings => 'Postavke';

  @override
  String get menuTheme => 'Izgled';

  @override
  String get menuThemeSystem => 'Kao sistem';

  @override
  String get menuThemeLight => 'Svijetlo';

  @override
  String get menuThemeDark => 'Tamno';

  @override
  String get menuSunlightTip => 'Na otvorenom je svijetla tema čitljivija.';

  @override
  String get menuSound => 'Zvukovi';

  @override
  String get menuHaptics => 'Vibracija';

  @override
  String get menuHapticsUnavailable => 'Nije dostupno na ovom uređaju';

  @override
  String get menuKeepScreenOn => 'Ekran uvijek uključen';

  @override
  String get menuKeepScreenOnCaption => 'Tokom skeniranja i iskorištavanja';

  @override
  String get menuHelp => 'Pomoć';

  @override
  String menuVersion(String version) {
    return 'Verzija $version';
  }

  @override
  String get menuSignOut => 'Odjavi se';

  @override
  String get menuSignOutConfirmTitle => 'Odjaviti se?';

  @override
  String get menuSignOutConfirmBody =>
      'Historija smjene na ovom uređaju bit će izbrisana.';

  @override
  String get menuSignOutConfirmAction => 'Odjavi se';

  @override
  String get sessionExpired => 'Sesija je istekla';

  @override
  String get sessionExpiredBody => 'Prijavite se ponovo za nastavak.';

  @override
  String get sessionExpiredAction => 'Ponovo se prijavi';

  @override
  String get forbiddenTitle => 'Nema dozvole za iskorištavanje';

  @override
  String get forbiddenBody =>
      'Ovaj račun više ne može iskorištavati kartice. Molimo pozovite menadžera.';

  @override
  String get deviceRevokedTitle => 'Uređaj je uklonjen';

  @override
  String get deviceRevokedBody =>
      'Uređaj više nije odobren za ovaj restoran. Molimo pozovite menadžera.';

  @override
  String get deviceRevokedAction => 'Prijavi se';

  @override
  String get suspendedTitle => 'Iskorištavanje je pauzirano';

  @override
  String get suspendedBody =>
      'Račun restorana je pauziran. Molimo pozovite menadžera.';

  @override
  String get lockedTitle => 'Račun je privremeno zaključan';

  @override
  String lockedBody(String time) {
    return 'Previše pokušaja prijave. Ponovo za $time.';
  }

  @override
  String lockedButton(String time) {
    return 'Ponovo za $time';
  }

  @override
  String get lockedOver => 'Prijava je ponovo moguća';

  @override
  String get deactivatedTitle => 'Račun je deaktiviran';

  @override
  String get deactivatedBody =>
      'Ovaj račun se više ne može koristiti. Molimo pozovite menadžera.';

  @override
  String get updateTitle => 'Potrebno ažuriranje';

  @override
  String get updateBody =>
      'Ova verzija više nije podržana. Ažurirajte za nastavak rada.';

  @override
  String get updateAction => 'Ažuriraj sada';

  @override
  String get nfcOffTitle => 'NFC je isključen';

  @override
  String get nfcOffBody => 'Uključite NFC za skeniranje kartica.';

  @override
  String get nfcOffAction => 'Uključi NFC';

  @override
  String get nfcOffOn => 'NFC je uključen. Spremno za skeniranje.';

  @override
  String get cameraDeniedTitle => 'Pristup kameri je isključen';

  @override
  String get cameraDeniedBody =>
      'Dozvolite pristup kameri u postavkama za skeniranje QR kodova.';

  @override
  String get cameraDeniedAction => 'Otvori postavke';

  @override
  String get cameraRestrictedBody =>
      'Kamera je ograničena na ovom uređaju. Koristite broj kartice.';

  @override
  String get cameraUnavailableTitle => 'Kamera nije dostupna';

  @override
  String get cameraUnavailableBody =>
      'Zatvorite druge aplikacije s kamerom ili unesite broj kartice.';

  @override
  String get introSkip => 'Preskoči';

  @override
  String get introNext => 'Dalje';

  @override
  String get introStart => 'Počni';

  @override
  String introPage(int n) {
    return 'Stranica $n od 3';
  }

  @override
  String get intro1TitleAndroid => 'Prislonite karticu';

  @override
  String get intro1BodyAndroid =>
      'Prislonite karticu na poleđinu telefona. Stanje se pojavi za manje od sekunde.';

  @override
  String get intro1TitleIos => 'Skenirajte, pa prislonite karticu';

  @override
  String get intro1BodyIos =>
      'Dodirnite „Skeniraj karticu\", zatim prislonite karticu na vrh iPhonea.';

  @override
  String get intro1TitleNoNfc => 'Skenirajte QR kôd';

  @override
  String get intro1BodyNoNfc =>
      'Usmjerite kameru na QR kôd ili unesite broj kartice.';

  @override
  String get intro2Title => 'Unesite iznos, iskoristite';

  @override
  String intro2Body(String threshold) {
    return 'Pogledajte stanje, unesite iznos, gotovo. Od $threshold držite za potvrdu.';
  }

  @override
  String get intro3Title => 'Nikad dvaput knjiženo';

  @override
  String get intro3Body =>
      'Iskorištavanje radi samo uz vezu. Iskorištavanja iz smjene su pod „Nedavno\".';

  @override
  String a11ySpokenAmount(int euros, String cents) {
    String _temp0 = intl.Intl.pluralLogic(
      euros,
      locale: localeName,
      other: '$euros eura',
      few: '$euros eura',
      one: '$euros euro',
    );
    return '$_temp0 $cents';
  }

  @override
  String a11yCardLoaded(String restaurant, String spokenAmount) {
    return '$restaurant. Stanje $spokenAmount.';
  }

  @override
  String a11yProblem(String title, String body) {
    return '$title. $body';
  }

  @override
  String get a11yReady => 'Spremno za sljedeću karticu';

  @override
  String get a11yScanAvailable => 'Skeniranje ponovo moguće';

  @override
  String get a11yRedeemAvailable => 'Iskorištavanje ponovo moguće';
}
