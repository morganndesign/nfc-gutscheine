/**
 * NFC card programming v2 — the dashboard workflow (docs/NFC.md, "Programming tags"):
 *
 *   1. read the tag (UID + current content)
 *   2. ask the server whether the chip / the link on it is free        POST /cards/{id}/nfc/check
 *   3. refuse if it belongs to another card
 *   4. detect NTAG213 / 215 / 216 by memory size, then write the NDEF URL record
 *   5. read the tag again
 *   6. verify: same chip, URL exactly the card's URL
 *   7. only now save the UID                                          POST /cards/{id}/nfc
 *   8. optionally lock the tag permanently                           POST /cards/{id}/nfc/lock
 *
 * Every attempt carries one `attempt_id`; failures the server cannot see are reported to
 * POST /cards/{id}/nfc/attempts, so every attempt is logged, successful or not.
 *
 * Framework-free (tested with `node --test`); the hardware and the API are injected.
 */
import { NfcError, type NfcDriver, type NfcRecord, type TagSnapshot } from "./nfc.ts"

export type DetectedTagType = "ntag213" | "ntag215" | "ntag216"

export type ProgrammingStep = "waiting" | "checking" | "detecting" | "writing" | "verifying" | "saving" | "locking"

export const PROGRAMMING_STEPS: { step: ProgrammingStep; label: string }[] = [
  { step: "waiting", label: "Read tag" },
  { step: "checking", label: "Check tag is free" },
  { step: "detecting", label: "Detect chip type" },
  { step: "writing", label: "Write card link" },
  { step: "verifying", label: "Read back and verify" },
  { step: "saving", label: "Save chip to card" },
  { step: "locking", label: "Lock tag" },
]

/** Hints the UI shows while a step waits for the tag. */
export type ProgrammingHint = "hold_still" | "retap" | "remove_previous"

export interface ProgressEvent {
  step: ProgrammingStep
  hint?: ProgrammingHint
  uid?: string
  tagType?: DetectedTagType
}

export type CheckStatus = "available" | "already_programmed" | "refused"

export interface CheckResult {
  status: CheckStatus
  reason: string | null
  message: string | null
  conflict: { card_id: string; card_number: string } | null
  content: "blank" | "this_card" | "other_card" | "retired_card" | "stale_copy" | "foreign"
  replaces_tag: boolean
  /** The card's tag is already read-only. */
  locked?: boolean
  expected_url: string
  attempt_id: string
}

export interface FailureReport {
  attempt_id: string
  stage: "read" | "check" | "detect" | "write" | "verify" | "lock" | "bind"
  result: "failed" | "refused" | "cancelled"
  error_code: string
  message?: string | null
  uid?: string | null
  tag_type?: string | null
  previous_url?: string | null
  read_back_url?: string | null
  timings?: ProgramTimings
}

export interface ProgrammingApi {
  check(cardId: string, body: { attempt_id: string; uid: string; current_url: string | null; only_if_unprogrammed?: boolean }): Promise<CheckResult>
  bind(
    cardId: string,
    body: {
      method: "web_nfc"
      attempt_id: string
      tag_type: DetectedTagType
      uid: string
      read_back: { uid: string; url: string }
      timings?: ProgramTimings
      only_if_unprogrammed?: boolean
    },
  ): Promise<unknown>
  confirmLock(cardId: string, body: { attempt_id: string }): Promise<unknown>
  report(cardId: string, body: FailureReport): Promise<unknown>
}

export interface ProgramOptions {
  cardId: string
  /** The card's URL (`card_url` / NFC payload). Written verbatim and compared verbatim. */
  expectedUrl: string
  lock: boolean
  attemptId: string
  signal: AbortSignal
  /** Serial numbers to ignore while waiting (the tag programmed just before, still on the phone). */
  ignoreSerials?: string[]
  /** Programming station: refuse cards that got a tag in the meantime (e.g. on a second phone). */
  onlyIfUnprogrammed?: boolean
  onProgress?: (event: ProgressEvent) => void
}

export interface ProgramDeps {
  driver: NfcDriver
  api: ProgrammingApi
  /** Longest wait for one write / read-back before giving up (ms). */
  stepTimeoutMs?: number
  /** After this long without a result the UI is told to ask for a re-tap (ms). */
  retapHintMs?: number
  /** Clock (ms), injectable for tests. */
  now?: () => number
}

