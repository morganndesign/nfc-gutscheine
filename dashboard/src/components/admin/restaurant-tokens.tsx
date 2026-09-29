"use client"

import { KeyRound } from "lucide-react"
import { toast } from "sonner"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { useAdminApiTokens, useAdminRevokeApiToken } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import { formatRelative } from "@/lib/format"

/**
 * Incident response for the platform (audit S2): every active access token of the restaurant (integrations and
 * waiter app sign-ins) can be revoked at once from here. Platform administrators never hold tokens themselves.
 */
export function RestaurantTokens({ restaurantId }: { restaurantId: string }) {
  const { data } = useAdminApiTokens(restaurantId)
  const revoke = useAdminRevokeApiToken()
  const tokens = data?.data ?? []

  return (
    <Card className="lg:col-span-3">
      <CardHeader>
        <CardTitle>Active access tokens</CardTitle>
        <CardDescription>Integration tokens and waiter app sign-ins. Revoke one if it may have leaked.</CardDescription>
      </CardHeader>
      <CardContent className="space-y-2">
        {tokens.length === 0 ? <p className="text-muted-foreground text-sm">No active tokens.</p> : null}
        {tokens.map((t) => (
          <div key={t.id} className="flex items-center justify-between gap-3 rounded-xl border px-3 py-2 text-sm">
            <span className="flex min-w-0 items-center gap-2">
              <KeyRound className="text-muted-foreground size-4 shrink-0" aria-hidden />
              <span className="truncate font-medium">{t.name}</span>
              <Badge variant="outline">{t.kind === "device" ? "Waiter app" : "Integration"}</Badge>
              <span className="text-muted-foreground hidden truncate sm:inline">
                {t.owner?.name ?? "—"} · used {formatRelative(t.last_used_at)}
              </span>
            </span>
            <Button
              variant="outline"
              size="sm"
              className="text-destructive"
              disabled={revoke.isPending}
              onClick={async () => {
                try {
                  await revoke.mutateAsync(t.id)
                  toast.success(`${t.name} revoked`)
                } catch (e) {
                  toast.error(errorMessage(e))
                }
              }}
            >
              Revoke
            </Button>
          </div>
        ))}
      </CardContent>
    </Card>
  )
}
