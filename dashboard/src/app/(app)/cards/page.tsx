"use client"

import { Suspense, useState } from "react"
import Link from "next/link"
import { useSearchParams } from "next/navigation"
import { Ban, CreditCard, Pause, RotateCcw, Search } from "lucide-react"
import { toast } from "sonner"
import { BatchStatusBadge, CardStateBadge, cardStateLabel } from "@/components/cards/card-state"
import { CardOrders, OrderCardsButton } from "@/components/cards/card-orders"
import { useConfirm } from "@/components/common/confirm"
import { EmptyState } from "@/components/common/empty-state"
import { QueryError } from "@/components/common/query-error"
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
import { useCard, useCardAction, useCardBatches, useCards, useResetTestCard } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { Card, CardState } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { formatDateTime, formatNumber } from "@/lib/format"
import { formatMoney } from "@/lib/money"
import { useT } from "@/lib/i18n"

type Filter = "all" | "active" | "suspended" | "stock"

const FILTERS: Record<Filter, CardState[] | undefined> = {
  all: undefined,
  active: ["active"],
  suspended: ["suspended"],
  stock: ["available", "delivered"],
}

type Action = { card: Card; action: "suspend" | "revoke" }

/** Cards a test restaurant can put back into stock (decision 2026-10-05). */
const TEST_RESETTABLE = ["bound", "active", "suspended", "replaced", "revoked", "lost"]

