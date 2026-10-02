import type { CardBatch, CardBatchStatus } from "./api/types.ts"

/** Every batch status, in lifecycle order (for the status filter). */
export const BATCH_STATUSES: CardBatchStatus[] = [
  "in_production",
  "accepted",
  "shipped",
  "on_hold",
  "in_service",
  "depleted",
  "rejected",
  "lost",
  "compromised",
  "closed",
]

/**
 * The exceptions the platform may set by hand ("More …"). Release, shipping and the restaurant's receipt have their
 * own steps; the server checks every transition again.
 */
export const SPECIAL_TRANSITIONS: Partial<Record<CardBatchStatus, CardBatchStatus[]>> = {
  in_production: ["rejected"],
  accepted: ["rejected", "compromised"],
  shipped: ["lost", "compromised"],
  on_hold: ["compromised"],
  in_service: ["depleted", "compromised"],
  depleted: ["closed", "compromised"],
  rejected: ["closed"],
  lost: ["closed"],
  compromised: ["closed"],
}

/** The one main action of a batch row; the others only show a hint. */
export type BatchStep =
  | { kind: "release"; ready: number; unfinished: number }
  | { kind: "ship"; cards: number }
  | { kind: "awaiting-receipt" }
  | { kind: "on-hold" }
  | { kind: "none" }

export function nextStep(batch: Pick<CardBatch, "status" | "counts">): BatchStep {
  switch (batch.status) {
    case "in_production":
      // Before the release, central stock holds exactly the QA-passed cards; the rest of production is dropped.
      return { kind: "release", ready: batch.counts.central_stock, unfinished: batch.counts.in_production }
    case "accepted":
      return { kind: "ship", cards: batch.counts.central_stock }
    case "shipped":
      return { kind: "awaiting-receipt" }
    case "on_hold":
      return { kind: "on-hold" }
    default:
      return { kind: "none" }
  }
}
