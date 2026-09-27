"use client"

import { use, useState } from "react"
import Link from "next/link"
import { useRouter, useSearchParams } from "next/navigation"
import { ArrowDownLeft, ArrowLeft, ArrowUpRight, Ban, CheckCircle2, Clock, MoreHorizontal, Nfc, Pencil, Power, Printer, Replace, Shuffle } from "lucide-react"
import { toast } from "sonner"
import { StatusBadge } from "@/components/common/status-badge"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { CardVisual } from "@/components/cards/card-visual"
import { CardHistory } from "@/components/cards/card-history"
import { EditCardDialog } from "@/components/cards/edit-card-dialog"
import { MoneyDialog } from "@/components/cards/money-dialog"
import { NfcAttempts } from "@/components/cards/nfc-attempts"
import { NfcWriter } from "@/components/cards/nfc-writer"
import { TransferDialog } from "@/components/cards/transfer-dialog"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Card, CardAction, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { Skeleton } from "@/components/ui/skeleton"
import { useCard, useCardAction, useNfcPayload, useReplaceCard } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { GiftCard } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { formatCardNumber, formatDate, formatDateTime, formatRelative } from "@/lib/format"
import { formatMoney } from "@/lib/money"
import { TAG_TYPES } from "@/lib/nfc"

type DialogName = "redeem" | "reload" | "transfer" | "block" | "expire" | "replace" | "edit" | "nfc" | null

function Detail({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-4 py-2.5 text-sm">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="text-right font-medium">{children}</dd>
    </div>
  )
}

