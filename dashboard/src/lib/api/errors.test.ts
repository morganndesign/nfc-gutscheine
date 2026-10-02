import { test } from "node:test"
import assert from "node:assert/strict"
import { ApiError, errorText } from "./errors.ts"

const known = (code: string) => ["NOT_FOUND", "TOO_MANY_REQUESTS", "INSUFFICIENT_BALANCE"].includes(code)

test("a known error code is translated", () => {
  assert.deepEqual(errorText(new ApiError(422, { code: "INSUFFICIENT_BALANCE", message: "Not enough balance." }), known), {
    kind: "code",
    code: "INSUFFICIENT_BALANCE",
  })
})

test("validation messages (localised by the server) are shown", () => {
  const error = new ApiError(422, {
    code: "VALIDATION_FAILED",
    message: "The email has already been taken.",
    errors: { email: ["Diese E-Mail ist bereits vergeben."] },
  })
  assert.deepEqual(errorText(error, known), { kind: "field", message: "Diese E-Mail ist bereits vergeben." })
})

test("English server texts never reach the user", () => {
  // Laravel's 500 page, a reverse proxy's 502 HTML (no JSON body), an unknown HTTP_ code.
  assert.deepEqual(errorText(new ApiError(500, { message: "Server Error" }), known), { kind: "generic" })
  assert.deepEqual(errorText(new ApiError(502, {}), known), { kind: "generic" })
  assert.deepEqual(errorText(new ApiError(405, { code: "HTTP_405", message: "The POST method is not supported for route api/v1/x." }), known), {
    kind: "generic",
  })
  assert.deepEqual(errorText(new Error("Unexpected token < in JSON"), known), { kind: "generic" })
})

test("no connection is explained as such", () => {
  assert.deepEqual(errorText(new TypeError("Failed to fetch"), known), { kind: "offline" })
})
