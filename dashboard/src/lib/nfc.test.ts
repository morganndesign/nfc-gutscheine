import assert from "node:assert/strict"
import { test } from "node:test"
import { NfcError, toNfcError, WebNfcDriver, type NDEFReaderLike } from "./nfc.ts"

/** Minimal stand-in for Chrome's NDEFReader. All instances share one "field" (the tag on the phone). */
class FakeReader extends EventTarget implements NDEFReaderLike {
  static all: FakeReader[] = []
  static writes: unknown[] = []
  static writeError: Error | null = null
  scanning = false
  constructor() {
    super()
    FakeReader.all.push(this)
  }
  async scan(options?: { signal?: AbortSignal }) {
    this.scanning = true
    options?.signal?.addEventListener("abort", () => (this.scanning = false))
  }
  async write(message: unknown, options?: { overwrite?: boolean }) {
    if (FakeReader.writeError) throw FakeReader.writeError
    FakeReader.writes.push({ message, overwrite: options?.overwrite })
  }
  async makeReadOnly() {}
  /** Simulates the browser delivering a read to this reader. */
  emit(serialNumber: string, url: string | null) {
    const event = new Event("reading") as Event & { serialNumber: string; message: unknown }
    event.serialNumber = serialNumber
    event.message = { records: url ? [{ recordType: "url", data: new DataView(new TextEncoder().encode(url).buffer) }] : [] }
    this.dispatchEvent(event)
  }
}

function reset() {
  FakeReader.all = []
  FakeReader.writes = []
  FakeReader.writeError = null
}

const tick = () => new Promise((r) => setTimeout(r, 0))

test("waitForTag returns serial number and URL; the session uses one scanning reader", async () => {
  reset()
  const driver = new WebNfcDriver(() => new FakeReader())
  const pending = driver.waitForTag(new AbortController().signal)
  await tick()
  assert.equal(FakeReader.all.length, 1)
  assert.ok(FakeReader.all[0].scanning)
  FakeReader.all[0].emit("04:a2:3f:1b:6c:80:12", "https://x.test/c/abc")
  assert.deepEqual(await pending, { serialNumber: "04:a2:3f:1b:6c:80:12", url: "https://x.test/c/abc", recordCount: 1 })

  const blank = driver.waitForTag(new AbortController().signal)
  await tick()
  FakeReader.all[0].emit("04:00:00:00:00:00:01", null)
  assert.deepEqual(await blank, { serialNumber: "04:00:00:00:00:00:01", url: null, recordCount: 0 })
  assert.equal(FakeReader.all.length, 1)
  driver.close()
  assert.equal(FakeReader.all[0].scanning, false)
})

test("readAgain starts a short-lived second scan and stops it after the read", async () => {
  reset()
  const driver = new WebNfcDriver(() => new FakeReader())
  const again = driver.readAgain(new AbortController().signal)
  await tick()
  assert.equal(FakeReader.all.length, 2)
  FakeReader.all[1].emit("04:01", "https://x.test/c/abc")
  assert.equal((await again).url, "https://x.test/c/abc")
  assert.equal(FakeReader.all[1].scanning, false, "probe reader stopped")
  assert.ok(FakeReader.all[0].scanning, "session reader keeps scanning")

  // A re-tap delivered through the main reader also resolves it.
  const retap = driver.readAgain(new AbortController().signal)
  await tick()
  FakeReader.all[0].emit("04:01", "https://x.test/c/abc")
  assert.equal((await retap).serialNumber, "04:01")
})

test("write replaces the whole message (overwrite) and maps browser errors", async () => {
  reset()
  const driver = new WebNfcDriver(() => new FakeReader())
  await driver.write([{ recordType: "url", data: "https://x.test/c/abc" }], new AbortController().signal)
  assert.deepEqual(FakeReader.writes, [{ message: { records: [{ recordType: "url", data: "https://x.test/c/abc" }] }, overwrite: true }])

  FakeReader.writeError = new DOMException("io", "NetworkError")
  await assert.rejects(driver.write([{ recordType: "url", data: "x" }], new AbortController().signal), (e: NfcError) => e.code === "WRITE_FAILED")
})

test("cancel rejects the pending wait", async () => {
  reset()
  const driver = new WebNfcDriver(() => new FakeReader())
  const controller = new AbortController()
  const pending = driver.waitForTag(controller.signal)
  controller.abort()
  await assert.rejects(pending, (e: NfcError) => e.code === "CANCELLED")
})

test("scan permission errors are surfaced to the waiting step", async () => {
  reset()
  class Denied extends FakeReader {
    async scan() {
      throw new DOMException("denied", "NotAllowedError")
    }
  }
  const driver = new WebNfcDriver(() => new Denied())
  await assert.rejects(driver.waitForTag(new AbortController().signal), (e: NfcError) => e.code === "PERMISSION_DENIED")
})

test("error mapping", () => {
  assert.equal((toNfcError(new DOMException("x", "NotSupportedError")) as NfcError).code, "NFC_DISABLED")
  assert.equal((toNfcError(new DOMException("x", "NetworkError")) as NfcError).code, "TAG_LOST")
  assert.equal((toNfcError(new DOMException("x", "NetworkError"), "write") as NfcError).code, "WRITE_FAILED")
  assert.equal((toNfcError(new DOMException("x", "AbortError")) as NfcError).code, "CANCELLED")
})
