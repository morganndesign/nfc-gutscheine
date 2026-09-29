"use client"

import { useState } from "react"
import { CheckCircle2, Loader2, Package, Plus } from "lucide-react"
import { toast } from "sonner"
import { BatchStatusBadge, batchStatusLabel } from "@/components/cards/card-state"
import { EmptyState } from "@/components/common/empty-state"
import { PageHeader } from "@/components/common/page-header"
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
import { formatDate, formatNumber } from "@/lib/format"

/** The next steps the platform takes for a batch (the server checks every transition). */
const NEXT: Partial<Record<CardBatchStatus, CardBatchStatus[]>> = {
  ordered: ["in_production"],
  in_production: ["personalized"],
  personalized: ["qa_testing"],
  qa_testing: ["rejected"],
  accepted: ["assigned", "compromised"],
  assigned: ["shipped", "compromised"],
  shipped: ["delivered", "lost", "compromised"],
  delivered: ["compromised"],
  on_hold: ["compromised"],
  in_service: ["depleted", "compromised"],
  depleted: ["in_service", "closed", "compromised"],
  compromised: ["closed"],
  rejected: ["closed"],
  lost: ["closed"],
}

function OrderDialog({ onClose }: { onClose: () => void }) {
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
          <DialogTitle>Order cards</DialogTitle>
          <DialogDescription>Cards are printed with the restaurant&apos;s branding only and personalised at the in-house station.</DialogDescription>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            try {
              await order.mutateAsync({ restaurant_id: restaurant, quantity: Number(quantity), manufacturer: manufacturer.trim(), card_design_ref: design.trim() || undefined })
              toast.success("Batch ordered")
              onClose()
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label>Restaurant</Label>
            <Select value={restaurant} onValueChange={setRestaurant}>
              <SelectTrigger className="w-full" aria-label="Restaurant">
                <SelectValue placeholder="Choose a restaurant" />
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
              <Label htmlFor="b-qty">Quantity</Label>
              <Input id="b-qty" inputMode="numeric" value={quantity} onChange={(e) => setQuantity(e.target.value.replace(/\D/g, ""))} required />
            </div>
            <div className="space-y-2">
              <Label htmlFor="b-man">Printer</Label>
              <Input id="b-man" value={manufacturer} onChange={(e) => setManufacturer(e.target.value)} maxLength={120} required />
            </div>
          </div>
          <div className="space-y-2">
            <Label htmlFor="b-design">Artwork reference</Label>
            <Input id="b-design" value={design} onChange={(e) => setDesign(e.target.value)} maxLength={120} placeholder="optional" />
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" disabled={order.isPending || !restaurant || !quantity || manufacturer.trim().length < 2}>
              {order.isPending ? <Loader2 className="animate-spin" /> : null} Order
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function StatusDialog({ batch, onClose }: { batch: CardBatch; onClose: () => void }) {
  const action = useCardBatchAction()
  const options = NEXT[batch.status] ?? []
  const [status, setStatus] = useState<CardBatchStatus | "">(options[0] ?? "")
  const [reason, setReason] = useState("")
  const [tracking, setTracking] = useState(batch.tracking_ref ?? "")

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{batch.batch_code}</DialogTitle>
          <DialogDescription>{batch.restaurant?.name}</DialogDescription>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            if (!status) return
            try {
              await action.mutateAsync({ id: batch.id, kind: "status", status, reason: reason.trim(), tracking_ref: tracking.trim() || undefined })
              toast.success(`${batch.batch_code}: ${batchStatusLabel(status)}`)
              onClose()
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label>Next status</Label>
            <Select value={status} onValueChange={(v) => setStatus(v as CardBatchStatus)}>
              <SelectTrigger className="w-full" aria-label="Next status">
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
            {status === "compromised" ? <p className="text-destructive text-xs">Every card of this batch not yet with a guest is revoked for good.</p> : null}
          </div>
          {status === "shipped" ? (
            <div className="space-y-2">
              <Label htmlFor="b-track">Tracking number</Label>
              <Input id="b-track" value={tracking} onChange={(e) => setTracking(e.target.value)} maxLength={120} />
            </div>
          ) : null}
          <div className="space-y-2">
            <Label htmlFor="b-reason">Reason</Label>
            <Input id="b-reason" value={reason} onChange={(e) => setReason(e.target.value)} maxLength={120} required />
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" variant={status === "compromised" ? "destructive" : "default"} disabled={action.isPending || !status || reason.trim().length < 3}>
              {action.isPending ? <Loader2 className="animate-spin" /> : null} Save
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function HoldDialog({ batch, onClose }: { batch: CardBatch; onClose: () => void }) {
  const action = useCardBatchAction()
  const [missing, setMissing] = useState("")
  const numbers = missing.split(/[\s,;]+/).map((n) => n.trim().toUpperCase()).filter(Boolean)
  const report = batch.qa_report?.receipt as { counted?: number; expected?: number } | undefined

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Resolve {batch.batch_code}</DialogTitle>
          <DialogDescription>
            The restaurant counted {report?.counted ?? "?"} of {report?.expected ?? "?"} cards. List the cards that are really missing; they become lost, every other
            delivered card becomes available.
          </DialogDescription>
        </DialogHeader>
        <Textarea value={missing} onChange={(e) => setMissing(e.target.value)} placeholder="B-2026-0001-0042, B-2026-0001-0043" rows={4} />
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button
            disabled={action.isPending}
            onClick={async () => {
              try {
                await action.mutateAsync({ id: batch.id, kind: "hold-resolution", missing: numbers })
                toast.success(`${batch.batch_code} is in service`)
                onClose()
              } catch (err) {
                toast.error(errorMessage(err))
              }
            }}
          >
            {action.isPending ? <Loader2 className="animate-spin" /> : null} Resolve ({numbers.length} missing)
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function Content() {
  const [page, setPage] = useState(1)
  const [status, setStatus] = useState<CardBatchStatus | "all">("all")
  const { data, isLoading } = useAdminCardBatches(page, status === "all" ? undefined : status)
  const action = useCardBatchAction()
  const [ordering, setOrdering] = useState(false)
  const [changing, setChanging] = useState<CardBatch | null>(null)
  const [resolving, setResolving] = useState<CardBatch | null>(null)

  const approve = async (b: CardBatch) => {
    try {
      const res = await action.mutateAsync({ id: b.id, kind: "approval" })
      toast.success(res.data.status === "accepted" ? `${b.batch_code} accepted` : "First approval recorded; a second person must approve")
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Card batches"
        description="Order, personalise at the station, accept (two people), ship. The restaurant confirms the delivery in the waiter app."
        actions={
          <Button onClick={() => setOrdering(true)}>
            <Plus /> Order cards
          </Button>
        }
      />
      <div className="bg-card overflow-hidden rounded-2xl border">
        <div className="flex items-center gap-3 border-b p-3">
          <Select value={status} onValueChange={(v) => (setStatus(v as CardBatchStatus | "all"), setPage(1))}>
            <SelectTrigger className="w-48" aria-label="Filter by status">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All statuses</SelectItem>
              {(Object.keys(NEXT) as CardBatchStatus[]).concat(["closed"]).map((s) => (
                <SelectItem key={s} value={s}>
                  {batchStatusLabel(s)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        {isLoading ? (
          <Skeleton className="m-4 h-64" />
        ) : data?.data.length ? (
          <>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Batch</TableHead>
                  <TableHead>Restaurant</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Ordered</TableHead>
                  <TableHead className="text-right">Personalised</TableHead>
                  <TableHead className="text-right">QA failed</TableHead>
                  <TableHead className="hidden lg:table-cell">Ordered on</TableHead>
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
                    <TableCell className="text-right whitespace-nowrap">
                      {b.status === "qa_testing" ? (
                        <Button size="sm" variant="outline" onClick={() => void approve(b)} disabled={action.isPending}>
                          <CheckCircle2 /> Approve {b.approvals?.length ? "(2nd)" : ""}
                        </Button>
                      ) : null}
                      {b.status === "on_hold" ? (
                        <Button size="sm" variant="outline" onClick={() => setResolving(b)}>
                          Resolve
                        </Button>
                      ) : null}
                      {NEXT[b.status]?.length ? (
                        <Button size="sm" variant="ghost" onClick={() => setChanging(b)}>
                          Status…
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
          <EmptyState icon={Package} title="No card batches" description="Order the first batch for a restaurant." />
        )}
      </div>
      {ordering ? <OrderDialog onClose={() => setOrdering(false)} /> : null}
      {changing ? <StatusDialog batch={changing} onClose={() => setChanging(null)} /> : null}
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
