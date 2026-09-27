// Types mirror the Laravel API resources (backend/app/Http/Resources). Money = integer minor units (cents).

export type CardStatus = "inactive" | "active" | "redeemed" | "blocked" | "expired" | "replaced"
export type TransactionType = "issue" | "redemption" | "reload" | "transfer_out" | "transfer_in" | "expiration" | "reversal" | "adjustment"
export type NfcTagType = "ntag213" | "ntag215" | "ntag216" | "ntag424_dna" | "qr_only"
export type RoleSlug = "platform_admin" | "owner" | "manager" | "waiter"
export type ScanMethod = "nfc" | "qr" | "link" | "manual" | "api"

export type Permission =
  | "dashboard.view"
  | "cards.view"
  | "cards.scan"
  | "cards.create"
  | "cards.update"
  | "cards.activate"
  | "cards.redeem"
  | "cards.reload"
  | "cards.block"
  | "cards.unblock"
  | "cards.expire"
  | "cards.transfer"
  | "cards.replace"
  | "cards.write_nfc"
  | "cards.export"
  | "transactions.view"
  | "transactions.reverse"
  | "transactions.export"
  | "customers.view"
  | "customers.manage"
  | "users.view"
  | "users.manage"
  | "devices.view"
  | "devices.manage"
  | "settings.manage"
  | "api_tokens.manage"
  | "audit.view"
  | "platform.restaurants.manage"
  | "platform.settings.manage"
  | "platform.audit.view"

export interface RestaurantSettings {
  card_number_prefix: string
  default_validity_months: number
  min_card_value: number
  max_card_value: number
  max_card_balance: number
  max_single_redemption: number | null
  max_redemptions_per_card_per_hour: number
  allow_reload: boolean
  allow_partial_redemption: boolean
  public_balance_check: boolean
  enforce_nfc_uid_binding: boolean
  lock_nfc_tags_after_write: boolean
  send_customer_emails: boolean
  brand_color: string
  receipt_footer: string | null
}

export interface SessionRestaurant {
  id: string
  name: string
  slug: string
  currency: string
  timezone: string
  locale: string
  status: "active" | "suspended"
  settings: RestaurantSettings
}

export interface SessionUser {
  id: string
  name: string
  email: string
  locale: string
  role: { slug: RoleSlug; name: string }
  is_platform_admin: boolean
  permissions: Permission[]
  restaurant: SessionRestaurant | null
  platform: { support_email: string | null; notice: string | null }
}

export interface Customer {
  id: string
  first_name: string | null
  last_name: string | null
  full_name: string
  email: string | null
  phone: string | null
  notes: string | null
  marketing_consent: boolean
  anonymized: boolean
  gift_cards_count?: number
  gift_cards_balance?: number
  created_at: string
}

export interface GiftCard {
  id: string
  card_number: string
  card_number_formatted: string
  status: CardStatus
  currency: string
  initial_value: number
  balance: number
  total_loaded: number
  total_redeemed: number
  expires_at: string | null
  is_expired: boolean
  activated_at: string | null
  redeemed_at: string | null
  blocked_at: string | null
  blocked_reason: string | null
  expired_at: string | null
  recipient_name: string | null
  notes: string | null
  customer?: Customer | null
  issued_by?: { id: string; name: string } | null
  replaced_by?: { id: string; card_number: string } | null
  replaces?: { id: string; card_number: string } | null
  nfc: { tag_type: NfcTagType | null; uid: string | null; written_at: string | null; verified_at: string | null; locked: boolean }
  card_url?: string
  last_used_at: string | null
  created_at: string
  updated_at: string
}

/** Minimal card view returned to the waiter app. */
export interface ScannedCard {
  id: string
  restaurant_name: string
  card_number: string
  status: CardStatus
  currency: string
  balance: number
  expires_at: string | null
  is_expired: boolean
  blocked_reason: string | null
  allow_partial_redemption: boolean
  actions: { redeem: boolean; reload: boolean; history: boolean; block: boolean; activate: boolean }
}

export interface Transaction {
  id: string
  type: TransactionType
  type_label: string
  amount: number
  balance_before: number
  balance_after: number
  currency: string
  reference: string | null
  note: string | null
  reversed: boolean
  reversed_at: string | null
  reversible: boolean
  related_transaction_id: string | null
  gift_card?: { id: string; card_number: string; status: CardStatus }
  user?: { id: string; name: string } | null
  device?: { id: string; name: string } | null
  created_at: string
}

