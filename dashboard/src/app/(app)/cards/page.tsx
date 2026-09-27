"use client"

import { useState } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { CreditCard, Download, Filter, Loader2, Nfc, Plus, Search } from "lucide-react"
import { toast } from "sonner"
import { PageHeader } from "@/components/common/page-header"
import { CARD_STATUSES, StatusBadge, statusLabel } from "@/components/common/status-badge"
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
import { useCards } from "@/lib/api/hooks"
import { downloadFile, errorMessage } from "@/lib/api/client"
import type { CardStatus } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { formatDate } from "@/lib/format"
import { formatMoney } from "@/lib/money"

const SORTS = [
  { value: "-created_at", label: "Newest first" },
  { value: "created_at", label: "Oldest first" },
  { value: "-balance", label: "Highest balance" },
  { value: "balance", label: "Lowest balance" },
  { value: "expires_at", label: "Expiring soonest" },
  { value: "-last_used_at", label: "Recently used" },
]

function CardsContent() {
  const { can } = useAuth()
  const router = useRouter()
  const [search, setSearch] = useState("")
  const [status, setStatus] = useState<CardStatus[]>([])
  const [sort, setSort] = useState("-created_at")
  const [page, setPage] = useState(1)
  const [exporting, setExporting] = useState(false)
  const debounced = useDebounce(search)

  const filters = { search: debounced, status, sort, page, per_page: 25 }
  const { data, isLoading, isFetching } = useCards(filters)

  const toggleStatus = (s: CardStatus) => {
    setPage(1)
    setStatus((prev) => (prev.includes(s) ? prev.filter((x) => x !== s) : [...prev, s]))
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Gift cards"
        description={data ? `${data.meta.total} card${data.meta.total === 1 ? "" : "s"}` : "All cards of your restaurant"}
        actions={
          <>
            {can("cards.export") ? (
              <Button
                variant="outline"
                disabled={exporting}
                onClick={async () => {
                  setExporting(true)
                  try {
                    await downloadFile("/cards/export", { search: debounced, status, sort }, "gift-cards.csv")
                  } catch (e) {
                    toast.error(errorMessage(e))
                  } finally {
                    setExporting(false)
                  }
                }}
              >
                {exporting ? <Loader2 className="animate-spin" /> : <Download />} Export CSV
              </Button>
            ) : null}
            {can("cards.write_nfc") ? (
              <Button variant="outline" asChild>
                <Link href="/cards/program">
                  <Nfc /> Program NFC tags
                </Link>
              </Button>
            ) : null}
            {can("cards.create") ? (
              <Button asChild>
                <Link href="/cards/new">
                  <Plus /> New gift card
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
              placeholder="Search by card number, customer, recipient or note…"
              className="h-9 pl-9"
              aria-label="Search cards"
            />
          </div>
          <div className="flex gap-2">
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="outline" className="h-9">
                  <Filter /> Status
                  {status.length ? <span className="bg-primary text-primary-foreground rounded-full px-1.5 text-[10px]">{status.length}</span> : null}
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-48">
                <DropdownMenuLabel>Filter by status</DropdownMenuLabel>
                <DropdownMenuSeparator />
                {CARD_STATUSES.map((s) => (
                  <DropdownMenuCheckboxItem key={s} checked={status.includes(s)} onCheckedChange={() => toggleStatus(s)} onSelect={(e) => e.preventDefault()}>
                    {statusLabel(s)}
                  </DropdownMenuCheckboxItem>
                ))}
              </DropdownMenuContent>
            </DropdownMenu>
            <Select value={sort} onValueChange={(v) => setSort(v)}>
              <SelectTrigger className="h-9 w-44" aria-label="Sort">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {SORTS.map((s) => (
                  <SelectItem key={s.value} value={s.value}>
                    {s.label}
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
        ) : data && data.data.length > 0 ? (
          <div className={isFetching ? "opacity-70 transition-opacity" : ""}>
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-4">Card</TableHead>
                  <TableHead className="hidden sm:table-cell">Customer</TableHead>
                  <TableHead className="hidden sm:table-cell">Status</TableHead>
                  <TableHead className="pr-4 text-right sm:pr-2">Balance</TableHead>
                  <TableHead className="hidden md:table-cell">Expires</TableHead>
                  <TableHead className="hidden pr-4 lg:table-cell">Issued</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.data.map((card) => (
                  <TableRow key={card.id} className="cursor-pointer" onClick={() => router.push(`/cards/${card.id}`)}>
                    <TableCell className="pl-4">
                      <Link href={`/cards/${card.id}`} className="card-number text-sm font-medium" onClick={(e) => e.stopPropagation()}>
                        {card.card_number_formatted}
                      </Link>
                      <span className="text-muted-foreground block max-w-44 truncate text-xs sm:hidden">
                        {card.customer?.full_name ?? card.recipient_name ?? "Anonymous"}
                      </span>
                    </TableCell>
                    <TableCell className="text-muted-foreground hidden max-w-48 truncate sm:table-cell">
                      {card.customer?.full_name ?? card.recipient_name ?? "—"}
                    </TableCell>
                    <TableCell className="hidden sm:table-cell">
                      <StatusBadge status={card.status} />
                    </TableCell>
                    <TableCell className="tabular pr-4 text-right sm:pr-2">
                      <span className="font-medium">{formatMoney(card.balance, card.currency)}</span>
                      <span className="text-muted-foreground hidden text-xs sm:inline"> / {formatMoney(card.initial_value, card.currency)}</span>
                      <span className="mt-1 flex justify-end sm:hidden">
                        <StatusBadge status={card.status} />
                      </span>
                    </TableCell>
                    <TableCell className={`hidden md:table-cell ${card.is_expired ? "text-amber-700 dark:text-amber-400" : "text-muted-foreground"}`}>
                      {formatDate(card.expires_at)}
                    </TableCell>
                    <TableCell className="text-muted-foreground hidden pr-4 lg:table-cell">{formatDate(card.created_at)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            <PaginationBar page={data.meta} onPageChange={setPage} />
          </div>
        ) : (
          <EmptyState
            icon={CreditCard}
            title={debounced || status.length ? "No matching cards" : "No gift cards yet"}
            description={
              debounced || status.length ? "Try a different search or clear the filters." : "Create your first gift card and write it to an NFC tag."
            }
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
                  Clear filters
                </Button>
              ) : can("cards.create") ? (
                <Button asChild>
                  <Link href="/cards/new">
                    <Plus /> New gift card
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

export default function CardsPage() {
  return (
    <RequirePermission permission="cards.view">
      <CardsContent />
    </RequirePermission>
  )
}
