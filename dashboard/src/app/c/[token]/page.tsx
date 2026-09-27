"use client"

import { use } from "react"
import { CreditCard, Loader2 } from "lucide-react"
import { StatusBadge } from "@/components/common/status-badge"
import { WaiterShell } from "@/components/waiter/waiter-shell"
import { WaiterTerminal } from "@/components/waiter/terminal"
import { FullScreenLoader } from "@/components/layout/auth-guard"
import { usePublicCard } from "@/lib/api/hooks"
import { useAuth } from "@/lib/auth"
import { formatDate } from "@/lib/format"
import { formatMoney } from "@/lib/money"
import { guestCopy } from "@/lib/guest-copy"

/**
 * The URL stored on every card. Staff (logged in with scan permission) land directly in the
 * waiter terminal with the card opened; everybody else sees the anonymous balance page.
 */
function PublicBalance({ token }: { token: string }) {
  const { data, isLoading, error } = usePublicCard(token, true)

  if (isLoading) {
    return (
      <div className="flex min-h-dvh items-center justify-center">
        <Loader2 className="text-muted-foreground size-6 animate-spin" />
      </div>
    )
  }

  if (error || !data) {
    const t = guestCopy(typeof navigator !== "undefined" ? navigator.language : null)
    return (
      <div className="bg-surface flex min-h-dvh flex-col items-center justify-center gap-3 px-6 text-center">
        <span className="bg-muted text-muted-foreground flex size-14 items-center justify-center rounded-2xl">
          <CreditCard className="size-7" aria-hidden />
        </span>
        <h1 className="text-lg font-semibold">{t.notFoundTitle}</h1>
        <p className="text-muted-foreground max-w-xs text-sm">{t.notFoundText}</p>
      </div>
    )
  }

  const locale = data.locale ?? "de-AT"
  const t = guestCopy(locale)

  return (
    <div className="bg-surface flex min-h-dvh flex-col items-center justify-center px-6 py-12">
      <div className="w-full max-w-sm space-y-6 text-center">
        <div
          className="mx-auto flex size-14 items-center justify-center rounded-2xl text-white shadow-lg"
          style={{ background: data.brand_color ?? "#18181b" }}
        >
          <CreditCard className="size-7" aria-hidden />
        </div>
        <div>
          <p className="text-muted-foreground text-sm">{t.giftCard}</p>
          <h1 className="text-xl font-semibold text-balance">{data.restaurant_name}</h1>
        </div>
        {data.balance_visible ? (
          <div className="bg-card space-y-3 rounded-3xl border p-6 shadow-sm">
            <p className="text-muted-foreground text-sm">{t.balance}</p>
            <p className="tabular text-5xl font-semibold tracking-tight">{formatMoney(data.balance ?? 0, data.currency ?? "EUR", locale)}</p>
            {data.status ? <StatusBadge status={data.status} label={t.status[data.status]} /> : null}
            <div className="text-muted-foreground space-y-0.5 pt-2 text-sm">
              <p className="card-number">{data.card_number}</p>
              <p>{data.expires_at ? `${t.validUntil} ${formatDate(data.expires_at, locale)}` : t.noExpiry}</p>
            </div>
          </div>
        ) : (
          <p className="bg-card text-muted-foreground rounded-3xl border p-6 text-sm">{t.askStaff}</p>
        )}
        <p className="text-muted-foreground text-xs">Powered by GiftCard Pro</p>
      </div>
    </div>
  )
}

export default function CardLinkPage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = use(params)
  const { user, isLoading, can } = useAuth()

  if (isLoading) return <FullScreenLoader />

  if (user && user.restaurant && can("cards.scan")) {
    return (
      <WaiterShell>
        <WaiterTerminal initialToken={typeof window !== "undefined" ? window.location.href : token} />
      </WaiterShell>
    )
  }

  return <PublicBalance token={token} />
}
