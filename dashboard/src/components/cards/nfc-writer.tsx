"use client"

import { useState } from "react"
import Link from "next/link"
import { AlertTriangle, CheckCircle2, Loader2, Nfc, Printer, ShieldCheck, Smartphone } from "lucide-react"
import { toast } from "sonner"
import { CopyButton } from "@/components/common/copy-button"
import { CardQr } from "@/components/cards/card-qr"
import { NfcErrorPanel } from "@/components/cards/nfc-error"
import { NfcProgramSteps } from "@/components/cards/nfc-program-steps"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Switch } from "@/components/ui/switch"
import { useBindNfc } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { GiftCard, NfcPayload, NfcTagType } from "@/lib/api/types"
import { TAG_TYPES } from "@/lib/nfc"
import { ProgrammingError, TAG_TYPE_LABEL, type ProgramResult } from "@/lib/nfc-programming"
import { useCapabilities } from "@/hooks/use-capabilities"
import { useNfcProgrammer } from "@/hooks/use-nfc-programmer"

type Kind = "ntag" | "ntag424_dna" | "qr_only"

const KINDS: { value: Kind; label: string; description: string }[] = [
  { value: "ntag", label: "NFC tag · NTAG213 / 215 / 216", description: "Chip type is detected automatically" },
  { value: "ntag424_dna", label: "NTAG 424 DNA", description: "Cryptographic anti-cloning (SUN)" },
  { value: "qr_only", label: "QR code only", description: "Printed card without chip" },
]

const NTAG21X = TAG_TYPES.filter((t) => ["ntag213", "ntag215", "ntag216"].includes(t.value))

function initialKind(hint: NfcTagType): Kind {
  return hint === "ntag424_dna" || hint === "qr_only" ? hint : "ntag"
}

/**
 * Programs the physical card. NTAG213/215/216 are written with Web NFC (Chrome on Android) through the
 * verified workflow (read → check → detect → write → read back → verify → save → lock); only then is
 * the chip linked to the card. Other browsers, NTAG 424 DNA and QR cards are recorded without a chip UID.
 */
