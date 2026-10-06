"use client"

import { Ban, CheckCircle2, Circle, Clock, Globe, Heart, Undo2 } from "lucide-react"
import { cn } from "@/lib/utils"
import type { VoucherStatus } from "@/lib/api/types"
import { tr, useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

/** Expired and blocked vouchers keep their balance; refunded ones are closed; an empty active voucher is "Empty". */
const STATUS: Record<VoucherStatus | "empty", { label: MessageKey; className: string; icon: typeof Circle }> = {
  active: {
    label: "voucherStatus.active",
    className: "bg-emerald-50 text-emerald-700 ring-emerald-600/15 dark:bg-emerald-500/10 dark:text-emerald-400",
    icon: CheckCircle2,
  },
  empty: { label: "voucherStatus.empty", className: "bg-sky-50 text-sky-700 ring-sky-600/15 dark:bg-sky-500/10 dark:text-sky-400", icon: Circle },
  blocked: { label: "voucherStatus.blocked", className: "bg-red-50 text-red-700 ring-red-600/15 dark:bg-red-500/10 dark:text-red-400", icon: Ban },
  expired: { label: "voucherStatus.expired", className: "bg-amber-50 text-amber-800 ring-amber-600/20 dark:bg-amber-500/10 dark:text-amber-400", icon: Clock },
  refunded: { label: "voucherStatus.refunded", className: "bg-zinc-100 text-zinc-700 ring-zinc-500/20 dark:bg-zinc-500/15 dark:text-zinc-300", icon: Undo2 },
}

export const VOUCHER_STATUSES: VoucherStatus[] = ["active", "blocked", "expired", "refunded"]

export { displayStatus } from "@/lib/voucher-state"

export function statusLabelKey(status: VoucherStatus | "empty"): MessageKey {
  return STATUS[status].label
}

/** The status in the current UI language (outside React; in components prefer `t(statusLabelKey(status))`). */
export function statusLabel(status: VoucherStatus | "empty"): string {
  return tr(STATUS[status].label)
}

export function StatusBadge({
  status,
  className,
  size = "sm",
  label,
}: {
  status: VoucherStatus | "empty"
  className?: string
  size?: "sm" | "lg"
  /** Override the text, e.g. for guest-facing pages in the restaurant's language. */
  label?: string
}) {
  const t = useT()
  const cfg = STATUS[status]
  const Icon = cfg.icon
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full font-medium ring-1 ring-inset",
        size === "sm" ? "px-2 py-0.5 text-xs" : "px-3 py-1 text-sm",
        cfg.className,
        className,
      )}
    >
      <Icon className={size === "sm" ? "size-3" : "size-4"} aria-hidden />
      {label ?? t(cfg.label)}
    </span>
  )
}

/** Bought in the restaurant's online shop (decision 2026-10-06). */
export function OnlineBadge({ className }: { className?: string }) {
  const t = useT()
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset",
        "bg-sky-50 text-sky-700 ring-sky-600/15 dark:bg-sky-500/10 dark:text-sky-300",
        className,
      )}
    >
      <Globe className="size-3" aria-hidden />
      {t("online.badge")}
    </span>
  )
}

/** A regular's loyalty voucher: the owner gave value without payment (decision 2026-10-05). */
export function LoyaltyBadge({ className }: { className?: string }) {
  const t = useT()
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset",
        "bg-violet-50 text-violet-700 ring-violet-600/15 dark:bg-violet-500/10 dark:text-violet-300",
        className,
      )}
    >
      <Heart className="size-3" aria-hidden />
      {t("vouchers.loyalty.badge")}
    </span>
  )
}
