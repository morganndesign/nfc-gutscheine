"use client"

import { useCallback, useEffect, useRef, useState } from "react"
import Link from "next/link"
import {
  ArrowLeft,
  CheckCircle2,
  CircleSlash,
  Download,
  Loader2,
  Nfc,
  Play,
  RotateCcw,
  SkipForward,
  Smartphone,
  Square,
  Volume2,
  VolumeX,
  XCircle,
} from "lucide-react"
import { PageHeader } from "@/components/common/page-header"
import { StatusBadge } from "@/components/common/status-badge"
import { NfcErrorPanel } from "@/components/cards/nfc-error"
import { NfcProgramSteps } from "@/components/cards/nfc-program-steps"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Progress } from "@/components/ui/progress"
import { Switch } from "@/components/ui/switch"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useCapabilities } from "@/hooks/use-capabilities"
import { useNfcProgrammer } from "@/hooks/use-nfc-programmer"
import { api, errorMessage } from "@/lib/api/client"
import { useCards } from "@/lib/api/hooks"
import { toast } from "sonner"
import type { GiftCard, Paginated } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { formatCardNumber } from "@/lib/format"
import { formatMoney } from "@/lib/money"
import { ProgrammingError, TAG_TYPE_LABEL, type DetectedTagType, type ProgramTimings } from "@/lib/nfc-programming"

type Outcome = "programmed" | "already_programmed" | "skipped" | "failed"

interface LogEntry {
  key: number
  card: GiftCard
  outcome: Outcome
  uid: string | null
  tagType: DetectedTagType | null
  locked: boolean
  detail: string | null
  errorCode: string | null
  timings: ProgramTimings | null
  at: Date
}

type Phase = "setup" | "running" | "finished"

const PAGE = 50

/** The card number just before `start` (inclusive start for the exclusive `card_number_after` filter). */
function numberBefore(start: string): string | undefined {
  const digits = start.replace(/\D/g, "")
  if (!digits) return undefined
  const prev = BigInt(digits) - BigInt(1)
  return prev < BigInt(0) ? undefined : prev.toString().padStart(digits.length, "0")
}

/** Short confirmation sounds (no audio files) — the operator looks at the cards, not the screen. */
function beep(ok: boolean) {
  try {
    const ctx = new AudioContext()
    const osc = ctx.createOscillator()
    const gain = ctx.createGain()
    osc.frequency.value = ok ? 1175 : 220
    gain.gain.value = 0.08
    osc.connect(gain).connect(ctx.destination)
    osc.start()
    osc.stop(ctx.currentTime + (ok ? 0.12 : 0.35))
    osc.onended = () => void ctx.close()
  } catch {
    /* audio unavailable */
  }
  try {
    navigator.vibrate?.(ok ? 60 : [80, 60, 80])
  } catch {
    /* vibration unavailable */
  }
}

function useWakeLock(active: boolean) {
  useEffect(() => {
    if (!active || typeof navigator === "undefined" || !("wakeLock" in navigator)) return
    let sentinel: WakeLockSentinel | null = null
    let released = false
    const acquire = () =>
      navigator.wakeLock
        .request("screen")
        .then((s) => {
          if (released) void s.release()
          else sentinel = s
        })
        .catch(() => undefined)
    void acquire()
    const onVisible = () => document.visibilityState === "visible" && void acquire()
    document.addEventListener("visibilitychange", onVisible)
    return () => {
      released = true
      document.removeEventListener("visibilitychange", onVisible)
      void sentinel?.release().catch(() => undefined)
    }
  }, [active])
}

function Stat({ label, value, tone }: { label: string; value: number | string; tone?: "ok" | "warn" | "bad" }) {
  return (
    <div className="bg-card rounded-xl border px-3 py-2">
      <p className="text-muted-foreground text-xs">{label}</p>
      <p
        className={`text-xl font-semibold tabular-nums ${tone === "ok" ? "text-emerald-700 dark:text-emerald-400" : tone === "bad" ? "text-destructive" : tone === "warn" ? "text-amber-700 dark:text-amber-400" : ""}`}
      >
        {value}
      </p>
    </div>
  )
}

