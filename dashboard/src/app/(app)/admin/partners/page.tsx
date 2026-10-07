"use client"

import { useState } from "react"
import { KeyRound, Loader2, Plug, Plus } from "lucide-react"
import { toast } from "sonner"
import { useConfirm } from "@/components/common/confirm"
import { CopyButton } from "@/components/common/copy-button"
import { EmptyState } from "@/components/common/empty-state"
import { PageHeader } from "@/components/common/page-header"
import { QueryError } from "@/components/common/query-error"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { errorMessage } from "@/lib/api/client"
import { useAdminPartnerKey, useAdminPartners, useAdminPartnerStatus } from "@/lib/api/hooks"
import type { AdminPartner } from "@/lib/api/types"
import { formatDateTime } from "@/lib/format"
import { useT } from "@/lib/i18n"

/**
 * Admin › Kassen-Partner (audit L4): the POS companies with a partner key — the same as `php artisan partner:manage`.
 * A new partner or a new key is shown once, here.
 */
function Content() {
  const t = useT()
  const confirm = useConfirm()
  const { data, isLoading, error, refetch } = useAdminPartners()
  const keyMutation = useAdminPartnerKey()
  const status = useAdminPartnerStatus()
  const [creating, setCreating] = useState(false)
  const [name, setName] = useState("")
  const [email, setEmail] = useState("")
  const [shown, setShown] = useState<{ name: string; key: string } | null>(null)

  const newKey = async (p: AdminPartner) => {
    if (
      !(await confirm({
        title: t("partners.newKeyTitle", { name: p.name }),
        description: t("partners.newKeyBody"),
        confirmLabel: t("partners.newKey"),
        destructive: true,
      }))
    )
      return
    try {
      const r = await keyMutation.mutateAsync({ id: p.id })
      setShown({ name: r.name, key: r.key })
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  const switchStatus = async (p: AdminPartner) => {
    const active = p.status !== "active"
    if (
      !active &&
      !(await confirm({
        title: t("partners.suspendTitle", { name: p.name }),
        description: t("partners.suspendBody"),
        confirmLabel: t("partners.suspend"),
        destructive: true,
      }))
    )
      return
    try {
      await status.mutateAsync({ id: p.id, active })
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("nav.partners")}
        description={t("partners.description")}
        actions={
          <Button onClick={() => (setName(""), setEmail(""), setCreating(true))}>
            <Plus /> {t("partners.new")}
          </Button>
        }
      />
      <div className="bg-card overflow-hidden rounded-2xl border">
        {isLoading ? (
          <Skeleton className="m-4 h-48" />
        ) : error && !data ? (
          <QueryError error={error} onRetry={() => void refetch()} />
        ) : data?.length ? (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("partners.colPartner")}</TableHead>
                <TableHead>{t("partners.colKey")}</TableHead>
                <TableHead>{t("partners.colRestaurants")}</TableHead>
                <TableHead>{t("partners.colLastUsed")}</TableHead>
                <TableHead />
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.map((p) => (
                <TableRow key={p.id}>
                  <TableCell>
                    <p className="font-medium">{p.name}</p>
                    {p.contact_email ? <p className="text-muted-foreground text-xs">{p.contact_email}</p> : null}
                    <Badge variant={p.status === "active" ? "secondary" : "destructive"} className="mt-1">
                      {p.status === "active" ? t("partners.active") : t("partners.suspended")}
                    </Badge>
                  </TableCell>
                  <TableCell className="font-mono text-xs">{p.key_prefix}…</TableCell>
                  <TableCell className="max-w-xs text-sm whitespace-normal">
                    {p.restaurants.length ? p.restaurants.map((r) => r.name ?? "—").join(", ") : "—"}
                  </TableCell>
                  <TableCell className="text-xs whitespace-nowrap">{p.last_used_at ? formatDateTime(p.last_used_at) : t("partners.never")}</TableCell>
                  <TableCell>
                    <div className="flex justify-end gap-2">
                      <Button size="sm" variant="outline" disabled={keyMutation.isPending} onClick={() => void newKey(p)}>
                        <KeyRound /> {t("partners.newKey")}
                      </Button>
                      <Button size="sm" variant="outline" disabled={status.isPending} onClick={() => void switchStatus(p)}>
                        {p.status === "active" ? t("partners.suspend") : t("partners.activate")}
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        ) : (
          <EmptyState icon={Plug} title={t("partners.empty")} />
        )}
      </div>

      <Dialog open={creating} onOpenChange={setCreating}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>{t("partners.new")}</DialogTitle>
          </DialogHeader>
          <form
            className="space-y-4"
            onSubmit={async (e) => {
              e.preventDefault()
              try {
                const r = await keyMutation.mutateAsync({ name: name.trim(), contact_email: email.trim() || null })
                setCreating(false)
                setShown({ name: r.name, key: r.key })
              } catch (err) {
                toast.error(errorMessage(err))
              }
            }}
          >
            <div className="space-y-2">
              <Label htmlFor="p-name">{t("partners.name")}</Label>
              <Input id="p-name" value={name} onChange={(e) => setName(e.target.value)} required minLength={2} maxLength={120} autoFocus />
            </div>
            <div className="space-y-2">
              <Label htmlFor="p-email">{t("partners.email")}</Label>
              <Input id="p-email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} maxLength={190} />
            </div>
            <DialogFooter>
              <Button type="submit" disabled={keyMutation.isPending || name.trim().length < 2}>
                {keyMutation.isPending ? <Loader2 className="animate-spin" /> : null}
                {t("partners.create")}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* The key, shown once: closing the dialog forgets it. */}
      <Dialog open={shown !== null} onOpenChange={(o) => !o && setShown(null)}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>{t("partners.keyTitle", { name: shown?.name ?? "" })}</DialogTitle>
            <DialogDescription>{t("partners.keyBody")}</DialogDescription>
          </DialogHeader>
          <div className="bg-muted rounded-xl px-4 py-3 font-mono text-sm break-all" aria-live="polite">
            {shown?.key}
          </div>
          <DialogFooter>
            {shown ? <CopyButton value={shown.key} /> : null}
            <Button onClick={() => setShown(null)}>{t("partners.done")}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}

export default function AdminPartnersPage() {
  return (
    <RequirePermission permission="platform.settings.manage">
      <Content />
    </RequirePermission>
  )
}
