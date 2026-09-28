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
import { errorMessage } from "@/lib/api/client"

/** Mail delivery: which mailer is active and a test e-mail to the signed-in admin. */
function MailDeliveryCard() {
  const { data } = useMailStatus()
  const test = useSendTestMail()

  return (
    <Card>
      <CardHeader>
        <CardTitle>E-mail delivery</CardTitle>
        <CardDescription>Invitations, password links and card e-mails. Configured in the deployment (MAIL_* variables).</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4 text-sm">
        {!data ? (
          <Skeleton className="h-10 w-full" />
        ) : data.delivers ? (
          <p className="flex items-center gap-2">
            <CheckCircle2 className="size-4 text-emerald-600" /> Delivered with <span className="font-mono">{data.mailer}</span> from {data.from_name} &lt;
            {data.from_address}&gt;
          </p>
        ) : (
          <MailWarning showLink={false} />
        )}
      </CardContent>
      <CardFooter className="justify-end">
        <Button
          variant="outline"
          disabled={test.isPending || !data?.delivers}
          onClick={async () => {
            try {
              toast.success((await test.mutateAsync()).message)
            } catch (e) {
              toast.error(errorMessage(e), { duration: 15_000 })
            }
          }}
        >
          {test.isPending ? <Loader2 className="animate-spin" /> : <Mail />} Send test e-mail to me
        </Button>
      </CardFooter>
    </Card>
  )
}

function Content() {
  const { data } = useSystemSettings()
  const update = useUpdateSystemSettings()
  const [values, setValues] = useState<Record<string, unknown>>({})

  useEffect(() => {
    if (data) setValues(Object.fromEntries(data.map((s) => [s.key, s.value])))
  }, [data])

  if (!data) return <Skeleton className="h-64 w-full rounded-2xl" />

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader title="System settings" description="Platform-wide configuration." />
      <MailDeliveryCard />
      <Card>
        <CardContent className="space-y-5">
          {data.map((s) => (
            <div key={s.key} className="space-y-2">
              <Label htmlFor={s.key}>{SETTING_LABELS[s.key] ?? s.key.replace(/^(platform|app)\./, "").replace(/[_.]/g, " ")}</Label>
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
              {s.description ? <p className="text-muted-foreground text-xs">{s.description}</p> : null}
            </div>
          ))}
        </CardContent>
        <CardFooter className="justify-end">
          <Button
            disabled={update.isPending}
            onClick={async () => {
              try {
                await update.mutateAsync(Object.entries(values).map(([key, value]) => ({ key, value })))
                toast.success("Settings saved")
              } catch (e) {
                toast.error(errorMessage(e))
              }
            }}
          >
            {update.isPending ? <Loader2 className="animate-spin" /> : null} Save
          </Button>
        </CardFooter>
      </Card>
    </div>
  )
}

const SETTING_LABELS: Record<string, string> = {
  "app.min_version.android": "Minimum waiter app version (Android)",
  "app.min_version.ios": "Minimum waiter app version (iPhone)",
  "platform.default_plan": "Default plan",
  "platform.maintenance_notice": "Maintenance notice",
  "platform.support_email": "Support e-mail",
}

export default function SystemSettingsPage() {
  return (
    <RequirePermission permission="platform.settings.manage">
      <Content />
    </RequirePermission>
  )
}
