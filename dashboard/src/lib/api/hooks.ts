"use client"

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { api } from "@/lib/api/client"
import type {
  ApiToken,
  AuditLog,
  CardStatus,
  Customer,
  DashboardCharts,
  DashboardStats,
  Device,
  GiftCard,
  HistoryEntry,
  MailStatus,
  NfcPayload,
  NfcTagType,
  NfcWriteAttempt,
  NfcWriteMethod,
  NotificationTemplate,
  Paginated,
  PlatformStats,
  PublicCard,
  Restaurant,
  RestaurantSettings,
  Role,
  ScanMethod,
  ScannedCard,
  StaffUser,
  SystemSetting,
  Transaction,
  TransactionType,
} from "@/lib/api/types"

export const keys = {
  dashboard: ["dashboard"] as const,
  cards: ["cards"] as const,
  card: (id: string) => ["cards", id] as const,
  cardHistory: (id: string) => ["cards", id, "history"] as const,
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

// ---------------------------------------------------------------- cards

export interface CardFilters {
  search?: string
  status?: CardStatus[]
  sort?: string
  page?: number
  per_page?: number
  customer_id?: string
  expires_to?: string
  min_balance?: number
  nfc_status?: "unprogrammed" | "unverified" | "verified"
  card_number_after?: string
}

export function useCards(filters: CardFilters) {
  return useQuery({
    queryKey: [...keys.cards, "list", filters],
    queryFn: () => api<Paginated<GiftCard>>("/cards", { query: { ...filters } }),
    placeholderData: keepPreviousData,
  })
}

export function useCard(id: string) {
  return useQuery({
    queryKey: keys.card(id),
    queryFn: async () => (await api<{ data: GiftCard }>(`/cards/${id}`)).data,
  })
}

export function useCardHistory(id: string, enabled = true) {
  return useQuery({
    queryKey: keys.cardHistory(id),
    queryFn: async () => (await api<{ data: HistoryEntry[] }>(`/cards/${id}/history`)).data,
    enabled,
  })
}

export interface CreateCardInput {
  value: number
  expires_at?: string | null
  customer_id?: string | null
  customer?: { first_name?: string; last_name?: string; email?: string; phone?: string; marketing_consent?: boolean } | null
  recipient_name?: string | null
  notes?: string | null
  activate?: boolean
  nfc_tag_type?: NfcTagType | null
}

export function useCreateCard() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ input, idempotencyKey }: { input: CreateCardInput; idempotencyKey: string }) =>
      api<{ data: GiftCard; transaction: Transaction; nfc: NfcPayload; replayed: boolean }>("/cards", {
        method: "POST",
        body: input,
        idempotencyKey,
      }),
    onSuccess: () => invalidateCardData(qc),
  })
}

export function useUpdateCard(id: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: { customer_id?: string | null; recipient_name?: string | null; notes?: string | null; expires_at?: string | null }) =>
      api<{ data: GiftCard }>(`/cards/${id}`, { method: "PATCH", body: input }),
    onSuccess: () => invalidateCardData(qc, id),
  })
}

export type CardAction = "activate" | "block" | "unblock" | "expire"

export function useCardAction(id: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ action, reason }: { action: CardAction; reason?: string }) =>
      api<{ data: GiftCard }>(`/cards/${id}/${action}`, { method: "POST", body: reason !== undefined ? { reason } : {} }),
    onSuccess: () => invalidateCardData(qc, id),
  })
}

export interface MoneyInput {
  amount: number
  reference?: string | null
  note?: string | null
}

export interface MoneyResult {
  data: { card: GiftCard | ScannedCard; transaction: Transaction }
  replayed: boolean
}

export function useMoneyOperation(kind: "redeem" | "reload") {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ cardId, input, idempotencyKey }: { cardId: string; input: MoneyInput; idempotencyKey: string }) =>
      api<MoneyResult>(`/cards/${cardId}/${kind}`, { method: "POST", body: input, idempotencyKey }),
    onSuccess: (_data, vars) => invalidateCardData(qc, vars.cardId),
  })
}

