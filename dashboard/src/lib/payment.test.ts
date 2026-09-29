import { test } from "node:test"
import assert from "node:assert/strict"
import { paymentComplete } from "./payment.ts"

test("cash needs nothing else", () => {
  assert.equal(paymentComplete({ method: "cash" }), true)
})

test("card terminal and bank transfer need a reference", () => {
  assert.equal(paymentComplete({ method: "card_terminal" }), false)
  assert.equal(paymentComplete({ method: "card_terminal", reference: "  " }), false)
  assert.equal(paymentComplete({ method: "card_terminal", reference: "T-4711" }), true)
  assert.equal(paymentComplete({ method: "bank_transfer", reference: "AT-2026-01" }), true)
})

test("complimentary needs a reason of at least three characters", () => {
  assert.equal(paymentComplete({ method: "complimentary" }), false)
  assert.equal(paymentComplete({ method: "complimentary", reason: "ok" }), false)
  assert.equal(paymentComplete({ method: "complimentary", reason: "Raffle prize" }), true)
})
