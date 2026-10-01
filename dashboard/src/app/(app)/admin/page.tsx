"use client"

import { useState } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { Building2, CreditCard, Euro, Loader2, Plus, Receipt, Search } from "lucide-react"
import { toast } from "sonner"
import { InvitationBadge, invitationDetail } from "@/components/admin/invitation-badge"
import { MailWarning } from "@/components/admin/mail-warning"
import { RestaurantActions, RestaurantStatusBadge } from "@/components/admin/restaurant-actions"
import { PageHeader } from "@/components/common/page-header"
import { Segmented } from "@/components/common/segmented"
import { StatCard } from "@/components/common/stat-card"
import { PaginationBar } from "@/components/common/pagination-bar"
import { EmptyState } from "@/components/common/empty-state"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useDebounce } from "@/hooks/use-debounce"
import { useAdminRestaurants, useCreateRestaurant, usePlatformStats, type AdminRestaurantFilter, type CreateRestaurantInput } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import { formatDate, formatNumber } from "@/lib/format"
import { formatMoney } from "@/lib/money"
import { useT } from "@/lib/i18n"

const EMPTY_FORM = { name: "", email: "", phone: "", address_line1: "", postal_code: "", city: "Wien", ownerName: "", ownerEmail: "" }

function CreateRestaurantDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const t = useT()
  const create = useCreateRestaurant()
  const router = useRouter()
  const [form, setForm] = useState(EMPTY_FORM)
  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement>) => setForm((f) => ({ ...f, [k]: e.target.value }))

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{t("admin.restaurants.onboard")}</DialogTitle>
          <DialogDescription>{t("admin.create.description")}</DialogDescription>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            const input: CreateRestaurantInput = {
              name: form.name,
              email: form.email || undefined,
              phone: form.phone || undefined,
              address_line1: form.address_line1 || undefined,
              postal_code: form.postal_code || undefined,
              city: form.city || undefined,
              country: "AT",
              currency: "EUR",
              timezone: "Europe/Vienna",
              locale: "de-AT",
              owner: { name: form.ownerName, email: form.ownerEmail },
            }
            try {
              const res = await create.mutateAsync(input)
              const invitation = res.owner.invitation
              if (invitation?.delivery === "queued") {
                // Invitations are sent from the queue; the restaurant page shows when it went out.
                toast.success(t("admin.create.createdSending", { name: res.data.name, email: res.owner.email }))
              } else if (invitation && invitation.delivery !== "sent") {
                // The restaurant exists; the owner can be invited again from its page once mail works.
                toast.warning(t("admin.create.createdNotDelivered", { name: res.data.name }), {
                  description: invitationDetail(invitation, t),
                  duration: 15_000,
                })
              } else {
                toast.success(t("admin.create.createdSent", { name: res.data.name, email: res.owner.email }))
              }
              setForm(EMPTY_FORM)
              onOpenChange(false)
              router.push(`/admin/restaurants/${res.data.id}`)
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2 sm:col-span-2">
              <Label htmlFor="r-name">{t("admin.field.restaurantName")}</Label>
              <Input id="r-name" required value={form.name} onChange={set("name")} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="r-email">{t("admin.field.email")}</Label>
              <Input id="r-email" type="email" value={form.email} onChange={set("email")} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="r-phone">{t("admin.field.phone")}</Label>
              <Input id="r-phone" value={form.phone} onChange={set("phone")} />
            </div>
            <div className="space-y-2 sm:col-span-2">
              <Label htmlFor="r-street">{t("admin.field.street")}</Label>
              <Input id="r-street" value={form.address_line1} onChange={set("address_line1")} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="r-zip">{t("admin.field.postalCode")}</Label>
              <Input id="r-zip" value={form.postal_code} onChange={set("postal_code")} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="r-city">{t("admin.field.city")}</Label>
              <Input id="r-city" value={form.city} onChange={set("city")} />
            </div>
          </div>
          <div className="bg-surface space-y-3 rounded-2xl p-4">
            <p className="text-sm font-medium">{t("admin.create.ownerAccount")}</p>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="o-name">{t("admin.field.name")}</Label>
                <Input id="o-name" required value={form.ownerName} onChange={set("ownerName")} />
              </div>
              <div className="space-y-2">
                <Label htmlFor="o-email">{t("admin.field.email")}</Label>
                <Input id="o-email" type="email" required value={form.ownerEmail} onChange={set("ownerEmail")} />
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={create.isPending}>
              {create.isPending ? <Loader2 className="animate-spin" /> : null} {t("admin.create.submit")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function AdminContent() {
  const t = useT()
  const router = useRouter()
  const stats = usePlatformStats()
  const [search, setSearch] = useState("")
  const [page, setPage] = useState(1)
  const [creating, setCreating] = useState(false)
  const [filter, setFilter] = useState<AdminRestaurantFilter>("all")
  const { data, isLoading } = useAdminRestaurants(useDebounce(search), page, filter)
  const s = stats.data

  return (
    <div className="space-y-8">
      <PageHeader
        title={t("nav.restaurants")}
        description={t("admin.restaurants.description")}
        actions={
          <Button onClick={() => setCreating(true)}>
            <Plus /> {t("admin.restaurants.onboard")}
          </Button>
        }
      />
      <MailWarning />
      <div className="grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-4">
        <StatCard
          label={t("nav.restaurants")}
          icon={Building2}
          loading={stats.isLoading}
          value={s?.restaurants_total ?? 0}
          hint={`${t("admin.stats.active", { count: s?.restaurants_active ?? 0 })}${s?.restaurants_archived ? ` · ${t("admin.stats.archived", { count: s.restaurants_archived })}` : ""}`}
        />
        <StatCard
          label={t("nav.vouchers")}
          icon={CreditCard}
          loading={stats.isLoading}
          value={formatNumber(s?.vouchers_total ?? 0)}
          hint={t("admin.stats.active", { count: formatNumber(s?.vouchers_active ?? 0) })}
        />
        <StatCard label={t("admin.stats.transactionsMonth")} icon={Receipt} loading={stats.isLoading} value={formatNumber(s?.transactions_this_month ?? 0)} />
        <StatCard label={t("admin.stats.volumeMonth")} icon={Euro} loading={stats.isLoading} value={formatMoney(s?.volume_sold_this_month ?? 0, "EUR")} />
      </div>
      <div className="bg-card overflow-hidden rounded-2xl border">
        <div className="flex flex-col gap-3 border-b p-3 sm:flex-row sm:items-center">
          <div className="relative flex-1">
            <Search className="text-muted-foreground absolute top-1/2 left-3 size-4 -translate-y-1/2" />
            <Input value={search} onChange={(e) => (setSearch(e.target.value), setPage(1))} placeholder={t("admin.restaurants.search")} className="h-9 pl-9" />
          </div>
          <Segmented
            label={t("admin.col.status")}
            value={filter}
            onChange={(v) => (setFilter(v), setPage(1))}
            options={[
              { value: "all", label: t("admin.restaurants.filterAll") },
              { value: "active", label: t("admin.status.active") },
              { value: "suspended", label: t("admin.status.disabled") },
              { value: "archived", label: t("admin.status.archived") },
            ]}
          />
        </div>
        {isLoading ? (
          <div className="space-y-2 p-4">
            {Array.from({ length: 5 }).map((_, i) => (
              <Skeleton key={i} className="h-10 w-full" />
            ))}
          </div>
        ) : data?.data.length ? (
          <>
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-4">{t("admin.col.restaurant")}</TableHead>
                  <TableHead className="hidden md:table-cell">{t("admin.col.owner")}</TableHead>
                  <TableHead className="hidden lg:table-cell">{t("admin.field.email")}</TableHead>
                  <TableHead>{t("admin.col.status")}</TableHead>
                  <TableHead className="hidden sm:table-cell">{t("admin.col.created")}</TableHead>
                  <TableHead className="w-12 pr-4 text-right">
                    <span className="sr-only">{t("admin.col.actions")}</span>
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.data.map((r) => (
                  <TableRow key={r.id} className="cursor-pointer" onClick={() => router.push(`/admin/restaurants/${r.id}`)}>
                    <TableCell className="pl-4">
                      <Link
                        href={`/admin/restaurants/${r.id}`}
                        className="font-medium hover:underline focus-visible:underline focus-visible:outline-none"
                        onClick={(e) => e.stopPropagation()}
                      >
                        {r.name}
                      </Link>
                      <div className="text-muted-foreground text-xs">
                        {r.city ?? r.slug} · {t("admin.restaurants.cards", { count: r.vouchers_count ?? 0 })} ·{" "}
                        {formatMoney(r.outstanding_balance ?? 0, r.currency)}
                      </div>
                      <div className="text-muted-foreground text-xs md:hidden">
                        {r.owner ? `${r.owner.name} · ${r.owner.email}` : t("admin.restaurants.noOwner")}
                      </div>
                    </TableCell>
                    <TableCell className="hidden md:table-cell">
                      {r.owner ? (
                        <div className="space-y-1">
                          <div>{r.owner.name}</div>
                          <InvitationBadge invitation={r.owner.invitation} />
                        </div>
                      ) : (
                        <span className="text-muted-foreground">{t("admin.restaurants.noOwner")}</span>
                      )}
                    </TableCell>
                    <TableCell className="text-muted-foreground hidden lg:table-cell">{r.owner?.email ?? r.email ?? "—"}</TableCell>
                    <TableCell>
                      <RestaurantStatusBadge restaurant={r} />
                    </TableCell>
                    <TableCell className="text-muted-foreground hidden sm:table-cell">{formatDate(r.created_at)}</TableCell>
                    <TableCell className="pr-4 text-right" onClick={(e) => e.stopPropagation()}>
                      <RestaurantActions restaurant={r} variant="menu" onDeleted={() => undefined} />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            <PaginationBar page={data.meta} onPageChange={setPage} />
          </>
        ) : (
          <EmptyState
            icon={Building2}
            title={search || filter !== "all" ? t("admin.restaurants.noMatch") : t("admin.restaurants.empty")}
            description={search || filter !== "all" ? t("admin.restaurants.noMatchHint") : t("admin.restaurants.emptyHint")}
          />
        )}
      </div>
      <CreateRestaurantDialog open={creating} onOpenChange={setCreating} />
    </div>
  )
}

export default function AdminPage() {
  return (
    <RequirePermission permission="platform.restaurants.manage">
      <AdminContent />
    </RequirePermission>
  )
}
