"use client"

import { useRef, useState } from "react"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { MoneyInput } from "@/components/common/money-input"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { useTransferBalance } from "@/lib/api/hooks"
import { ApiError, errorMessage, newIdempotencyKey } from "@/lib/api/client"
import { formatMoney, parseMoneyInput } from "@/lib/money"

export function TransferDialog({
  cardId,
  balance,
  currency,
  open,
  onOpenChange,
}: {
  cardId: string
  balance: number
  currency: string
  open: boolean
  onOpenChange: (o: boolean) => void
}) {
  const [target, setTarget] = useState("")
  const [amount, setAmount] = useState("")
  const [error, setError] = useState<string | null>(null)
  const key = useRef(newIdempotencyKey())
  const transfer = useTransferBalance(cardId)
  const cents = amount ? parseMoneyInput(amount) : null

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Transfer balance</DialogTitle>
          <DialogDescription>Move value to another card of this restaurant. Available: {formatMoney(balance, currency)}</DialogDescription>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            setError(null)
            try {
              const res = await transfer.mutateAsync({ idempotencyKey: key.current, input: { target_card_number: target, amount: cents } })
              toast.success(`Transferred. Target card balance: ${formatMoney(res.data.target.balance, currency)}`)
              key.current = newIdempotencyKey()
              setTarget("")
              setAmount("")
              onOpenChange(false)
            } catch (err) {
              setError(errorMessage(err))
              if (err instanceof ApiError && err.status < 500) key.current = newIdempotencyKey()
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="target">Target card number</Label>
            <Input
              id="target"
              inputMode="numeric"
              className="card-number"
              placeholder="1234 5678 9012 3456"
              value={target}
              onChange={(e) => setTarget(e.target.value)}
              autoFocus
              required
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="amount">Amount</Label>
            <MoneyInput id="amount" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="Full balance" />
          </div>
          {error ? <p className="bg-destructive/10 text-destructive rounded-lg px-3 py-2 text-sm">{error}</p> : null}
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={transfer.isPending || target.replace(/\D/g, "").length < 8 || (cents !== null && (cents <= 0 || cents > balance))}>
              {transfer.isPending ? <Loader2 className="animate-spin" /> : null} Transfer {cents ? formatMoney(cents, currency) : "all"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
