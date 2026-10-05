"use client"

import { use, useState } from "react"
import Link from "next/link"
import { ArrowDownLeft, ArrowLeft, Ban, CheckCircle2, Clock, Loader2, MoreHorizontal, Pencil, QrCode, RotateCcw, Undo2 } from "lucide-react"
import { toast } from "sonner"
import { LoyaltyBadge, StatusBadge, displayStatus } from "@/components/common/status-badge"
import { useConfirm } from "@/components/common/confirm"
import { PAYMENT_METHOD_LABELS } from "@/components/vouchers/payment-fields"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { VoucherVisual } from "@/components/vouchers/voucher-visual"
import { VoucherHistory } from "@/components/vouchers/voucher-history"
import { EditVoucherDialog } from "@/components/vouchers/edit-voucher-dialog"
import { RefundDialog } from "@/components/vouchers/refund-dialog"
import { ReissueDialog } from "@/components/vouchers/reissue-dialog"
import { ReloadDialog } from "@/components/vouchers/reload-dialog"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Card, CardAction, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Skeleton } from "@/components/ui/skeleton"
import { useCancelSale, useReinstateVoucher, useVoucher, useVoucherAction } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { Voucher } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { formatDate, formatDateTime, formatRelative, todayInput } from "@/lib/format"
import { formatMoney } from "@/lib/money"
import { soldToday } from "@/lib/voucher-state"
import { useDocumentTitle } from "@/hooks/use-document-title"
import { useT } from "@/lib/i18n"

