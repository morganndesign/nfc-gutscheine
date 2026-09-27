# Cookie-Richtlinie

> **Muster/Vorlage — vor Verwendung durch eine in Österreich zugelassene Rechtsanwältin / einen Rechtsanwalt prüfen lassen.**
> Keine Rechtsberatung. Stellen mit **[Prüfen: …]** bedürfen einer besonderen Prüfung. Die technischen Angaben entsprechen dem Stand der Anwendung im September 2026 und sind bei jeder Änderung der Anwendung zu aktualisieren.

*Geltungsbereich: Cookies und Speicherung im Browser (localStorage, sessionStorage) auf app.giftcardpro.at (Anwendung, einschließlich der öffentlichen Guthabenseite) und giftcardpro.at (Website).*

---

## 1. Kurzfassung

- Die Anwendung GiftCard Pro verwendet **ausschließlich technisch notwendige** Cookies und Browser-Speicher.
- **Keine** Analyse-, Statistik- oder Werbe-Cookies, **keine** Cookies von Drittanbietern, **kein** Tracking, **keine** externen Schriftarten oder Skripte.
- Deshalb ist **keine Einwilligung** erforderlich und es wird kein Cookie-Banner angezeigt (§ 165 Abs 3 TKG 2021).
- Die Website giftcardpro.at verwendet standardmäßig ebenfalls keine Tracking-Cookies.

## 2. Was sind Cookies und Browser-Speicher?

**Cookies** sind kleine Textdateien, die eine Website im Browser ablegt und bei jedem weiteren Aufruf wieder mitsendet. **localStorage** und **sessionStorage** sind Speicherbereiche im Browser, die nur von der Website selbst gelesen werden und nicht automatisch an den Server gesendet werden. sessionStorage wird beim Schließen des Tabs gelöscht, localStorage bleibt bis zur Löschung erhalten.

Rechtlich werden beide gleich behandelt: Das Speichern und Auslesen von Informationen auf Ihrem Endgerät ist nach § 165 Abs 3 TKG 2021 ohne Einwilligung nur zulässig, wenn es **unbedingt erforderlich** ist, damit wir einen von Ihnen ausdrücklich gewünschten Dienst bereitstellen können.

## 3. Cookies der Anwendung (app.giftcardpro.at)

| Name | Zweck | Speicherdauer | Art | Anbieter |
|---|---|---|---|---|
| `giftcardpro_session` | Anmeldung: hält Sie nach dem Login angemeldet und bindet die Sitzung an Ihr Gerät. Inhalt verschlüsselt, für Skripte nicht lesbar (`HttpOnly`), nur über HTTPS (`Secure`), `SameSite=Lax`. | Läuft nach **8 Stunden** ohne Aktivität ab | technisch notwendig | eigener (First Party) |
| `XSRF-TOKEN` | Schutz vor Cross-Site-Request-Forgery (CSRF): Die Anwendung sendet den Wert bei jeder Änderung mit, damit fremde Websites keine Aktionen in Ihrem Namen auslösen können. | wie Sitzung (8 Stunden ohne Aktivität) | technisch notwendig | eigener |
| `remember_web_…` | Nur wenn Sie beim Login **Keep me signed in on this device** wählen: hält Sie auf diesem Gerät angemeldet. Verschlüsselt, `HttpOnly`. | bis zu [400 Tage] oder bis zur Abmeldung bzw. Passwortänderung [Prüfen: technisch konfigurierten Wert bestätigen] | technisch notwendig (von Ihnen ausdrücklich gewünscht) | eigener |
| `sidebar_state` | Merkt sich, ob Sie die Seitenleiste im Dashboard ein- oder ausgeklappt haben. Wird nur gesetzt, wenn Sie die Seitenleiste umschalten. | 7 Tage | technisch notwendig (Darstellungseinstellung) [Prüfen] | eigener |

## 4. Browser-Speicher der Anwendung (localStorage / sessionStorage)

