"use client"

import { useRef, useState } from "react"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { useRefundVoucher } from "@/lib/api/hooks"
import type { Voucher } from "@/lib/api/types"
import { errorMessage, newIdempotencyKey } from "@/lib/api/client"
import { formatMoney } from "@/lib/money"
import { useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"
import { REFUND_CODES, forgetPendingKey, isUncertainOutcome, pendingKey, rememberPendingKey } from "@/lib/outcome"

type Method = "cash" | "card_terminal" | "bank_transfer"

const METHODS: { value: Method; label: MessageKey }[] = [
  { value: "cash", label: "payment.method.cash" },
  { value: "card_terminal", label: "payment.method.card_terminal" },
  { value: "bank_transfer", label: "payment.method.bank_transfer" },
]

/** Owner: pay the remaining balance back and close the voucher. Complimentary value is not paid out. */
export function RefundDialog({ voucher, open, onOpenChange }: { voucher: Voucher; open: boolean; onOpenChange: (open: boolean) => void }) {
  const t = useT()
  const [method, setMethod] = useState<Method>("cash")
  const [reference, setReference] = useState("")
  const [reason, setReason] = useState("")
  const [error, setError] = useState<string | null>(null)
  const [uncertain, setUncertain] = useState(false)
  const key = useRef(newIdempotencyKey())
  const mutation = useRefundVoucher()
  const refundable = voucher.refundable ?? 0
  const forfeited = voucher.balance - refundable
  const needsReference = method !== "cash"
  const invalid = reason.trim().length < 3 || (needsReference && reference.trim() === "") || refundable <= 0
  const scope = `refund:${voucher.id}`

  const reset = () => {
    setMethod("cash")
    setReference("")
    setReason("")
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
          <DialogTitle>{t("vouchers.refund.title")}</DialogTitle>
          <DialogDescription>{t("vouchers.refund.description", { amount: formatMoney(refundable, voucher.currency) })}</DialogDescription>
        </DialogHeader>
        {forfeited > 0 ? (
          <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:bg-amber-500/10 dark:text-amber-300">
            {t("vouchers.refund.forfeited", { amount: formatMoney(forfeited, voucher.currency) })}
          </p>
        ) : null}
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            if (invalid && !uncertain) return
            setError(null)
            const stored = uncertain ? null : pendingKey(scope)
            if (stored) key.current = stored
            const unanswered = uncertain || stored !== null
            try {
              const result = await mutation.mutateAsync({
                voucherId: voucher.id,
                idempotencyKey: key.current,
                input: { payment: { method, reference: needsReference ? reference.trim() : null }, reason: reason.trim() },
              })
              forgetPendingKey(scope)
              const paid = result.data.transaction.payment?.amount ?? refundable
              toast.success(t("vouchers.refund.done", { amount: formatMoney(paid, voucher.currency) }))
              reset()
              onOpenChange(false)
            } catch (err) {
              if (isUncertainOutcome(err, { unanswered, finalCodes: REFUND_CODES })) {
                rememberPendingKey(scope, key.current)
                setUncertain(true)
                setError(t("vouchers.refund.uncertain"))
              } else {
                forgetPendingKey(scope)
                setUncertain(false)
                setError(errorMessage(err))
                key.current = newIdempotencyKey()
              }
            }
          }}
        >
          <div className="space-y-2">
            <Label>{t("vouchers.refund.paidBackBy")}</Label>
            <div className="grid grid-cols-3 gap-2">
              {METHODS.map((m) => (
                <Button
                  key={m.value}
                  type="button"
                  disabled={uncertain}
                  variant={method === m.value ? "default" : "outline"}
                  onClick={() => setMethod(m.value)}
                >
                  {t(m.label)}
                </Button>
              ))}
            </div>
          </div>
          {needsReference ? (
            <div className="space-y-2">
              <Label htmlFor="refund-reference">{method === "card_terminal" ? t("payment.terminalReceipt") : t("payment.bankReference")}</Label>
              <Input id="refund-reference" disabled={uncertain} value={reference} onChange={(e) => setReference(e.target.value)} maxLength={120} />
            </div>
          ) : null}
          <div className="space-y-2">
            <Label htmlFor="refund-reason">{t("vouchers.field.reason")}</Label>
            <Input
              id="refund-reason"
              disabled={uncertain}
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              maxLength={500}
              placeholder={t("vouchers.refund.reasonPlaceholder")}
            />
          </div>
          {error ? <p className="bg-destructive/10 text-destructive rounded-lg px-3 py-2 text-sm">{error}</p> : null}
          <DialogFooter>
            {!uncertain ? (
              <Button type="button" variant="outline" onClick={() => changeOpen(false)}>
                {t("common.cancel")}
              </Button>
            ) : null}
            <Button type="submit" variant="destructive" disabled={(invalid && !uncertain) || mutation.isPending}>
              {mutation.isPending ? <Loader2 className="animate-spin" /> : null}
              {uncertain ? t("vouchers.refund.check") : t("vouchers.refund.submit", { amount: formatMoney(refundable, voucher.currency) })}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
