"use client"

import { AuthGuard } from "@/components/layout/auth-guard"
import { WaiterShell } from "@/components/waiter/waiter-shell"
import { WaiterTerminal } from "@/components/waiter/terminal"

export default function WaiterPage() {
  return (
    <AuthGuard permission="vouchers.redeem">
      <WaiterShell>
        <WaiterTerminal />
      </WaiterShell>
    </AuthGuard>
  )
}
