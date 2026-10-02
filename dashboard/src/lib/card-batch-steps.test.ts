import { test } from "node:test"
import assert from "node:assert/strict"
import { BATCH_STATUSES, nextStep, SPECIAL_TRANSITIONS } from "./card-batch-steps.ts"
import type { CardBatchCounts } from "./api/types.ts"

const counts = (c: Partial<CardBatchCounts>): CardBatchCounts => ({
  in_production: 0,
  qa_failed: 0,
  central_stock: 0,
  in_transit: 0,
  available: 0,
  activated: 0,
  replaced: 0,
  revoked: 0,
  lost: 0,
  destroyed: 0,
  registered: 0,
  ...c,
})

test("a batch in production is released with its personalised cards", () => {
  assert.deepEqual(nextStep({ status: "in_production", counts: counts({ central_stock: 2, in_production: 1 }) }), {
    kind: "release",
    ready: 2,
    unfinished: 1,
  })
  // Nothing personalised yet: the page disables the button.
  assert.deepEqual(nextStep({ status: "in_production", counts: counts({}) }), { kind: "release", ready: 0, unfinished: 0 })
})

test("a released batch ships; a shipped one waits for the restaurant", () => {
  assert.deepEqual(nextStep({ status: "accepted", counts: counts({ central_stock: 5 }) }), { kind: "ship", cards: 5 })
  assert.deepEqual(nextStep({ status: "shipped", counts: counts({ in_transit: 5 }) }), { kind: "awaiting-receipt" })
  assert.deepEqual(nextStep({ status: "on_hold", counts: counts({}) }), { kind: "on-hold" })
  for (const status of ["in_service", "depleted", "rejected", "lost", "compromised", "closed"] as const) {
    assert.deepEqual(nextStep({ status, counts: counts({}) }), { kind: "none" })
  }
})

test("the main steps are never offered as special transitions", () => {
  const offered = Object.values(SPECIAL_TRANSITIONS).flat()
  for (const own of ["in_production", "accepted", "shipped", "in_service", "on_hold"]) {
    assert.ok(!offered.includes(own as never), own)
  }
  assert.deepEqual(SPECIAL_TRANSITIONS.closed, undefined)
  assert.equal(BATCH_STATUSES.length, 10)
})
