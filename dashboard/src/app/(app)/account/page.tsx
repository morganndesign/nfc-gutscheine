"use client"

import { useState } from "react"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { useConfirm } from "@/components/common/confirm"
import { PageHeader } from "@/components/common/page-header"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { api, errorMessage } from "@/lib/api/client"
import { useAuth } from "@/lib/auth"
import { LANGUAGES, toLanguage, translate, useI18n } from "@/lib/i18n"

export default function AccountPage() {
  const { user, refresh } = useAuth()
  const { t, language, setLanguage } = useI18n()
  const [switching, setSwitching] = useState(false)
  const [name, setName] = useState(user?.name ?? "")
  const [saving, setSaving] = useState(false)
  const [current, setCurrent] = useState("")
  const [password, setPassword] = useState("")
  const [confirmation, setConfirmation] = useState("")
  const [changing, setChanging] = useState(false)
  const [signingOut, setSigningOut] = useState(false)
  const confirm = useConfirm()

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <PageHeader title={t("account.title")} description={user?.email} />
      <Card>
        <CardHeader>
          <CardTitle>{t("account.profile")}</CardTitle>
        </CardHeader>
        <CardContent>
          <form method="post"
            className="flex flex-col gap-3 sm:flex-row sm:items-end"
            onSubmit={async (e) => {
              e.preventDefault()
              setSaving(true)
              try {
                await api("/auth/profile", { method: "PUT", body: { name } })
                await refresh()
                toast.success(t("account.profileSaved"))
              } catch (err) {
                toast.error(errorMessage(err))
              } finally {
                setSaving(false)
              }
            }}
          >
            <div className="flex-1 space-y-2">
              <Label htmlFor="name">{t("manage.field.name")}</Label>
              <Input id="name" value={name} onChange={(e) => setName(e.target.value)} required />
            </div>
            <Button type="submit" disabled={saving}>
              {saving ? <Loader2 className="animate-spin" /> : null} {t("common.save")}
            </Button>
          </form>
          <div className="mt-6 space-y-2 border-t pt-6">
            <Label htmlFor="language">{t("common.language")}</Label>
            <div className="flex items-center gap-2">
              <Select
                value={language}
                disabled={switching}
                onValueChange={async (v) => {
                  const next = toLanguage(v)
                  if (next === language) return
                  setSwitching(true)
                  try {
                    await setLanguage(next)
                    toast.success(translate(next, "account.languageSaved"))
                  } catch (err) {
                    toast.error(errorMessage(err))
                  } finally {
                    setSwitching(false)
                  }
                }}
              >
                <SelectTrigger id="language" className="w-full sm:w-72">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {LANGUAGES.map((l) => (
                    <SelectItem key={l.code} value={l.code}>
                      {l.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {switching ? <Loader2 className="text-muted-foreground size-4 animate-spin" aria-hidden /> : null}
            </div>
            <p className="text-muted-foreground text-xs">{t("account.languageHint")}</p>
          </div>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>{t("account.password")}</CardTitle>
          <CardDescription>{t("account.passwordDescription")}</CardDescription>
        </CardHeader>
        <CardContent>
          <form method="post"
            className="space-y-4"
            onSubmit={async (e) => {
              e.preventDefault()
              if (password !== confirmation) {
                toast.error(t("account.passwordMismatch"))
                return
              }
              setChanging(true)
              try {
                await api("/auth/password", { method: "PUT", body: { current_password: current, password, password_confirmation: confirmation } })
                toast.success(t("account.passwordChanged"))
                setCurrent("")
                setPassword("")
                setConfirmation("")
              } catch (err) {
                toast.error(errorMessage(err))
              } finally {
                setChanging(false)
              }
            }}
          >
            <div className="space-y-2">
              <Label htmlFor="current">{t("account.currentPassword")}</Label>
              <Input id="current" type="password" autoComplete="current-password" value={current} onChange={(e) => setCurrent(e.target.value)} required />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="new">{t("account.newPassword")}</Label>
                <Input id="new" type="password" autoComplete="new-password" value={password} onChange={(e) => setPassword(e.target.value)} required />
              </div>
              <div className="space-y-2">
                <Label htmlFor="confirm">{t("account.repeatPassword")}</Label>
                <Input
                  id="confirm"
                  type="password"
                  autoComplete="new-password"
                  value={confirmation}
                  onChange={(e) => setConfirmation(e.target.value)}
                  required
                />
              </div>
            </div>
            <Button type="submit" disabled={changing}>
              {changing ? <Loader2 className="animate-spin" /> : null} {t("account.changePassword")}
            </Button>
          </form>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>{t("account.everywhere")}</CardTitle>
          <CardDescription>{t("account.everywhereDescription")}</CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            variant="outline"
            className="text-destructive"
            disabled={signingOut}
            onClick={async () => {
              const ok = await confirm({
                title: t("account.everywhereConfirmTitle"),
                description: t("account.everywhereDescription"),
                confirmLabel: t("account.everywhere"),
                destructive: true,
              })
              if (!ok) return
              setSigningOut(true)
              try {
                await api("/auth/logout-everywhere", { method: "POST" })
                toast.success(t("account.everywhereDone"))
              } catch (e) {
                toast.error(errorMessage(e))
              } finally {
                setSigningOut(false)
              }
            }}
          >
            {signingOut ? <Loader2 className="animate-spin" /> : null} {t("account.everywhere")}
          </Button>
        </CardContent>
      </Card>
    </div>
  )
}
