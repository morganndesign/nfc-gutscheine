"use client"

import { useCallback, useEffect, useRef, useState } from "react"
import Link from "next/link"
import { AlertTriangle, Check, History, Loader2, QrCode, RefreshCw, X } from "lucide-react"
import { StatusBadge, displayStatus } from "@/components/common/status-badge"
import { Keypad } from "@/components/waiter/keypad"
import { QrScanner } from "@/components/waiter/qr-scanner"
import { useCapabilities } from "@/hooks/use-capabilities"
import { Button } from "@/components/ui/button"
import { ApiError, errorMessage, newIdempotencyKey } from "@/lib/api/client"
import { usePresent, useRedeemVoucher } from "@/lib/api/hooks"
import type { Presentment } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { formatDate } from "@/lib/format"
import { formatMoney } from "@/lib/money"
import { REDEMPTION_CODES, forgetPendingKey, isUncertainOutcome, pendingKey, rememberPendingKey } from "@/lib/outcome"
import { cn } from "@/lib/utils"
import { useT } from "@/lib/i18n"

type Mode = "ready" | "qr" | "voucher" | "success"

interface SuccessInfo {
  amount: number
  balance: number
  currency: string
  replayed: boolean
}

const AUTO_RESET_MS = 8000

/**
 * The web till for digital vouchers: scan the voucher's QR → a single-use presentment (60 s) → amount → redeem.
 * Card vouchers are redeemed only in the Android and iPhone app, which authenticates the card itself
 * (architecture §10.3); the web never reads cards and never finds a voucher by its number.
 *
 * Uncertain outcomes (audit M1, M2, M6): when the connection drops after "Redeem", the result is unknown. The
 * amount, the presentment and the idempotency key are kept, and the only way on is "Check again", which sends
 * the same request: the server books it once or returns the booking it already made. The key is also kept in
 * this tab for the voucher and amount, so scanning the voucher again after leaving reuses it.
 */
