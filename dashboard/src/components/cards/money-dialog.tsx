"use client"

import { useRef, useState } from "react"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { MoneyInput } from "@/components/common/money-input"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { useMoneyOperation } from "@/lib/api/hooks"
import { ApiError, errorMessage, newIdempotencyKey } from "@/lib/api/client"
import { centsToInput, formatMoney, parseMoneyInput } from "@/lib/money"

export function MoneyDialog({
  kind,
  cardId,
  balance,
  currency,
  open,
  onOpenChange,
}: {
  kind: "redeem" | "reload"
  cardId: string
  balance: number
  currency: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const [amount, setAmount] = useState("")
  const [reference, setReference] = useState("")
  const [note, setNote] = useState("")
  const [error, setError] = useState<string | null>(null)
  const key = useRef(newIdempotencyKey())
  const mutation = useMoneyOperation(kind)
  const cents = parseMoneyInput(amount)
  const invalid = !cents || cents <= 0 || (kind === "redeem" && cents > balance)

  const reset = () => {
    setAmount("")
    setReference("")
    setNote("")
    setError(null)
    key.current = newIdempotencyKey()
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!o) reset()
        onOpenChange(o)
      }}
    >
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{kind === "redeem" ? "Redeem balance" : "Reload card"}</DialogTitle>
          <DialogDescription>Current balance {formatMoney(balance, currency)}</DialogDescription>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            if (invalid || !cents) return
            setError(null)
            try {
              const result = await mutation.mutateAsync({
                cardId,
                idempotencyKey: key.current,
                input: { amount: cents, reference: reference || null, note: note || null },
              })
              toast.success(
                kind === "redeem"
                  ? `${formatMoney(cents, currency)} redeemed · remaining ${formatMoney(result.data.card.balance, currency)}`
                  : `${formatMoney(cents, currency)} loaded · new balance ${formatMoney(result.data.card.balance, currency)}`,
              )
              reset()
              onOpenChange(false)
            } catch (err) {
              setError(errorMessage(err))
              if (err instanceof ApiError && err.status < 500) key.current = newIdempotencyKey()
            }
          }}
        >
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <Label htmlFor="amount">Amount</Label>
              {kind === "redeem" ? (
                <button type="button" className="text-muted-foreground hover:text-foreground text-xs" onClick={() => setAmount(centsToInput(balance))}>
                  Full balance
                </button>
              ) : null}
            </div>
            <MoneyInput id="amount" autoFocus value={amount} onChange={(e) => setAmount(e.target.value)} className="h-12 text-xl" />
            {kind === "redeem" && cents && cents > balance ? <p className="text-destructive text-xs">Exceeds the available balance.</p> : null}
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="reference">Reference</Label>
              <Input id="reference" placeholder="Bill / table no." value={reference} onChange={(e) => setReference(e.target.value)} maxLength={120} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="note">Note</Label>
              <Input id="note" value={note} onChange={(e) => setNote(e.target.value)} maxLength={500} />
            </div>
          </div>
          {error ? <p className="bg-destructive/10 text-destructive rounded-lg px-3 py-2 text-sm">{error}</p> : null}
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={invalid || mutation.isPending}>
              {mutation.isPending ? <Loader2 className="animate-spin" /> : null}
              {kind === "redeem" ? "Redeem" : "Reload"} {cents ? formatMoney(cents, currency) : ""}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
