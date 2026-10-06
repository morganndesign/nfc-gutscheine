"use client"

import { use, useEffect, useMemo, useRef, useState } from "react"
import { Gift, Loader2, Lock } from "lucide-react"
import { MoneyInput } from "@/components/common/money-input"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Checkbox } from "@/components/ui/checkbox"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Skeleton } from "@/components/ui/skeleton"
import { Textarea } from "@/components/ui/textarea"
import { ApiError, api, errorMessage } from "@/lib/api/client"
import type { PublicShop } from "@/lib/api/types"
import { useI18n } from "@/lib/i18n"
import { formatMoney, parseMoneyInput } from "@/lib/money"
import { cn } from "@/lib/utils"
import { ShopFrame } from "./shop-frame"

/**
 * A restaurant's voucher shop (online sales, decision 2026-10-06): the guest chooses an amount, says for whom, and
 * pays on Stripe's page. The voucher is e-mailed as a PDF once Stripe confirms the payment; a gift card, when
 * offered, is picked up at the restaurant.
 */
export default function ShopPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = use(params)
  const { t, language } = useI18n()
  const [shop, setShop] = useState<PublicShop | null>(null)
  const [closed, setClosed] = useState(false)
  const [amount, setAmount] = useState<number | "custom" | null>(null)
  const [custom, setCustom] = useState("")
  const [recipient, setRecipient] = useState("")
  const [message, setMessage] = useState("")
  const [email, setEmail] = useState("")
  const [name, setName] = useState("")
  const [pickup, setPickup] = useState(false)
  const [accepted, setAccepted] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const trap = useRef<HTMLInputElement>(null)
  const cancelled = typeof window !== "undefined" && new URLSearchParams(window.location.search).has("cancelled")

  useEffect(() => {
    api<{ data: PublicShop }>(`/shop/${encodeURIComponent(slug)}`)
      .then((r) => {
        setShop(r.data)
        setAmount(r.data.amounts[Math.min(1, r.data.amounts.length - 1)] ?? (r.data.custom_amount ? "custom" : null))
      })
      .catch(() => setClosed(true))
  }, [slug])

  const money = (cents: number) => formatMoney(cents, shop?.currency ?? "EUR")
  const value = useMemo(() => (amount === "custom" ? parseMoneyInput(custom) : amount), [amount, custom])
  const valid = shop !== null && value !== null && value >= shop.min_amount && value <= shop.max_amount && /^\S+@\S+\.\S+$/.test(email.trim()) && accepted

  if (closed) {
    return (
      <ShopFrame shop={null}>
        <Card>
          <CardContent className="space-y-2 py-10 text-center">
            <Gift className="text-muted-foreground mx-auto size-10" aria-hidden />
            <h1 className="text-xl font-semibold">{t("shop.closed.title")}</h1>
            <p className="text-muted-foreground text-sm">{t("shop.closed.body")}</p>
          </CardContent>
        </Card>
      </ShopFrame>
    )
  }
  if (!shop) {
    return (
      <ShopFrame shop={null}>
        <Skeleton className="h-[32rem] w-full rounded-2xl" />
      </ShopFrame>
    )
  }

  return (
    <ShopFrame shop={shop}>
      <Card className="overflow-hidden">
        <div className="px-6 pt-6 pb-2" style={{ borderTop: "6px solid var(--shop-brand)" }}>
          <h1 className="text-2xl font-semibold tracking-tight">{shop.headline ?? shop.restaurant.name}</h1>
          {shop.intro ? <p className="text-muted-foreground mt-2 text-sm whitespace-pre-line">{shop.intro}</p> : null}
          <p className="text-muted-foreground mt-2 text-xs">
            {shop.validity_months ? t("shop.validity", { months: shop.validity_months }) : t("shop.noExpiry")}
          </p>
        </div>
        <CardContent className="space-y-5 pt-4">
          {cancelled ? (
            <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:bg-amber-500/10 dark:text-amber-200">{t("shop.cancelled")}</p>
          ) : null}
          <form
            className="space-y-5"
            onSubmit={async (e) => {
              e.preventDefault()
              if (!valid || value === null) return
              setBusy(true)
              setError(null)
              try {
                const r = await api<{ data: { checkout_url: string } }>(`/shop/${encodeURIComponent(slug)}/orders`, {
                  method: "POST",
                  body: {
                    amount: value,
                    buyer_email: email.trim(),
                    buyer_name: name.trim() || null,
                    recipient_name: recipient.trim() || null,
                    gift_message: message.trim() || null,
                    card_pickup: shop.card_pickup && pickup,
                    accept_terms: accepted,
                    locale: language,
                    website: trap.current?.value || undefined,
                  },
                })
                window.location.assign(r.data.checkout_url)
              } catch (err) {
                setError(err instanceof ApiError && err.status === 429 ? t("shop.tooMany") : errorMessage(err, t("shop.error")))
                setBusy(false)
              }
            }}
          >
            <fieldset className="space-y-2">
              <legend className="text-sm font-medium">{t("shop.amount")}</legend>
              <div className="grid grid-cols-3 gap-2">
                {shop.amounts.map((a) => (
                  <button
                    key={a}
                    type="button"
                    aria-pressed={amount === a}
                    onClick={() => setAmount(a)}
                    className={cn(
                      "rounded-xl border px-3 py-3 text-base font-semibold tabular-nums transition",
                      amount === a ? "border-transparent text-white" : "bg-background hover:border-foreground/30",
                    )}
                    style={amount === a ? { background: "var(--shop-brand)" } : undefined}
                  >
                    {money(a)}
                  </button>
                ))}
                {shop.custom_amount ? (
                  <button
                    type="button"
                    aria-pressed={amount === "custom"}
                    onClick={() => setAmount("custom")}
                    className={cn(
                      "rounded-xl border px-3 py-3 text-sm font-medium transition",
                      amount === "custom" ? "border-transparent text-white" : "bg-background hover:border-foreground/30",
                    )}
                    style={amount === "custom" ? { background: "var(--shop-brand)" } : undefined}
                  >
                    {t("shop.custom")}
                  </button>
                ) : null}
              </div>
              {amount === "custom" ? (
                <div className="space-y-1">
                  <MoneyInput aria-label={t("shop.custom")} value={custom} onChange={(e) => setCustom(e.target.value)} autoFocus />
                  <p className="text-muted-foreground text-xs">{t("shop.customHint", { min: money(shop.min_amount), max: money(shop.max_amount) })}</p>
                </div>
              ) : null}
            </fieldset>

            <div className="space-y-2">
              <Label htmlFor="shop-recipient">{t("shop.recipient")}</Label>
              <Input id="shop-recipient" maxLength={120} value={recipient} onChange={(e) => setRecipient(e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="shop-message">{t("shop.message")}</Label>
              <Textarea id="shop-message" maxLength={300} value={message} onChange={(e) => setMessage(e.target.value)} />
              <p className="text-muted-foreground text-xs">{t("shop.messageHint")}</p>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="shop-email">{t("shop.email")}</Label>
                <Input
                  id="shop-email"
                  type="email"
                  required
                  autoComplete="email"
                  maxLength={254}
                  aria-describedby="shop-email-hint"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                />
                <p id="shop-email-hint" className="text-muted-foreground text-xs">
                  {t("shop.emailHint")}
                </p>
              </div>
              <div className="space-y-2">
                <Label htmlFor="shop-name">{t("shop.name")}</Label>
                <Input id="shop-name" autoComplete="name" maxLength={120} value={name} onChange={(e) => setName(e.target.value)} />
              </div>
            </div>
            {/* A field people never see: a bot fills it, the server then refuses the order. */}
            <input ref={trap} type="text" name="website" tabIndex={-1} autoComplete="off" className="hidden" aria-hidden />

            {shop.card_pickup ? (
              <label className="flex items-start gap-3 rounded-xl border p-3 text-sm">
                <Checkbox checked={pickup} onCheckedChange={(v) => setPickup(v === true)} className="mt-0.5" />
                <span>
                  <span className="font-medium">{t("shop.cardPickup")}</span>
                  <span className="text-muted-foreground mt-1 block text-xs">{t("shop.cardPickupHint")}</span>
                </span>
              </label>
            ) : null}

            <label className="flex items-start gap-3 text-sm">
              <Checkbox checked={accepted} onCheckedChange={(v) => setAccepted(v === true)} className="mt-0.5" />
              <span>
                {t("shop.accept", { restaurant: shop.restaurant.name })}{" "}
                {shop.terms_url ? (
                  <a href={shop.terms_url} target="_blank" rel="noopener" className="underline">
                    {t("shop.terms")}
                  </a>
                ) : null}
              </span>
            </label>

            {error ? <p role="alert" className="bg-destructive/10 text-destructive rounded-lg px-3 py-2 text-sm">{error}</p> : null}
            <Button type="submit" size="lg" className="w-full text-white" style={{ background: "var(--shop-brand)" }} disabled={!valid || busy}>
              {busy ? <Loader2 className="animate-spin" /> : <Lock />}
              {busy ? t("shop.paying") : t("shop.pay", { amount: value !== null ? money(value) : "" })}
            </Button>
            <p className="text-muted-foreground text-center text-xs">{t("shop.secure")}</p>
          </form>
        </CardContent>
      </Card>
    </ShopFrame>
  )
}
