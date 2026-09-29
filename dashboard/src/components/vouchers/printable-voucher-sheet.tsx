"use client"

import { guestCopy } from "@/lib/guest-copy"
import { formatDate } from "@/lib/format"
import { cn } from "@/lib/utils"

/**
 * The printable voucher (P0-03): the QR, the restaurant and its branding. No voucher number and no value are
 * printed (architecture §5.2, §6.4): the QR is the voucher, the balance lives on the server. The QR is shown only
 * in the sale response, so this sheet exists only right after the sale.
 */
export function PrintableVoucherSheet({
  qrSvg,
  restaurantName,
  brandColor,
  locale,
  recipientName,
  expiresAt,
  className,
}: {
  qrSvg: string
  restaurantName: string
  brandColor?: string
  locale?: string
  recipientName?: string | null
  expiresAt: string | null
  className?: string
}) {
  const copy = guestCopy(locale)
  const src = `data:image/svg+xml;base64,${typeof window === "undefined" ? "" : window.btoa(unescape(encodeURIComponent(qrSvg)))}`

  return (
    <section className={cn("print-sheet mx-auto w-full max-w-md overflow-hidden rounded-2xl border bg-white text-zinc-900 shadow-sm", className)}>
      <div className="px-8 py-6 text-white" style={{ background: brandColor ?? "#18181b" }}>
        <p className="text-xs tracking-widest uppercase opacity-80">{copy.voucher}</p>
        <p className="mt-1 text-2xl font-semibold">{restaurantName}</p>
        {recipientName ? (
          <p className="mt-1 text-sm opacity-90">
            {copy.for} {recipientName}
          </p>
        ) : null}
      </div>
      <div className="flex flex-col items-center gap-4 px-8 py-8">
        {/* eslint-disable-next-line @next/next/no-img-element -- generated QR, never optimised or cached */}
        <img src={src} alt="QR code" className="size-64" />
        <p className="text-center text-sm">{copy.howTo}</p>
        <p className="text-center text-xs text-zinc-500">{expiresAt ? `${copy.validUntil} ${formatDate(expiresAt)}` : copy.noExpiry}</p>
        <p className="text-center text-xs text-zinc-500">{copy.keepSafe}</p>
      </div>
    </section>
  )
}
