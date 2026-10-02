"use client"

import { Suspense, useEffect, useState } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { useAuth } from "@/lib/auth"
import { api, errorMessage } from "@/lib/api/client"
import { useDocumentTitle } from "@/hooks/use-document-title"
import { useT } from "@/lib/i18n"

/**
 * Invitation and reset links carry their token in the URL fragment (#token=…&email=…), which browsers never send
 * to a server, so it cannot end up in access logs or Referer headers. It is read once and removed from the address
 * bar and history right away.
 */
function useLinkParams(): URLSearchParams | null {
  const [params, setParams] = useState<URLSearchParams | null>(null)
  useEffect(() => {
    const hash = window.location.hash.replace(/^#/, "")
    setParams(new URLSearchParams(hash))
    if (hash) window.history.replaceState(null, "", window.location.pathname)
  }, [])
  return params
}

function ResetForm() {
  const t = useT()
  useDocumentTitle(t("forgotPassword.title"))
  const linkParams = useLinkParams()
  const params = linkParams ?? new URLSearchParams()
  const router = useRouter()
  const { user, logout } = useAuth()
  const [password, setPassword] = useState("")
  const [confirmation, setConfirmation] = useState("")
  const [pending, setPending] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const token = params.get("token") ?? ""
  const email = params.get("email") ?? ""
  const invite = params.get("invite") === "1"

  if (linkParams === null) return null

  if (!token || !email) {
    return (
      <div className="bg-card rounded-2xl border p-8 text-center text-sm">
        {t("resetPassword.incomplete")}{" "}
        <Link href="/forgot-password" className="underline">
          {t("resetPassword.requestNew")}
        </Link>
      </div>
    )
  }

  return (
    <form
      className="bg-card space-y-4 rounded-2xl border p-6 shadow-sm sm:p-8"
      onSubmit={async (e) => {
        e.preventDefault()
        setError(null)
        if (password !== confirmation) {
          setError(t("resetPassword.mismatch"))
          return
        }
        setPending(true)
        try {
          await api("/auth/reset-password", { method: "POST", body: { token, email, password, password_confirmation: confirmation } })
          // Someone else may still be signed in in this browser (e.g. the platform admin who just onboarded this
          // owner): sign that session out, otherwise the login page would forward straight into their account.
          if (user) await logout().catch(() => undefined)
          toast.success(invite ? t("resetPassword.accountReady") : t("resetPassword.saved"))
          router.replace("/login")
        } catch (err) {
          setError(errorMessage(err))
        } finally {
          setPending(false)
        }
      }}
    >
      <div className="space-y-1 text-center">
        <h1 className="text-xl font-semibold tracking-tight">{invite ? t("resetPassword.welcome") : t("resetPassword.chooseTitle")}</h1>
        {invite ? <p className="text-muted-foreground text-sm">{t("resetPassword.activateHint")}</p> : null}
        <p className="text-muted-foreground text-sm">{email}</p>
      </div>
      <div className="space-y-2">
        <Label htmlFor="password">{t("resetPassword.newPassword")}</Label>
        <Input
          id="password"
          type="password"
          autoComplete="new-password"
          minLength={12}
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="h-10"
        />
        <p className="text-muted-foreground text-xs">{t("resetPassword.rules")}</p>
      </div>
      <div className="space-y-2">
        <Label htmlFor="confirmation">{t("resetPassword.repeat")}</Label>
        <Input
          id="confirmation"
          type="password"
          autoComplete="new-password"
          required
          value={confirmation}
          onChange={(e) => setConfirmation(e.target.value)}
          className="h-10"
        />
      </div>
      {error ? <p className="text-destructive text-sm">{error}</p> : null}
      <Button type="submit" className="h-10 w-full" disabled={pending}>
        {pending ? <Loader2 className="animate-spin" /> : null} {t("resetPassword.submit")}
      </Button>
    </form>
  )
}

export default function ResetPasswordPage() {
  return (
    <Suspense>
      <ResetForm />
    </Suspense>
  )
}
