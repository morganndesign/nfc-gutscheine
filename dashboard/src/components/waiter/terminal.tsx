"use client"

import { useCallback, useEffect, useRef, useState } from "react"
import Link from "next/link"
import { AlertTriangle, ArrowDownLeft, Ban, Check, History, Keyboard, Loader2, Nfc, QrCode, X } from "lucide-react"
import { toast } from "sonner"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { StatusBadge } from "@/components/common/status-badge"
import { Keypad } from "@/components/waiter/keypad"
import { QrScanner } from "@/components/waiter/qr-scanner"
import { useCapabilities } from "@/hooks/use-capabilities"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { api, ApiError, errorMessage, newIdempotencyKey } from "@/lib/api/client"
import { useMoneyOperation, useScanCard } from "@/lib/api/hooks"
import type { ScanMethod, ScannedCard } from "@/lib/api/types"
import { formatDate } from "@/lib/format"
import { formatMoney } from "@/lib/money"
import { isWebNfcSupported, readTagOnce } from "@/lib/nfc"
import { cn } from "@/lib/utils"

type Mode = "ready" | "manual" | "qr" | "card" | "success"

interface SuccessInfo {
  kind: "redeem" | "reload"
  amount: number
  balance: number
  currency: string
  cardNumber: string
}

const AUTO_RESET_MS = 8000

/** What to do on phones without Web NFC (iPhone, or Android without Chrome / with NFC switched off). */
function tapHint(): string {
  const ua = typeof navigator !== "undefined" ? navigator.userAgent : ""
  if (/iPhone|iPad/.test(ua)) return "Hold the card to the top of the iPhone and open the notification — or scan the QR code."
  if (/Android/.test(ua)) return "To tap cards, switch on NFC and open this page in Chrome. Until then, scan the QR code."
  return "Scan the QR code on the card or enter the card number."
}

/**
 * The waiter terminal: tap → card → amount → redeem → done. Designed for one-handed use on a phone
 * and for a full redemption in well under five seconds.
 */
