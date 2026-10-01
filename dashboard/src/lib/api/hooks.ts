"use client"

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { api, apiRaw, newIdempotencyKey } from "@/lib/api/client"
import type {
  ApiToken,
  Card,
  CardBatch,
  CardBatchStatus,
  CardState,
  SecurityAlert,
  AuditLog,
  Customer,
  DashboardCharts,
  DashboardStats,
  Device,
  HistoryEntry,
  MailStatus,
  NotificationTemplate,
  Paginated,
  Payment,
  PaymentMethod,
  PlatformStats,
  PresentedVoucher,
  Presentment,
  Restaurant,
  RestaurantSettings,
  Role,
  StaffUser,
  SystemSetting,
  Transaction,
  TransactionType,
  Voucher,
  VoucherKind,
  VoucherStatus,
  VoucherFormat,
  VoucherTemplate,
} from "@/lib/api/types"

export const keys = {
  dashboard: ["dashboard"] as const,
  vouchers: ["vouchers"] as const,
  voucher: (id: string) => ["vouchers", id] as const,
  voucherHistory: (id: string) => ["vouchers", id, "history"] as const,
  transactions: ["transactions"] as const,
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
  securityAlerts: ["admin", "security-alerts"] as const,
}

// ---------------------------------------------------------------- dashboard

export function useDashboardStats() {
  return useQuery({
    queryKey: [...keys.dashboard, "stats"],
    queryFn: async () => (await api<{ data: DashboardStats }>("/dashboard/stats")).data,
    refetchInterval: 60_000,
  })
}

export function useDashboardCharts(days: 7 | 30 | 90) {
  return useQuery({
    queryKey: [...keys.dashboard, "charts", days],
    queryFn: async () => (await api<{ data: DashboardCharts }>("/dashboard/charts", { query: { days } })).data,
    placeholderData: keepPreviousData,
  })
}

export function useRecentActivity(limit = 8) {
  return useQuery({
    queryKey: [...keys.dashboard, "activity", limit],
    queryFn: async () => (await api<{ data: Transaction[] }>("/dashboard/activity", { query: { limit } })).data,
    refetchInterval: 30_000,
  })
}

// ---------------------------------------------------------------- vouchers

export interface VoucherFilters {
  search?: string
  status?: VoucherStatus[]
  kind?: VoucherKind
  sort?: string
  page?: number
  per_page?: number
  customer_id?: string
  expires_to?: string
  min_balance?: number
}

export function useVouchers(filters: VoucherFilters) {
  return useQuery({
    queryKey: [...keys.vouchers, "list", filters],
    queryFn: () => api<Paginated<Voucher>>("/vouchers", { query: { ...filters } }),
    placeholderData: keepPreviousData,
  })
}

export function useVoucher(id: string) {
  return useQuery({
    queryKey: keys.voucher(id),
    queryFn: async () => (await api<{ data: Voucher }>(`/vouchers/${id}`)).data,
  })
}

export function useVoucherHistory(id: string, enabled = true) {
  return useQuery({
    queryKey: keys.voucherHistory(id),
    queryFn: async () => (await api<{ data: HistoryEntry[] }>(`/vouchers/${id}/history`)).data,
    enabled,
  })
}

/** How the money was received (decision 25). The amount is always the amount sold or reloaded. */
export interface PaymentInput {
  method: PaymentMethod
  /** Terminal receipt number or bank reference: required for card_terminal and bank_transfer. */
  reference?: string | null
  /** Required for complimentary vouchers (owner only). */
  reason?: string | null
}

export interface SellVoucherInput {
  value: number
  form: "printable"
  payment: PaymentInput
  customer_id?: string | null
  customer?: { first_name?: string; last_name?: string; email?: string; phone?: string; marketing_consent?: boolean } | null
  recipient_name?: string | null
  notes?: string | null
}

export interface SaleResult {
  data: Voucher
  transaction: Transaction
  payment: Payment
  /** The printable QR, shown exactly once. Null on a retried sale that may no longer show it. */
  printable: { payload: string; qr_svg: string } | null
  replayed: boolean
}

export function useSellVoucher() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ input, idempotencyKey }: { input: SellVoucherInput; idempotencyKey: string }) =>
      api<SaleResult>("/vouchers", { method: "POST", body: input, idempotencyKey }),
    onSuccess: () => invalidateVoucherData(qc),
  })
}

