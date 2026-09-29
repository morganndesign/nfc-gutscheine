"use client"

import Link from "next/link"
import { ArrowRight, QrCode, Settings2, Ticket, Users } from "lucide-react"
import type { LucideIcon } from "lucide-react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { useAuth } from "@/lib/auth"
import type { Permission } from "@/lib/api/types"

const STEPS: { title: string; description: string; href: string; icon: LucideIcon; permission: Permission }[] = [
  { title: "Check your voucher rules", description: "Values, limits and validity", href: "/settings", icon: Settings2, permission: "settings.manage" },
  { title: "Invite your team", description: "Managers and waiters get an e-mail", href: "/team", icon: Users, permission: "users.manage" },
  { title: "Sell the first voucher", description: "Record the payment and print the QR", href: "/vouchers/new", icon: Ticket, permission: "vouchers.sell" },
  { title: "Install the waiter app", description: "Scan a voucher and redeem in seconds", href: "/waiter", icon: QrCode, permission: "vouchers.redeem" },
]

/** Shown on the dashboard of a brand-new restaurant until the first voucher has been sold. */
export function GettingStarted() {
  const { can } = useAuth()
  const steps = STEPS.filter((s) => can(s.permission))
  if (!steps.length) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>Welcome to GiftCard Pro</CardTitle>
        <CardDescription>A few quick steps and your restaurant is ready to sell vouchers.</CardDescription>
      </CardHeader>
      <CardContent>
        <ol className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          {steps.map((step) => (
            <li key={step.href}>
              <Link
                href={step.href}
                className="group hover:bg-muted/60 focus-visible:ring-ring/50 flex h-full items-start gap-3 rounded-xl border p-4 transition-colors outline-none focus-visible:ring-[3px]"
              >
                <span className="bg-muted text-foreground flex size-9 shrink-0 items-center justify-center rounded-full" aria-hidden>
                  <step.icon className="size-4" />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block text-sm font-medium">{step.title}</span>
                  <span className="text-muted-foreground mt-0.5 block text-xs">{step.description}</span>
                </span>
                <ArrowRight className="text-muted-foreground mt-2 size-4 shrink-0 transition-transform group-hover:translate-x-0.5" aria-hidden />
              </Link>
            </li>
          ))}
        </ol>
      </CardContent>
    </Card>
  )
}
