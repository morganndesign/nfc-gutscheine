"use client"

import { useState } from "react"
import { KeyRound, Loader2, Plus } from "lucide-react"
import { toast } from "sonner"
import { CopyButton } from "@/components/common/copy-button"
import { QueryError } from "@/components/common/query-error"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardAction, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Checkbox } from "@/components/ui/checkbox"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { useApiTokens, useCreateApiToken, useRevokeApiToken } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { Permission } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { formatDate, formatRelative } from "@/lib/format"
import { useConfirm } from "@/components/common/confirm"
import { hasMessage, useT, type Translate } from "@/lib/i18n"

/** An integration never spends without a presentment: "vouchers.redeem" also needs a scanned voucher QR. */
const PRESET_ABILITIES: Permission[] = ["vouchers.redeem", "vouchers.view", "vouchers.export", "transactions.view", "transactions.export"]

function abilityLabel(t: Translate, ability: string): string {
  const key = `apiTokens.ability.${ability}`
  return hasMessage(key) ? t(key) : ability
}

/** "Send it as <code>…</code>": the translation keeps the code snippets in place. */
function UsageHint() {
  const t = useT()
  const text = t("apiTokens.usage", { auth: "[[auth]]", idempotency: "[[idem]]" })
  return (
    <p className="text-muted-foreground text-xs">
      {text
        .split(/(\[\[auth\]\]|\[\[idem\]\])/)
        .map((part, i) =>
          part === "[[auth]]" ? <code key={i}>Authorization: Bearer &lt;token&gt;</code> : part === "[[idem]]" ? <code key={i}>Idempotency-Key</code> : part,
        )}
    </p>
  )
}

