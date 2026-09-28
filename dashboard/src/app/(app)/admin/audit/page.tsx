"use client"

import { Suspense, useState } from "react"
import Link from "next/link"
import { useSearchParams } from "next/navigation"
import { Search, ShieldCheck, X } from "lucide-react"
import { AuditTable } from "@/components/common/audit-table"
import { EmptyState } from "@/components/common/empty-state"
import { PageHeader } from "@/components/common/page-header"
import { PaginationBar } from "@/components/common/pagination-bar"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Skeleton } from "@/components/ui/skeleton"
import { useDebounce } from "@/hooks/use-debounce"
import { useAdminRestaurant, usePlatformAudit } from "@/lib/api/hooks"

function Content() {
  const params = useSearchParams()
  const restaurantId = params.get("restaurant_id") ?? undefined
  const [page, setPage] = useState(1)
  const [action, setAction] = useState("")
  const { data, isLoading } = usePlatformAudit(page, { restaurantId, action: useDebounce(action.trim()) })
  const restaurant = useAdminRestaurant(restaurantId ?? "")

  return (
    <div className="space-y-6">
      <PageHeader title="Platform audit" description="Security-relevant events across all restaurants." />
      <div className="bg-card overflow-hidden rounded-2xl border">
        <div className="flex flex-col gap-3 border-b p-3 sm:flex-row sm:items-center">
          <div className="relative flex-1">
            <Search className="text-muted-foreground absolute top-1/2 left-3 size-4 -translate-y-1/2" />
            <Input
              value={action}
              onChange={(e) => (setAction(e.target.value), setPage(1))}
              placeholder="Filter by action, e.g. restaurant. or user.invitation"
              className="h-9 pl-9"
              aria-label="Filter by action"
            />
          </div>
          {restaurantId ? (
            <Button variant="outline" size="sm" asChild>
              <Link href="/admin/audit">
                {restaurant.data?.data.name ?? "One restaurant"} <X />
              </Link>
            </Button>
          ) : null}
        </div>
        {isLoading ? (
          <Skeleton className="m-4 h-64" />
        ) : data?.data.length ? (
          <>
            <AuditTable logs={data.data} showRestaurant={!restaurantId} />
            <PaginationBar page={data.meta} onPageChange={setPage} />
          </>
        ) : (
          <EmptyState icon={ShieldCheck} title="No events" description={action || restaurantId ? "Nothing matches the filter." : undefined} />
        )}
      </div>
    </div>
  )
}

export default function PlatformAuditPage() {
  return (
    <RequirePermission permission="platform.audit.view">
      <Suspense>
        <Content />
      </Suspense>
    </RequirePermission>
  )
}
