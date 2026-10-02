"use client"

import { useState, type ReactNode } from "react"
import { CheckCircle2, Loader2, MoreHorizontal, Package, Plus, Truck } from "lucide-react"
import { toast } from "sonner"
import { BatchStatusBadge, batchStatusLabel } from "@/components/cards/card-state"
import { useConfirm } from "@/components/common/confirm"
import { EmptyState } from "@/components/common/empty-state"
import { PageHeader } from "@/components/common/page-header"
import { QueryError } from "@/components/common/query-error"
import { PaginationBar } from "@/components/common/pagination-bar"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Textarea } from "@/components/ui/textarea"
import { useAdminCardBatches, useAdminRestaurants, useCardBatchAction, useOrderCardBatch } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { CardBatch, CardBatchStatus } from "@/lib/api/types"
import { BATCH_STATUSES, nextStep, SPECIAL_TRANSITIONS, type BatchStep } from "@/lib/card-batch-steps"
import { formatDate, formatNumber } from "@/lib/format"
import { useT } from "@/lib/i18n"

function OrderDialog({ onClose }: { onClose: () => void }) {
  const t = useT()
  const restaurants = useAdminRestaurants("", 1, "active")
  const order = useOrderCardBatch()
  const [restaurant, setRestaurant] = useState("")
  const [quantity, setQuantity] = useState("100")
  const [manufacturer, setManufacturer] = useState("")
  const [design, setDesign] = useState("")

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t("admin.batches.order")}</DialogTitle>
          <DialogDescription>{t("admin.batches.orderDescription")}</DialogDescription>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            try {
              await order.mutateAsync({
                restaurant_id: restaurant,
                quantity: Number(quantity),
                manufacturer: manufacturer.trim() || undefined,
                card_design_ref: design.trim() || undefined,
              })
              toast.success(t("admin.batches.ordered"))
              onClose()
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label>{t("admin.col.restaurant")}</Label>
            <Select value={restaurant} onValueChange={setRestaurant}>
              <SelectTrigger className="w-full" aria-label={t("admin.col.restaurant")}>
                <SelectValue placeholder={t("admin.batches.chooseRestaurant")} />
              </SelectTrigger>
              <SelectContent>
                {(restaurants.data?.data ?? []).map((r) => (
                  <SelectItem key={r.id} value={r.id}>
                    {r.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-2">
              <Label htmlFor="b-qty">{t("admin.batches.quantity")}</Label>
              <Input id="b-qty" inputMode="numeric" value={quantity} onChange={(e) => setQuantity(e.target.value.replace(/\D/g, ""))} required />
            </div>
            <div className="space-y-2">
              <Label htmlFor="b-man">{t("admin.batches.printer")}</Label>
              <Input
                id="b-man"
                value={manufacturer}
                onChange={(e) => setManufacturer(e.target.value)}
                maxLength={120}
                placeholder={t("admin.batches.optional")}
                aria-describedby="b-man-hint"
              />
            </div>
          </div>
          <p id="b-man-hint" className="text-muted-foreground -mt-2 text-xs">
            {t("admin.batches.printerHint")}
          </p>
          <div className="space-y-2">
            <Label htmlFor="b-design">{t("admin.batches.artwork")}</Label>
            <Input
              id="b-design"
              value={design}
              onChange={(e) => setDesign(e.target.value)}
              maxLength={120}
              placeholder={t("admin.batches.optional")}
              aria-describedby="b-design-hint"
            />
            <p id="b-design-hint" className="text-muted-foreground text-xs">
              {t("admin.batches.artworkHint")}
            </p>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={order.isPending || !restaurant || !quantity}>
              {order.isPending ? <Loader2 className="animate-spin" /> : null} {t("admin.batches.orderSubmit")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

/** The exceptions (stop, lost, leaked keys, close …), with a reason. The main steps have their own buttons. */
function SpecialStatusDialog({ batch, onClose }: { batch: CardBatch; onClose: () => void }) {
  const t = useT()
  const action = useCardBatchAction()
  const options = SPECIAL_TRANSITIONS[batch.status] ?? []
  const [status, setStatus] = useState<CardBatchStatus | "">(options[0] ?? "")
  const [reason, setReason] = useState("")

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>
            {batch.batch_code} · {batch.restaurant?.name}
          </DialogTitle>
          <DialogDescription>{t("admin.batches.moreDescription")}</DialogDescription>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            if (!status) return
            try {
              await action.mutateAsync({ id: batch.id, kind: "status", status, reason: reason.trim() })
              toast.success(`${batch.batch_code}: ${batchStatusLabel(status)}`)
              onClose()
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label>{t("admin.batches.nextStatus")}</Label>
            <Select value={status} onValueChange={(v) => setStatus(v as CardBatchStatus)}>
              <SelectTrigger className="w-full" aria-label={t("admin.batches.nextStatus")}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {options.map((o) => (
                  <SelectItem key={o} value={o}>
                    {batchStatusLabel(o)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {status === "compromised" ? <p className="text-destructive text-xs">{t("admin.batches.compromisedWarning")}</p> : null}
          </div>
          <div className="space-y-2">
            <Label htmlFor="b-reason">{t("admin.batches.reason")}</Label>
            <Input id="b-reason" value={reason} onChange={(e) => setReason(e.target.value)} maxLength={120} required />
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t("common.cancel")}
            </Button>
            <Button
              type="submit"
              variant={status === "compromised" || status === "rejected" || status === "lost" ? "destructive" : "default"}
              disabled={action.isPending || !status || reason.trim().length < 3}
            >
              {action.isPending ? <Loader2 className="animate-spin" /> : null} {t("common.save")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function ShipDialog({ batch, onClose }: { batch: CardBatch; onClose: () => void }) {
  const t = useT()
  const action = useCardBatchAction()
  const [tracking, setTracking] = useState(batch.tracking_ref ?? "")

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t("admin.batches.shipTitle", { code: batch.batch_code })}</DialogTitle>
          <DialogDescription>
            {t("admin.batches.shipDescription", { count: batch.counts.central_stock, restaurant: batch.restaurant?.name ?? "" })}
          </DialogDescription>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            try {
              await action.mutateAsync({ id: batch.id, kind: "shipment", tracking_ref: tracking.trim() || undefined })
              toast.success(t("admin.batches.shipped", { code: batch.batch_code }))
              onClose()
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="b-track">{t("admin.batches.tracking")}</Label>
            <Input id="b-track" value={tracking} onChange={(e) => setTracking(e.target.value)} maxLength={120} placeholder={t("admin.batches.optional")} />
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={action.isPending}>
              {action.isPending ? <Loader2 className="animate-spin" /> : <Truck />} {t("admin.batches.ship")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function HoldDialog({ batch, onClose }: { batch: CardBatch; onClose: () => void }) {
  const t = useT()
  const action = useCardBatchAction()
  const [missing, setMissing] = useState("")
  const numbers = missing
    .split(/[\s,;]+/)
    .map((n) => n.trim().toUpperCase())
    .filter(Boolean)
  const report = batch.qa_report?.receipt as { counted?: number; expected?: number } | undefined

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t("admin.batches.resolveTitle", { code: batch.batch_code })}</DialogTitle>
          <DialogDescription>{t("admin.batches.resolveDescription", { counted: report?.counted ?? "?", expected: report?.expected ?? "?" })}</DialogDescription>
        </DialogHeader>
        <Textarea value={missing} onChange={(e) => setMissing(e.target.value)} placeholder="B-2026-0001-0042, B-2026-0001-0043" rows={4} />
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t("common.cancel")}
          </Button>
          <Button
            disabled={action.isPending}
            onClick={async () => {
              try {
                await action.mutateAsync({ id: batch.id, kind: "hold-resolution", missing: numbers })
                toast.success(t("admin.batches.inService", { code: batch.batch_code }))
                onClose()
              } catch (err) {
                toast.error(errorMessage(err))
              }
            }}
          >
            {action.isPending ? <Loader2 className="animate-spin" /> : null} {t("admin.batches.resolveSubmit", { count: numbers.length })}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function StepHint({ children }: { children: ReactNode }) {
  return <p className="text-muted-foreground max-w-56 text-xs">{children}</p>
}

function Content() {
  const t = useT()
  const confirm = useConfirm()
  const [page, setPage] = useState(1)
  const [status, setStatus] = useState<CardBatchStatus | "all">("all")
  const { data, isLoading, error, refetch } = useAdminCardBatches(page, status === "all" ? undefined : status)
  const action = useCardBatchAction()
  const [ordering, setOrdering] = useState(false)
  const [changing, setChanging] = useState<CardBatch | null>(null)
  const [shipping, setShipping] = useState<CardBatch | null>(null)
  const [resolving, setResolving] = useState<CardBatch | null>(null)

  const release = async (b: CardBatch, step: Extract<BatchStep, { kind: "release" }>) => {
    const ok = await confirm({
      title: t("admin.batches.releaseTitle", { code: b.batch_code }),
      description: t("admin.batches.releaseDescription", { ready: step.ready, ordered: b.quantity_ordered, unfinished: step.unfinished }),
      confirmLabel: t("admin.batches.release"),
    })
    if (!ok) return
    try {
      await action.mutateAsync({ id: b.id, kind: "release" })
      toast.success(t("admin.batches.released", { code: b.batch_code }))
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  /** The one main button of a row and the line under it that says what happens next. */
  const stepCell = (b: CardBatch) => {
    const step = nextStep(b)
    switch (step.kind) {
      case "release":
        return (
          <>
            <Button size="sm" onClick={() => void release(b, step)} disabled={action.isPending || step.ready === 0}>
              <CheckCircle2 /> {t("admin.batches.release")}
            </Button>
            <StepHint>
              {step.ready === 0 ? t("admin.batches.releaseBlocked") : t("admin.batches.releaseHint", { ready: step.ready, ordered: b.quantity_ordered })}
            </StepHint>
          </>
        )
      case "ship":
        return (
          <>
            <Button size="sm" onClick={() => setShipping(b)}>
              <Truck /> {t("admin.batches.ship")}
            </Button>
            <StepHint>{t("admin.batches.shipHint")}</StepHint>
          </>
        )
      case "awaiting-receipt":
        return <StepHint>{t("admin.batches.awaitingReceipt")}</StepHint>
      case "on-hold":
        return (
          <>
            <Button size="sm" variant="outline" onClick={() => setResolving(b)}>
              {t("admin.batches.resolve")}
            </Button>
            <StepHint>{t("admin.batches.holdHint")}</StepHint>
          </>
        )
      default:
        return null
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("nav.cardBatches")}
        description={t("admin.batches.description")}
        actions={
          <Button onClick={() => setOrdering(true)}>
            <Plus /> {t("admin.batches.order")}
          </Button>
        }
      />
      <div className="bg-card overflow-hidden rounded-2xl border">
        <div className="flex items-center gap-3 border-b p-3">
          <Select value={status} onValueChange={(v) => (setStatus(v as CardBatchStatus | "all"), setPage(1))}>
            <SelectTrigger className="w-48" aria-label={t("admin.batches.filterStatus")}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">{t("admin.batches.allStatuses")}</SelectItem>
              {BATCH_STATUSES.map((s) => (
                <SelectItem key={s} value={s}>
                  {batchStatusLabel(s)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
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
                  <TableHead>{t("admin.batches.colBatch")}</TableHead>
                  <TableHead>{t("admin.col.restaurant")}</TableHead>
                  <TableHead>{t("admin.col.status")}</TableHead>
                  <TableHead className="text-right">{t("admin.batches.colOrdered")}</TableHead>
                  <TableHead className="text-right">{t("admin.batches.colPersonalised")}</TableHead>
                  <TableHead className="text-right">{t("admin.batches.colQaFailed")}</TableHead>
                  <TableHead className="hidden lg:table-cell">{t("admin.batches.colOrderedOn")}</TableHead>
                  <TableHead>{t("admin.batches.colNextStep")}</TableHead>
                  <TableHead />
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.data.map((b) => (
                  <TableRow key={b.id}>
                    <TableCell className="font-mono">{b.batch_code}</TableCell>
                    <TableCell>{b.restaurant?.name}</TableCell>
                    <TableCell>
                      <BatchStatusBadge status={b.status} />
                    </TableCell>
                    <TableCell className="text-right tabular-nums">{formatNumber(b.quantity_ordered)}</TableCell>
                    <TableCell className="text-right tabular-nums">{formatNumber(b.counts.registered - b.counts.qa_failed - b.counts.in_production)}</TableCell>
                    <TableCell className="text-right tabular-nums">{formatNumber(b.counts.qa_failed)}</TableCell>
                    <TableCell className="hidden lg:table-cell">{formatDate(b.ordered_at)}</TableCell>
                    <TableCell>
                      <div className="flex max-w-60 flex-col items-start gap-1 whitespace-normal">{stepCell(b)}</div>
                    </TableCell>
                    <TableCell className="text-right">
                      {SPECIAL_TRANSITIONS[b.status]?.length ? (
                        <Button
                          size="icon-sm"
                          variant="ghost"
                          onClick={() => setChanging(b)}
                          aria-label={`${t("admin.batches.more")}: ${b.batch_code}`}
                          title={t("admin.batches.more")}
                        >
                          <MoreHorizontal />
                        </Button>
                      ) : null}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            <PaginationBar page={data.meta} onPageChange={setPage} />
          </>
        ) : (
          <EmptyState icon={Package} title={t("admin.batches.empty")} description={t("admin.batches.emptyHint")} />
        )}
      </div>
      {ordering ? <OrderDialog onClose={() => setOrdering(false)} /> : null}
      {changing ? <SpecialStatusDialog batch={changing} onClose={() => setChanging(null)} /> : null}
      {shipping ? <ShipDialog batch={shipping} onClose={() => setShipping(null)} /> : null}
      {resolving ? <HoldDialog batch={resolving} onClose={() => setResolving(null)} /> : null}
    </div>
  )
}

export default function CardBatchesPage() {
  return (
    <RequirePermission permission="platform.cards.manage">
      <Content />
    </RequirePermission>
  )
}
