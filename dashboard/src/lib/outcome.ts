/**
 * A money request whose outcome is unknown: the connection dropped or the server failed after the request may
 * have been booked (audit M1, M2, M6). The same idempotency key must be sent again, never a new one, and the
 * screen must never claim that nothing was booked.
 *
 * - No answer (no connection, timeout, aborted request), a 5xx or a 408 is uncertain.
 * - A first answer with any other status is definitive: nothing was booked with this key.
 * - Once a request with this key went unanswered, only a code of the operation itself is definitive. The server
 *   looks the key up before its limits and checks, so a booked key is always answered with what it booked. A
 *   gateway answer (401, 403, 429, 404, …) or an unknown code says nothing about the earlier request.
 */
export function isUncertainOutcome(error: unknown, earlier?: { unanswered: boolean; finalCodes: ReadonlySet<string> }): boolean {
  if (typeof error !== "object" || error === null || !("status" in error) || typeof error.status !== "number") return true
  if (error.status >= 500 || error.status === 408) return true
  if (!earlier?.unanswered) return false
  const code = "code" in error && typeof error.code === "string" ? error.code : null
  return code === null || !earlier.finalCodes.has(code)
}

/** Codes only a redemption answers with, after it looked the key up. */
export const REDEMPTION_CODES: ReadonlySet<string> = new Set([
  "PRESENTMENT_INVALID",
  "INSUFFICIENT_BALANCE",
  "VOUCHER_BLOCKED",
  "VOUCHER_EXPIRED",
  "VOUCHER_NOT_REDEEMABLE",
  "INVALID_VOUCHER_STATE",
  "DEBIT_LIMIT_EXCEEDED",
  "VELOCITY_LIMIT_EXCEEDED",
  "INVALID_AMOUNT",
])

/** Codes a cancellation answers with after it looked the key up: nothing was booked. */
export const CANCEL_CODES: ReadonlySet<string> = new Set(["VALIDATION_FAILED", "INVALID_VOUCHER_STATE", "INVALID_AMOUNT", "IDEMPOTENCY_CONFLICT"])

/** Codes only a sale answers with. */
export const SALE_CODES: ReadonlySet<string> = new Set(["INVALID_AMOUNT", "BALANCE_LIMIT_EXCEEDED", "VALIDATION_FAILED", "COMPLIMENTARY_NOT_ALLOWED"])

/** Codes only a reload answers with. */
export const RELOAD_CODES: ReadonlySet<string> = new Set([
  ...SALE_CODES,
  "VOUCHER_BLOCKED",
  "VOUCHER_EXPIRED",
  "VOUCHER_NOT_REDEEMABLE",
  "INVALID_VOUCHER_STATE",
  "LOYALTY_VOUCHER_ONLY",
])

/**
 * Codes only a refund answers with (the voucher state checks run after the key lookup). A 403 is not one of them: it
 * comes from the route's permission check, before the key is looked up, and says nothing about an earlier attempt.
 */
export const REFUND_CODES: ReadonlySet<string> = new Set([
  "VALIDATION_FAILED",
  "VOUCHER_NOT_REFUNDABLE",
  "VOUCHER_NOT_REDEEMABLE",
  "INSUFFICIENT_BALANCE",
  "INVALID_AMOUNT",
  "IDEMPOTENCY_CONFLICT",
])

/**
 * Keys of requests that went unanswered, kept in this browser tab (sessionStorage) under a description of the
 * request. Leaving the page does not lose them: sending the same request again reuses the key, so the server
 * answers with what the lost request booked instead of booking it twice. Kept for [PENDING_KEY_TTL_MS]; storage
 * that is unavailable only loses this safety net, never the page.
 */
export const PENDING_KEY_TTL_MS = 15 * 60 * 1000
const PREFIX = "gcp.pending-key."

export function pendingKey(scope: string, now: number = Date.now()): string | null {
  try {
    const raw = window.sessionStorage.getItem(PREFIX + scope)
    if (!raw) return null
    const stored = JSON.parse(raw) as { key?: unknown; at?: unknown }
    if (typeof stored.key !== "string" || typeof stored.at !== "number" || now - stored.at > PENDING_KEY_TTL_MS) {
      window.sessionStorage.removeItem(PREFIX + scope)
      return null
    }
    return stored.key
  } catch {
    return null
  }
}

export function rememberPendingKey(scope: string, key: string, now: number = Date.now()): void {
  try {
    window.sessionStorage.setItem(PREFIX + scope, JSON.stringify({ key, at: now }))
  } catch {
    // Storage unavailable: the page still keeps the key while it is open.
  }
}

export function forgetPendingKey(scope: string): void {
  try {
    window.sessionStorage.removeItem(PREFIX + scope)
  } catch {
    // Nothing stored.
  }
}
