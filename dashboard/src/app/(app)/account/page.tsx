"use client"

import { useState } from "react"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { PageHeader } from "@/components/common/page-header"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { api, errorMessage } from "@/lib/api/client"
import { useAuth } from "@/lib/auth"

export default function AccountPage() {
  const { user, refresh } = useAuth()
  const [name, setName] = useState(user?.name ?? "")
  const [saving, setSaving] = useState(false)
  const [current, setCurrent] = useState("")
  const [password, setPassword] = useState("")
  const [confirmation, setConfirmation] = useState("")
  const [changing, setChanging] = useState(false)

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <PageHeader title="Account" description={user?.email} />
      <Card>
        <CardHeader>
          <CardTitle>Profile</CardTitle>
        </CardHeader>
        <CardContent>
          <form
            className="flex flex-col gap-3 sm:flex-row sm:items-end"
            onSubmit={async (e) => {
              e.preventDefault()
              setSaving(true)
              try {
                await api("/auth/profile", { method: "PUT", body: { name } })
                await refresh()
                toast.success("Profile saved")
              } catch (err) {
                toast.error(errorMessage(err))
              } finally {
                setSaving(false)
              }
            }}
          >
            <div className="flex-1 space-y-2">
              <Label htmlFor="name">Name</Label>
              <Input id="name" value={name} onChange={(e) => setName(e.target.value)} required />
            </div>
            <Button type="submit" disabled={saving}>
              {saving ? <Loader2 className="animate-spin" /> : null} Save
            </Button>
          </form>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>Password</CardTitle>
          <CardDescription>Changing your password signs you out on all other devices.</CardDescription>
        </CardHeader>
        <CardContent>
          <form
            className="space-y-4"
            onSubmit={async (e) => {
              e.preventDefault()
              if (password !== confirmation) {
                toast.error("The new passwords do not match.")
                return
              }
              setChanging(true)
              try {
                await api("/auth/password", { method: "PUT", body: { current_password: current, password, password_confirmation: confirmation } })
                toast.success("Password changed")
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
              <Label htmlFor="current">Current password</Label>
              <Input id="current" type="password" autoComplete="current-password" value={current} onChange={(e) => setCurrent(e.target.value)} required />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="new">New password</Label>
                <Input id="new" type="password" autoComplete="new-password" value={password} onChange={(e) => setPassword(e.target.value)} required />
              </div>
              <div className="space-y-2">
                <Label htmlFor="confirm">Repeat new password</Label>
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
              {changing ? <Loader2 className="animate-spin" /> : null} Change password
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
