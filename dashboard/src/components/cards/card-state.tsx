import { Badge } from "@/components/ui/badge"
import type { CardBatchStatus, CardState } from "@/lib/api/types"

const LABELS: Record<CardState, string> = {
  manufactured: "Manufactured",
  personalized: "Personalised",
  qa_passed: "QA passed",
  qa_failed: "QA failed",
  in_inventory: "Central stock",
  assigned: "Assigned",
  shipped: "Shipped",
  delivered: "Delivered",
  available: "In stock",
  bound: "Being sold",
  active: "Active",
  suspended: "Suspended",
  replaced: "Replaced",
  revoked: "Revoked",
  lost: "Lost",
  destroyed: "Destroyed",
}

export function cardStateLabel(state: CardState): string {
  return LABELS[state] ?? state
}

export function CardStateBadge({ state }: { state: CardState }) {
  const variant = state === "active" ? "default" : state === "suspended" || state === "revoked" || state === "lost" ? "destructive" : "secondary"
  return <Badge variant={variant}>{cardStateLabel(state)}</Badge>
}

const BATCH_LABELS: Record<CardBatchStatus, string> = {
  ordered: "Ordered",
  in_production: "In production",
  personalized: "Personalised",
  qa_testing: "QA testing",
  accepted: "Accepted",
  rejected: "Rejected",
  assigned: "Assigned",
  shipped: "Shipped",
  delivered: "Delivered",
  on_hold: "On hold",
  in_service: "In service",
  depleted: "Depleted",
  compromised: "Compromised",
  lost: "Lost",
  closed: "Closed",
}

export function batchStatusLabel(status: CardBatchStatus): string {
  return BATCH_LABELS[status] ?? status
}

export function BatchStatusBadge({ status }: { status: CardBatchStatus }) {
  const variant = status === "compromised" || status === "rejected" || status === "lost" || status === "on_hold" ? "destructive" : status === "in_service" ? "default" : "secondary"
  return <Badge variant={variant}>{batchStatusLabel(status)}</Badge>
}