export function WaiterTerminal() {
  const [mode, setMode] = useState<Mode>("ready")
  const [presentment, setPresentment] = useState<Presentment | null>(null)
  const [amount, setAmount] = useState(0)
  const [scanError, setScanError] = useState<string | null>(null)
  const [redeemError, setRedeemError] = useState<string | null>(null)
  const [uncertain, setUncertain] = useState(false)
  const [success, setSuccess] = useState<SuccessInfo | null>(null)

  const { can } = useAuth()
  const t = useT()
  const present = usePresent()
  const redeem = useRedeemVoucher()
  const idempotencyKey = useRef(newIdempotencyKey())
  const { qr: qrSupported } = useCapabilities()
  const presentVoucher = present.mutateAsync

  const reset = useCallback(() => {
    setPresentment(null)
    setAmount(0)
    setSuccess(null)
    setScanError(null)
    setRedeemError(null)
    setUncertain(false)
    idempotencyKey.current = newIdempotencyKey()
    setMode("ready")
  }, [])

  const onScanned = useCallback(
    async (credential: string) => {
      setScanError(null)
      try {
        const result = await presentVoucher(credential)
        setPresentment(result.data)
        setAmount(0)
        setRedeemError(null)
        idempotencyKey.current = newIdempotencyKey()
        setMode("voucher")
        if ("vibrate" in navigator) navigator.vibrate?.(30)
      } catch (e) {
        setScanError(
          e instanceof ApiError && e.code === "MEDIUM_NOT_RECOGNIZED"
            ? t("waiter.error.notRecognized")
            : e instanceof ApiError && e.code === "PRESENTMENT_METHOD_NOT_ALLOWED"
              ? t("waiter.error.cardOnly")
              : errorMessage(e, t("waiter.error.checkFailed")),
        )
        if ("vibrate" in navigator) navigator.vibrate?.([60, 40, 60])
        setMode("ready")
      }
    },
    [presentVoucher, t],
  )

  useEffect(() => {
    if (mode !== "success") return
    const timer = setTimeout(reset, AUTO_RESET_MS)
    return () => clearTimeout(timer)
  }, [mode, reset])

  // Leaving while the outcome is unknown asks first (the key survives in this tab either way).
  useEffect(() => {
    if (!uncertain) return
    const warn = (e: BeforeUnloadEvent) => e.preventDefault()
    window.addEventListener("beforeunload", warn)
    return () => window.removeEventListener("beforeunload", warn)
  }, [uncertain])

  const submit = async () => {
    if (!presentment || amount <= 0) return
    setRedeemError(null)
    const scope = `redeem:${presentment.voucher.id}:${amount}`
    const stored = uncertain ? null : pendingKey(scope)
    if (stored) idempotencyKey.current = stored
    const unanswered = uncertain || stored !== null
    try {
      const result = await redeem.mutateAsync({
        voucherId: presentment.voucher.id,
        idempotencyKey: idempotencyKey.current,
        input: { amount, presentment_id: presentment.id },
      })
      forgetPendingKey(scope)
      setUncertain(false)
      setSuccess({ amount, balance: result.data.voucher.balance, currency: presentment.voucher.currency, replayed: result.replayed })
      setMode("success")
      if ("vibrate" in navigator) navigator.vibrate?.([20, 30, 20])
    } catch (e) {
      if (isUncertainOutcome(e, { unanswered, finalCodes: REDEMPTION_CODES })) {
        // Keep key, amount and presentment: the retry replays the booking if it was made.
        rememberPendingKey(scope, idempotencyKey.current)
        setUncertain(true)
        setRedeemError(t("waiter.error.uncertain"))
        return
      }
      forgetPendingKey(scope)
      setUncertain(false)
      idempotencyKey.current = newIdempotencyKey()
      if (e instanceof ApiError && e.code === "PRESENTMENT_INVALID") {
        setRedeemError(t("waiter.error.presentmentInvalid"))
      } else {
        setRedeemError(t("waiter.error.nothingBooked", { message: errorMessage(e) }))
      }
    }
  }

  // ------------------------------------------------------------------ success
  if (mode === "success" && success) {
    return (
      <div className="flex flex-1 flex-col items-center justify-center gap-6 text-center" role="status" aria-live="assertive">
        <div className="animate-in zoom-in-50 flex size-24 items-center justify-center rounded-full bg-emerald-500 text-white shadow-lg shadow-emerald-500/30 duration-300">
          <Check className="size-12" strokeWidth={3} />
        </div>
        <div className="space-y-1">
          <p className="text-muted-foreground text-sm">{success.replayed ? t("waiter.alreadyBooked") : t("waiter.redeemed")}</p>
          <p className="tabular text-5xl font-semibold tracking-tight">{formatMoney(success.amount, success.currency)}</p>
        </div>
        <div className="bg-muted rounded-2xl px-6 py-3">
          <p className="text-muted-foreground text-sm">{t("waiter.remaining")}</p>
          <p className="tabular text-2xl font-semibold">{formatMoney(success.balance, success.currency)}</p>
        </div>
        <Button size="lg" className="h-14 w-full max-w-xs rounded-2xl text-lg" onClick={reset} autoFocus>
          {t("waiter.next")}
        </Button>
      </div>
    )
  }

  // ------------------------------------------------------------------ voucher
  if (mode === "voucher" && presentment) {
    const voucher = presentment.voucher
    const canRedeem = voucher.actions.redeem
    const tooMuch = amount > voucher.balance
    const overLimit = amount > voucher.max_debit_per_transaction
    const fullOnly = !voucher.allow_partial_redemption && amount !== voucher.balance

    return (
      <div className="short:gap-2.5 flex flex-1 flex-col gap-4">
        <div className="bg-muted short:py-2 rounded-3xl py-3 pr-2 pl-5">
          <div className="flex items-center justify-between gap-2">
            <p className="text-muted-foreground truncate text-sm">{t("waiter.digitalVoucher", { restaurant: voucher.restaurant_name })}</p>
            <div className="flex shrink-0 items-center gap-1">
              <StatusBadge status={displayStatus(voucher)} />
              {!uncertain ? (
                <Button variant="ghost" size="icon" className="rounded-full" onClick={reset} aria-label={t("waiter.closeVoucher")}>
                  <X />
                </Button>
              ) : null}
            </div>
          </div>
          <p
            className="tabular short:text-3xl text-4xl font-semibold tracking-tight"
            aria-label={t("waiter.balanceA11y", { amount: formatMoney(voucher.balance, voucher.currency) })}
          >
            {formatMoney(voucher.balance, voucher.currency)}
          </p>
          <p className="text-muted-foreground mt-0.5 pb-1 text-xs">
            {voucher.expires_at ? t("waiter.validUntil", { date: formatDate(voucher.expires_at) }) : t("waiter.noExpiry")}
          </p>
        </div>

        {!canRedeem ? (
          <div
            role="alert"
            className={cn(
              "flex items-start gap-2 rounded-2xl border px-4 py-3 text-sm",
              voucher.status === "blocked"
                ? "border-red-200 bg-red-50 text-red-800 dark:border-red-500/30 dark:bg-red-500/10 dark:text-red-200"
                : "border-amber-300 bg-amber-50 text-amber-900 dark:border-amber-500/30 dark:bg-amber-500/10 dark:text-amber-200",
            )}
          >
            <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
            <span>
              {voucher.status === "blocked"
                ? voucher.blocked_reason
                  ? t("waiter.blockedReason", { reason: voucher.blocked_reason })
                  : t("waiter.blocked")
                : voucher.is_expired || voucher.status === "expired"
                  ? t("waiter.expired")
                  : voucher.balance === 0
                    ? t("waiter.empty")
                    : t("waiter.notRedeemable")}
            </span>
          </div>
        ) : null}

        {canRedeem ? (
          <>
            <div className="flex items-end justify-between px-1">
              <span
                aria-live="polite"
                aria-label={t("waiter.amountA11y", { amount: formatMoney(amount, voucher.currency) })}
                className={cn(
                  "tabular short:text-4xl text-5xl font-semibold tracking-tight",
                  amount === 0 && "text-muted-foreground/50",
                  (tooMuch || overLimit) && "text-destructive",
                )}
              >
                {formatMoney(amount, voucher.currency)}
              </span>
              {!uncertain ? (
                <Button variant="outline" className="rounded-xl" onClick={() => setAmount(Math.min(voucher.balance, voucher.max_debit_per_transaction))}>
                  {t("waiter.fullBalance")}
                </Button>
              ) : null}
            </div>
            {tooMuch ? (
              <p role="alert" className="text-destructive -mt-2 px-1 text-sm">
                {t("waiter.tooMuch", { amount: formatMoney(voucher.balance, voucher.currency) })}
              </p>
            ) : overLimit ? (
              <p role="alert" className="text-destructive -mt-2 px-1 text-sm">
                {t("waiter.overLimit", { amount: formatMoney(voucher.max_debit_per_transaction, voucher.currency) })}
              </p>
            ) : null}
            {redeemError ? (
              <p
                role="alert"
                className={cn(
                  "rounded-2xl px-4 py-3 text-sm",
                  uncertain ? "bg-amber-50 text-amber-900 dark:bg-amber-500/10 dark:text-amber-200" : "bg-destructive/10 text-destructive",
                )}
              >
                {redeemError}
              </p>
            ) : null}
            {!uncertain ? <Keypad value={amount} onChange={setAmount} /> : null}
            <Button
              size="lg"
              className="short:h-14 h-16 rounded-2xl text-lg"
              disabled={amount <= 0 || redeem.isPending || (!uncertain && (tooMuch || overLimit || fullOnly))}
              onClick={submit}
            >
              {redeem.isPending ? <Loader2 className="animate-spin" /> : uncertain ? <RefreshCw /> : null}
              {amount > 0
                ? t(uncertain ? "waiter.checkAgainAmount" : "waiter.redeemAmount", { amount: formatMoney(amount, voucher.currency) })
                : t(uncertain ? "waiter.checkAgain" : "waiter.redeem")}
            </Button>
            {!voucher.allow_partial_redemption ? <p className="text-muted-foreground text-center text-xs">{t("waiter.fullOnly")}</p> : null}
          </>
        ) : (
          <Button size="lg" className="h-14 rounded-2xl text-lg" onClick={reset} autoFocus>
            {t("waiter.next")}
          </Button>
        )}

        {can("vouchers.view") && !uncertain ? (
          <Button variant="outline" className="mt-auto h-12 rounded-2xl" asChild>
            <Link href={`/vouchers/${voucher.id}`}>
              <History /> {t("waiter.details")}
            </Link>
          </Button>
        ) : null}
      </div>
    )
  }

  // ------------------------------------------------------------------ QR camera
  if (mode === "qr") {
    return (
      <div className="flex flex-1 flex-col gap-4">
        <QrScanner
          onResult={(value) => {
            setMode("ready")
            void onScanned(value)
          }}
          onError={(message) => {
            setScanError(message)
            setMode("ready")
          }}
        />
        <Button variant="outline" size="lg" className="h-12 rounded-2xl" onClick={() => setMode("ready")}>
          {t("common.cancel")}
        </Button>
      </div>
    )
  }

  // ------------------------------------------------------------------ ready
  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-8">
      <button
        type="button"
        onClick={() => setMode("qr")}
        disabled={present.isPending || !qrSupported}
        className="group bg-primary text-primary-foreground shadow-primary/20 relative flex size-64 flex-col items-center justify-center gap-3 rounded-full shadow-2xl transition active:scale-[0.97] disabled:opacity-80"
        aria-label={t("waiter.scanA11y")}
      >
        {present.isPending ? <Loader2 className="size-14 animate-spin" /> : <QrCode className="size-16" />}
        <span className="text-xl font-semibold">{present.isPending ? t("waiter.checking") : t("waiter.scan")}</span>
      </button>

      {scanError ? (
        <p role="alert" className="bg-destructive/10 text-destructive max-w-sm rounded-2xl px-4 py-3 text-center text-sm">
          {scanError}
        </p>
      ) : (
        <p className="text-muted-foreground max-w-xs text-center text-sm">{qrSupported ? t("waiter.hint") : t("waiter.noCamera")}</p>
      )}
    </div>
  )
}
