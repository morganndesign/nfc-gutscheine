"use client"

import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Segmented } from "@/components/common/segmented"
import type { PaymentInput } from "@/lib/api/hooks"
import type { PaymentMethod } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

export { paymentComplete } from "@/lib/payment"

/** How the money was received, by method (translate the server's `method_label` from the method instead). */
export const PAYMENT_METHOD_LABELS: Record<PaymentMethod, MessageKey> = {
  cash: "payment.method.cash",
  card_terminal: "payment.method.card_terminal",
  bank_transfer: "payment.method.bank_transfer",
  complimentary: "payment.method.complimentary",
  online: "payment.method.online",
}

/**
 * Every sale and reload records how the money was received (decision 25). Loyalty is offered to those allowed to
 * give it, and on a top-up only for a loyalty voucher (`loyalty: false`): a paid voucher never becomes one.
 */
export function PaymentFields({
  value,
  onChange,
  loyalty = true,
}: {
  value: PaymentInput
  onChange: (value: PaymentInput) => void
  loyalty?: boolean
}) {
  const { can } = useAuth()
  const t = useT()
  const methods: PaymentMethod[] = ["cash", "card_terminal", "bank_transfer", ...(loyalty && can("vouchers.sell_complimentary") ? (["complimentary"] as const) : [])]

  return (
    <div className="space-y-3">
      <div className="space-y-2">
        <Label>{t("payment.label")}</Label>
        <Segmented
          label={t("payment.methodAria")}
          value={value.method}
          onChange={(method) => onChange({ method, reference: null, reason: null })}
          options={methods.map((m) => ({ value: m, label: t(PAYMENT_METHOD_LABELS[m]) }))}
          className="w-full"
        />
      </div>
      {value.method === "card_terminal" || value.method === "bank_transfer" ? (
        <div className="space-y-2">
          <Label htmlFor="payment-reference">{value.method === "card_terminal" ? t("payment.terminalReceipt") : t("payment.bankReference")}</Label>
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
          <Label htmlFor="payment-reason">{t("payment.complimentaryReason")}</Label>
          <Input
            id="payment-reason"
            required
            minLength={3}
            maxLength={500}
            placeholder={t("payment.complimentaryPlaceholder")}
            value={value.reason ?? ""}
            onChange={(e) => onChange({ ...value, reason: e.target.value })}
          />
          <p className="text-muted-foreground text-xs">{t("payment.complimentaryHint")}</p>
        </div>
      ) : null}
    </div>
  )
}
