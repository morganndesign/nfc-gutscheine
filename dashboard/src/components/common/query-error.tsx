"use client"

import { AlertTriangle, RotateCcw } from "lucide-react"
import { Button } from "@/components/ui/button"
import { errorMessage } from "@/lib/api/client"
import { useT } from "@/lib/i18n"

/**
 * A list or page that could not be loaded. Never shown as "nothing here yet": an empty state while the server is
 * unreachable would tell the owner that vouchers or bookings do not exist.
 */
export function QueryError({ error, onRetry, fallback }: { error: unknown; onRetry?: () => void; fallback?: string }) {
  const t = useT()
  return (
    <div role="alert" className="flex flex-col items-center justify-center gap-3 px-6 py-16 text-center">
      <div className="bg-destructive/10 text-destructive flex size-12 items-center justify-center rounded-2xl">
        <AlertTriangle className="size-5" aria-hidden />
      </div>
      <p className="text-muted-foreground max-w-sm text-sm">{errorMessage(error, fallback ?? t("errors.loadFailed"))}</p>
      {onRetry ? (
        <Button variant="outline" onClick={onRetry}>
          <RotateCcw /> {t("errorPage.retry")}
        </Button>
      ) : null}
    </div>
  )
}
