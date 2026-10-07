"use client"

import { useState } from "react"
import { Ban, Loader2, Monitor, Pencil, RotateCcw, Smartphone, Store, Tablet } from "lucide-react"
import { toast } from "sonner"
import { PageHeader } from "@/components/common/page-header"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { EmptyState } from "@/components/common/empty-state"
import { QueryError } from "@/components/common/query-error"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Skeleton } from "@/components/ui/skeleton"
import { useDeviceAction, useDevices } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { Device } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { formatRelative } from "@/lib/format"
import { useConfirm } from "@/components/common/confirm"
import { useT } from "@/lib/i18n"

const ICONS = { phone: Smartphone, tablet: Tablet, pos: Store } as Record<string, typeof Monitor>

function RenameDialog({ device, onClose }: { device: Device; onClose: () => void }) {
  const t = useT()
  const action = useDeviceAction()
  const [name, setName] = useState(device.name)

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-sm">
        <DialogHeader>
          <DialogTitle>{t("devices.renameTitle")}</DialogTitle>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            try {
              await action.mutateAsync({ id: device.id, action: "rename", name: name.trim() })
              toast.success(t("devices.renamed"))
              onClose()
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="device-name">{t("manage.field.name")}</Label>
            <Input
              id="device-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              maxLength={120}
              placeholder={t("devices.namePlaceholder")}
              autoFocus
              required
            />
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={action.isPending || !name.trim()}>
              {action.isPending ? <Loader2 className="animate-spin" /> : null} {t("common.save")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function DevicesContent() {
  const t = useT()
  const confirm = useConfirm()
  const { can } = useAuth()
  const { data, isLoading, error, refetch } = useDevices()
  const action = useDeviceAction()
  const [renaming, setRenaming] = useState<Device | null>(null)
  const [revoking, setRevoking] = useState<Device | null>(null)

  const run = async (d: Device, act: "revoke" | "restore") => {
    if (
      act === "restore" &&
      !(await confirm({
        title: t("devices.restoreTitle", { name: d.name }),
        description: t("devices.restoreDescription"),
        confirmLabel: t("devices.restore"),
      }))
    )
      return
    try {
      await action.mutateAsync({ id: d.id, action: act })
      toast.success(act === "revoke" ? t("devices.revokedToast", { name: d.name }) : t("devices.restoredToast", { name: d.name }))
      setRevoking(null)
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("devices.title")} description={t("devices.description")} />
      {isLoading ? (
        <div className="grid gap-3 sm:grid-cols-2">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-24 rounded-2xl" />
          ))}
        </div>
      ) : error && !data ? (
        <QueryError error={error} onRetry={() => void refetch()} />
      ) : data?.data.length ? (
        <div className="grid gap-3 sm:grid-cols-2">
          {data.data.map((d) => {
            const Icon = ICONS[d.type] ?? Monitor
            return (
              <div key={d.id} className="bg-card flex min-w-0 items-start gap-3 rounded-2xl border p-4 sm:gap-4">
                <div className="bg-muted flex size-10 shrink-0 items-center justify-center rounded-xl">
                  <Icon className="size-5" />
                </div>
                <div className="min-w-0 flex-1 space-y-1">
                  <div className="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1">
                    <p className="min-w-0 truncate font-medium">{d.name}</p>
                    {d.is_current ? <Badge variant="secondary">{t("devices.thisDevice")}</Badge> : null}
                    {d.status === "revoked" ? <Badge variant="destructive">{t("devices.revokedBadge")}</Badge> : null}
                  </div>
                  <p className="text-muted-foreground text-xs">
                    {!d.last_seen_at
                      ? t("devices.neverSeen")
                      : d.last_user
                        ? t("devices.lastSeenBy", { time: formatRelative(d.last_seen_at), name: d.last_user.name })
                        : t("devices.lastSeen", { time: formatRelative(d.last_seen_at) })}
                    {d.last_ip ? ` · ${d.last_ip}` : ""}
                  </p>
                </div>
                {can("devices.manage") ? (
                  <div className="flex shrink-0 flex-col items-end gap-1 sm:flex-row sm:items-center">
                    <Button
                      variant="ghost"
                      size="icon-sm"
                      aria-label={t("devices.renameAria", { name: d.name })}
                      title={t("devices.rename")}
                      onClick={() => setRenaming(d)}
                    >
                      <Pencil />
                    </Button>
                    {!d.is_current ? (
                      d.status === "active" ? (
                        <Button variant="outline" size="sm" className="text-destructive" onClick={() => setRevoking(d)}>
                          <Ban /> {t("devices.revoke")}
                        </Button>
                      ) : (
                        <Button variant="outline" size="sm" onClick={() => void run(d, "restore")}>
                          <RotateCcw /> {t("devices.restore")}
                        </Button>
                      )
                    ) : null}
                  </div>
                ) : null}
              </div>
            )
          })}
        </div>
      ) : (
        <EmptyState icon={Smartphone} title={t("devices.emptyTitle")} description={t("devices.emptyDescription")} />
      )}
      {renaming ? <RenameDialog device={renaming} onClose={() => setRenaming(null)} /> : null}
      <ReasonDialog
        open={revoking !== null}
        onOpenChange={(o) => !o && setRevoking(null)}
        title={t("devices.revokeTitle", { name: revoking?.name ?? "" })}
        description={t("devices.revokeDescription")}
        confirmLabel={t("devices.revokeConfirm")}
        destructive
        reasonRequired="none"
        pending={action.isPending}
        onConfirm={() => revoking && void run(revoking, "revoke")}
      />
    </div>
  )
}

export default function DevicesPage() {
  return (
    <RequirePermission permission="devices.view">
      <DevicesContent />
    </RequirePermission>
  )
}
