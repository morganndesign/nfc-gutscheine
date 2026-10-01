"use client"

import type { ReactNode } from "react"
import { CreditCard } from "lucide-react"
import { LANGUAGES, useI18n, type Language } from "@/lib/i18n"
import { cn } from "@/lib/utils"

const SHORT: Record<Language, string> = { de: "Deutsch", en: "English", bs: "BHS" }

/** Before sign-in the choice is kept in this browser; after sign-in the account's language applies. */
function LanguageSwitcher() {
  const { language, setLanguage, t } = useI18n()
  return (
    <div role="group" aria-label={t("common.language")} className="flex items-center justify-center gap-1">
      {LANGUAGES.map((l) => (
        <button
          key={l.code}
          type="button"
          lang={l.code}
          title={l.label}
          aria-pressed={language === l.code}
          onClick={() => void setLanguage(l.code)}
          className={cn(
            "focus-visible:ring-ring/50 rounded-md px-2 py-1 text-xs transition outline-none focus-visible:ring-[3px]",
            language === l.code ? "text-foreground bg-muted font-medium" : "text-muted-foreground hover:text-foreground",
          )}
        >
          {SHORT[l.code]}
        </button>
      ))}
    </div>
  )
}

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <div className="bg-surface flex min-h-dvh flex-col">
      <main className="flex flex-1 items-center justify-center px-4 py-12">
        <div className="w-full max-w-sm">
          <div className="mb-8 flex flex-col items-center gap-3 text-center">
            <div className="bg-primary text-primary-foreground flex size-12 items-center justify-center rounded-2xl shadow-sm">
              <CreditCard className="size-6" aria-hidden />
            </div>
            <span className="text-muted-foreground text-sm font-medium">GiftCard Pro</span>
          </div>
          {children}
          <div className="mt-6">
            <LanguageSwitcher />
          </div>
        </div>
      </main>
      <footer className="text-muted-foreground pb-6 text-center text-xs">© {new Date().getFullYear()} GiftCard Pro</footer>
    </div>
  )
}
