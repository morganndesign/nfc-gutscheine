import { ArrowDownLeft, ArrowUpRight, CreditCard, RotateCcw } from "lucide-react"
import { cn } from "@/lib/utils"
import type { TransactionType } from "@/lib/api/types"

const TYPES: Record<TransactionType, { label: string; icon: typeof CreditCard; className: string }> = {
  issue: { label: "Sale", icon: CreditCard, className: "bg-emerald-50 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400" },
  reload: { label: "Reload", icon: ArrowDownLeft, className: "bg-emerald-50 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400" },
  redemption: { label: "Redemption", icon: ArrowUpRight, className: "bg-zinc-100 text-zinc-700 dark:bg-zinc-500/15 dark:text-zinc-300" },
  reversal: { label: "Reversal", icon: RotateCcw, className: "bg-sky-50 text-sky-700 dark:bg-sky-500/10 dark:text-sky-400" },
}

export const TRANSACTION_TYPES = Object.keys(TYPES) as TransactionType[]

export function transactionLabel(type: TransactionType): string {
  return TYPES[type].label
}

export function TransactionTypeIcon({ type, className }: { type: TransactionType; className?: string }) {
  const cfg = TYPES[type]
  const Icon = cfg.icon
  return (
    <span className={cn("flex size-8 shrink-0 items-center justify-center rounded-full", cfg.className, className)} aria-hidden>
      <Icon className="size-4" />
    </span>
  )
}
