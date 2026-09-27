"use client"

import { useState } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { Building2, CreditCard, Euro, Loader2, Plus, Receipt, Search } from "lucide-react"
import { toast } from "sonner"
import { PageHeader } from "@/components/common/page-header"
import { StatCard } from "@/components/common/stat-card"
import { PaginationBar } from "@/components/common/pagination-bar"
import { EmptyState } from "@/components/common/empty-state"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useDebounce } from "@/hooks/use-debounce"
import { useAdminRestaurants, useCreateRestaurant, usePlatformStats, type CreateRestaurantInput } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import { formatDate, formatNumber } from "@/lib/format"
import { formatMoney } from "@/lib/money"

function CreateRestaurantDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const create = useCreateRestaurant()
  const router = useRouter()
  const [form, setForm] = useState({ name: "", email: "", phone: "", address_line1: "", postal_code: "", city: "Wien", ownerName: "", ownerEmail: "" })
  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement>) => setForm((f) => ({ ...f, [k]: e.target.value }))

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Onboard restaurant</DialogTitle>
          <DialogDescription>Creates an isolated tenant and invites the owner by e-mail.</DialogDescription>
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
              toast.success(`${res.data.name} created · invitation sent to ${form.ownerEmail}`)
              onOpenChange(false)
              router.push(`/admin/restaurants/${res.data.id}`)
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2 sm:col-span-2">
              <Label htmlFor="r-name">Restaurant name</Label>
              <Input id="r-name" required value={form.name} onChange={set("name")} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="r-email">E-mail</Label>
              <Input id="r-email" type="email" value={form.email} onChange={set("email")} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="r-phone">Phone</Label>
              <Input id="r-phone" value={form.phone} onChange={set("phone")} />
            </div>
            <div className="space-y-2 sm:col-span-2">
              <Label htmlFor="r-street">Street</Label>
              <Input id="r-street" value={form.address_line1} onChange={set("address_line1")} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="r-zip">Postal code</Label>
              <Input id="r-zip" value={form.postal_code} onChange={set("postal_code")} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="r-city">City</Label>
              <Input id="r-city" value={form.city} onChange={set("city")} />
            </div>
          </div>
          <div className="bg-surface space-y-3 rounded-2xl p-4">
            <p className="text-sm font-medium">Owner account</p>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="o-name">Name</Label>
                <Input id="o-name" required value={form.ownerName} onChange={set("ownerName")} />
              </div>
              <div className="space-y-2">
                <Label htmlFor="o-email">E-mail</Label>
                <Input id="o-email" type="email" required value={form.ownerEmail} onChange={set("ownerEmail")} />
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={create.isPending}>
              {create.isPending ? <Loader2 className="animate-spin" /> : null} Create restaurant
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function AdminContent() {
  const router = useRouter()
  const stats = usePlatformStats()
  const [search, setSearch] = useState("")
  const [page, setPage] = useState(1)
  const [creating, setCreating] = useState(false)
  const { data, isLoading } = useAdminRestaurants(useDebounce(search), page)
  const s = stats.data

  return (
    <div className="space-y-8">
      <PageHeader
        title="Restaurants"
        description="All tenants on the platform."
        actions={
          <Button onClick={() => setCreating(true)}>
            <Plus /> Onboard restaurant
          </Button>
        }
      />
      <div className="grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-4">
        <StatCard
          label="Restaurants"
          icon={Building2}
          loading={stats.isLoading}
          value={s?.restaurants_total ?? 0}
          hint={`${s?.restaurants_active ?? 0} active`}
        />
        <StatCard
          label="Gift cards"
          icon={CreditCard}
          loading={stats.isLoading}
          value={formatNumber(s?.cards_total ?? 0)}
          hint={`${formatNumber(s?.cards_active ?? 0)} active`}
        />
        <StatCard label="Transactions this month" icon={Receipt} loading={stats.isLoading} value={formatNumber(s?.transactions_this_month ?? 0)} />
        <StatCard label="Volume sold this month" icon={Euro} loading={stats.isLoading} value={formatMoney(s?.volume_sold_this_month ?? 0, "EUR")} />
      </div>
      <div className="bg-card overflow-hidden rounded-2xl border">
        <div className="border-b p-3">
          <div className="relative">
            <Search className="text-muted-foreground absolute top-1/2 left-3 size-4 -translate-y-1/2" />
            <Input value={search} onChange={(e) => (setSearch(e.target.value), setPage(1))} placeholder="Search restaurants…" className="h-9 pl-9" />
          </div>
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
                  <TableHead className="pl-4">Restaurant</TableHead>
                  <TableHead className="hidden sm:table-cell">Status</TableHead>
                  <TableHead className="hidden text-right sm:table-cell">Cards</TableHead>
                  <TableHead className="pr-4 text-right sm:pr-2">Outstanding</TableHead>
                  <TableHead className="hidden text-right md:table-cell">Users</TableHead>
                  <TableHead className="hidden pr-4 md:table-cell">Created</TableHead>
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
                      <div className="text-muted-foreground text-xs">{r.city ?? r.slug}</div>
                    </TableCell>
                    <TableCell className="hidden sm:table-cell">
                      {r.status === "active" ? <Badge variant="secondary">Active</Badge> : <Badge variant="destructive">Suspended</Badge>}
                    </TableCell>
                    <TableCell className="tabular hidden text-right sm:table-cell">{r.gift_cards_count ?? 0}</TableCell>
                    <TableCell className="tabular pr-4 text-right sm:pr-2">
                      {formatMoney(r.outstanding_balance ?? 0, r.currency)}
                      <span className="text-muted-foreground block text-xs sm:hidden">
                        {r.gift_cards_count ?? 0} cards{r.status !== "active" ? " · Suspended" : ""}
                      </span>
                    </TableCell>
                    <TableCell className="tabular hidden text-right md:table-cell">{r.users_count ?? 0}</TableCell>
                    <TableCell className="text-muted-foreground hidden pr-4 md:table-cell">{formatDate(r.created_at)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            <PaginationBar page={data.meta} onPageChange={setPage} />
          </>
        ) : (
          <EmptyState icon={Building2} title="No restaurants" description="Onboard the first restaurant to get started." />
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
