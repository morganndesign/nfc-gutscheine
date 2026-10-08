"use client"

import { useRef, useState } from "react"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { MoneyInput } from "@/components/common/money-input"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { PaymentFields, paymentComplete } from "@/components/vouchers/payment-fields"
import { type PaymentInput, useReloadVoucher } from "@/lib/api/hooks"
import { ApiError, errorMessage, newIdempotencyKey } from "@/lib/api/client"
import { useAuth } from "@/lib/auth"
import { formatMoney, parseMoneyInput } from "@/lib/money"
import { useT } from "@/lib/i18n"
import { RELOAD_CODES, forgetPendingKey, isUncertainOutcome, pendingKey, rememberPendingKey } from "@/lib/outcome"

export function ReloadDialog({
  voucherId,
  balance,
  maxBalance,
  currency,
  loyalty,
  open,
  onOpenChange,
}: {
  voucherId: string
  balance: number
  maxBalance: number
  currency: string
  /** A loyalty voucher: topped up with loyalty value only, never with money (decision 2026-10-06). */
  loyalty: boolean
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const t = useT()
  const { refresh, can } = useAuth()
  const initialPayment = (): PaymentInput => (loyalty ? { method: "complimentary" } : { method: "cash" })
  // A loyalty voucher without the right to give Loyalty: nothing to book here.
  const denied = loyalty && !can("vouchers.sell_complimentary")
  const [amount, setAmount] = useState("")
  const [note, setNote] = useState("")
  const [payment, setPayment] = useState<PaymentInput>(initialPayment)
  const [error, setError] = useState<string | null>(null)
  const [uncertain, setUncertain] = useState(false)
  const key = useRef(newIdempotencyKey())
  const mutation = useReloadVoucher()
  const cents = parseMoneyInput(amount)
  // While the outcome is unknown the balance shown may already include this reload: only "Check and reload"
  // (the same request) finds out, so the limit check must not block it.
  const tooMuch = !uncertain && !!cents && balance + cents > maxBalance
  const invalid = denied || !cents || cents <= 0 || tooMuch || (!uncertain && !paymentComplete(payment))
  const scope = `reload:${voucherId}:${cents ?? 0}:${payment.method}:${payment.reference ?? ""}`

  const reset = () => {
    setAmount("")
    setNote("")
    setPayment(initialPayment())
    setError(null)
    setUncertain(false)
    key.current = newIdempotencyKey()
  }

  // Closing (Escape, outside click or Cancel) clears the form; an unknown outcome is resolved first, never abandoned.
  const changeOpen = (o: boolean) => {
    if (!o && uncertain) return
    if (!o) reset()
    onOpenChange(o)
  }

  return (
    <Dialog open={open} onOpenChange={changeOpen}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t("vouchers.reload.title")}</DialogTitle>
          <DialogDescription>
            {t("vouchers.reload.description", { balance: formatMoney(balance, currency), max: formatMoney(maxBalance, currency) })}
          </DialogDescription>
        </DialogHeader>
        <form method="post"
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            if (invalid || !cents) return
            setError(null)
            const stored = uncertain ? null : pendingKey(scope)
            if (stored) key.current = stored
            const unanswered = uncertain || stored !== null
            try {
              const result = await mutation.mutateAsync({
                voucherId,
                idempotencyKey: key.current,
                input: { amount: cents, payment, note: note || null },
              })
              forgetPendingKey(scope)
              toast.success(t("vouchers.reload.done", { amount: formatMoney(cents, currency), balance: formatMoney(result.data.voucher.balance, currency) }))
              reset()
              onOpenChange(false)
            } catch (err) {
              if (isUncertainOutcome(err, { unanswered, finalCodes: RELOAD_CODES })) {
                rememberPendingKey(scope, key.current)
                setUncertain(true)
                setError(t("vouchers.reload.uncertain"))
              } else {
                // The owner took the loyalty right back meanwhile: the payment choices follow at once (audit L4).
                if (err instanceof ApiError && err.code === "COMPLIMENTARY_NOT_ALLOWED") void refresh()
                forgetPendingKey(scope)
                setUncertain(false)
                setError(errorMessage(err))
                key.current = newIdempotencyKey()
              }
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="amount">{t("vouchers.field.amount")}</Label>
            <MoneyInput id="amount" autoFocus disabled={uncertain} value={amount} onChange={(e) => setAmount(e.target.value)} className="h-12 text-xl" />
            {tooMuch ? <p className="text-destructive text-xs">{t("vouchers.reload.tooMuch", { max: formatMoney(maxBalance, currency) })}</p> : null}
          </div>
          {denied ? (
            <p className="bg-destructive/10 text-destructive rounded-lg px-3 py-2 text-sm">{t("payment.loyaltyOnlyDenied")}</p>
          ) : !uncertain ? (
            <PaymentFields value={payment} onChange={setPayment} loyalty={loyalty} loyaltyOnly={loyalty} />
          ) : null}
          <div className="space-y-2">
            <Label htmlFor="note">{t("vouchers.field.note")}</Label>
            <Input id="note" disabled={uncertain} value={note} onChange={(e) => setNote(e.target.value)} maxLength={500} />
          </div>
          {error ? <p className="bg-destructive/10 text-destructive rounded-lg px-3 py-2 text-sm">{error}</p> : null}
          <DialogFooter>
            {!uncertain ? (
              <Button type="button" variant="outline" onClick={() => changeOpen(false)}>
                {t("common.cancel")}
              </Button>
            ) : null}
            <Button type="submit" disabled={invalid || mutation.isPending}>
              {mutation.isPending ? <Loader2 className="animate-spin" /> : null}
              {uncertain
                ? t("vouchers.reload.check")
                : cents
                  ? t("vouchers.reload.submit", { amount: formatMoney(cents, currency) })
                  : t("vouchers.reload.submitEmpty")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
