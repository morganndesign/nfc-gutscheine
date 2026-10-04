"use client"

import { useState } from "react"
import { Loader2, PackagePlus } from "lucide-react"
import { toast } from "sonner"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { useCardOrders, useOrderCards } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { CardOrder, CardOrderStatus } from "@/lib/api/types"
import { formatDate, formatNumber } from "@/lib/format"
import { useT, type MessageKey } from "@/lib/i18n"

const STATUS: Record<CardOrderStatus, { label: MessageKey; variant: "secondary" | "default" | "destructive" }> = {
  requested: { label: "cards.order.status.requested", variant: "secondary" },
  accepted: { label: "cards.order.status.accepted", variant: "default" },
  declined: { label: "cards.order.status.declined", variant: "destructive" },
}

/** "Order cards": quantity and an optional note for the platform (decision 2026-10-04). */
export function OrderCardsDialog({ onClose }: { onClose: () => void }) {
  const t = useT()
  const order = useOrderCards()
  const [quantity, setQuantity] = useState("50")
  const [note, setNote] = useState("")
  const amount = Number(quantity)
  const valid = Number.isInteger(amount) && amount >= 1 && amount <= 1000

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t("cards.order.title")}</DialogTitle>
          <DialogDescription>{t("cards.order.description")}</DialogDescription>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            try {
              await order.mutateAsync({ quantity: amount, note: note.trim() || undefined })
              toast.success(t("cards.order.sent"))
              onClose()
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="o-qty">{t("cards.order.quantity")}</Label>
            <Input
              id="o-qty"
              inputMode="numeric"
              value={quantity}
              onChange={(e) => setQuantity(e.target.value.replace(/\D/g, "").slice(0, 4))}
              aria-invalid={!valid || undefined}
              aria-describedby="o-qty-hint"
              required
            />
            <p id="o-qty-hint" className="text-muted-foreground text-xs">
              {t("cards.order.quantityHint")}
            </p>
          </div>
          <div className="space-y-2">
            <Label htmlFor="o-note">{t("cards.order.note")}</Label>
            <Textarea
              id="o-note"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              maxLength={500}
              rows={3}
              placeholder={t("cards.order.notePlaceholder")}
            />
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={order.isPending || !valid}>
              {order.isPending ? <Loader2 className="animate-spin" /> : null} {t("cards.order.submit")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

export function OrderCardsButton() {
  const t = useT()
  const [open, setOpen] = useState(false)
  return (
    <>
      <Button onClick={() => setOpen(true)}>
        <PackagePlus /> {t("cards.order.title")}
      </Button>
      {open ? <OrderCardsDialog onClose={() => setOpen(false)} /> : null}
    </>
  )
}

function OrderLine({ order }: { order: CardOrder }) {
  const t = useT()
  const s = STATUS[order.status]
  return (
    <li className="flex flex-col gap-1 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
      <div className="min-w-0">
        <p className="text-sm font-medium">{t("cards.order.line", { count: formatNumber(order.quantity), date: formatDate(order.created_at) })}</p>
        {order.note ? <p className="text-muted-foreground truncate text-xs">{order.note}</p> : null}
        {order.status === "declined" && order.decline_reason ? (
          <p className="text-destructive text-xs">{t("cards.order.declinedBecause", { reason: order.decline_reason })}</p>
        ) : null}
        {order.status === "accepted" && order.batch_code ? (
          <p className="text-muted-foreground text-xs">{t("cards.order.acceptedAs", { batch: order.batch_code })}</p>
        ) : null}
      </div>
      <Badge variant={s.variant} className="self-start sm:self-center">
        {t(s.label)}
      </Badge>
    </li>
  )
}

/** The restaurant's recent card orders and what became of them. */
export function CardOrders() {
  const t = useT()
  const { data } = useCardOrders()
  if (!data?.length) return null
  return (
    <div className="bg-card overflow-hidden rounded-2xl border">
      <div className="border-b px-4 py-3">
        <h2 className="text-sm font-medium">{t("cards.order.listTitle")}</h2>
        <p className="text-muted-foreground text-xs">{t("cards.order.listHint")}</p>
      </div>
      <ul className="divide-y">
        {data.slice(0, 5).map((o) => (
          <OrderLine key={o.id} order={o} />
        ))}
      </ul>
    </div>
  )
}
