import { regionalLocale, regionalTimeZone } from "@/lib/regional"

export function formatDate(iso: string | null | undefined, locale = regionalLocale(), timeZone = regionalTimeZone()): string {
  if (!iso) return "—"
  return new Intl.DateTimeFormat(locale, { dateStyle: "medium", timeZone }).format(new Date(iso))
}

export function formatDateTime(iso: string | null | undefined, locale = regionalLocale(), timeZone = regionalTimeZone()): string {
  if (!iso) return "—"
  return new Intl.DateTimeFormat(locale, { dateStyle: "medium", timeStyle: "short", timeZone }).format(new Date(iso))
}

export function formatRelative(iso: string | null | undefined, locale = "en"): string {
  if (!iso) return "Never"
  const diff = (new Date(iso).getTime() - Date.now()) / 1000
  const rtf = new Intl.RelativeTimeFormat(locale, { numeric: "auto" })
  const abs = Math.abs(diff)
  if (abs < 60) return rtf.format(Math.round(diff), "second")
  if (abs < 3600) return rtf.format(Math.round(diff / 60), "minute")
  if (abs < 86400) return rtf.format(Math.round(diff / 3600), "hour")
  if (abs < 86400 * 30) return rtf.format(Math.round(diff / 86400), "day")
  if (abs < 86400 * 365) return rtf.format(Math.round(diff / (86400 * 30)), "month")
  return rtf.format(Math.round(diff / (86400 * 365)), "year")
}

export function formatNumber(value: number, locale = regionalLocale()): string {
  return new Intl.NumberFormat(locale).format(value)
}

/** Today's date (YYYY-MM-DD) in the restaurant's timezone — for date inputs. */
export function todayInput(offsetDays = 0, timeZone = regionalTimeZone()): string {
  const d = new Date(Date.now() + offsetDays * 86_400_000)
  return new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).format(d)
}

/** The calendar day (YYYY-MM-DD) of an ISO timestamp in the restaurant's timezone. */
export function isoToDateInput(iso: string | null | undefined, timeZone = regionalTimeZone()): string {
  if (!iso) return ""
  return new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(iso))
}

/** "5285105870986488" → "5285 1058 7098 6488" (the way it is printed on the card). */
export function formatCardNumber(number: string): string {
  return number.replace(/\D/g, "").replace(/(\d{4})(?=\d)/g, "$1 ")
}