export function NfcWriter({ cardId, payload, current, onDone }: { cardId: string; payload: NfcPayload; current?: GiftCard["nfc"]; onDone?: () => void }) {
  const [kind, setKind] = useState<Kind>(initialKind(payload.tag_type_hint))
  const [manualType, setManualType] = useState<NfcTagType>(
    ["ntag213", "ntag215", "ntag216"].includes(payload.tag_type_hint) ? payload.tag_type_hint : "ntag215",
  )
  const [lock, setLock] = useState<boolean>(payload.lock_after_write ?? false)
  const [error, setError] = useState<ProgrammingError | null>(null)
  const [result, setResult] = useState<ProgramResult | null>(null)
  const [recorded, setRecorded] = useState(false)
  const bind = useBindNfc(cardId)
  const { nfc: supported } = useCapabilities()
  const programmer = useNfcProgrammer()
  const busy = programmer.state.running

  const program = async () => {
    setError(null)
    setResult(null)
    try {
      const res = await programmer.program({ id: cardId, url: payload.url }, { lock })
      setResult(res)
      if (res.outcome === "programmed" && res.lockError) toast.warning(`Tag verified and saved, but not locked: ${res.lockError}`)
      onDone?.()
    } catch (e) {
      if (e instanceof ProgrammingError) {
        if (e.code !== "CANCELLED") setError(e)
      } else {
        toast.error(errorMessage(e))
      }
    }
  }

  const record = async (method: "manual" | "provisioned" | "printed", tagType: NfcTagType, locked: boolean) => {
    try {
      await bind.mutateAsync({ method, tag_type: tagType, locked })
      setRecorded(true)
      toast.success(method === "printed" ? "Card marked as printed." : "Card recorded as programmed.")
      onDone?.()
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  if (result || recorded) {
    return (
      <div className="flex flex-col items-center gap-3 rounded-2xl border bg-emerald-50/60 p-6 text-center dark:bg-emerald-500/5" data-testid="nfc-result">
        <CheckCircle2 className="size-10 text-emerald-700" />
        {result?.outcome === "programmed" ? (
          <div className="space-y-1">
            <p className="font-medium">Tag programmed and verified</p>
            <p className="text-muted-foreground text-sm">
              {TAG_TYPE_LABEL[result.tagType]} · <span className="font-mono">{result.uid}</span>
              {result.locked ? " · locked" : ""}
            </p>
            {result.replacedTag ? <p className="text-muted-foreground text-xs">The previous tag of this card no longer works.</p> : null}
          </div>
        ) : result?.outcome === "already_programmed" ? (
          <div className="space-y-1">
            <p className="font-medium">This tag is already programmed for this card</p>
            <p className="text-muted-foreground font-mono text-sm">{result.uid}</p>
          </div>
        ) : (
          <p className="font-medium">{kind === "qr_only" ? "Card ready" : "Card recorded"}</p>
        )}
        <p className="text-muted-foreground text-sm">The card can now be scanned by your staff.</p>
        {result ? (
          <Button variant="outline" size="sm" onClick={() => setResult(null)}>
            Program another tag for this card
          </Button>
        ) : null}
      </div>
    )
  }

  return (
    <div className="space-y-5">
      <div className="space-y-2">
        <Label htmlFor="tag-kind">Card type</Label>
        <Select value={kind} onValueChange={(v) => setKind(v as Kind)} disabled={busy}>
          <SelectTrigger id="tag-kind" className="w-full">
            <SelectValue>{KINDS.find((k) => k.value === kind)?.label}</SelectValue>
          </SelectTrigger>
          <SelectContent>
            {KINDS.map((k) => (
              <SelectItem key={k.value} value={k.value}>
                <span className="flex flex-col">
                  <span>{k.label}</span>
                  <span className="text-muted-foreground text-xs">{k.description}</span>
                </span>
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {kind === "ntag" && current?.uid ? (
        <p className="flex gap-2 rounded-xl border border-amber-300 bg-amber-50 p-3 text-sm text-amber-900 dark:border-amber-500/40 dark:bg-amber-500/10 dark:text-amber-200">
          <AlertTriangle className="mt-0.5 size-4 shrink-0" />
          <span>
            This card is linked to chip <span className="font-mono">{current.uid}</span>. Programming another tag replaces it — the old tag will stop working.
          </span>
        </p>
      ) : null}

      {kind === "ntag424_dna" ? (
        <div className="bg-surface space-y-3 rounded-2xl border p-4 text-sm">
          <p className="flex items-center gap-2 font-medium">
            <ShieldCheck className="size-4" /> NTAG 424 DNA provisioning
          </p>
          <p className="text-muted-foreground">
            Program the tag with a provisioning tool (e.g. NXP TagWriter) using SUN / SDM with encrypted PICC data and CMAC. Use this NDEF URL template and the
            server&apos;s SDM keys:
          </p>
          <code className="bg-background block rounded-lg p-3 text-xs break-all">
            {payload.ndef_template ?? `${payload.url}?picc=00000000000000000000000000000000&cmac=0000000000000000`}
          </code>
          <div className="flex flex-wrap gap-2">
            <CopyButton value={payload.ndef_template ?? payload.url} label="Copy template" />
            <Button size="sm" onClick={() => record("provisioned", "ntag424_dna", true)} disabled={bind.isPending}>
              {bind.isPending ? <Loader2 className="animate-spin" /> : null} Mark as provisioned
            </Button>
          </div>
          <p className="text-muted-foreground text-xs">The chip&apos;s UID is bound automatically on the first verified tap.</p>
        </div>
      ) : kind === "qr_only" ? (
        <div className="flex flex-col items-center gap-4 rounded-2xl border p-6 sm:flex-row">
          <CardQr cardId={cardId} className="size-36" />
          <div className="space-y-3 text-sm">
            <p className="text-muted-foreground">Print the QR code on the card. Guests and staff scan it with the phone camera.</p>
            <div className="flex flex-wrap gap-2">
              <Button variant="outline" size="sm" asChild>
                <Link href={`/print/cards/${cardId}`} target="_blank">
                  <Printer /> Print card
                </Link>
              </Button>
              <Button size="sm" onClick={() => record("printed", "qr_only", false)} disabled={bind.isPending}>
                Mark as printed
              </Button>
            </div>
          </div>
        </div>
      ) : supported ? (
        <div className="space-y-4">
          <label className="flex items-center justify-between gap-3 rounded-xl border p-3 text-sm">
            <span>
              <span className="font-medium">Lock tag after writing</span>
              <span className="text-muted-foreground block text-xs">Permanent, after the tag was verified — it can never be rewritten</span>
            </span>
            <Switch checked={lock} onCheckedChange={setLock} disabled={busy} aria-label="Lock tag after writing" />
          </label>

          <div className="grid gap-4 rounded-2xl border border-dashed p-5 sm:grid-cols-[auto_1fr] sm:items-start">
            <div className={`bg-primary/5 mx-auto flex size-16 items-center justify-center rounded-full ${busy ? "animate-pulse" : ""}`}>
              <Nfc className="size-8" />
            </div>
            <NfcProgramSteps state={programmer.state} lock={lock} error={error} />
          </div>

          {error ? <NfcErrorPanel error={error} /> : null}

          <div className="flex flex-wrap justify-center gap-2">
            {busy ? (
              <Button variant="outline" onClick={programmer.cancel}>
                Cancel
              </Button>
            ) : (
              <Button size="lg" onClick={program}>
                <Nfc /> {error ? "Try again" : "Write NFC tag"}
              </Button>
            )}
          </div>
          <p className="text-muted-foreground text-center text-xs">Only the card link is written to the tag — never the balance.</p>
        </div>
      ) : (
        <div className="bg-surface space-y-4 rounded-2xl border p-4 text-sm">
          <p className="flex items-center gap-2 font-medium">
            <Smartphone className="size-4" /> This browser cannot program NFC tags
          </p>
          <p className="text-muted-foreground">
            Open this card on an Android phone with Chrome to program and verify the tag in one tap. Tags written with another app (e.g. NFC Tools) using this
            URL record are <strong>not verified</strong>, and their chip serial number is not saved, so copied cards cannot be detected.
          </p>
          <div className="flex items-center gap-2">
            <Input readOnly value={payload.url} className="font-mono text-xs" onFocus={(e) => e.currentTarget.select()} aria-label="Card URL" />
            <CopyButton value={payload.url} />
          </div>
          <div className="grid gap-3 sm:grid-cols-[1fr_auto] sm:items-end">
            <div className="space-y-1.5">
              <Label htmlFor="manual-type">Tag type</Label>
              <Select value={manualType} onValueChange={(v) => setManualType(v as NfcTagType)}>
                <SelectTrigger id="manual-type" className="w-full">
                  <SelectValue>{NTAG21X.find((t) => t.value === manualType)?.label}</SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {NTAG21X.map((t) => (
                    <SelectItem key={t.value} value={t.value}>
                      {t.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <Button onClick={() => record("manual", manualType, false)} disabled={bind.isPending}>
              {bind.isPending ? <Loader2 className="animate-spin" /> : null} Mark as written
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}
