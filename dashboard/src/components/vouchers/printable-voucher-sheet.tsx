"use client"

import { useEffect, useRef, useState } from "react"
import { createPortal } from "react-dom"
import { PAPER, ScaledArtwork, VoucherArtwork, type VoucherContent, type VoucherLook } from "@/components/vouchers/voucher-artwork"
import { useLogoImage } from "@/lib/api/hooks"
import type { RestaurantSettings } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"

/** The restaurant's voucher design and its logo (ready = the logo, if any, is loaded and may be printed). */
export function useVoucherLook(settings?: RestaurantSettings | null): { look: VoucherLook; logo: string | null; ready: boolean } {
  const { user } = useAuth()
  const s = settings ?? user?.restaurant?.settings
  const logo = useLogoImage(s?.logo_url)
  const design = s?.voucher_design
  return {
    look: {
      template: design?.template ?? "classic",
      format: design?.format ?? "a5",
      brandColor: s?.brand_color ?? "#18181B",
      accentColor: design?.accent_color ?? "#C9A86A",
      headline: design?.headline ?? null,
      message: design?.message ?? null,
    },
    logo: logo.data ?? null,
    ready: !s?.logo_url || logo.isSuccess || logo.isError,
  }
}

/** Width of the parent element in pixels (previews). */
export function useWidth<T extends HTMLElement>(fallback = 360): [React.RefObject<T | null>, number] {
  const ref = useRef<T>(null)
  const [width, setWidth] = useState(fallback)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new ResizeObserver(([entry]) => setWidth(Math.max(160, Math.floor(entry.contentRect.width))))
    observer.observe(el)
    return () => observer.disconnect()
  }, [])
  return [ref, width]
}

/**
 * The voucher just sold (or re-issued): a preview on screen, and the exact page for `window.print()`. Printing shows
 * only the voucher, at its paper size, edge to edge and in colour; "Save as PDF" in the print dialog gives a file to
 * send by e-mail. The QR exists only in this response: it is never stored or fetched again.
 */
export function PrintableVoucherSheet({
  qrSvg,
  recipientName,
  expiresAt,
  value,
  currency,
  maxWidth = 420,
}: {
  qrSvg: string
  recipientName?: string | null
  expiresAt: string | null
  /** The value sold, in cents. */
  value: number
  currency: string
  maxWidth?: number
}) {
  const { user } = useAuth()
  const restaurant = user?.restaurant
  const { look, logo } = useVoucherLook()
  const [ref, width] = useWidth<HTMLDivElement>()

  const content: VoucherContent = {
    restaurantName: restaurant?.name ?? "",
    logo,
    locale: restaurant?.locale,
    value,
    currency,
    recipientName,
    expiresAt,
    qrSvg,
  }

  return (
    <div ref={ref} className="w-full" style={{ maxWidth }}>
      <ScaledArtwork look={look} content={content} width={Math.min(width, maxWidth)} />
      <VoucherPrintPage look={look} content={content} />
    </div>
  )
}

/** The page `window.print()` prints: only this voucher, at its paper size, without margins. */
export function VoucherPrintPage({ look, content }: { look: VoucherLook; content: VoucherContent }) {
  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])
  if (!mounted) return null
  const paper = PAPER[look.format]
  return createPortal(
    <div className="voucher-print-root" aria-hidden>
      <style>{`@page { size: ${paper.width}mm ${paper.height}mm; margin: 0; }`}</style>
      <VoucherArtwork look={look} content={content} />
    </div>,
    document.body,
  )
}