/** Durations of one attempt in milliseconds, measured from the moment the tag was read. */
export interface ProgramTimings {
  check_ms?: number
  detect_ms?: number
  write_ms?: number
  verify_ms?: number
  save_ms?: number
  lock_ms?: number
  /** Tag read → chip saved (without the optional lock). */
  total_ms?: number
}

export type ProgramResult =
  | {
      outcome: "programmed"
      uid: string
      tagType: DetectedTagType
      locked: boolean
      lockError: string | null
      replacedTag: boolean
      timings: ProgramTimings
    }
  | { outcome: "already_programmed"; uid: string; locked: boolean; lockError: string | null; timings: ProgramTimings }

// ------------------------------------------------------------------ errors the operator sees

export type ErrorCategory =
  | "tag_removed"
  | "wrong_tag"
  | "tag_locked"
  | "tag_in_use"
  | "write_failed"
  | "verification_failed"
  | "server_unavailable"
  | "network_timeout"
  | "card_state"
  | "nfc_unavailable"
  | "cancelled"
  | "other"

interface ErrorText {
  category: ErrorCategory
  title: string
  /** What happened and what to do. `null`: use the server's own message (it names the other card). */
  message: string | null
}

const RETRY = "Nothing was saved to the card — try again with the same or another tag."

/** One clear title and instruction per failure (docs/NFC.md, "Errors"). */
export const ERROR_TEXTS: Record<string, ErrorText> = {
  TAG_LOST: { category: "tag_removed", title: "Tag removed too early", message: `Keep the tag flat on the back of the phone until the green tick. ${RETRY}` },
  TAG_REMOVED: {
    category: "tag_removed",
    title: "Tag removed too early",
    message: `The tag moved away while it was being written. Keep it flat on the phone until the green tick. ${RETRY}`,
  },
  TIMEOUT: {
    category: "tag_removed",
    title: "Tag removed too early",
    message: `The tag stopped answering. Hold it flat on the back of the phone and keep it there until the green tick. ${RETRY}`,
  },
  READ_FAILED: {
    category: "wrong_tag",
    title: "Wrong tag type",
    message: "This tag cannot be read as an NFC card. Use an NTAG213, NTAG215 or NTAG216 tag.",
  },
  TAG_UNSUPPORTED: {
    category: "wrong_tag",
    title: "Wrong tag type",
    message: "This is not an NTAG213, NTAG215 or NTAG216 tag (for example an NTAG 424 DNA or a bank card). Use a blank NTAG21x tag.",
  },
  TAG_TOO_SMALL: { category: "wrong_tag", title: "Wrong tag type", message: "The card link does not fit on this tag. Use an NTAG215 or NTAG216 tag." },
  TAG_READ_ONLY: {
    category: "tag_locked",
    title: "Tag is locked",
    message: "This tag is write-protected and cannot be programmed. Use a blank tag.",
  },
  TAG_LINKED_TO_OTHER_CARD: { category: "tag_in_use", title: "Tag belongs to another active card", message: null },
  TAG_CARRIES_OTHER_CARD: { category: "tag_in_use", title: "Tag belongs to another active card", message: null },
  TAG_OF_OTHER_BUSINESS: { category: "tag_in_use", title: "Tag belongs to another business", message: null },
  NFC_TAG_IN_USE: { category: "tag_in_use", title: "Tag belongs to another active card", message: null },
  WRITE_FAILED: {
    category: "write_failed",
    title: "Write failed",
    message: `The phone could not write the tag. Hold it still and try again; if it fails again, the tag may be damaged — use another one. ${RETRY}`,
  },
  URL_MISMATCH: {
    category: "verification_failed",
    title: "Verification failed",
    message: `The tag did not contain the card link when it was read back. ${RETRY}`,
  },
  TAG_SWAPPED: {
    category: "verification_failed",
    title: "Verification failed",
    message: `A different tag was read back. Keep the same tag on the phone until the green tick. ${RETRY}`,
  },
  NFC_VERIFICATION_FAILED: { category: "verification_failed", title: "Verification failed", message: `The server could not confirm the tag. ${RETRY}` },
  SERVER_UNAVAILABLE: {
    category: "server_unavailable",
    title: "Server unavailable",
    message: "GiftCard Pro cannot be reached right now. Check the phone's internet connection and try again in a moment. Nothing was saved.",
  },
  NETWORK_TIMEOUT: {
    category: "network_timeout",
    title: "Network timeout",
    message: "The server did not answer in time. Check the connection and try again — the card is saved at most once.",
  },
  RATE_LIMITED: { category: "network_timeout", title: "Too many requests", message: "Wait a few seconds, then try again." },
  CARD_CLOSED: { category: "card_state", title: "Card is closed", message: null },
  CARD_ALREADY_PROGRAMMED: { category: "card_state", title: "Card already programmed", message: null },
  NFC_CARD_ALREADY_PROGRAMMED: {
    category: "card_state",
    title: "Card already programmed",
    message: "Another phone programmed this card a moment ago. This tag was not saved and can be used for the next card.",
  },
  URL_OUTDATED: { category: "card_state", title: "Card link changed", message: "Reload the page, then try again." },
  PERMISSION_DENIED: { category: "nfc_unavailable", title: "NFC not allowed", message: "Allow NFC for this site in Chrome (site settings), then try again." },
  NFC_DISABLED: { category: "nfc_unavailable", title: "NFC is off", message: "Turn on NFC in the phone settings, then try again." },
  NFC_UNSUPPORTED: { category: "nfc_unavailable", title: "No NFC", message: "Use Chrome on an Android phone with NFC." },
  CANCELLED: { category: "cancelled", title: "Cancelled", message: "Cancelled." },
}

