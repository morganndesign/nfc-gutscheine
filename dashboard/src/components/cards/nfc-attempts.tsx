"use client"

import { Skeleton } from "@/components/ui/skeleton"
import { useNfcAttempts } from "@/lib/api/hooks"
import type { NfcWriteAttempt } from "@/lib/api/types"
import { formatDateTime } from "@/lib/format"
import { TAG_TYPES } from "@/lib/nfc"
import { cn } from "@/lib/utils"

const RESULT: Record<NfcWriteAttempt["result"], { label: string; tone: string }> = {
  succeeded: { label: "Programmed", tone: "text-emerald-700 dark:text-emerald-400" },
  already_programmed: { label: "Already programmed", tone: "text-emerald-700 dark:text-emerald-400" },
  in_progress: { label: "Not finished", tone: "text-amber-700 dark:text-amber-400" },
  refused: { label: "Refused", tone: "text-destructive" },
  failed: { label: "Failed", tone: "text-destructive" },
  cancelled: { label: "Cancelled", tone: "text-muted-foreground" },
}

const METHOD: Record<NfcWriteAttempt["method"], string> = {
  web_nfc: "verified",
  manual: "external app, unverified",
  provisioned: "NTAG 424 DNA provisioning",
  printed: "QR printed",
}

/** Every attempt to program this card's tag (GET /cards/{id}/nfc/attempts). */
export function NfcAttempts({ cardId }: { cardId: string }) {
  const { data, isLoading } = useNfcAttempts(cardId)

  if (isLoading) return <Skeleton className="h-16 w-full" />
  if (!data?.length) return <p className="text-muted-foreground text-sm">No programming attempts yet.</p>

  return (
    <ul className="divide-y text-sm" data-testid="nfc-attempts">
      {data.map((a) => (
        <li key={a.id} className="flex items-start justify-between gap-3 py-2">
          <div className="min-w-0">
            <p className={cn("font-medium", RESULT[a.result].tone)}>
              {RESULT[a.result].label}
              <span className="text-muted-foreground font-normal"> · {METHOD[a.method]}</span>
              {a.locked ? <span className="text-muted-foreground font-normal"> · locked</span> : null}
            </p>
            {a.error_message ? <p className="text-muted-foreground text-xs">{a.error_message}</p> : null}
            <p className="text-muted-foreground font-mono text-xs">
              {a.tag_type ? `${TAG_TYPES.find((t) => t.value === a.tag_type)?.label ?? a.tag_type} · ` : ""}
              {a.uid ?? "no chip serial"}
            </p>
          </div>
          <div className="text-muted-foreground shrink-0 text-right text-xs">
            {formatDateTime(a.created_at)}
            {a.user ? <span className="block">{a.user.name}</span> : null}
          </div>
        </li>
      ))}
    </ul>
  )
}