export function useUpdateVoucher(id: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: { customer_id?: string | null; recipient_name?: string | null; notes?: string | null }) =>
      api<{ data: Voucher }>(`/vouchers/${id}`, { method: "PATCH", body: input }),
    onSuccess: () => invalidateVoucherData(qc, id),
  })
}

export type VoucherAction = "block" | "unblock" | "expire"

export function useVoucherAction(id: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ action, reason }: { action: VoucherAction; reason?: string }) =>
      api<{ data: Voucher }>(`/vouchers/${id}/${action}`, { method: "POST", body: reason !== undefined ? { reason } : {} }),
    onSuccess: () => invalidateVoucherData(qc, id),
  })
}

export function useReinstateVoucher(id: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: { reason: string; expires_on?: string | null }) => api<{ data: Voucher }>(`/vouchers/${id}/reinstate`, { method: "POST", body: input }),
    onSuccess: () => invalidateVoucherData(qc, id),
  })
}

export interface MoneyResult {
  data: { voucher: Voucher | PresentedVoucher; transaction: Transaction }
  replayed: boolean
}

export function useReloadVoucher() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({
      voucherId,
      input,
      idempotencyKey,
    }: {
      voucherId: string
      input: { amount: number; payment: PaymentInput; note?: string | null }
      idempotencyKey: string
    }) => api<MoneyResult>(`/vouchers/${voucherId}/reloads`, { method: "POST", body: input, idempotencyKey }),
    onSuccess: (_data, vars) => invalidateVoucherData(qc, vars.voucherId),
  })
}

/** Pays the remaining balance back (never more than was paid) and closes the voucher: owners. */
export function useRefundVoucher() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({
      voucherId,
      input,
      idempotencyKey,
    }: {
      voucherId: string
      input: { payment: { method: "cash" | "card_terminal" | "bank_transfer"; reference?: string | null }; reason: string }
      idempotencyKey: string
    }) => api<MoneyResult>(`/vouchers/${voucherId}/refund`, { method: "POST", body: input, idempotencyKey }),
    onSuccess: (_data, vars) => invalidateVoucherData(qc, vars.voucherId),
  })
}

/**
 * Cancels an unused sale of today (booked by mistake). A second attempt after a lost answer is safe: the voucher is
 * closed by the first one, so no second payout can happen.
 */
export function useCancelSale() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ voucherId, reason, reference }: { voucherId: string; reason: string; reference?: string | null }) =>
      api<MoneyResult>(`/vouchers/${voucherId}/cancellation`, {
        method: "POST",
        body: { reason, reference: reference || null },
        idempotencyKey: newIdempotencyKey(),
      }),
    onSuccess: (_data, vars) => invalidateVoucherData(qc, vars.voucherId),
  })
}

/** A new printable QR for a lost or unprinted sheet (the previous QR stops). */
export function useReissueQr() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ voucherId, reason }: { voucherId: string; reason: string }) =>
      api<{ data: Voucher; printable: { payload: string; qr_svg: string } }>(`/vouchers/${voucherId}/printable`, { method: "POST", body: { reason } }),
    onSuccess: (_data, vars) => invalidateVoucherData(qc, vars.voucherId),
  })
}

/** The till: scanning a voucher's QR creates a single-use presentment for the redemption that follows. */
export function usePresent() {
  return useMutation({
    mutationFn: (credential: string) =>
      api<{ data: Presentment }>("/presentments", { method: "POST", body: { purpose: "spend", method: "printable_qr", credential } }),
  })
}

export function useRedeemVoucher() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({
      voucherId,
      input,
      idempotencyKey,
    }: {
      voucherId: string
      input: { amount: number; presentment_id: string; reference?: string | null }
      idempotencyKey: string
    }) => api<MoneyResult>(`/vouchers/${voucherId}/redemptions`, { method: "POST", body: input, idempotencyKey }),
    onSuccess: (_data, vars) => invalidateVoucherData(qc, vars.voucherId),
  })
}

function invalidateVoucherData(qc: ReturnType<typeof useQueryClient>, id?: string) {
  void qc.invalidateQueries({ queryKey: keys.vouchers })
  void qc.invalidateQueries({ queryKey: keys.dashboard })
  void qc.invalidateQueries({ queryKey: keys.transactions })
  void qc.invalidateQueries({ queryKey: keys.customers })
  if (id) void qc.invalidateQueries({ queryKey: keys.voucher(id) })
}

// ---------------------------------------------------------------- transactions

export interface TransactionFilters {
  type?: TransactionType[]
  search?: string
  from?: string
  to?: string
  voucher_id?: string
  page?: number
  per_page?: number
}