type DialogName = "reload" | "block" | "expire" | "reinstate" | "edit" | "refund" | "cancel" | "reissue" | null

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
  const t = useT()
  const reinstate = useReinstateVoucher(voucher.id)
  const [reason, setReason] = useState("")
  const [expiresOn, setExpiresOn] = useState("")

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t("vouchers.reinstate.title")}</DialogTitle>
          <DialogDescription>{t("vouchers.reinstate.description", { amount: formatMoney(voucher.balance, voucher.currency) })}</DialogDescription>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            try {
              await reinstate.mutateAsync({ reason, expires_on: expiresOn || null })
              toast.success(t("vouchers.reinstate.done"))
              onOpenChange(false)
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="reinstate-reason">{t("vouchers.field.reason")}</Label>
            <Input id="reinstate-reason" required minLength={3} maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
          </div>
          <div className="space-y-2">
            <Label htmlFor="reinstate-expiry">{t("vouchers.reinstate.newLastDay")}</Label>
            <Input id="reinstate-expiry" type="date" min={todayInput(1)} value={expiresOn} onChange={(e) => setExpiresOn(e.target.value)} />
            <p className="text-muted-foreground text-xs">{t("vouchers.reinstate.leaveEmpty")}</p>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={reason.trim().length < 3 || reinstate.isPending}>
              {reinstate.isPending ? <Loader2 className="animate-spin" /> : null} {t("vouchers.detail.reinstate")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function VoucherDetail({ voucher }: { voucher: Voucher }) {
  const { user, can } = useAuth()
  const t = useT()
  const confirm = useConfirm()
  const [dialog, setDialog] = useState<DialogName>(null)
  const action = useVoucherAction(voucher.id)
  const settings = user?.restaurant?.settings
  const canReload = can("vouchers.reload") && voucher.status === "active" && !voucher.is_expired && !!settings?.allow_reload

  const run = async (name: "unblock" | "block" | "expire", reason?: string, message?: string) => {
    try {
      await action.mutateAsync({ action: name, reason })
      toast.success(message ?? t("vouchers.updated"))
      setDialog(null)
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  // A sale booked by mistake: unused and sold today (the server checks again, and who may cancel).
  const salePayment = voucher.payments?.length === 1 ? voucher.payments[0] : undefined
  const cancellable =
    can("vouchers.cancel_sale") &&
    voucher.status === "active" &&
    voucher.total_redeemed === 0 &&
    voucher.total_loaded === voucher.initial_value &&
    !!salePayment &&
    soldToday(voucher.created_at, user?.restaurant?.timezone)
  const needsStornoReference = salePayment?.method === "card_terminal" || salePayment?.method === "bank_transfer"
  const [stornoReference, setStornoReference] = useState("")
  const cancelSale = useCancelSale()

  useDocumentTitle(voucher.voucher_number_formatted)

  const activeQr = voucher.media?.find((m) => m.type === "printable_qr" && m.status === "active")
  const activeCard = voucher.media?.find((m) => m.type === "nfc_card" && m.status === "active")
  const earlierCards = voucher.media?.filter((m) => m.type === "nfc_card" && m.status === "revoked") ?? []

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <Button variant="ghost" size="sm" asChild className="-ml-2">
          <Link href="/vouchers">
            <ArrowLeft /> {t("vouchers.title")}
          </Link>
        </Button>
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
            <h1 className="card-number text-xl font-semibold sm:text-2xl">{voucher.voucher_number_formatted}</h1>
            <StatusBadge status={displayStatus(voucher)} size="lg" />
            {voucher.loyalty ? <LoyaltyBadge /> : null}
          </div>
          <div className="flex flex-wrap gap-2">
            {canReload ? (
              <Button variant="outline" onClick={() => setDialog("reload")}>
                <ArrowDownLeft /> {t("vouchers.detail.reload")}
              </Button>
            ) : null}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="outline" size="icon" aria-label={t("vouchers.detail.moreActions")}>
                  <MoreHorizontal />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-52">
                {can("vouchers.update") ? (
                  <DropdownMenuItem onSelect={() => setDialog("edit")}>
                    <Pencil /> {t("vouchers.detail.editDetails")}
                  </DropdownMenuItem>
                ) : null}
                {can("vouchers.reissue") && voucher.kind === "digital" && voucher.status !== "refunded" ? (
                  <DropdownMenuItem onSelect={() => setDialog("reissue")}>
                    <QrCode /> {t("vouchers.detail.newQr")}
                  </DropdownMenuItem>
                ) : null}
                <DropdownMenuSeparator />
                {can("vouchers.unblock") && voucher.status === "blocked" ? (
                  <DropdownMenuItem
                    onSelect={async () => {
                      const ok = await confirm({
                        title: t("vouchers.unblock.title"),
                        description: t("vouchers.unblock.description"),
                        confirmLabel: t("vouchers.detail.unblock"),
                      })
                      if (ok) await run("unblock", undefined, t("vouchers.unblock.done"))
                    }}
                  >
                    <CheckCircle2 /> {t("vouchers.detail.unblock")}
                  </DropdownMenuItem>
                ) : null}
                {can("vouchers.reinstate") && voucher.status === "expired" ? (
                  <DropdownMenuItem onSelect={() => setDialog("reinstate")}>
                    <RotateCcw /> {t("vouchers.detail.reinstate")}
                  </DropdownMenuItem>
                ) : null}
                {cancellable ? (
                  <DropdownMenuItem variant="destructive" onSelect={() => setDialog("cancel")}>
                    <Undo2 /> {t("vouchers.detail.cancelSaleMenu")}
                  </DropdownMenuItem>
                ) : null}
                {(voucher.refundable ?? 0) > 0 ? (
                  <DropdownMenuItem variant="destructive" onSelect={() => setDialog("refund")}>
                    <Undo2 /> {t("vouchers.detail.refundMenu")}
                  </DropdownMenuItem>
                ) : null}
                {can("vouchers.block") && voucher.status !== "blocked" && voucher.status !== "refunded" ? (
                  <DropdownMenuItem variant="destructive" onSelect={() => setDialog("block")}>
                    <Ban /> {t("vouchers.detail.block")}
                  </DropdownMenuItem>
                ) : null}
                {can("vouchers.expire") && voucher.status === "active" ? (
                  <DropdownMenuItem variant="destructive" onSelect={() => setDialog("expire")}>
                    <Clock /> {t("vouchers.detail.expireNow")}
                  </DropdownMenuItem>
                ) : null}
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>
      </div>

      {voucher.status === "blocked" && voucher.blocked_reason ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800 dark:border-red-500/30 dark:bg-red-500/10 dark:text-red-300">
          {t("vouchers.detail.blockedBanner", { when: formatRelative(voucher.blocked_at), reason: voucher.blocked_reason })}
        </div>
      ) : null}
      {voucher.status === "expired" ? (
        <div className="rounded-xl border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-900 dark:border-amber-500/30 dark:bg-amber-500/10 dark:text-amber-200">
          {t(can("vouchers.reinstate") ? "vouchers.detail.expiredBanner" : "vouchers.detail.expiredBannerOwner", {
            when: formatRelative(voucher.expired_at),
            amount: formatMoney(voucher.balance, voucher.currency),
          })}
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
              status={voucher.status === "active" && voucher.is_expired ? "expired" : voucher.status}
              brandColor={settings?.brand_color}
            />
          </div>
          <Card>
            <CardHeader>
              <CardTitle>{t("vouchers.detail.details")}</CardTitle>
              {can("vouchers.update") ? (
                <CardAction>
                  <Button variant="ghost" size="sm" onClick={() => setDialog("edit")}>
                    <Pencil /> {t("common.edit")}
                  </Button>
                </CardAction>
              ) : null}
            </CardHeader>
            <CardContent>
              <dl className="divide-y">
                <Detail label={t("vouchers.col.balance")}>{formatMoney(voucher.balance, voucher.currency)}</Detail>
                <Detail label={t("vouchers.detail.initialValue")}>{formatMoney(voucher.initial_value, voucher.currency)}</Detail>
                <Detail label={t("vouchers.detail.reloaded")}>{formatMoney(voucher.total_loaded - voucher.initial_value, voucher.currency)}</Detail>
                <Detail label={t("vouchers.detail.redeemed")}>{formatMoney(voucher.total_redeemed, voucher.currency)}</Detail>
                <Detail label={t("vouchers.detail.kind")}>{voucher.kind === "digital" ? t("vouchers.detail.kindDigital") : t("vouchers.detail.card")}</Detail>
                {voucher.kind === "digital" ? (
                  <Detail label={t("vouchers.detail.qrCode")}>
                    {activeQr ? t("vouchers.detail.qrActiveSince", { date: formatDate(activeQr.created_at) }) : t("vouchers.detail.noActiveQr")}
                  </Detail>
                ) : (
                  <Detail label={t("vouchers.detail.card")}>
                    {activeCard?.card_number ? (
                      <Link href={`/cards?search=${encodeURIComponent(activeCard.card_number)}`} className="font-mono underline-offset-4 hover:underline">
                        {activeCard.card_number}
                      </Link>
                    ) : (
                      t("vouchers.detail.noActiveCard")
                    )}
                    {earlierCards.length ? (
                      <span className="text-muted-foreground block text-xs">
                        {t("vouchers.detail.replaced", { cards: earlierCards.map((m) => m.card_number).join(", ") })}
                      </span>
                    ) : null}
                  </Detail>
                )}
                <Detail label={t("vouchers.detail.validUntil")}>
                  <span className={voucher.is_expired ? "text-amber-700 dark:text-amber-400" : undefined}>
                    {voucher.expires_at ? formatDate(voucher.expires_at) : t("vouchers.noExpiry")}
                  </span>
                </Detail>
                <Detail label={t("vouchers.col.customer")}>
                  {voucher.customer ? (
                    <Link href={`/customers/${voucher.customer.id}`} className="hover:underline">
                      {voucher.customer.full_name}
                    </Link>
                  ) : (
                    t("vouchers.anonymous")
                  )}
                </Detail>
                <Detail label={t("vouchers.field.recipient")}>{voucher.recipient_name ?? t("common.none")}</Detail>
                <Detail label={t("vouchers.detail.sold")}>
                  {formatDateTime(voucher.created_at)}
                  {voucher.issued_by ? (
                    <span className="text-muted-foreground block text-xs font-normal">{t("vouchers.detail.soldBy", { name: voucher.issued_by.name })}</span>
                  ) : null}
                </Detail>
                <Detail label={t("vouchers.detail.lastUsed")}>{voucher.last_used_at ? formatRelative(voucher.last_used_at) : t("common.never")}</Detail>
              </dl>
              {voucher.notes ? <p className="bg-surface text-muted-foreground mt-3 rounded-xl p-3 text-sm whitespace-pre-line">{voucher.notes}</p> : null}
            </CardContent>
          </Card>
          {voucher.payments?.length ? (
            <Card>
              <CardHeader>
                <CardTitle>{t("vouchers.detail.payments")}</CardTitle>
              </CardHeader>
              <CardContent>
                <dl className="divide-y">
                  {voucher.payments.map((p) => (
                    <Detail key={p.id} label={`${formatDateTime(p.created_at)} · ${t(PAYMENT_METHOD_LABELS[p.method])}`}>
                      {formatMoney(p.amount, p.currency)}
                      {p.reference ? (
                        <span className="text-muted-foreground block text-xs font-normal">{t("vouchers.ref", { reference: p.reference })}</span>
                      ) : null}
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
            <CardTitle>{t("vouchers.history.title")}</CardTitle>
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
        loyalty={voucher.loyalty}
        open={dialog === "reload"}
        onOpenChange={(o) => setDialog(o ? "reload" : null)}
      />
      {dialog === "edit" ? <EditVoucherDialog voucher={voucher} open onOpenChange={(o) => setDialog(o ? "edit" : null)} /> : null}
      {dialog === "reissue" ? <ReissueDialog voucher={voucher} open onOpenChange={(o) => setDialog(o ? "reissue" : null)} /> : null}
      {dialog === "refund" ? <RefundDialog voucher={voucher} open onOpenChange={(o) => setDialog(o ? "refund" : null)} /> : null}
      {dialog === "reinstate" ? <ReinstateDialog voucher={voucher} open onOpenChange={(o) => setDialog(o ? "reinstate" : null)} /> : null}
      <ReasonDialog
        open={dialog === "cancel"}
        onOpenChange={(o) => setDialog(o ? "cancel" : null)}
        title={t("vouchers.cancelSale.title")}
        description={
          salePayment?.method === "complimentary"
            ? t("vouchers.cancelSale.descriptionComplimentary", { amount: formatMoney(voucher.balance, voucher.currency) })
            : t("vouchers.cancelSale.description", {
                amount: formatMoney(voucher.balance, voucher.currency),
                method: salePayment ? t(PAYMENT_METHOD_LABELS[salePayment.method]) : "",
              })
        }
        suggestions={[t("vouchers.reason.wrongAmount"), t("vouchers.reason.wrongVoucherType"), t("vouchers.reason.guestChangedMind")]}
        confirmLabel={t("vouchers.cancelSale.title")}
        destructive
        pending={cancelSale.isPending}
        onConfirm={async (reason) => {
          if (needsStornoReference && stornoReference.trim() === "") {
            toast.error(t("vouchers.cancelSale.referenceMissing"))
            return
          }
          try {
            await cancelSale.mutateAsync({ voucherId: voucher.id, reason, reference: needsStornoReference ? stornoReference.trim() : null })
            toast.success(t("vouchers.cancelSale.done"))
            setDialog(null)
          } catch (e) {
            toast.error(errorMessage(e))
          }
        }}
      >
        {needsStornoReference ? (
          <div className="space-y-2">
            <Label htmlFor="storno-reference">
              {salePayment?.method === "card_terminal" ? t("vouchers.cancelSale.terminalReceipt") : t("vouchers.cancelSale.bankReference")}
            </Label>
            <Input id="storno-reference" value={stornoReference} onChange={(e) => setStornoReference(e.target.value)} maxLength={120} />
          </div>
        ) : null}
      </ReasonDialog>
      <ReasonDialog
        open={dialog === "block"}
        onOpenChange={(o) => setDialog(o ? "block" : null)}
        title={t("vouchers.detail.block")}
        suggestions={[t("vouchers.reason.reportedStolen"), t("vouchers.reason.reportedLost"), t("vouchers.reason.suspiciousUse")]}
        description={t("vouchers.block.description")}
        confirmLabel={t("vouchers.detail.block")}
        destructive
        pending={action.isPending}
        onConfirm={(reason) => run("block", reason, t("vouchers.block.done"))}
      />
      <ReasonDialog
        open={dialog === "expire"}
        onOpenChange={(o) => setDialog(o ? "expire" : null)}
        title={t("vouchers.expire.title")}
        description={t("vouchers.expire.description", { amount: formatMoney(voucher.balance, voucher.currency) })}
        confirmLabel={t("vouchers.expire.confirm")}
        destructive
        pending={action.isPending}
        onConfirm={(reason) => run("expire", reason, t("vouchers.expire.done"))}
      />
    </div>
  )
}

function VoucherPageContent({ id }: { id: string }) {
  const t = useT()
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
  if (error || !data) return <p className="text-muted-foreground py-16 text-center">{errorMessage(error, t("vouchers.notFound"))}</p>
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