function CardDetail({ number, onClose, onAction }: { number: string; onClose: () => void; onAction: (a: Action) => void }) {
  const { can, user } = useAuth()
  const confirm = useConfirm()
  const reset = useResetTestCard()
  const { data: card, isLoading, error } = useCard(number)
  const t = useT()

  return (
    <Sheet open onOpenChange={(o) => !o && onClose()}>
      <SheetContent className="w-full overflow-y-auto sm:max-w-md">
        <SheetHeader>
          <SheetTitle className="font-mono">{number}</SheetTitle>
          <SheetDescription>{card ? cardStateLabel(card.state) : t("common.loading")}</SheetDescription>
        </SheetHeader>
        {error && !card ? (
          <QueryError error={error} />
        ) : isLoading || !card ? (
          <Skeleton className="m-4 h-40" />
        ) : (
          <div className="space-y-6 px-4 pb-6">
            {card.voucher ? (
              <div className="bg-muted/40 rounded-xl border p-3">
                <p className="text-muted-foreground text-xs">{t("ops.col.voucher")}</p>
                <Link href={`/vouchers/${card.voucher.id}`} className="font-mono text-sm underline-offset-4 hover:underline">
                  {card.voucher.voucher_number}
                </Link>
                <p className="text-lg font-semibold tabular-nums">{formatMoney(card.voucher.balance, card.voucher.currency)}</p>
              </div>
            ) : null}
            {card.successor ? (
              <p className="text-sm">
                {t("cards.replacedBy")} <span className="font-mono">{card.successor}</span>.
              </p>
            ) : null}
            {can("cards.manage") ? (
              <div className="flex flex-wrap gap-2">
                {card.state === "active" ? (
                  <Button variant="outline" className="text-destructive" onClick={() => onAction({ card, action: "suspend" })}>
                    <Pause /> {t("cards.suspend")}
                  </Button>
                ) : null}
                {card.state === "suspended" ? (
                  // Resumed only with the card itself at the till, in the app (decision 2026-10-06); a card with
                  // compromised keys is replaced, never resumed (audit K6).
                  <p className="text-muted-foreground text-sm">{t(card.resumable === false ? "cards.resumeCompromised" : "cards.resumeInApp")}</p>
                ) : null}
                {card.state === "available" || card.state === "delivered" ? (
                  <Button variant="outline" className="text-destructive" onClick={() => onAction({ card, action: "revoke" })}>
                    <Ban /> {t("cards.revoke")}
                  </Button>
                ) : null}
                {user?.restaurant?.is_test && TEST_RESETTABLE.includes(card.state) ? (
                  <Button
                    variant="outline"
                    disabled={reset.isPending}
                    onClick={async () => {
                      const ok = await confirm({
                        title: t("cards.testReset.title", { number: card.card_number }),
                        description: t("cards.testReset.description"),
                        confirmLabel: t("cards.testReset.confirm"),
                      })
                      if (!ok) return
                      try {
                        await reset.mutateAsync(card.card_number)
                        toast.success(t("cards.testReset.done", { number: card.card_number }))
                      } catch (e) {
                        toast.error(errorMessage(e))
                      }
                    }}
                  >
                    <RotateCcw /> {t("cards.testReset.action")}
                  </Button>
                ) : null}
              </div>
            ) : null}
            {card.state === "active" || card.state === "suspended" ? <p className="text-muted-foreground text-xs">{t("cards.replaceHint")}</p> : null}
            <div>
              <h3 className="mb-2 text-sm font-medium">{t("cards.history")}</h3>
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
  const t = useT()
  if (!data?.length) return null
  return (
    <div className="bg-card overflow-hidden rounded-2xl border">
      <div className="border-b px-4 py-3">
        <h2 className="text-sm font-medium">{t("cards.deliveries")}</h2>
        <p className="text-muted-foreground text-xs">{t("cards.deliveriesHint")}</p>
      </div>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>{t("cards.col.batch")}</TableHead>
            <TableHead>{t("ops.col.status")}</TableHead>
            <TableHead className="text-right">{t("cards.col.ordered")}</TableHead>
            <TableHead className="text-right">{t("cards.col.inStock")}</TableHead>
            <TableHead className="text-right">{t("cards.col.sold")}</TableHead>
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
  const { data, isLoading, error, refetch } = useCards(page, { state: FILTERS[filter], search: useDebounce(search.trim()) })
  const action = useCardAction()
  const { can } = useAuth()
  const t = useT()

  const run = async (reason: string) => {
    if (!acting) return
    try {
      await action.mutateAsync({ number: acting.card.card_number, action: acting.action, reason })
      toast.success(t(acting.action === "suspend" ? "cards.toast.suspended" : "cards.toast.revoked"))
      setActing(null)
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("nav.cards")} description={t("cards.description")} actions={can("cards.receive") ? <OrderCardsButton /> : null} />
      <CardOrders />
      <Batches />
      <div className="bg-card overflow-hidden rounded-2xl border">
        <div className="flex flex-col gap-3 border-b p-3 sm:flex-row sm:items-center">
          <div className="relative flex-1">
            <Search className="text-muted-foreground absolute top-1/2 left-3 size-4 -translate-y-1/2" />
            <Input
              value={search}
              onChange={(e) => (setSearch(e.target.value), setPage(1))}
              placeholder={t("cards.searchPlaceholder")}
              className="h-9 pl-9"
              aria-label={t("cards.searchLabel")}
            />
          </div>
          <Segmented
            label={t("cards.filterLabel")}
            value={filter}
            onChange={(f) => (setFilter(f), setPage(1))}
            options={[
              { value: "all", label: t("cards.filter.all") },
              { value: "active", label: t("cards.filter.active") },
              { value: "suspended", label: t("cards.filter.suspended") },
              { value: "stock", label: t("cards.filter.stock") },
            ]}
          />
        </div>
        {isLoading ? (
          <Skeleton className="m-4 h-64" />
        ) : error && !data ? (
          <QueryError error={error} onRetry={() => void refetch()} />
        ) : data?.data.length ? (
          <>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("cards.col.card")}</TableHead>
                  <TableHead>{t("cards.col.state")}</TableHead>
                  <TableHead className="hidden sm:table-cell">{t("cards.col.batch")}</TableHead>
                  <TableHead className="text-right">{t("ops.col.balance")}</TableHead>
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
          <EmptyState
            icon={CreditCard}
            title={t("cards.emptyTitle")}
            description={search || filter !== "all" ? t("cards.emptyFiltered") : t("cards.emptyDescription")}
          />
        )}
      </div>
      {open ? <CardDetail number={open} onClose={() => setOpen(null)} onAction={setActing} /> : null}
      <ReasonDialog
        open={acting !== null}
        onOpenChange={(o) => !o && setActing(null)}
        title={t(
          acting?.action === "suspend" ? "cards.dialog.suspendTitle" : "cards.dialog.revokeTitle",
          { number: acting?.card.card_number ?? "" },
        )}
        description={t(acting?.action === "suspend" ? "cards.dialog.suspendDescription" : "cards.dialog.revokeDescription")}
        confirmLabel={t(acting?.action === "suspend" ? "cards.dialog.suspendConfirm" : "cards.revoke")}
        destructive
        suggestions={[t("cards.reason.lost"), t("cards.reason.stolen"), t("cards.reason.damaged")]}
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
