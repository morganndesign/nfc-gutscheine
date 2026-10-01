"use client"

import { Badge } from "@/components/ui/badge"
import type { StaffUser } from "@/lib/api/types"
import { useT } from "@/lib/i18n"

/** One vocabulary for a team member's state everywhere: Invited → Active, or Locked / Deactivated. */
export function UserStatusBadge({ user }: { user: Pick<StaffUser, "status" | "locked" | "last_login_at"> }) {
  const t = useT()
  if (user.status !== "active")
    return (
      <Badge variant="outline" className="text-muted-foreground">
        {t("userStatus.deactivated")}
      </Badge>
    )
  if (user.locked) return <Badge variant="destructive">{t("userStatus.locked")}</Badge>
  if (!user.last_login_at) return <Badge variant="outline">{t("userStatus.invited")}</Badge>
  return <Badge variant="secondary">{t("userStatus.active")}</Badge>
}
