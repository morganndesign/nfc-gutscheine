"use client"

import { Suspense, useEffect } from "react"
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
import { ApiError, errorMessage } from "@/lib/api/client"
import { homeFor, safeRedirectPath, useAuth } from "@/lib/auth"

const schema = z.object({
  email: z.string().trim().email("Enter a valid e-mail address"),
  password: z.string().min(1, "Enter your password"),
  remember: z.boolean(),
})
type Values = z.infer<typeof schema>

function LoginForm() {
  const { user, login } = useAuth()
  const router = useRouter()
  const params = useSearchParams()
  const next = params.get("next")

  const form = useForm<Values>({ resolver: zodResolver(schema), defaultValues: { email: "", password: "", remember: false } })

  useEffect(() => {
    if (user) router.replace(safeRedirectPath(next) ?? homeFor(user))
  }, [user, next, router])

  const onSubmit = form.handleSubmit(async (values) => {
    try {
      await login(values.email, values.password, values.remember)
    } catch (error) {
      if (error instanceof ApiError && error.code === "ACCOUNT_LOCKED") {
        const minutes = Math.ceil((error.body.retry_after ?? 900) / 60)
        form.setError("root", { message: `Too many failed attempts. Try again in ${minutes} minute${minutes === 1 ? "" : "s"}.` })
      } else {
        form.setError("root", { message: errorMessage(error) })
      }
    }
  })

  const { errors, isSubmitting } = form.formState

  return (
    <div className="bg-card rounded-2xl border p-6 shadow-sm sm:p-8">
      <div className="mb-6 space-y-1 text-center">
        <h1 className="text-xl font-semibold tracking-tight">Sign in</h1>
        <p className="text-muted-foreground text-sm">Welcome back. Sign in to your restaurant.</p>
      </div>
      <form onSubmit={onSubmit} className="space-y-4" noValidate>
        <div className="space-y-2">
          <Label htmlFor="email">E-mail</Label>
          <Input id="email" type="email" autoComplete="username" autoFocus className="h-10" aria-invalid={!!errors.email} {...form.register("email")} />
          {errors.email ? <p className="text-destructive text-xs">{errors.email.message}</p> : null}
        </div>
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <Label htmlFor="password">Password</Label>
            <Link href="/forgot-password" className="text-muted-foreground hover:text-foreground text-xs">
              Forgot password?
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
            Keep me signed in on this device
            <span className="block text-xs">Only on your own device, never on a shared one.</span>
          </span>
        </label>
        {errors.root ? (
          <p role="alert" className="bg-destructive/10 text-destructive rounded-lg px-3 py-2 text-sm">
            {errors.root.message}
          </p>
        ) : null}
        <Button type="submit" className="h-10 w-full" disabled={isSubmitting}>
          {isSubmitting ? <Loader2 className="animate-spin" /> : null}
          Sign in
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
