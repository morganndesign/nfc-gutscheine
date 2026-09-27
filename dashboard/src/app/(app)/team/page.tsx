"use client"

import { useState } from "react"
import { KeyRound, Loader2, MoreHorizontal, Pencil, Plus, UserCheck, UserX, Users } from "lucide-react"
import { toast } from "sonner"
import { UserStatusBadge } from "@/components/common/user-status-badge"
import { PageHeader } from "@/components/common/page-header"
import { EmptyState } from "@/components/common/empty-state"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useRoles, useSaveUser, useUserAction, useUsers } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { StaffUser } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { formatRelative } from "@/lib/format"

function UserDialog({ user, open, onOpenChange }: { user?: StaffUser; open: boolean; onOpenChange: (o: boolean) => void }) {
  const roles = useRoles()
  const save = useSaveUser(user?.id)
  const [name, setName] = useState(user?.name ?? "")
  const [email, setEmail] = useState(user?.email ?? "")
  const [role, setRole] = useState<string>(user?.role?.slug ?? "waiter")
  const assignable = roles.data?.filter((r) => r.assignable) ?? []

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{user ? "Edit team member" : "Invite team member"}</DialogTitle>
          {!user ? <DialogDescription>They receive an e-mail with a link to set their password.</DialogDescription> : null}
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            try {
              await save.mutateAsync({ name, email, role })
              toast.success(user ? "Team member updated" : `Invitation sent to ${email}`)
              onOpenChange(false)
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="u-name">Name</Label>
            <Input id="u-name" required value={name} onChange={(e) => setName(e.target.value)} />
          </div>
          <div className="space-y-2">
            <Label htmlFor="u-email">E-mail</Label>
            <Input id="u-email" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
          </div>
          <div className="space-y-2">
            <Label htmlFor="u-role">Role</Label>
            <Select value={role} onValueChange={setRole}>
              <SelectTrigger id="u-role" className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {assignable.map((r) => (
                  <SelectItem key={r.slug} value={r.slug}>
                    {r.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <p className="text-muted-foreground text-xs">{roles.data?.find((r) => r.slug === role)?.description}</p>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={save.isPending}>
              {save.isPending ? <Loader2 className="animate-spin" /> : null} {user ? "Save" : "Send invitation"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function TeamContent() {
  const { user: me, can } = useAuth()
  const { data, isLoading } = useUsers()
  const action = useUserAction()
  const [editing, setEditing] = useState<StaffUser | "new" | null>(null)
  const manage = can("users.manage")

  const run = async (id: string, act: "deactivate" | "activate" | "password-reset", msg: string) => {
    try {
      await action.mutateAsync({ id, action: act })
      toast.success(msg)
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Team"
        description="Everyone who can sign in to your restaurant."
        actions={
          manage ? (
            <Button onClick={() => setEditing("new")}>
              <Plus /> Invite
            </Button>
          ) : null
        }
      />
      <div className="bg-card overflow-hidden rounded-2xl border">
        {isLoading ? (
          <div className="space-y-2 p-4">
            {Array.from({ length: 4 }).map((_, i) => (
              <Skeleton key={i} className="h-12 w-full" />
            ))}
          </div>
        ) : data?.data.length ? (
          <Table>
            <TableHeader>
              <TableRow className="hover:bg-transparent">
                <TableHead className="pl-4">Name</TableHead>
                <TableHead className="hidden sm:table-cell">Role</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="hidden md:table-cell">Last sign-in</TableHead>
                <TableHead className="w-10 pr-4" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.data.map((u) => (
                <TableRow key={u.id}>
                  <TableCell className="pl-4">
                    <div className="font-medium">
                      {u.name} {u.id === me?.id ? <span className="text-muted-foreground text-xs font-normal">(you)</span> : null}
                    </div>
                    <div className="text-muted-foreground text-xs">{u.email}</div>
                    <div className="text-muted-foreground text-xs sm:hidden">{u.role?.name}</div>
                  </TableCell>
                  <TableCell className="hidden sm:table-cell">{u.role?.name}</TableCell>
                  <TableCell>
                    <UserStatusBadge user={u} />
                  </TableCell>
                  <TableCell className="text-muted-foreground hidden md:table-cell">{formatRelative(u.last_login_at)}</TableCell>
                  <TableCell className="pr-4">
                    {manage && u.id !== me?.id ? (
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon-sm" aria-label={`Actions for ${u.name}`}>
                            <MoreHorizontal />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem onSelect={() => setEditing(u)}>
                            <Pencil /> Edit
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onSelect={() => run(u.id, "password-reset", u.last_login_at ? "Password reset e-mail sent" : "Invitation sent again")}
                          >
                            <KeyRound /> {u.last_login_at ? "Send password reset" : "Resend invitation"}
                          </DropdownMenuItem>
                          {u.status === "active" ? (
                            <DropdownMenuItem variant="destructive" onSelect={() => run(u.id, "deactivate", `${u.name} deactivated`)}>
                              <UserX /> Deactivate
                            </DropdownMenuItem>
                          ) : (
                            <DropdownMenuItem onSelect={() => run(u.id, "activate", `${u.name} reactivated`)}>
                              <UserCheck /> Reactivate
                            </DropdownMenuItem>
                          )}
                        </DropdownMenuContent>
                      </DropdownMenu>
                    ) : null}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        ) : (
          <EmptyState icon={Users} title="No team members" />
        )}
      </div>
      {editing ? (
        <UserDialog
          key={editing === "new" ? "new" : editing.id}
          user={editing === "new" ? undefined : editing}
          open
          onOpenChange={(o) => !o && setEditing(null)}
        />
      ) : null}
    </div>
  )
}

export default function TeamPage() {
  return (
    <RequirePermission permission="users.view">
      <TeamContent />
    </RequirePermission>
  )
}
