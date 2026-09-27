/**
 * Web NFC (Chrome on Android). The tag only ever carries a URL with the card's random token —
 * never balances or personal data. iPhones read the same NDEF URL natively (background tag
 * reading) and open /c/{token} directly, so no app is needed there.
 *
 * This module has no framework imports so it can be unit-tested with `node --test`.
 */

interface NDEFRecordInit {
  recordType: string
  data?: string | BufferSource
  mediaType?: string
}

interface NDEFRecord {
  recordType: string
  mediaType?: string
  data?: DataView
  encoding?: string
}

interface NDEFMessage {
  records: NDEFRecord[]
}

interface NDEFReadingEvent extends Event {
  serialNumber: string
  message: NDEFMessage
}

export interface NDEFReaderLike extends EventTarget {
  scan(options?: { signal?: AbortSignal }): Promise<void>
  write(message: { records: NDEFRecordInit[] } | string, options?: { signal?: AbortSignal; overwrite?: boolean }): Promise<void>
  makeReadOnly?(options?: { signal?: AbortSignal }): Promise<void>
}

declare global {
  interface Window {
    NDEFReader?: new () => NDEFReaderLike
  }
}

export interface NfcRead {
  url: string | null
  serialNumber: string
}

/** Everything one read of a tag tells the browser. */
export interface TagSnapshot {
  /** Chip UID as reported by the browser ("04:a2:3f:…"). */
  serialNumber: string
  /** First URL on the tag, or null (blank / other content). */
  url: string | null
  /** Number of NDEF records (0 = blank or empty tag). */
  recordCount: number
}

export type NfcRecord = { recordType: "url"; data: string } | { recordType: "mime"; mediaType: string; data: Uint8Array<ArrayBuffer> }

export type NfcErrorCode =
  "NFC_UNSUPPORTED" | "PERMISSION_DENIED" | "NFC_DISABLED" | "TAG_LOST" | "READ_FAILED" | "WRITE_FAILED" | "LOCK_UNSUPPORTED" | "TIMEOUT" | "CANCELLED"

export class NfcError extends Error {
  readonly code: NfcErrorCode

  constructor(code: NfcErrorCode, message: string) {
    super(message)
    this.name = "NfcError"
    this.code = code
  }
}

export function isWebNfcSupported(): boolean {
  return typeof window !== "undefined" && "NDEFReader" in window
}

function decodeUrl(record: NDEFRecord): string | null {
  if (!record.data) return null
  if (record.recordType === "url" || record.recordType === "absolute-url") {
    return new TextDecoder().decode(record.data)
  }
  if (record.recordType === "text") {
    const text = new TextDecoder(record.encoding ?? "utf-8").decode(record.data)
    return /^https?:\/\//.test(text) ? text : null
  }
  return null
}

function snapshot(event: Event): TagSnapshot {
  const e = event as NDEFReadingEvent
  const records = (e.message?.records ?? []).filter((r) => r.recordType !== "empty")
  return {
    serialNumber: e.serialNumber,
    url: records.map(decodeUrl).find((u): u is string => !!u) ?? null,
    recordCount: records.length,
  }
}

/**
 * Maps browser errors to stable codes. `NetworkError` is what Chrome reports for every I/O failure
 * (tag removed, not writable, message too large for the chip).
 */
export function toNfcError(err: unknown, during: "read" | "write" | "lock" = "read"): NfcError | unknown {
  if (err instanceof NfcError) return err
  if (!(err instanceof Error) && !(typeof err === "object" && err !== null && "name" in err)) return err
  const name = (err as { name: string }).name
  if (name === "AbortError") return new NfcError("CANCELLED", "Cancelled.")
  if (name === "NotAllowedError") return new NfcError("PERMISSION_DENIED", "NFC permission was denied. Allow NFC for this site in the browser settings.")
  if (name === "NotSupportedError") return new NfcError("NFC_DISABLED", "NFC is turned off or not available. Enable NFC in the phone settings.")
  if (name === "NetworkError") {
    return during === "write"
      ? new NfcError("WRITE_FAILED", "The tag could not be written. Hold it still against the phone and try again.")
      : during === "lock"
        ? new NfcError("WRITE_FAILED", "The tag could not be locked.")
        : new NfcError("TAG_LOST", "The tag was removed too early. Hold it still and try again.")
  }
  return err
}

