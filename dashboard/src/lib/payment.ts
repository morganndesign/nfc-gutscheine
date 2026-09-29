import type { PaymentMethod } from "./api/types.ts"

export interface PaymentDraft {
  method: PaymentMethod
  reference?: string | null
  reason?: string | null
}

/** True when the payment details are complete for the chosen method (mirrors the server's rules). */
export function paymentComplete(p: PaymentDraft): boolean {
  if (p.method === "card_terminal" || p.method === "bank_transfer") return !!p.reference?.trim()
  if (p.method === "complimentary") return (p.reason?.trim().length ?? 0) >= 3
  return true
}
