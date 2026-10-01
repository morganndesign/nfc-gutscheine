"use client"

import { QrCode } from "lucide-react"
import { cn } from "@/lib/utils"
import { formatMoney } from "@/lib/money"
import { formatDate } from "@/lib/format"
import type { VoucherKind, VoucherStatus } from "@/lib/api/types"
import { useT } from "@/lib/i18n"

/** A wallet-style rendering of a voucher for staff screens. Guests never see the voucher number. */
export function VoucherVisual({
  restaurantName,
  kind,
  balance,
  currency,
  expiresAt,
  status,
  brandColor = "#18181b",
  className,
}: {
  restaurantName: string
  kind: VoucherKind
  balance: number
  currency: string
  expiresAt: string | null
  status: VoucherStatus
  brandColor?: string
  className?: string
}) {
  const t = useT()
  const muted = status !== "active"
  return (
    <div
      className={cn(
        "relative aspect-[1.586] w-full max-w-sm overflow-hidden rounded-2xl p-5 text-white shadow-xl shadow-black/10 transition",
        muted && "grayscale-[60%]",
        className,
      )}
      style={{ background: `linear-gradient(135deg, ${brandColor} 0%, color-mix(in oklch, ${brandColor} 70%, black) 100%)` }}
    >
      <div className="pointer-events-none absolute -top-16 -right-16 size-56 rounded-full bg-white/10 blur-2xl" />
      <div className="relative flex h-full flex-col justify-between">
        <div className="flex items-start justify-between">
          <div>
            <p className="text-xs tracking-widest text-white/70 uppercase">{kind === "digital" ? t("voucherVisual.digital") : t("voucherVisual.card")}</p>
            <p className="mt-0.5 text-base font-semibold">{restaurantName}</p>
          </div>
          <QrCode className="size-6 text-white/80" aria-hidden />
        </div>
        <div>
          <p className="tabular text-3xl font-semibold tracking-tight">{formatMoney(balance, currency)}</p>
          <p className="mt-2 text-xs text-white/75">{expiresAt ? t("voucherVisual.validUntil", { date: formatDate(expiresAt) }) : t("vouchers.noExpiry")}</p>
        </div>
      </div>
    </div>
  )
}
