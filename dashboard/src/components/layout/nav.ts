import {
  ArrowLeftRight,
  Building2,
  CreditCard,
  Package,
  ShieldAlert,
  QrCode,
  Ticket,
  LayoutDashboard,
  ScrollText,
  Settings,
  ShieldCheck,
  Smartphone,
  SlidersHorizontal,
  Users,
  UserSquare2,
  Wallet,
  type LucideIcon,
} from "lucide-react"
import type { Permission } from "@/lib/api/types"
import type { MessageKey } from "@/lib/i18n/catalog"

export interface NavItem {
  href: string
  label: MessageKey
  icon: LucideIcon
  permission: Permission
  requiresRestaurant?: boolean
  /** Number shown next to the entry, e.g. open card orders waiting for the platform. */
  badge?: "openCardOrders"
}

export const RESTAURANT_NAV: NavItem[] = [
  { href: "/dashboard", label: "nav.dashboard", icon: LayoutDashboard, permission: "dashboard.view", requiresRestaurant: true },
  { href: "/vouchers", label: "nav.vouchers", icon: Ticket, permission: "vouchers.view", requiresRestaurant: true },
  { href: "/transactions", label: "nav.transactions", icon: ArrowLeftRight, permission: "transactions.view", requiresRestaurant: true },
  { href: "/cash-up", label: "nav.cashUp", icon: Wallet, permission: "transactions.view", requiresRestaurant: true },
  { href: "/customers", label: "nav.customers", icon: UserSquare2, permission: "customers.view", requiresRestaurant: true },
  { href: "/cards", label: "nav.cards", icon: CreditCard, permission: "cards.view", requiresRestaurant: true },
  { href: "/waiter", label: "nav.redeem", icon: QrCode, permission: "vouchers.redeem", requiresRestaurant: true },
]

export const MANAGE_NAV: NavItem[] = [
  { href: "/team", label: "nav.team", icon: Users, permission: "users.view", requiresRestaurant: true },
  { href: "/devices", label: "nav.devices", icon: Smartphone, permission: "devices.view", requiresRestaurant: true },
  { href: "/audit", label: "nav.audit", icon: ScrollText, permission: "audit.view", requiresRestaurant: true },
  { href: "/settings", label: "nav.settings", icon: Settings, permission: "settings.manage", requiresRestaurant: true },
]

export const PLATFORM_NAV: NavItem[] = [
  { href: "/admin", label: "nav.restaurants", icon: Building2, permission: "platform.restaurants.manage" },
  { href: "/admin/card-batches", label: "nav.cardBatches", icon: Package, permission: "platform.cards.manage", badge: "openCardOrders" },
  { href: "/admin/security", label: "nav.securityAlerts", icon: ShieldAlert, permission: "platform.audit.view" },
  { href: "/admin/audit", label: "nav.platformAudit", icon: ShieldCheck, permission: "platform.audit.view" },
  { href: "/admin/settings", label: "nav.systemSettings", icon: SlidersHorizontal, permission: "platform.settings.manage" },
]