export function describeError(code: string, fallback?: string): { category: ErrorCategory; title: string; message: string } {
  const text = ERROR_TEXTS[code]
  if (!text) return { category: "other", title: "Programming failed", message: fallback || `Something went wrong. ${RETRY}` }
  return { category: text.category, title: text.title, message: text.message ?? fallback ?? text.title }
}

export class ProgrammingError extends Error {
  readonly code: string
  readonly stage: FailureReport["stage"]
  readonly conflict: CheckResult["conflict"]
  readonly uid: string | null
  readonly category: ErrorCategory
  readonly title: string

  constructor(code: string, message: string | null, stage: FailureReport["stage"], extra: { conflict?: CheckResult["conflict"]; uid?: string | null } = {}) {
    const text = describeError(code, message ?? undefined)
    super(text.message)
    this.name = "ProgrammingError"
    this.code = code
    this.stage = stage
    this.conflict = extra.conflict ?? null
    this.uid = extra.uid ?? null
    this.category = text.category
    this.title = text.title
  }
}

/**
 * Turns a failed API request into a stable code: no answer → SERVER_UNAVAILABLE, too slow →
 * NETWORK_TIMEOUT, 5xx → SERVER_UNAVAILABLE; answers with a `code` keep it.
 */
export function apiFailure(err: unknown): Error & { code: string; answered: boolean } {
  const e = err as { name?: string; status?: number; code?: unknown; message?: string }
  const make = (code: string, answered: boolean, message?: string) => Object.assign(new Error(message ?? describeError(code).message), { code, answered })
  if (e?.name === "TimeoutError") return make("NETWORK_TIMEOUT", false)
  if (e?.name === "TypeError") return make("SERVER_UNAVAILABLE", false)
  if (typeof e?.status === "number") {
    if (e.status === 0 || e.status >= 500) return make("SERVER_UNAVAILABLE", false)
    if (e.status === 429) return make("RATE_LIMITED", true)
  }
  if (typeof e?.code === "string" && e.code !== "") return make(e.code, e.code !== "VALIDATION_FAILED", e.message)
  return make("UNKNOWN_ERROR", false, e?.message)
}

// ------------------------------------------------------------------ NDEF sizes & chip detection

const encoder = new TextEncoder()

/** Well-known URI prefixes (NFC Forum URI RTD) — the browser abbreviates them on the tag. */
const URI_PREFIXES = ["https://www.", "http://www.", "https://", "http://"]

/** Size in bytes of an NDEF message with one short/long record. */
function recordSize(typeLength: number, payloadLength: number): number {
  return 1 + 1 + (payloadLength < 256 ? 1 : 4) + typeLength + payloadLength
}

/** Size of the NDEF message holding only the card URL (well-known type "U"). */
export function urlMessageSize(url: string): number {
  const prefix = URI_PREFIXES.find((p) => url.startsWith(p))
  const rest = prefix ? url.slice(prefix.length) : url
  return recordSize(1, 1 + encoder.encode(rest).length)
}

