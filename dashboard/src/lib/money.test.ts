import { test } from "node:test"
import assert from "node:assert/strict"
import { centsToInput, formatMoney, parseMoneyInput } from "./money.ts"

test("decimal comma and decimal point", () => {
  assert.equal(parseMoneyInput("12,50"), 1250)
  assert.equal(parseMoneyInput("12.50"), 1250)
  assert.equal(parseMoneyInput("12,5"), 1250)
  assert.equal(parseMoneyInput("0,05"), 5)
  assert.equal(parseMoneyInput("12"), 1200)
  assert.equal(parseMoneyInput("12,"), 1200)
})

test("thousands separators in de-AT and en notation", () => {
  assert.equal(parseMoneyInput("1.234,50"), 123450)
  assert.equal(parseMoneyInput("1,234.50"), 123450)
  assert.equal(parseMoneyInput("1.234"), 123400)
  assert.equal(parseMoneyInput("1.234.567"), 123456700)
  assert.equal(parseMoneyInput("12,505"), 1250500)
  assert.equal(parseMoneyInput("1 234,50"), 123450)
  assert.equal(parseMoneyInput("1 234,50"), 123450)
  assert.equal(parseMoneyInput("€ 25,00"), 2500)
  assert.equal(parseMoneyInput(" 25 € "), 2500)
})

test("a typo never becomes a different amount", () => {
  for (const input of ["-12,50", "−5", "1e5", "12abc", "abc", "", ",", "1,2,3", "12.34.5", "1.23,4.5", "1,234,5", "1..5", "+5", "0x10"]) {
    assert.equal(parseMoneyInput(input), null, input)
  }
})

test("huge values are refused", () => {
  assert.equal(parseMoneyInput("999999999999999999999"), null)
  assert.equal(parseMoneyInput("1000000000,01"), null)
  assert.equal(parseMoneyInput("1000000000"), 100_000_000_000)
})

test("round trip with the locale's formatting", () => {
  assert.equal(centsToInput(123450, "de-AT"), "1234,50")
  assert.equal(parseMoneyInput(centsToInput(123450, "de-AT")), 123450)
  assert.equal(parseMoneyInput(centsToInput(123450, "en-GB")), 123450)
  assert.equal(parseMoneyInput(formatMoney(123450, "EUR", "de-AT")), 123450)
  assert.equal(parseMoneyInput(formatMoney(123450, "EUR", "en-GB")), 123450)
})
