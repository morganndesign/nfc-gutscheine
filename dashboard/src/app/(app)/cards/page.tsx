"use client"

import { Suspense, useState } from "react"
import Link from "next/link"
import { useSearchParams } from "next/navigation"
import { Ban, CreditCard, Pause, Play, Search } from "lucide-react"
import { toast } from "sonner"
import { BatchStatusBadge, CardStateBadge, cardStateLabel } from "@/components/cards/card-state"
import { EmptyState } from "@/components/common/empty-state"
import { PageHeader } from "@/components/common/page-header"
import { PaginationBar } from "@/components/common/pagination-bar"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { Segmented } from "@/components/common/segmented"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useDebounce } from "@/hooks/use-debounce"
import { useCard, useCardAction, useCardBatches, useCards } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { Card, CardState } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { formatDateTime, formatNumber } from "@/lib/format"
import { formatMoney } from "@/lib/money"

type Filter = "all" | "active" | "suspended" | "stock"

const FILTERS: Record<Filter, CardState[] | undefined> = {
  all: undefined,
  active: ["active"],
  suspended: ["suspended"],
  stock: ["available", "delivered"],
}

type Action = { card: Card; action: "suspend" | "resume" | "revoke" }

function CardDetail({ number, onClose, onAction }: { number: string; onClose: () => void; onAction: (a: Action) => void }) {
  const { can } = useAuth()
  const { data: card, isLoading } = useCard(number)

  return (
    <Sheet open onOpenChange={(o) => !o && onClose()}>
      <SheetContent className="w-full overflow-y-auto sm:max-w-md">
        <SheetHeader>
          <SheetTitle className="font-mono">{number}</SheetTitle>
          <SheetDescription>{card ? cardStateLabel(card.state) : "Loading…"}</SheetDescription>
        </SheetHeader>
        {isLoading || !card ? (
          <Skeleton className="m-4 h-40" />
        ) : (
          <div className="space-y-6 px-4 pb-6">
            {card.voucher ? (
              <div className="bg-muted/40 rounded-xl border p-3">
                <p className="text-muted-foreground text-xs">Voucher</p>
                <Link href={`/vouchers/${card.voucher.id}`} className="font-mono text-sm underline-offset-4 hover:underline">
                  {card.voucher.voucher_number}
                </Link>
                <p className="text-lg font-semibold tabular-nums">{formatMoney(card.voucher.balance, card.voucher.currency)}</p>
              </div>
            ) : null}
            {card.successor ? <p className="text-sm">Replaced by <span className="font-mono">{card.successor}</span>.</p> : null}
            {can("cards.manage") ? (
              <div className="flex flex-wrap gap-2">
                {card.state === "active" ? (
                  <Button variant="outline" className="text-destructive" onClick={() => onAction({ card, action: "suspend" })}>
                    <Pause /> Suspend
                  </Button>
                ) : null}
                {card.state === "suspended" ? (
                  <Button variant="outline" onClick={() => onAction({ card, action: "resume" })}>
                    <Play /> Resume
                  </Button>
                ) : null}
                {card.state === "available" || card.state === "delivered" ? (
                  <Button variant="outline" className="text-destructive" onClick={() => onAction({ card, action: "revoke" })}>
                    <Ban /> Take out of service
                  </Button>
                ) : null}
              </div>
            ) : null}
            {card.state === "active" || card.state === "suspended" ? (
              <p className="text-muted-foreground text-xs">
                To replace a lost or damaged card, open the waiter app → Menu → Find a card, and hold a new card from stock to the phone. The balance moves to
                the new card.
              </p>
            ) : null}
            <div>
              <h3 className="mb-2 text-sm font-medium">History</h3>
              <ol className="space-y-2">
                {(card.history ?? []).map((h, i) => (
                  <li key={i} className="flex items-start justify-between gap-3 text-sm">
                    <span>
                      {cardStateLabel(h.to_state)}
                      <span className="text-muted-foreground block text-xs">{h.reason}</span>
                    </span>
                    <span className="text-muted-foreground shrink-0 text-xs">{formatDateTime(h.at)}</span>
                  </li>
                ))}
              </ol>
            </div>
          </div>
        )}
      </SheetContent>
    </Sheet>
  )
}

