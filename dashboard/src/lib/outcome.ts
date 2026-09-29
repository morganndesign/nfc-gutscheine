/**
 * A money request whose outcome is unknown: the connection dropped or the server failed after the request may
 * have been booked (audit M1, M2, M6). The same idempotency key must be sent again, never a new one, and the
 * screen must never claim that nothing was booked.
 *
 * Any error with an HTTP status (ApiError) is judged by its status; anything else (no connection, timeout,
 * aborted request) is uncertain.
 */
export function isUncertainOutcome(error: unknown): boolean {
  if (typeof error === "object" && error !== null && "status" in error && typeof error.status === "number") {
    return error.status >= 500 || error.status === 408
  }
  return true
}
