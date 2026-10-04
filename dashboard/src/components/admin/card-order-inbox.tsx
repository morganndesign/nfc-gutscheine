"use client"

import { useState } from "react"
import { Check, Loader2, X } from "lucide-react"
import { toast } from "sonner"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { useAdminCardOrders, useDecideCardOrder } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { CardOrder } from "@/lib/api/types"
import { formatDateTime, formatNumber } from "@/lib/format"
import { useT } from "@/lib/i18n"

/** Accepting orders the batch: the quantity can be changed (as agreed with the restaurant), the printer is optional. */
function AcceptDialog({ order, onClose }: { order: CardOrder; onClose: () => void }) {
  const t = useT()
  const decide = useDecideCardOrder()
  const [quantity, setQuantity] = useState(String(order.quantity))
  const [manufacturer, setManufacturer] = useState("")
  const amount = Number(quantity)

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>
            {t("admin.orders.acceptTitle")} · {order.restaurant?.name}
          </DialogTitle>
          <DialogDescription>{t("admin.orders.acceptDescription")}</DialogDescription>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            try {
              const done = await decide.mutateAsync({
                id: order.id,
                kind: "accept",
                quantity: amount !== order.quantity ? amount : undefined,
                manufacturer: manufacturer.trim() || undefined,
              })
              toast.success(t("admin.orders.accepted", { batch: done.data.batch_code ?? "" }))
              onClose()
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-2">
              <Label htmlFor="ao-qty">{t("admin.batches.quantity")}</Label>
              <Input id="ao-qty" inputMode="numeric" value={quantity} onChange={(e) => setQuantity(e.target.value.replace(/\D/g, ""))} required />
            </div>
            <div className="space-y-2">
              <Label htmlFor="ao-man">{t("admin.batches.printer")}</Label>
              <Input
                id="ao-man"
                value={manufacturer}
                onChange={(e) => setManufacturer(e.target.value)}
                maxLength={120}
                placeholder={t("admin.batches.optional")}
              />
            </div>
          </div>
          {order.note ? <p className="bg-muted/50 rounded-lg p-3 text-sm">{order.note}</p> : null}
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={decide.isPending || !(amount >= 1)}>
              {decide.isPending ? <Loader2 className="animate-spin" /> : null} {t("admin.orders.acceptSubmit")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

/** Open card orders of the restaurants, on top of the batches; hidden when there are none. */
export function CardOrderInbox() {
  const t = useT()
  const { data } = useAdminCardOrders()
  const decide = useDecideCardOrder()
  const [accepting, setAccepting] = useState<CardOrder | null>(null)
  const [declining, setDeclining] = useState<CardOrder | null>(null)
  const open = (data ?? []).filter((o) => o.status === "requested")
  if (!open.length) return null

  return (
    <div className="bg-card overflow-hidden rounded-2xl border">
      <div className="border-b px-4 py-3">
        <h2 className="text-sm font-medium">{t("admin.orders.title", { count: formatNumber(open.length) })}</h2>
        <p className="text-muted-foreground text-xs">{t("admin.orders.hint")}</p>
      </div>
      <ul className="divide-y">
        {open.map((o) => (
          <li key={o.id} className="flex flex-col gap-3 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="min-w-0">
              <p className="text-sm font-medium">
                {o.restaurant?.name} · {t("cards.order.line", { count: formatNumber(o.quantity), date: formatDateTime(o.created_at) })}
              </p>
              <p className="text-muted-foreground text-xs">
                {o.requested_by ? t("admin.orders.by", { name: o.requested_by }) : null}
                {o.note ? ` · ${o.note}` : null}
              </p>
            </div>
            <div className="flex shrink-0 gap-2">
              <Button size="sm" onClick={() => setAccepting(o)}>
                <Check /> {t("admin.orders.accept")}
              </Button>
              <Button size="sm" variant="outline" onClick={() => setDeclining(o)}>
                <X /> {t("admin.orders.decline")}
              </Button>
            </div>
          </li>
        ))}
      </ul>
      {accepting ? <AcceptDialog order={accepting} onClose={() => setAccepting(null)} /> : null}
      <ReasonDialog
        open={declining !== null}
        onOpenChange={(o) => !o && setDeclining(null)}
        title={`${t("admin.orders.declineTitle")} · ${declining?.restaurant?.name ?? ""}`}
        description={t("admin.orders.declineDescription")}
        confirmLabel={t("admin.orders.decline")}
        destructive
        pending={decide.isPending}
        onConfirm={async (reason) => {
          if (!declining) return
          try {
            await decide.mutateAsync({ id: declining.id, kind: "decline", reason })
            toast.success(t("admin.orders.declined"))
            setDeclining(null)
          } catch (err) {
            toast.error(errorMessage(err))
          }
        }}
      />
    </div>
  )
}
