import { Ban, CheckCircle2, Circle, Clock } from "lucide-react"
import { cn } from "@/lib/utils"
import type { VoucherStatus } from "@/lib/api/types"

/** Expired and blocked vouchers keep their balance; an empty active voucher is shown as "Empty". */
const STATUS: Record<VoucherStatus | "empty", { label: string; className: string; icon: typeof Circle }> = {
  active: { label: "Active", className: "bg-emerald-50 text-emerald-700 ring-emerald-600/15 dark:bg-emerald-500/10 dark:text-emerald-400", icon: CheckCircle2 },
  empty: { label: "Empty", className: "bg-sky-50 text-sky-700 ring-sky-600/15 dark:bg-sky-500/10 dark:text-sky-400", icon: Circle },
  blocked: { label: "Blocked", className: "bg-red-50 text-red-700 ring-red-600/15 dark:bg-red-500/10 dark:text-red-400", icon: Ban },
  expired: { label: "Expired", className: "bg-amber-50 text-amber-800 ring-amber-600/20 dark:bg-amber-500/10 dark:text-amber-400", icon: Clock },
}

export const VOUCHER_STATUSES: VoucherStatus[] = ["active", "blocked", "expired"]

/** The badge status of a voucher: "empty" for an active voucher without balance. */
export function displayStatus(voucher: { status: VoucherStatus; balance: number }): VoucherStatus | "empty" {
  return voucher.status === "active" && voucher.balance === 0 ? "empty" : voucher.status
}

export function statusLabel(status: VoucherStatus | "empty"): string {
  return STATUS[status].label
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