export function useTransactions(filters: TransactionFilters) {
  return useQuery({
    queryKey: [...keys.transactions, filters],
    queryFn: () => api<Paginated<Transaction>>("/transactions", { query: { ...filters } }),
    placeholderData: keepPreviousData,
  })
}

export interface CashUp {
  date: string
  currency: string
  methods: { method: PaymentMethod; received: number; paid_out: number; net: number; payments: number }[]
  staff: { user: { id: string; name: string } | null; method: PaymentMethod; received: number; paid_out: number }[]
  reversed_reloads: number
  complimentary: number
  total_received: number
  total_paid_out: number
  outstanding_end_of_day: number
}

/** The end-of-day cash-up of one local day. */
export function useCashUp(date: string) {
  return useQuery({
    queryKey: ["cash-up", date],
    queryFn: () => api<{ data: CashUp }>("/reports/cash-up", { query: { date } }),
    select: (r) => r.data,
  })
}

export function useReverseTransaction() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) =>
      api<{ data: Transaction }>(`/transactions/${id}/reverse`, { method: "POST", body: { reason } }),
    onSuccess: () => invalidateVoucherData(qc),
  })
}

// ---------------------------------------------------------------- customers

export function useCustomers(search: string, page = 1) {
  return useQuery({
    queryKey: [...keys.customers, search, page],
    queryFn: () => api<Paginated<Customer>>("/customers", { query: { search, page } }),
    placeholderData: keepPreviousData,
  })
}

export function useCustomer(id: string) {
  return useQuery({
    queryKey: keys.customer(id),
    queryFn: () => api<{ data: Customer; vouchers: Voucher[] }>(`/customers/${id}`),
  })
}

export type CustomerInput = Partial<Pick<Customer, "first_name" | "last_name" | "email" | "phone" | "notes" | "marketing_consent">>

export function useSaveCustomer(id?: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: CustomerInput) => api<{ data: Customer }>(id ? `/customers/${id}` : "/customers", { method: id ? "PATCH" : "POST", body: input }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.customers }),
  })
}

export function useAnonymizeCustomer(id: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: () => api<{ data: Customer }>(`/customers/${id}/anonymize`, { method: "POST" }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.customers }),
  })
}

// ---------------------------------------------------------------- team

export function useUsers(search = "") {
  return useQuery({
    queryKey: [...keys.users, search],
    queryFn: () => api<Paginated<StaffUser>>("/users", { query: { search, per_page: 100 } }),
  })
}

export function useRoles() {
  return useQuery({
    queryKey: keys.roles,
    queryFn: async () => (await api<{ data: Role[] }>("/roles")).data,
    staleTime: 10 * 60_000,
  })
}

export function useSaveUser(id?: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: { name?: string; email?: string; role?: string; locale?: string }) =>
      api<{ data: StaffUser }>(id ? `/users/${id}` : "/users", { method: id ? "PATCH" : "POST", body: input }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.users }),
  })
}

export function useUserAction() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, action }: { id: string; action: "deactivate" | "activate" | "password-reset" }) => api(`/users/${id}/${action}`, { method: "POST" }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.users }),
  })
}

// ---------------------------------------------------------------- devices

export function useDevices() {
  return useQuery({
    queryKey: keys.devices,
    queryFn: () => api<Paginated<Device>>("/devices", { query: { per_page: 100 } }),
  })
}

export function useDeviceAction() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, action, name }: { id: string; action: "revoke" | "restore" | "rename"; name?: string }) =>
      action === "rename" ? api(`/devices/${id}`, { method: "PATCH", body: { name } }) : api(`/devices/${id}/${action}`, { method: "POST" }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.devices }),
  })
}

// ---------------------------------------------------------------- settings

export function useRestaurantSettings() {
  return useQuery({
    queryKey: keys.settings,
    queryFn: async () => (await api<{ data: Restaurant }>("/settings")).data,
  })
}

export function useUpdateRestaurantProfile() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: Partial<Restaurant>) => api<{ data: Restaurant }>("/settings/restaurant", { method: "PUT", body: input }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: keys.settings })
      void qc.invalidateQueries({ queryKey: ["session"] })
    },
  })
}

/** The writable voucher rules and design (PUT /settings/vouchers; every field optional). */
export type VoucherSettingsInput = Partial<Omit<RestaurantSettings, "platform_limits" | "voucher_design" | "logo_url">> &
  Partial<{
    voucher_template: VoucherTemplate
    voucher_format: VoucherFormat
    accent_color: string
    voucher_headline: string | null
    voucher_message: string | null
  }>

