import type { Language } from "@/lib/i18n/format"

/** The current UI language for code outside React (API client, formatters); set by the I18nProvider during render. */
let current: Language = "de"

export function currentLanguage(): Language {
  return current
}

export function setCurrentLanguage(language: Language): void {
  current = language
}
