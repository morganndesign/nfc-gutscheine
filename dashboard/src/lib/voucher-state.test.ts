import { test } from "node:test"
import assert from "node:assert/strict"
import { displayStatus, soldToday } from "./voucher-state.ts"

test("an active voucher past its expiry date shows as expired", () => {
  assert.equal(displayStatus({ status: "active", balance: 5000, is_expired: true }), "expired")
  assert.equal(displayStatus({ status: "active", balance: 0, is_expired: true }), "expired")
})

test("status badges", () => {
  assert.equal(displayStatus({ status: "active", balance: 5000, is_expired: false }), "active")
  assert.equal(displayStatus({ status: "active", balance: 0 }), "empty")
  assert.equal(displayStatus({ status: "blocked", balance: 5000, is_expired: true }), "blocked")
  assert.equal(displayStatus({ status: "refunded", balance: 0 }), "refunded")
  assert.equal(displayStatus({ status: "expired", balance: 2000, is_expired: true }), "expired")
})

test("'sold today' is the restaurant's day, not the browser's", () => {
  // 23:30 in Vienna on 1 October is 21:30 UTC; at 00:30 Vienna time on 2 October it is no longer today there.
  const sold = "2026-10-01T21:30:00Z"
  const now = new Date("2026-10-01T22:30:00Z")
  assert.equal(soldToday(sold, "Europe/Vienna", now), false)
  assert.equal(soldToday(sold, "UTC", now), true)
  // Sold at 00:10 Vienna time (22:10 UTC the day before) is today in Vienna at 10:00.
  assert.equal(soldToday("2026-10-01T22:10:00Z", "Europe/Vienna", new Date("2026-10-02T08:00:00Z")), true)
  assert.equal(soldToday("2026-10-01T22:10:00Z", "America/New_York", new Date("2026-10-02T08:00:00Z")), false)
})
