"use client"

import type { ReactNode } from "react"
import { AppSidebar } from "@/components/layout/app-sidebar"
import { ActingBanner } from "@/components/layout/acting-banner"
import { AuthGuard } from "@/components/layout/auth-guard"
import { PlatformNotice } from "@/components/layout/platform-notice"
import { SidebarInset, SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar"
import { Separator } from "@/components/ui/separator"
import { useAuth } from "@/lib/auth"

function TopBar() {
  const { user } = useAuth()
  return (
    <header className="bg-background/80 supports-[backdrop-filter]:bg-background/70 sticky top-0 z-20 flex h-14 shrink-0 items-center gap-2 border-b px-4 backdrop-blur">
      <SidebarTrigger className="-ml-1" />
      <Separator orientation="vertical" className="mr-2 h-4" />
      <span className="text-muted-foreground truncate text-sm">{user?.restaurant?.name ?? "Platform"}</span>
    </header>
  )
}

export default function AppLayout({ children }: { children: ReactNode }) {
  return (
    <AuthGuard>
      <SidebarProvider>
        <AppSidebar />
        <SidebarInset className="min-w-0">
          <PlatformNotice />
          <ActingBanner />
          <TopBar />
          <main className="mx-auto w-full max-w-7xl flex-1 px-4 py-6 sm:px-6 lg:px-8 lg:py-8">{children}</main>
        </SidebarInset>
      </SidebarProvider>
    </AuthGuard>
  )
}
