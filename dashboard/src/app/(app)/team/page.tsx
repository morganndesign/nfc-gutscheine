"use client"

import { useState } from "react"
import { Gift, KeyRound, Loader2, MoreHorizontal, Pencil, Plus, UserCheck, UserX, Users } from "lucide-react"
import { toast } from "sonner"
import { UserStatusBadge } from "@/components/common/user-status-badge"
import { PageHeader } from "@/components/common/page-header"
import { EmptyState } from "@/components/common/empty-state"
import { QueryError } from "@/components/common/query-error"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Skeleton } from "@/components/ui/skeleton"
import { Switch } from "@/components/ui/switch"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useLoyaltyGrant, useRoles, useSaveUser, useUserAction, useUsers } from "@/lib/api/hooks"
import { ApiError, errorMessage } from "@/lib/api/client"
import type { StaffUser } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { formatRelative } from "@/lib/format"
import { useConfirm } from "@/components/common/confirm"
import { LANGUAGES, toLanguage, useT, type Language } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

function UserDialog({ user, open, onOpenChange }: { user?: StaffUser; open: boolean; onOpenChange: (o: boolean) => void }) {
  const roles = useRoles()
  const save = useSaveUser(user?.id)
  const [name, setName] = useState(user?.name ?? "")
  const [email, setEmail] = useState(user?.email ?? "")
  const t = useT()
  const [role, setRole] = useState<string>(user?.role?.slug ?? "waiter")
  const [locale, setLocale] = useState<Language>(user ? toLanguage(user.locale) : "de")
  const assignable = roles.data?.filter((r) => r.assignable) ?? []
  // Server validation (e-mail already taken, …) is shown next to its field, in the user's language.
  const [fieldErrors, setFieldErrors] = useState<Record<string, string[]>>({})
  const fieldError = (field: string) =>
    fieldErrors[field]?.[0] ? (
      <p id={`u-${field}-error`} className="text-destructive text-xs">
        {fieldErrors[field][0]}
      </p>
    ) : null

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{user ? t("team.dialog.editTitle") : t("team.dialog.inviteTitle")}</DialogTitle>
          {!user ? <DialogDescription>{t("team.dialog.inviteDescription")}</DialogDescription> : null}
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            setFieldErrors({})
            try {
              await save.mutateAsync({ name, email, role, locale })
              toast.success(user ? t("team.dialog.updated") : t("team.dialog.invited", { email }))
              onOpenChange(false)
            } catch (err) {
              if (err instanceof ApiError && err.code === "VALIDATION_FAILED") setFieldErrors(err.fieldErrors)
              else toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="u-name">{t("manage.field.name")}</Label>
            <Input
              id="u-name"
              required
              value={name}
              aria-invalid={!!fieldErrors.name}
              aria-describedby={fieldErrors.name ? "u-name-error" : undefined}
              onChange={(e) => setName(e.target.value)}
            />
            {fieldError("name")}
          </div>
          <div className="space-y-2">
            <Label htmlFor="u-email">{t("manage.field.email")}</Label>
            <Input
              id="u-email"
              type="email"
              required
              value={email}
              aria-invalid={!!fieldErrors.email}
              aria-describedby={fieldErrors.email ? "u-email-error" : undefined}
              onChange={(e) => setEmail(e.target.value)}
            />
            {fieldError("email")}
          </div>
          <div className="space-y-2">
            <Label htmlFor="u-role">{t("team.role")}</Label>
            <Select value={role} onValueChange={setRole}>
              <SelectTrigger id="u-role" className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {assignable.map((r) => (
                  <SelectItem key={r.slug} value={r.slug}>
                    {t(`roles.${r.slug}` as MessageKey)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <p className="text-muted-foreground text-xs">{t(`team.roleDescription.${role}` as MessageKey)}</p>
            {fieldError("role")}
          </div>
          <div className="space-y-2">
            <Label htmlFor="u-locale">{t("common.language")}</Label>
            <Select value={locale} onValueChange={(v) => setLocale(toLanguage(v))}>
              <SelectTrigger id="u-locale" className="w-full">
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
            <p className="text-muted-foreground text-xs">{t("team.dialog.languageHint")}</p>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={save.isPending}>
              {save.isPending ? <Loader2 className="animate-spin" /> : null} {user ? t("common.save") : t("team.dialog.sendInvitation")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

/**
 * Loyalty (decision 2026-10-05): owners give it by role; the owner chooses which managers may too. Waiters never.
 */
function LoyaltyGrants({ users }: { users: StaffUser[] }) {
  const t = useT()
  const grant = useLoyaltyGrant()
  const managers = users.filter((u) => u.role?.slug === "manager")
  const [pending, setPending] = useState<string | null>(null)

  const change = async (u: StaffUser, allowed: boolean) => {
    setPending(u.id)
    try {
      await grant.mutateAsync({ id: u.id, allowed })
      toast.success(allowed ? t("team.loyalty.allowed", { name: u.name }) : t("team.loyalty.revoked", { name: u.name }))
    } catch (e) {
      toast.error(errorMessage(e))
    } finally {
      setPending(null)
    }
  }

  return (
    <section aria-labelledby="loyalty-grants" className="bg-card rounded-2xl border p-4 sm:p-5">
      <div className="flex items-start gap-3">
        <Gift className="text-muted-foreground mt-0.5 size-5 shrink-0" aria-hidden />
        <div className="space-y-1">
          <h2 id="loyalty-grants" className="font-medium">
            {t("team.loyalty.title")}
          </h2>
          <p className="text-muted-foreground text-sm">{t("team.loyalty.description")}</p>
        </div>
      </div>
      {managers.length ? (
        <ul className="mt-4 divide-y">
          {managers.map((u) => (
            <li key={u.id} className="flex items-center justify-between gap-4 py-3">
              <div className="min-w-0">
                <div className="truncate text-sm font-medium">{u.name}</div>
                <div className="text-muted-foreground truncate text-xs">
                  {u.status === "active" ? u.email : t("team.loyalty.inactive")}
                </div>
              </div>
              <div className="flex items-center gap-2">
                {pending === u.id ? <Loader2 className="text-muted-foreground size-4 animate-spin" aria-hidden /> : null}
                <Switch
                  checked={!!u.can_give_loyalty}
                  disabled={pending !== null}
                  aria-label={t("team.loyalty.switch", { name: u.name })}
                  onCheckedChange={(v) => void change(u, v)}
                />
              </div>
            </li>
          ))}
        </ul>
      ) : (
        <p className="text-muted-foreground mt-4 text-sm">{t("team.loyalty.noManagers")}</p>
      )}
    </section>
  )
}

function TeamContent() {
  const t = useT()
  const confirm = useConfirm()
  const { user: me, can } = useAuth()
  const { data, isLoading, error, refetch } = useUsers()
  const action = useUserAction()
  const [editing, setEditing] = useState<StaffUser | "new" | null>(null)
  const manage = can("users.manage")

  const run = async (u: StaffUser, act: "deactivate" | "activate" | "password-reset") => {
    const invited = !u.last_login_at
    const ask =
      act === "deactivate"
        ? {
            title: t("team.confirmDeactivate.title", { name: u.name }),
            description: t("team.confirmDeactivate.description", { name: u.name }),
            confirmLabel: t("team.deactivate"),
            destructive: true,
          }
        : act === "activate"
          ? {
              title: t("team.confirmReactivate.title", { name: u.name }),
              description: t("team.confirmReactivate.description", { name: u.name }),
              confirmLabel: t("team.reactivate"),
            }
          : invited
            ? {
                title: t("team.confirmResend.title"),
                description: t("team.confirmResend.description", { email: u.email }),
                confirmLabel: t("team.resendInvitation"),
              }
            : {
                title: t("team.confirmReset.title"),
                description: t("team.confirmReset.description", { email: u.email }),
                confirmLabel: t("team.confirmReset.confirm"),
              }
    if (!(await confirm(ask))) return
    const msg =
      act === "deactivate"
        ? t("team.deactivated", { name: u.name })
        : act === "activate"
          ? t("team.reactivated", { name: u.name })
          : invited
            ? t("team.invitationResent")
            : t("team.passwordResetSent")
    try {
      await action.mutateAsync({ id: u.id, action: act })
      toast.success(msg)
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("team.title")}
        description={t("team.description")}
        actions={
          manage ? (
            <Button onClick={() => setEditing("new")}>
              <Plus /> {t("team.invite")}
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
        ) : error && !data ? (
          <QueryError error={error} onRetry={() => void refetch()} />
        ) : data?.data.length ? (
          <Table>
            <TableHeader>
              <TableRow className="hover:bg-transparent">
                <TableHead className="pl-4">{t("manage.field.name")}</TableHead>
                <TableHead className="hidden sm:table-cell">{t("team.role")}</TableHead>
                <TableHead>{t("team.column.status")}</TableHead>
                <TableHead className="hidden md:table-cell">{t("team.column.lastSignIn")}</TableHead>
                <TableHead className="w-10 pr-4" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.data.map((u) => (
                <TableRow key={u.id}>
                  <TableCell className="pl-4">
                    <div className="font-medium">
                      {u.name} {u.id === me?.id ? <span className="text-muted-foreground text-xs font-normal">{t("team.you")}</span> : null}
                    </div>
                    <div className="text-muted-foreground text-xs">{u.email}</div>
                    <div className="text-muted-foreground text-xs sm:hidden">{u.role ? t(`roles.${u.role.slug}` as MessageKey) : null}</div>
                  </TableCell>
                  <TableCell className="hidden sm:table-cell">{u.role ? t(`roles.${u.role.slug}` as MessageKey) : null}</TableCell>
                  <TableCell>
                    <UserStatusBadge user={u} />
                  </TableCell>
                  <TableCell className="text-muted-foreground hidden md:table-cell">{formatRelative(u.last_login_at)}</TableCell>
                  <TableCell className="pr-4">
                    {manage && u.id !== me?.id ? (
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon-sm" aria-label={t("team.actionsFor", { name: u.name })}>
                            <MoreHorizontal />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem onSelect={() => setEditing(u)}>
                            <Pencil /> {t("common.edit")}
                          </DropdownMenuItem>
                          <DropdownMenuItem onSelect={() => void run(u, "password-reset")}>
                            <KeyRound /> {u.last_login_at ? t("team.sendPasswordReset") : t("team.resendInvitation")}
                          </DropdownMenuItem>
                          {u.status === "active" ? (
                            <DropdownMenuItem variant="destructive" onSelect={() => void run(u, "deactivate")}>
                              <UserX /> {t("team.deactivate")}
                            </DropdownMenuItem>
                          ) : (
                            <DropdownMenuItem onSelect={() => void run(u, "activate")}>
                              <UserCheck /> {t("team.reactivate")}
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
          <EmptyState icon={Users} title={t("team.empty")} />
        )}
      </div>
      {manage && me?.role.slug === "owner" && data ? <LoyaltyGrants users={data.data} /> : null}
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
