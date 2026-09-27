import assert from "node:assert/strict"
import { test } from "node:test"
import { NfcError, type NfcDriver, type NfcRecord, type TagSnapshot } from "./nfc.ts"
import {
  apiFailure,
  describeError,
  detectTagType,
  normalizeUid,
  PROBES,
  probeRecord,
  programCard,
  ProgrammingError,
  urlMessageSize,
  type CheckResult,
  type FailureReport,
  type ProgrammingApi,
  type ProgressEvent,
} from "./nfc-programming.ts"

const URL = "https://app.giftcardpro.at/c/3f6c2b1e-8d4a-4c5e-9f1a-2b3c4d5e6f70"
const CAP = { ntag213: 144, ntag215: 504, ntag216: 888, ntag424: 256 }

/** Independent NDEF size model of the fake chip (not the implementation's). */
function messageSize(records: NfcRecord[]): number {
  return records.reduce((sum, r) => {
    const payload = r.recordType === "url" ? 1 + new TextEncoder().encode(r.data.replace(/^https:\/\//, "")).length : r.data.length
    const type = r.recordType === "url" ? 1 : r.mediaType.length
    return sum + 2 + (payload < 256 ? 1 : 4) + type + payload
  }, 0)
}

class FakeTag {
  records: NfcRecord[] = []
  readOnly = false
  writes: NfcRecord[][] = []
  serial: string
  memory: number
  constructor(serial: string, memory: number, url: string | null = null) {
    this.serial = serial
    this.memory = memory
    if (url) this.records = [{ recordType: "url", data: url }]
  }
  /** NDEF TLV overhead: 2 (or 4 for long messages) + terminator. */
  fits(records: NfcRecord[]): boolean {
    const size = messageSize(records)
    return size + (size < 255 ? 2 : 4) + 1 <= this.memory
  }
  snapshot(): TagSnapshot {
    const url = this.records.find((r) => r.recordType === "url") as { data: string } | undefined
    return { serialNumber: this.serial, url: url?.data ?? null, recordCount: this.records.length }
  }
}

interface DriverOptions {
  /** Tags presented one after the other to waitForTag. */
  queue: FakeTag[]
  corruptUrlWrite?: boolean
  staleFirstReadBack?: boolean
  swapOnReadBack?: FakeTag
  failUrlWrite?: boolean
  lockFails?: boolean
  readBackHangs?: boolean
}

class FakeDriver implements NfcDriver {
  current: FakeTag | null = null
  readBacks = 0
  locked = false
  closed = false
  private readonly o: DriverOptions
  constructor(o: DriverOptions) {
    this.o = o
  }
  get canMakeReadOnly() {
    return true
  }
  async waitForTag(signal: AbortSignal): Promise<TagSnapshot> {
    const next = this.o.queue.shift()
    if (!next) {
      return new Promise((_, reject) => signal.addEventListener("abort", () => reject(new NfcError("CANCELLED", "Cancelled."))))
    }
    this.current = next
    return next.snapshot()
  }
  async readAgain(signal: AbortSignal): Promise<TagSnapshot> {
    this.readBacks++
    if (this.o.readBackHangs) {
      return new Promise((_, reject) => signal.addEventListener("abort", () => reject(new NfcError("CANCELLED", "Cancelled."))))
    }
    if (this.o.swapOnReadBack) return this.o.swapOnReadBack.snapshot()
    const tag = this.tag()
    if (this.o.staleFirstReadBack && this.readBacks === 1) return { serialNumber: tag.serial, url: null, recordCount: 1 }
    return tag.snapshot()
  }
  async write(records: NfcRecord[]): Promise<void> {
    const tag = this.tag()
    const isUrl = records[0]?.recordType === "url"
    if (tag.readOnly || !tag.fits(records) || (isUrl && this.o.failUrlWrite)) throw new NfcError("WRITE_FAILED", "The tag could not be written.")
    tag.writes.push(records)
    tag.records = isUrl && this.o.corruptUrlWrite ? [{ recordType: "url", data: URL.slice(0, -1) }] : records
  }
  async makeReadOnly(): Promise<void> {
    if (this.o.lockFails) throw new NfcError("WRITE_FAILED", "The tag could not be locked.")
    this.tag().readOnly = true
    this.locked = true
  }
  close() {
    this.closed = true
  }
  /** The operator holds a tag again (used by "Try again"). */
  present(tag: FakeTag) {
    this.o.queue.push(tag)
  }
  /** The next attempt writes normally (the tag is held still this time). */
  fix() {
    this.o.failUrlWrite = false
  }
  private tag(): FakeTag {
    assert.ok(this.current, "no tag in the field")
    return this.current
  }
}

class FakeApi implements ProgrammingApi {
  calls: string[] = []
  reports: FailureReport[] = []
  binds: unknown[] = []
  checkResult: Partial<CheckResult> = {}
  bindError: unknown = null
  async check(cardId: string, body: { attempt_id: string; uid: string; current_url: string | null }): Promise<CheckResult> {
    this.calls.push(`check:${body.uid}:${body.current_url ?? "-"}`)
    return {
      status: "available",
      reason: null,
      message: null,
      conflict: null,
      content: body.current_url ? "foreign" : "blank",
      replaces_tag: false,
      expected_url: URL,
      attempt_id: body.attempt_id,
      ...this.checkResult,
    }
  }
  async bind(_cardId: string, body: unknown) {
    this.calls.push("bind")
    if (this.bindError) throw this.bindError
    this.binds.push(body)
    return {}
  }
  async confirmLock() {
    this.calls.push("lock")
    return {}
  }
  async report(_cardId: string, body: FailureReport) {
    this.calls.push(`report:${body.stage}:${body.result}:${body.error_code}`)
    this.reports.push(body)
    return {}
  }
}

function run(driver: FakeDriver, api: FakeApi, extra: { lock?: boolean; signal?: AbortSignal; ignoreSerials?: string[]; events?: ProgressEvent[] } = {}) {
  return programCard(
    {
      cardId: "card-1",
      expectedUrl: URL,
      lock: extra.lock ?? false,
      attemptId: "8f0c7f4e-1c1b-4d9e-9a55-0f7f8d9a1b2c",
      signal: extra.signal ?? new AbortController().signal,
      ignoreSerials: extra.ignoreSerials,
      onProgress: (e) => extra.events?.push(e),
    },
    { driver, api, stepTimeoutMs: 200, retapHintMs: 50 },
  )
}

test("sizes: URL record uses the https:// abbreviation, probes have the exact message size", () => {
  assert.equal(urlMessageSize("https://a.b/c"), 2 + 1 + 1 + 1 + "a.b/c".length)
  for (const size of Object.values(PROBES)) assert.equal(messageSize([probeRecord(size)]), size)
})

test("detects NTAG213 / 215 / 216 by memory and rejects other chips", async () => {
  for (const [memory, expected] of [
    [CAP.ntag213, "ntag213"],
    [CAP.ntag215, "ntag215"],
    [CAP.ntag216, "ntag216"],
    [CAP.ntag424, "unsupported"],
  ] as const) {
    const tag = new FakeTag("04:01:02:03:04:05:06", memory)
    const writes: number[] = []
    const type = await detectTagType(async (records) => {
      writes.push(messageSize(records))
      if (!tag.fits(records)) throw new NfcError("WRITE_FAILED", "too big")
    })
    assert.equal(type, expected, `memory ${memory}`)
    assert.ok(writes.length <= 8)
  }
  // A locked tag accepts no write at all.
  assert.equal(
    await detectTagType(async () => {
      throw new NfcError("WRITE_FAILED", "read-only")
    }),
    "read_only",
  )
})

test("a brief loss of contact during detection is retried, not taken for a smaller chip", async () => {
  let failures = 1
  const tag = new FakeTag("04:01:02:03:04:05:06", CAP.ntag216)
  const type = await detectTagType(async (records) => {
    if (failures-- > 0) throw new NfcError("WRITE_FAILED", "tag lost")
    if (!tag.fits(records)) throw new NfcError("WRITE_FAILED", "too big")
  })
  assert.equal(type, "ntag216")
})

test("complete workflow: read → check → detect → write → read back → verify → bind → lock", async () => {
  const tag = new FakeTag("04:a2:3f:1b:6c:80:12", CAP.ntag215)
  const driver = new FakeDriver({ queue: [tag] })
  const api = new FakeApi()
  const events: ProgressEvent[] = []

  const result = await run(driver, api, { lock: true, events })

  assert.equal(result.outcome, "programmed")
  assert.ok(result.outcome === "programmed")
  assert.deepEqual(
    { uid: result.uid, tagType: result.tagType, locked: result.locked, lockError: result.lockError, replacedTag: result.replacedTag },
    { uid: "04A23F1B6C8012", tagType: "ntag215", locked: true, lockError: null, replacedTag: false },
  )
  for (const key of ["check_ms", "detect_ms", "write_ms", "verify_ms", "save_ms", "lock_ms", "total_ms"] as const) {
    assert.equal(typeof result.timings[key], "number", key)
  }
  assert.deepEqual(api.calls, ["check:04A23F1B6C8012:-", "bind", "lock"])
  assert.deepEqual(tag.records, [{ recordType: "url", data: URL }], "only the card URL remains on the tag")
  assert.equal(tag.readOnly, true)
  const { timings, ...bound } = api.binds[0] as Record<string, unknown>
  assert.deepEqual(bound, {
    method: "web_nfc",
    attempt_id: "8f0c7f4e-1c1b-4d9e-9a55-0f7f8d9a1b2c",
    tag_type: "ntag215",
    uid: "04A23F1B6C8012",
    read_back: { uid: "04:a2:3f:1b:6c:80:12", url: URL },
  })
  assert.equal(typeof (timings as { write_ms?: number }).write_ms, "number", "timings are sent with the bind")
  assert.deepEqual([...new Set(events.map((e) => e.step))], ["waiting", "checking", "detecting", "writing", "verifying", "saving", "locking"])
  assert.equal(api.reports.length, 0)
})

test("refused by the server: nothing is written and nothing saved", async () => {
  const tag = new FakeTag("04:11:22:33:44:55:66", CAP.ntag215, "https://app.giftcardpro.at/c/other")
  const driver = new FakeDriver({ queue: [tag] })
  const api = new FakeApi()
  api.checkResult = {
    status: "refused",
    reason: "TAG_CARRIES_OTHER_CARD",
    message: "This tag carries the link of card 1234.",
    conflict: { card_id: "c2", card_number: "1234" },
  }

  await assert.rejects(run(driver, api), (e: ProgrammingError) => {
    assert.equal(e.code, "TAG_CARRIES_OTHER_CARD")
    assert.equal(e.conflict?.card_number, "1234")
    assert.equal(e.stage, "check")
    return true
  })
  assert.equal(tag.writes.length, 0)
  assert.equal(tag.records[0]?.recordType, "url")
  assert.deepEqual(api.calls, ["check:04112233445566:https://app.giftcardpro.at/c/other"], "the server logged the refusal itself")
})

test("already programmed for this card: no write", async () => {
  const tag = new FakeTag("04:11:22:33:44:55:66", CAP.ntag215, URL)
  tag.readOnly = true
  const api = new FakeApi()
  api.checkResult = { status: "already_programmed", content: "this_card" }
  const result = await run(new FakeDriver({ queue: [tag] }), api)
  assert.equal(result.outcome, "already_programmed")
  assert.equal(result.uid, "04112233445566")
  assert.equal(tag.writes.length, 0)
})

test("unsupported chip (NTAG 424 / Type 4) is refused and logged", async () => {
  const api = new FakeApi()
  await assert.rejects(run(new FakeDriver({ queue: [new FakeTag("04:01:02:03:04:05:06", CAP.ntag424)] }), api), { code: "TAG_UNSUPPORTED" })
  assert.deepEqual(api.calls.slice(1), ["report:detect:refused:TAG_UNSUPPORTED"])
  assert.equal(api.binds.length, 0)
})

test("URL read back differs: verification fails after a re-read, nothing saved", async () => {
  const api = new FakeApi()
  const driver = new FakeDriver({ queue: [new FakeTag("04:01:02:03:04:05:06", CAP.ntag213)], corruptUrlWrite: true })
  await assert.rejects(run(driver, api), { code: "URL_MISMATCH", stage: "verify" })
  assert.equal(driver.readBacks, 2)
  assert.equal(api.binds.length, 0)
  assert.equal(api.reports[0]?.stage, "verify")
  assert.equal(api.reports[0]?.read_back_url, URL.slice(0, -1))
})

test("a stale first read-back is re-read before verifying", async () => {
  const api = new FakeApi()
  const events: ProgressEvent[] = []
  const driver = new FakeDriver({ queue: [new FakeTag("04:01:02:03:04:05:06", CAP.ntag216)], staleFirstReadBack: true })
  const result = await run(driver, api, { events })
  assert.equal(result.outcome, "programmed")
  assert.ok(events.some((e) => e.step === "verifying" && e.hint === "retap"))
})

test("another tag read back: TAG_SWAPPED, nothing saved", async () => {
  const api = new FakeApi()
  const driver = new FakeDriver({
    queue: [new FakeTag("04:01:02:03:04:05:06", CAP.ntag215)],
    swapOnReadBack: new FakeTag("04:99:99:99:99:99:99", CAP.ntag215, URL),
  })
  await assert.rejects(run(driver, api), { code: "TAG_SWAPPED" })
  assert.equal(api.binds.length, 0)
  assert.deepEqual(api.calls.slice(1), ["report:verify:failed:TAG_SWAPPED"])
})

test("tag removed while the URL is written: 'Tag removed too early', logged with the detected type", async () => {
  const api = new FakeApi()
  await assert.rejects(run(new FakeDriver({ queue: [new FakeTag("04:01:02:03:04:05:06", CAP.ntag215)], failUrlWrite: true }), api), {
    code: "TAG_REMOVED",
    stage: "write",
    category: "tag_removed",
    title: "Tag removed too early",
  })
  assert.equal(api.reports[0]?.tag_type, "ntag215")
  assert.equal(api.binds.length, 0)
})

test("no answer from the tag: TIMEOUT after the re-tap hint", async () => {
  const api = new FakeApi()
  const events: ProgressEvent[] = []
  await assert.rejects(run(new FakeDriver({ queue: [new FakeTag("04:01:02:03:04:05:06", CAP.ntag215)], readBackHangs: true }), api, { events }), {
    code: "TIMEOUT",
  })
  assert.ok(events.some((e) => e.hint === "retap"))
  assert.deepEqual(api.calls.slice(1), ["report:verify:failed:TIMEOUT"])
})

test("lock error keeps the verified tag and is logged", async () => {
  const api = new FakeApi()
  const result = await run(new FakeDriver({ queue: [new FakeTag("04:01:02:03:04:05:06", CAP.ntag215)], lockFails: true }), api, { lock: true })
  assert.equal(result.outcome, "programmed")
  assert.equal(result.outcome === "programmed" && result.locked, false)
  assert.ok(result.outcome === "programmed" && result.lockError)
  assert.deepEqual(api.calls, ["check:04010203040506:-", "bind", "report:lock:failed:LOCK_FAILED"])
})

test("cancel while waiting for a tag logs nothing; cancel mid-way is logged as cancelled", async () => {
  const idle = new AbortController()
  const api = new FakeApi()
  const pending = run(new FakeDriver({ queue: [] }), api, { signal: idle.signal })
  idle.abort()
  await assert.rejects(pending, { code: "CANCELLED" })
  assert.deepEqual(api.calls, [])

  const busy = new AbortController()
  const api2 = new FakeApi()
  const hanging = run(new FakeDriver({ queue: [new FakeTag("04:01:02:03:04:05:06", CAP.ntag215)], readBackHangs: true }), api2, { signal: busy.signal })
  setTimeout(() => busy.abort(), 20)
  await assert.rejects(hanging, { code: "CANCELLED" })
  assert.deepEqual(api2.calls.slice(1), ["report:verify:cancelled:CANCELLED"])
})

test("the tag programmed just before is ignored until the next tag arrives", async () => {
  const previous = new FakeTag("04:aa:aa:aa:aa:aa:aa", CAP.ntag215, URL)
  const next = new FakeTag("04:bb:bb:bb:bb:bb:bb", CAP.ntag215)
  const events: ProgressEvent[] = []
  const api = new FakeApi()
  const result = await run(new FakeDriver({ queue: [previous, next] }), api, { ignoreSerials: ["04AAAAAAAAAAAA"], events })
  assert.equal(result.outcome === "programmed" && result.uid, "04BBBBBBBBBBBB")
  assert.ok(events.some((e) => e.hint === "remove_previous"))
  assert.equal(previous.writes.length, 0)
})

test("bind rejected by the server is not reported twice; an unanswered bind is reported", async () => {
  const api = new FakeApi()
  api.bindError = Object.assign(new Error("This NFC tag is already linked to another active card."), { code: "NFC_TAG_IN_USE" })
  await assert.rejects(run(new FakeDriver({ queue: [new FakeTag("04:01:02:03:04:05:06", CAP.ntag215)] }), api), { code: "NFC_TAG_IN_USE", stage: "bind" })
  assert.equal(api.reports.length, 0)

  const offline = new FakeApi()
  offline.bindError = new TypeError("Failed to fetch")
  await assert.rejects(run(new FakeDriver({ queue: [new FakeTag("04:01:02:03:04:05:06", CAP.ntag215)] }), offline), { code: "UNKNOWN_ERROR" })
  assert.deepEqual(offline.calls.slice(-1), ["report:bind:failed:UNKNOWN_ERROR"])

  // The real API wrapper maps "no answer" to SERVER_UNAVAILABLE and reports it (best effort).
  const down = new FakeApi()
  down.bindError = apiFailure(new TypeError("Failed to fetch"))
  await assert.rejects(run(new FakeDriver({ queue: [new FakeTag("04:01:02:03:04:05:06", CAP.ntag215)] }), down), {
    code: "SERVER_UNAVAILABLE",
    category: "server_unavailable",
    title: "Server unavailable",
  })
  assert.deepEqual(down.calls.slice(-1), ["report:bind:failed:SERVER_UNAVAILABLE"])
})

test("normalizeUid", () => {
  assert.equal(normalizeUid("04:a2:3f:1b:6c:80:12"), "04A23F1B6C8012")
})

test("a locked tag is recognised before the card link is written", async () => {
  const tag = new FakeTag("04:01:02:03:04:05:06", CAP.ntag215)
  tag.readOnly = true
  const api = new FakeApi()
  await assert.rejects(run(new FakeDriver({ queue: [tag] }), api), { code: "TAG_READ_ONLY", category: "tag_locked", title: "Tag is locked", stage: "detect" })
  assert.equal(api.binds.length, 0)
  assert.deepEqual(api.calls.slice(1), ["report:detect:refused:TAG_READ_ONLY"])
})

test("every failure class has a clear title and instruction", () => {
  const expectations: [string, string, string][] = [
    ["TAG_LOST", "tag_removed", "Tag removed too early"],
    ["TAG_REMOVED", "tag_removed", "Tag removed too early"],
    ["TIMEOUT", "tag_removed", "Tag removed too early"],
    ["TAG_UNSUPPORTED", "wrong_tag", "Wrong tag type"],
    ["TAG_TOO_SMALL", "wrong_tag", "Wrong tag type"],
    ["TAG_READ_ONLY", "tag_locked", "Tag is locked"],
    ["TAG_LINKED_TO_OTHER_CARD", "tag_in_use", "Tag belongs to another active card"],
    ["TAG_CARRIES_OTHER_CARD", "tag_in_use", "Tag belongs to another active card"],
    ["NFC_TAG_IN_USE", "tag_in_use", "Tag belongs to another active card"],
    ["WRITE_FAILED", "write_failed", "Write failed"],
    ["URL_MISMATCH", "verification_failed", "Verification failed"],
    ["TAG_SWAPPED", "verification_failed", "Verification failed"],
    ["NFC_VERIFICATION_FAILED", "verification_failed", "Verification failed"],
    ["SERVER_UNAVAILABLE", "server_unavailable", "Server unavailable"],
    ["NETWORK_TIMEOUT", "network_timeout", "Network timeout"],
  ]
  for (const [code, category, title] of expectations) {
    const d = describeError(code, "server text")
    assert.equal(d.category, category, code)
    assert.equal(d.title, title, code)
    assert.ok(d.message.length > 10, code)
  }
  // Refusals keep the server's sentence, which names the other card.
  assert.equal(describeError("TAG_LINKED_TO_OTHER_CARD", "This tag is already linked to card 1234.").message, "This tag is already linked to card 1234.")
  assert.equal(describeError("SOMETHING_NEW", "Plain server text").title, "Programming failed")
})

test("API failures map to stable codes", () => {
  assert.deepEqual(pick(apiFailure(new DOMException("t", "TimeoutError"))), { code: "NETWORK_TIMEOUT", answered: false })
  assert.deepEqual(pick(apiFailure(new TypeError("Failed to fetch"))), { code: "SERVER_UNAVAILABLE", answered: false })
  assert.deepEqual(pick(apiFailure({ name: "ApiError", status: 503, message: "x" })), { code: "SERVER_UNAVAILABLE", answered: false })
  assert.deepEqual(pick(apiFailure({ name: "ApiError", status: 429, message: "x" })), { code: "RATE_LIMITED", answered: true })
  assert.deepEqual(pick(apiFailure({ name: "ApiError", status: 409, code: "NFC_TAG_IN_USE", message: "linked" })), { code: "NFC_TAG_IN_USE", answered: true })
  assert.deepEqual(pick(apiFailure({ name: "ApiError", status: 422, code: "VALIDATION_FAILED", message: "bad" })), {
    code: "VALIDATION_FAILED",
    answered: false,
  })
})

function pick(e: { code: string; answered: boolean }) {
  return { code: e.code, answered: e.answered }
}

test("recovery: after any failure the same session programs the next try right away", async () => {
  const tag = new FakeTag("04:01:02:03:04:05:06", CAP.ntag215)
  const driver = new FakeDriver({ queue: [tag], failUrlWrite: true })
  const api = new FakeApi()
  await assert.rejects(run(driver, api), { code: "TAG_REMOVED" })

  // Operator taps "Try again" and holds the tag again: new attempt, same driver (NFC session), no reload.
  driver.fix()
  driver.present(tag)
  const again = await programCard(
    { cardId: "card-1", expectedUrl: URL, lock: false, attemptId: "5b6c1b0e-2f5a-4b8e-8c1d-3e2f1a0b9c8d", signal: new AbortController().signal },
    { driver, api, stepTimeoutMs: 200, retapHintMs: 50 },
  )
  assert.equal(again.outcome, "programmed")
  assert.equal(tag.snapshot().url, URL)
})

test("station mode asks the server to refuse cards that got a tag elsewhere", async () => {
  const api = new FakeApi()
  const seen: unknown[] = []
  api.check = async (_id, body) => {
    seen.push(body)
    return {
      status: "refused",
      reason: "CARD_ALREADY_PROGRAMMED",
      message: "This card already has a tag.",
      conflict: null,
      content: "blank",
      replaces_tag: false,
      expected_url: URL,
      attempt_id: body.attempt_id,
    }
  }
  await assert.rejects(
    programCard(
      { cardId: "c", expectedUrl: URL, lock: false, attemptId: "a", signal: new AbortController().signal, onlyIfUnprogrammed: true },
      { driver: new FakeDriver({ queue: [new FakeTag("04:01:02:03:04:05:06", CAP.ntag215)] }), api },
    ),
    { code: "CARD_ALREADY_PROGRAMMED", category: "card_state" },
  )
  assert.equal((seen[0] as { only_if_unprogrammed?: boolean }).only_if_unprogrammed, true)
  assert.equal(api.reports.length, 0, "refusal logged by the server")
})

test("timings follow the clock", async () => {
  let t = 1000
  const clock = () => (t += 7)
  const result = await programCard(
    { cardId: "c", expectedUrl: URL, lock: false, attemptId: "a", signal: new AbortController().signal },
    { driver: new FakeDriver({ queue: [new FakeTag("04:01:02:03:04:05:06", CAP.ntag216)] }), api: new FakeApi(), now: clock },
  )
  assert.ok(result.outcome === "programmed")
  const { check_ms, detect_ms, write_ms, verify_ms, save_ms, total_ms } = result.timings
  for (const v of [check_ms, detect_ms, write_ms, verify_ms]) assert.equal(v, 7)
  assert.ok((save_ms ?? 0) >= 7)
  assert.ok((total_ms ?? 0) >= 35)
})

test("already programmed but not locked yet: the retry locks it", async () => {
  const tag = new FakeTag("04:11:22:33:44:55:66", CAP.ntag215, URL)
  const api = new FakeApi()
  api.checkResult = { status: "already_programmed", content: "this_card", locked: false }
  const driver = new FakeDriver({ queue: [tag] })
  const result = await run(driver, api, { lock: true })
  assert.equal(result.outcome, "already_programmed")
  assert.equal(result.locked, true)
  assert.equal(tag.readOnly, true)
  assert.equal(tag.writes.length, 0)
  assert.deepEqual(api.calls.slice(1), ["lock"])
})
