"use client"

import { Badge } from "@/components/ui/badge"
import type { CardBatchStatus, CardState } from "@/lib/api/types"
import { hasMessage, tr, useT } from "@/lib/i18n"

/** Card state in the UI language (unknown states from a newer server show their code). */
export function cardStateLabel(state: CardState): string {
  const key = `cards.state.${state}`
  return hasMessage(key) ? tr(key) : state
}

export function CardStateBadge({ state }: { state: CardState }) {
  useT() // re-render on a language change
  const variant = state === "active" ? "default" : state === "suspended" || state === "revoked" || state === "lost" ? "destructive" : "secondary"
  return <Badge variant={variant}>{cardStateLabel(state)}</Badge>
}

/** Card batch status in the UI language. */
export function batchStatusLabel(status: CardBatchStatus): string {
  const key = `cards.batch.${status}`
  return hasMessage(key) ? tr(key) : status
}

export function BatchStatusBadge({ status }: { status: CardBatchStatus }) {
  useT() // re-render on a language change
  const variant =
    status === "compromised" || status === "rejected" || status === "lost" || status === "on_hold"
      ? "destructive"
      : status === "in_service"
        ? "default"
        : "secondary"
  return <Badge variant={variant}>{batchStatusLabel(status)}</Badge>
}
