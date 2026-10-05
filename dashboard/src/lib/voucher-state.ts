import type { VoucherStatus } from "./api/types.ts"

/**
 * The status staff see: "expired" also for an active voucher past its expiry date (the nightly job that sets the
 * status may not have run yet, but the server already refuses it), "empty" for an active voucher without balance.
 */
export function displayStatus(voucher: { status: VoucherStatus; balance: number; is_expired?: boolean }): VoucherStatus | "empty" {
  if (voucher.status === "active" && voucher.is_expired) return "expired"
  return voucher.status === "active" && voucher.balance === 0 ? "empty" : voucher.status
}
