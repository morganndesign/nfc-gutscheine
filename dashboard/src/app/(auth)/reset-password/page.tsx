"use client"

import { Suspense, useState } from "react"
import Link from "next/link"
import { useRouter, useSearchParams } from "next/navigation"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { api, errorMessage } from "@/lib/api/client"

function ResetForm() {
  const params = useSearchParams()
  const router = useRouter()
  const [password, setPassword] = useState("")
  const [confirmation, setConfirmation] = useState("")
  const [pending, setPending] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const token = params.get("token") ?? ""
  const email = params.get("email") ?? ""
  const invite = params.get("invite") === "1"

  if (!token || !email) {
    return (
      <div className="bg-card rounded-2xl border p-8 text-center text-sm">
        This link is incomplete.{" "}
        <Link href="/forgot-password" className="underline">
          Request a new one
        </Link>
        .
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
          setError("The passwords do not match.")
          return
        }
        setPending(true)
        try {
          await api("/auth/reset-password", { method: "POST", body: { token, email, password, password_confirmation: confirmation } })
          toast.success(invite ? "Your account is ready. Sign in with your new password." : "Password saved. You can sign in now.")
          router.replace("/login")
        } catch (err) {
          setError(errorMessage(err))
        } finally {
          setPending(false)
        }
      }}
    >
      <div className="space-y-1 text-center">
        <h1 className="text-xl font-semibold tracking-tight">{invite ? "Welcome to GiftCard Pro" : "Choose a new password"}</h1>
        {invite ? <p className="text-muted-foreground text-sm">Choose a password to activate your account.</p> : null}
        <p className="text-muted-foreground text-sm">{email}</p>
      </div>
      <div className="space-y-2">
        <Label htmlFor="password">New password</Label>
        <Input
          id="password"
          type="password"
          autoComplete="new-password"
          minLength={10}
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="h-10"
        />
        <p className="text-muted-foreground text-xs">At least 12 characters with upper- and lower-case letters and a number.</p>
      </div>
      <div className="space-y-2">
        <Label htmlFor="confirmation">Repeat password</Label>
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
        {pending ? <Loader2 className="animate-spin" /> : null} Save password
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
