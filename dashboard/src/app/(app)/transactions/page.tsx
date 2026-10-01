"use client"

import { useState } from "react"
import Link from "next/link"
import { ArrowLeftRight, Download, Filter, Loader2, RotateCcw, Search } from "lucide-react"
import { toast } from "sonner"
import { PageHeader } from "@/components/common/page-header"
import { EmptyState } from "@/components/common/empty-state"
import { PaginationBar } from "@/components/common/pagination-bar"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { TRANSACTION_TYPES, TransactionTypeIcon } from "@/components/vouchers/transaction-type"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Input } from "@/components/ui/input"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useDebounce } from "@/hooks/use-debounce"
import { useReverseTransaction, useTransactions } from "@/lib/api/hooks"
import { downloadFile, errorMessage } from "@/lib/api/client"
import type { TransactionType } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { formatDateTime } from "@/lib/format"
import { formatMoney, formatSignedMoney } from "@/lib/money"
import { cn } from "@/lib/utils"
import { useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

function TransactionsContent() {
  const { can } = useAuth()
  const [search, setSearch] = useState("")
  const [types, setTypes] = useState<TransactionType[]>([])
  const [from, setFrom] = useState("")
  const [to, setTo] = useState("")
  const [page, setPage] = useState(1)
  const [exporting, setExporting] = useState(false)
  const [reversing, setReversing] = useState<string | null>(null)
  const debounced = useDebounce(search)
  const reverse = useReverseTransaction()
  const t = useT()

  const filters = { search: debounced, type: types, from, to, page, per_page: 50 }
  const { data, isLoading, isFetching } = useTransactions(filters)

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("nav.transactions")}
        description={t("transactions.description")}
        actions={
          can("transactions.export") ? (
            <Button
              variant="outline"
              disabled={exporting}
              onClick={async () => {
                setExporting(true)
                try {
                  await downloadFile("/transactions/export", { search: debounced, type: types, from, to }, "transactions.csv")
                } catch (e) {
                  toast.error(errorMessage(e))
                } finally {
                  setExporting(false)
                }
              }}
            >
              {exporting ? <Loader2 className="animate-spin" /> : <Download />} {t("transactions.export")}
            </Button>
          ) : null
        }
      />

      <div className="bg-card overflow-hidden rounded-2xl border">
        <div className="flex flex-col gap-2 border-b p-3 lg:flex-row lg:items-center">
          <div className="relative flex-1">
            <Search className="text-muted-foreground absolute top-1/2 left-3 size-4 -translate-y-1/2" />
            <Input
              value={search}
              onChange={(e) => {
                setSearch(e.target.value)
                setPage(1)
              }}
              placeholder={t("transactions.searchPlaceholder")}
              className="h-9 pl-9"
              aria-label={t("transactions.searchLabel")}
            />
          </div>
          <div className="grid grid-cols-2 gap-2 sm:flex sm:items-center">
            <label className="text-muted-foreground flex min-w-0 flex-col gap-1 text-xs sm:flex-row sm:items-center sm:gap-2">
              {t("transactions.from")}
              <Input type="date" value={from} max={to || undefined} onChange={(e) => (setFrom(e.target.value), setPage(1))} className="h-9 min-w-0 sm:w-40" />
            </label>
            <label className="text-muted-foreground flex min-w-0 flex-col gap-1 text-xs sm:flex-row sm:items-center sm:gap-2">
              {t("transactions.to")}
              <Input type="date" value={to} min={from || undefined} onChange={(e) => (setTo(e.target.value), setPage(1))} className="h-9 min-w-0 sm:w-40" />
            </label>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="outline" className="col-span-2 h-9 sm:col-span-1">
                  <Filter /> {t("ops.col.type")}
                  {types.length ? <span className="bg-primary text-primary-foreground rounded-full px-1.5 text-[10px]">{types.length}</span> : null}
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-48">
                <DropdownMenuLabel>{t("transactions.typeFilterLabel")}</DropdownMenuLabel>
                <DropdownMenuSeparator />
                {TRANSACTION_TYPES.map((type) => (
                  <DropdownMenuCheckboxItem
                    key={type}
                    checked={types.includes(type)}
                    onSelect={(e) => e.preventDefault()}
                    onCheckedChange={() => {
                      setPage(1)
                      setTypes((prev) => (prev.includes(type) ? prev.filter((x) => x !== type) : [...prev, type]))
                    }}
                  >
                    {t(`ops.txType.${type}` as MessageKey)}
                  </DropdownMenuCheckboxItem>
                ))}
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>

        {isLoading ? (
          <div className="space-y-2 p-4">
            {Array.from({ length: 10 }).map((_, i) => (
              <Skeleton key={i} className="h-10 w-full" />
            ))}
          </div>
        ) : data?.data.length ? (
          <div className={isFetching ? "opacity-70 transition-opacity" : ""}>
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-4">{t("ops.col.type")}</TableHead>
                  <TableHead className="hidden sm:table-cell">{t("ops.col.voucher")}</TableHead>
                  <TableHead className="text-right">{t("ops.col.amount")}</TableHead>
                  <TableHead className="hidden text-right md:table-cell">{t("transactions.col.balanceAfter")}</TableHead>
                  <TableHead className="hidden lg:table-cell">{t("transactions.col.reference")}</TableHead>
                  <TableHead className="hidden md:table-cell">{t("transactions.col.by")}</TableHead>
                  <TableHead className="hidden sm:table-cell">{t("ops.col.date")}</TableHead>
                  <TableHead className="w-10 pr-4" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.data.map((tx) => (
                  <TableRow key={tx.id} className={tx.reversed ? "opacity-60" : undefined}>
                    <TableCell className="pl-4">
                      <div className="flex items-center gap-2">
                        <TransactionTypeIcon type={tx.type} className="size-7" />
                        <div className="min-w-0">
                          <span className="text-sm">{t(`ops.txType.${tx.type}` as MessageKey)}</span>
                          {tx.reversed ? (
                            <span className="bg-muted text-muted-foreground ml-1.5 rounded px-1.5 text-[10px] uppercase">{t("transactions.reversed")}</span>
                          ) : null}
                          <span className="text-muted-foreground block text-xs sm:hidden">
                            {tx.voucher ? `•••• ${tx.voucher.voucher_number.slice(-4)} · ` : ""}
                            {formatDateTime(tx.created_at)}
                          </span>
                        </div>
                      </div>
                    </TableCell>
                    <TableCell className="hidden sm:table-cell">
                      {tx.voucher ? (
                        <Link href={`/vouchers/${tx.voucher.id}`} className="card-number text-sm hover:underline">
                          •••• {tx.voucher.voucher_number.slice(-4)}
                        </Link>
                      ) : (
                        "—"
                      )}
                    </TableCell>
                    <TableCell
                      className={cn("tabular text-right font-medium", tx.amount > 0 && "text-emerald-700 dark:text-emerald-400", tx.reversed && "line-through")}
                    >
                      {formatSignedMoney(tx.amount, tx.currency)}
                    </TableCell>
                    <TableCell className="text-muted-foreground tabular hidden text-right md:table-cell">
                      {formatMoney(tx.balance_after, tx.currency)}
                    </TableCell>
                    <TableCell className="text-muted-foreground hidden max-w-40 truncate lg:table-cell">{tx.reference ?? tx.note ?? "—"}</TableCell>
                    <TableCell className="text-muted-foreground hidden md:table-cell">
                      {tx.user?.name ?? t("ops.system")}
                      {tx.device ? <span className="block text-xs">{tx.device.name}</span> : null}
                    </TableCell>
                    <TableCell className="text-muted-foreground hidden whitespace-nowrap sm:table-cell">{formatDateTime(tx.created_at)}</TableCell>
                    <TableCell className="pr-4">
                      {tx.reversible && can("transactions.reverse") ? (
                        <Button
                          variant="ghost"
                          size="icon-sm"
                          aria-label={t("transactions.reverseTitle")}
                          title={t("transactions.reverse")}
                          onClick={() => setReversing(tx.id)}
                        >
                          <RotateCcw />
                        </Button>
                      ) : null}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            <PaginationBar page={data.meta} onPageChange={setPage} />
          </div>
        ) : (
          <EmptyState icon={ArrowLeftRight} title={t("transactions.emptyTitle")} description={t("transactions.emptyDescription")} />
        )}
      </div>

      <ReasonDialog
        open={reversing !== null}
        onOpenChange={(o) => !o && setReversing(null)}
        title={t("transactions.reverseTitle")}
        suggestions={[t("transactions.reason.wrongAmount"), t("transactions.reason.wrongVoucher"), t("transactions.reason.guestCancelled")]}
        description={t("transactions.reverseDescription")}
        confirmLabel={t("transactions.reverse")}
        destructive
        pending={reverse.isPending}
        onConfirm={async (reason) => {
          if (!reversing) return
          try {
            await reverse.mutateAsync({ id: reversing, reason })
            toast.success(t("transactions.reversedToast"))
            setReversing(null)
          } catch (e) {
            toast.error(errorMessage(e))
          }
        }}
      />
    </div>
  )
}

export default function TransactionsPage() {
  return (
    <RequirePermission permission="transactions.view">
      <TransactionsContent />
    </RequirePermission>
  )
}
