"use client"

import { use, useState } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { useQueryClient } from "@tanstack/react-query"
import { ArrowLeft, LogIn, PauseCircle, PlayCircle } from "lucide-react"
import { toast } from "sonner"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import { UserStatusBadge } from "@/components/common/user-status-badge"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useAdminRestaurant, useRestaurantStatus } from "@/lib/api/hooks"
import { errorMessage, setActingRestaurant } from "@/lib/api/client"
import { formatDate, formatRelative } from "@/lib/format"
import { formatMoney } from "@/lib/money"

function RestaurantContent({ id }: { id: string }) {
  const { data, isLoading, refetch } = useAdminRestaurant(id)
  const status = useRestaurantStatus()
  const [suspending, setSuspending] = useState(false)
  const qc = useQueryClient()
  const router = useRouter()

  if (isLoading || !data) return <Skeleton className="h-96 w-full rounded-2xl" />
  const r = data.data

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <Button variant="ghost" size="sm" asChild className="-ml-2">
          <Link href="/admin">
            <ArrowLeft /> Restaurants
          </Link>
        </Button>
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-3">
            <h1 className="text-2xl font-semibold tracking-tight">{r.name}</h1>
            {r.status === "active" ? <Badge variant="secondary">Active</Badge> : <Badge variant="destructive">Suspended</Badge>}
          </div>
          <div className="flex gap-2">
            <Button
              variant="outline"
              disabled={r.status !== "active"}
              onClick={() => {
                setActingRestaurant(r.id)
                void qc.resetQueries()
                router.push("/dashboard")
              }}
            >
              <LogIn /> Open restaurant
            </Button>
            {r.status === "active" ? (
              <Button variant="outline" className="text-destructive" onClick={() => setSuspending(true)}>
                <PauseCircle /> Suspend
              </Button>
            ) : (
              <Button
                onClick={async () => {
                  try {
                    await status.mutateAsync({ id: r.id, action: "reactivate" })
                    toast.success("Restaurant reactivated")
                    void refetch()
                  } catch (e) {
                    toast.error(errorMessage(e))
                  }
                }}
              >
                <PlayCircle /> Reactivate
              </Button>
            )}
          </div>
        </div>
        {r.status === "suspended" ? (
          <p className="text-destructive text-sm">
            Suspended {formatRelative(r.suspended_at)}: {r.suspension_reason}
          </p>
        ) : null}
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle>Profile</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm">
            <p>{r.legal_name ?? r.name}</p>
            <p className="text-muted-foreground">
              {[r.address_line1, [r.postal_code, r.city].filter(Boolean).join(" ")].filter(Boolean).join(", ") || "No address"}
            </p>
            <p className="text-muted-foreground">{r.email ?? "—"}</p>
            <p className="text-muted-foreground">
              {r.currency} · {r.locale} · {r.timezone}
            </p>
            <p className="text-muted-foreground">
              Plan: <span className="capitalize">{r.plan}</span>
            </p>
            <p className="text-muted-foreground">Customer since {formatDate(r.created_at)}</p>
            <p className="pt-2 font-medium">
              {r.gift_cards_count ?? 0} cards · {formatMoney(r.outstanding_balance ?? 0, r.currency)}
            </p>
          </CardContent>
        </Card>
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Users</CardTitle>
          </CardHeader>
          <CardContent className="px-0">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-6">Name</TableHead>
                  <TableHead className="hidden sm:table-cell">Role</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="hidden pr-6 md:table-cell">Last sign-in</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.users.map((u) => (
                  <TableRow key={u.id}>
                    <TableCell className="pl-6">
                      <div className="font-medium">{u.name}</div>
                      <div className="text-muted-foreground text-xs">{u.email}</div>
                    </TableCell>
                    <TableCell className="hidden sm:table-cell">{u.role?.name}</TableCell>
                    <TableCell>
                      <UserStatusBadge user={u} />
                    </TableCell>
                    <TableCell className="text-muted-foreground hidden pr-6 md:table-cell">{formatRelative(u.last_login_at)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </div>

      <ReasonDialog
        open={suspending}
        onOpenChange={setSuspending}
        title={`Suspend ${r.name}`}
        description="All users of this restaurant are locked out immediately. Cards keep their balances and work again after reactivation."
        confirmLabel="Suspend"
        destructive
        pending={status.isPending}
        onConfirm={async (reason) => {
          try {
            await status.mutateAsync({ id: r.id, action: "suspend", reason })
            toast.success("Restaurant suspended")
            setSuspending(false)
            void refetch()
          } catch (e) {
            toast.error(errorMessage(e))
          }
        }}
      />
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
