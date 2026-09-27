"use client"

import type { ReactNode } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { LayoutDashboard, LogOut, Menu } from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { useAuth } from "@/lib/auth"
import { PlatformNotice } from "@/components/layout/platform-notice"

export function WaiterShell({ children }: { children: ReactNode }) {
  const { user, can, logout } = useAuth()
  const router = useRouter()

  return (
    <div className="bg-background flex min-h-dvh flex-col pt-[env(safe-area-inset-top)] pb-[env(safe-area-inset-bottom)]">
      <PlatformNotice />
      <header className="short:py-1.5 flex items-center justify-between px-5 py-3">
        <div className="min-w-0">
          <p className="truncate text-base font-semibold">{user?.restaurant?.name}</p>
          <p className="text-muted-foreground truncate text-xs">{user?.name}</p>
        </div>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-lg" aria-label="Menu">
              <Menu />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56">
            <DropdownMenuLabel className="font-normal">
              <div className="text-sm font-medium">{user?.name}</div>
              <div className="text-muted-foreground text-xs">{user?.role.name}</div>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            {can("dashboard.view") ? (
              <DropdownMenuItem asChild>
                <Link href="/dashboard">
                  <LayoutDashboard /> Dashboard
                </Link>
              </DropdownMenuItem>
            ) : null}
            <DropdownMenuItem
              onSelect={async () => {
                await logout()
                router.replace("/login")
              }}
            >
              <LogOut /> Sign out
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </header>
      <main className="short:pb-3 mx-auto flex w-full max-w-md flex-1 flex-col px-5 pb-6">{children}</main>
    </div>
  )
}
