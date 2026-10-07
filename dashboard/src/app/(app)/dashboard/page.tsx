"use client"

import { useState } from "react"
import dynamic from "next/dynamic"
import Link from "next/link"
import { ArrowDownRight, ArrowRight, CalendarClock, Euro, Plus, Receipt, Ticket, Wallet } from "lucide-react"
import { GettingStarted } from "@/components/dashboard/getting-started"
import { PageHeader } from "@/components/common/page-header"
import { QueryError } from "@/components/common/query-error"
import { StatCard } from "@/components/common/stat-card"
import { EmptyState } from "@/components/common/empty-state"
import { StatusBreakdown } from "@/components/charts/status-breakdown"
import { TransactionTypeIcon } from "@/components/vouchers/transaction-type"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Card, CardAction, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import { Segmented } from "@/components/common/segmented"
import { useDashboardCharts, useDashboardStats, useRecentActivity } from "@/lib/api/hooks"
import { useAuth } from "@/lib/auth"
import { formatRelative } from "@/lib/format"
import { formatMoney, formatSignedMoney } from "@/lib/money"
import { useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

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
  const t = useT()
  if (previous <= 0) return <span>{t("dashboard.trend.noPrevious")}</span>
  const change = ((current - previous) / previous) * 100
  const up = change >= 0
  return (
    <span>
      <span className={up ? "text-emerald-700 dark:text-emerald-400" : "text-red-600 dark:text-red-400"}>
        {up ? "▲" : "▼"} {Math.abs(change).toFixed(0)}%
      </span>{" "}
      {t("dashboard.trend.vsLastMonth")}
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
  const t = useT()
  const hour = new Date().getHours()
  const greeting: MessageKey = hour < 12 ? "dashboard.greeting.morning" : hour < 18 ? "dashboard.greeting.afternoon" : "dashboard.greeting.evening"

  return (
    <div className="space-y-8">
      <PageHeader
        title={t("nav.dashboard")}
        description={t(greeting, { name: user?.name.split(" ")[0] ?? "" })}
        actions={
          can("vouchers.sell") ? (
            <Button asChild>
              <Link href="/vouchers/new">
                <Plus /> {t("dashboard.sellVoucher")}
              </Link>
            </Button>
          ) : null
        }
      />

      {s && s.vouchers_sold === 0 ? <GettingStarted /> : null}

      {/* No figures rather than wrong ones: "0 € outstanding" while the server is unreachable would be false. */}
      {stats.error && !s ? (
        <QueryError error={stats.error} onRetry={() => void stats.refetch()} />
      ) : (
        <div className="grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-4">
          <StatCard
            label={t("dashboard.outstanding")}
            icon={Wallet}
            loading={stats.isLoading}
            value={formatMoney(s?.outstanding_balance, currency)}
            hint={s ? t("dashboard.outstandingHint", { count: s.outstanding_vouchers }) : null}
          />
          <StatCard
            label={t("dashboard.revenueMonth")}
            icon={Euro}
            loading={stats.isLoading}
            value={formatMoney(s?.monthly_revenue, currency)}
            hint={s ? <Trend current={s.monthly_revenue} previous={s.previous_month_revenue} /> : null}
          />
          <StatCard
            label={t("dashboard.redeemedMonth")}
            icon={ArrowDownRight}
            loading={stats.isLoading}
            value={formatMoney(s?.monthly_redeemed, currency)}
            hint={s ? t("dashboard.redeemedToday", { amount: formatMoney(s.today_redeemed, currency) }) : null}
          />
          <StatCard
            label={t("dashboard.vouchersSold")}
            icon={Ticket}
            loading={stats.isLoading}
            value={s?.vouchers_sold ?? 0}
            hint={s ? t("dashboard.vouchersSoldHint", { month: s.vouchers_sold_this_month, empty: s.vouchers_empty }) : null}
          />
        </div>
      )}

      <div className="grid gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>{t("dashboard.sales.title")}</CardTitle>
            <CardDescription>{t("dashboard.sales.description")}</CardDescription>
            <CardAction>
              <Segmented
                label={t("dashboard.period")}
                value={String(days) as "7" | "30" | "90"}
                onChange={(v) => setDays(Number(v) as 7 | 30 | 90)}
                options={[
                  { value: "7", label: t("dashboard.periodDays", { days: 7 }) },
                  { value: "30", label: t("dashboard.periodDays", { days: 30 }) },
                  { value: "90", label: t("dashboard.periodDays", { days: 90 }) },
                ]}
              />
            </CardAction>
          </CardHeader>
          <CardContent>{charts.data ? <SalesChart data={charts.data.daily} currency={currency} /> : <Skeleton className="h-64 w-full" />}</CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t("dashboard.voucherStatus.title")}</CardTitle>
            <CardDescription>
              {s && s.expiring_soon > 0 ? (
                <span className="inline-flex items-center gap-1">
                  <CalendarClock className="size-3.5" /> {t("dashboard.voucherStatus.expiring", { count: s.expiring_soon })}
                </span>
              ) : (
                t("dashboard.voucherStatus.all")
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
            <CardTitle>{t("dashboard.monthly.title")}</CardTitle>
            <CardDescription>{t("dashboard.monthly.description")}</CardDescription>
          </CardHeader>
          <CardContent>
            {charts.data ? <MonthlyRevenueChart data={charts.data.monthly} currency={currency} /> : <Skeleton className="h-56 w-full" />}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t("dashboard.activity.title")}</CardTitle>
            {can("transactions.view") ? (
              <CardAction>
                <Button variant="ghost" size="sm" asChild>
                  <Link href="/transactions">
                    {t("dashboard.activity.viewAll")} <ArrowRight />
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
            ) : activity.error && !activity.data ? (
              <QueryError error={activity.error} onRetry={() => void activity.refetch()} />
            ) : activity.data?.length ? (
              <ul>
                {activity.data.map((tx) => (
                  <li key={tx.id}>
                    <Link href={tx.voucher ? `/vouchers/${tx.voucher.id}` : "#"} className="hover:bg-muted flex items-center gap-3 rounded-lg px-2 py-2">
                      <TransactionTypeIcon type={tx.type} />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-medium">{t(`ops.txType.${tx.type}` as MessageKey)}</p>
                        <p className="text-muted-foreground truncate text-xs">
                          ••{tx.voucher?.voucher_number.slice(-4)} · {tx.user?.name ?? tx.device?.name ?? t("ops.system")} · {formatRelative(tx.created_at)}
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
              <EmptyState icon={Receipt} title={t("dashboard.activity.emptyTitle")} description={t("dashboard.activity.emptyDescription")} />
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
