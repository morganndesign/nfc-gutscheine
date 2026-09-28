/** Human wording for audit events, shared by the audit log and the card history. */
const LABELS: Record<string, string> = {
  "api_token.created": "API token created",
  "api_token.revoked": "API token revoked",
  "auth.login": "Signed in",
  "auth.logout": "Signed out",
  "auth.failed": "Failed sign-in",
  "auth.locked": "Account locked after failed sign-ins",
  "auth.password_reset": "Password set via e-mail link",
  "customer.anonymized": "Customer anonymized (GDPR)",
  "customer.created": "Customer created",
  "customer.updated": "Customer updated",
  "device.registered": "New device signed in",
  "device.restored": "Device restored",
  "device.revoked": "Device revoked",
  "device.updated": "Device renamed",
  "gift_card.activated": "Card activated",
  "gift_card.balance_transferred": "Balance transferred",
  "gift_card.blocked": "Card blocked",
  "gift_card.expired": "Card expired",
  "gift_card.foreign_scan": "Card of another restaurant scanned",
  "gift_card.issued": "Card issued",
  "gift_card.nfc_replay": "Copied NFC tap rejected",
  "gift_card.nfc_signature_invalid": "Invalid NFC signature rejected",
  "gift_card.nfc_uid_mismatch": "Cloned card rejected",
  "gift_card.nfc_written": "NFC tag written",
  "gift_card.nfc_write_failed": "NFC tag programming failed",
  "gift_card.nfc_write_refused": "NFC tag refused (belongs to another card)",
  "gift_card.nfc_locked": "NFC tag locked",
  "gift_card.nfc_lock_failed": "NFC tag could not be locked",
  "gift_card.redeemed": "Card redeemed",
  "gift_card.reloaded": "Card reloaded",
  "gift_card.replaced": "Card replaced",
  "gift_card.unblocked": "Card unblocked",
  "gift_card.updated": "Card details edited",
  "notification_template.updated": "E-mail template edited",
  "platform.mail_test": "Test e-mail sent",
  "restaurant.archived": "Restaurant archived",
  "restaurant.created": "Restaurant created",
  "restaurant.deleted": "Restaurant deleted permanently",
  "restaurant.reactivated": "Restaurant enabled",
  "restaurant.restored": "Restaurant restored",
  "restaurant.settings_updated": "Card rules changed",
  "restaurant.suspended": "Restaurant disabled",
  "restaurant.updated": "Restaurant profile edited",
  "system_setting.updated": "Platform setting changed",
  "transaction.reversed": "Transaction reversed",
  "user.activated": "Team member reactivated",
  "user.created": "Team member invited",
  "user.deactivated": "Team member deactivated",
  "user.invitation_accepted": "Invitation accepted (account activated)",
  "user.invitation_resent": "Invitation sent again",
  "user.password_changed": "Password changed",
  "user.password_reset_sent": "Password reset e-mail sent",
  "user.profile_updated": "Profile edited",
  "user.updated": "Team member edited",
}

const CATEGORIES: Record<string, string> = {
  api_token: "API",
  auth: "Sign-in",
  customer: "Customer",
  device: "Device",
  gift_card: "Gift card",
  notification_template: "E-mails",
  platform: "Platform",
  restaurant: "Restaurant",
  system_setting: "Platform",
  transaction: "Transaction",
  user: "Team",
}

/** Events an owner should notice: possible fraud or lock-outs. */
const ALERTS = new Set(["auth.locked", "gift_card.foreign_scan", "gift_card.nfc_replay", "gift_card.nfc_signature_invalid", "gift_card.nfc_uid_mismatch"])

export function auditLabel(action: string): string {
  if (LABELS[action]) return LABELS[action]
  const words = (action.split(".").slice(1).join(" ") || action).replace(/_/g, " ")
  return words.charAt(0).toUpperCase() + words.slice(1)
}

export function auditCategory(action: string): string {
  const key = action.split(".")[0] ?? ""
  return CATEGORIES[key] ?? key.replace(/_/g, " ")
}

export function isAuditAlert(action: string): boolean {
  return ALERTS.has(action)
}
