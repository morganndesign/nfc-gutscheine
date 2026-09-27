import type { CardStatus } from "@/lib/api/types"

/**
 * Texts that guests read (public balance page, printed card). They follow the restaurant's language,
 * not the staff UI language — an Austrian guest should never see a mix of German and English.
 */
const COPY = {
  de: {
    giftCard: "Gutschein",
    balance: "Aktuelles Guthaben",
    validUntil: "Gültig bis",
    noExpiry: "Unbegrenzt gültig",
    askStaff: "Bitte fragen Sie im Restaurant nach Ihrem Guthaben.",
    scanHint: "Code scannen oder Karte ans Handy halten, um das Guthaben zu prüfen.",
    for: "für",
    notFoundTitle: "Gutschein nicht gefunden",
    notFoundText: "Dieser Link ist ungültig. Bitte wenden Sie sich an das Restaurant.",
    status: {
      active: "Gültig",
      inactive: "Noch nicht aktiviert",
      redeemed: "Vollständig eingelöst",
      blocked: "Gesperrt",
      expired: "Abgelaufen",
      replaced: "Ersetzt",
    },
  },
  en: {
    giftCard: "Gift card",
    balance: "Current balance",
    validUntil: "Valid until",
    noExpiry: "No expiry date",
    askStaff: "Please ask the restaurant staff for your balance.",
    scanHint: "Scan the code or tap the card with your phone to check the balance.",
    for: "for",
    notFoundTitle: "Gift card not found",
    notFoundText: "This link is not valid. Please contact the restaurant.",
    status: { active: "Valid", inactive: "Not activated yet", redeemed: "Fully redeemed", blocked: "Blocked", expired: "Expired", replaced: "Replaced" },
  },
} satisfies Record<string, { status: Record<CardStatus, string> } & Record<string, unknown>>

export type GuestCopy = (typeof COPY)["de"]

export function guestCopy(locale: string | null | undefined): GuestCopy {
  return (locale ?? "de-AT").toLowerCase().startsWith("de") ? COPY.de : COPY.en
}
