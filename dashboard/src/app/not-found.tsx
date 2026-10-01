"use client"

import Link from "next/link"
import { Button } from "@/components/ui/button"
import { useT } from "@/lib/i18n"

export default function NotFound() {
  const t = useT()
  return (
    <div className="flex min-h-dvh flex-col items-center justify-center gap-4 px-6 text-center">
      <p className="text-muted-foreground text-sm font-medium">404</p>
      <h1 className="text-2xl font-semibold tracking-tight">{t("notFound.title")}</h1>
      <p className="text-muted-foreground max-w-sm text-sm">{t("notFound.text")}</p>
      <Button asChild>
        <Link href="/">{t("notFound.home")}</Link>
      </Button>
    </div>
  )
}
