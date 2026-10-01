import { Badge } from "@/components/ui/badge"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import type { InvitationSummary } from "@/lib/api/types"
import { formatDateTime } from "@/lib/format"
import { useT, type Translate } from "@/lib/i18n"

/** Whether "Invite again" makes sense: the account has not chosen a password yet. */
export function canInviteAgain(invitation: InvitationSummary | null | undefined): boolean {
  return invitation != null && invitation.status !== "accepted"
}

/** One line explaining the invitation state, for tooltips and dialogs. */
export function invitationDetail(invitation: InvitationSummary, t: Translate): string {
  if (invitation.status === "accepted") return t("admin.invitation.accepted")
  if (invitation.delivery === "failed") return t("admin.invitation.failed", { error: invitation.error ?? t("admin.invitation.mailServerError") })
  // The server's reason for "logged" is always the same English hint (MAIL_MAILER=log): say it in the UI language.
  if (invitation.delivery === "logged") return t("admin.invitation.logged")
  if (invitation.delivery === "queued") return t("admin.invitation.queued")
  if (invitation.status === "pending")
    return t("admin.invitation.pending", { sent: formatDateTime(invitation.last_sent_at), expires: formatDateTime(invitation.expires_at) })
  if (invitation.status === "expired") return t("admin.invitation.expired")
  return t("admin.invitation.notSent")
}

/**
 * Invitation state of an account that has not signed in yet. Delivery problems win over the link state,
 * because a "pending" link nobody received is the case the admin has to act on.
 */
export function InvitationBadge({ invitation }: { invitation: InvitationSummary | null | undefined }) {
  const t = useT()
  if (!invitation || invitation.status === "accepted") return null

  const [label, variant] =
    invitation.delivery === "failed" || invitation.delivery === "logged"
      ? ([t("admin.invitation.badgeNotDelivered"), "destructive"] as const)
      : invitation.delivery === "queued"
        ? ([t("admin.invitation.badgeSending"), "outline"] as const)
        : invitation.status === "pending"
          ? ([t("admin.invitation.badgePending"), "outline"] as const)
          : invitation.status === "expired"
            ? ([t("admin.invitation.badgeExpired"), "outline"] as const)
            : ([t("admin.invitation.badgeNotInvited"), "outline"] as const)

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Badge variant={variant} className="cursor-default">
          {label}
        </Badge>
      </TooltipTrigger>
      <TooltipContent className="max-w-xs">{invitationDetail(invitation, t)}</TooltipContent>
    </Tooltip>
  )
}