/**
 * Usable NDEF message size (bytes) of each chip, after the TLV header and terminator
 * (NXP NTAG213/215/216 datasheet: 144 / 504 / 888 bytes of user memory).
 */
export const NDEF_CAPACITY: Record<DetectedTagType, number> = { ntag213: 137, ntag215: 492, ntag216: 868 }

export const TAG_TYPE_LABEL: Record<DetectedTagType, string> = { ntag213: "NTAG213", ntag215: "NTAG215", ntag216: "NTAG216" }

export const PROBE_MEDIA_TYPE = "application/vnd.giftcardpro.probe"

/**
 * Probe messages. Web NFC does not expose the chip model, so the memory size is measured by writing
 * messages of known sizes; the real URL is written right after, replacing them.
 *   600 B: fits NTAG216 (868) but not NTAG215 (≤ 504)
 *   300 B: fits NTAG215 (492) but not NTAG213 (≤ 144) nor a 256-byte NDEF file (NTAG 424 DNA, Type 4)
 *   200 B: fits a 256-byte NDEF file but not NTAG213 → such a tag is not an NTAG21x
 *    40 B: fits every writable tag → if even this fails twice, the tag is locked (read-only)
 */
export const PROBES = { ntag216: 600, ntag215: 300, other: 200, writable: 40 } as const

export function probeRecord(totalSize: number): NfcRecord {
  const typeLength = encoder.encode(PROBE_MEDIA_TYPE).length
  let payload = totalSize - recordSize(typeLength, 0)
  if (payload >= 256) payload = totalSize - (1 + 1 + 4 + typeLength)
  return { recordType: "mime", mediaType: PROBE_MEDIA_TYPE, data: new Uint8Array(Math.max(payload, 0)).fill(0x2e) }
}

/** Writes and tells whether it fitted. A failure is retried once so a brief loss of contact is not taken for "too small". */
async function fits(write: (records: NfcRecord[]) => Promise<void>, size: number): Promise<boolean> {
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      await write([probeRecord(size)])
      return true
    } catch (err) {
      if (err instanceof NfcError && err.code === "WRITE_FAILED") continue
      throw err
    }
  }
  return false
}

/**
 * Detects NTAG213 / NTAG215 / NTAG216 by capacity. `unsupported`: a chip that is none of them (e.g. NTAG 424
 * DNA or another Type 4 tag, provisioned with its own tool); `read_only`: the tag accepts no write at all.
 */
export async function detectTagType(write: (records: NfcRecord[]) => Promise<void>): Promise<DetectedTagType | "unsupported" | "read_only"> {
  if (await fits(write, PROBES.ntag216)) return "ntag216"
  if (await fits(write, PROBES.ntag215)) return "ntag215"
  if (await fits(write, PROBES.other)) return "unsupported"
  if (await fits(write, PROBES.writable)) return "ntag213"
  return "read_only"
}

// ------------------------------------------------------------------ the workflow

export function normalizeUid(serial: string): string {
  return serial.replace(/[^0-9a-f]/gi, "").toUpperCase()
}

function withTimeout<T>(run: (signal: AbortSignal) => Promise<T>, parent: AbortSignal, timeoutMs: number, retapMs: number, onRetap: () => void): Promise<T> {
  const controller = new AbortController()
  const abort = () => controller.abort()
  parent.addEventListener("abort", abort, { once: true })
  let timedOut = false
  const hint = setTimeout(onRetap, retapMs)
  const timer = setTimeout(() => {
    timedOut = true
    controller.abort()
  }, timeoutMs)
  return run(controller.signal)
    .catch((err: unknown) => {
      if (timedOut) throw new NfcError("TIMEOUT", "The tag did not respond. Hold it flat against the back of the phone and try again.")
      throw err
    })
    .finally(() => {
      clearTimeout(hint)
      clearTimeout(timer)
      parent.removeEventListener("abort", abort)
    })
}

function errorCode(err: unknown): string {
  if (err instanceof NfcError) return err.code
  const code = (err as { code?: unknown })?.code
  return typeof code === "string" && code !== "" ? code : "UNKNOWN_ERROR"
}

function errorMessage(err: unknown): string | null {
  return err instanceof Error && err.message ? err.message : null
}

/** An API error the server answered (and therefore logged itself), as opposed to no / no timely answer. */
function answeredByServer(err: unknown): boolean {
  const e = err as { answered?: unknown; code?: unknown }
  if (typeof e?.answered === "boolean") return e.answered
  return typeof e?.code === "string" && e.code !== "VALIDATION_FAILED" && !(err instanceof NfcError)
}

