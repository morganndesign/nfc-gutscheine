import { regionalLocale } from "./regional.ts"

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

/** Largest amount an input may hold: far above any limit, safely below the precision of a JavaScript number. */
export const MAX_INPUT_CENTS = 100_000_000_000

/**
 * Parses an amount typed by staff into cents: "12,50", "12.50", "1.234,50", "1,234.50", "1 234,50", "12", "€ 12,50".
 * Returns null for anything that is not unambiguously one non-negative amount with at most two decimals — a minus
 * sign, letters ("1e5", "12abc"), three decimals, misplaced group separators ("1,2,3") or absurdly large values — so a
 * typo can never silently become a different amount.
 */
export function parseMoneyInput(input: string): number | null {
  // Spaces (also the narrow/no-break spaces Intl uses), apostrophes as group separators and currency symbols go.
  const cleaned = input.replace(/[\s\u00a0\u202f'’]/g, "").replace(/\p{Sc}/gu, "")
  if (!/^\d[\d.,]*$/.test(cleaned)) return null

  let integer: string
  let fraction = ""
  const lastSep = Math.max(cleaned.lastIndexOf(","), cleaned.lastIndexOf("."))
  const separators = cleaned.replace(/\d/g, "")
  const decimalPart = lastSep >= 0 ? cleaned.slice(lastSep + 1) : ""

  // The last separator is the decimal separator when it is followed by at most two digits and differs from (or is the
  // only one of) the separators before it ("12,5", "1.234,50", "12."); otherwise every separator groups thousands.
  const isDecimal = lastSep >= 0 && decimalPart.length <= 2 && !separators.slice(0, -1).includes(cleaned[lastSep])
  if (isDecimal) {
    integer = cleaned.slice(0, lastSep)
    fraction = decimalPart
  } else {
    integer = cleaned
  }

  // Group separators: one kind, every group exactly three digits ("1.234.567"), never "1,2,3" or "12.34.5".
  if (/[.,]/.test(integer)) {
    if (!/^\d{1,3}([.,]\d{3})+$/.test(integer) || new Set(integer.replace(/\d/g, "")).size !== 1) return null
    integer = integer.replace(/[.,]/g, "")
  }
  if (!/^\d+$/.test(integer) || integer.length > 12) return null

  const cents = Number(integer) * 100 + Number(fraction.padEnd(2, "0") || "0")
  return Number.isSafeInteger(cents) && cents <= MAX_INPUT_CENTS ? cents : null
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
