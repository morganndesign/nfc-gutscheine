import { Badge } from "@/components/ui/badge"
import type { StaffUser } from "@/lib/api/types"

/** One vocabulary for a team member's state everywhere: Invited → Active, or Locked / Deactivated. */
export function UserStatusBadge({ user }: { user: Pick<StaffUser, "status" | "locked" | "last_login_at"> }) {
  if (user.status !== "active")
    return (
      <Badge variant="outline" className="text-muted-foreground">
        Deactivated
      </Badge>
    )
  if (user.locked) return <Badge variant="destructive">Locked</Badge>
  if (!user.last_login_at) return <Badge variant="outline">Invited</Badge>
  return <Badge variant="secondary">Active</Badge>
}
