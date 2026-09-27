"use client"

import Link from "next/link"
import { AlertTriangle, Lock, ServerCrash, Timer, Unplug, XCircle } from "lucide-react"
import type { ProgrammingError } from "@/lib/nfc-programming"
import { formatCardNumber } from "@/lib/format"

const ICONS = {
  tag_removed: Unplug,
  wrong_tag: XCircle,
  tag_locked: Lock,
  tag_in_use: AlertTriangle,
  write_failed: XCircle,
  verification_failed: XCircle,
  server_unavailable: ServerCrash,
  network_timeout: Timer,
  card_state: AlertTriangle,
  nfc_unavailable: AlertTriangle,
  cancelled: XCircle,
  other: XCircle,
} as const

/** One failed programming attempt: what happened, what to do, and that nothing was saved. */
export function NfcErrorPanel({ error }: { error: ProgrammingError }) {
  const Icon = ICONS[error.category]
  return (
    <div
      className="border-destructive/40 bg-destructive/5 flex gap-3 rounded-xl border p-3 text-sm"
      role="alert"
      data-error-code={error.code}
      data-error-category={error.category}
    >
      <Icon className="text-destructive mt-0.5 size-5 shrink-0" />
      <div className="space-y-1">
        <p className="font-semibold">{error.title}</p>
        <p>{error.message}</p>
        {error.conflict ? (
          <Link className="inline-block underline underline-offset-4" href={`/cards/${error.conflict.card_id}`} target="_blank">
            Open card {formatCardNumber(error.conflict.card_number)}
          </Link>
        ) : null}
      </div>
    </div>
  )
}
