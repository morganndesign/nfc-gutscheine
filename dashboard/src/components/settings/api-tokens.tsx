"use client"

import { useState } from "react"
import { KeyRound, Loader2, Plus } from "lucide-react"
import { toast } from "sonner"
import { CopyButton } from "@/components/common/copy-button"
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

/** An integration never spends without a presentment: "vouchers.redeem" also needs a scanned voucher QR. */
const PRESET_ABILITIES: Permission[] = ["vouchers.redeem", "vouchers.view", "vouchers.export", "transactions.view", "transactions.export"]

export function ApiTokens() {
  const { user } = useAuth()
  const { data } = useApiTokens()
  const create = useCreateApiToken()
  const revoke = useRevokeApiToken()
  const [open, setOpen] = useState(false)
  const [name, setName] = useState("")
  const [abilities, setAbilities] = useState<string[]>(["transactions.view", "transactions.export"])
  const [expires, setExpires] = useState("")
  const [plain, setPlain] = useState<string | null>(null)
  const available = PRESET_ABILITIES.filter((a) => user?.permissions.includes(a))

  return (
    <Card>
      <CardHeader>
        <CardTitle>API tokens</CardTitle>
        <CardDescription>Connect your POS or accounting system. Tokens act with exactly the abilities you select.</CardDescription>
        <CardAction>
          <Button size="sm" onClick={() => setOpen(true)}>
            <Plus /> New token
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent>
        {data?.data.length ? (
          <ul className="divide-y rounded-2xl border">
            {data.data.map((t) => (
              <li key={t.id} className="flex items-start justify-between gap-4 p-4">
                <div className="min-w-0 space-y-1">
                  <p className="flex items-center gap-2 text-sm font-medium">
                    <KeyRound className="text-muted-foreground size-4" /> {t.name}
                    {t.active ? <Badge variant="secondary">Active</Badge> : <Badge variant="outline">{t.revoked_at ? "Revoked" : "Expired"}</Badge>}
                  </p>
                  <p className="text-muted-foreground text-xs">
                    {t.abilities.join(", ")} · last used {formatRelative(t.last_used_at)} · {t.expires_at ? `expires ${formatDate(t.expires_at)}` : "no expiry"}
                  </p>
                </div>
                {t.active ? (
                  <Button
                    variant="outline"
                    size="sm"
                    className="text-destructive"
                    onClick={async () => {
                      try {
                        await revoke.mutateAsync(t.id)
                        toast.success("Token revoked")
                      } catch (e) {
                        toast.error(errorMessage(e))
                      }
                    }}
                  >
                    Revoke
                  </Button>
                ) : null}
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-muted-foreground py-6 text-center text-sm">No API tokens yet.</p>
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
                <DialogTitle>Copy your token now</DialogTitle>
                <DialogDescription>For security reasons it will never be shown again.</DialogDescription>
              </DialogHeader>
              <div className="flex items-center gap-2">
                <Input readOnly value={plain} className="font-mono text-xs" onFocus={(e) => e.currentTarget.select()} />
                <CopyButton value={plain} />
              </div>
              <p className="text-muted-foreground text-xs">
                Send it as <code>Authorization: Bearer &lt;token&gt;</code>. Money endpoints also require an <code>Idempotency-Key</code> header.
              </p>
              <DialogFooter>
                <Button onClick={() => setOpen(false)}>Done</Button>
              </DialogFooter>
            </>
          ) : (
            <form
              className="space-y-4"
              onSubmit={async (e) => {
                e.preventDefault()
                try {
                  const res = await create.mutateAsync({ name, abilities, expires_at: expires || null })
                  setPlain(res.plain_text_token)
                } catch (err) {
                  toast.error(errorMessage(err))
                }
              }}
            >
              <DialogHeader>
                <DialogTitle>New API token</DialogTitle>
              </DialogHeader>
              <div className="space-y-2">
                <Label htmlFor="t-name">Name</Label>
                <Input id="t-name" required placeholder="e.g. POS terminal bar" value={name} onChange={(e) => setName(e.target.value)} />
              </div>
              <div className="space-y-2">
                <Label>Abilities</Label>
                <div className="grid gap-2 sm:grid-cols-2">
                  {available.map((a) => (
                    <label key={a} className="flex items-center gap-2 rounded-lg border p-2 text-sm">
                      <Checkbox checked={abilities.includes(a)} onCheckedChange={(v) => setAbilities((s) => (v ? [...s, a] : s.filter((x) => x !== a)))} />
                      <span className="font-mono text-xs">{a}</span>
                    </label>
                  ))}
                </div>
              </div>
              <div className="space-y-2">
                <Label htmlFor="t-exp">Expires</Label>
                <Input id="t-exp" type="date" value={expires} onChange={(e) => setExpires(e.target.value)} />
                <p className="text-muted-foreground text-xs">Leave empty for the maximum lifetime allowed by the platform.</p>
              </div>
              <DialogFooter>
                <Button type="button" variant="outline" onClick={() => setOpen(false)}>
                  Cancel
                </Button>
                <Button type="submit" disabled={create.isPending || !name || !abilities.length}>
                  {create.isPending ? <Loader2 className="animate-spin" /> : null} Create token
                </Button>
              </DialogFooter>
            </form>
          )}
        </DialogContent>
      </Dialog>
    </Card>
  )
}
