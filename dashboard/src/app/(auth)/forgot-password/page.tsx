"use client"

import { useState } from "react"
import Link from "next/link"
import { Loader2, MailCheck } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { api, errorMessage } from "@/lib/api/client"
import { useDocumentTitle } from "@/hooks/use-document-title"
import { useT } from "@/lib/i18n"

export default function ForgotPasswordPage() {
  const t = useT()
  useDocumentTitle(t("forgotPassword.title"))
  const [email, setEmail] = useState("")
  const [state, setState] = useState<"idle" | "sending" | "sent">("idle")
  const [error, setError] = useState<string | null>(null)

  return (
    <div className="bg-card rounded-2xl border p-6 shadow-sm sm:p-8">
      {state === "sent" ? (
        <div className="space-y-3 text-center">
          <MailCheck className="mx-auto size-8 text-emerald-700" />
          <h1 className="text-xl font-semibold">{t("forgotPassword.sentTitle")}</h1>
          <p className="text-muted-foreground text-sm">{t("forgotPassword.sentText", { email })}</p>
          <Button asChild variant="outline" className="w-full">
            <Link href="/login">{t("forgotPassword.backToSignIn")}</Link>
          </Button>
        </div>
      ) : (
        <form method="post"
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            setError(null)
            setState("sending")
            try {
              await api("/auth/forgot-password", { method: "POST", body: { email } })
              setState("sent")
            } catch (err) {
              setError(errorMessage(err))
              setState("idle")
            }
          }}
        >
          <div className="space-y-1 text-center">
            <h1 className="text-xl font-semibold tracking-tight">{t("forgotPassword.title")}</h1>
            <p className="text-muted-foreground text-sm">{t("forgotPassword.subtitle")}</p>
          </div>
          <div className="space-y-2">
            <Label htmlFor="email">{t("manage.field.email")}</Label>
            <Input id="email" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} className="h-10" autoFocus />
          </div>
          {error ? <p className="text-destructive text-sm">{error}</p> : null}
          <Button type="submit" className="h-10 w-full" disabled={state === "sending"}>
            {state === "sending" ? <Loader2 className="animate-spin" /> : null} {t("forgotPassword.submit")}
          </Button>
          <p className="text-center text-sm">
            <Link href="/login" className="text-muted-foreground hover:text-foreground">
              {t("forgotPassword.backToSignIn")}
            </Link>
          </p>
        </form>
      )}
    </div>
  )
}
