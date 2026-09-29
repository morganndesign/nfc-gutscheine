"use client"

import { use, useState } from "react"
import Link from "next/link"
import { ArrowDownLeft, ArrowLeft, Ban, CheckCircle2, Clock, Loader2, MoreHorizontal, Pencil, RotateCcw, Undo2 } from "lucide-react"
import { toast } from "sonner"
import { StatusBadge, displayStatus } from "@/components/common/status-badge"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { VoucherVisual } from "@/components/vouchers/voucher-visual"
import { VoucherHistory } from "@/components/vouchers/voucher-history"
import { EditVoucherDialog } from "@/components/vouchers/edit-voucher-dialog"
import { RefundDialog } from "@/components/vouchers/refund-dialog"
import { ReloadDialog } from "@/components/vouchers/reload-dialog"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Card, CardAction, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Skeleton } from "@/components/ui/skeleton"
import { useReinstateVoucher, useVoucher, useVoucherAction } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { Voucher } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { formatDate, formatDateTime, formatRelative, todayInput } from "@/lib/format"
import { formatMoney } from "@/lib/money"

type DialogName = "reload" | "block" | "expire" | "reinstate" | "edit" | "refund" | null

function Detail({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-4 py-2.5 text-sm">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="text-right font-medium">{children}</dd>
    </div>
  )
}

