import { test } from "node:test"
import assert from "node:assert/strict"
import { displayStatus } from "./voucher-state.ts"

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

