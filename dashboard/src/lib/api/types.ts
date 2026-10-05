// Types mirror the Laravel API resources (backend/app/Http/Resources). Money = integer minor units (cents).

export type VoucherStatus = "active" | "blocked" | "expired" | "refunded"
/** card: spent only with its NTAG 424 DNA card; digital: spent only with its QR (decision 26). */
export type VoucherKind = "card" | "digital"
export type TransactionType = "issue" | "redemption" | "reload" | "reversal" | "refund"
export type PaymentMethod = "cash" | "card_terminal" | "bank_transfer" | "complimentary"
export type RoleSlug = "platform_admin" | "owner" | "manager" | "waiter"

export type Permission =
  | "dashboard.view"
  | "vouchers.view"
  | "vouchers.sell"
  | "vouchers.sell_complimentary"
  | "vouchers.update"
  | "vouchers.redeem"
  | "vouchers.reload"
  | "vouchers.block"
  | "vouchers.unblock"
  | "vouchers.expire"
  | "vouchers.reinstate"
  | "vouchers.export"
  | "vouchers.refund"
  | "vouchers.cancel_sale"
  | "vouchers.reissue"
  | "cards.view"
  | "cards.receive"
  | "cards.bind"
  | "cards.manage"
  | "cards.replace_lost"
  | "transactions.view"
  | "transactions.reverse"
  | "transactions.reverse_own_reload"
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
  | "platform.cards.personalize"
  | "platform.cards.manage"

export type VoucherTemplate = "classic" | "minimal" | "bold" | "elegant"
export type VoucherFormat = "a4" | "a5" | "a6"

export interface VoucherDesignSettings {
  template: VoucherTemplate
  format: VoucherFormat
  accent_color: string
  headline: string | null
  message: string | null
}

export interface RestaurantSettings {
  /** null: vouchers do not expire (the default). */
  validity_months: number | null
  min_voucher_value: number
  max_voucher_balance: number
  max_debit_per_transaction: number
  max_debit_per_voucher_per_day: number
  max_redemptions_per_voucher_per_hour: number
  allow_reload: boolean
  allow_partial_redemption: boolean
  send_customer_emails: boolean
  public_balance: boolean
  brand_color: string
  receipt_footer: string | null
  voucher_design: VoucherDesignSettings
  /** Versioned API path of the logo (fetch it with the session: it needs the device header), null without a logo. */
  logo_url: string | null
  platform_limits: {
    max_voucher_balance: number
    max_debit_per_transaction: number
    max_debit_per_voucher_per_day: number
    min_validity_months: number
  }
}

export interface SessionRestaurant {
  id: string
  name: string
  slug: string
  currency: string
  timezone: string
  locale: string
  status: "active" | "suspended"
  /** The platform's own test restaurant (decision 2026-10-05). */
  is_test: boolean
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
  vouchers_count?: number
  vouchers_balance?: number
  created_at: string
}

export interface Payment {
  id: string
  method: PaymentMethod
  method_label: string
  /** in: received for a sale or reload; out: paid back with a refund. */
  direction: "in" | "out"
  amount: number
  currency: string
  reference: string | null
  reason: string | null
  created_at: string
}

export interface Medium {
  id: string
  type: "printable_qr" | "nfc_card"
  role: "spend"
  status: "active" | "revoked"
  /** The inventory number of a physical card (`nfc_card`). */
  card_number: string | null
  created_at: string
  revoked_at: string | null
}

export type CardState =
  | "manufactured"
  | "personalized"
  | "qa_passed"
  | "qa_failed"
  | "in_inventory"
  | "assigned"
  | "shipped"
  | "delivered"
  | "available"
  | "bound"
  | "active"
  | "suspended"
  | "replaced"
  | "revoked"
  | "lost"
  | "destroyed"

export interface Card {
  card_number: string
  state: CardState
  state_changed_at: string
  batch_code: string | null
  voucher: { id: string; voucher_number: string; status: VoucherStatus; balance: number; currency: string } | null
  successor: string | null
  history?: { from_state: CardState | null; to_state: CardState; reason: string; at: string | null }[]
}

export type CardBatchStatus = "in_production" | "accepted" | "rejected" | "shipped" | "on_hold" | "in_service" | "depleted" | "compromised" | "lost" | "closed"

export interface CardBatchCounts {
  in_production: number
  qa_failed: number
  central_stock: number
  in_transit: number
  available: number
  activated: number
  replaced: number
  revoked: number
  lost: number
  destroyed: number
  registered: number
}

export interface CardBatch {
  id: string
  batch_code: string
  status: CardBatchStatus
  quantity_ordered: number
  counts: CardBatchCounts
  card_design_ref: string | null
  ordered_at: string | null
  shipped_at: string | null
  delivered_at: string | null
  received_at: string | null
  tracking_ref: string | null
  /** Platform view only. */
  restaurant?: { id: string; name: string }
  key_set?: string
  manufacturer?: string
  accepted_at?: string | null
  /** The platform admin who released the batch (user id). */
  released_by?: string | null
  qa_report?: Record<string, unknown> | null
}

