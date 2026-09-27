/**
 * Regional settings of the restaurant the user works for. Set once from the session
 * (AuthProvider) so every money/date formatter uses the restaurant's locale and timezone
 * instead of whatever the browser happens to be configured with.
 */
let currentLocale = "de-AT"
let currentTimeZone: string | undefined = "Europe/Vienna"

export function setRegional(locale: string | undefined, timeZone: string | undefined): void {
  currentLocale = locale || "de-AT"
  currentTimeZone = timeZone || undefined
}

export function regionalLocale(): string {
  return currentLocale
}

export function regionalTimeZone(): string | undefined {
  return currentTimeZone
}
