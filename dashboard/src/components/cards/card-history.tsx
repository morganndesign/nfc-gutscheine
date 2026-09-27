"use client"

import { useState } from "react"
import { History, RotateCcw } from "lucide-react"
import { toast } from "sonner"
import { EmptyState } from "@/components/common/empty-state"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { TransactionTypeIcon } from "@/components/cards/transaction-type"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { useCardHistory, useReverseTransaction } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { TransactionType } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { auditLabel } from "@/lib/audit"
import { formatDateTime } from "@/lib/format"
import { formatMoney, formatSignedMoney } from "@/lib/money"
import { cn } from "@/lib/utils"

const REVERSIBLE: string[] = ["redemption", "reload"]

export function CardHistory({ cardId, currency }: { cardId: string; currency: string }) {
  const { can } = useAuth()
  const { data, isLoading } = useCardHistory(cardId)
  const reverse = useReverseTransaction()
  const [reversing, setReversing] = useState<string | null>(null)

  if (isLoading) {
    return (
      <div className="space-y-3">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton key={i} className="h-12 w-full" />
        ))}
      </div>
    )
  }
  if (!data?.length) return <EmptyState icon={History} title="No history" />

  return (
    <>
      <ol className="relative space-y-1">
        {data.map((entry) => (
          <li key={entry.id} className="group hover:bg-muted/60 flex items-start gap-3 rounded-xl px-2 py-2.5">
            {entry.kind === "transaction" ? (
              <TransactionTypeIcon type={entry.type as TransactionType} />
            ) : (
              <span className="bg-muted text-muted-foreground flex size-8 shrink-0 items-center justify-center rounded-full">
                <History className="size-4" />
              </span>
            )}
            <div className="min-w-0 flex-1">
              <div className="flex items-baseline justify-between gap-3">
                <p className={cn("text-sm font-medium", entry.reversed && "line-through opacity-60")}>
                  {entry.kind === "event" ? auditLabel(entry.type) : entry.label}
                  {entry.reversed ? <span className="text-muted-foreground ml-2 text-xs font-normal no-underline">reversed</span> : null}
                </p>
                {entry.amount !== null ? (
                  <span
                    className={cn(
                      "tabular text-sm font-medium",
                      entry.amount > 0 && "text-emerald-700 dark:text-emerald-400",
                      entry.reversed && "line-through opacity-60",
                    )}
                  >
                    {formatSignedMoney(entry.amount, currency)}
                  </span>
                ) : null}
              </div>
              <p className="text-muted-foreground text-xs">
                {formatDateTime(entry.created_at)}
                {entry.user ? ` · ${entry.user}` : ""}
                {entry.device ? ` · ${entry.device}` : ""}
                {entry.reference ? ` · Ref. ${entry.reference}` : ""}
                {entry.balance_after !== null ? ` · Balance ${formatMoney(entry.balance_after, currency)}` : ""}
              </p>
              {entry.note ? <p className="text-muted-foreground mt-0.5 text-xs italic">“{entry.note}”</p> : null}
            </div>
            {entry.kind === "transaction" && REVERSIBLE.includes(entry.type) && !entry.reversed && can("transactions.reverse") ? (
              <Button
                variant="ghost"
                size="icon-sm"
                className="group-hover:opacity-100 focus-visible:opacity-100 sm:opacity-0"
                aria-label="Reverse transaction"
                onClick={() => setReversing(entry.id)}
              >
                <RotateCcw />
              </Button>
            ) : can("transactions.reverse") ? (
              <span className="size-7 shrink-0" aria-hidden />
            ) : null}
          </li>
        ))}
      </ol>
      <ReasonDialog
        open={reversing !== null}
        onOpenChange={(o) => !o && setReversing(null)}
        title="Reverse transaction"
        suggestions={["Wrong amount", "Wrong card", "Guest cancelled"]}
        description="Creates a counter-entry that restores the previous balance. The original entry stays in the ledger."
        confirmLabel="Reverse"
        destructive
        pending={reverse.isPending}
        onConfirm={async (reason) => {
          if (!reversing) return
          try {
            await reverse.mutateAsync({ id: reversing, reason })
            toast.success("Transaction reversed")
            setReversing(null)
          } catch (e) {
            toast.error(errorMessage(e))
          }
        }}
      />
    </>
  )
}
