import { Badge } from "@/components/ui/badge"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import type { InvitationSummary } from "@/lib/api/types"
import { formatDateTime } from "@/lib/format"

/** Whether "Invite again" makes sense: the account has not chosen a password yet. */
export function canInviteAgain(invitation: InvitationSummary | null | undefined): boolean {
  return invitation != null && invitation.status !== "accepted"
}

/** One line explaining the invitation state, for tooltips and dialogs. */
export function invitationDetail(invitation: InvitationSummary): string {
  if (invitation.status === "accepted") return "The account is active."
  if (invitation.delivery === "failed") return `The last invitation could not be sent: ${invitation.error ?? "mail server error"}`
  if (invitation.delivery === "logged") return invitation.error ?? "E-mail is not delivered by this platform (MAIL_MAILER=log)."
  if (invitation.delivery === "queued") return "The invitation is being sent. Refresh in a moment to see whether it went out."
  if (invitation.status === "pending")
    return `Invitation sent ${formatDateTime(invitation.last_sent_at)}; the link is valid until ${formatDateTime(invitation.expires_at)}.`
  if (invitation.status === "expired") return "The invitation link has expired. Send it again."
  return "No invitation has been sent yet."
}

/**
 * Invitation state of an account that has not signed in yet. Delivery problems win over the link state,
 * because a "pending" link nobody received is the case the admin has to act on.
 */
export function InvitationBadge({ invitation }: { invitation: InvitationSummary | null | undefined }) {
  if (!invitation || invitation.status === "accepted") return null

  const [label, variant] =
    invitation.delivery === "failed" || invitation.delivery === "logged"
      ? (["Invitation not delivered", "destructive"] as const)
      : invitation.delivery === "queued"
        ? (["Sending invitation…", "outline"] as const)
        : invitation.status === "pending"
          ? (["Invitation pending", "outline"] as const)
          : invitation.status === "expired"
            ? (["Invitation expired", "outline"] as const)
            : (["Not invited", "outline"] as const)

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Badge variant={variant} className="cursor-default">
          {label}
        </Badge>
      </TooltipTrigger>
      <TooltipContent className="max-w-xs">{invitationDetail(invitation)}</TooltipContent>
    </Tooltip>
  )
}