/**
 * Programs one card. Resolves when the chip is verified and saved (or was already programmed for
 * this card); rejects with a {@link ProgrammingError} — nothing is saved to the card in that case.
 * Every failure can be retried right away with a new `attemptId`, in the same NFC session.
 */
export async function programCard(options: ProgramOptions, deps: ProgramDeps): Promise<ProgramResult> {
  const { cardId, expectedUrl, lock, attemptId, signal, onProgress } = options
  const { driver, api } = deps
  const now = deps.now ?? (() => Date.now())
  const stepTimeout = deps.stepTimeoutMs ?? 15000
  const retapAfter = deps.retapHintMs ?? 2500
  const ignored = new Set((options.ignoreSerials ?? []).map(normalizeUid))

  let stage: FailureReport["stage"] = "read"
  let tag: TagSnapshot | null = null
  let tagType: DetectedTagType | null = null
  let readBackUrl: string | null = null
  let serverError: unknown = undefined
  const timings: ProgramTimings = {}
  let started = 0
  const measure = async <T>(key: keyof ProgramTimings, run: () => Promise<T>): Promise<T> => {
    const t = now()
    try {
      return await run()
    } finally {
      timings[key] = Math.round(now() - t)
    }
  }

  const progress = (step: ProgrammingStep, hint?: ProgrammingHint) =>
    onProgress?.({ step, hint, uid: tag ? normalizeUid(tag.serialNumber) : undefined, tagType: tagType ?? undefined })

  const report = async (result: FailureReport["result"], code: string, message: string | null) => {
    try {
      await api.report(cardId, {
        attempt_id: attemptId,
        stage,
        result,
        error_code: code,
        message,
        uid: tag ? normalizeUid(tag.serialNumber) : null,
        tag_type: tagType,
        previous_url: tag?.url ?? null,
        read_back_url: readBackUrl,
        timings,
      })
    } catch {
      // Logging is best effort; the operator already sees the error.
    }
  }

  const timed = <T>(step: ProgrammingStep, run: (s: AbortSignal) => Promise<T>) =>
    withTimeout(run, signal, stepTimeout, retapAfter, () => progress(step, "retap"))

  const lockTag = async (): Promise<{ locked: boolean; lockError: string | null }> => {
    stage = "lock"
    progress("locking", "hold_still")
    try {
      await measure("lock_ms", async () => {
        await timed("locking", (s) => driver.makeReadOnly(s))
        await api.confirmLock(cardId, { attempt_id: attemptId })
      })
      return { locked: true, lockError: null }
    } catch (err) {
      const lockError = errorMessage(err) ?? "The tag could not be locked."
      await report("failed", err instanceof NfcError ? "LOCK_FAILED" : errorCode(err), lockError)
      return { locked: false, lockError }
    }
  }

  const server = async <T>(run: () => Promise<T>): Promise<T> => {
    try {
      return await run()
    } catch (err) {
      serverError = err
      throw err
    }
  }

  try {
    // 1. Read the tag.
    progress("waiting")
    for (;;) {
      const read = await driver.waitForTag(signal)
      if (!ignored.has(normalizeUid(read.serialNumber))) {
        tag = read
        break
      }
      progress("waiting", "remove_previous")
    }
    started = now()
    const uid = normalizeUid(tag.serialNumber)

    // 2–3. Server check: refuse tags of other cards before anything is written.
    stage = "check"
    progress("checking")
    const check = await measure("check_ms", () =>
      server(() =>
        api.check(cardId, { attempt_id: attemptId, uid, current_url: tag?.url ?? null, ...(options.onlyIfUnprogrammed ? { only_if_unprogrammed: true } : {}) }),
      ),
    )
    if (check.status === "refused") {
      // Logged by the server.
      throw Object.assign(new ProgrammingError(check.reason ?? "TAG_REFUSED", check.message, "check", { conflict: check.conflict, uid }), { answered: true })
    }
    if (check.status === "already_programmed") {
      timings.total_ms = Math.round(now() - started)
      // Saved earlier (e.g. the answer was lost): still lock it if the operator asked for it.
      const locking = lock && !check.locked ? await lockTag() : { locked: check.locked === true, lockError: null }
      return { outcome: "already_programmed", uid, ...locking, timings }
    }
    if (check.expected_url !== expectedUrl) {
      throw new ProgrammingError("URL_OUTDATED", null, "check", { uid })
    }

    // 4. Detect the chip, then write the NDEF URL record.
    stage = "detect"
    progress("detecting", "hold_still")
    const detected = await measure("detect_ms", () => detectTagType((records) => timed("detecting", (s) => driver.write(records, s))))
    if (detected === "unsupported") throw new ProgrammingError("TAG_UNSUPPORTED", null, "detect", { uid })
    if (detected === "read_only") throw new ProgrammingError("TAG_READ_ONLY", null, "detect", { uid })
    tagType = detected
    if (urlMessageSize(expectedUrl) > NDEF_CAPACITY[tagType]) {
      throw new ProgrammingError("TAG_TOO_SMALL", null, "detect", { uid })
    }

    stage = "write"
    progress("writing", "hold_still")
    try {
      await measure("write_ms", () => timed("writing", (s) => driver.write([{ recordType: "url", data: expectedUrl }], s)))
    } catch (err) {
      // The tag accepted the probe writes a moment ago: a failure now means it moved away.
      if (err instanceof NfcError && err.code === "WRITE_FAILED") throw new ProgrammingError("TAG_REMOVED", null, "write", { uid })
      throw err
    }

    // 5–6. Read back and verify. A second read (after a re-tap) rules out a stale read.
    stage = "verify"
    progress("verifying", "hold_still")
    const back = await measure("verify_ms", async () => {
      let read = await timed("verifying", (s) => driver.readAgain(s))
      readBackUrl = read.url
      if (normalizeUid(read.serialNumber) === uid && read.url !== expectedUrl) {
        progress("verifying", "retap")
        read = await timed("verifying", (s) => driver.readAgain(s))
        readBackUrl = read.url
      }
      return read
    })
    if (normalizeUid(back.serialNumber) !== uid) throw new ProgrammingError("TAG_SWAPPED", null, "verify", { uid })
    if (back.url !== expectedUrl) throw new ProgrammingError("URL_MISMATCH", null, "verify", { uid })

    // 7. Save the chip — the server compares URL and chip once more.
    stage = "bind"
    progress("saving")
    timings.total_ms = Math.round(now() - started)
    await measure("save_ms", () =>
      server(() =>
        api.bind(cardId, {
          method: "web_nfc",
          attempt_id: attemptId,
          tag_type: detected,
          uid,
          read_back: { uid: back.serialNumber, url: back.url ?? "" },
          timings: { ...timings, total_ms: Math.round(now() - started) },
          ...(options.onlyIfUnprogrammed ? { only_if_unprogrammed: true } : {}),
        }),
      ),
    )
    timings.total_ms = Math.round(now() - started)

    // 8. Lock (optional). A lock error leaves a verified, writable tag.
    const { locked, lockError } = lock ? await lockTag() : { locked: false, lockError: null }

    return { outcome: "programmed", uid, tagType: detected, locked, lockError, replacedTag: check.replaces_tag, timings }
  } catch (err) {
    const code = errorCode(err)
    const cancelled = code === "CANCELLED"
    const programmingError =
      err instanceof ProgrammingError ? err : new ProgrammingError(code, errorMessage(err), stage, { uid: tag ? normalizeUid(tag.serialNumber) : null })

    // Refusals and errors the server answered are logged by the server itself. Everything else —
    // including requests that got no (timely) answer — is reported so no attempt stays "in progress".
    const serverLogged = (err as { answered?: unknown })?.answered === true || (err === serverError && answeredByServer(err))
    if (!serverLogged && !(cancelled && tag === null)) {
      await report(
        cancelled ? "cancelled" : programmingError.category === "wrong_tag" || programmingError.category === "tag_locked" ? "refused" : "failed",
        programmingError.code,
        cancelled ? null : programmingError.message,
      )
    }
    throw programmingError
  }
}

/** Short, operator-facing sentence for the hint shown under the current step. */
export function hintText(hint: ProgrammingHint | undefined, step: ProgrammingStep): string {
  if (hint === "remove_previous") return "Remove the tag you just programmed and hold the next blank tag to the phone."
  if (hint === "retap") return "Lift the tag and hold it to the phone again."
  if (step === "waiting") return "Hold a blank tag against the back of the phone."
  if (step === "checking" || step === "saving") return "Keep the tag on the phone…"
  return "Hold the tag still — do not move it."
}