export function ApiTokens() {
  const t = useT()
  const confirm = useConfirm()
  const { user } = useAuth()
  const { data, error, refetch } = useApiTokens()
  const create = useCreateApiToken()
  const revoke = useRevokeApiToken()
  const [open, setOpen] = useState(false)
  const [name, setName] = useState("")
  const [abilities, setAbilities] = useState<string[]>(["transactions.view", "transactions.export"])
  const [expires, setExpires] = useState("")
  const [plain, setPlain] = useState<string | null>(null)
  const available = PRESET_ABILITIES.filter((a) => user?.permissions.includes(a))
  // Only what this user may grant (and sees ticked): a preset the user lacks would be refused by the server.
  const granted = abilities.filter((a) => (available as string[]).includes(a))

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("apiTokens.title")}</CardTitle>
        <CardDescription>{t("apiTokens.description")}</CardDescription>
        <CardAction>
          <Button size="sm" onClick={() => setOpen(true)}>
            <Plus /> {t("apiTokens.new")}
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent>
        {error && !data ? (
          <QueryError error={error} onRetry={() => void refetch()} />
        ) : data?.data.length ? (
          <ul className="divide-y rounded-2xl border">
            {data.data.map((token) => (
              <li key={token.id} className="flex items-start justify-between gap-4 p-4">
                <div className="min-w-0 space-y-1">
                  <p className="flex items-center gap-2 text-sm font-medium">
                    <KeyRound className="text-muted-foreground size-4" /> {token.name}
                    {token.active ? (
                      <Badge variant="secondary">{t("apiTokens.active")}</Badge>
                    ) : (
                      <Badge variant="outline">{token.revoked_at ? t("apiTokens.revoked") : t("apiTokens.expired")}</Badge>
                    )}
                  </p>
                  <p className="text-muted-foreground text-xs">
                    {token.abilities.map((a) => abilityLabel(t, a)).join(", ")} · {t("apiTokens.lastUsed", { time: formatRelative(token.last_used_at) })} ·{" "}
                    {token.expires_at ? t("apiTokens.expires", { date: formatDate(token.expires_at) }) : t("apiTokens.noExpiry")}
                  </p>
                </div>
                {token.active ? (
                  <Button
                    variant="outline"
                    size="sm"
                    className="text-destructive"
                    onClick={async () => {
                      const ok = await confirm({
                        title: t("apiTokens.confirmRevoke.title", { name: token.name }),
                        description: t("apiTokens.confirmRevoke.description"),
                        confirmLabel: t("apiTokens.confirmRevoke.confirm"),
                        destructive: true,
                      })
                      if (!ok) return
                      try {
                        await revoke.mutateAsync(token.id)
                        toast.success(t("apiTokens.revokedToast"))
                      } catch (e) {
                        toast.error(errorMessage(e))
                      }
                    }}
                  >
                    {t("apiTokens.revoke")}
                  </Button>
                ) : null}
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-muted-foreground py-6 text-center text-sm">{t("apiTokens.empty")}</p>
        )}
      </CardContent>

      <Dialog
        open={open}
        onOpenChange={(o) => {
          setOpen(o)
          if (!o) {
            setPlain(null)
            setName("")
          }
        }}
      >
        <DialogContent className="sm:max-w-lg">
          {plain ? (
            <>
              <DialogHeader>
                <DialogTitle>{t("apiTokens.copyTitle")}</DialogTitle>
                <DialogDescription>{t("apiTokens.copyDescription")}</DialogDescription>
              </DialogHeader>
              <div className="flex items-center gap-2">
                <Input readOnly value={plain} className="font-mono text-xs" onFocus={(e) => e.currentTarget.select()} />
                <CopyButton value={plain} />
              </div>
              <UsageHint />
              <DialogFooter>
                <Button onClick={() => setOpen(false)}>{t("apiTokens.done")}</Button>
              </DialogFooter>
            </>
          ) : (
            <form
              className="space-y-4"
              onSubmit={async (e) => {
                e.preventDefault()
                try {
                  const res = await create.mutateAsync({ name: name.trim(), abilities: granted, expires_at: expires || null })
                  setPlain(res.plain_text_token)
                } catch (err) {
                  toast.error(errorMessage(err))
                }
              }}
            >
              <DialogHeader>
                <DialogTitle>{t("apiTokens.newTitle")}</DialogTitle>
              </DialogHeader>
              <div className="space-y-2">
                <Label htmlFor="t-name">{t("manage.field.name")}</Label>
                <Input id="t-name" required placeholder={t("apiTokens.namePlaceholder")} value={name} onChange={(e) => setName(e.target.value)} />
              </div>
              <div className="space-y-2">
                <Label>{t("apiTokens.abilities")}</Label>
                <div className="grid gap-2 sm:grid-cols-2">
                  {available.map((a) => (
                    <label key={a} className="flex items-center gap-2 rounded-lg border p-2 text-sm">
                      <Checkbox checked={abilities.includes(a)} onCheckedChange={(v) => setAbilities((s) => (v ? [...s, a] : s.filter((x) => x !== a)))} />
                      <span className="min-w-0">
                        <span className="block">{abilityLabel(t, a)}</span>
                        <span className="text-muted-foreground block font-mono text-xs">{a}</span>
                      </span>
                    </label>
                  ))}
                </div>
              </div>
              <div className="space-y-2">
                <Label htmlFor="t-exp">{t("apiTokens.expiresLabel")}</Label>
                <Input id="t-exp" type="date" value={expires} onChange={(e) => setExpires(e.target.value)} />
                <p className="text-muted-foreground text-xs">{t("apiTokens.expiresHint")}</p>
              </div>
              <DialogFooter>
                <Button type="button" variant="outline" onClick={() => setOpen(false)}>
                  {t("common.cancel")}
                </Button>
                <Button type="submit" disabled={create.isPending || !name.trim() || !granted.length}>
                  {create.isPending ? <Loader2 className="animate-spin" /> : null} {t("apiTokens.create")}
                </Button>
              </DialogFooter>
            </form>
          )}
        </DialogContent>
      </Dialog>
    </Card>
  )
}
