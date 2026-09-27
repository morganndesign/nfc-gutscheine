"use client"

import { Bar, BarChart, CartesianGrid, XAxis, YAxis } from "recharts"
import { ChartContainer, ChartTooltip, type ChartConfig } from "@/components/ui/chart"
import { MoneyTooltip } from "@/components/charts/money-tooltip"
import { formatCompactMoney } from "@/lib/money"
import { regionalLocale } from "@/lib/regional"
import { ChartEmpty } from "@/components/charts/chart-empty"

const config = { revenue: { label: "Revenue", color: "var(--chart-1)" } } satisfies ChartConfig

export function MonthlyRevenueChart({ data, currency }: { data: { month: string; revenue: number }[]; currency: string }) {
  const monthFormat = new Intl.DateTimeFormat(regionalLocale(), { month: "short", timeZone: "UTC" })
  const longFormat = new Intl.DateTimeFormat(regionalLocale(), { month: "long", year: "numeric", timeZone: "UTC" })
  const toDate = (m: string) => new Date(`${m}-01T00:00:00Z`)

  if (!data.some((d) => d.revenue !== 0)) {
    return <ChartEmpty className="h-56" title="No revenue yet" description="Card sales and reloads appear here per month." />
  }

  return (
    <ChartContainer config={config} className="aspect-auto h-56 w-full">
      <BarChart data={data} margin={{ left: 4, right: 8, top: 8 }} barCategoryGap={6} accessibilityLayer>
        <CartesianGrid vertical={false} strokeDasharray="3 3" />
        <XAxis dataKey="month" tickLine={false} axisLine={false} tickMargin={8} tickFormatter={(m: string) => monthFormat.format(toDate(m))} />
        <YAxis tickLine={false} axisLine={false} width={64} tickFormatter={(v: number) => formatCompactMoney(v, currency)} />
        <ChartTooltip
          cursor={{ fill: "var(--muted)" }}
          content={<MoneyTooltip currency={currency} labels={{ revenue: "Revenue" }} labelFormatter={(m) => longFormat.format(toDate(m))} />}
        />
        <Bar dataKey="revenue" fill="var(--color-revenue)" radius={[4, 4, 0, 0]} maxBarSize={36} />
      </BarChart>
    </ChartContainer>
  )
}
