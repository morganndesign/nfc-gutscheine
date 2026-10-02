import type { VoucherStatus } from "./api/types.ts"

/**
 * The status staff see: "expired" also for an active voucher past its expiry date (the nightly job that sets the
 * status may not have run yet, but the server already refuses it), "empty" for an active voucher without balance.
 */
export function displayStatus(voucher: { status: VoucherStatus; balance: number; is_expired?: boolean }): VoucherStatus | "empty" {
  if (voucher.status === "active" && voucher.is_expired) return "expired"
  return voucher.status === "active" && voucher.balance === 0 ? "empty" : voucher.status
}

/** The calendar day (YYYY-MM-DD) of a moment in a timezone (undefined: the browser's). */
export function dayIn(moment: Date, timeZone: string | undefined): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).format(moment)
}

/**
 * A sale booked by mistake may be cancelled while the voucher is untouched and it was sold today — today in the
 * restaurant's timezone, like the server decides, not in the browser's.
 */
export function soldToday(createdAt: string, timeZone: string | undefined, now: Date = new Date()): boolean {
  return dayIn(new Date(createdAt), timeZone) === dayIn(now, timeZone)
}
