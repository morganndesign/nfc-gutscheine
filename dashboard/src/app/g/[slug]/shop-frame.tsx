"use client"

import type { CSSProperties, ReactNode } from "react"
import { LANGUAGES, useI18n } from "@/lib/i18n"
import type { PublicShop } from "@/lib/api/types"
import { cn } from "@/lib/utils"

const SHORT = { de: "DE", en: "EN", bs: "BHS" } as const

/** The frame of a restaurant's public shop: its logo, its color, the language choice and the legal links. */
export function ShopFrame({ shop, children }: { shop: PublicShop | null; children: ReactNode }) {
  const { language, setLanguage, t } = useI18n()
  const brand = shop?.brand_color ?? "#0F172A"

  return (
    <div className="bg-muted/40 min-h-dvh" style={{ "--shop-brand": brand } as CSSProperties}>
      <div className="mx-auto flex min-h-dvh max-w-lg flex-col px-4 py-6 sm:py-10">
        <header className="mb-6 flex items-center justify-between gap-3">
          <div className="flex min-w-0 items-center gap-3">
            {shop?.logo_url ? (
              // eslint-disable-next-line @next/next/no-img-element -- the restaurant's own logo
              <img src={shop.logo_url} alt="" className="size-12 rounded-xl bg-white object-contain p-1" />
            ) : (
              <span aria-hidden className="size-3 rounded-full" style={{ background: brand }} />
            )}
            <span className="truncate text-lg font-semibold">{shop?.restaurant.name}</span>
          </div>
          <div role="group" aria-label={t("common.language")} className="flex gap-1">
            {LANGUAGES.map((l) => (
              <button
                key={l.code}
                type="button"
                lang={l.code}
                aria-pressed={language === l.code}
                onClick={() => void setLanguage(l.code)}
                className={cn("rounded-md px-2 py-1 text-xs", language === l.code ? "bg-background font-medium shadow-sm" : "text-muted-foreground")}
              >
                {SHORT[l.code]}
              </button>
            ))}
          </div>
        </header>
        <main className="flex-1">{children}</main>
        <footer className="text-muted-foreground mt-8 flex flex-wrap items-center justify-center gap-x-4 gap-y-1 text-xs">
          {shop?.terms_url ? (
            <a href={shop.terms_url} target="_blank" rel="noopener" className="hover:underline">
              {t("shop.terms")}
            </a>
          ) : null}
          {shop?.imprint_url ? (
            <a href={shop.imprint_url} target="_blank" rel="noopener" className="hover:underline">
              {t("shop.imprint")}
            </a>
          ) : null}
          <span>{t("shop.poweredBy")}</span>
        </footer>
      </div>
    </div>
  )
}
