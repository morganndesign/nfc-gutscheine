"use client"

import { useEffect, useState } from "react"
import { CheckCircle2, Loader2, Mail } from "lucide-react"
import { toast } from "sonner"
import { PageHeader } from "@/components/common/page-header"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { MailWarning } from "@/components/admin/mail-warning"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Skeleton } from "@/components/ui/skeleton"
import { Switch } from "@/components/ui/switch"
import { useMailStatus, useSendTestMail, useSystemSettings, useUpdateSystemSettings } from "@/lib/api/hooks"
import { useAuth } from "@/lib/auth"
import { ApiError, errorMessage } from "@/lib/api/client"
import { useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

/** Mail delivery: which mailer is active and a test e-mail to the signed-in admin. */
function MailDeliveryCard() {
  const t = useT()
  const { data } = useMailStatus()
  const test = useSendTestMail()
  const { user } = useAuth()
  const [to, setTo] = useState<string | null>(null)
  const recipient = to ?? user?.email ?? ""

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("admin.mail.title")}</CardTitle>
        <CardDescription>{t("admin.mail.description")}</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4 text-sm">
        {!data ? (
          <Skeleton className="h-10 w-full" />
        ) : data.delivers ? (
          <p className="flex items-center gap-2">
            <CheckCircle2 className="size-4 shrink-0 text-emerald-600" />
            <span>
              {t("admin.mail.deliveredWith")} <span className="font-mono">{data.mailer}</span>
              {data.host ? (
                <>
                  {" "}
                  {t("admin.mail.via")}{" "}
                  <span className="font-mono">
                    {data.host}:{data.port}
                  </span>
                </>
              ) : null}{" "}
              {t("admin.mail.from", { name: data.from_name, address: data.from_address })}
            </span>
          </p>
        ) : (
          <MailWarning showLink={false} />
        )}
        <div className="space-y-2">
          <Label htmlFor="test-mail-to">{t("admin.mail.testTo")}</Label>
          <Input id="test-mail-to" type="email" value={recipient} onChange={(e) => setTo(e.target.value)} placeholder="name@example.com" autoComplete="email" />
          <p className="text-muted-foreground text-xs">{t("admin.mail.testHint")}</p>
        </div>
      </CardContent>
      <CardFooter className="justify-end">
        <Button
          variant="outline"
          disabled={test.isPending || !data?.delivers || recipient.trim() === ""}
          onClick={async () => {
            try {
              const res = await test.mutateAsync(recipient.trim() === user?.email ? undefined : recipient.trim())
              toast.success(t("admin.mail.testSent", { recipient: res.data.recipient }))
            } catch (e) {
              if (e instanceof ApiError && (e.code === "MAIL_RECIPIENT_REJECTED" || e.code === "MAIL_NOT_DELIVERED")) {
                const to = (e.body as { data?: { recipient?: string } }).data?.recipient ?? recipient.trim()
                // The description is the mail server's own answer (technical, as sent by the server).
                toast.error(t(e.code === "MAIL_RECIPIENT_REJECTED" ? "admin.mail.testRejected" : "admin.mail.testFailed", { recipient: to }), {
                  description: e.message,
                  duration: 20_000,
                })
              } else toast.error(errorMessage(e), { duration: 20_000 })
            }
          }}
        >
          {test.isPending ? <Loader2 className="animate-spin" /> : <Mail />} {t("admin.mail.sendTest")}
        </Button>
      </CardFooter>
    </Card>
  )
}

/**
 * The platform settings this page edits, in this order. Label and help text are translated here by key (the
 * server's English description is not shown). Keys the server does not have are skipped.
 */
const SETTINGS: { key: string; label: MessageKey; hint: MessageKey }[] = [
  { key: "platform.support_email", label: "admin.settings.supportEmail", hint: "admin.settings.supportEmailHint" },
  { key: "platform.maintenance_notice", label: "admin.settings.maintenance", hint: "admin.settings.maintenanceHint" },
  { key: "app.min_version.android", label: "admin.settings.minAndroid", hint: "admin.settings.minAndroidHint" },
  { key: "app.min_version.ios", label: "admin.settings.minIos", hint: "admin.settings.minIosHint" },
]

function Content() {
  const t = useT()
  const { data } = useSystemSettings()
  const update = useUpdateSystemSettings()
  const [values, setValues] = useState<Record<string, unknown>>({})

  useEffect(() => {
    if (data) setValues(Object.fromEntries(data.filter((s) => SETTINGS.some((x) => x.key === s.key)).map((s) => [s.key, s.value])))
  }, [data])

  if (!data) return <Skeleton className="h-64 w-full rounded-2xl" />

  const rows = SETTINGS.flatMap((def) => {
    const setting = data.find((s) => s.key === def.key)
    return setting ? [{ ...def, type: setting.type }] : []
  })

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader title={t("nav.systemSettings")} description={t("admin.settings.description")} />
      <MailDeliveryCard />
      <Card>
        <CardContent className="space-y-5">
          {rows.map((s) => (
            <div key={s.key} className="space-y-2">
              <Label htmlFor={s.key}>{t(s.label)}</Label>
              {s.type === "boolean" ? (
                <div className="flex items-center gap-2">
                  <Switch id={s.key} checked={Boolean(values[s.key])} onCheckedChange={(v) => setValues((x) => ({ ...x, [s.key]: v }))} />
                </div>
              ) : (
                <Input
                  id={s.key}
                  value={(values[s.key] as string | null) ?? ""}
                  onChange={(e) => setValues((x) => ({ ...x, [s.key]: e.target.value || null }))}
                />
              )}
              <p className="text-muted-foreground text-xs">{t(s.hint)}</p>
            </div>
          ))}
        </CardContent>
        <CardFooter className="justify-end">
          <Button
            disabled={update.isPending}
            onClick={async () => {
              try {
                await update.mutateAsync(Object.entries(values).map(([key, value]) => ({ key, value })))
                toast.success(t("admin.settings.saved"))
              } catch (e) {
                toast.error(errorMessage(e))
              }
            }}
          >
            {update.isPending ? <Loader2 className="animate-spin" /> : null} {t("common.save")}
          </Button>
        </CardFooter>
      </Card>
    </div>
  )
}

export default function SystemSettingsPage() {
  return (
    <RequirePermission permission="platform.settings.manage">
      <Content />
    </RequirePermission>
  )
}