export function useUpdateVoucherSettings() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: VoucherSettingsInput) => api<{ data: RestaurantSettings }>("/settings/vouchers", { method: "PUT", body: input }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: keys.settings })
      void qc.invalidateQueries({ queryKey: ["session"] })
    },
  })
}

/** Upload (a PNG or JPEG file) or remove (null) the restaurant's logo. */
export function useRestaurantLogo() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (file: File | null) => {
      if (file === null) return api<{ data: RestaurantSettings }>("/settings/logo", { method: "DELETE" })
      const body = new FormData()
      body.append("logo", file)
      return api<{ data: RestaurantSettings }>("/settings/logo", { method: "POST", body })
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: keys.settings })
      void qc.invalidateQueries({ queryKey: ["session"] })
    },
  })
}

/**
 * The logo as a data: URL (for screen and print). Fetched with the session's headers — an <img> pointing at the API
 * would lack the device header and end the session.
 */
export function useLogoImage(path: string | null | undefined) {
  return useQuery({
    queryKey: ["logo", path],
    enabled: !!path,
    staleTime: Infinity,
    queryFn: async () => {
      const response = await apiRaw((path ?? "").replace(/^\/api\/v1/, ""))
      const blob = await response.blob()
      return await new Promise<string>((resolve, reject) => {
        const reader = new FileReader()
        reader.onload = () => resolve(String(reader.result))
        reader.onerror = () => reject(reader.error)
        reader.readAsDataURL(blob)
      })
    },
  })
}

export function useNotificationTemplates() {
  return useQuery({
    queryKey: keys.templates,
    queryFn: async () => (await api<{ data: NotificationTemplate[] }>("/settings/notification-templates")).data,
  })
}

export function useSaveTemplate() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ key, ...input }: { key: string; locale: string; subject: string; body: string; is_active: boolean }) =>
      api(`/settings/notification-templates/${key}`, { method: "PUT", body: input }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.templates }),
  })
}

export function useApiTokens() {
  return useQuery({
    queryKey: keys.tokens,
    queryFn: () => api<Paginated<ApiToken>>("/api-tokens"),
  })
}

export function useCreateApiToken() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: { name: string; abilities: string[]; expires_at?: string | null }) =>
      api<{ data: ApiToken; plain_text_token: string }>("/api-tokens", { method: "POST", body: input }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.tokens }),
  })
}

export function useRevokeApiToken() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => api(`/api-tokens/${id}/revoke`, { method: "POST" }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.tokens }),
  })
}

export function useAuditLogs(filters: { action?: string; page?: number }) {
  return useQuery({
    queryKey: [...keys.audit, filters],
    queryFn: () => api<Paginated<AuditLog>>("/audit-logs", { query: filters }),
    placeholderData: keepPreviousData,
  })
}

// ---------------------------------------------------------------- platform admin

export function usePlatformStats() {
  return useQuery({
    queryKey: [...keys.admin, "stats"],
    queryFn: async () => (await api<{ data: PlatformStats }>("/admin/stats")).data,
  })
}

export type AdminRestaurantFilter = "all" | "active" | "suspended" | "archived"

export function useAdminRestaurants(search: string, page = 1, status: AdminRestaurantFilter = "all") {
  return useQuery({
    queryKey: [...keys.admin, "restaurants", "list", search, page, status],
    queryFn: () => api<Paginated<Restaurant>>("/admin/restaurants", { query: { search, page, status: status === "all" ? undefined : status } }),
    placeholderData: keepPreviousData,
  })
}

/** Every restaurant by name, archived ones included (for filters): all pages of the active and the archived list. */
export function useAllAdminRestaurants() {
  return useQuery({
    queryKey: [...keys.admin, "restaurants", "all-names"],
    queryFn: async () => {
      const all: { id: string; name: string; archived: boolean }[] = []
      for (const status of [undefined, "archived"] as const) {
        for (let page = 1; ; page++) {
          const res = await api<Paginated<Restaurant>>("/admin/restaurants", { query: { page, per_page: 100, status } })
          all.push(...res.data.map((r) => ({ id: r.id, name: r.name, archived: status === "archived" })))
          if (page >= res.meta.last_page) break
        }
      }
      return all.sort((a, b) => a.name.localeCompare(b.name))
    },
    staleTime: 60_000,
  })
}