function OutcomeLabel({ entry }: { entry: LogEntry }) {
  switch (entry.outcome) {
    case "programmed":
      return (
        <span className="inline-flex items-center gap-1 text-emerald-700 dark:text-emerald-400">
          <CheckCircle2 className="size-3.5" /> Verified{entry.locked ? " · locked" : ""}
        </span>
      )
    case "already_programmed":
      return (
        <span className="inline-flex items-center gap-1 text-emerald-700 dark:text-emerald-400">
          <CheckCircle2 className="size-3.5" /> Already programmed
        </span>
      )
    case "skipped":
      return (
        <span className="text-muted-foreground inline-flex items-center gap-1">
          <CircleSlash className="size-3.5" /> Skipped
        </span>
      )
    default:
      return (
        <span className="text-destructive inline-flex items-center gap-1">
          <XCircle className="size-3.5" /> Failed
        </span>
      )
  }
}

/** Station requests that must not hang the session. */
const LIST_TIMEOUT_MS = 15000

/** Refusals that mean "this card is done elsewhere" — the station moves on by itself. */
const DONE_ELSEWHERE = new Set(["CARD_ALREADY_PROGRAMMED", "NFC_CARD_ALREADY_PROGRAMMED"])

function formatDuration(ms: number): string {
  const total = Math.max(0, Math.round(ms / 1000))
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  const s = total % 60
  return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}` : `${m}:${String(s).padStart(2, "0")}`
}

function formatSeconds(ms: number | null): string {
  return ms === null ? "—" : `${(ms / 1000).toFixed(1)} s`
}

function average(values: (number | undefined)[]): number | null {
  const v = values.filter((x): x is number => typeof x === "number")
  return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null
}

function csvCell(value: string | number | null | undefined): string {
  const text = value === null || value === undefined ? "" : String(value)
  // Formula injection safe, quotes escaped.
  const safe = /^[=+\-@]/.test(text) ? `'${text}` : text
  return /[;"\n]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe
}

/** The session log as CSV (for the release test report). */
function downloadLog(log: LogEntry[]) {
  const header = [
    "Time",
    "Card number",
    "Result",
    "Chip type",
    "Chip serial",
    "Locked",
    "Detect ms",
    "Write ms",
    "Verify ms",
    "Tag to saved ms",
    "Error code",
    "Detail",
  ]
  const rows = [...log]
    .reverse()
    .map((e) => [
      e.at.toISOString(),
      e.card.card_number,
      e.outcome,
      e.tagType ? TAG_TYPE_LABEL[e.tagType] : "",
      e.uid,
      e.locked ? "yes" : "no",
      e.timings?.detect_ms,
      e.timings?.write_ms,
      e.timings?.verify_ms,
      e.timings?.total_ms,
      e.errorCode,
      e.detail,
    ])
  const csv = "\uFEFF" + [header, ...rows].map((r) => r.map(csvCell).join(";")).join("\r\n")
  const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }))
  const a = document.createElement("a")
  a.href = url
  a.download = `nfc-programming-${new Date().toISOString().slice(0, 19).replace(/[:T]/g, "-")}.csv`
  a.click()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

/**
 * NFC programming station: works through all cards without a tag in card-number order. For each card
 * the operator holds one blank tag to the phone; it is checked, detected, written, read back, verified
 * and saved (optionally locked) — then the next card comes up automatically. Every failure can be
 * retried or skipped without leaving the session.
 */
