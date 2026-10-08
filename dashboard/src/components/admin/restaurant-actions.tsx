"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { Archive, ArchiveRestore, FlaskConical, Loader2, Mail, MoreHorizontal, PauseCircle, Pencil, PlayCircle, Trash2 } from "lucide-react"
import { toast } from "sonner"
import { canInviteAgain, invitationDetail } from "@/components/admin/invitation-badge"
import { useConfirm } from "@/components/common/confirm"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { ApiError, errorMessage } from "@/lib/api/client"
import { useDeleteRestaurant, useResendInvitation, useRestaurantStatus, useUpdateRestaurant, type UpdateRestaurantInput } from "@/lib/api/hooks"
import type { InvitationSummary, Restaurant } from "@/lib/api/types"
import { useT } from "@/lib/i18n"

/** Archived > Disabled > Active: the state that decides what the restaurant's users can do. */
export function RestaurantStatusBadge({ restaurant }: { restaurant: Pick<Restaurant, "status" | "archived_at"> & { is_test?: boolean } }) {
  const t = useT()
  const status = <RestaurantStatus restaurant={restaurant} />
  if (!restaurant.is_test) return status
  return (
    <span className="inline-flex items-center gap-1.5">
      {status}
      <Badge variant="outline">{t("admin.test.badge")}</Badge>
    </span>
  )
}

function RestaurantStatus({ restaurant }: { restaurant: Pick<Restaurant, "status" | "archived_at"> }) {
  const t = useT()
  if (restaurant.archived_at)
    return (
      <Badge variant="outline" className="text-muted-foreground">
        {t("admin.status.archived")}
      </Badge>
    )
  if (restaurant.status === "suspended") return <Badge variant="destructive">{t("admin.status.disabled")}</Badge>
  return <Badge variant="secondary">{t("admin.status.active")}</Badge>
}

// ------------------------------------------------------------------------------------------ edit

const CURRENCIES = ["EUR", "CHF", "USD", "GBP"]
const LOCALES = ["de-AT", "de-DE", "de-CH", "en-GB", "en-US"]

type EditForm = Record<"name" | "legal_name" | "vat_number" | "email" | "phone" | "website" | "address_line1" | "postal_code" | "city" | "country", string> & {
  currency: string
  timezone: string
  locale: string
}

function toForm(r: Restaurant): EditForm {
  return {
    name: r.name,
    legal_name: r.legal_name ?? "",
    vat_number: r.vat_number ?? "",
    email: r.email ?? "",
    phone: r.phone ?? "",
    website: r.website ?? "",
    address_line1: r.address_line1 ?? "",
    postal_code: r.postal_code ?? "",
    city: r.city ?? "",
    country: r.country,
    currency: r.currency,
    timezone: r.timezone,
    locale: r.locale,
  }
}

