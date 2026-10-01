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
import { useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

const GROUPS: { value: string; label: MessageKey }[] = [
  { value: "all", label: "audit.group.all" },
  { value: "voucher.", label: "audit.group.vouchers" },
  { value: "card.", label: "audit.group.cards" },
  { value: "presentment.", label: "audit.group.scans" },
  { value: "transaction.", label: "audit.group.transactions" },
  { value: "auth.", label: "audit.group.signIns" },
  { value: "user.", label: "audit.group.team" },
  { value: "device.", label: "audit.group.devices" },
  { value: "restaurant.", label: "audit.group.settings" },
  { value: "api_token.", label: "audit.group.apiTokens" },
  { value: "customer.", label: "audit.group.customers" },
]

function AuditContent() {
  const t = useT()
  const [group, setGroup] = useState("all")
  const [page, setPage] = useState(1)
  const { data, isLoading } = useAuditLogs({ action: group === "all" ? undefined : group, page })

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("nav.audit")}
        description={t("audit.description")}
        actions={
          <Select value={group} onValueChange={(v) => (setGroup(v), setPage(1))}>
            <SelectTrigger className="w-44" aria-label={t("audit.filter")}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {GROUPS.map((g) => (
                <SelectItem key={g.value} value={g.value}>
                  {t(g.label)}
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
          <EmptyState icon={ScrollText} title={t("audit.empty")} />
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