function friendlyNfcError(err: Error): Error {
  const mapped = toNfcError(err)
  return mapped instanceof Error ? mapped : err
}

/**
 * Waits for a single tag tap and returns the URL stored on it plus the chip serial number.
 * (Used by the web waiter terminal — reading only.)
 */
export async function readTagOnce(signal: AbortSignal): Promise<NfcRead> {
  if (!window.NDEFReader) throw new Error("NFC is not supported on this device.")
  const reader = new window.NDEFReader()

  return new Promise<NfcRead>((resolve, reject) => {
    const onReading = (event: Event) => {
      const tag = snapshot(event)
      cleanup()
      resolve({ url: tag.url, serialNumber: tag.serialNumber })
    }
    const onError = () => {
      cleanup()
      reject(new Error("The card could not be read. Hold it still against the back of the phone."))
    }
    const cleanup = () => {
      reader.removeEventListener("reading", onReading)
      reader.removeEventListener("readingerror", onError)
    }
    reader.addEventListener("reading", onReading)
    reader.addEventListener("readingerror", onError)
    signal.addEventListener("abort", () => {
      cleanup()
      reject(new DOMException("Scan cancelled", "AbortError"))
    })
    reader.scan({ signal }).catch((err: unknown) => {
      cleanup()
      reject(err instanceof Error ? friendlyNfcError(err) : err)
    })
  })
}

/** The operations the card-programming workflow needs from the NFC hardware. */
export interface NfcDriver {
  /** Resolves with the next tag that is presented to the phone. */
  waitForTag(signal: AbortSignal): Promise<TagSnapshot>
  /** Reads the tag in the field again (fresh read of its memory), or the next tag presented. */
  readAgain(signal: AbortSignal): Promise<TagSnapshot>
  /** Replaces the NDEF message of the tag in the field. */
  write(records: NfcRecord[], signal: AbortSignal): Promise<void>
  /** Makes the tag in the field permanently read-only. */
  makeReadOnly(signal: AbortSignal): Promise<void>
  readonly canMakeReadOnly: boolean
  /** Stops scanning. */
  close(): void
}

type Waiter = { resolve: (tag: TagSnapshot) => void; reject: (err: unknown) => void }

/**
 * Web NFC implementation. One reader scans for the whole session, so the phone keeps the tag
 * connected between the steps (read → write → read back) and a programming station needs to grant
 * the NFC permission only once. A fresh read of a tag that stays on the phone is triggered by
 * starting a second, short-lived scan; if the browser does not deliver it, lifting and re-tapping
 * the tag delivers it through the main reader.
 */
export class WebNfcDriver implements NfcDriver {
  private main: NDEFReaderLike | null = null
  private started: Promise<void> | null = null
  private readonly stop = new AbortController()
  private waiters = new Set<Waiter>()
  private readonly create: () => NDEFReaderLike

  constructor(create: () => NDEFReaderLike = defaultReader) {
    this.create = create
  }

  get canMakeReadOnly(): boolean {
    return typeof this.reader().makeReadOnly === "function"
  }

  private reader(): NDEFReaderLike {
    if (!this.main) {
      this.main = this.create()
      this.main.addEventListener("reading", (event) => this.dispatch(snapshot(event)))
      this.main.addEventListener("readingerror", () =>
        this.fail(new NfcError("READ_FAILED", "This tag could not be read. Use an NTAG213, NTAG215 or NTAG216 tag.")),
      )
    }
    return this.main
  }