export function EditRestaurantDialog({ restaurant, open, onOpenChange }: { restaurant: Restaurant; open: boolean; onOpenChange: (o: boolean) => void }) {
  const t = useT()
  const update = useUpdateRestaurant()
  const [form, setForm] = useState<EditForm>(() => toForm(restaurant))
  const [errors, setErrors] = useState<Record<string, string[]>>({})
  const set = (k: keyof EditForm) => (e: React.ChangeEvent<HTMLInputElement>) => setForm((f) => ({ ...f, [k]: e.target.value }))
  const field = (k: keyof EditForm, label: string, props: React.ComponentProps<typeof Input> = {}, span = false) => (
    <div className={span ? "space-y-2 sm:col-span-2" : "space-y-2"}>
      <Label htmlFor={`edit-${k}`}>{label}</Label>
      <Input id={`edit-${k}`} value={form[k]} onChange={set(k)} aria-invalid={errors[k] ? true : undefined} {...props} />
      {errors[k] ? <p className="text-destructive text-xs">{errors[k][0]}</p> : null}
    </div>
  )
  const lockedCurrency = (restaurant.vouchers_count ?? 0) > 0

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (o) {
          setForm(toForm(restaurant))
          setErrors({})
        }
        onOpenChange(o)
      }}
    >
      <DialogContent className="max-h-[90dvh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>{t("admin.edit.title", { name: restaurant.name })}</DialogTitle>
          <DialogDescription>{t("admin.edit.description")}</DialogDescription>
        </DialogHeader>
        <form method="post"
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            setErrors({})
            const input: UpdateRestaurantInput = {
              name: form.name,
              legal_name: form.legal_name || null,
              vat_number: form.vat_number || null,
              email: form.email || null,
              phone: form.phone || null,
              website: form.website || null,
              address_line1: form.address_line1 || null,
              postal_code: form.postal_code || null,
              city: form.city || null,
              country: form.country.toUpperCase(),
              currency: form.currency,
              timezone: form.timezone,
              locale: form.locale,
            }
            try {
              await update.mutateAsync({ id: restaurant.id, input })
              toast.success(t("admin.edit.saved"))
              onOpenChange(false)
            } catch (err) {
              if (err instanceof ApiError && err.body.errors) setErrors(err.body.errors)
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="grid gap-4 sm:grid-cols-2">
            {field("name", t("admin.field.restaurantName"), { required: true }, true)}
            {field("legal_name", t("admin.field.legalName"))}
            {field("vat_number", t("admin.field.vatNumber"))}
            {field("email", t("admin.field.email"), { type: "email" })}
            {field("phone", t("admin.field.phone"))}
            {field("website", t("admin.field.website"), { type: "url", placeholder: "https://" }, true)}
            {field("address_line1", t("admin.field.street"), {}, true)}
            {field("postal_code", t("admin.field.postalCode"))}
            {field("city", t("admin.field.city"))}
            {field("country", t("admin.field.country"), { required: true, maxLength: 2, minLength: 2 })}
            {field("timezone", t("admin.field.timezone"), { required: true })}
            <div className="space-y-2">
              <Label htmlFor="edit-locale">{t("admin.field.locale")}</Label>
              <Select value={form.locale} onValueChange={(v) => setForm((f) => ({ ...f, locale: v }))}>
                <SelectTrigger id="edit-locale" className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {LOCALES.map((l) => (
                    <SelectItem key={l} value={l}>
                      {l}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="edit-currency">{t("admin.field.currency")}</Label>
              <Select value={form.currency} onValueChange={(v) => setForm((f) => ({ ...f, currency: v }))} disabled={lockedCurrency}>
                <SelectTrigger id="edit-currency" className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {CURRENCIES.map((c) => (
                    <SelectItem key={c} value={c}>
                      {c}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {lockedCurrency ? <p className="text-muted-foreground text-xs">{t("admin.edit.currencyFixed", { currency: restaurant.currency })}</p> : null}
              {errors.currency ? <p className="text-destructive text-xs">{errors.currency[0]}</p> : null}
            </div>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={update.isPending}>
              {update.isPending ? <Loader2 className="animate-spin" /> : null} {t("common.save")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

// ---------------------------------------------------------------------------------- invite again

/**
 * Sends an invitation again (new link, the previous one stops working). Name and e-mail address can be
 * corrected while the invitation has not been accepted.
 */
export function InviteAgainDialog({
  restaurantId,
  person,
  open,
  onOpenChange,
}: {
  restaurantId: string
  /** The account to invite; `userId` omitted = the restaurant owner. */
  person: { userId?: string; name: string; email: string; invitation: InvitationSummary | null | undefined }
  open: boolean
  onOpenChange: (o: boolean) => void
}) {
  const t = useT()
  const resend = useResendInvitation()
  const [name, setName] = useState(person.name)
  const [email, setEmail] = useState(person.email)

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (o) {
          setName(person.name)
          setEmail(person.email)
        }
        onOpenChange(o)
      }}
    >
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t("admin.invite.again")}</DialogTitle>
          <DialogDescription>{t("admin.invite.againDescription", { name: person.name })}</DialogDescription>
        </DialogHeader>
        {person.invitation ? <p className="bg-surface rounded-xl p-3 text-sm">{invitationDetail(person.invitation, t)}</p> : null}
        <form method="post"
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            try {
              const res = await resend.mutateAsync({
                restaurantId,
                userId: person.userId,
                name: name !== person.name ? name : undefined,
                email: email !== person.email ? email : undefined,
              })
              const to = res.data.email
              toast.success(res.data.invitation?.delivery === "queued" ? t("admin.invite.sending", { email: to }) : t("admin.invite.sent", { email: to }))
              onOpenChange(false)
            } catch (err) {
              if (err instanceof ApiError && err.code === "INVITATION_NOT_DELIVERED") {
                const invitation = (err.body as { data?: { invitation?: InvitationSummary | null } }).data?.invitation
                toast.error(t("admin.invite.notDelivered", { email: email.trim() }), {
                  description: invitation ? invitationDetail(invitation, t) : undefined,
                  duration: 10_000,
                })
              } else toast.error(errorMessage(err), { duration: 10_000 })
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="invite-name">{t("admin.field.name")}</Label>
            <Input id="invite-name" required value={name} onChange={(e) => setName(e.target.value)} />
          </div>
          <div className="space-y-2">
            <Label htmlFor="invite-email">{t("admin.field.email")}</Label>
            <Input id="invite-email" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
            <p className="text-muted-foreground text-xs">{t("admin.invite.fixAddress")}</p>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={resend.isPending}>
              {resend.isPending ? <Loader2 className="animate-spin" /> : <Mail />} {t("admin.invite.send")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

// ---------------------------------------------------------------------------------------- delete

export function DeleteRestaurantDialog({
  restaurant,
  open,
  onOpenChange,
  onDeleted,
}: {
  restaurant: Pick<Restaurant, "id" | "name" | "slug">
  open: boolean
  onOpenChange: (o: boolean) => void
  onDeleted?: () => void
}) {
  const t = useT()
  const remove = useDeleteRestaurant()
  const [confirm, setConfirm] = useState("")
  const [refusal, setRefusal] = useState<string | null>(null)
  const matches = confirm.trim().toLowerCase() === restaurant.slug.toLowerCase()

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (o) {
          setConfirm("")
          setRefusal(null)
        }
        onOpenChange(o)
      }}
    >
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t("admin.delete.title", { name: restaurant.name })}</DialogTitle>
          <DialogDescription>{t("admin.delete.description")}</DialogDescription>
        </DialogHeader>
        <form method="post"
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            setRefusal(null)
            try {
              await remove.mutateAsync({ id: restaurant.id, confirm })
              toast.success(t("admin.delete.deleted", { name: restaurant.name }))
              onOpenChange(false)
              onDeleted?.()
            } catch (err) {
              if (err instanceof ApiError && err.code === "RESTAURANT_NOT_DELETABLE") setRefusal(t("admin.delete.notDeletable"))
              else toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="delete-confirm">
              {t("admin.delete.typeToConfirm")} <span className="font-mono font-semibold">{restaurant.slug}</span>
            </Label>
            <Input id="delete-confirm" autoComplete="off" value={confirm} onChange={(e) => setConfirm(e.target.value)} />
          </div>
          {refusal ? <p className="text-destructive text-sm">{refusal}</p> : null}
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" variant="destructive" disabled={!matches || remove.isPending}>
              {remove.isPending ? <Loader2 className="animate-spin" /> : <Trash2 />} {t("admin.delete.submit")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

// --------------------------------------------------------------------------------------- actions

type Dialogs = "edit" | "invite" | "disable" | "archive" | "delete" | null

/**
 * Every platform action on one restaurant: Edit · Invite again · Disable/Enable · Archive/Restore · Delete.
 * `menu` for table rows, `buttons` for the detail page.
 */
export function RestaurantActions({ restaurant, variant, onDeleted }: { restaurant: Restaurant; variant: "menu" | "buttons"; onDeleted?: () => void }) {
  const t = useT()
  const confirm = useConfirm()
  const router = useRouter()
  const status = useRestaurantStatus()
  const update = useUpdateRestaurant()
  const [dialog, setDialog] = useState<Dialogs>(null)
  const archived = restaurant.archived_at !== null
  const disabled = restaurant.status === "suspended"
  const owner = restaurant.owner
  const invitable = !archived && !disabled && owner != null && canInviteAgain(owner.invitation)
  const close = (o: boolean) => (!o ? setDialog(null) : undefined)

  /** Enable and Restore give access back at once: ask first. */
  const run = async (action: "reactivate" | "restore") => {
    const name = restaurant.name
    const ok = await confirm(
      action === "reactivate"
        ? { title: t("admin.actions.enableTitle", { name }), description: t("admin.actions.enableDescription"), confirmLabel: t("admin.actions.enable") }
        : { title: t("admin.actions.restoreTitle", { name }), description: t("admin.actions.restoreDescription"), confirmLabel: t("admin.actions.restore") },
    )
    if (!ok) return
    const message = action === "reactivate" ? t("admin.actions.enabled", { name }) : t("admin.actions.restored", { name })
    try {
      await status.mutateAsync({ id: restaurant.id, action })
      toast.success(message)
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  /** The platform's own test restaurant: its cards can be put back into stock. Never for a real restaurant. */
  const toggleTest = async () => {
    const name = restaurant.name
    const on = !restaurant.is_test
    const ok = await confirm({
      title: t(on ? "admin.test.onTitle" : "admin.test.offTitle", { name }),
      description: t(on ? "admin.test.onDescription" : "admin.test.offDescription"),
      confirmLabel: t(on ? "admin.test.on" : "admin.test.off"),
    })
    if (!ok) return
    try {
      await update.mutateAsync({ id: restaurant.id, input: { is_test: on } })
      toast.success(t(on ? "admin.test.onDone" : "admin.test.offDone", { name }))
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  const items = [
    !archived && { key: "edit", icon: Pencil, label: t("common.edit"), onSelect: () => setDialog("edit") },
    invitable && { key: "invite", icon: Mail, label: t("admin.invite.again"), onSelect: () => setDialog("invite") },
    !archived && { key: "test", icon: FlaskConical, label: t(restaurant.is_test ? "admin.test.off" : "admin.test.on"), onSelect: () => void toggleTest() },
    !archived &&
      (disabled
        ? { key: "enable", icon: PlayCircle, label: t("admin.actions.enable"), onSelect: () => void run("reactivate") }
        : { key: "disable", icon: PauseCircle, label: t("admin.actions.disable"), destructive: true, onSelect: () => setDialog("disable") }),
    archived
      ? { key: "restore", icon: ArchiveRestore, label: t("admin.actions.restore"), onSelect: () => void run("restore") }
      : { key: "archive", icon: Archive, label: t("admin.actions.archive"), onSelect: () => setDialog("archive") },
    { key: "delete", icon: Trash2, label: t("common.delete"), destructive: true, separated: true, onSelect: () => setDialog("delete") },
  ].filter(Boolean) as { key: string; icon: typeof Pencil; label: string; destructive?: boolean; separated?: boolean; onSelect: () => void }[]

  return (
    <>
      {variant === "menu" ? (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon" aria-label={t("admin.actionsFor", { name: restaurant.name })} onClick={(e) => e.stopPropagation()}>
              <MoreHorizontal />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" onClick={(e) => e.stopPropagation()}>
            {items.map((i) => (
              <div key={i.key}>
                {i.separated ? <DropdownMenuSeparator /> : null}
                <DropdownMenuItem variant={i.destructive ? "destructive" : "default"} onSelect={i.onSelect}>
                  <i.icon /> {i.label}
                </DropdownMenuItem>
              </div>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
      ) : (
        <div className="flex flex-wrap gap-2">
          {items.map((i) => (
            <Button key={i.key} variant="outline" className={i.destructive ? "text-destructive" : undefined} disabled={status.isPending} onClick={i.onSelect}>
              <i.icon /> {i.label}
            </Button>
          ))}
        </div>
      )}

      {dialog === "edit" ? <EditRestaurantDialog restaurant={restaurant} open onOpenChange={close} /> : null}
      {dialog === "invite" && owner ? (
        <InviteAgainDialog
          restaurantId={restaurant.id}
          person={{ name: owner.name, email: owner.email, invitation: owner.invitation }}
          open
          onOpenChange={close}
        />
      ) : null}
      <ReasonDialog
        open={dialog === "disable"}
        onOpenChange={close}
        title={t("admin.actions.disableTitle", { name: restaurant.name })}
        description={t("admin.actions.disableDescription")}
        confirmLabel={t("admin.actions.disable")}
        destructive
        suggestions={[t("admin.actions.disableReason1"), t("admin.actions.disableReason2"), t("admin.actions.disableReason3")]}
        pending={status.isPending}
        onConfirm={async (reason) => {
          try {
            await status.mutateAsync({ id: restaurant.id, action: "suspend", reason })
            toast.success(t("admin.actions.disabled", { name: restaurant.name }))
            setDialog(null)
          } catch (e) {
            toast.error(errorMessage(e))
          }
        }}
      />
      <ReasonDialog
        open={dialog === "archive"}
        onOpenChange={close}
        title={t("admin.actions.archiveTitle", { name: restaurant.name })}
        description={t("admin.actions.archiveDescription")}
        confirmLabel={t("admin.actions.archive")}
        destructive
        reasonRequired={false}
        suggestions={[t("admin.actions.archiveReason1"), t("admin.actions.archiveReason2"), t("admin.actions.archiveReason3")]}
        pending={status.isPending}
        onConfirm={async (reason) => {
          try {
            await status.mutateAsync({ id: restaurant.id, action: "archive", reason: reason || undefined })
            toast.success(t("admin.actions.archived", { name: restaurant.name }))
            setDialog(null)
          } catch (e) {
            toast.error(errorMessage(e))
          }
        }}
      />
      {dialog === "delete" ? (
        <DeleteRestaurantDialog restaurant={restaurant} open onOpenChange={close} onDeleted={() => (onDeleted ? onDeleted() : router.push("/admin"))} />
      ) : null}
    </>
  )
}
