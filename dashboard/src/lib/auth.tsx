"use client"

import { createContext, useCallback, useContext, useEffect, useMemo, type ReactNode } from "react"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import { usePathname } from "next/navigation"
import { api, ApiError, prefetchCsrfCookie } from "@/lib/api/client"
import { setRegional } from "@/lib/regional"
import type { Permission, SessionUser } from "@/lib/api/types"
import { MANAGE_NAV, PLATFORM_NAV, RESTAURANT_NAV } from "@/components/layout/nav"

interface AuthContextValue {
  user: SessionUser | null
  isLoading: boolean
  /** The session could not be checked (server unreachable or failing) — not the same as "signed out". */
  sessionError: unknown
  can: (permission: Permission) => boolean
  canAny: (...permissions: Permission[]) => boolean
  /** Step 1. A trusted browser is signed in at once; any other gets a code by e-mail (decision 2026-10-05). */
  login: (email: string, password: string, remember: boolean) => Promise<LoginResult>
  /** Step 2: the 6-digit code from the e-mail. */
  confirmCode: (login: string, code: string) => Promise<SessionUser>
  resendCode: (login: string) => Promise<void>
  logout: () => Promise<void>
  refresh: () => Promise<void>
}

export type LoginResult = { kind: "signedIn"; user: SessionUser } | { kind: "code"; login: string; email: string }

type LoginAnswer = { data: SessionUser } | { data: { code_required: true; login: string; email: string } }

const AuthContext = createContext<AuthContextValue | null>(null)

export const SESSION_QUERY_KEY = ["session"] as const

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient()
  // A restaurant's public shop (/g/…) is for guests: no session is asked for there.
  const publicShop = usePathname()?.startsWith("/g/") ?? false

  const { data, isLoading, error } = useQuery({
    queryKey: SESSION_QUERY_KEY,
    enabled: !publicShop,
    queryFn: async () => {
      try {
        return (await api<{ data: SessionUser }>("/auth/me")).data
      } catch (error) {
        if (error instanceof ApiError && (error.status === 401 || error.status === 419)) return null
        throw error
      }
    },
    staleTime: 5 * 60_000,
    retry: false,
  })

  const user = data ?? null

  // Format money and dates in the restaurant's locale and timezone, everywhere.
  // Runs during render (not in an effect) so the very first paint is already correct.
  setRegional(user?.restaurant?.locale, user?.restaurant?.timezone)

  // Fetch the CSRF cookie right away so the first card scan does not pay for an extra round trip.
  useEffect(() => {
    if (user) void prefetchCsrfCookie()
  }, [user])

  const can = useCallback((permission: Permission) => !!user?.permissions.includes(permission), [user])
  const canAny = useCallback((...permissions: Permission[]) => permissions.some((p) => user?.permissions.includes(p)), [user])

  const signedIn = useCallback(
    (user: SessionUser) => {
      // Drop data cached for a previous user, but keep the (observed) session query itself.
      queryClient.removeQueries({ predicate: (q) => q.queryKey[0] !== SESSION_QUERY_KEY[0] })
      queryClient.setQueryData(SESSION_QUERY_KEY, user)
      return user
    },
    [queryClient],
  )

  const login = useCallback(
    async (email: string, password: string, remember: boolean): Promise<LoginResult> => {
      const result = await api<LoginAnswer>("/auth/login", { method: "POST", body: { email, password, remember } })
      if ("code_required" in result.data) return { kind: "code", login: result.data.login, email: result.data.email }
      return { kind: "signedIn", user: signedIn(result.data) }
    },
    [signedIn],
  )

  const confirmCode = useCallback(
    async (login: string, code: string) => {
      const result = await api<{ data: SessionUser }>("/auth/login/code", { method: "POST", body: { login, code } })
      return signedIn(result.data)
    },
    [signedIn],
  )

  const resendCode = useCallback(async (login: string) => {
    await api("/auth/login/code/resend", { method: "POST", body: { login } })
  }, [])

  const logout = useCallback(async () => {
    try {
      await api("/auth/logout", { method: "POST" })
    } finally {
      queryClient.removeQueries({ predicate: (q) => q.queryKey[0] !== SESSION_QUERY_KEY[0] })
      queryClient.setQueryData(SESSION_QUERY_KEY, null)
    }
  }, [queryClient])

  const refresh = useCallback(async () => {
    await queryClient.invalidateQueries({ queryKey: SESSION_QUERY_KEY })
  }, [queryClient])

  const sessionError = data === undefined ? error : null
  const value = useMemo(
    () => ({ user, isLoading, sessionError, can, canAny, login, confirmCode, resendCode, logout, refresh }),
    [user, isLoading, sessionError, can, canAny, login, confirmCode, resendCode, logout, refresh],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error("useAuth must be used inside <AuthProvider>")
  return ctx
}

/** Only same-site paths are accepted as a post-login destination (prevents open redirects like "//evil.com" or "/\\evil.com"). */
export function safeRedirectPath(next: string | null): string | null {
  if (!next || !/^\/(?![\/\\])[^\s\\]*$/.test(next)) return null
  return next
}

/**
 * Whether `path` is a page this user may open: the navigation entry it belongs to (longest matching prefix) must be
 * one of theirs. A link left over from another account (e.g. `?next=/settings` after an owner's session expired,
 * then a platform administrator signs in) must not land them on "no access".
 */
export function mayOpen(user: SessionUser, path: string): boolean {
  const pathname = path.split(/[?#]/)[0]
  const item = [...RESTAURANT_NAV, ...MANAGE_NAV, ...PLATFORM_NAV]
    .filter((i) => pathname === i.href || pathname.startsWith(`${i.href}/`))
    .sort((a, b) => b.href.length - a.href.length)[0]
  if (!item) return !pathname.startsWith("/admin") || user.is_platform_admin
  return user.permissions.includes(item.permission) && (!item.requiresRestaurant || !!user.restaurant)
}

/** After sign-in: the requested page when this user may open it, else their home. */
export function destinationFor(user: SessionUser, next: string | null): string {
  const path = safeRedirectPath(next)
  return path && mayOpen(user, path) ? path : homeFor(user)
}

/** Where a user lands after login, based on what they are allowed to do. */
export function homeFor(user: SessionUser): string {
  if (user.is_platform_admin && !user.restaurant) return "/admin"
  if (user.permissions.includes("dashboard.view")) return "/dashboard"
  return "/waiter"
}
