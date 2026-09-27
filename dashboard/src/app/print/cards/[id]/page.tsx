"use client"

import { use } from "react"
import Link from "next/link"
import { ArrowLeft, Printer } from "lucide-react"
import { CardQr } from "@/components/cards/card-qr"
import { AuthGuard } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { useCard } from "@/lib/api/hooks"
import { useAuth } from "@/lib/auth"
import { formatDate } from "@/lib/format"
import { formatMoney } from "@/lib/money"
import { guestCopy } from "@/lib/guest-copy"

/**
 * Print layout in ISO/IEC 7810 ID-1 size (85.60 × 53.98 mm): front with value, back with QR code.
 */
function PrintContent({ id }: { id: string }) {
  const { user } = useAuth()
  const { data: card } = useCard(id)
  const brand = user?.restaurant?.settings.brand_color ?? "#18181b"
  const locale = user?.restaurant?.locale ?? "de-AT"
  const t = guestCopy(locale)

  if (!card) return <Skeleton className="m-8 h-64 w-96" />

  return (
    <div className="bg-surface min-h-dvh p-8 print:bg-white print:p-0">
      <style>{`@page { size: A4; margin: 15mm; }`}</style>
      <div className="no-print mb-6 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="sm" asChild className="-ml-2">
            <Link href={`/cards/${card.id}`}>
              <ArrowLeft /> Back to card
            </Link>
          </Button>
          <p className="text-muted-foreground text-sm">Print at 100 % scale (no “fit to page”), then cut along the edges.</p>
        </div>
        <Button onClick={() => window.print()}>
          <Printer /> Print
        </Button>
      </div>
      <div className="flex flex-wrap gap-6">
        <div
          className="flex h-[53.98mm] w-[85.6mm] flex-col justify-between rounded-[3mm] p-[5mm] text-white"
          style={{ background: brand, printColorAdjust: "exact", WebkitPrintColorAdjust: "exact" }}
        >
          <div>
            <p className="text-[7pt] tracking-[0.2em] uppercase opacity-75">{t.giftCard}</p>
            <p className="text-[12pt] font-semibold">{user?.restaurant?.name}</p>
          </div>
          <div>
            <p className="text-[20pt] leading-none font-semibold">{formatMoney(card.initial_value, card.currency, locale)}</p>
            {card.recipient_name ? (
              <p className="mt-1 text-[8pt] opacity-80">
                {t.for} {card.recipient_name}
              </p>
            ) : null}
          </div>
        </div>
        <div className="flex h-[53.98mm] w-[85.6mm] items-center gap-[4mm] rounded-[3mm] border border-zinc-300 bg-white p-[5mm] text-zinc-900">
          <CardQr cardId={card.id} className="size-[38mm] shrink-0 p-0" />
          <div className="space-y-[2mm] text-[7pt] leading-snug">
            <p className="card-number text-[8pt] font-semibold">{card.card_number_formatted}</p>
            <p>{card.expires_at ? `${t.validUntil} ${formatDate(card.expires_at, locale)}` : t.noExpiry}</p>
            <p className="text-zinc-500">{t.scanHint}</p>
          </div>
        </div>
      </div>
    </div>
  )
}

export default function PrintCardPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  return (
    <AuthGuard permission="cards.write_nfc">
      <PrintContent id={id} />
    </AuthGuard>
  )
}
