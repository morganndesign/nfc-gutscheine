import { test } from "node:test"
import assert from "node:assert/strict"
import { format, toLanguage } from "./format.ts"

test("placeholders are filled", () => {
  assert.equal(format("en", "Revoke {name}?", { name: "Pixel 7" }), "Revoke Pixel 7?")
  assert.equal(format("en", "{a} and {missing}", { a: 1 }), "1 and ")
})

test("plurals follow the language", () => {
  const msg = "{count, plural, one {# voucher} other {# vouchers}}"
  assert.equal(format("en", msg, { count: 1 }), "1 voucher")
  assert.equal(format("en", msg, { count: 3 }), "3 vouchers")
  const bs = "{count, plural, one {# vaučer} few {# vaučera} other {# vaučera}}"
  assert.equal(format("bs", bs, { count: 21 }), "21 vaučer")
  assert.equal(format("bs", bs, { count: 3 }), "3 vaučera")
  assert.equal(format("de", "{n, plural, =0 {keine} one {# Karte} other {# Karten}}", { n: 0 }), "keine")
  assert.equal(format("de", "Seit {count, plural, one {# Tag} other {# Tagen}} offen", { count: 2 }), "Seit 2 Tagen offen")
})

test("languages: German unless English or BHS", () => {
  assert.equal(toLanguage("de-AT"), "de")
  assert.equal(toLanguage("en"), "en")
  assert.equal(toLanguage("hr"), "bs")
  assert.equal(toLanguage(null), "de")
  assert.equal(toLanguage("fr"), "de")
})
