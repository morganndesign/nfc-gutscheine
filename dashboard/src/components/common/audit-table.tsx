"use client"

import { Fragment, useState } from "react"
import { ChevronRight, ShieldAlert } from "lucide-react"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import type { AuditLog } from "@/lib/api/types"
import { auditCategory, auditLabel, isAuditAlert } from "@/lib/audit"
import { formatDateTime } from "@/lib/format"
import { useT } from "@/lib/i18n"
import { cn } from "@/lib/utils"

function Values({ label, values }: { label: string; values: Record<string, unknown> | null }) {
  if (!values || !Object.keys(values).length) return null
  return (
    <div className="min-w-0">
      <p className="text-muted-foreground mb-1 text-xs font-medium">{label}</p>
      <pre className="bg-muted overflow-x-auto rounded-lg p-2 text-xs">{JSON.stringify(values, null, 2)}</pre>
    </div>
  )
}

export function AuditTable({ logs, showRestaurant = false }: { logs: AuditLog[]; showRestaurant?: boolean }) {
  const t = useT()
  const [open, setOpen] = useState<string | null>(null)
  return (
    <Table>
      <TableHeader>
        <TableRow className="hover:bg-transparent">
          <TableHead className="w-8 pl-4" />
          <TableHead>{t("audit.col.event")}</TableHead>
          {showRestaurant ? <TableHead>{t("admin.col.restaurant")}</TableHead> : null}
          <TableHead className="hidden sm:table-cell">{t("audit.col.user")}</TableHead>
          <TableHead className="hidden md:table-cell">{t("audit.col.ip")}</TableHead>
          <TableHead className="pr-4">{t("audit.col.time")}</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {logs.map((log) => (
          <Fragment key={log.id}>
            <TableRow className="cursor-pointer" onClick={() => setOpen(open === log.id ? null : log.id)}>
              <TableCell className="pl-4">
                <button
                  type="button"
                  aria-expanded={open === log.id}
                  aria-label={t("audit.showDetails")}
                  className="focus-visible:ring-ring/50 -m-1 flex rounded p-1 outline-none focus-visible:ring-[3px]"
                  onClick={(e) => {
                    e.stopPropagation()
                    setOpen(open === log.id ? null : log.id)
                  }}
                >
                  <ChevronRight className={cn("text-muted-foreground size-4 transition", open === log.id && "rotate-90")} />
                </button>
              </TableCell>
              <TableCell>
                <span className={cn("font-medium", isAuditAlert(log.action) && "text-red-700 dark:text-red-400")}>
                  {isAuditAlert(log.action) ? <ShieldAlert className="mr-1 inline size-4 -translate-y-px" aria-label={t("audit.securityAlert")} /> : null}
                  {auditLabel(log.action)}
                </span>
                <span className="text-muted-foreground block text-xs">
                  {auditCategory(log.action)}
                  <span className="sm:hidden"> · {log.user?.name ?? t("audit.system")}</span>
                </span>
              </TableCell>
              {showRestaurant ? <TableCell className="text-muted-foreground">{log.restaurant?.name ?? t("audit.platform")}</TableCell> : null}
              <TableCell className="text-muted-foreground hidden sm:table-cell">{log.user?.name ?? t("audit.system")}</TableCell>
              <TableCell className="text-muted-foreground hidden font-mono text-xs md:table-cell">{log.ip_address ?? "—"}</TableCell>
              <TableCell className="text-muted-foreground pr-4 whitespace-nowrap">{formatDateTime(log.created_at)}</TableCell>
            </TableRow>
            {open === log.id ? (
              <TableRow className="hover:bg-transparent">
                <TableCell colSpan={showRestaurant ? 6 : 5} className="bg-surface px-6 py-4">
                  <div className="grid gap-4 md:grid-cols-3">
                    <Values label={t("audit.before")} values={log.old_values} />
                    <Values label={t("audit.after")} values={log.new_values} />
                    <Values label={t("audit.details")} values={log.metadata} />
                  </div>
                  <p className="text-muted-foreground mt-2 font-mono text-[11px]">
                    {log.auditable_type ? `${log.auditable_type} ${log.auditable_id}` : ""}{" "}
                    {log.request_id ? `· ${t("audit.request", { id: log.request_id })}` : ""}
                  </p>
                </TableCell>
              </TableRow>
            ) : null}
          </Fragment>
        ))}
      </TableBody>
    </Table>
  )
}
