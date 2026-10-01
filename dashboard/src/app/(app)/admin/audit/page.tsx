"use client"

import { Suspense, useState } from "react"
import { usePathname, useRouter, useSearchParams } from "next/navigation"
import { Search, ShieldCheck } from "lucide-react"
import { AuditTable } from "@/components/common/audit-table"
import { EmptyState } from "@/components/common/empty-state"
import { PageHeader } from "@/components/common/page-header"
import { PaginationBar } from "@/components/common/pagination-bar"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectSeparator, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Skeleton } from "@/components/ui/skeleton"
import { useDebounce } from "@/hooks/use-debounce"
import { useAllAdminRestaurants, usePlatformAudit } from "@/lib/api/hooks"
import { useT } from "@/lib/i18n"

const ALL = "all"
const PLATFORM = "platform"

function Content() {
  const t = useT()
  const params = useSearchParams()
  const router = useRouter()
  const pathname = usePathname()
  // `?restaurant=<id>|platform`; `restaurant_id` is the older link format (still accepted).
  const restaurant = params.get("restaurant") ?? params.get("restaurant_id") ?? ALL
  const [page, setPage] = useState(1)
  const [action, setAction] = useState("")
  const { data, isLoading } = usePlatformAudit(page, { restaurant: restaurant === ALL ? undefined : restaurant, action: useDebounce(action.trim()) })
  const restaurants = useAllAdminRestaurants()

  const setRestaurant = (value: string) => {
    const next = new URLSearchParams(params.toString())
    next.delete("restaurant_id")
    if (value === ALL) next.delete("restaurant")
    else next.set("restaurant", value)
    const query = next.toString()
    router.replace(query ? `${pathname}?${query}` : pathname, { scroll: false })
    setPage(1)
  }

  const known = restaurant === ALL || restaurant === PLATFORM || (restaurants.data ?? []).some((r) => r.id === restaurant)

  return (
    <div className="space-y-6">
      <PageHeader title={t("nav.platformAudit")} description={t("admin.audit.description")} />
      <div className="bg-card overflow-hidden rounded-2xl border">
        <div className="flex flex-col gap-3 border-b p-3 sm:flex-row sm:items-center">
          <Select value={restaurant} onValueChange={setRestaurant}>
            <SelectTrigger className="w-full sm:w-64" aria-label={t("admin.audit.filterRestaurant")}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ALL}>{t("admin.audit.allRestaurants")}</SelectItem>
              <SelectItem value={PLATFORM}>{t("admin.audit.platformOnly")}</SelectItem>
              <SelectSeparator />
              {/* A restaurant from the link that is not (yet) in the list still shows as selected. */}
              {!known ? <SelectItem value={restaurant}>{restaurant}</SelectItem> : null}
              {(restaurants.data ?? []).map((r) => (
                <SelectItem key={r.id} value={r.id}>
                  {r.archived ? t("admin.audit.archivedRestaurant", { name: r.name }) : r.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <div className="relative flex-1">
            <Search className="text-muted-foreground absolute top-1/2 left-3 size-4 -translate-y-1/2" />
            <Input
              value={action}
              onChange={(e) => (setAction(e.target.value), setPage(1))}
              placeholder={t("admin.audit.filterActionPlaceholder")}
              className="h-9 pl-9"
              aria-label={t("admin.audit.filterAction")}
            />
          </div>
        </div>
        {isLoading ? (
          <Skeleton className="m-4 h-64" />
        ) : data?.data.length ? (
          <>
            <AuditTable logs={data.data} showRestaurant={restaurant === ALL} />
            <PaginationBar page={data.meta} onPageChange={setPage} />
          </>
        ) : (
          <EmptyState icon={ShieldCheck} title={t("audit.empty")} description={action || restaurant !== ALL ? t("admin.audit.noMatch") : undefined} />
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
