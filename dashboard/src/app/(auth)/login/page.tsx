"use client"

import { Suspense, useEffect, useMemo, useState } from "react"
import Link from "next/link"
import { useRouter, useSearchParams } from "next/navigation"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { ArrowLeft, Loader2, MailCheck } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { errorMessage } from "@/lib/api/client"
import { destinationFor, useAuth } from "@/lib/auth"
import { useDocumentTitle } from "@/hooks/use-document-title"
import { useT, type Translate } from "@/lib/i18n"

function loginSchema(t: Translate) {
  return z.object({
    email: z.string().trim().email(t("login.invalidEmail")),
    password: z.string().min(1, t("login.passwordRequired")),
    remember: z.boolean(),
  })
}
type Values = z.infer<ReturnType<typeof loginSchema>>

function LoginForm() {
  const t = useT()
  useDocumentTitle(t("login.title"))
  const { user, login } = useAuth()
  // Step 2 after the password: the code sent by e-mail (decision 2026-10-05).
  const [pending, setPending] = useState<{ login: string; email: string } | null>(null)
  const schema = useMemo(() => loginSchema(t), [t])
  const router = useRouter()
  const params = useSearchParams()
  const next = params.get("next")

  const form = useForm<Values>({ resolver: zodResolver(schema), defaultValues: { email: "", password: "", remember: false } })

  useEffect(() => {
    if (user) router.replace(destinationFor(user, next))
  }, [user, next, router])

  const onSubmit = form.handleSubmit(async (values) => {
    try {
      const result = await login(values.email, values.password, values.remember)
      if (result.kind === "code") setPending({ login: result.login, email: result.email })
    } catch (error) {
      // Failed and locked sign-ins get the same answer from the server (audit S4).
      form.setError("root", { message: errorMessage(error) })
    }
  })

  const { errors, isSubmitting } = form.formState

  if (pending)
    return (
      <CodeStep
        pending={pending}
        onBack={() => {
          setPending(null)
          form.setValue("password", "")
        }}
      />
    )

  return (
    <div className="bg-card rounded-2xl border p-6 shadow-sm sm:p-8">
      <div className="mb-6 space-y-1 text-center">
        <h1 className="text-xl font-semibold tracking-tight">{t("login.title")}</h1>
        <p className="text-muted-foreground text-sm">{t("login.subtitle")}</p>
      </div>
      <form onSubmit={onSubmit} className="space-y-4" noValidate>
        <div className="space-y-2">
          <Label htmlFor="email">{t("manage.field.email")}</Label>
          <Input id="email" type="email" autoComplete="username" autoFocus className="h-10" aria-invalid={!!errors.email} {...form.register("email")} />
          {errors.email ? <p className="text-destructive text-xs">{errors.email.message}</p> : null}
        </div>
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <Label htmlFor="password">{t("login.password")}</Label>
            <Link href="/forgot-password" className="text-muted-foreground hover:text-foreground text-xs">
              {t("login.forgot")}
            </Link>
          </div>
          <Input
            id="password"
            type="password"
            autoComplete="current-password"
            className="h-10"
            aria-invalid={!!errors.password}
            {...form.register("password")}
          />
          {errors.password ? <p className="text-destructive text-xs">{errors.password.message}</p> : null}
        </div>
        <label className="text-muted-foreground flex items-center gap-2 text-sm">
          <Checkbox checked={form.watch("remember")} onCheckedChange={(v) => form.setValue("remember", v === true)} />
          <span>
            {t("login.remember")}
            <span className="block text-xs">{t("login.rememberHint")}</span>
          </span>
        </label>
        {errors.root ? (
          <p role="alert" className="bg-destructive/10 text-destructive rounded-lg px-3 py-2 text-sm">
            {errors.root.message}
          </p>
        ) : null}
        <Button type="submit" className="h-10 w-full" disabled={isSubmitting}>
          {isSubmitting ? <Loader2 className="animate-spin" /> : null}
          {t("login.submit")}
        </Button>
      </form>
    </div>
  )
}

/** The 6-digit code from the e-mail; this browser is then trusted for 15 days. */
function CodeStep({ pending, onBack }: { pending: { login: string; email: string }; onBack: () => void }) {
  const t = useT()
  const { confirmCode, resendCode } = useAuth()
  const [code, setCode] = useState("")
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [resending, setResending] = useState(false)
  const complete = code.length === 6

  const submit = async (value: string) => {
    if (value.length !== 6 || busy) return
    setBusy(true)
    setError(null)
    try {
      await confirmCode(pending.login, value)
    } catch (e) {
      setError(errorMessage(e))
      setCode("")
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="bg-card rounded-2xl border p-6 shadow-sm sm:p-8">
      <div className="mb-6 space-y-2 text-center">
        <span className="bg-primary text-primary-foreground mx-auto flex size-10 items-center justify-center rounded-xl">
          <MailCheck className="size-5" />
        </span>
        <h1 className="text-xl font-semibold tracking-tight">{t("login.code.title")}</h1>
        <p className="text-muted-foreground text-sm">{t("login.code.subtitle", { email: pending.email })}</p>
      </div>
      <form
        className="space-y-4"
        noValidate
        onSubmit={(e) => {
          e.preventDefault()
          void submit(code)
        }}
      >
        <div className="space-y-2">
          <Label htmlFor="code">{t("login.code.label")}</Label>
          <Input
            id="code"
            inputMode="numeric"
            autoComplete="one-time-code"
            autoFocus
            maxLength={7}
            placeholder="000000"
            className="h-12 text-center font-mono text-2xl tracking-[0.5em]"
            aria-invalid={!!error}
            aria-describedby="code-hint"
            value={code}
            onChange={(e) => {
              const digits = e.target.value.replace(/\D/g, "").slice(0, 6)
              setCode(digits)
              setError(null)
              // A pasted or auto-filled code signs in without another click.
              if (digits.length === 6) void submit(digits)
            }}
          />
          <p id="code-hint" className="text-muted-foreground text-xs">
            {t("login.code.hint")}
          </p>
        </div>
        {error ? (
          <p role="alert" className="bg-destructive/10 text-destructive rounded-lg px-3 py-2 text-sm">
            {error}
          </p>
        ) : null}
        {notice ? (
          <p role="status" className="text-muted-foreground text-sm">
            {notice}
          </p>
        ) : null}
        <Button type="submit" className="h-10 w-full" disabled={busy || !complete}>
          {busy ? <Loader2 className="animate-spin" /> : null}
          {t("login.code.submit")}
        </Button>
        <div className="flex items-center justify-between text-sm">
          <Button type="button" variant="ghost" size="sm" onClick={onBack}>
            <ArrowLeft /> {t("common.back")}
          </Button>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            disabled={resending}
            onClick={async () => {
              setResending(true)
              setError(null)
              try {
                await resendCode(pending.login)
                setNotice(t("login.code.resent"))
              } catch (e) {
                setError(errorMessage(e))
              } finally {
                setResending(false)
              }
            }}
          >
            {resending ? <Loader2 className="animate-spin" /> : null} {t("login.code.resend")}
          </Button>
        </div>
      </form>
    </div>
  )
}

export default function LoginPage() {
  return (
    <Suspense>
      <LoginForm />
    </Suspense>
  )
}