| Schlüssel | Speicher | Zweck | Speicherdauer | Art |
|---|---|---|---|---|
| `gcp.device-id` | localStorage | Zufällige Geräte-ID (keine Hardware-Informationen, kein Fingerprinting). Dient der Sicherheit: Geräte werden im Restaurantkonto registriert, können benannt und bei Verlust gesperrt werden; eine kopierte Sitzung funktioniert auf einem anderen Gerät nicht. | bis Sie die Websitedaten löschen | technisch notwendig |
| `theme` | localStorage | Ihre Wahl zwischen hellem, dunklem oder System-Design. | bis Sie die Websitedaten löschen | technisch notwendig (Darstellungseinstellung) |
| `gcp.acting-restaurant` | sessionStorage | Nur für Plattform-Administratoren des Anbieters: merkt sich, in welchem Restaurant gerade gearbeitet wird („Open restaurant"). | bis zum Schließen des Tabs | technisch notwendig |

**Öffentliche Guthabenseite:** Wenn Gäste ihre Karte mit dem eigenen Smartphone scannen, können dieselben technisch notwendigen Einträge (Sitzungs- und CSRF-Cookie, Geräte-ID) entstehen. Es werden keine Tracking- oder Werbeeinträge gesetzt. [Prüfen: technisch bestätigen, welche Einträge auf der Guthabenseite tatsächlich entstehen]

**Rechtsgrundlage** für alle Einträge: § 165 Abs 3 TKG 2021 (unbedingt erforderlich, keine Einwilligung notwendig); für eine damit verbundene Verarbeitung personenbezogener Daten Art 6 Abs 1 lit b DSGVO (Bereitstellung des Dienstes) und lit f DSGVO (Sicherheit).

## 5. Website (giftcardpro.at)

- Standardmäßig setzt die Website **keine** Cookies zu Analyse-, Marketing- oder Werbezwecken und bindet keine Inhalte von Drittanbietern ein, die Cookies setzen.
- Falls eine Reichweitenmessung eingesetzt wird, dann nur **cookielos** und ohne Speicherung auf Ihrem Endgerät: [Name des Tools, Anbieter, Serverstandort EU] oder „keine". [Prüfen: auch cookielose Messung datenschutzrechtlich bewerten]
- Eingebettete Terminbuchungs-, Karten- oder Videodienste werden erst nach Ihrem Klick geladen („Zwei-Klick-Lösung"), falls solche eingesetzt werden. [Prüfen]

## 6. Wenn später ein einwilligungspflichtiges Werkzeug dazukommt

Setzen wir künftig ein Werkzeug ein, das nicht unbedingt erforderlich ist (z. B. Analyse mit Cookies, Werbe-Pixel, eingebettete Videos, Chat-Widget eines Drittanbieters), gilt Folgendes:

1. Wir holen **vorher** Ihre Einwilligung über ein Einwilligungsbanner ein (Art 6 Abs 1 lit a DSGVO, § 165 Abs 3 TKG 2021).
2. Das Banner bietet „Akzeptieren" und „Ablehnen" gleichwertig auf der ersten Ebene an; nichts ist vorausgewählt.
3. Vor der Einwilligung werden keine entsprechenden Cookies gesetzt und keine Skripte geladen.
4. Sie können Ihre Einwilligung jederzeit über einen dauerhaft erreichbaren Link („Cookie-Einstellungen") widerrufen.
5. Diese Richtlinie und die [Datenschutzerklärung](privacy-policy.md) werden vorher aktualisiert (Name, Zweck, Anbieter, Speicherdauer, allfällige Drittlandübermittlung).

In der Anwendung selbst sind keine einwilligungspflichtigen Werkzeuge vorgesehen.

## 7. Cookies im Browser verwalten und löschen

Sie können Cookies und Websitedaten jederzeit in Ihrem Browser ansehen und löschen. Wenn Sie die notwendigen Einträge der Anwendung löschen oder blockieren, werden Sie abgemeldet bzw. können sich nicht anmelden; nach dem Löschen der Geräte-ID wird Ihr Gerät beim nächsten Login als neues Gerät registriert.

- **Google Chrome:** Einstellungen → Datenschutz und Sicherheit → Drittanbieter-Cookies bzw. Websitedaten; oder Schloss-Symbol in der Adressleiste → Cookies und Websitedaten.
- **Mozilla Firefox:** Einstellungen → Datenschutz & Sicherheit → Cookies und Website-Daten → Daten verwalten.
- **Apple Safari (Mac):** Einstellungen → Datenschutz → Websitedaten verwalten.
- **Safari auf iPhone/iPad:** Einstellungen → Apps → Safari → Erweitert → Website-Daten. [Prüfen: Menüpfad je iOS-Version]
- **Microsoft Edge:** Einstellungen → Cookies und Websiteberechtigungen → Cookies und Websitedaten verwalten.

Die Bezeichnungen können sich je nach Browserversion unterscheiden. Hilfe finden Sie in der Dokumentation Ihres Browsers.

## 8. Kontakt und Änderungen

Fragen zu dieser Richtlinie: **datenschutz@giftcardpro.at**. Wir aktualisieren diese Richtlinie, sobald sich eingesetzte Cookies oder Speichereinträge ändern. Weitere Informationen zur Verarbeitung personenbezogener Daten finden Sie in unserer [Datenschutzerklärung](privacy-policy.md).

---

Version 1.0 · Stand: September 2026
