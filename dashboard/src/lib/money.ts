import { regionalLocale } from "@/lib/regional"

const formatters = new Map<string, Intl.NumberFormat>()

export function formatMoney(minor: number | null | undefined, currency = "EUR", locale = regionalLocale()): string {
  const key = `${locale}|${currency}`
  let f = formatters.get(key)
  if (!f) {
    f = new Intl.NumberFormat(locale, { style: "currency", currency })
    formatters.set(key, f)
  }
  return f.format((minor ?? 0) / 100)
}

/** Signed variant for ledger rows: "+50,00 €" / "−18,50 €". */
export function formatSignedMoney(minor: number, currency = "EUR", locale = regionalLocale()): string {
  const abs = formatMoney(Math.abs(minor), currency, locale)
  if (minor > 0) return `+${abs}`
  if (minor < 0) return `−${abs}`
  return abs
}

/** "€ 50" for whole amounts, "€ 12,50" otherwise — for chips, limits and other short labels. */
export function formatMoneyShort(minor: number | null | undefined, currency = "EUR", locale = regionalLocale()): string {
  const value = minor ?? 0
  if (value % 100 !== 0) return formatMoney(value, currency, locale)
  return new Intl.NumberFormat(locale, { style: "currency", currency, maximumFractionDigits: 0 }).format(value / 100)
}

export function formatCompactMoney(minor: number, currency = "EUR", locale = regionalLocale()): string {
  return new Intl.NumberFormat(locale, { style: "currency", currency, notation: "compact", maximumFractionDigits: 1 }).format(minor / 100)
}

/**
 * Parses user input like "12,50", "12.50", "1.234,50" or "12" into cents. Returns null when invalid.
 */
export function parseMoneyInput(input: string): number | null {
  const cleaned = input.replace(/[^\d.,]/g, "")
  if (!cleaned) return null
  const lastSep = Math.max(cleaned.lastIndexOf(","), cleaned.lastIndexOf("."))
  let normalized: string
  if (lastSep >= 0 && cleaned.length - lastSep - 1 <= 2) {
    normalized = cleaned.slice(0, lastSep).replace(/[.,]/g, "") + "." + cleaned.slice(lastSep + 1)
  } else {
    normalized = cleaned.replace(/[.,]/g, "")
  }
  const value = Number(normalized)
  if (!Number.isFinite(value) || value < 0) return null
  return Math.round(value * 100)
}

/** Formats cents for an editable input using the locale's decimal separator ("12,50" / "12.50"). */
export function centsToInput(cents: number, locale = regionalLocale()): string {
  const decimal = new Intl.NumberFormat(locale).formatToParts(1.5).find((p) => p.type === "decimal")?.value ?? ","
  return (cents / 100).toFixed(2).replace(".", decimal)
}

/** The currency symbol as the locale writes it (€, CHF, £ …). */
export function currencySymbol(currency = "EUR", locale = regionalLocale()): string {
  return new Intl.NumberFormat(locale, { style: "currency", currency }).formatToParts(0).find((p) => p.type === "currency")?.value ?? currency
}
