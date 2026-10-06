"use client"

import { useState } from "react"
import { ShieldAlert } from "lucide-react"
import { toast } from "sonner"
import { EmptyState } from "@/components/common/empty-state"
import { PageHeader } from "@/components/common/page-header"
import { QueryError } from "@/components/common/query-error"
import { PaginationBar } from "@/components/common/pagination-bar"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { Segmented } from "@/components/common/segmented"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useAcknowledgeAlert, useSecurityAlerts } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { SecurityAlert } from "@/lib/api/types"
import { formatDateTime } from "@/lib/format"
import { useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

/** Rules with an explanation for the person on call (`admin.security.rule.<rule>`). */
const RULES = new Set([
  "card.clone_attempt",
  "card.url_replay",
  "card.counter_gap",
  "card.counterfeit",
  "card.unknown_keys",
  "card.replacements",
  "device.token_theft",
  "auth.account_locked",
  "auth.code_guessing",
  "auth.credential_stuffing",
  "presentment.guessing",
  "money.limit_hits",
  "money.reversals",
  "money.refunds",
  "money.complimentary",
  "money.loyalty_topups",
  "card.delivery_short",
  "online.dispute",
  "online.account_change",
  "online.order_burst",
])

function SeverityBadge({ severity }: { severity: SecurityAlert["severity"] }) {
  const t = useT()
  return <Badge variant={severity === "warning" ? "secondary" : "destructive"}>{t(`admin.security.severity.${severity}` as MessageKey)}</Badge>
}

function Content() {
  const t = useT()
  const [page, setPage] = useState(1)
  const [status, setStatus] = useState<"open" | "acknowledged">("open")
  const { data, isLoading, error, refetch } = useSecurityAlerts(page, status)
  const ack = useAcknowledgeAlert()
  const [acking, setAcking] = useState<SecurityAlert | null>(null)

  return (
    <div className="space-y-6">
      <PageHeader title={t("nav.securityAlerts")} description={t("admin.security.description")} />
      <div className="bg-card overflow-hidden rounded-2xl border">
        <div className="border-b p-3">
          <Segmented
            label={t("admin.security.alertStatus")}
            value={status}
            onChange={(v) => (setStatus(v), setPage(1))}
            options={[
              { value: "open", label: t("admin.security.open") },
              { value: "acknowledged", label: t("admin.security.acknowledged") },
            ]}
          />
        </div>
        {isLoading ? (
          <Skeleton className="m-4 h-64" />
        ) : error && !data ? (
          <QueryError error={error} onRetry={() => void refetch()} />
        ) : data?.data.length ? (
          <>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t("admin.security.colRule")}</TableHead>
                  <TableHead>{t("admin.security.colSeverity")}</TableHead>
                  <TableHead>{t("admin.security.colSubject")}</TableHead>
                  <TableHead className="text-right">{t("admin.security.colCount")}</TableHead>
                  <TableHead>{t("admin.security.colLastSeen")}</TableHead>
                  <TableHead />
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.data.map((a) => (
                  <TableRow key={a.id}>
                    <TableCell className="max-w-md">
                      <p className="font-mono text-sm">{a.rule}</p>
                      <p className="text-muted-foreground text-xs whitespace-normal">
                        {RULES.has(a.rule) ? t(`admin.security.rule.${a.rule}` as MessageKey) : ""}
                      </p>
                      {a.note ? <p className="mt-1 text-xs whitespace-normal">{t("admin.security.note", { note: a.note })}</p> : null}
                    </TableCell>
                    <TableCell>
                      <SeverityBadge severity={a.severity} />
                    </TableCell>
                    <TableCell className="font-mono text-xs">{a.subject}</TableCell>
                    <TableCell className="text-right tabular-nums">{a.occurrences}</TableCell>
                    <TableCell className="text-xs whitespace-nowrap">{formatDateTime(a.last_seen_at)}</TableCell>
                    <TableCell className="text-right">
                      {a.status === "open" ? (
                        <Button size="sm" variant="outline" onClick={() => setAcking(a)}>
                          {t("admin.security.acknowledge")}
                        </Button>
                      ) : null}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            <PaginationBar page={data.meta} onPageChange={setPage} />
          </>
        ) : (
          <EmptyState icon={ShieldAlert} title={status === "open" ? t("admin.security.noOpen") : t("admin.security.noneAcknowledged")} />
        )}
      </div>
      <ReasonDialog
        open={acking !== null}
        onOpenChange={(o) => !o && setAcking(null)}
        title={t("admin.security.ackTitle", { rule: acking?.rule ?? "" })}
        description={t("admin.security.ackDescription")}
        confirmLabel={t("admin.security.acknowledge")}
        reasonLabel={t("admin.security.ackNote")}
        pending={ack.isPending}
        onConfirm={async (note) => {
          if (!acking) return
          try {
            await ack.mutateAsync({ id: acking.id, note })
            toast.success(t("admin.security.acked"))
            setAcking(null)
          } catch (e) {
            toast.error(errorMessage(e))
          }
        }}
      />
    </div>
  )
}

export default function SecurityAlertsPage() {
  return (
    <RequirePermission permission="platform.audit.view">
      <Content />
    </RequirePermission>
  )
}
