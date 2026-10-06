"use client"

import { use, useEffect, useState } from "react"
import { CheckCircle2, Loader2, XCircle } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { api, ApiError } from "@/lib/api/client"
import type { OnlineOrderStatus, PublicShop } from "@/lib/api/types"
import { useT } from "@/lib/i18n"
import { formatMoney } from "@/lib/money"
import { ShopFrame } from "../shop-frame"

type OrderState = { status: OnlineOrderStatus; amount: number; currency: string; restaurant: string; card_pickup: boolean; email: string }

/**
 * The buyer's page after Stripe: the voucher is created by Stripe's confirmation (the webhook), not by this page.
 * It asks until the order is paid (usually seconds) and then says where the voucher went.
 */
export default function ThanksPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = use(params)
  const t = useT()
  const [shop, setShop] = useState<PublicShop | null>(null)
  const [order, setOrder] = useState<OrderState | null>(null)
  const [missing, setMissing] = useState(false)
  const [slow, setSlow] = useState(false)

  useEffect(() => {
    api<{ data: PublicShop }>(`/shop/${encodeURIComponent(slug)}`)
      .then((r) => setShop(r.data))
      .catch(() => undefined)
  }, [slug])

  useEffect(() => {
    const query = new URLSearchParams(window.location.search)
    const id = query.get("order")
    const token = query.get("token")
    if (!id || !token) {
      setMissing(true)
      return
    }
    let stop = false
    let tries = 0
    let failures = 0
    const poll = async () => {
      try {
        const r = await api<{ data: OrderState }>(`/shop/orders/${encodeURIComponent(id)}`, { query: { token } })
        if (stop) return
        failures = 0
        setOrder(r.data)
        if (r.data.status !== "pending") return
        if (tries++ < 40) setTimeout(() => void poll(), 2500)
        else setSlow(true)
      } catch (error) {
        if (stop) return
        // A wrong link is final; a dropped connection is tried again.
        if ((error instanceof ApiError && error.status === 404) || ++failures > 3) setMissing(true)
        else setTimeout(() => void poll(), 2500)
      }
    }
    void poll()
    return () => {
      stop = true
    }
  }, [])

  const paid = order?.status === "paid"
  const refunded = order?.status === "refunded" || order?.status === "disputed"
  const failed = missing || (order !== null && order.status !== "paid" && order.status !== "pending")
  const title = paid
    ? t("shop.thanks.title")
    : missing
      ? t("shop.thanks.unknown")
      : refunded
        ? t("shop.thanks.refunded")
        : failed
          ? t("shop.thanks.failed")
          : t("shop.thanks.pending")

  return (
    <ShopFrame shop={shop}>
      <Card>
        <CardContent className="space-y-4 py-10 text-center">
          {paid ? (
            <CheckCircle2 className="mx-auto size-12 text-emerald-600" aria-hidden />
          ) : failed ? (
            <XCircle className="text-muted-foreground mx-auto size-12" aria-hidden />
          ) : (
            <Loader2 className="text-muted-foreground mx-auto size-12 animate-spin" aria-hidden />
          )}
          <h1 className="text-2xl font-semibold">{title}</h1>
          <div role="status" aria-live="polite" className="text-muted-foreground space-y-2 text-sm">
            {paid && order ? (
              <>
                <p>{t("shop.thanks.paid", { amount: formatMoney(order.amount, order.currency), email: order.email })}</p>
                {order.card_pickup ? <p>{t("shop.thanks.pickup")}</p> : null}
              </>
            ) : missing ? (
              <p>{t("shop.thanks.unknownHint")}</p>
            ) : !failed ? (
              <p>{slow ? t("shop.thanks.slow") : t("shop.thanks.pendingHint")}</p>
            ) : null}
          </div>
          <Button asChild variant="outline">
            <a href={`/g/${encodeURIComponent(slug)}`}>{t("shop.thanks.back")}</a>
          </Button>
        </CardContent>
      </Card>
    </ShopFrame>
  )
}
