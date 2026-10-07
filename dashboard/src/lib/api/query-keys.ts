/** React Query keys. A key that starts with another one is invalidated with it (["vouchers", id] with ["vouchers"]). */
export const keys = {
  session: ["session"] as const,
  dashboard: ["dashboard"] as const,
  vouchers: ["vouchers"] as const,
  voucher: (id: string) => ["vouchers", id] as const,
  voucherHistory: (id: string) => ["vouchers", id, "history"] as const,
  transactions: ["transactions"] as const,
  cashUp: ["cash-up"] as const,
  customers: ["customers"] as const,
  customer: (id: string) => ["customers", id] as const,
  users: ["users"] as const,
  roles: ["roles"] as const,
  devices: ["devices"] as const,
  settings: ["settings"] as const,
  templates: ["settings", "templates"] as const,
  tokens: ["api-tokens"] as const,
  audit: ["audit"] as const,
  admin: ["admin"] as const,
  cards: ["cards"] as const,
  cardBatches: ["card-batches"] as const,
  adminCardBatches: ["admin", "card-batches"] as const,
  cardOrders: ["card-orders"] as const,
  onlineShop: ["online-shop"] as const,
  onlineOrders: ["online-orders"] as const,
  partnerConnections: ["partner-connections"] as const,
  adminCardOrders: ["admin", "card-orders"] as const,
  securityAlerts: ["admin", "security-alerts"] as const,
}

/**
 * Everything a sale, reload, redemption, refund, cancellation, reversal or voucher change can alter: lists, the
 * voucher and its history, the dashboard, the transactions, the day's cash-up, customers (their balances), cards (the
 * balance on a card) and the audit log.
 */
export const VOUCHER_DATA_KEYS: readonly (readonly string[])[] = [
  keys.vouchers,
  keys.dashboard,
  keys.transactions,
  keys.cashUp,
  keys.customers,
  keys.cards,
  keys.audit,
]
