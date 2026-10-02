"use client"

import { useEffect, type ReactNode } from "react"
import { usePathname, useRouter } from "next/navigation"
import { Loader2 } from "lucide-react"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { homeFor, useAuth } from "@/lib/auth"
import type { Permission } from "@/lib/api/types"
import { useT } from "@/lib/i18n"

export function FullScreenLoader() {
  const t = useT()
  return (
    <div className="flex min-h-dvh items-center justify-center" role="status" aria-label={t("common.loading")}>
      <Loader2 className="text-muted-foreground size-6 animate-spin" />
    </div>
  )
}

/** Client-side route guard. The API enforces every permission independently. */
export function AuthGuard({ children, permission }: { children: ReactNode; permission?: Permission }) {
  const { user, isLoading, can } = useAuth()
  const router = useRouter()
  const pathname = usePathname()

  useEffect(() => {
    if (isLoading) return
    if (!user) router.replace(`/login?next=${encodeURIComponent(pathname)}`)
  }, [isLoading, user, router, pathname])

  if (isLoading || !user) return <FullScreenLoader />
  if (permission && !can(permission)) return <Forbidden />
  return <>{children}</>
}

export function Forbidden() {
  const t = useT()
  const { user } = useAuth()
  const platform = !!user?.is_platform_admin && !user.restaurant
  return (
    <div className="flex min-h-[50vh] flex-col items-center justify-center gap-2 text-center">
      <p className="text-lg font-semibold">{t("accessGuard.title")}</p>
      <p className="text-muted-foreground max-w-sm text-sm">{platform ? t("accessGuard.platformText") : t("accessGuard.text")}</p>
      {user ? (
        <Button asChild variant="outline" className="mt-3">
          <Link href={homeFor(user)}>{t("accessGuard.home")}</Link>
        </Button>
      ) : null}
    </div>
  )
}

export function RequirePermission({ permission, children }: { permission: Permission; children: ReactNode }) {
  const { can } = useAuth()
  return can(permission) ? <>{children}</> : <Forbidden />
}