function ProgrammingStation() {
  const { user } = useAuth()
  const { nfc: supported } = useCapabilities()
  const programmer = useNfcProgrammer()

  const [phase, setPhase] = useState<Phase>("setup")
  const [startAt, setStartAt] = useState("")
  const [lock, setLock] = useState<boolean>(user?.restaurant?.settings?.lock_nfc_tags_after_write ?? false)
  const [sound, setSound] = useState(true)
  const [current, setCurrent] = useState<GiftCard | null>(null)
  const [error, setError] = useState<ProgrammingError | null>(null)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [log, setLog] = useState<LogEntry[]>([])
  const [loading, setLoading] = useState(false)
  const [sessionTotal, setSessionTotal] = useState<number | null>(null)
  const [failedAttempts, setFailedAttempts] = useState(0)
  const [startedAt, setStartedAt] = useState<number | null>(null)
  const [stoppedAt, setStoppedAt] = useState<number | null>(null)
  const [clock, setClock] = useState(() => Date.now())

  const queue = useRef<GiftCard[]>([])
  const cursor = useRef<string | undefined>(undefined)
  const exhausted = useRef(false)
  const lastUid = useRef<string | null>(null)
  /** Increments whenever the current run is abandoned (skip / stop), so its late result is ignored. */
  const run = useRef(0)
  const advanceRef = useRef<() => Promise<void>>(async () => undefined)
  const logKey = useRef(0)
  const soundRef = useRef(sound)
  soundRef.current = sound
  const lockRef = useRef(lock)
  lockRef.current = lock

  const remaining = useCards({ nfc_status: "unprogrammed", per_page: 1 })

  useWakeLock(phase === "running")

  useEffect(() => {
    if (phase !== "running") return
    const timer = setInterval(() => setClock(Date.now()), 1000)
    return () => clearInterval(timer)
  }, [phase])

  const addLog = useCallback((card: GiftCard, outcome: Outcome, extra: Partial<LogEntry> = {}) => {
    logKey.current += 1
    const entry: LogEntry = {
      key: logKey.current,
      card,
      outcome,
      uid: null,
      tagType: null,
      locked: false,
      detail: null,
      errorCode: null,
      timings: null,
      at: new Date(),
      ...extra,
    }
    setLog((prev) => [entry, ...prev].slice(0, 2000))
  }, [])

  const listCards = (query: Record<string, string | number | undefined>) =>
    api<Paginated<GiftCard>>("/cards", { query: { nfc_status: "unprogrammed", sort: "card_number", ...query }, signal: AbortSignal.timeout(LIST_TIMEOUT_MS) })

  /** Next card of the queue, loading the next page (card-number cursor) when needed. */
  const nextCard = useCallback(async (): Promise<GiftCard | null> => {
    if (queue.current.length === 0 && !exhausted.current) {
      const page = await listCards({ per_page: PAGE, card_number_after: cursor.current })
      queue.current = page.data
      if (page.data.length < PAGE) exhausted.current = true
      if (page.data.length > 0) cursor.current = page.data[page.data.length - 1].card_number
    }
    return queue.current.shift() ?? null
  }, [])

  const program = useCallback(
    async (card: GiftCard) => {
      const token = ++run.current
      setError(null)
      if (!card.card_url) {
        setError(new ProgrammingError("NO_CARD_URL", "The card link is not available for your role.", "check"))
        return
      }
      try {
        const result = await programmer.program(
          { id: card.id, url: card.card_url },
          { lock: lockRef.current, ignoreSerials: lastUid.current ? [lastUid.current] : [], onlyIfUnprogrammed: true },
        )
        if (token !== run.current) return
        lastUid.current = result.uid
        if (soundRef.current) beep(true)
        if (result.outcome === "programmed") {
          addLog(card, "programmed", {
            uid: result.uid,
            tagType: result.tagType,
            locked: result.locked,
            timings: result.timings,
            detail: result.lockError ? `Not locked: ${result.lockError}` : null,
          })
        } else {
          addLog(card, "already_programmed", {
            uid: result.uid,
            locked: result.locked,
            timings: result.timings,
            detail: result.lockError ? `Not locked: ${result.lockError}` : null,
          })
        }
        void advanceRef.current()
      } catch (e) {
        if (token !== run.current) return
        const err = e instanceof ProgrammingError ? e : new ProgrammingError("UNKNOWN_ERROR", errorMessage(e), "read")
        if (err.code === "CANCELLED") return
        if (DONE_ELSEWHERE.has(err.code)) {
          // Another phone programmed this card: move on. A tag written here can be used for the next card.
          addLog(card, "skipped", { uid: err.uid, errorCode: err.code, detail: "Programmed on another device" })
          toast.info(`${formatCardNumber(card.card_number)} was programmed on another device. Lift the tag and hold it again for the next card.`)
          void advanceRef.current()
          return
        }
        setFailedAttempts((n) => n + 1)
        if (soundRef.current) beep(false)
        setError(err)
      }
    },
    [programmer, addLog],
  )

  const advance = useCallback(async () => {
    setError(null)
    setLoadError(null)
    try {
      const card = await nextCard()
      setCurrent(card)
      if (!card) {
        setPhase("finished")
        setStoppedAt(Date.now())
        programmer.close()
        return
      }
      void program(card)
    } catch (e) {
      setCurrent(null)
      setLoadError(errorMessage(e))
    }
  }, [nextCard, program, programmer])
  advanceRef.current = advance

  const start = async () => {
    setLoading(true)
    setLoadError(null)
    queue.current = []
    exhausted.current = false
    cursor.current = numberBefore(startAt)
    lastUid.current = null
    try {
      const count = await listCards({ per_page: 1, card_number_after: cursor.current })
      setSessionTotal(count.meta.total)
    } catch (e) {
      setLoadError(errorMessage(e))
      setLoading(false)
      return
    }
    setLog([])
    setFailedAttempts(0)
    setStartedAt(Date.now())
    setStoppedAt(null)
    setClock(Date.now())
    setPhase("running")
    await advance()
    setLoading(false)
  }

  const stop = () => {
    run.current += 1
    programmer.cancel()
    programmer.close()
    if (current && error) addLog(current, "failed", { uid: error.uid, errorCode: error.code, detail: error.message })
    setCurrent(null)
    setError(null)
    setPhase("setup")
    setStoppedAt(Date.now())
    void remaining.refetch()
  }

  const skip = () => {
    if (!current) return
    run.current += 1
    programmer.cancel()
    addLog(current, error ? "failed" : "skipped", { uid: error?.uid ?? null, errorCode: error?.code ?? null, detail: error?.message ?? null })
    void advance()
  }

  const retry = () => {
    if (current) void program(current)
  }

  useEffect(() => {
    if (phase !== "running") void remaining.refetch()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [log.length, phase])

  const programmed = log.filter((l) => l.outcome === "programmed")
  const completed = programmed.length + log.filter((l) => l.outcome === "already_programmed").length
  const skipped = log.filter((l) => l.outcome === "skipped" || l.outcome === "failed").length
  const elapsed = startedAt ? (stoppedAt ?? clock) - startedAt : 0
  const avgTagToSaved = average(programmed.map((l) => l.timings?.total_ms))
  const avgWrite = average(programmed.map((l) => l.timings?.write_ms))
  const avgVerify = average(programmed.map((l) => l.timings?.verify_ms))
  const perCardInclHandling = completed > 0 ? elapsed / completed : null
  const total = sessionTotal ?? 0

  if (!supported) {
    return (
      <div className="space-y-6">
        <PageHeader title="Program NFC tags" description="Write and verify the tags of many cards in one session." />
        <Card>
          <CardContent className="flex flex-col items-center gap-3 py-10 text-center">
            <Smartphone className="text-muted-foreground size-10" />
            <p className="font-medium">Open this page in Chrome on an Android phone with NFC</p>
            <p className="text-muted-foreground max-w-md text-sm">
              Tags are written, read back and verified by the phone. Desktop browsers and iPhones cannot write NFC tags from a web page.
            </p>
            <Button variant="outline" asChild>
              <Link href="/cards">
                <ArrowLeft /> Gift cards
              </Link>
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <Button variant="ghost" size="sm" asChild className="-ml-2">
          <Link href="/cards">
            <ArrowLeft /> Gift cards
          </Link>
        </Button>
        <PageHeader
          title="Program NFC tags"
          description="Each card gets its own tag: hold one blank tag at a time to the phone. Tags are checked, written, read back and verified before they are saved."
          actions={
            <Button variant="ghost" size="icon" onClick={() => setSound((s) => !s)} aria-label={sound ? "Mute sounds" : "Turn sounds on"} aria-pressed={sound}>
              {sound ? <Volume2 /> : <VolumeX />}
            </Button>
          }
        />
      </div>

      {startedAt ? (
        <Card data-testid="station-stats">
          <CardContent className="space-y-4 pt-6">
            <div className="space-y-2">
              <div className="flex items-baseline justify-between gap-3">
                <p className="text-lg font-semibold tabular-nums" data-testid="station-progress">
                  {completed} / {total} cards programmed
                </p>
                <p className="text-muted-foreground text-sm tabular-nums">{total > 0 ? Math.round((completed / total) * 100) : 0} %</p>
              </div>
              <Progress value={total > 0 ? (completed / total) * 100 : 0} aria-label="Programming progress" />
            </div>
            <div className="grid grid-cols-2 gap-2 sm:grid-cols-5">
              <Stat label="Successful" value={completed} tone="ok" />
              <Stat label="Failed attempts" value={failedAttempts} tone="bad" />
              <Stat label="Skipped cards" value={skipped} tone="warn" />
              <Stat label="Elapsed" value={formatDuration(elapsed)} />
              <Stat label="Avg. per card" value={formatSeconds(perCardInclHandling)} />
            </div>
            <p className="text-muted-foreground text-xs" data-testid="station-timing">
              Tag to saved {formatSeconds(avgTagToSaved)} on average · write {avgWrite === null ? "—" : `${Math.round(avgWrite)} ms`} · read back and verify{" "}
              {avgVerify === null ? "—" : `${Math.round(avgVerify)} ms`} · still without tag: {remaining.data?.meta.total ?? "—"}
            </p>
          </CardContent>
        </Card>
      ) : (
        <p className="text-muted-foreground text-sm">Cards without a tag: {remaining.data?.meta.total ?? "—"}</p>
      )}

      {phase === "setup" || phase === "finished" ? (
        <Card>
          <CardHeader>
            <CardTitle>{phase === "finished" ? "All cards programmed" : "Start a session"}</CardTitle>
            <CardDescription>
              {phase === "finished"
                ? "There are no more cards without a tag in this queue."
                : "Cards without a tag are programmed in card-number order. Label each tag with the card number shown on screen. With several phones, give each phone its own start number."}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-1.5">
                <Label htmlFor="start-at">
                  Start at card number <span className="text-muted-foreground font-normal">(optional)</span>
                </Label>
                <Input
                  id="start-at"
                  inputMode="numeric"
                  value={startAt}
                  onChange={(e) => setStartAt(e.target.value)}
                  placeholder="First card without a tag"
                  className="font-mono"
                />
              </div>
              <label className="flex items-center justify-between gap-3 rounded-xl border p-3 text-sm">
                <span>
                  <span className="font-medium">Lock each tag after verifying</span>
                  <span className="text-muted-foreground block text-xs">Permanent — tags can never be rewritten</span>
                </span>
                <Switch checked={lock} onCheckedChange={setLock} aria-label="Lock each tag after verifying" />
              </label>
            </div>
            {loadError ? (
              <p className="text-destructive text-sm" role="alert">
                {loadError}
              </p>
            ) : null}
            <Button size="lg" onClick={start} disabled={loading || remaining.data?.meta.total === 0}>
              {loading ? <Loader2 className="animate-spin" /> : <Play />} {phase === "finished" ? "Start again" : "Start programming"}
            </Button>
            {remaining.data?.meta.total === 0 ? <p className="text-muted-foreground text-sm">Every usable card already has a tag.</p> : null}
          </CardContent>
        </Card>
      ) : (
        <Card data-testid="station-current">
          <CardContent className="grid gap-6 pt-6 md:grid-cols-[1fr_1fr]">
            {current ? (
              <>
                <div className="space-y-3">
                  <p className="text-muted-foreground text-xs font-medium tracking-wide uppercase">Card to program</p>
                  <p className="card-number text-3xl font-semibold break-all sm:text-4xl" data-testid="station-card-number">
                    {formatCardNumber(current.card_number)}
                  </p>
                  <div className="flex flex-wrap items-center gap-2 text-sm">
                    <StatusBadge status={current.status} />
                    <span className="text-muted-foreground">
                      Value {formatMoney(current.initial_value, current.currency)}
                      {current.recipient_name ? ` · for ${current.recipient_name}` : ""}
                    </span>
                  </div>
                  <div
                    className={`flex size-20 items-center justify-center rounded-full ${error ? "bg-destructive/10" : "bg-primary/5"} ${programmer.state.running ? "animate-pulse" : ""}`}
                  >
                    <Nfc className={`size-10 ${error ? "text-destructive" : ""}`} />
                  </div>
                </div>
                <div className="space-y-4">
                  <NfcProgramSteps state={programmer.state} lock={lock} error={error} />
                  {error ? <NfcErrorPanel error={error} /> : null}
                  <div className="flex flex-wrap gap-2">
                    {error ? (
                      <Button onClick={retry}>
                        <RotateCcw /> Try again
                      </Button>
                    ) : null}
                    <Button variant="outline" onClick={skip}>
                      <SkipForward /> Skip card
                    </Button>
                    <Button variant="ghost" onClick={stop}>
                      <Square /> Stop
                    </Button>
                  </div>
                </div>
              </>
            ) : loadError ? (
              <div className="space-y-3 md:col-span-2">
                <NfcErrorPanel error={new ProgrammingError("SERVER_UNAVAILABLE", null, "check")} />
                <div className="flex flex-wrap gap-2">
                  <Button onClick={() => void advance()}>
                    <RotateCcw /> Try again
                  </Button>
                  <Button variant="ghost" onClick={stop}>
                    <Square /> Stop
                  </Button>
                </div>
              </div>
            ) : (
              <div className="text-muted-foreground flex items-center gap-2 text-sm">
                <Loader2 className="size-4 animate-spin" /> Loading the next card…
              </div>
            )}
          </CardContent>
        </Card>
      )}

      <Card>
        <CardHeader className="flex flex-row items-start justify-between gap-3">
          <div className="space-y-1.5">
            <CardTitle>This session</CardTitle>
            <CardDescription>Every attempt is also stored in the card&apos;s programming history.</CardDescription>
          </div>
          {log.length > 0 ? (
            <Button variant="outline" size="sm" onClick={() => downloadLog(log)}>
              <Download /> CSV
            </Button>
          ) : null}
        </CardHeader>
        <CardContent className="px-0">
          {log.length === 0 ? (
            <p className="text-muted-foreground px-6 text-sm">No cards programmed yet.</p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="pl-6">Card</TableHead>
                  <TableHead>Result</TableHead>
                  <TableHead className="hidden sm:table-cell">Chip</TableHead>
                  <TableHead className="hidden text-right sm:table-cell">Tag to saved</TableHead>
                  <TableHead className="hidden pr-6 text-right sm:table-cell">Time</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody data-testid="station-log">
                {log.map((entry) => (
                  <TableRow key={entry.key}>
                    <TableCell className="pl-6">
                      <Link href={`/cards/${entry.card.id}`} className="card-number hover:underline">
                        {formatCardNumber(entry.card.card_number)}
                      </Link>
                    </TableCell>
                    <TableCell>
                      <OutcomeLabel entry={entry} />
                      {entry.detail ? <span className="text-muted-foreground block max-w-xs text-xs">{entry.detail}</span> : null}
                    </TableCell>
                    <TableCell className="hidden font-mono text-xs sm:table-cell">
                      {entry.tagType ? `${TAG_TYPE_LABEL[entry.tagType]} · ` : ""}
                      {entry.uid ?? "—"}
                    </TableCell>
                    <TableCell className="hidden text-right text-xs tabular-nums sm:table-cell">{formatSeconds(entry.timings?.total_ms ?? null)}</TableCell>
                    <TableCell className="text-muted-foreground hidden pr-6 text-right text-xs tabular-nums sm:table-cell">
                      {entry.at.toLocaleTimeString()}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

export default function ProgramNfcPage() {
  return (
    <RequirePermission permission="cards.write_nfc">
      <ProgrammingStation />
    </RequirePermission>
  )
}
