import { test } from "node:test"
import assert from "node:assert/strict"
import { guestCopy, guestLocale } from "./guest-copy.ts"

test("guests read the restaurant's language", () => {
  assert.equal(guestCopy("de-AT").voucher, "Gutschein")
  assert.equal(guestCopy("en-GB").voucher, "Voucher")
  assert.equal(guestCopy("bs-BA").voucher, "Vaučer")
  assert.equal(guestCopy("hr_HR").voucher, "Vaučer")
  assert.equal(guestCopy("sr-Latn-RS").voucher, "Vaučer")
  assert.equal(guestCopy(null).voucher, "Gutschein")
})

test("guest texts carry no figures; the value is printed from the sale, in the restaurant format", () => {
  for (const locale of ["de", "en", "bs"]) {
    const texts = Object.values(guestCopy(locale)).join(" ")
    assert.doesNotMatch(texts, /€|EUR|\d/)
  }
})

test("the value label and money format follow the restaurant", () => {
  assert.equal(guestCopy("de-AT").value, "Wert")
  assert.equal(guestCopy("bs-BA").value, "Vrijednost")
  assert.equal(guestLocale("bs_BA"), "bs-BA")
  assert.equal(guestLocale(null), "de-AT")
})