export interface HistoryEntry {
  id: string
  kind: "transaction" | "event"
  type: string
  label: string
  amount: number | null
  balance_after: number | null
  reference: string | null
  note: string | null
  reversed: boolean
  user: string | null
  device: string | null
  created_at: string
}

export type NfcWriteMethod = "web_nfc" | "manual" | "provisioned" | "printed"

export interface NfcWriteAttempt {
  id: string
  attempt_id: string
  gift_card_id: string
  method: NfcWriteMethod
  stage: "read" | "check" | "detect" | "write" | "verify" | "lock" | "bind"
  result: "in_progress" | "succeeded" | "already_programmed" | "refused" | "failed" | "cancelled"
  error_code: string | null
  error_message: string | null
  uid: string | null
  tag_type: NfcTagType | null
  locked: boolean
  user: { id: string; name: string } | null
  created_at: string
  completed_at: string | null
}

export interface NfcPayload {
  url: string
  tag_type_hint: NfcTagType
  ndef_template: string | null
  lock_after_write?: boolean
}

export interface StaffUser {
  id: string
  name: string
  email: string
  status: "active" | "inactive"
  locale: string
  role?: { slug: RoleSlug; name: string }
  restaurant_id: string | null
  last_login_at: string | null
  locked: boolean
  created_at: string
}

export interface Role {
  slug: RoleSlug
  name: string
  description: string | null
  permissions: Permission[]
  assignable: boolean
}

export interface Device {
  id: string
  name: string
  type: string
  platform: string | null
  status: "active" | "revoked"
  last_seen_at: string | null
  last_ip: string | null
  last_user?: { id: string; name: string } | null
  is_current: boolean
  revoked_at: string | null
  created_at: string
}

export interface Restaurant {
  id: string
  name: string
  slug: string
  legal_name: string | null
  vat_number: string | null
  email: string | null
  phone: string | null
  website: string | null
  address_line1: string | null
  address_line2: string | null
  postal_code: string | null
  city: string | null
  country: string
  currency: string
  timezone: string
  locale: string
  status: "active" | "suspended"
  plan: string
  suspended_at: string | null
  suspension_reason: string | null
  settings?: RestaurantSettings
  users_count?: number
  gift_cards_count?: number
  outstanding_balance?: number
  created_at: string
}

export interface AuditLog {
  id: string
  action: string
  auditable_type: string | null
  auditable_id: string | null
  old_values: Record<string, unknown> | null
  new_values: Record<string, unknown> | null
  metadata: Record<string, unknown> | null
  user?: { id: string; name: string } | null
  restaurant?: { id: string; name: string } | null
  ip_address: string | null
  request_id: string | null
  created_at: string
}

export interface ApiToken {
  id: string
  name: string
  abilities: string[]
  last_used_at: string | null
  expires_at: string | null
  revoked_at: string | null
  active: boolean
  owner?: { id: string; name: string }
  created_at: string
}

export interface NotificationTemplate {
  id: string
  key: string
  channel: string
  locale: string
  subject: string
  body: string
  is_active: boolean
  is_default: boolean
  placeholders: string[]
}

export interface DashboardStats {
  currency: string
  cards_sold: number
  cards_sold_this_month: number
  cards_active: number
  cards_inactive: number
  cards_redeemed: number
  cards_blocked: number
  cards_expired: number
  outstanding_balance: number
  outstanding_cards: number
  today_transactions: number
  today_redeemed: number
  monthly_revenue: number
  previous_month_revenue: number
  monthly_redeemed: number
  expiring_soon: number
}

export interface DashboardCharts {
  daily: { date: string; sold: number; redeemed: number; transactions: number }[]
  monthly: { month: string; revenue: number; redeemed: number }[]
  status_distribution: { status: CardStatus; count: number; balance: number }[]
}

export interface PlatformStats {
  restaurants_total: number
  restaurants_active: number
  cards_total: number
  cards_active: number
  transactions_this_month: number
  volume_sold_this_month: number
}

export interface SystemSetting {
  key: string
  value: unknown
  type: string
  description: string | null
  is_public: boolean
}

export interface PublicCard {
  restaurant_name: string
  brand_color?: string
  balance_visible: boolean
  card_number?: string
  status?: CardStatus
  balance?: number
  currency?: string
  expires_at?: string | null
  locale?: string
}

export interface Paginated<T> {
  data: T[]
  links: { first: string | null; last: string | null; prev: string | null; next: string | null }
  meta: { current_page: number; from: number | null; last_page: number; per_page: number; to: number | null; total: number }
}
