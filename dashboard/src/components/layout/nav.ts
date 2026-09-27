import {
  ArrowLeftRight,
  Building2,
  CreditCard,
  LayoutDashboard,
  ScrollText,
  Settings,
  ShieldCheck,
  Smartphone,
  SlidersHorizontal,
  Users,
  UserSquare2,
  Nfc,
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
  { href: "/cards", label: "Gift cards", icon: CreditCard, permission: "cards.view", requiresRestaurant: true },
  { href: "/transactions", label: "Transactions", icon: ArrowLeftRight, permission: "transactions.view", requiresRestaurant: true },
  { href: "/customers", label: "Customers", icon: UserSquare2, permission: "customers.view", requiresRestaurant: true },
  { href: "/waiter", label: "Waiter mode", icon: Nfc, permission: "cards.scan", requiresRestaurant: true },
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
