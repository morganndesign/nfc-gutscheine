"use client"

import { useState } from "react"
import { ScrollText } from "lucide-react"
import { PageHeader } from "@/components/common/page-header"
import { EmptyState } from "@/components/common/empty-state"
import { PaginationBar } from "@/components/common/pagination-bar"
import { AuditTable } from "@/components/common/audit-table"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Skeleton } from "@/components/ui/skeleton"
import { useAuditLogs } from "@/lib/api/hooks"

const GROUPS = [
  { value: "all", label: "All events" },
  { value: "voucher.", label: "Vouchers" },
  { value: "presentment.", label: "Scans" },
  { value: "transaction.", label: "Transactions" },
  { value: "auth.", label: "Sign-ins" },
  { value: "user.", label: "Team" },
  { value: "device.", label: "Devices" },
  { value: "restaurant.", label: "Settings" },
  { value: "api_token.", label: "API tokens" },
  { value: "customer.", label: "Customers" },
]

function AuditContent() {
  const [group, setGroup] = useState("all")
  const [page, setPage] = useState(1)
  const { data, isLoading } = useAuditLogs({ action: group === "all" ? undefined : group, page })

  return (
    <div className="space-y-6">
      <PageHeader
        title="Audit log"
        description="Every security- and money-relevant action, with who, when and from where. Entries can never be changed or deleted."
        actions={
          <Select value={group} onValueChange={(v) => (setGroup(v), setPage(1))}>
            <SelectTrigger className="w-44" aria-label="Filter events">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {GROUPS.map((g) => (
                <SelectItem key={g.value} value={g.value}>
                  {g.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        }
      />
      <div className="bg-card overflow-hidden rounded-2xl border">
        {isLoading ? (
          <div className="space-y-2 p-4">
            {Array.from({ length: 10 }).map((_, i) => (
              <Skeleton key={i} className="h-10 w-full" />
            ))}
          </div>
        ) : data?.data.length ? (
          <>
            <AuditTable logs={data.data} />
            <PaginationBar page={data.meta} onPageChange={setPage} />
          </>
        ) : (
          <EmptyState icon={ScrollText} title="No events" />
        )}
      </div>
    </div>
  )
}

export default function AuditPage() {
  return (
    <RequirePermission permission="audit.view">
      <AuditContent />
    </RequirePermission>
  )
}