  private start(): Promise<void> {
    this.started ??= this.reader()
      .scan({ signal: this.stop.signal })
      .catch((err: unknown) => {
        this.started = null
        throw toNfcError(err)
      })
    return this.started
  }

  private dispatch(tag: TagSnapshot) {
    const current = [...this.waiters]
    this.waiters.clear()
    current.forEach((w) => w.resolve(tag))
  }

  private fail(err: unknown) {
    const current = [...this.waiters]
    this.waiters.clear()
    current.forEach((w) => w.reject(err))
  }

  private next(signal: AbortSignal): Promise<TagSnapshot> {
    return new Promise<TagSnapshot>((resolve, reject) => {
      if (signal.aborted) return reject(new NfcError("CANCELLED", "Cancelled."))
      const waiter: Waiter = {
        resolve: (tag) => {
          signal.removeEventListener("abort", onAbort)
          resolve(tag)
        },
        reject: (err) => {
          signal.removeEventListener("abort", onAbort)
          reject(err)
        },
      }
      const onAbort = () => {
        this.waiters.delete(waiter)
        reject(new NfcError("CANCELLED", "Cancelled."))
      }
      signal.addEventListener("abort", onAbort, { once: true })
      this.waiters.add(waiter)
    })
  }

  /** Registers for the next read, then makes sure the session scan is running. */
  private async listen(signal: AbortSignal): Promise<{ tag: Promise<TagSnapshot> }> {
    const tag = this.next(signal)
    try {
      await this.start()
    } catch (err) {
      tag.catch(() => undefined)
      this.fail(err)
      throw err
    }
    // Wrapped: returning the promise itself from an async function would wait for the tag.
    return { tag }
  }

  async waitForTag(signal: AbortSignal): Promise<TagSnapshot> {
    return (await this.listen(signal)).tag
  }

  async readAgain(signal: AbortSignal): Promise<TagSnapshot> {
    const { tag } = await this.listen(signal)
    const probe = this.create()
    const probeStop = new AbortController()
    const onProbe = (event: Event) => this.dispatch(snapshot(event))
    probe.addEventListener("reading", onProbe)
    probe.scan({ signal: probeStop.signal }).catch(() => undefined)
    try {
      return await tag
    } finally {
      probe.removeEventListener("reading", onProbe)
      probeStop.abort()
    }
  }

  async write(records: NfcRecord[], signal: AbortSignal): Promise<void> {
    await this.start()
    try {
      await this.reader().write({ records }, { signal, overwrite: true })
    } catch (err) {
      throw toNfcError(err, "write")
    }
  }

  async makeReadOnly(signal: AbortSignal): Promise<void> {
    const reader = this.reader()
    if (!reader.makeReadOnly) throw new NfcError("LOCK_UNSUPPORTED", "This browser cannot lock tags. Update Chrome to lock tags.")
    await this.start()
    try {
      await reader.makeReadOnly({ signal })
    } catch (err) {
      throw toNfcError(err, "lock")
    }
  }

  close(): void {
    this.fail(new NfcError("CANCELLED", "Cancelled."))
    this.stop.abort()
  }
}

function defaultReader(): NDEFReaderLike {
  if (typeof window === "undefined" || !window.NDEFReader) throw new NfcError("NFC_UNSUPPORTED", "NFC is not supported on this device.")
  return new window.NDEFReader()
}

export const TAG_TYPES: { value: string; label: string; description: string }[] = [
  { value: "ntag213", label: "NTAG213", description: "144 bytes · standard cards and stickers" },
  { value: "ntag215", label: "NTAG215", description: "504 bytes · recommended default" },
  { value: "ntag216", label: "NTAG216", description: "888 bytes" },
  { value: "ntag424_dna", label: "NTAG 424 DNA", description: "Cryptographic anti-cloning (SUN)" },
  { value: "qr_only", label: "QR code only", description: "Printed card without chip" },
]
