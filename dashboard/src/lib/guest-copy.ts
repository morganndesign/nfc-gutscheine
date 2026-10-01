/**
 * Texts that guests read (the printable voucher sheet). They follow the restaurant's language, not the staff UI
 * language: an Austrian guest should never see a mix of German and English. The sheet shows the voucher's value as
 * part of the design (ADR-003); it is what was bought, not a balance — the balance lives on the server. It never
 * shows the voucher number: the QR is the voucher.
 */
const COPY = {
  de: {
    voucher: "Gutschein",
    headline: "Ein Geschenk für Sie",
    scan: "Einlösbar mit diesem Code",
    value: "Wert",
    for: "für",
    howTo: "Bitte zeigen Sie diesen Code beim Bezahlen vor.",
    keepSafe: "Wie Bargeld aufbewahren: Wer den Code besitzt, kann den Gutschein einlösen.",
    noExpiry: "Unbefristet gültig",
    validUntil: "Gültig bis",
  },
  en: {
    voucher: "Voucher",
    headline: "A gift for you",
    scan: "Redeem with this code",
    value: "Value",
    for: "for",
    howTo: "Please show this code when you pay.",
    keepSafe: "Keep it safe like cash: whoever holds the code can redeem the voucher.",
    noExpiry: "No expiry date",
    validUntil: "Valid until",
  },
  bhs: {
    voucher: "Vaučer",
    headline: "Poklon za vas",
    scan: "Iskoristite uz ovaj kôd",
    value: "Vrijednost",
    for: "za",
    howTo: "Molimo pokažite ovaj kôd prilikom plaćanja.",
    keepSafe: "Čuvajte ga kao gotovinu: ko ima kôd, može iskoristiti vaučer.",
    noExpiry: "Bez roka važenja",
    validUntil: "Vrijedi do",
  },
} satisfies Record<string, Record<string, string>>

export type GuestCopy = (typeof COPY)["de"]

/** German, Bosnian/Croatian/Serbian or English, by the restaurant's locale (the waiter app uses the same rule). */
export function guestCopy(locale: string | null | undefined): GuestCopy {
  const language = (locale ?? "de-AT").toLowerCase().slice(0, 2)
  if (language === "de") return COPY.de
  if (language === "bs" || language === "hr" || language === "sr") return COPY.bhs
  return COPY.en
}

/** The locale the restaurant's money is printed in (`de-AT`, `bs-BA`, …); guests read the restaurant's format. */
export function guestLocale(locale: string | null | undefined): string {
  return (locale ?? "de-AT").replace("_", "-")
}
