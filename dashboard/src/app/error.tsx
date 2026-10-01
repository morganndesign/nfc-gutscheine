"use client"

import { useEffect } from "react"
import { Button } from "@/components/ui/button"
import { useT } from "@/lib/i18n"

export default function GlobalError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  const t = useT()
  useEffect(() => {
    console.error(error)
  }, [error])

  return (
    <div className="flex min-h-dvh flex-col items-center justify-center gap-4 px-6 text-center">
      <h1 className="text-2xl font-semibold tracking-tight">{t("errorPage.title")}</h1>
      <p className="text-muted-foreground max-w-sm text-sm">{error.digest ? t("errorPage.textRef", { ref: error.digest }) : t("errorPage.text")}</p>
      <Button onClick={reset}>{t("errorPage.retry")}</Button>
    </div>
  )
}
