"use client"

import { useEffect, useState } from "react"
import { Skeleton } from "@/components/ui/skeleton"
import { apiRaw } from "@/lib/api/client"
import { cn } from "@/lib/utils"

/** Renders the card's QR code (SVG generated server-side; contains only the card URL). */
export function CardQr({ cardId, className }: { cardId: string; className?: string }) {
  const [src, setSrc] = useState<string | null>(null)
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    let url: string | null = null
    let cancelled = false
    apiRaw(`/cards/${cardId}/qr`)
      .then((r) => r.blob())
      .then((blob) => {
        if (cancelled) return
        url = URL.createObjectURL(blob)
        setSrc(url)
      })
      .catch(() => !cancelled && setFailed(true))
    return () => {
      cancelled = true
      if (url) URL.revokeObjectURL(url)
    }
  }, [cardId])

  if (failed) return <div className={cn("bg-muted text-muted-foreground flex items-center justify-center rounded-xl text-xs", className)}>QR unavailable</div>
  if (!src) return <Skeleton className={cn("rounded-xl", className)} />
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={src} alt="QR code of the gift card" className={cn("rounded-xl bg-white p-2", className)} />
}
