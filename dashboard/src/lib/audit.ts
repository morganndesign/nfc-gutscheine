import { tr } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

// Human wording for audit events (in the UI language), shared by the audit log and the voucher history.

/**
 * Every audit action the backend writes (keep complete: `grep -rn "audit->log(" backend/app`). Translated as
 * `audit.action.<action>`.
 */
const ACTIONS = new Set([
  "api_token.created",
  "api_token.revoked",
  "auth.login",
  "auth.logout",
  "auth.failed",
  "auth.locked",
  "auth.locked_attempt",
  "auth.access_revoked",
  "auth.device_token_issued",
  "auth.password_reset",
  "card.replaced",
  "customer.anonymized",
  "customer.created",
  "customer.updated",
  "device.registered",
  "device.restored",
  "device.revoked",
  "device.updated",
  "medium.issued",
  "medium.revoked",
  "notification_template.updated",
  "presentment.failed",
  "presentment.rejected",
  "platform.mail_test",
  "restaurant.archived",
  "restaurant.created",
  "restaurant.deleted",
  "restaurant.owner_invited",
  "restaurant.reactivated",
  "restaurant.restored",
  "restaurant.settings_updated",
  "restaurant.suspended",
  "restaurant.updated",
  "security_alert.acknowledged",
  "system_setting.updated",
  "transaction.reversed",
  "user.activated",
  "user.created",
  "user.deactivated",
  "user.invitation_accepted",
  "user.invitation_resent",
  "user.password_changed",
  "user.password_reset_sent",
  "user.profile_updated",
  "user.updated",
  "voucher.blocked",
  "voucher.expired",
  "voucher.qr_reissued",
  "voucher.redeemed",
  "voucher.refunded",
  "voucher.reinstated",
  "voucher.reloaded",
  "voucher.sale_cancelled",
  "voucher.sold",
  "voucher.unblocked",
  "voucher.updated",
])

/** Prefix of the action → category key (`audit.category.<key>`). */
const CATEGORIES: Record<string, string> = {
  api_token: "api_token",
  auth: "auth",
  card: "card",
  customer: "customer",
  device: "device",
  medium: "voucher",
  presentment: "voucher",
  voucher: "voucher",
  notification_template: "notification_template",
  platform: "platform",
  restaurant: "restaurant",
  security_alert: "security_alert",
  system_setting: "platform",
  transaction: "transaction",
  user: "user",
}

/** Events an owner should notice: possible fraud or lock-outs. */
const ALERTS = new Set(["auth.locked", "auth.locked_attempt", "presentment.failed", "presentment.rejected"])

export function auditLabel(action: string): string {
  if (ACTIONS.has(action)) return tr(`audit.action.${action}` as MessageKey)
  const words = (action.split(".").slice(1).join(" ") || action).replace(/_/g, " ")
  return words.charAt(0).toUpperCase() + words.slice(1)
}

export function auditCategory(action: string): string {
  const key = action.split(".")[0] ?? ""
  const category = CATEGORIES[key]
  return category ? tr(`audit.category.${category}` as MessageKey) : key.replace(/_/g, " ")
}

export function isAuditAlert(action: string): boolean {
  return ALERTS.has(action)
}
