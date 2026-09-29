import { test } from "node:test"
import assert from "node:assert/strict"
import { guestCopy } from "./guest-copy.ts"

test("guests read the restaurant's language", () => {
  assert.equal(guestCopy("de-AT").voucher, "Gutschein")
  assert.equal(guestCopy("en-GB").voucher, "Voucher")
  assert.equal(guestCopy(null).voucher, "Gutschein")
})

test("no guest text mentions a number or a value", () => {
  for (const locale of ["de", "en"]) {
    const texts = Object.values(guestCopy(locale)).join(" ")
    assert.doesNotMatch(texts, /€|EUR|\d/)
  }
})