function Batches() {
  const { data } = useCardBatches()
  if (!data?.length) return null
  return (
    <div className="bg-card overflow-hidden rounded-2xl border">
      <div className="border-b px-4 py-3">
        <h2 className="text-sm font-medium">Deliveries</h2>
        <p className="text-muted-foreground text-xs">Confirm a delivery in the waiter app: Menu → Confirm a delivery.</p>
      </div>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Batch</TableHead>
            <TableHead>Status</TableHead>
            <TableHead className="text-right">Ordered</TableHead>
            <TableHead className="text-right">In stock</TableHead>
            <TableHead className="text-right">Sold</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.map((b) => (
            <TableRow key={b.id}>
              <TableCell className="font-mono">{b.batch_code}</TableCell>
              <TableCell>
                <BatchStatusBadge status={b.status} />
              </TableCell>
              <TableCell className="text-right tabular-nums">{formatNumber(b.quantity_ordered)}</TableCell>
              <TableCell className="text-right tabular-nums">{formatNumber(b.counts.available)}</TableCell>
              <TableCell className="text-right tabular-nums">{formatNumber(b.counts.activated)}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  )
}

function CardsContent() {
  const params = useSearchParams()
  const [filter, setFilter] = useState<Filter>("all")
  const [search, setSearch] = useState(params.get("search") ?? "")
  const [page, setPage] = useState(1)
  const [open, setOpen] = useState<string | null>(null)
  const [acting, setActing] = useState<Action | null>(null)
  const { data, isLoading } = useCards(page, { state: FILTERS[filter], search: useDebounce(search.trim()) })
  const action = useCardAction()

  const run = async (reason: string) => {
    if (!acting) return
    try {
      await action.mutateAsync({ number: acting.card.card_number, action: acting.action, reason })
      toast.success(acting.action === "suspend" ? "Card suspended" : acting.action === "resume" ? "Card resumed" : "Card taken out of service")
      setActing(null)
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title="Cards" description="Physical gift cards: your stock and your guests' cards. Suspend a lost card at once; it no longer pays." />
      <Batches />
      <div className="bg-card overflow-hidden rounded-2xl border">
        <div className="flex flex-col gap-3 border-b p-3 sm:flex-row sm:items-center">
          <div className="relative flex-1">
            <Search className="text-muted-foreground absolute top-1/2 left-3 size-4 -translate-y-1/2" />
            <Input value={search} onChange={(e) => (setSearch(e.target.value), setPage(1))} placeholder="Card number, e.g. 0042" className="h-9 pl-9" aria-label="Search cards" />
          </div>
          <Segmented
            label="Card filter"
            value={filter}
            onChange={(f) => (setFilter(f), setPage(1))}
            options={[
              { value: "all", label: "All" },
              { value: "active", label: "Active" },
              { value: "suspended", label: "Suspended" },
              { value: "stock", label: "In stock" },
            ]}
          />
        </div>
        {isLoading ? (
          <Skeleton className="m-4 h-64" />
        ) : data?.data.length ? (
          <>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Card</TableHead>
                  <TableHead>State</TableHead>
                  <TableHead className="hidden sm:table-cell">Batch</TableHead>
                  <TableHead className="text-right">Balance</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.data.map((c) => (
                  <TableRow key={c.card_number} className="cursor-pointer" onClick={() => setOpen(c.card_number)}>
                    <TableCell className="font-mono">{c.card_number}</TableCell>
                    <TableCell>
                      <CardStateBadge state={c.state} />
                    </TableCell>
                    <TableCell className="hidden font-mono sm:table-cell">{c.batch_code}</TableCell>
                    <TableCell className="text-right tabular-nums">{c.voucher ? formatMoney(c.voucher.balance, c.voucher.currency) : "—"}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            <PaginationBar page={data.meta} onPageChange={setPage} />
          </>
        ) : (
          <EmptyState icon={CreditCard} title="No cards" description={search || filter !== "all" ? "Nothing matches the filter." : "Cards appear here once a delivery is confirmed."} />
        )}
      </div>
      {open ? <CardDetail number={open} onClose={() => setOpen(null)} onAction={setActing} /> : null}
      <ReasonDialog
        open={acting !== null}
        onOpenChange={(o) => !o && setActing(null)}
        title={acting?.action === "suspend" ? `Suspend ${acting.card.card_number}?` : acting?.action === "resume" ? `Resume ${acting?.card.card_number}?` : `Take ${acting?.card.card_number ?? "card"} out of service?`}
        description={
          acting?.action === "suspend"
            ? "The card stops paying immediately, also for a tap made a moment ago. The balance stays with the voucher."
            : acting?.action === "revoke"
              ? "The card can never be sold. Use this for damaged or missing stock cards."
              : "The card pays again."
        }
        confirmLabel={acting?.action === "suspend" ? "Suspend card" : acting?.action === "resume" ? "Resume card" : "Take out of service"}
        destructive={acting?.action !== "resume"}
        suggestions={acting?.action === "resume" ? ["Found again"] : ["Lost", "Stolen", "Damaged"]}
        pending={action.isPending}
        onConfirm={(reason) => void run(reason)}
      />
    </div>
  )
}

export default function CardsPage() {
  return (
    <RequirePermission permission="cards.view">
      <Suspense>
        <CardsContent />
      </Suspense>
    </RequirePermission>
  )
}
