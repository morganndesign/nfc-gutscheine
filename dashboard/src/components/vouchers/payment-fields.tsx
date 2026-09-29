"use client"

import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Segmented } from "@/components/common/segmented"
import type { PaymentInput } from "@/lib/api/hooks"
import type { PaymentMethod } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"

export { paymentComplete } from "@/lib/payment"

const LABELS: Record<PaymentMethod, string> = {
  cash: "Cash",
  card_terminal: "Card terminal",
  bank_transfer: "Bank transfer",
  complimentary: "Complimentary",
}

/** Every sale and reload records how the money was received (decision 25). */
export function PaymentFields({ value, onChange }: { value: PaymentInput; onChange: (value: PaymentInput) => void }) {
  const { can } = useAuth()
  const methods: PaymentMethod[] = ["cash", "card_terminal", "bank_transfer", ...(can("vouchers.sell_complimentary") ? (["complimentary"] as const) : [])]

  return (
    <div className="space-y-3">
      <div className="space-y-2">
        <Label>Payment</Label>
        <Segmented
          label="Payment method"
          value={value.method}
          onChange={(method) => onChange({ method, reference: null, reason: null })}
          options={methods.map((m) => ({ value: m, label: LABELS[m] }))}
          className="w-full"
        />
      </div>
      {value.method === "card_terminal" || value.method === "bank_transfer" ? (
        <div className="space-y-2">
          <Label htmlFor="payment-reference">{value.method === "card_terminal" ? "Terminal receipt number" : "Bank reference"}</Label>
          <Input
            id="payment-reference"
            required
            maxLength={120}
            value={value.reference ?? ""}
            onChange={(e) => onChange({ ...value, reference: e.target.value })}
          />
        </div>
      ) : null}
      {value.method === "complimentary" ? (
        <div className="space-y-2">
          <Label htmlFor="payment-reason">Why is this voucher free?</Label>
          <Input
            id="payment-reason"
            required
            minLength={3}
            maxLength={500}
            placeholder="e.g. raffle prize, guest compensation"
            value={value.reason ?? ""}
            onChange={(e) => onChange({ ...value, reason: e.target.value })}
          />
          <p className="text-muted-foreground text-xs">Complimentary value is not revenue and is listed separately in reports.</p>
        </div>
      ) : null}
    </div>
  )
}
