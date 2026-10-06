"use client"

import { useEffect, useRef, useState } from "react"
import { Check, Copy, Download, ExternalLink, Loader2, RefreshCw } from "lucide-react"
import { toast } from "sonner"
import { useConfirm } from "@/components/common/confirm"
import { MoneyInput } from "@/components/common/money-input"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Skeleton } from "@/components/ui/skeleton"
import { Switch } from "@/components/ui/switch"
import { Textarea } from "@/components/ui/textarea"
import { QueryError } from "@/components/common/query-error"
import { ApiError, errorMessage } from "@/lib/api/client"
import { useConnectOnlinePayments, useOnlineAccountAction, useOnlineOrders, useOnlineShop, useUpdateOnlineShop } from "@/lib/api/hooks"
import type { OnlineOrder, OnlineShopState } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { centsToInput, formatMoney, parseMoneyInput } from "@/lib/money"
import { useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

function svgDataUrl(svg: string): string {
  const bytes = new TextEncoder().encode(svg)
  let binary = ""
  bytes.forEach((b) => (binary += String.fromCharCode(b)))
  return `data:image/svg+xml;base64,${btoa(binary)}`
}

/**
 * Settings › Online-Shop (owners, decision 2026-10-06): connect the restaurant's own Stripe account (never a key),
 * set what the shop offers, switch it on, and share it. Below: the latest online orders and the gift cards waiting
 * to be picked up.
 */
export function OnlineShopSettings() {
  const t = useT()
  const { data, error, refetch } = useOnlineShop()
  const action = useOnlineAccountAction()
  const refreshed = useRef(false)

  // Back from Stripe's onboarding (?stripe=return): read the account's state at once.
  useEffect(() => {
    if (refreshed.current || !data?.account) return
    if (new URLSearchParams(window.location.search).get("stripe") !== null) {
      refreshed.current = true
      action.mutate("refresh")
    }
  }, [data?.account, action])

  if (error && !data) return <QueryError error={error} onRetry={() => void refetch()} />
  if (!data) return <Skeleton className="h-96 w-full rounded-2xl" />

  return (
    <div className="space-y-4">
      <ConnectionCard state={data} />
      {data.account?.charges_enabled ? (
        <>
          <ShopForm state={data} />
          <ShareCard state={data} />
        </>
      ) : null}
      <Orders />
      <p className="text-muted-foreground px-1 text-xs">{t("online.description")}</p>
    </div>
  )
}

function ConnectionCard({ state }: { state: OnlineShopState }) {
  const t = useT()
  const confirm = useConfirm()
  const connect = useConnectOnlinePayments()
  const action = useOnlineAccountAction()
  const account = state.account

  const start = async () => {
    try {
      window.location.assign(await connect.mutateAsync())
    } catch (err) {
      toast.error(errorMessage(err))
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          {t("online.connect.title")}
          {account?.charges_enabled ? <Badge>{t("online.connect.ready")}</Badge> : null}
        </CardTitle>
        <CardDescription>
          {!state.configured
            ? t("online.notConfigured")
            : account === null
              ? t("online.connect.none")
              : account.charges_enabled
                ? account.payouts_enabled
                  ? t("online.connect.ready")
                  : t("online.connect.payoutsPending")
                : t("online.connect.pending")}
        </CardDescription>
      </CardHeader>
      <CardFooter className="flex flex-wrap gap-2">
        {state.configured && (account === null || !account.details_submitted || !account.charges_enabled) ? (
          <Button onClick={() => void start()} disabled={connect.isPending}>
            {connect.isPending ? <Loader2 className="animate-spin" /> : <ExternalLink />}
            {account === null ? t("online.connect.button") : t("online.connect.continue")}
          </Button>
        ) : null}
        {account !== null ? (
          <>
            <Button variant="outline" onClick={() => action.mutate("refresh", { onError: (e) => toast.error(errorMessage(e)) })} disabled={action.isPending}>
              <RefreshCw className={action.isPending ? "animate-spin" : undefined} /> {t("online.connect.refresh")}
            </Button>
            <Button
              variant="ghost"
              className="text-destructive"
              onClick={async () => {
                if (
                  await confirm({
                    title: t("online.connect.disconnectTitle"),
                    description: t("online.connect.disconnectBody"),
                    confirmLabel: t("online.connect.disconnect"),
                    destructive: true,
                  })
                ) {
                  action.mutate("disconnect", { onError: (e) => toast.error(errorMessage(e)) })
                }
              }}
            >
              {t("online.connect.disconnect")}
            </Button>
          </>
        ) : null}
      </CardFooter>
    </Card>
  )
}

function ShopForm({ state }: { state: OnlineShopState }) {
  const t = useT()
  const currency = useAuth().user?.restaurant?.currency ?? "EUR"
  const update = useUpdateOnlineShop()
  const shop = state.shop
  const [enabled, setEnabled] = useState(shop.enabled)
  const [amounts, setAmounts] = useState(shop.amounts.map((a) => centsToInput(a)).join(", "))
  const [custom, setCustom] = useState(shop.custom_amount)
  const [max, setMax] = useState(centsToInput(shop.max_amount))
  const [pickup, setPickup] = useState(shop.card_pickup)
  const [headline, setHeadline] = useState(shop.headline ?? "")
  const [intro, setIntro] = useState(shop.intro ?? "")
  const [terms, setTerms] = useState(shop.terms_url ?? "")
  const [imprint, setImprint] = useState(shop.imprint_url ?? "")
  const [errors, setErrors] = useState<Record<string, string>>({})

  const money = (cents: number) => formatMoney(cents, currency)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("online.shop.title")}</CardTitle>
      </CardHeader>
      <form
        className="contents"
        onSubmit={async (e) => {
          e.preventDefault()
          setErrors({})
          const parsed = amounts
            .split(/[;\n]|,(?=\s)/)
            .map((a) => parseMoneyInput(a.trim()))
            .filter((a): a is number => a !== null && a > 0)
          try {
            await update.mutateAsync({
              enabled,
              amounts: parsed,
              custom_amount: custom,
              max_amount: parseMoneyInput(max) ?? shop.max_amount,
              card_pickup: pickup,
              headline: headline.trim() || null,
              intro: intro.trim() || null,
              terms_url: terms.trim() || null,
              imprint_url: imprint.trim() || null,
            })
            toast.success(t("online.shop.saved"))
          } catch (err) {
            const fields = err instanceof ApiError ? err.fieldErrors : {}
            if (Object.keys(fields).length > 0) setErrors(Object.fromEntries(Object.entries(fields).map(([k, v]) => [k.split(".")[0], v[0] ?? ""])))
            else toast.error(errorMessage(err))
          }
        }}
      >
        <CardContent className="space-y-5">
          <Toggle id="shop-enabled" checked={enabled} onChange={setEnabled} label="online.shop.enabled" hint="online.shop.enabledHint" error={errors.enabled} />
          <div className="space-y-2">
            <Label htmlFor="shop-amounts">{t("online.shop.amounts")}</Label>
            <Input id="shop-amounts" value={amounts} onChange={(e) => setAmounts(e.target.value)} />
            <p className="text-muted-foreground text-xs">{t("online.shop.amountsHint")}</p>
            {errors.amounts ? <p className="text-destructive text-xs">{errors.amounts}</p> : null}
          </div>
          <Toggle
            id="shop-custom"
            checked={custom}
            onChange={setCustom}
            label="online.shop.custom"
            hintText={t("online.shop.customHint", { min: money(state.limits.min_amount), max: money(parseMoneyInput(max) ?? shop.max_amount) })}
          />
          <div className="space-y-2">
            <Label htmlFor="shop-max">{t("online.shop.max")}</Label>
            <MoneyInput id="shop-max" value={max} onChange={(e) => setMax(e.target.value)} className="max-w-40" />
            <p className="text-muted-foreground text-xs">{t("online.shop.maxHint", { max: money(state.limits.max_amount) })}</p>
            {errors.max_amount ? <p className="text-destructive text-xs">{errors.max_amount}</p> : null}
          </div>
          <Toggle id="shop-pickup" checked={pickup} onChange={setPickup} label="online.shop.cardPickup" hint="online.shop.cardPickupHint" />
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="shop-headline">{t("online.shop.headline")}</Label>
              <Input
                id="shop-headline"
                maxLength={120}
                value={headline}
                placeholder={t("online.shop.headlinePlaceholder")}
                onChange={(e) => setHeadline(e.target.value)}
              />
            </div>
            <div className="space-y-2 sm:col-span-2">
              <Label htmlFor="shop-intro">{t("online.shop.intro")}</Label>
              <Textarea id="shop-intro" maxLength={600} value={intro} onChange={(e) => setIntro(e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="shop-terms">{t("online.shop.terms")}</Label>
              <Input id="shop-terms" type="url" placeholder="https://" value={terms} onChange={(e) => setTerms(e.target.value)} />
              {errors.terms_url ? <p className="text-destructive text-xs">{errors.terms_url}</p> : null}
            </div>
            <div className="space-y-2">
              <Label htmlFor="shop-imprint">{t("online.shop.imprint")}</Label>
              <Input id="shop-imprint" type="url" placeholder="https://" value={imprint} onChange={(e) => setImprint(e.target.value)} />
              {errors.imprint_url ? <p className="text-destructive text-xs">{errors.imprint_url}</p> : null}
            </div>
            <p className="text-muted-foreground text-xs sm:col-span-2">{t("online.shop.legalHint")}</p>
          </div>
        </CardContent>
        <CardFooter>
          <Button type="submit" disabled={update.isPending}>
            {update.isPending ? <Loader2 className="animate-spin" /> : null}
            {t("online.shop.save")}
          </Button>
        </CardFooter>
      </form>
    </Card>
  )
}

function Toggle({
  id,
  checked,
  onChange,
  label,
  hint,
  hintText,
  error,
}: {
  id: string
  checked: boolean
  onChange: (v: boolean) => void
  label: MessageKey
  hint?: MessageKey
  hintText?: string
  error?: string
}) {
  const t = useT()
  return (
    <div className="flex items-start justify-between gap-4">
      <div className="space-y-1">
        <Label htmlFor={id}>{t(label)}</Label>
        <p className="text-muted-foreground text-xs">{hintText ?? (hint ? t(hint) : null)}</p>
        {error ? <p className="text-destructive text-xs">{error}</p> : null}
      </div>
      <Switch id={id} checked={checked} onCheckedChange={onChange} />
    </div>
  )
}

function CopyField({ id, value, label, multiline = false }: { id: string; value: string; label: string; multiline?: boolean }) {
  const t = useT()
  const [copied, setCopied] = useState(false)
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>{label}</Label>
      <div className="flex gap-2">
        {multiline ? (
          <Textarea id={id} readOnly value={value} className="font-mono text-xs" rows={3} />
        ) : (
          <Input id={id} readOnly value={value} className="font-mono text-xs" />
        )}
        <Button
          type="button"
          variant="outline"
          onClick={() => {
            void navigator.clipboard.writeText(value).then(() => {
              setCopied(true)
              setTimeout(() => setCopied(false), 1500)
            })
          }}
          aria-label={t("online.share.copy")}
        >
          {copied ? <Check /> : <Copy />}
          <span className="sr-only sm:not-sr-only">{copied ? t("online.share.copied") : t("online.share.copy")}</span>
        </Button>
      </div>
    </div>
  )
}

function ShareCard({ state }: { state: OnlineShopState }) {
  const t = useT()
  const color = "#0F172A"
  const snippet = `<a href="${state.url}" target="_blank" rel="noopener" style="display:inline-block;padding:12px 20px;border-radius:10px;background:${color};color:#ffffff;font-family:sans-serif;font-weight:600;text-decoration:none">${t("online.share.buttonLabel")}</a>`
  const qr = svgDataUrl(state.qr_svg)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("online.share.title")}</CardTitle>
      </CardHeader>
      <CardContent className="grid gap-6 sm:grid-cols-[1fr_auto]">
        <div className="space-y-4">
          <CopyField id="shop-url" label={t("online.share.link")} value={state.url} />
          <div className="space-y-1">
            <CopyField id="shop-button" label={t("online.share.button")} value={snippet} multiline />
            <p className="text-muted-foreground text-xs">{t("online.share.buttonHint")}</p>
          </div>
          <Button asChild variant="outline">
            <a href={state.url} target="_blank" rel="noopener">
              <ExternalLink /> {t("online.share.open")}
            </a>
          </Button>
        </div>
        <div className="flex flex-col items-center gap-2">
          <p className="text-sm font-medium">{t("online.share.qr")}</p>
          {/* eslint-disable-next-line @next/next/no-img-element -- generated QR */}
          <img src={qr} alt={state.url} className="size-40 rounded-lg bg-white p-2" />
          <Button asChild variant="ghost" size="sm">
            <a href={qr} download="gutschein-shop-qr.svg">
              <Download /> {t("online.share.qrDownload")}
            </a>
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

const STATUS: Record<OnlineOrder["status"], MessageKey> = {
  pending: "online.status.pending",
  paid: "online.status.paid",
  expired: "online.status.expired",
  refunded: "online.status.refunded",
  disputed: "online.status.disputed",
}

function Orders() {
  const t = useT()
  const all = useOnlineOrders()
  const pickup = useOnlineOrders(true)
  const date = (iso: string | null) => (iso ? new Date(iso).toLocaleString(undefined, { dateStyle: "short", timeStyle: "short" }) : "")

  const row = (o: OnlineOrder) => (
    <li key={o.id} className="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
      <div className="min-w-0">
        <p className="truncate font-medium">
          {o.voucher ? (
            <a className="hover:underline" href={`/vouchers/${o.voucher.id}`}>
              {formatMoney(o.amount, o.currency)}
            </a>
          ) : (
            formatMoney(o.amount, o.currency)
          )}{" "}
          <span className="text-muted-foreground font-normal">· {o.buyer_name ?? o.buyer_email}</span>
        </p>
        <p className="text-muted-foreground text-xs">
          {date(o.paid_at ?? o.created_at)}
          {o.card_pickup
            ? o.card_picked_up_at
              ? ` · ${t("online.orders.pickedUp")}`
              : ` · ${t("online.voucher.pickupOpen", { date: date(o.card_pickup_from) })}`
            : ""}
        </p>
      </div>
      <Badge variant={o.status === "paid" ? "secondary" : o.status === "disputed" ? "destructive" : "outline"}>{t(STATUS[o.status])}</Badge>
    </li>
  )

  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <Card>
        <CardHeader>
          <CardTitle>{t("online.orders.pickupTitle")}</CardTitle>
        </CardHeader>
        <CardContent>
          {pickup.data && pickup.data.length > 0 ? (
            <ul className="divide-y">{pickup.data.map(row)}</ul>
          ) : (
            <p className="text-muted-foreground text-sm">{t("online.orders.pickupEmpty")}</p>
          )}
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>{t("online.orders.title")}</CardTitle>
        </CardHeader>
        <CardContent>
          {all.data && all.data.length > 0 ? (
            <ul className="divide-y">{all.data.slice(0, 20).map(row)}</ul>
          ) : (
            <p className="text-muted-foreground text-sm">{t("online.orders.empty")}</p>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
