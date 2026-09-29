"use client"

import { useState } from "react"
import { ShieldAlert } from "lucide-react"
import { toast } from "sonner"
import { EmptyState } from "@/components/common/empty-state"
import { PageHeader } from "@/components/common/page-header"
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

/** What each rule means and what to do, for the person on call. */
const RULES: Record<string, string> = {
  "card.clone_attempt": "A card's tap URL was presented on another chip (a copied NDEF). The genuine card is safe; check where it was photographed or read.",
  "card.url_replay": "The same card URL was replayed several times. Someone collected it; the replays were refused.",
  "card.counter_gap": "Many reads of this card never reached the server (read elsewhere). Ask the restaurant; suspend and replace if in doubt.",
  "card.counterfeit": "A chip at the station is not a genuine NXP NTAG 424 DNA. Stop the print run and contact the printer.",
  "card.unknown_keys": "A chip at the station had keys that are neither factory nor ours.",
  "device.token_theft": "An app sign-in was used from another phone: the token was copied. Revoke the device and reset the person's password.",
  "auth.account_locked": "An account was locked after wrong passwords.",
  "auth.credential_stuffing": "Many wrong passwords from one network across accounts.",
  "presentment.guessing": "One phone presented many unknown QR codes or cards.",
  "money.limit_hits": "Redemptions keep hitting the restaurant's limits.",
  "money.reversals": "One person reversed many bookings today.",
  "money.complimentary": "One person gave away many complimentary vouchers today.",
}

function severityBadge(s: SecurityAlert["severity"]) {
  return <Badge variant={s === "warning" ? "secondary" : "destructive"}>{s}</Badge>
}

function Content() {
  const [page, setPage] = useState(1)
  const [status, setStatus] = useState<"open" | "acknowledged">("open")
  const { data, isLoading } = useSecurityAlerts(page, status)
  const ack = useAcknowledgeAlert()
  const [acking, setAcking] = useState<SecurityAlert | null>(null)

  return (
    <div className="space-y-6">
      <PageHeader title="Security alerts" description="Fraud and attack rules over the security event stream. High and critical alerts are also e-mailed to operations." />
      <div className="bg-card overflow-hidden rounded-2xl border">
        <div className="border-b p-3">
          <Segmented
            label="Alert status"
            value={status}
            onChange={(v) => (setStatus(v), setPage(1))}
            options={[
              { value: "open", label: "Open" },
              { value: "acknowledged", label: "Acknowledged" },
            ]}
          />
        </div>
        {isLoading ? (
          <Skeleton className="m-4 h-64" />
        ) : data?.data.length ? (
          <>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Rule</TableHead>
                  <TableHead>Severity</TableHead>
                  <TableHead>Subject</TableHead>
                  <TableHead className="text-right">Count</TableHead>
                  <TableHead>Last seen</TableHead>
                  <TableHead />
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.data.map((a) => (
                  <TableRow key={a.id}>
                    <TableCell className="max-w-md">
                      <p className="font-mono text-sm">{a.rule}</p>
                      <p className="text-muted-foreground text-xs whitespace-normal">{RULES[a.rule] ?? ""}</p>
                      {a.note ? <p className="mt-1 text-xs whitespace-normal">Note: {a.note}</p> : null}
                    </TableCell>
                    <TableCell>{severityBadge(a.severity)}</TableCell>
                    <TableCell className="font-mono text-xs">{a.subject}</TableCell>
                    <TableCell className="text-right tabular-nums">{a.occurrences}</TableCell>
                    <TableCell className="text-xs whitespace-nowrap">{formatDateTime(a.last_seen_at)}</TableCell>
                    <TableCell className="text-right">
                      {a.status === "open" ? (
                        <Button size="sm" variant="outline" onClick={() => setAcking(a)}>
                          Acknowledge
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
          <EmptyState icon={ShieldAlert} title={status === "open" ? "No open alerts" : "Nothing acknowledged yet"} />
        )}
      </div>
      <ReasonDialog
        open={acking !== null}
        onOpenChange={(o) => !o && setAcking(null)}
        title={`Acknowledge ${acking?.rule ?? "alert"}?`}
        description="Write what was checked and done; the note stays with the alert and in the platform audit."
        confirmLabel="Acknowledge"
        reasonLabel="Note"
        pending={ack.isPending}
        onConfirm={async (note) => {
          if (!acking) return
          try {
            await ack.mutateAsync({ id: acking.id, note })
            toast.success("Alert acknowledged")
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
