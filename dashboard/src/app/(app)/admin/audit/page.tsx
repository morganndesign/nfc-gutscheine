"use client"

import { useState } from "react"
import { ShieldCheck } from "lucide-react"
import { AuditTable } from "@/components/common/audit-table"
import { EmptyState } from "@/components/common/empty-state"
import { PageHeader } from "@/components/common/page-header"
import { PaginationBar } from "@/components/common/pagination-bar"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Skeleton } from "@/components/ui/skeleton"
import { usePlatformAudit } from "@/lib/api/hooks"

function Content() {
  const [page, setPage] = useState(1)
  const { data, isLoading } = usePlatformAudit(page)
  return (
    <div className="space-y-6">
      <PageHeader title="Platform audit" description="Security-relevant events across all restaurants." />
      <div className="bg-card overflow-hidden rounded-2xl border">
        {isLoading ? (
          <Skeleton className="m-4 h-64" />
        ) : data?.data.length ? (
          <>
            <AuditTable logs={data.data} showRestaurant />
            <PaginationBar page={data.meta} onPageChange={setPage} />
          </>
        ) : (
          <EmptyState icon={ShieldCheck} title="No events" />
        )}
      </div>
    </div>
  )
}

export default function PlatformAuditPage() {
  return (
    <RequirePermission permission="platform.audit.view">
      <Content />
    </RequirePermission>
  )
}
