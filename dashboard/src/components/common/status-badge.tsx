import { Ban, CheckCircle2, Circle, CircleDashed, Clock, Replace } from "lucide-react"
import { cn } from "@/lib/utils"
import type { CardStatus } from "@/lib/api/types"

const STATUS: Record<CardStatus, { label: string; className: string; icon: typeof Circle }> = {
  active: { label: "Active", className: "bg-emerald-50 text-emerald-700 ring-emerald-600/15 dark:bg-emerald-500/10 dark:text-emerald-400", icon: CheckCircle2 },
  inactive: { label: "Inactive", className: "bg-zinc-100 text-zinc-600 ring-zinc-500/15 dark:bg-zinc-500/10 dark:text-zinc-400", icon: CircleDashed },
  redeemed: { label: "Redeemed", className: "bg-sky-50 text-sky-700 ring-sky-600/15 dark:bg-sky-500/10 dark:text-sky-400", icon: Circle },
  blocked: { label: "Blocked", className: "bg-red-50 text-red-700 ring-red-600/15 dark:bg-red-500/10 dark:text-red-400", icon: Ban },
  expired: { label: "Expired", className: "bg-amber-50 text-amber-800 ring-amber-600/20 dark:bg-amber-500/10 dark:text-amber-400", icon: Clock },
  replaced: { label: "Replaced", className: "bg-violet-50 text-violet-700 ring-violet-600/15 dark:bg-violet-500/10 dark:text-violet-400", icon: Replace },
}

export const CARD_STATUSES = Object.keys(STATUS) as CardStatus[]

export function statusLabel(status: CardStatus): string {
  return STATUS[status].label
}

export function StatusBadge({
  status,
  className,
  size = "sm",
  label,
}: {
  status: CardStatus
  className?: string
  size?: "sm" | "lg"
  /** Override the text, e.g. for guest-facing pages in the restaurant's language. */
  label?: string
}) {
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
      {label ?? cfg.label}
    </span>
  )
}