export type CardOrderStatus = "requested" | "accepted" | "declined"

/** A restaurant's request for new cards; the platform accepts it (a batch is ordered) or declines it. */
export interface CardOrder {
  id: string
  quantity: number
  note: string | null
  status: CardOrderStatus
  requested_by: string | null
  created_at: string
  decided_at: string | null
  decline_reason: string | null
  batch_code: string | null
  /** Platform view only. */
  restaurant?: { id: string; name: string }
}

export interface SecurityAlert {
  id: string
  rule: string
  severity: "warning" | "high" | "critical"
  restaurant_id: string | null
  subject: string | null
  occurrences: number
  first_event_seq: number
  last_event_seq: number
  first_seen_at: string
  last_seen_at: string
  status: "open" | "acknowledged"
  acknowledged_at: string | null
  note: string | null
}

export interface Voucher {
  id: string
  kind: VoucherKind
  /** Internal number: staff and support only, never printed, never a credential. */
  voucher_number: string
  voucher_number_formatted: string
  status: VoucherStatus
  /** The owner gave value without payment at least once (decision 2026-10-05): a regular's loyalty voucher. */
  loyalty: boolean
  currency: string
  initial_value: number
  balance: number
  total_loaded: number
  total_redeemed: number
  expires_at: string | null
  is_expired: boolean
  blocked_at: string | null
  blocked_reason: string | null
  expired_at: string | null
  recipient_name: string | null
  /** The buyer's message for the recipient, printed on the voucher. */
  gift_message: string | null
  notes: string | null
  customer?: Customer | null
  issued_by?: { id: string; name: string } | null
  media?: Medium[]
  payments?: Payment[]
  /** Detail view, for those who may refund: what a refund would pay back now. */
  refundable?: number
  last_used_at: string | null
  created_at: string
  updated_at: string
}

/** What the till sees after a voucher was presented. No customer data. */
export interface PresentedVoucher {
  id: string
  kind: VoucherKind
  restaurant_name: string
  voucher_number: string
  status: VoucherStatus
  currency: string
  balance: number
  expires_at: string | null
  is_expired: boolean
  blocked_reason: string | null
  allow_partial_redemption: boolean
  max_debit_per_transaction: number
  actions: { redeem: boolean }
}

/** Single-use, 60-second proof that the voucher's medium was presented here, now. */
export interface Presentment {
  id: string
  purpose: "spend"
  method: "printable_qr" | "live_auth"
  level: string
  expires_at: string
  voucher: PresentedVoucher
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
  payment?: Payment | null
  voucher?: { id: string; kind: VoucherKind; voucher_number: string; status: VoucherStatus }
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
  payment_method: PaymentMethod | null
  reversed: boolean
  /** The server's verdict for the signed-in account: undoable now, by this person. */
  reversible: boolean
  user: string | null
  device: string | null
  created_at: string
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
  /** Only in platform administration responses. */
  invitation?: InvitationSummary | null
}

/**
 * State of an account's invitation (platform admin). `delivery` is the outcome of the latest e-mail:
 * "logged" means the platform only writes e-mails to its log (MAIL_MAILER=log) — nobody received it.
 */
export interface InvitationSummary {
  status: "accepted" | "pending" | "expired" | "not_sent"
  expires_at: string | null
  last_sent_at: string | null
  delivery: "queued" | "sent" | "logged" | "failed" | null
  error: string | null
}

export interface RestaurantOwner {
  id: string
  name: string
  email: string
  status: "active" | "inactive"
  last_login_at: string | null
  invitation: InvitationSummary | null
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
  /** The platform's own test restaurant: its cards can be put back into stock (decision 2026-10-05). */
  is_test: boolean
  suspended_at: string | null
  suspension_reason: string | null
  settings?: RestaurantSettings
  users_count?: number
  vouchers_count?: number
  outstanding_balance?: number
  /** Set when the restaurant is archived (hidden, users locked out, data kept). */
  archived_at: string | null
  owner?: RestaurantOwner | null
  created_at: string
}

export interface MailStatus {
  mailer: string
  delivers: boolean
  from_address: string | null
  from_name: string | null
  /** SMTP server (no credentials); null for other mailers. */
  host: string | null
  port: number | null
  problem: string | null
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
  kind?: "device" | "integration"
  restaurant?: { id: string; name: string } | null
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
  vouchers_sold: number
  vouchers_sold_this_month: number
  vouchers_active: number
  vouchers_empty: number
  vouchers_blocked: number
  vouchers_expired: number
  /** Liability towards guests: every voucher balance, expired and blocked ones included. */
  outstanding_balance: number
  outstanding_vouchers: number
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
  status_distribution: { status: VoucherStatus; count: number; balance: number }[]
}

export interface PlatformStats {
  restaurants_total: number
  restaurants_active: number
  restaurants_archived: number
  vouchers_total: number
  vouchers_active: number
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

export interface Paginated<T> {
  data: T[]
  links: { first: string | null; last: string | null; prev: string | null; next: string | null }
  meta: { current_page: number; from: number | null; last_page: number; per_page: number; to: number | null; total: number }
}
