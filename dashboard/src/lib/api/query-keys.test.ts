import { test } from "node:test"
import assert from "node:assert/strict"
import { VOUCHER_DATA_KEYS, keys } from "./query-keys.ts"

/** Mirrors React Query's prefix matching of `invalidateQueries({ queryKey })`. */
const invalidated = (key: readonly unknown[]) => VOUCHER_DATA_KEYS.some((prefix) => prefix.every((part, i) => key[i] === part))

test("a money movement refreshes every view of it", () => {
  for (const key of [
    keys.voucher("v1"),
    keys.voucherHistory("v1"),
    [...keys.vouchers, "list", { page: 1 }],
    [...keys.cashUp, "2026-10-02"],
    [...keys.dashboard, "stats"],
    [...keys.transactions, { page: 1 }],
    keys.customer("c1"),
    [...keys.cards, "one", "B-0001-0001-0001"],
  ]) {
    assert.ok(invalidated(key), JSON.stringify(key))
  }
})

test("unrelated data is left alone", () => {
  for (const key of [keys.session, keys.users, keys.devices, keys.settings, keys.admin]) assert.equal(invalidated(key), false, JSON.stringify(key))
})
