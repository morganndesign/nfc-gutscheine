"use client"

import { Suspense, useEffect, useMemo } from "react"
import Link from "next/link"
import { useRouter, useSearchParams } from "next/navigation"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { errorMessage } from "@/lib/api/client"
import { destinationFor, useAuth } from "@/lib/auth"
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
  const { user, login } = useAuth()
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
      await login(values.email, values.password, values.remember)
    } catch (error) {
      // Failed and locked sign-ins get the same answer from the server (audit S4).
      form.setError("root", { message: errorMessage(error) })
    }
  })

  const { errors, isSubmitting } = form.formState

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

export default function LoginPage() {
  return (
    <Suspense>
      <LoginForm />
    </Suspense>
  )
}
