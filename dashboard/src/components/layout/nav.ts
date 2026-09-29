import {
  ArrowLeftRight,
  Building2,
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
  type LucideIcon,
} from "lucide-react"
import type { Permission } from "@/lib/api/types"

export interface NavItem {
  href: string
  label: string
  icon: LucideIcon
  permission: Permission
  requiresRestaurant?: boolean
}

export const RESTAURANT_NAV: NavItem[] = [
  { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard, permission: "dashboard.view", requiresRestaurant: true },
  { href: "/vouchers", label: "Vouchers", icon: Ticket, permission: "vouchers.view", requiresRestaurant: true },
  { href: "/transactions", label: "Transactions", icon: ArrowLeftRight, permission: "transactions.view", requiresRestaurant: true },
  { href: "/customers", label: "Customers", icon: UserSquare2, permission: "customers.view", requiresRestaurant: true },
  { href: "/waiter", label: "Redeem", icon: QrCode, permission: "vouchers.redeem", requiresRestaurant: true },
]

export const MANAGE_NAV: NavItem[] = [
  { href: "/team", label: "Team", icon: Users, permission: "users.view", requiresRestaurant: true },
  { href: "/devices", label: "Devices", icon: Smartphone, permission: "devices.view", requiresRestaurant: true },
  { href: "/audit", label: "Audit log", icon: ScrollText, permission: "audit.view", requiresRestaurant: true },
  { href: "/settings", label: "Settings", icon: Settings, permission: "settings.manage", requiresRestaurant: true },
]

export const PLATFORM_NAV: NavItem[] = [
  { href: "/admin", label: "Restaurants", icon: Building2, permission: "platform.restaurants.manage" },
  { href: "/admin/audit", label: "Platform audit", icon: ShieldCheck, permission: "platform.audit.view" },
  { href: "/admin/settings", label: "System settings", icon: SlidersHorizontal, permission: "platform.settings.manage" },
]