/** Owner only: an expired voucher becomes usable again with its full balance (it was never written off). */
function ReinstateDialog({ voucher, open, onOpenChange }: { voucher: Voucher; open: boolean; onOpenChange: (o: boolean) => void }) {
  const reinstate = useReinstateVoucher(voucher.id)
  const [reason, setReason] = useState("")
  const [expiresOn, setExpiresOn] = useState("")

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Reinstate voucher</DialogTitle>
          <DialogDescription>The voucher becomes usable again with its balance of {formatMoney(voucher.balance, voucher.currency)}.</DialogDescription>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            try {
              await reinstate.mutateAsync({ reason, expires_on: expiresOn || null })
              toast.success("Voucher reinstated")
              onOpenChange(false)
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="reinstate-reason">Reason</Label>
            <Input id="reinstate-reason" required minLength={3} maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
          </div>
          <div className="space-y-2">
            <Label htmlFor="reinstate-expiry">New last valid day</Label>
            <Input id="reinstate-expiry" type="date" min={todayInput(1)} value={expiresOn} onChange={(e) => setExpiresOn(e.target.value)} />
            <p className="text-muted-foreground text-xs">Leave empty for no expiry.</p>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={reason.trim().length < 3 || reinstate.isPending}>
              {reinstate.isPending ? <Loader2 className="animate-spin" /> : null} Reinstate
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function VoucherDetail({ voucher }: { voucher: Voucher }) {
  const { user, can } = useAuth()
  const [dialog, setDialog] = useState<DialogName>(null)
  const action = useVoucherAction(voucher.id)
  const settings = user?.restaurant?.settings
  const canReload = can("vouchers.reload") && voucher.status === "active" && !voucher.is_expired && !!settings?.allow_reload

  const run = async (name: "unblock" | "block" | "expire", reason?: string, message?: string) => {
    try {
      await action.mutateAsync({ action: name, reason })
      toast.success(message ?? "Voucher updated")
      setDialog(null)
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  const activeQr = voucher.media?.find((m) => m.type === "printable_qr" && m.status === "active")
  const activeCard = voucher.media?.find((m) => m.type === "nfc_card" && m.status === "active")
  const earlierCards = voucher.media?.filter((m) => m.type === "nfc_card" && m.status === "revoked") ?? []

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <Button variant="ghost" size="sm" asChild className="-ml-2">
          <Link href="/vouchers">
            <ArrowLeft /> Vouchers
          </Link>
        </Button>
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
            <h1 className="card-number text-xl font-semibold sm:text-2xl">{voucher.voucher_number_formatted}</h1>
            <StatusBadge status={displayStatus(voucher)} size="lg" />
          </div>
          <div className="flex flex-wrap gap-2">
            {canReload ? (
              <Button variant="outline" onClick={() => setDialog("reload")}>
                <ArrowDownLeft /> Reload
              </Button>
            ) : null}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="outline" size="icon" aria-label="More actions">
                  <MoreHorizontal />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-52">
                {can("vouchers.update") ? (
                  <DropdownMenuItem onSelect={() => setDialog("edit")}>
                    <Pencil /> Edit details
                  </DropdownMenuItem>
                ) : null}
                <DropdownMenuSeparator />
                {can("vouchers.unblock") && voucher.status === "blocked" ? (
                  <DropdownMenuItem onSelect={() => run("unblock", undefined, "Voucher unblocked")}>
                    <CheckCircle2 /> Unblock
                  </DropdownMenuItem>
                ) : null}
                {can("vouchers.reinstate") && voucher.status === "expired" ? (
                  <DropdownMenuItem onSelect={() => setDialog("reinstate")}>
                    <RotateCcw /> Reinstate
                  </DropdownMenuItem>
                ) : null}
                {(voucher.refundable ?? 0) > 0 ? (
                  <DropdownMenuItem variant="destructive" onSelect={() => setDialog("refund")}>
                    <Undo2 /> Refund…
                  </DropdownMenuItem>
                ) : null}
                {can("vouchers.block") && voucher.status !== "blocked" && voucher.status !== "refunded" ? (
                  <DropdownMenuItem variant="destructive" onSelect={() => setDialog("block")}>
                    <Ban /> Block voucher
                  </DropdownMenuItem>
                ) : null}
                {can("vouchers.expire") && voucher.status === "active" ? (
                  <DropdownMenuItem variant="destructive" onSelect={() => setDialog("expire")}>
                    <Clock /> Expire now
                  </DropdownMenuItem>
                ) : null}
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>
      </div>

      {voucher.status === "blocked" && voucher.blocked_reason ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800 dark:border-red-500/30 dark:bg-red-500/10 dark:text-red-300">
          Blocked {formatRelative(voucher.blocked_at)}: {voucher.blocked_reason}
        </div>
      ) : null}
      {voucher.status === "expired" ? (
        <div className="rounded-xl border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-900 dark:border-amber-500/30 dark:bg-amber-500/10 dark:text-amber-200">
          Expired {formatRelative(voucher.expired_at)}. The balance of {formatMoney(voucher.balance, voucher.currency)} is kept
          {can("vouchers.reinstate") ? " and the voucher can be reinstated." : "; the owner can reinstate the voucher."}
        </div>
      ) : null}

      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.4fr)]">
        <div className="space-y-6">
          <div className="max-w-md">
            <VoucherVisual
              restaurantName={user?.restaurant?.name ?? ""}
              kind={voucher.kind}
              balance={voucher.balance}
              currency={voucher.currency}
              expiresAt={voucher.expires_at}
              status={voucher.status}
              brandColor={settings?.brand_color}
            />
          </div>
          <Card>
            <CardHeader>
              <CardTitle>Details</CardTitle>
              {can("vouchers.update") ? (
                <CardAction>
                  <Button variant="ghost" size="sm" onClick={() => setDialog("edit")}>
                    <Pencil /> Edit
                  </Button>
                </CardAction>
              ) : null}
            </CardHeader>
            <CardContent>
              <dl className="divide-y">
                <Detail label="Balance">{formatMoney(voucher.balance, voucher.currency)}</Detail>
                <Detail label="Initial value">{formatMoney(voucher.initial_value, voucher.currency)}</Detail>
                <Detail label="Reloaded">{formatMoney(voucher.total_loaded - voucher.initial_value, voucher.currency)}</Detail>
                <Detail label="Redeemed">{formatMoney(voucher.total_redeemed, voucher.currency)}</Detail>
                <Detail label="Kind">{voucher.kind === "digital" ? "Digital (QR)" : "Card"}</Detail>
                {voucher.kind === "digital" ? (
                  <Detail label="QR code">{activeQr ? `Active since ${formatDate(activeQr.created_at)}` : "No active QR"}</Detail>
                ) : (
                  <Detail label="Card">
                    {activeCard?.card_number ? (
                      <Link href={`/cards?search=${encodeURIComponent(activeCard.card_number)}`} className="font-mono underline-offset-4 hover:underline">
                        {activeCard.card_number}
                      </Link>
                    ) : (
                      "No active card"
                    )}
                    {earlierCards.length ? (
                      <span className="text-muted-foreground block text-xs">Replaced: {earlierCards.map((m) => m.card_number).join(", ")}</span>
                    ) : null}
                  </Detail>
                )}
                <Detail label="Valid until">
                  <span className={voucher.is_expired ? "text-amber-700 dark:text-amber-400" : undefined}>
                    {voucher.expires_at ? formatDate(voucher.expires_at) : "No expiry"}
                  </span>
                </Detail>
                <Detail label="Customer">
                  {voucher.customer ? (
                    <Link href={`/customers/${voucher.customer.id}`} className="hover:underline">
                      {voucher.customer.full_name}
                    </Link>
                  ) : (
                    "Anonymous"
                  )}
                </Detail>
                <Detail label="Recipient">{voucher.recipient_name ?? "—"}</Detail>
                <Detail label="Sold">
                  {formatDateTime(voucher.created_at)}
                  {voucher.issued_by ? <span className="text-muted-foreground block text-xs font-normal">by {voucher.issued_by.name}</span> : null}
                </Detail>
                <Detail label="Last used">{voucher.last_used_at ? formatRelative(voucher.last_used_at) : "Never"}</Detail>
              </dl>
              {voucher.notes ? <p className="bg-surface text-muted-foreground mt-3 rounded-xl p-3 text-sm whitespace-pre-line">{voucher.notes}</p> : null}
            </CardContent>
          </Card>
          {voucher.payments?.length ? (
            <Card>
              <CardHeader>
                <CardTitle>Payments</CardTitle>
              </CardHeader>
              <CardContent>
                <dl className="divide-y">
                  {voucher.payments.map((p) => (
                    <Detail key={p.id} label={`${formatDateTime(p.created_at)} · ${p.method_label}`}>
                      {formatMoney(p.amount, p.currency)}
                      {p.reference ? <span className="text-muted-foreground block text-xs font-normal">Ref. {p.reference}</span> : null}
                      {p.reason ? <span className="text-muted-foreground block text-xs font-normal">{p.reason}</span> : null}
                    </Detail>
                  ))}
                </dl>
              </CardContent>
            </Card>
          ) : null}
        </div>

        <Card className="self-start">
          <CardHeader>
            <CardTitle>History</CardTitle>
          </CardHeader>
          <CardContent className="px-3">
            <VoucherHistory voucherId={voucher.id} currency={voucher.currency} />
          </CardContent>
        </Card>
      </div>

      <ReloadDialog
        voucherId={voucher.id}
        balance={voucher.balance}
        maxBalance={settings?.max_voucher_balance ?? voucher.balance}
        currency={voucher.currency}
        open={dialog === "reload"}
        onOpenChange={(o) => setDialog(o ? "reload" : null)}
      />
      {dialog === "edit" ? <EditVoucherDialog voucher={voucher} open onOpenChange={(o) => setDialog(o ? "edit" : null)} /> : null}
      {dialog === "refund" ? <RefundDialog voucher={voucher} open onOpenChange={(o) => setDialog(o ? "refund" : null)} /> : null}
      {dialog === "reinstate" ? <ReinstateDialog voucher={voucher} open onOpenChange={(o) => setDialog(o ? "reinstate" : null)} /> : null}
      <ReasonDialog
        open={dialog === "block"}
        onOpenChange={(o) => setDialog(o ? "block" : null)}
        title="Block voucher"
        suggestions={["Reported stolen", "Reported lost", "Suspicious use"]}
        description="A blocked voucher cannot be redeemed or reloaded until it is unblocked. Its balance is kept."
        confirmLabel="Block voucher"
        destructive
        pending={action.isPending}
        onConfirm={(reason) => run("block", reason, "Voucher blocked")}
      />
      <ReasonDialog
        open={dialog === "expire"}
        onOpenChange={(o) => setDialog(o ? "expire" : null)}
        title="Expire voucher now"
        description={`The voucher can no longer be redeemed. Its balance of ${formatMoney(voucher.balance, voucher.currency)} is kept, and you can reinstate it later.`}
        confirmLabel="Expire voucher"
        destructive
        pending={action.isPending}
        onConfirm={(reason) => run("expire", reason, "Voucher expired")}
      />
    </div>
  )
}

function VoucherPageContent({ id }: { id: string }) {
  const { data, isLoading, error } = useVoucher(id)
  if (isLoading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-10 w-72" />
        <div className="grid gap-6 lg:grid-cols-2">
          <Skeleton className="aspect-[1.586] w-full max-w-sm rounded-2xl" />
          <Skeleton className="h-96 w-full rounded-2xl" />
        </div>
      </div>
    )
  }
  if (error || !data) return <p className="text-muted-foreground py-16 text-center">{errorMessage(error, "Voucher not found.")}</p>
  return <VoucherDetail voucher={data} />
}

export default function VoucherPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  return (
    <RequirePermission permission="vouchers.view">
      <VoucherPageContent id={id} />
    </RequirePermission>
  )
}
