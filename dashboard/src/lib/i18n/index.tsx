"use client"

import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react"
import { api } from "@/lib/api/client"
import { useAuth } from "@/lib/auth"
import { CATALOGS, type MessageKey } from "@/lib/i18n/catalog"
import { currentLanguage, setCurrentLanguage } from "@/lib/i18n/state"
import { format, intlTag, toLanguage, type Language, type Params } from "@/lib/i18n/format"

/**
 * The staff UI language: German (default, Austria first), English or Bosnian/Croatian/Serbian. Signed in, it is the
 * user's own choice (saved on the account, the waiter app uses the same one); before sign-in, the browser's last
 * choice. Guest-facing texts (printed voucher, e-mails) follow the restaurant's language instead.
 */
export const LANGUAGES: { code: Language; label: string }[] = [
  { code: "de", label: "Deutsch" },
  { code: "en", label: "English" },
  { code: "bs", label: "Bosanski · Hrvatski · Srpski" },
]

const STORAGE_KEY = "gcp.language"

export type Translate = (key: MessageKey, params?: Params) => string

export function translate(language: Language, key: MessageKey, params?: Params): string {
  return format(language, CATALOGS[language][key] ?? CATALOGS.en[key] ?? key, params)
}

/** `t()` outside React, in the current UI language. */
export function tr(key: MessageKey, params?: Params): string {
  return translate(currentLanguage(), key, params)
}

interface I18nValue {
  language: Language
  t: Translate
  setLanguage: (language: Language) => Promise<void>
}

const I18nContext = createContext<I18nValue | null>(null)

function storedLanguage(): Language | null {
  try {
    const v = window.localStorage.getItem(STORAGE_KEY)
    return v ? toLanguage(v) : null
  } catch {
    return null
  }
}

export function I18nProvider({ children }: { children: ReactNode }) {
  const { user, refresh } = useAuth()
  const [local, setLocal] = useState<Language | null>(null)

  useEffect(() => setLocal(storedLanguage()), [])

  const language: Language = user ? toLanguage(user.locale) : (local ?? "de")
  setCurrentLanguage(language)

  useEffect(() => {
    document.documentElement.lang = language
  }, [language])

  const setLanguage = useCallback(
    async (next: Language) => {
      try {
        window.localStorage.setItem(STORAGE_KEY, next)
      } catch {
        // Private mode: the choice lasts for this page only.
      }
      setLocal(next)
      if (user) {
        await api("/auth/profile", { method: "PUT", body: { locale: next } })
        await refresh()
      }
    },
    [user, refresh],
  )

  const t = useCallback<Translate>((key, params) => translate(language, key, params), [language])
  const value = useMemo(() => ({ language, t, setLanguage }), [language, t, setLanguage])

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>
}

export function useI18n(): I18nValue {
  const value = useContext(I18nContext)
  if (!value) throw new Error("useI18n outside I18nProvider")
  return value
}

export function useT(): Translate {
  return useI18n().t
}

export type { Language, MessageKey, Params }
export { currentLanguage, intlTag, toLanguage }

/** Whether a key exists (API error codes that have a translation). */
export function hasMessage(key: string): key is MessageKey {
  return key in CATALOGS.en
}
