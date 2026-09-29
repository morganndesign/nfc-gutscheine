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
import { errorMessage, newIdempotencyKey } from "@/lib/api/client"
import { formatMoney, parseMoneyInput } from "@/lib/money"
import { isUncertainOutcome } from "@/lib/outcome"

export function ReloadDialog({
  voucherId,
  balance,
  maxBalance,
  currency,
  open,
  onOpenChange,
}: {
  voucherId: string
  balance: number
  maxBalance: number
  currency: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const [amount, setAmount] = useState("")
  const [note, setNote] = useState("")
  const [payment, setPayment] = useState<PaymentInput>({ method: "cash" })
  const [error, setError] = useState<string | null>(null)
  const [uncertain, setUncertain] = useState(false)
  const key = useRef(newIdempotencyKey())
  const mutation = useReloadVoucher()
  const cents = parseMoneyInput(amount)
  const tooMuch = !!cents && balance + cents > maxBalance
  const invalid = !cents || cents <= 0 || tooMuch || !paymentComplete(payment)

  const reset = () => {
    setAmount("")
    setNote("")
    setPayment({ method: "cash" })
    setError(null)
    setUncertain(false)
    key.current = newIdempotencyKey()
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        // An unknown outcome is resolved first (sent again with the same key), never abandoned.
        if (!o && uncertain) return
        if (!o) reset()
        onOpenChange(o)
      }}
    >
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Reload voucher</DialogTitle>
          <DialogDescription>
            Current balance {formatMoney(balance, currency)} · at most {formatMoney(maxBalance, currency)}
          </DialogDescription>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            if (invalid || !cents) return
            setError(null)
            try {
              const result = await mutation.mutateAsync({
                voucherId,
                idempotencyKey: key.current,
                input: { amount: cents, payment, note: note || null },
              })
              toast.success(`${formatMoney(cents, currency)} loaded · new balance ${formatMoney(result.data.voucher.balance, currency)}`)
              reset()
              onOpenChange(false)
            } catch (err) {
              if (isUncertainOutcome(err)) {
                setUncertain(true)
                setError(
                  "The connection was interrupted, so it is not known whether the reload was booked. Press “Check and reload”: it can never be booked twice.",
                )
              } else {
                setUncertain(false)
                setError(errorMessage(err))
                key.current = newIdempotencyKey()
              }
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="amount">Amount</Label>
            <MoneyInput id="amount" autoFocus disabled={uncertain} value={amount} onChange={(e) => setAmount(e.target.value)} className="h-12 text-xl" />
            {tooMuch ? <p className="text-destructive text-xs">The balance would exceed {formatMoney(maxBalance, currency)}.</p> : null}
          </div>
          {!uncertain ? <PaymentFields value={payment} onChange={setPayment} /> : null}
          <div className="space-y-2">
            <Label htmlFor="note">Note</Label>
            <Input id="note" disabled={uncertain} value={note} onChange={(e) => setNote(e.target.value)} maxLength={500} />
          </div>
          {error ? <p className="bg-destructive/10 text-destructive rounded-lg px-3 py-2 text-sm">{error}</p> : null}
          <DialogFooter>
            {!uncertain ? (
              <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
                Cancel
              </Button>
            ) : null}
            <Button type="submit" disabled={invalid || mutation.isPending}>
              {mutation.isPending ? <Loader2 className="animate-spin" /> : null}
              {uncertain ? "Check and reload" : `Reload ${cents ? formatMoney(cents, currency) : ""}`}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