function CardDetail({ card }: { card: GiftCard }) {
  const { user, can } = useAuth()
  const router = useRouter()
  const searchParams = useSearchParams()
  const [dialog, setDialog] = useState<DialogName>(searchParams.get("write") ? "nfc" : null)
  const action = useCardAction(card.id)
  const replace = useReplaceCard(card.id)
  const nfc = useNfcPayload(card.id, dialog === "nfc")
  const settings = user?.restaurant?.settings
  const open = card.status !== "expired" && card.status !== "replaced"
  const canRedeem = can("cards.redeem") && card.status === "active" && !card.is_expired && card.balance > 0
  const canReload = can("cards.reload") && ["active", "redeemed", "inactive"].includes(card.status) && !card.is_expired && !!settings?.allow_reload

  const run = async (name: "activate" | "unblock" | "block" | "expire", reason?: string, message?: string) => {
    try {
      await action.mutateAsync({ action: name, reason })
      toast.success(message ?? "Card updated")
      setDialog(null)
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  const tagLabel = TAG_TYPES.find((t) => t.value === card.nfc.tag_type)?.label

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <Button variant="ghost" size="sm" asChild className="-ml-2">
          <Link href="/cards">
            <ArrowLeft /> Gift cards
          </Link>
        </Button>
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
            <h1 className="card-number text-xl font-semibold sm:text-2xl">{card.card_number_formatted}</h1>
            <StatusBadge status={card.status} size="lg" />
          </div>
          <div className="flex flex-wrap gap-2">
            {canRedeem ? (
              <Button onClick={() => setDialog("redeem")}>
                <ArrowUpRight /> Redeem
              </Button>
            ) : null}
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
                {can("cards.activate") && card.status === "inactive" ? (
                  <DropdownMenuItem onSelect={() => run("activate", undefined, "Card activated")}>
                    <Power /> Activate
                  </DropdownMenuItem>
                ) : null}
                {can("cards.update") && open ? (
                  <DropdownMenuItem onSelect={() => setDialog("edit")}>
                    <Pencil /> Edit details
                  </DropdownMenuItem>
                ) : null}
                {can("cards.write_nfc") && open ? (
                  <>
                    <DropdownMenuItem onSelect={() => setDialog("nfc")}>
                      <Nfc /> Write NFC tag
                    </DropdownMenuItem>
                    <DropdownMenuItem onSelect={() => window.open(`/print/cards/${card.id}`, "_blank")}>
                      <Printer /> Print card / QR
                    </DropdownMenuItem>
                  </>
                ) : null}
                {can("cards.transfer") && open && card.balance > 0 ? (
                  <DropdownMenuItem onSelect={() => setDialog("transfer")}>
                    <Shuffle /> Transfer balance
                  </DropdownMenuItem>
                ) : null}
                {can("cards.replace") && open ? (
                  <DropdownMenuItem onSelect={() => setDialog("replace")}>
                    <Replace /> Replace lost card
                  </DropdownMenuItem>
                ) : null}
                <DropdownMenuSeparator />
                {can("cards.unblock") && card.status === "blocked" ? (
                  <DropdownMenuItem onSelect={() => run("unblock", undefined, "Card unblocked")}>
                    <CheckCircle2 /> Unblock
                  </DropdownMenuItem>
                ) : null}
                {can("cards.block") && ["active", "inactive", "redeemed"].includes(card.status) ? (
                  <DropdownMenuItem variant="destructive" onSelect={() => setDialog("block")}>
                    <Ban /> Block card
                  </DropdownMenuItem>
                ) : null}
                {can("cards.expire") && open ? (
                  <DropdownMenuItem variant="destructive" onSelect={() => setDialog("expire")}>
                    <Clock /> Expire now
                  </DropdownMenuItem>
                ) : null}
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>
      </div>

      {card.status === "blocked" && card.blocked_reason ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800 dark:border-red-500/30 dark:bg-red-500/10 dark:text-red-300">
          Blocked {formatRelative(card.blocked_at)}: {card.blocked_reason}
        </div>
      ) : null}
      {card.replaced_by ? (
        <div className="bg-surface rounded-xl border px-4 py-3 text-sm">
          This card was replaced by{" "}
          <Link className="card-number font-medium underline" href={`/cards/${card.replaced_by.id}`}>
            {formatCardNumber(card.replaced_by.card_number)}
          </Link>
          .
        </div>
      ) : null}

      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.4fr)]">
        <div className="space-y-6">
          <div className="max-w-md">
            <CardVisual
              restaurantName={user?.restaurant?.name ?? ""}
              cardNumber={card.card_number_formatted}
              balance={card.balance}
              currency={card.currency}
              expiresAt={card.expires_at}
              status={card.status}
              brandColor={settings?.brand_color}
            />
          </div>
          <Card>
            <CardHeader>
              <CardTitle>Details</CardTitle>
              {can("cards.update") && open ? (
                <CardAction>
                  <Button variant="ghost" size="sm" onClick={() => setDialog("edit")}>
                    <Pencil /> Edit
                  </Button>
                </CardAction>
              ) : null}
            </CardHeader>
            <CardContent>
              <dl className="divide-y">
                <Detail label="Balance">{formatMoney(card.balance, card.currency)}</Detail>
                <Detail label="Initial value">{formatMoney(card.initial_value, card.currency)}</Detail>
                {/* total_loaded counts the sale of the card itself; a replacement starts at 0 and carries its value as initial_value. */}
                <Detail label="Reloaded">{formatMoney(card.replaces ? card.total_loaded : card.total_loaded - card.initial_value, card.currency)}</Detail>
                <Detail label="Redeemed">{formatMoney(card.total_redeemed, card.currency)}</Detail>
                <Detail label="Valid until">
                  <span className={card.is_expired ? "text-amber-700 dark:text-amber-400" : undefined}>
                    {card.expires_at ? formatDate(card.expires_at) : "No expiry"}
                  </span>
                </Detail>
                <Detail label="Customer">
                  {card.customer ? (
                    <Link href={`/customers/${card.customer.id}`} className="hover:underline">
                      {card.customer.full_name}
                    </Link>
                  ) : (
                    "—"
                  )}
                </Detail>
                <Detail label="Recipient">{card.recipient_name ?? "—"}</Detail>
                <Detail label="Issued">
                  {formatDateTime(card.created_at)}
                  {card.issued_by ? <span className="text-muted-foreground block text-xs font-normal">by {card.issued_by.name}</span> : null}
                </Detail>
                <Detail label="Last used">{card.last_used_at ? formatRelative(card.last_used_at) : "Never"}</Detail>
                <Detail label="NFC tag">
                  {card.nfc.written_at ? (
                    <>
                      {tagLabel ?? card.nfc.tag_type}
                      {card.nfc.locked ? " · locked" : ""}
                      {card.nfc.tag_type !== "qr_only" && card.nfc.tag_type !== "ntag424_dna" ? (
                        card.nfc.verified_at ? (
                          <span className="block text-xs font-normal text-emerald-700 dark:text-emerald-400">
                            Verified {formatDateTime(card.nfc.verified_at)}
                          </span>
                        ) : (
                          <span className="block text-xs font-normal text-amber-700 dark:text-amber-400">Not verified (written with another app)</span>
                        )
                      ) : null}
                      {card.nfc.uid ? <span className="text-muted-foreground block font-mono text-xs font-normal">{card.nfc.uid}</span> : null}
                    </>
                  ) : can("cards.write_nfc") && open ? (
                    <button type="button" className="text-amber-700 underline-offset-4 hover:underline dark:text-amber-400" onClick={() => setDialog("nfc")}>
                      Not written yet — write now
                    </button>
                  ) : (
                    <span className="text-amber-700 dark:text-amber-400">Not written yet</span>
                  )}
                </Detail>
                {card.replaces ? (
                  <Detail label="Replaces">
                    <Link className="card-number hover:underline" href={`/cards/${card.replaces.id}`}>
                      {formatCardNumber(card.replaces.card_number)}
                    </Link>
                  </Detail>
                ) : null}
              </dl>
              {card.notes ? <p className="bg-surface text-muted-foreground mt-3 rounded-xl p-3 text-sm whitespace-pre-line">{card.notes}</p> : null}
            </CardContent>
          </Card>
        </div>

        <div className="space-y-6 self-start">
          <Card>
            <CardHeader>
              <CardTitle>History</CardTitle>
            </CardHeader>
            <CardContent className="px-3">
              <CardHistory cardId={card.id} currency={card.currency} />
            </CardContent>
          </Card>
          {can("cards.write_nfc") ? (
            <Card>
              <CardHeader>
                <CardTitle>Tag programming</CardTitle>
              </CardHeader>
              <CardContent>
                <NfcAttempts cardId={card.id} />
              </CardContent>
            </Card>
          ) : null}
        </div>
      </div>

      <MoneyDialog
        kind="redeem"
        cardId={card.id}
        balance={card.balance}
        currency={card.currency}
        open={dialog === "redeem"}
        onOpenChange={(o) => setDialog(o ? "redeem" : null)}
      />
      <MoneyDialog
        kind="reload"
        cardId={card.id}
        balance={card.balance}
        currency={card.currency}
        open={dialog === "reload"}
        onOpenChange={(o) => setDialog(o ? "reload" : null)}
      />
      <TransferDialog
        cardId={card.id}
        balance={card.balance}
        currency={card.currency}
        open={dialog === "transfer"}
        onOpenChange={(o) => setDialog(o ? "transfer" : null)}
      />
      {dialog === "edit" ? <EditCardDialog card={card} open onOpenChange={(o) => setDialog(o ? "edit" : null)} /> : null}
      <ReasonDialog
        open={dialog === "block"}
        onOpenChange={(o) => setDialog(o ? "block" : null)}
        title="Block card"
        suggestions={["Reported stolen", "Reported lost", "Suspicious use"]}
        description="A blocked card cannot be redeemed or reloaded until it is unblocked."
        confirmLabel="Block card"
        destructive
        pending={action.isPending}
        onConfirm={(reason) => run("block", reason, "Card blocked")}
      />
      <ReasonDialog
        open={dialog === "expire"}
        onOpenChange={(o) => setDialog(o ? "expire" : null)}
        title="Expire card now"
        description={`The remaining balance of ${formatMoney(card.balance, card.currency)} will be written off. This cannot be undone.`}
        confirmLabel="Expire card"
        destructive
        reasonRequired={false}
        pending={action.isPending}
        onConfirm={(reason) => run("expire", reason || undefined, "Card expired")}
      />
      <ReasonDialog
        open={dialog === "replace"}
        onOpenChange={(o) => setDialog(o ? "replace" : null)}
        title="Replace lost or damaged card"
        suggestions={["Lost", "Damaged", "Stolen"]}
        description={`A new card with a new number and link is issued with the remaining balance of ${formatMoney(card.balance, card.currency)}. The old card stops working immediately.`}
        confirmLabel="Issue replacement"
        pending={replace.isPending}
        onConfirm={async (reason) => {
          try {
            const res = await replace.mutateAsync({ reason, nfc_tag_type: card.nfc.tag_type })
            toast.success(`Replacement card ${res.data.card_number_formatted} issued`)
            setDialog(null)
            router.push(`/cards/${res.data.id}?write=1`)
          } catch (e) {
            toast.error(errorMessage(e))
          }
        }}
      />
      <Dialog open={dialog === "nfc"} onOpenChange={(o) => setDialog(o ? "nfc" : null)}>
        <DialogContent className="sm:max-w-xl">
          <DialogHeader>
            <DialogTitle>Program card</DialogTitle>
            <DialogDescription>Writes only the secure card link. Balance and customer data never leave the server.</DialogDescription>
          </DialogHeader>
          {nfc.data ? (
            <NfcWriter cardId={card.id} payload={{ ...nfc.data, tag_type_hint: card.nfc.tag_type ?? nfc.data.tag_type_hint }} current={card.nfc} />
          ) : (
            <Skeleton className="h-48 w-full" />
          )}
        </DialogContent>
      </Dialog>
    </div>
  )
}

function CardPageContent({ id }: { id: string }) {
  const { data, isLoading, error } = useCard(id)
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
  if (error || !data) return <p className="text-muted-foreground py-16 text-center">{errorMessage(error, "Card not found.")}</p>
  return <CardDetail card={data} />
}

export default function CardPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  return (
    <RequirePermission permission="cards.view">
      <CardPageContent id={id} />
    </RequirePermission>
  )
}
