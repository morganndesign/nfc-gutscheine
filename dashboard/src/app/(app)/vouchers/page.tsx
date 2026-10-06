"use client"

import { useState } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { Download, Filter, Loader2, Plus, Search, Ticket } from "lucide-react"
import { toast } from "sonner"
import { PageHeader } from "@/components/common/page-header"
import { QueryError } from "@/components/common/query-error"
import { LoyaltyBadge, OnlineBadge, StatusBadge, VOUCHER_STATUSES, displayStatus, statusLabelKey } from "@/components/common/status-badge"
import { EmptyState } from "@/components/common/empty-state"
import { PaginationBar } from "@/components/common/pagination-bar"
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
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useDebounce } from "@/hooks/use-debounce"
import { useVouchers } from "@/lib/api/hooks"
import { downloadFile, errorMessage } from "@/lib/api/client"
import type { VoucherStatus } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { formatDate } from "@/lib/format"
import { formatMoney } from "@/lib/money"
import { useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

const SORTS: { value: string; label: MessageKey }[] = [
  { value: "-created_at", label: "vouchers.list.sortNewest" },
  { value: "created_at", label: "vouchers.list.sortOldest" },
  { value: "-balance", label: "vouchers.list.sortHighestBalance" },
  { value: "balance", label: "vouchers.list.sortLowestBalance" },
  { value: "expires_at", label: "vouchers.list.sortExpiring" },
  { value: "-last_used_at", label: "vouchers.list.sortRecentlyUsed" },
]

function VouchersContent() {
  const { can } = useAuth()
  const t = useT()
  const router = useRouter()
  const [search, setSearch] = useState("")
  const [status, setStatus] = useState<VoucherStatus[]>([])
  const [loyalty, setLoyalty] = useState(false)
  const [sort, setSort] = useState("-created_at")
  const [page, setPage] = useState(1)
  const [exporting, setExporting] = useState(false)
  const debounced = useDebounce(search)

  const filters = { search: debounced, status, sort, page, per_page: 25, ...(loyalty ? { loyalty: 1 as const } : {}) }
  const { data, isLoading, isFetching, error, refetch } = useVouchers(filters)

  const toggleStatus = (s: VoucherStatus) => {
    setPage(1)
    setStatus((prev) => (prev.includes(s) ? prev.filter((x) => x !== s) : [...prev, s]))
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("vouchers.title")}
        description={data ? t("vouchers.list.count", { count: data.meta.total }) : t("vouchers.list.description")}
        actions={
          <>
            {can("vouchers.export") ? (
              <Button
                variant="outline"
                disabled={exporting}
                onClick={async () => {
                  setExporting(true)
                  try {
                    await downloadFile("/vouchers/export", { search: debounced, status, sort, ...(loyalty ? { loyalty: 1 } : {}) }, "vouchers.csv")
                  } catch (e) {
                    toast.error(errorMessage(e))
                  } finally {
                    setExporting(false)
                  }
                }}
              >
                {exporting ? <Loader2 className="animate-spin" /> : <Download />} {t("vouchers.list.export")}
              </Button>
            ) : null}
            {can("vouchers.sell") ? (
              <Button asChild>
                <Link href="/vouchers/new">
                  <Plus /> {t("vouchers.sell")}
                </Link>
              </Button>
            ) : null}
          </>
        }
      />

      <div className="bg-card overflow-hidden rounded-2xl border">
        <div className="flex flex-col gap-2 border-b p-3 sm:flex-row sm:items-center">
          <div className="relative flex-1">
            <Search className="text-muted-foreground absolute top-1/2 left-3 size-4 -translate-y-1/2" />
            <Input
              value={search}
              onChange={(e) => {
                setSearch(e.target.value)
                setPage(1)
              }}
              placeholder={t("vouchers.list.searchPlaceholder")}
              className="h-9 pl-9"
              aria-label={t("vouchers.list.searchAria")}
            />
          </div>
          <div className="flex gap-2">
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="outline" className="h-9">
                  <Filter /> {t("vouchers.col.status")}
                  {status.length + (loyalty ? 1 : 0) ? (
                    <span className="bg-primary text-primary-foreground rounded-full px-1.5 text-[10px]">{status.length + (loyalty ? 1 : 0)}</span>
                  ) : null}
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-48">
                <DropdownMenuLabel>{t("vouchers.list.filterByStatus")}</DropdownMenuLabel>
                <DropdownMenuSeparator />
                {VOUCHER_STATUSES.map((s) => (
                  <DropdownMenuCheckboxItem key={s} checked={status.includes(s)} onCheckedChange={() => toggleStatus(s)} onSelect={(e) => e.preventDefault()}>
                    {t(statusLabelKey(s))}
                  </DropdownMenuCheckboxItem>
                ))}
                <DropdownMenuSeparator />
                <DropdownMenuCheckboxItem
                  checked={loyalty}
                  onCheckedChange={(v) => {
                    setLoyalty(v === true)
                    setPage(1)
                  }}
                  onSelect={(e) => e.preventDefault()}
                >
                  {t("vouchers.loyalty.only")}
                </DropdownMenuCheckboxItem>
              </DropdownMenuContent>
            </DropdownMenu>
            <Select value={sort} onValueChange={(v) => setSort(v)}>
              <SelectTrigger className="h-9 w-44" aria-label={t("vouchers.list.sortAria")}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {SORTS.map((s) => (
                  <SelectItem key={s.value} value={s.value}>
                    {t(s.label)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>

        {isLoading ? (
          <div className="space-y-2 p-4">
            {Array.from({ length: 8 }).map((_, i) => (
              <Skeleton key={i} className="h-10 w-full" />
            ))}
          </div>
        ) : error && !data ? (
          <QueryError error={error} onRetry={() => void refetch()} />
        ) : data && data.data.length > 0 ? (
          <div className={isFetching ? "opacity-70 transition-opacity" : ""}>
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-4">{t("vouchers.col.voucher")}</TableHead>
                  <TableHead className="hidden sm:table-cell">{t("vouchers.col.customer")}</TableHead>
                  <TableHead className="hidden sm:table-cell">{t("vouchers.col.status")}</TableHead>
                  <TableHead className="pr-4 text-right sm:pr-2">{t("vouchers.col.balance")}</TableHead>
                  <TableHead className="hidden md:table-cell">{t("vouchers.col.expires")}</TableHead>
                  <TableHead className="hidden pr-4 lg:table-cell">{t("vouchers.col.issued")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.data.map((voucher) => (
                  <TableRow key={voucher.id} className="cursor-pointer" onClick={() => router.push(`/vouchers/${voucher.id}`)}>
                    <TableCell className="pl-4">
                      <Link href={`/vouchers/${voucher.id}`} className="card-number text-sm font-medium" onClick={(e) => e.stopPropagation()}>
                        {voucher.voucher_number_formatted}
                      </Link>
                      <span className="text-muted-foreground block max-w-44 truncate text-xs sm:hidden">
                        {voucher.customer?.full_name ?? voucher.recipient_name ?? t("vouchers.anonymous")}
                      </span>
                    </TableCell>
                    <TableCell className="text-muted-foreground hidden max-w-48 truncate sm:table-cell">
                      {voucher.customer?.full_name ?? voucher.recipient_name ?? t("common.none")}
                    </TableCell>
                    <TableCell className="hidden sm:table-cell">
                      <span className="inline-flex items-center gap-1.5">
                        <StatusBadge status={displayStatus(voucher)} />
                        {voucher.loyalty ? <LoyaltyBadge /> : null}
                        {voucher.online ? <OnlineBadge /> : null}
                      </span>
                    </TableCell>
                    <TableCell className="tabular pr-4 text-right sm:pr-2">
                      <span className="font-medium">{formatMoney(voucher.balance, voucher.currency)}</span>
                      <span className="text-muted-foreground hidden text-xs sm:inline"> / {formatMoney(voucher.initial_value, voucher.currency)}</span>
                      <span className="mt-1 flex justify-end sm:hidden">
                        <StatusBadge status={displayStatus(voucher)} />
                      </span>
                    </TableCell>
                    <TableCell className={`hidden md:table-cell ${voucher.is_expired ? "text-amber-700 dark:text-amber-400" : "text-muted-foreground"}`}>
                      {formatDate(voucher.expires_at)}
                    </TableCell>
                    <TableCell className="text-muted-foreground hidden pr-4 lg:table-cell">{formatDate(voucher.created_at)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            <PaginationBar page={data.meta} onPageChange={setPage} />
          </div>
        ) : (
          <EmptyState
            icon={Ticket}
            title={debounced || status.length ? t("vouchers.list.noMatches") : t("vouchers.list.empty")}
            description={debounced || status.length ? t("vouchers.list.noMatchesHint") : t("vouchers.list.emptyHint")}
            action={
              debounced || status.length ? (
                <Button
                  variant="outline"
                  onClick={() => {
                    setSearch("")
                    setStatus([])
                    setPage(1)
                  }}
                >
                  {t("vouchers.list.clearFilters")}
                </Button>
              ) : can("vouchers.sell") ? (
                <Button asChild>
                  <Link href="/vouchers/new">
                    <Plus /> {t("vouchers.sell")}
                  </Link>
                </Button>
              ) : undefined
            }
          />
        )}
      </div>
    </div>
  )
}

export default function VouchersPage() {
  return (
    <RequirePermission permission="vouchers.view">
      <VouchersContent />
    </RequirePermission>
  )
}