/** Records that make a restaurant non-deletable (they must be kept; archive instead). */
export interface RestaurantBusinessData {
  vouchers: number
  transactions: number
  customers: number
}

export function useAdminRestaurant(id: string) {
  return useQuery({
    queryKey: [...keys.admin, "restaurants", id],
    queryFn: () => api<{ data: Restaurant; users: StaffUser[]; business_data: RestaurantBusinessData }>(`/admin/restaurants/${id}`),
    enabled: id !== "",
  })
}

export type UpdateRestaurantInput = Partial<
  Pick<
    Restaurant,
    | "name"
    | "legal_name"
    | "vat_number"
    | "email"
    | "phone"
    | "website"
    | "address_line1"
    | "address_line2"
    | "postal_code"
    | "city"
    | "country"
    | "currency"
    | "timezone"
    | "locale"
  >
>

export function useUpdateRestaurant() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: UpdateRestaurantInput }) =>
      api<{ data: Restaurant }>(`/admin/restaurants/${id}`, { method: "PATCH", body: input }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.admin }),
  })
}

export function useDeleteRestaurant() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, confirm }: { id: string; confirm: string }) =>
      api<{ message: string }>(`/admin/restaurants/${id}`, { method: "DELETE", body: { confirm } }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.admin }),
  })
}

/**
 * Sends an invitation again: the restaurant owner's (no userId) or another not yet active account's.
 * A mistyped name or e-mail address can be corrected in the same step.
 */
export function useResendInvitation() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ restaurantId, userId, name, email }: { restaurantId: string; userId?: string; name?: string; email?: string }) =>
      api<{ message: string; data: StaffUser }>(
        userId ? `/admin/restaurants/${restaurantId}/users/${userId}/invitation` : `/admin/restaurants/${restaurantId}/invitation`,
        { method: "POST", body: { name: name || undefined, email: email || undefined } },
      ),
    // Also after a failed delivery: the attempt (and any correction) is saved and shown.
    onSettled: () => void qc.invalidateQueries({ queryKey: keys.admin }),
  })
}

/** The platform invites a new owner for a restaurant (handover, or the only owner lost access). */
export function useInviteOwner() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ restaurantId, name, email }: { restaurantId: string; name: string; email: string }) =>
      api<{ data: StaffUser }>(`/admin/restaurants/${restaurantId}/owners`, { method: "POST", body: { name, email } }),
    onSettled: () => void qc.invalidateQueries({ queryKey: keys.admin }),
  })
}

export function useMailStatus() {
  return useQuery({
    queryKey: [...keys.admin, "mail"],
    queryFn: async () => (await api<{ data: MailStatus }>("/admin/mail")).data,
    staleTime: 60_000,
  })
}

/** Sends a test e-mail to `to`, or to the signed-in platform admin when omitted. */
export function useSendTestMail() {
  return useMutation({
    mutationFn: (to?: string) =>
      api<{ message: string; data: { recipient: string; mailer: string; guard: string } }>("/admin/mail/test", {
        method: "POST",
        body: { to: to || undefined },
      }),
  })
}

export interface CreateRestaurantInput {
  name: string
  email?: string
  phone?: string
  address_line1?: string
  postal_code?: string
  city?: string
  country?: string
  currency?: string
  timezone?: string
  locale?: string
  owner: { name: string; email: string }
}

export function useCreateRestaurant() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: CreateRestaurantInput) => api<{ data: Restaurant; owner: StaffUser }>("/admin/restaurants", { method: "POST", body: input }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.admin }),
  })
}

export function useRestaurantStatus() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, action, reason }: { id: string; action: "suspend" | "reactivate" | "archive" | "restore"; reason?: string }) =>
      api(`/admin/restaurants/${id}/${action}`, { method: "POST", body: reason ? { reason } : {} }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.admin }),
  })
}

/** Incident response (audit S2): every restaurant's access tokens, revocable by the platform. */
export function useAdminApiTokens(restaurantId: string, activeOnly = true) {
  return useQuery({
    queryKey: [...keys.admin, "api-tokens", restaurantId, activeOnly],
    queryFn: () => api<Paginated<ApiToken>>("/admin/api-tokens", { query: { restaurant_id: restaurantId, active: activeOnly ? 1 : undefined, per_page: 100 } }),
    enabled: restaurantId !== "",
  })
}

export function useAdminRevokeApiToken() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => api<{ data: ApiToken }>(`/admin/api-tokens/${id}/revoke`, { method: "POST" }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: [...keys.admin, "api-tokens"] }),
  })
}

