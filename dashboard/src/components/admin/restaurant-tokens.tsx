"use client"

import { KeyRound } from "lucide-react"
import { toast } from "sonner"
import { useConfirm } from "@/components/common/confirm"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { useAdminApiTokens, useAdminRevokeApiToken } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import { formatRelative } from "@/lib/format"
import { useT } from "@/lib/i18n"

/**
 * Incident response for the platform (audit S2): every active access token of the restaurant (integrations and
 * waiter app sign-ins) can be revoked at once from here. Platform administrators never hold tokens themselves.
 */
export function RestaurantTokens({ restaurantId }: { restaurantId: string }) {
  const t = useT()
  const confirm = useConfirm()
  const { data } = useAdminApiTokens(restaurantId)
  const revoke = useAdminRevokeApiToken()
  const tokens = data?.data ?? []

  return (
    <Card className="lg:col-span-3">
      <CardHeader>
        <CardTitle>{t("admin.tokens.title")}</CardTitle>
        <CardDescription>{t("admin.tokens.description")}</CardDescription>
      </CardHeader>
      <CardContent className="space-y-2">
        {tokens.length === 0 ? <p className="text-muted-foreground text-sm">{t("admin.tokens.none")}</p> : null}
        {tokens.map((token) => (
          <div key={token.id} className="flex items-center justify-between gap-3 rounded-xl border px-3 py-2 text-sm">
            <span className="flex min-w-0 items-center gap-2">
              <KeyRound className="text-muted-foreground size-4 shrink-0" aria-hidden />
              <span className="truncate font-medium">{token.name}</span>
              <Badge variant="outline">{token.kind === "device" ? t("admin.tokens.kindDevice") : t("admin.tokens.kindIntegration")}</Badge>
              <span className="text-muted-foreground hidden truncate sm:inline">
                {token.owner?.name ?? "—"} · {t("admin.tokens.used", { when: formatRelative(token.last_used_at) })}
              </span>
            </span>
            <Button
              variant="outline"
              size="sm"
              className="text-destructive"
              disabled={revoke.isPending}
              onClick={async () => {
                const ok = await confirm({
                  title: t("admin.tokens.revokeTitle", { name: token.name }),
                  description: token.kind === "device" ? t("admin.tokens.revokeDevice") : t("admin.tokens.revokeIntegration"),
                  confirmLabel: t("admin.tokens.revoke"),
                  destructive: true,
                })
                if (!ok) return
                try {
                  await revoke.mutateAsync(token.id)
                  toast.success(t("admin.tokens.revoked", { name: token.name }))
                } catch (e) {
                  toast.error(errorMessage(e))
                }
              }}
            >
              {t("admin.tokens.revoke")}
            </Button>
          </div>
        ))}
      </CardContent>
    </Card>
  )
}
