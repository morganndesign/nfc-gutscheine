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
import { forgetPendingKey, isUncertainOutcome, pendingKey, rememberPendingKey } from "@/lib/outcome"

type Method = "cash" | "card_terminal" | "bank_transfer"

const METHODS: { value: Method; label: string }[] = [
  { value: "cash", label: "Cash" },
  { value: "card_terminal", label: "Card terminal" },
  { value: "bank_transfer", label: "Bank transfer" },
]

/** Codes after which the refund certainly did not happen (anything else may have been booked). */
const REFUND_CODES: ReadonlySet<string> = new Set([
  "VALIDATION_FAILED",
  "FORBIDDEN",
  "VOUCHER_NOT_REFUNDABLE",
  "VOUCHER_NOT_REDEEMABLE",
  "INSUFFICIENT_BALANCE",
  "INVALID_AMOUNT",
  "IDEMPOTENCY_CONFLICT",
])

/** Owner: pay the remaining balance back and close the voucher. Complimentary value is not paid out. */
export function RefundDialog({ voucher, open, onOpenChange }: { voucher: Voucher; open: boolean; onOpenChange: (open: boolean) => void }) {
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

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!o && uncertain) return
        if (!o) reset()
        onOpenChange(o)
      }}
    >
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Refund voucher</DialogTitle>
          <DialogDescription>
            Pays {formatMoney(refundable, voucher.currency)} back to the guest and closes the voucher for good. Its QR code and card stop working.
          </DialogDescription>
        </DialogHeader>
        {forfeited > 0 ? (
          <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:bg-amber-500/10 dark:text-amber-300">
            {formatMoney(forfeited, voucher.currency)} of the balance was complimentary and is not paid out.
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
              toast.success(`${formatMoney(paid, voucher.currency)} refunded · voucher closed`)
              reset()
              onOpenChange(false)
            } catch (err) {
              if (isUncertainOutcome(err, { unanswered, finalCodes: REFUND_CODES })) {
                rememberPendingKey(scope, key.current)
                setUncertain(true)
                setError("The connection was interrupted, so it is not known whether the refund was booked. Press “Check and refund”: it can never be paid twice.")
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
            <Label>Paid back by</Label>
            <div className="grid grid-cols-3 gap-2">
              {METHODS.map((m) => (
                <Button key={m.value} type="button" disabled={uncertain} variant={method === m.value ? "default" : "outline"} onClick={() => setMethod(m.value)}>
                  {m.label}
                </Button>
              ))}
            </div>
          </div>
          {needsReference ? (
            <div className="space-y-2">
              <Label htmlFor="refund-reference">{method === "card_terminal" ? "Terminal receipt number" : "Bank reference"}</Label>
              <Input id="refund-reference" disabled={uncertain} value={reference} onChange={(e) => setReference(e.target.value)} maxLength={120} />
            </div>
          ) : null}
          <div className="space-y-2">
            <Label htmlFor="refund-reason">Reason</Label>
            <Input id="refund-reason" disabled={uncertain} value={reason} onChange={(e) => setReason(e.target.value)} maxLength={500} placeholder="e.g. sold by mistake" />
          </div>
          {error ? <p className="bg-destructive/10 text-destructive rounded-lg px-3 py-2 text-sm">{error}</p> : null}
          <DialogFooter>
            {!uncertain ? (
              <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
                Cancel
              </Button>
            ) : null}
            <Button type="submit" variant="destructive" disabled={(invalid && !uncertain) || mutation.isPending}>
              {mutation.isPending ? <Loader2 className="animate-spin" /> : null}
              {uncertain ? "Check and refund" : `Refund ${formatMoney(refundable, voucher.currency)}`}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
