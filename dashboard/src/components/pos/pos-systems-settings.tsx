"use client"

import { useState } from "react"
import { Check, Copy, KeyRound, Loader2, Store } from "lucide-react"
import { toast } from "sonner"
import { useConfirm } from "@/components/common/confirm"
import { QueryError } from "@/components/common/query-error"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import { errorMessage } from "@/lib/api/client"
import { useCreatePartnerCode, useDisconnectPartner, usePartnerConnections } from "@/lib/api/hooks"
import { formatDate, formatDateTime } from "@/lib/format"
import { useT } from "@/lib/i18n"

/**
 * Settings › Kassensysteme (owners, decision 2026-10-07): a POS system redeems vouchers and gift cards in its own
 * till app. The owner creates a one-time code for the POS provider, sees the connected systems and their tills, and
 * disconnects a system (a single till is revoked under Devices).
 */
export function PosSystemsSettings() {
  const t = useT()
  const confirm = useConfirm()
  const { data, error, refetch, isLoading } = usePartnerConnections()
  const createCode = useCreatePartnerCode()
  const disconnect = useDisconnectPartner()
  const [code, setCode] = useState<{ code: string; expires_at: string } | null>(null)
  const [copied, setCopied] = useState(false)

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <CardTitle>{t("pos.title")}</CardTitle>
          <CardDescription>{t("pos.description")}</CardDescription>
        </CardHeader>
        {code ? (
          <CardContent className="space-y-3">
            <p className="text-sm font-medium">{t("pos.code.title")}</p>
            <div className="bg-muted flex flex-wrap items-center gap-3 rounded-xl px-4 py-3">
              <span className="card-number font-mono text-2xl font-semibold tracking-widest" aria-live="polite">
                {code.code}
              </span>
              <Button
                variant="outline"
                size="sm"
                onClick={async () => {
                  await navigator.clipboard.writeText(code.code)
                  setCopied(true)
                  toast.success(t("pos.code.copied"))
                }}
              >
                {copied ? <Check /> : <Copy />}
                {t("pos.code.copy")}
              </Button>
            </div>
            <p className="text-muted-foreground text-sm">{t("pos.code.body", { time: formatDateTime(code.expires_at) })}</p>
          </CardContent>
        ) : null}
        <CardFooter>
          <Button
            disabled={createCode.isPending}
            onClick={async () => {
              try {
                setCopied(false)
                setCode(await createCode.mutateAsync())
              } catch (e) {
                toast.error(errorMessage(e))
              }
            }}
          >
            {createCode.isPending ? <Loader2 className="animate-spin" /> : <KeyRound />}
            {t("pos.code.button")}
          </Button>
        </CardFooter>
      </Card>

      {isLoading ? (
        <Skeleton className="h-32 w-full rounded-2xl" />
      ) : error && !data ? (
        <QueryError error={error} onRetry={() => void refetch()} />
      ) : !data?.length ? (
        <p className="text-muted-foreground px-1 text-sm">{t("pos.empty")}</p>
      ) : (
        data.map((c) => (
          <Card key={c.id}>
            <CardHeader className="flex flex-row items-start gap-3 space-y-0">
              <div className="bg-muted flex size-10 shrink-0 items-center justify-center rounded-xl">
                <Store className="size-5" aria-hidden />
              </div>
              <div className="min-w-0 flex-1">
                <CardTitle className="text-base">{c.partner.name}</CardTitle>
                <CardDescription>{t("pos.connectedSince", { date: formatDate(c.connected_at) })}</CardDescription>
              </div>
              <Button
                variant="outline"
                size="sm"
                disabled={disconnect.isPending}
                onClick={async () => {
                  if (
                    await confirm({
                      title: t("pos.disconnectTitle"),
                      description: t("pos.disconnectBody"),
                      confirmLabel: t("pos.disconnect"),
                      destructive: true,
                    })
                  ) {
                    try {
                      await disconnect.mutateAsync(c.id)
                      toast.success(t("pos.disconnected"))
                    } catch (e) {
                      toast.error(errorMessage(e))
                    }
                  }
                }}
              >
                {t("pos.disconnect")}
              </Button>
            </CardHeader>
            <CardContent className="space-y-2">
              <p className="text-sm font-medium">{t("pos.tills")}</p>
              {c.terminals.length === 0 ? (
                <p className="text-muted-foreground text-sm">{t("pos.noTills")}</p>
              ) : (
                <ul className="divide-y rounded-xl border">
                  {c.terminals.map((d) => (
                    <li key={d.id} className="flex flex-wrap items-center justify-between gap-2 px-3 py-2 text-sm">
                      <span className="min-w-0 truncate">{d.name}</span>
                      <span className="text-muted-foreground flex items-center gap-2 text-xs">
                        {d.status === "revoked" ? <Badge variant="destructive">{t("pos.revoked")}</Badge> : null}
                        {d.last_seen_at ? t("pos.lastSeen", { date: formatDateTime(d.last_seen_at) }) : null}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
              <p className="text-muted-foreground text-xs">{t("pos.tillsHint")}</p>
            </CardContent>
          </Card>
        ))
      )}
    </div>
  )
}