export function useTransferBalance(id: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ input, idempotencyKey }: { input: { target_card_number: string; amount?: number | null; note?: string | null }; idempotencyKey: string }) =>
      api<{ data: { source: GiftCard; target: GiftCard } }>(`/cards/${id}/transfer`, { method: "POST", body: input, idempotencyKey }),
    onSuccess: () => invalidateCardData(qc),
  })
}

export function useReplaceCard(id: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: { reason: string; nfc_tag_type?: NfcTagType | null }) =>
      api<{ data: GiftCard; nfc: NfcPayload }>(`/cards/${id}/replace`, { method: "POST", body: input }),
    onSuccess: () => invalidateCardData(qc),
  })
}

export function useNfcPayload(id: string, enabled: boolean) {
  return useQuery({
    queryKey: [...keys.card(id), "nfc"],
    queryFn: async () => (await api<{ data: NfcPayload }>(`/cards/${id}/nfc`)).data,
    enabled,
  })
}

export function useBindNfc(id: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: { method: Exclude<NfcWriteMethod, "web_nfc">; tag_type: NfcTagType; locked?: boolean }) =>
      api<{ data: GiftCard }>(`/cards/${id}/nfc`, { method: "POST", body: input }),
    onSuccess: () => invalidateCardData(qc, id),
  })
}

export function useNfcAttempts(id: string, enabled = true) {
  return useQuery({
    queryKey: [...keys.card(id), "nfc-attempts"],
    queryFn: async () => (await api<{ data: NfcWriteAttempt[] }>(`/cards/${id}/nfc/attempts`)).data,
    enabled,
  })
}

export function useScanCard() {
  return useMutation({
    mutationFn: (input: { method: ScanMethod; token?: string; card_number?: string; nfc_uid?: string | null }) =>
      api<{ data: ScannedCard }>("/scan", { method: "POST", body: input }),
  })
}

export function usePublicCard(token: string, enabled: boolean) {
  return useQuery({
    queryKey: ["public-card", token],
    queryFn: async () => (await api<{ data: PublicCard }>(`/public/cards/${token}`)).data,
    enabled,
    retry: false,
  })
}

function invalidateCardData(qc: ReturnType<typeof useQueryClient>, id?: string) {
  void qc.invalidateQueries({ queryKey: keys.cards })
  void qc.invalidateQueries({ queryKey: keys.dashboard })
  void qc.invalidateQueries({ queryKey: keys.transactions })
  void qc.invalidateQueries({ queryKey: keys.customers })
  if (id) void qc.invalidateQueries({ queryKey: keys.card(id) })
}

// ---------------------------------------------------------------- transactions

export interface TransactionFilters {
  type?: TransactionType[]
  search?: string
  from?: string
  to?: string
  gift_card_id?: string
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

export function useReverseTransaction() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) =>
      api<{ data: Transaction }>(`/transactions/${id}/reverse`, { method: "POST", body: { reason } }),
    onSuccess: () => invalidateCardData(qc),
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
    queryFn: () => api<{ data: Customer; gift_cards: GiftCard[] }>(`/customers/${id}`),
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

export function useUpdateCardSettings() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: Partial<RestaurantSettings>) => api<{ data: RestaurantSettings }>("/settings/cards", { method: "PUT", body: input }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: keys.settings })
      void qc.invalidateQueries({ queryKey: ["session"] })
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

/** Records that make a restaurant non-deletable (they must be kept; archive instead). */
export interface RestaurantBusinessData {
  gift_cards: number
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
    | "plan"
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

export function usePlatformAudit(page = 1, filters: { restaurantId?: string; action?: string } = {}) {
  return useQuery({
    queryKey: [...keys.admin, "audit", page, filters.restaurantId ?? "", filters.action ?? ""],
    queryFn: () =>
      api<Paginated<AuditLog>>("/admin/audit-logs", {
        query: { page, restaurant_id: filters.restaurantId || undefined, action: filters.action || undefined },
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
