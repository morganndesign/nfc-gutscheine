import { ArrowDownLeft, ArrowUpRight, CreditCard, RotateCcw, Undo2 } from "lucide-react"
import { cn } from "@/lib/utils"
import type { TransactionType } from "@/lib/api/types"
import { tr } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

const TYPES: Record<TransactionType, { label: MessageKey; icon: typeof CreditCard; className: string }> = {
  issue: { label: "transactionType.issue", icon: CreditCard, className: "bg-emerald-50 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400" },
  reload: { label: "transactionType.reload", icon: ArrowDownLeft, className: "bg-emerald-50 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400" },
  redemption: { label: "transactionType.redemption", icon: ArrowUpRight, className: "bg-zinc-100 text-zinc-700 dark:bg-zinc-500/15 dark:text-zinc-300" },
  reversal: { label: "transactionType.reversal", icon: RotateCcw, className: "bg-sky-50 text-sky-700 dark:bg-sky-500/10 dark:text-sky-400" },
  refund: { label: "transactionType.refund", icon: Undo2, className: "bg-amber-50 text-amber-800 dark:bg-amber-500/10 dark:text-amber-400" },
}

export const TRANSACTION_TYPES = Object.keys(TYPES) as TransactionType[]

export function transactionLabelKey(type: TransactionType): MessageKey {
  return TYPES[type].label
}

/** The type in the current UI language (in components prefer `t(transactionLabelKey(type))`). */
export function transactionLabel(type: TransactionType): string {
  return tr(TYPES[type].label)
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
