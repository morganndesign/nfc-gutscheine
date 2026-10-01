"use client"

import { useState } from "react"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { useAuth } from "@/lib/auth"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Skeleton } from "@/components/ui/skeleton"
import { Switch } from "@/components/ui/switch"
import { Textarea } from "@/components/ui/textarea"
import { useNotificationTemplates, useSaveTemplate } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { NotificationTemplate } from "@/lib/api/types"
import { hasMessage, useT, type Translate } from "@/lib/i18n"

/** The order a guest receives them in. */
const KEY_ORDER = ["voucher_issued", "voucher_reloaded", "voucher_expiring", "voucher_refunded", "card_replaced"]

function templateLabel(t: Translate, key: string): string {
  const k = `emailTemplates.type.${key}`
  return hasMessage(k) ? t(k) : key.replace(/_/g, " ")
}

function TemplateEditor({ template, onClose }: { template: NotificationTemplate; onClose: () => void }) {
  const t = useT()
  const save = useSaveTemplate()
  const [subject, setSubject] = useState(template.subject)
  const [body, setBody] = useState(template.body)
  const [active, setActive] = useState(template.is_active)

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>
            {templateLabel(t, template.key)} · {template.locale.toUpperCase()}
          </DialogTitle>
          <DialogDescription>{t("emailTemplates.placeholders", { list: template.placeholders.map((p) => `{{ ${p} }}`).join(", ") })}</DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="subject">{t("emailTemplates.subject")}</Label>
            <Input id="subject" value={subject} onChange={(e) => setSubject(e.target.value)} maxLength={200} />
          </div>
          <div className="space-y-2">
            <Label htmlFor="body">{t("emailTemplates.message")}</Label>
            <Textarea id="body" rows={12} value={body} onChange={(e) => setBody(e.target.value)} className="font-mono text-sm" />
          </div>
          <label className="flex items-center gap-2 text-sm">
            <Switch checked={active} onCheckedChange={setActive} /> {t("emailTemplates.active")}
          </label>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t("common.cancel")}
          </Button>
          <Button
            disabled={save.isPending}
            onClick={async () => {
              try {
                await save.mutateAsync({ key: template.key, locale: template.locale, subject, body, is_active: active })
                toast.success(t("emailTemplates.saved"))
                onClose()
              } catch (e) {
                toast.error(errorMessage(e))
              }
            }}
          >
            {save.isPending ? <Loader2 className="animate-spin" /> : null} {t("common.save")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

export function NotificationTemplates() {
  const t = useT()
  const { user } = useAuth()
  const { data, isLoading } = useNotificationTemplates()
  const [editing, setEditing] = useState<NotificationTemplate | null>(null)
  // The restaurant's own language first, then the e-mails in the order a guest receives them.
  const language = (user?.restaurant?.locale ?? "de").slice(0, 2)
  const templates = [...(data ?? [])].sort(
    (a, b) => Number(b.locale === language) - Number(a.locale === language) || KEY_ORDER.indexOf(a.key) - KEY_ORDER.indexOf(b.key),
  )
  const preview = (text: string) => text.replaceAll("{{ restaurant_name }}", user?.restaurant?.name ?? "")

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("emailTemplates.title")}</CardTitle>
        <CardDescription>{t("emailTemplates.description")}</CardDescription>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <Skeleton className="h-40 w-full" />
        ) : (
          <ul className="divide-y rounded-2xl border">
            {templates.map((tpl) => (
              <li key={tpl.id} className="flex items-center justify-between gap-4 p-4">
                <div className="min-w-0">
                  <p className="flex items-center gap-2 text-sm font-medium">
                    {templateLabel(t, tpl.key)} <Badge variant="outline">{tpl.locale.toUpperCase()}</Badge>
                    {tpl.is_default ? <Badge variant="secondary">{t("emailTemplates.default")}</Badge> : <Badge>{t("emailTemplates.customized")}</Badge>}
                    {!tpl.is_active ? <Badge variant="destructive">{t("emailTemplates.off")}</Badge> : null}
                  </p>
                  <p className="text-muted-foreground truncate text-sm">{preview(tpl.subject)}</p>
                </div>
                <Button variant="outline" size="sm" onClick={() => setEditing(tpl)}>
                  {t("common.edit")}
                </Button>
              </li>
            ))}
          </ul>
        )}
      </CardContent>
      {editing ? <TemplateEditor template={editing} onClose={() => setEditing(null)} /> : null}
    </Card>
  )
}
