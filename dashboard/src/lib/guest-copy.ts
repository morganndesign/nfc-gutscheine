/**
 * Texts that guests read (the printable voucher sheet). They follow the restaurant's language, not the staff UI
 * language: an Austrian guest should never see a mix of German and English. Guests never see a voucher number
 * or a value on paper (architecture §6.4): the QR is the voucher, the balance lives on the server.
 */
const COPY = {
  de: {
    voucher: "Gutschein",
    for: "für",
    howTo: "Bitte zeigen Sie diesen Code beim Bezahlen vor.",
    keepSafe: "Wie Bargeld aufbewahren: Wer den Code besitzt, kann den Gutschein einlösen.",
    noExpiry: "Unbefristet gültig",
    validUntil: "Gültig bis",
  },
  en: {
    voucher: "Voucher",
    for: "for",
    howTo: "Please show this code when you pay.",
    keepSafe: "Keep it safe like cash: whoever holds the code can redeem the voucher.",
    noExpiry: "No expiry date",
    validUntil: "Valid until",
  },
  bhs: {
    voucher: "Vaučer",
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
