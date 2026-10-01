"use client"

import { useState } from "react"
import { History, RotateCcw } from "lucide-react"
import { toast } from "sonner"
import { EmptyState } from "@/components/common/empty-state"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { PAYMENT_METHOD_LABELS } from "@/components/vouchers/payment-fields"
import { TransactionTypeIcon, transactionLabelKey } from "@/components/vouchers/transaction-type"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { useReverseTransaction, useVoucherHistory } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { TransactionType } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { auditLabel } from "@/lib/audit"
import { formatDateTime } from "@/lib/format"
import { formatMoney, formatSignedMoney } from "@/lib/money"
import { useT } from "@/lib/i18n"
import { cn } from "@/lib/utils"

const REVERSIBLE: string[] = ["redemption", "reload"]
const TRANSACTION_TYPES: string[] = ["issue", "reload", "redemption", "reversal", "refund"]

export function VoucherHistory({ voucherId, currency }: { voucherId: string; currency: string }) {
  const { can } = useAuth()
  const t = useT()
  const { data, isLoading } = useVoucherHistory(voucherId)
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
  if (!data?.length) return <EmptyState icon={History} title={t("vouchers.history.empty")} />

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
                  {entry.kind === "event"
                    ? auditLabel(entry.type)
                    : TRANSACTION_TYPES.includes(entry.type)
                      ? t(transactionLabelKey(entry.type as TransactionType))
                      : entry.label}
                  {entry.reversed ? (
                    <span className="text-muted-foreground ml-2 text-xs font-normal no-underline">{t("vouchers.history.reversed")}</span>
                  ) : null}
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
                {entry.payment_method
                  ? ` · ${t("vouchers.history.payment", { method: PAYMENT_METHOD_LABELS[entry.payment_method] ? t(PAYMENT_METHOD_LABELS[entry.payment_method]) : entry.payment_method })}`
                  : ""}
                {entry.reference ? ` · ${t("vouchers.ref", { reference: entry.reference })}` : ""}
                {entry.balance_after !== null ? ` · ${t("vouchers.history.balance", { amount: formatMoney(entry.balance_after, currency) })}` : ""}
              </p>
              {entry.note ? <p className="text-muted-foreground mt-0.5 text-xs italic">“{entry.note}”</p> : null}
            </div>
            {entry.kind === "transaction" && REVERSIBLE.includes(entry.type) && !entry.reversed && can("transactions.reverse") ? (
              <Button
                variant="ghost"
                size="icon-sm"
                className="group-hover:opacity-100 focus-visible:opacity-100 sm:opacity-0"
                aria-label={t("vouchers.history.reverse")}
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
        title={t("vouchers.history.reverse")}
        suggestions={[t("vouchers.reason.wrongAmount"), t("vouchers.reason.wrongVoucher"), t("vouchers.reason.guestCancelled")]}
        description={t("vouchers.history.reverseDescription")}
        confirmLabel={t("vouchers.history.reverseConfirm")}
        destructive
        pending={reverse.isPending}
        onConfirm={async (reason) => {
          if (!reversing) return
          try {
            await reverse.mutateAsync({ id: reversing, reason })
            toast.success(t("vouchers.history.reversedToast"))
            setReversing(null)
          } catch (e) {
            toast.error(errorMessage(e))
          }
        }}
      />
    </>
  )
}