/** `restaurant`: a restaurant id, or `"platform"` for entries that belong to no restaurant. */
export function usePlatformAudit(page = 1, filters: { restaurant?: string; action?: string } = {}) {
  return useQuery({
    queryKey: [...keys.admin, "audit", page, filters.restaurant ?? "", filters.action ?? ""],
    queryFn: () =>
      api<Paginated<AuditLog>>("/admin/audit-logs", {
        query: { page, restaurant: filters.restaurant || undefined, action: filters.action || undefined },
      }),
    placeholderData: keepPreviousData,
  })
}

export function useSystemSettings() {
  return useQuery({
    queryKey: [...keys.admin, "system-settings"],
    queryFn: async () => (await api<{ data: SystemSetting[] }>("/admin/system-settings")).data,
  })
}

export function useUpdateSystemSettings() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (settings: { key: string; value: unknown }[]) => api("/admin/system-settings", { method: "PUT", body: { settings } }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: [...keys.admin, "system-settings"] }),
  })
}

// ---------------------------------------------------------------- cards

export function useCards(page: number, filters: { state?: CardState[]; search?: string }) {
  return useQuery({
    queryKey: [...keys.cards, page, filters],
    queryFn: () => api<Paginated<Card>>("/cards", { query: { page, per_page: 50, state: filters.state, search: filters.search || undefined } }),
    placeholderData: keepPreviousData,
  })
}

export function useCard(number: string | null) {
  return useQuery({
    queryKey: [...keys.cards, "one", number],
    queryFn: async () => (await api<{ data: Card }>(`/cards/${encodeURIComponent(number ?? "")}`)).data,
    enabled: number !== null,
  })
}

export function useCardAction() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ number, action, reason }: { number: string; action: "suspend" | "resume" | "revoke"; reason: string }) =>
      api<{ data: Card }>(`/cards/${encodeURIComponent(number)}/${action}`, { method: "POST", body: { reason } }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: keys.cards })
      void qc.invalidateQueries({ queryKey: keys.vouchers })
    },
  })
}

export function useCardBatches() {
  return useQuery({
    queryKey: keys.cardBatches,
    queryFn: async () => (await api<{ data: CardBatch[] }>("/card-batches")).data,
  })
}

// ---------------------------------------------------------------- card batches (platform)

export function useAdminCardBatches(page: number, status?: CardBatchStatus) {
  return useQuery({
    queryKey: [...keys.adminCardBatches, page, status],
    queryFn: () => api<Paginated<CardBatch>>("/admin/card-batches", { query: { page, status } }),
    placeholderData: keepPreviousData,
  })
}

export function useOrderCardBatch() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: { restaurant_id: string; manufacturer: string; quantity: number; card_design_ref?: string }) =>
      api<{ data: CardBatch }>("/admin/card-batches", { method: "POST", body: input }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.adminCardBatches }),
  })
}

export function useCardBatchAction() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({
      id,
      ...input
    }: { id: string } & (
      { kind: "status"; status: CardBatchStatus; reason: string; tracking_ref?: string } | { kind: "approval" } | { kind: "hold-resolution"; missing: string[] }
    )) =>
      input.kind === "status"
        ? api<{ data: CardBatch }>(`/admin/card-batches/${id}/status`, {
            method: "POST",
            body: { status: input.status, reason: input.reason, tracking_ref: input.tracking_ref },
          })
        : input.kind === "approval"
          ? api<{ data: CardBatch }>(`/admin/card-batches/${id}/approval`, { method: "POST" })
          : api<{ data: CardBatch }>(`/admin/card-batches/${id}/hold-resolution`, { method: "POST", body: { missing: input.missing } }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.adminCardBatches }),
  })
}

// ---------------------------------------------------------------- security alerts (platform)

export function useSecurityAlerts(page: number, status?: "open" | "acknowledged") {
  return useQuery({
    queryKey: [...keys.securityAlerts, page, status],
    queryFn: () => api<Paginated<SecurityAlert>>("/admin/security-alerts", { query: { page, status } }),
    placeholderData: keepPreviousData,
    refetchInterval: 60_000,
  })
}

export function useAcknowledgeAlert() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, note }: { id: string; note: string }) =>
      api<{ data: SecurityAlert }>(`/admin/security-alerts/${id}/acknowledge`, { method: "POST", body: { note } }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: keys.securityAlerts }),
  })
}
