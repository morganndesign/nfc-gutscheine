/** Human wording for audit events, shared by the audit log and the voucher history. */
const LABELS: Record<string, string> = {
  "api_token.created": "API token created",
  "api_token.revoked": "API token revoked",
  "auth.login": "Signed in",
  "auth.logout": "Signed out",
  "auth.failed": "Failed sign-in",
  "auth.locked": "Account locked after failed sign-ins",
  "auth.locked_attempt": "Sign-in attempt on a locked account",
  "auth.access_revoked": "All sign-ins and tokens revoked",
  "auth.device_token_issued": "Waiter app signed in",
  "auth.password_reset": "Password set via e-mail link",
  "customer.anonymized": "Customer anonymized (GDPR)",
  "customer.created": "Customer created",
  "customer.updated": "Customer updated",
  "device.registered": "New device signed in",
  "device.restored": "Device restored",
  "device.revoked": "Device revoked",
  "device.updated": "Device renamed",
  "medium.issued": "QR code issued",
  "medium.revoked": "QR code revoked",
  "notification_template.updated": "E-mail template edited",
  "presentment.failed": "Unknown or foreign voucher code scanned",
  "presentment.rejected": "Redemption with an invalid scan refused",
  "platform.mail_test": "Test e-mail sent",
  "restaurant.archived": "Restaurant archived",
  "restaurant.created": "Restaurant created",
  "restaurant.deleted": "Restaurant deleted permanently",
  "restaurant.reactivated": "Restaurant enabled",
  "restaurant.restored": "Restaurant restored",
  "restaurant.settings_updated": "Voucher rules changed",
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
  "voucher.blocked": "Voucher blocked",
  "voucher.expired": "Voucher expired (balance kept)",
  "voucher.redeemed": "Voucher redeemed",
  "voucher.reinstated": "Voucher reinstated",
  "voucher.reloaded": "Voucher reloaded",
  "voucher.sold": "Voucher sold",
  "voucher.unblocked": "Voucher unblocked",
  "voucher.updated": "Voucher details edited",
}

const CATEGORIES: Record<string, string> = {
  api_token: "API",
  auth: "Sign-in",
  customer: "Customer",
  device: "Device",
  medium: "Voucher",
  presentment: "Voucher",
  voucher: "Voucher",
  notification_template: "E-mails",
  platform: "Platform",
  restaurant: "Restaurant",
  system_setting: "Platform",
  transaction: "Transaction",
  user: "Team",
}

/** Events an owner should notice: possible fraud or lock-outs. */
const ALERTS = new Set(["auth.locked", "auth.locked_attempt", "presentment.failed", "presentment.rejected"])

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
