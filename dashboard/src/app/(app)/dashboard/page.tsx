"use client"

import { useState } from "react"
import dynamic from "next/dynamic"
import Link from "next/link"
import { ArrowDownRight, ArrowRight, CalendarClock, CreditCard, Euro, Plus, Receipt, Wallet } from "lucide-react"
import { GettingStarted } from "@/components/dashboard/getting-started"
import { PageHeader } from "@/components/common/page-header"
import { StatCard } from "@/components/common/stat-card"
import { EmptyState } from "@/components/common/empty-state"
import { StatusBreakdown } from "@/components/charts/status-breakdown"
import { TransactionTypeIcon } from "@/components/cards/transaction-type"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Card, CardAction, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import { Segmented } from "@/components/common/segmented"
import { useDashboardCharts, useDashboardStats, useRecentActivity } from "@/lib/api/hooks"
import { useAuth } from "@/lib/auth"
import { formatRelative } from "@/lib/format"
import { formatMoney, formatSignedMoney } from "@/lib/money"

// Recharts is the heaviest dependency of the app: load it after the KPIs so the numbers appear first.
const SalesChart = dynamic(() => import("@/components/charts/sales-chart").then((m) => m.SalesChart), {
  ssr: false,
  loading: () => <Skeleton className="h-64 w-full" />,
})
const MonthlyRevenueChart = dynamic(() => import("@/components/charts/monthly-revenue-chart").then((m) => m.MonthlyRevenueChart), {
  ssr: false,
  loading: () => <Skeleton className="h-56 w-full" />,
})

function Trend({ current, previous }: { current: number; previous: number }) {
  if (previous <= 0) return <span>No sales last month</span>
  const change = ((current - previous) / previous) * 100
  const up = change >= 0
  return (
    <span>
      <span className={up ? "text-emerald-700 dark:text-emerald-400" : "text-red-600 dark:text-red-400"}>
        {up ? "▲" : "▼"} {Math.abs(change).toFixed(0)}%
      </span>{" "}
      vs. last month
    </span>
  )
}

function DashboardContent() {
  const { user, can } = useAuth()
  const [days, setDays] = useState<7 | 30 | 90>(30)
  const stats = useDashboardStats()
  const charts = useDashboardCharts(days)
  const activity = useRecentActivity(8)
  const currency = user?.restaurant?.currency ?? "EUR"
  const s = stats.data

  return (
    <div className="space-y-8">
      <PageHeader
        title="Dashboard"
        description={`Good ${new Date().getHours() < 12 ? "morning" : new Date().getHours() < 18 ? "afternoon" : "evening"}, ${user?.name.split(" ")[0] ?? ""}.`}
        actions={
          can("cards.create") ? (
            <Button asChild>
              <Link href="/cards/new">
                <Plus /> New gift card
              </Link>
            </Button>
          ) : null
        }
      />

      {s && s.cards_sold === 0 ? <GettingStarted /> : null}

      <div className="grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-4">
        <StatCard
          label="Outstanding balance"
          icon={Wallet}
          loading={stats.isLoading}
          value={formatMoney(s?.outstanding_balance, currency)}
          hint={s ? `Open liability on ${s.outstanding_cards} card${s.outstanding_cards === 1 ? "" : "s"}` : null}
        />
        <StatCard
          label="Revenue this month"
          icon={Euro}
          loading={stats.isLoading}
          value={formatMoney(s?.monthly_revenue, currency)}
          hint={s ? <Trend current={s.monthly_revenue} previous={s.previous_month_revenue} /> : null}
        />
        <StatCard
          label="Redeemed this month"
          icon={ArrowDownRight}
          loading={stats.isLoading}
          value={formatMoney(s?.monthly_redeemed, currency)}
          hint={s ? `${formatMoney(s.today_redeemed, currency)} today` : null}
        />
        <StatCard
          label="Cards sold"
          icon={CreditCard}
          loading={stats.isLoading}
          value={s?.cards_sold ?? 0}
          hint={s ? `${s.cards_sold_this_month} this month · ${s.cards_active} in use` : null}
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Sales & redemptions</CardTitle>
            <CardDescription>Daily card value sold vs. redeemed</CardDescription>
            <CardAction>
              <Segmented
                label="Period"
                value={String(days) as "7" | "30" | "90"}
                onChange={(v) => setDays(Number(v) as 7 | 30 | 90)}
                options={[
                  { value: "7", label: "7d" },
                  { value: "30", label: "30d" },
                  { value: "90", label: "90d" },
                ]}
              />
            </CardAction>
          </CardHeader>
          <CardContent>{charts.data ? <SalesChart data={charts.data.daily} currency={currency} /> : <Skeleton className="h-64 w-full" />}</CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Card status</CardTitle>
            <CardDescription>
              {s && s.expiring_soon > 0 ? (
                <span className="inline-flex items-center gap-1">
                  <CalendarClock className="size-3.5" /> {s.expiring_soon} card{s.expiring_soon === 1 ? "" : "s"} expire within 30 days
                </span>
              ) : (
                "All cards by status"
              )}
            </CardDescription>
          </CardHeader>
          <CardContent>
            {charts.data ? <StatusBreakdown data={charts.data.status_distribution} currency={currency} /> : <Skeleton className="h-48 w-full" />}
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Monthly revenue</CardTitle>
            <CardDescription>Card sales and reloads over the last 12 months</CardDescription>
          </CardHeader>
          <CardContent>
            {charts.data ? <MonthlyRevenueChart data={charts.data.monthly} currency={currency} /> : <Skeleton className="h-56 w-full" />}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Recent activity</CardTitle>
            {can("transactions.view") ? (
              <CardAction>
                <Button variant="ghost" size="sm" asChild>
                  <Link href="/transactions">
                    View all <ArrowRight />
                  </Link>
                </Button>
              </CardAction>
            ) : null}
          </CardHeader>
          <CardContent className="px-2">
            {activity.isLoading ? (
              <div className="space-y-3 px-2">
                {Array.from({ length: 5 }).map((_, i) => (
                  <Skeleton key={i} className="h-10 w-full" />
                ))}
              </div>
            ) : activity.data?.length ? (
              <ul>
                {activity.data.map((tx) => (
                  <li key={tx.id}>
                    <Link href={tx.gift_card ? `/cards/${tx.gift_card.id}` : "#"} className="hover:bg-muted flex items-center gap-3 rounded-lg px-2 py-2">
                      <TransactionTypeIcon type={tx.type} />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-medium">{tx.type_label}</p>
                        <p className="text-muted-foreground truncate text-xs">
                          ••{tx.gift_card?.card_number.slice(-4)} · {tx.user?.name ?? "System"} · {formatRelative(tx.created_at)}
                        </p>
                      </div>
                      <span
                        className={`tabular text-sm font-medium ${tx.amount > 0 ? "text-emerald-700 dark:text-emerald-400" : ""} ${tx.reversed ? "line-through opacity-60" : ""}`}
                      >
                        {formatSignedMoney(tx.amount, tx.currency)}
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            ) : (
              <EmptyState icon={Receipt} title="No activity yet" description="Transactions will appear here as soon as cards are issued or redeemed." />
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

export default function DashboardPage() {
  return (
    <RequirePermission permission="dashboard.view">
      <DashboardContent />
    </RequirePermission>
  )
}