export function WaiterTerminal({ initialToken }: { initialToken?: string }) {
  const [mode, setMode] = useState<Mode>("ready")
  const [card, setCard] = useState<ScannedCard | null>(null)
  const [amount, setAmount] = useState(0)
  const [operation, setOperation] = useState<"redeem" | "reload">("redeem")
  const [listening, setListening] = useState(false)
  const [scanError, setScanError] = useState<string | null>(null)
  const [manualNumber, setManualNumber] = useState("")
  const [success, setSuccess] = useState<SuccessInfo | null>(null)
  const [blockOpen, setBlockOpen] = useState(false)
  const [blocking, setBlocking] = useState(false)

  const scan = useScanCard()
  const redeem = useMoneyOperation("redeem")
  const reload = useMoneyOperation("reload")
  const nfcAbort = useRef<AbortController | null>(null)
  const idempotencyKey = useRef(newIdempotencyKey())
  const { nfc: nfcSupported, qr: qrSupported } = useCapabilities()
  // mutateAsync is referentially stable; the mutation object itself is not (it changes with its state).
  const scanCard = scan.mutateAsync

  const reset = useCallback(() => {
    setCard(null)
    setAmount(0)
    setOperation("redeem")
    setSuccess(null)
    setScanError(null)
    setManualNumber("")
    idempotencyKey.current = newIdempotencyKey()
    setMode("ready")
  }, [])

  const resolve = useCallback(
    async (input: { method: ScanMethod; token?: string; card_number?: string; nfc_uid?: string | null }) => {
      setScanError(null)
      try {
        const result = await scanCard(input)
        setCard(result.data)
        setAmount(0)
        // Open on the action that is actually possible (e.g. an empty card can only be reloaded).
        setOperation(!result.data.actions.redeem && result.data.actions.reload ? "reload" : "redeem")
        idempotencyKey.current = newIdempotencyKey()
        setMode("card")
        if ("vibrate" in navigator) navigator.vibrate?.(30)
      } catch (e) {
        setScanError(
          e instanceof ApiError && e.code === "CARD_NOT_FOUND"
            ? input.method === "manual"
              ? "No card with this number. Check the digits and try again."
              : "This is not one of our gift cards."
            : errorMessage(e, "Card could not be read. Please try again."),
        )
        if ("vibrate" in navigator) navigator.vibrate?.([60, 40, 60])
        setMode((m) => (m === "manual" ? "manual" : "ready"))
      }
    },
    [scanCard],
  )

  const startNfc = useCallback(async () => {
    if (!isWebNfcSupported()) return
    nfcAbort.current?.abort()
    const controller = new AbortController()
    nfcAbort.current = controller
    setListening(true)
    try {
      while (!controller.signal.aborted) {
        const read = await readTagOnce(controller.signal)
        if (!read.url) {
          setScanError("This tag does not contain a gift card.")
          continue
        }
        controller.abort()
        await resolve({ method: "nfc", token: read.url, nfc_uid: read.serialNumber || null })
      }
    } catch (e) {
      if ((e as Error).name !== "AbortError") setScanError(errorMessage(e))
    } finally {
      setListening(false)
    }
  }, [resolve])

  // Resolve a card opened via its link (iPhone NFC / camera QR → /c/{token}).
  const initialHandled = useRef(false)
  useEffect(() => {
    if (initialToken && !initialHandled.current) {
      initialHandled.current = true
      // NTAG 424 DNA taps carry a one-time SUN signature in the URL → verify as a secure NFC read.
      const secure = /[?&]picc=[0-9A-Fa-f]{32}/.test(initialToken) && /[?&]cmac=[0-9A-Fa-f]{16}/.test(initialToken)
      void resolve({ method: secure ? "nfc" : "link", token: initialToken })
      // Leave the card link: a reload must not re-open the card, and the one-time SUN URL should not linger.
      window.history.replaceState(null, "", "/waiter")
    }
  }, [initialToken, resolve])

  // Listen for taps automatically whenever the terminal is idle (including the success screen, so the
  // next guest's card can be tapped straight away) and NFC permission was granted before.
  const listenForTaps = mode === "ready" || mode === "success"
  useEffect(() => {
    if (!listenForTaps || !nfcSupported) return
    let cancelled = false
    navigator.permissions
      ?.query({ name: "nfc" as PermissionName })
      .then((status) => {
        if (!cancelled && status.state === "granted") void startNfc()
      })
      .catch(() => undefined)
    return () => {
      cancelled = true
      nfcAbort.current?.abort()
    }
  }, [listenForTaps, nfcSupported, startNfc])

  useEffect(() => {
    if (mode !== "success") return
    const t = setTimeout(reset, AUTO_RESET_MS)
    return () => clearTimeout(t)
  }, [mode, reset])

  const submit = async () => {
    if (!card || amount <= 0) return
    const mutation = operation === "redeem" ? redeem : reload
    try {
      const result = await mutation.mutateAsync({ cardId: card.id, idempotencyKey: idempotencyKey.current, input: { amount } })
      setSuccess({ kind: operation, amount, balance: result.data.card.balance, currency: card.currency, cardNumber: card.card_number })
      setMode("success")
      if ("vibrate" in navigator) navigator.vibrate?.([20, 30, 20])
    } catch (e) {
      toast.error(errorMessage(e))
      // A definitive rejection means nothing was booked; a network failure keeps the key so a retry cannot double-charge.
      if (e instanceof ApiError && e.status < 500) idempotencyKey.current = newIdempotencyKey()
    }
  }

  const submitting = redeem.isPending || reload.isPending

  // ------------------------------------------------------------------ success
  if (mode === "success" && success) {
    return (
      <div className="flex flex-1 flex-col items-center justify-center gap-6 text-center" role="status" aria-live="assertive">
        <div className="animate-in zoom-in-50 flex size-24 items-center justify-center rounded-full bg-emerald-500 text-white shadow-lg shadow-emerald-500/30 duration-300">
          <Check className="size-12" strokeWidth={3} />
        </div>
        <div className="space-y-1">
          <p className="text-muted-foreground text-sm">{success.kind === "redeem" ? "Redeemed" : "Loaded"}</p>
          <p className="tabular text-5xl font-semibold tracking-tight">{formatMoney(success.amount, success.currency)}</p>
        </div>
        <div className="bg-muted rounded-2xl px-6 py-3">
          <p className="text-muted-foreground text-sm">Remaining balance</p>
          <p className="tabular text-2xl font-semibold">{formatMoney(success.balance, success.currency)}</p>
          <p className="text-muted-foreground card-number text-xs">{success.cardNumber}</p>
        </div>
        <Button size="lg" className="h-14 w-full max-w-xs rounded-2xl text-lg" onClick={reset} autoFocus>
          Next card
        </Button>
        {nfcSupported ? <p className="text-muted-foreground text-xs">Or simply tap the next card.</p> : null}
      </div>
    )
  }

  // ------------------------------------------------------------------ card
  if (mode === "card" && card) {
    const canRedeem = card.actions.redeem
    const canReload = card.actions.reload
    const disabled = operation === "redeem" ? !canRedeem : !canReload
    const tooMuch = operation === "redeem" && amount > card.balance

    return (
      <div className="short:gap-2.5 flex flex-1 flex-col gap-4">
        <div className="bg-muted short:py-2 rounded-3xl py-3 pr-2 pl-5">
          <div className="flex items-center justify-between gap-2">
            <p className="card-number text-muted-foreground truncate text-sm">{card.card_number}</p>
            <div className="flex shrink-0 items-center gap-1">
              <StatusBadge status={card.is_expired && card.status === "active" ? "expired" : card.status} />
              <Button variant="ghost" size="icon" className="rounded-full" onClick={reset} aria-label="Close card">
                <X />
              </Button>
            </div>
          </div>
          <p className="tabular short:text-3xl text-4xl font-semibold tracking-tight" aria-label={`Balance ${formatMoney(card.balance, card.currency)}`}>
            {formatMoney(card.balance, card.currency)}
          </p>
          <p className="text-muted-foreground mt-0.5 pb-1 text-xs">Balance · {card.expires_at ? `valid until ${formatDate(card.expires_at)}` : "no expiry"}</p>
        </div>

        {!canRedeem && operation === "redeem" ? (
          <div
            role="alert"
            className={cn(
              "flex items-start gap-2 rounded-2xl border px-4 py-3 text-sm",
              ["blocked", "replaced"].includes(card.status)
                ? "border-red-200 bg-red-50 text-red-800 dark:border-red-500/30 dark:bg-red-500/10 dark:text-red-200"
                : "border-amber-300 bg-amber-50 text-amber-900 dark:border-amber-500/30 dark:bg-amber-500/10 dark:text-amber-200",
            )}
          >
            <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
            <span>
              {card.status === "blocked"
                ? `This card is blocked${card.blocked_reason ? `: ${card.blocked_reason}` : "."}`
                : card.is_expired || card.status === "expired"
                  ? "This card has expired."
                  : card.status === "replaced"
                    ? "This card was replaced and is no longer valid. Ask the guest for the new card."
                    : card.status === "inactive"
                      ? "This card is not activated yet."
                      : card.balance === 0
                        ? "This card has no balance left."
                        : "This card cannot be redeemed."}
            </span>
          </div>
        ) : null}

        {canReload ? (
          <div className="bg-muted grid grid-cols-2 gap-1 rounded-2xl p-1 text-sm font-medium" role="group" aria-label="Operation">
            {(["redeem", "reload"] as const).map((op) => (
              <button
                key={op}
                type="button"
                onClick={() => {
                  setOperation(op)
                  setAmount(0)
                }}
                aria-pressed={operation === op}
                className={cn("h-11 rounded-xl transition", operation === op ? "bg-background shadow-sm" : "text-muted-foreground")}
              >
                {op === "redeem" ? "Redeem" : "Reload"}
              </button>
            ))}
          </div>
        ) : null}

        {!disabled ? (
          <>
            <div className="flex items-end justify-between px-1">
              <span
                aria-live="polite"
                aria-label={`Amount ${formatMoney(amount, card.currency)}`}
                className={cn(
                  "tabular short:text-4xl text-5xl font-semibold tracking-tight",
                  amount === 0 && "text-muted-foreground/50",
                  tooMuch && "text-destructive",
                )}
              >
                {formatMoney(amount, card.currency)}
              </span>
              {operation === "redeem" ? (
                <Button variant="outline" className="rounded-xl" onClick={() => setAmount(card.balance)}>
                  Full balance
                </Button>
              ) : null}
            </div>
            {tooMuch ? (
              <p role="alert" className="text-destructive -mt-2 px-1 text-sm">
                More than the balance. Redeem {formatMoney(card.balance, card.currency)} and collect the rest otherwise.
              </p>
            ) : null}
            <Keypad value={amount} onChange={setAmount} />
            <Button
              size="lg"
              className={cn("short:h-14 h-16 rounded-2xl text-lg", operation === "reload" && "bg-emerald-600 hover:bg-emerald-600/90")}
              disabled={amount <= 0 || tooMuch || submitting || (operation === "redeem" && !card.allow_partial_redemption && amount !== card.balance)}
              onClick={submit}
            >
              {submitting ? <Loader2 className="animate-spin" /> : operation === "redeem" ? null : <ArrowDownLeft />}
              {operation === "redeem" ? "Redeem" : "Load"} {amount > 0 ? formatMoney(amount, card.currency) : ""}
            </Button>
            {operation === "redeem" && !card.allow_partial_redemption ? (
              <p className="text-muted-foreground text-center text-xs">This restaurant only allows redeeming the full balance.</p>
            ) : null}
          </>
        ) : (
          <Button size="lg" className="h-14 rounded-2xl text-lg" onClick={reset} autoFocus>
            Next card
          </Button>
        )}

        <div className="mt-auto grid grid-cols-2 gap-2">
          {card.actions.history ? (
            <Button variant="outline" className="h-12 rounded-2xl" asChild>
              <Link href={`/cards/${card.id}`}>
                <History /> History
              </Link>
            </Button>
          ) : null}
          {card.actions.block ? (
            <Button variant="outline" className="text-destructive h-12 rounded-2xl" onClick={() => setBlockOpen(true)}>
              <Ban /> Block card
            </Button>
          ) : null}
        </div>

        <ReasonDialog
          open={blockOpen}
          onOpenChange={setBlockOpen}
          title="Block card"
          suggestions={["Reported stolen", "Reported lost", "Suspicious use"]}
          description="The card cannot be used until a manager unblocks it."
          confirmLabel="Block"
          destructive
          pending={blocking}
          onConfirm={async (reason) => {
            setBlocking(true)
            try {
              await api(`/cards/${card.id}/block`, { method: "POST", body: { reason } })
              toast.success("Card blocked")
              setBlockOpen(false)
              reset()
            } catch (e) {
              toast.error(errorMessage(e))
            } finally {
              setBlocking(false)
            }
          }}
        />
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
            void resolve({ method: "qr", token: value })
          }}
          onError={(message) => {
            setScanError(message)
            setMode("ready")
          }}
        />
        <Button variant="outline" size="lg" className="h-12 rounded-2xl" onClick={() => setMode("ready")}>
          Cancel
        </Button>
      </div>
    )
  }

  // ------------------------------------------------------------------ manual entry
  if (mode === "manual") {
    return (
      <form
        className="flex flex-1 flex-col gap-4"
        onSubmit={(e) => {
          e.preventDefault()
          void resolve({ method: "manual", card_number: manualNumber })
        }}
      >
        <p className="text-muted-foreground text-sm">Enter the number printed on the card.</p>
        <Input
          autoFocus
          inputMode="numeric"
          autoComplete="off"
          value={manualNumber}
          onChange={(e) =>
            setManualNumber(
              e.target.value
                .replace(/\D/g, "")
                .slice(0, 19)
                .replace(/(.{4})/g, "$1 ")
                .trim(),
            )
          }
          placeholder="1234 5678 9012 3456"
          className="card-number h-16 rounded-2xl text-center text-2xl"
        />
        {scanError ? <p className="bg-destructive/10 text-destructive rounded-xl px-4 py-3 text-sm">{scanError}</p> : null}
        <Button type="submit" size="lg" className="h-14 rounded-2xl text-lg" disabled={manualNumber.replace(/\D/g, "").length < 8 || scan.isPending}>
          {scan.isPending ? <Loader2 className="animate-spin" /> : null} Find card
        </Button>
        <Button type="button" variant="ghost" onClick={reset}>
          Cancel
        </Button>
      </form>
    )
  }

  // ------------------------------------------------------------------ ready
  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-8">
      <button
        type="button"
        onClick={() => (nfcSupported ? void startNfc() : qrSupported ? setMode("qr") : setMode("manual"))}
        disabled={scan.isPending}
        className="group bg-primary text-primary-foreground shadow-primary/20 relative flex size-64 flex-col items-center justify-center gap-3 rounded-full shadow-2xl transition active:scale-[0.97] disabled:opacity-80"
        aria-label={nfcSupported ? "Scan card with NFC" : "Scan card"}
      >
        {listening ? <span className="bg-primary/20 absolute inset-0 animate-ping rounded-full" aria-hidden /> : null}
        {scan.isPending ? <Loader2 className="size-14 animate-spin" /> : nfcSupported ? <Nfc className="size-16" /> : <QrCode className="size-16" />}
        <span className="text-xl font-semibold">{scan.isPending ? "Reading…" : listening ? "Tap card now" : nfcSupported ? "Scan card" : "Scan QR code"}</span>
        {listening ? <span className="text-sm opacity-70">Hold the card to the back of the phone</span> : null}
      </button>

      {scanError ? (
        <p role="alert" className="bg-destructive/10 text-destructive max-w-sm rounded-2xl px-4 py-3 text-center text-sm">
          {scanError}
        </p>
      ) : !nfcSupported ? (
        <p className="text-muted-foreground max-w-xs text-center text-sm">{tapHint()}</p>
      ) : listening ? null : (
        <p className="text-muted-foreground max-w-xs text-center text-sm">Press the button once — after that, cards are read as soon as they are tapped.</p>
      )}

      <div className="grid w-full max-w-sm grid-cols-2 gap-2">
        {qrSupported && nfcSupported ? (
          <Button variant="outline" className="h-12 rounded-2xl" onClick={() => setMode("qr")}>
            <QrCode /> QR code
          </Button>
        ) : null}
        <Button variant="outline" className={cn("h-12 rounded-2xl", !(qrSupported && nfcSupported) && "col-span-2")} onClick={() => setMode("manual")}>
          <Keyboard /> Card number
        </Button>
      </div>
    </div>
  )
}
