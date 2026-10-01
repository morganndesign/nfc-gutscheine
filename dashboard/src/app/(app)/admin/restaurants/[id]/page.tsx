"use client"

import { use, useState } from "react"
import Link from "next/link"
import { ArrowLeft, History, Mail, MoreHorizontal, UserPlus } from "lucide-react"
import { canInviteAgain, InvitationBadge } from "@/components/admin/invitation-badge"
import { MailWarning } from "@/components/admin/mail-warning"
import { InviteAgainDialog, RestaurantActions, RestaurantStatusBadge } from "@/components/admin/restaurant-actions"
import { InviteOwnerDialog } from "@/components/admin/invite-owner-dialog"
import { RestaurantTokens } from "@/components/admin/restaurant-tokens"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Card, CardAction, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { Skeleton } from "@/components/ui/skeleton"
import { UserStatusBadge } from "@/components/common/user-status-badge"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useAdminRestaurant } from "@/lib/api/hooks"
import type { StaffUser } from "@/lib/api/types"
import { formatDate, formatRelative } from "@/lib/format"
import { formatMoney } from "@/lib/money"
import { useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

function RestaurantContent({ id }: { id: string }) {
  const t = useT()
  const { data, isLoading, isError } = useAdminRestaurant(id)
  const [inviting, setInviting] = useState<StaffUser | null>(null)
  const [invitingOwner, setInvitingOwner] = useState(false)

  if (isError)
    return (
      <div className="space-y-4">
        <Button variant="ghost" size="sm" asChild className="-ml-2">
          <Link href="/admin">
            <ArrowLeft /> {t("nav.restaurants")}
          </Link>
        </Button>
        <p className="text-muted-foreground text-sm">{t("admin.restaurant.notFound")}</p>
      </div>
    )
  if (isLoading || !data) return <Skeleton className="h-96 w-full rounded-2xl" />

  const r = data.data
  const archived = r.archived_at !== null
  const usable = !archived && r.status === "active"
  const business = data.business_data
  const hasBusinessData = business.vouchers + business.transactions + business.customers > 0

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <Button variant="ghost" size="sm" asChild className="-ml-2">
          <Link href="/admin">
            <ArrowLeft /> {t("nav.restaurants")}
          </Link>
        </Button>
        <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
          <div className="flex items-center gap-3">
            <h1 className="text-2xl font-semibold tracking-tight">{r.name}</h1>
            <RestaurantStatusBadge restaurant={r} />
          </div>
          <div className="flex flex-wrap gap-2">
            <Button variant="outline" asChild>
              <Link href={`/admin/audit?restaurant=${r.id}`}>
                <History /> {t("nav.audit")}
              </Link>
            </Button>
            <RestaurantActions restaurant={r} variant="buttons" />
          </div>
        </div>
        {archived ? (
          <p className="text-muted-foreground text-sm">{t("admin.restaurant.archivedNote", { when: formatRelative(r.archived_at) })}</p>
        ) : r.status === "suspended" ? (
          <p className="text-destructive text-sm">
            {t("admin.restaurant.disabledNote", { when: formatRelative(r.suspended_at), reason: r.suspension_reason })}
          </p>
        ) : null}
      </div>

      <MailWarning />

      <div className="grid gap-6 lg:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle>{t("admin.restaurant.profile")}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm">
            <p>{r.legal_name ?? r.name}</p>
            <p className="text-muted-foreground">
              {[r.address_line1, [r.postal_code, r.city].filter(Boolean).join(" ")].filter(Boolean).join(", ") || t("admin.restaurant.noAddress")}
            </p>
            <p className="text-muted-foreground">{r.email ?? "—"}</p>
            {r.vat_number ? <p className="text-muted-foreground">{t("admin.restaurant.vat", { number: r.vat_number })}</p> : null}
            <p className="text-muted-foreground">
              {r.currency} · {r.locale} · {r.timezone}
            </p>
            <p className="text-muted-foreground">{t("admin.restaurant.customerSince", { date: formatDate(r.created_at) })}</p>
            <p className="pt-2 font-medium">
              {t("admin.restaurant.outstanding", { count: business.vouchers, amount: formatMoney(r.outstanding_balance ?? 0, r.currency) })}
            </p>
            <p className="text-muted-foreground text-xs">
              {hasBusinessData
                ? t("admin.restaurant.keepsData", { transactions: business.transactions, customers: business.customers })
                : t("admin.restaurant.deletable")}
            </p>
          </CardContent>
        </Card>
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>{t("admin.restaurant.users")}</CardTitle>
            <CardAction>
              <Button variant="outline" size="sm" onClick={() => setInvitingOwner(true)}>
                <UserPlus /> {t("admin.restaurant.inviteOwner")}
              </Button>
            </CardAction>
          </CardHeader>
          <CardContent className="px-0">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-6">{t("admin.field.name")}</TableHead>
                  <TableHead className="hidden sm:table-cell">{t("admin.col.role")}</TableHead>
                  <TableHead>{t("admin.col.status")}</TableHead>
                  <TableHead className="hidden md:table-cell">{t("admin.col.lastSignIn")}</TableHead>
                  <TableHead className="w-12 pr-6">
                    <span className="sr-only">{t("admin.col.actions")}</span>
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.users.map((u) => (
                  <TableRow key={u.id}>
                    <TableCell className="pl-6">
                      <div className="font-medium">
                        {u.name}
                        {r.owner?.id === u.id ? <span className="text-muted-foreground font-normal"> · {t("admin.restaurant.primaryOwner")}</span> : null}
                      </div>
                      <div className="text-muted-foreground text-xs">{u.email}</div>
                    </TableCell>
                    <TableCell className="hidden sm:table-cell">{u.role ? t(`roles.${u.role.slug}` as MessageKey) : null}</TableCell>
                    <TableCell>
                      {canInviteAgain(u.invitation) && u.status === "active" ? <InvitationBadge invitation={u.invitation} /> : <UserStatusBadge user={u} />}
                    </TableCell>
                    <TableCell className="text-muted-foreground hidden md:table-cell">{formatRelative(u.last_login_at)}</TableCell>
                    <TableCell className="pr-6 text-right">
                      {usable && u.status === "active" && canInviteAgain(u.invitation) ? (
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="icon" aria-label={t("admin.actionsFor", { name: u.name })}>
                              <MoreHorizontal />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            <DropdownMenuItem onSelect={() => setInviting(u)}>
                              <Mail /> {t("admin.invite.again")}
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      ) : null}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            {data.users.length === 0 ? <p className="text-muted-foreground px-6 py-4 text-sm">{t("admin.restaurant.noUsers")}</p> : null}
          </CardContent>
        </Card>
        <RestaurantTokens restaurantId={r.id} />
      </div>

      {inviting ? (
        <InviteAgainDialog
          restaurantId={r.id}
          person={{
            userId: r.owner?.id === inviting.id ? undefined : inviting.id,
            name: inviting.name,
            email: inviting.email,
            invitation: inviting.invitation,
          }}
          open
          onOpenChange={(o) => (!o ? setInviting(null) : undefined)}
        />
      ) : null}
      <InviteOwnerDialog restaurantId={r.id} open={invitingOwner} onOpenChange={setInvitingOwner} />
    </div>
  )
}

export default function AdminRestaurantPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  return (
    <RequirePermission permission="platform.restaurants.manage">
      <RestaurantContent id={id} />
    </RequirePermission>
  )
}
