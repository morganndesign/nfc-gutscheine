"use client"

import { Bar, BarChart, CartesianGrid, XAxis, YAxis } from "recharts"
import { ChartEmpty } from "@/components/charts/chart-empty"
import { ChartContainer, ChartTooltip, type ChartConfig } from "@/components/ui/chart"
import { MoneyTooltip } from "@/components/charts/money-tooltip"
import { formatCompactMoney } from "@/lib/money"
import { regionalLocale } from "@/lib/regional"

const config = {
  sold: { label: "Sold", color: "var(--chart-1)" },
  redeemed: { label: "Redeemed", color: "var(--chart-2)" },
} satisfies ChartConfig

const LABELS = { sold: "Sold (issued + reloaded)", redeemed: "Redeemed" }

export function SalesChart({ data, currency }: { data: { date: string; sold: number; redeemed: number }[]; currency: string }) {
  // Buckets are calendar days of the restaurant; format them as plain dates (UTC) so no timezone can shift them.
  const dayFormat = new Intl.DateTimeFormat(regionalLocale(), { day: "2-digit", month: "short", timeZone: "UTC" })
  const fullFormat = new Intl.DateTimeFormat(regionalLocale(), { weekday: "short", day: "2-digit", month: "long", timeZone: "UTC" })
  const toDate = (day: string) => new Date(`${day}T00:00:00Z`)

  if (!data.some((d) => d.sold !== 0 || d.redeemed !== 0)) {
    return <ChartEmpty className="h-64" title="No sales in this period" description="Sold and redeemed amounts appear here per day." />
  }

  return (
    <div className="space-y-3">
      <div className="text-muted-foreground flex items-center gap-4 text-xs" aria-hidden>
        <span className="flex items-center gap-1.5">
          <span className="size-2.5 rounded-sm bg-[var(--chart-1)]" /> Sold
        </span>
        <span className="flex items-center gap-1.5">
          <span className="size-2.5 rounded-sm bg-[var(--chart-2)]" /> Redeemed
        </span>
      </div>
      <ChartContainer config={config} className="aspect-auto h-64 w-full">
        <BarChart data={data} margin={{ left: 4, right: 8, top: 8 }} barGap={1} barCategoryGap="20%" accessibilityLayer>
          <CartesianGrid vertical={false} strokeDasharray="3 3" />
          <XAxis dataKey="date" tickLine={false} axisLine={false} tickMargin={8} minTickGap={24} tickFormatter={(v: string) => dayFormat.format(toDate(v))} />
          <YAxis tickLine={false} axisLine={false} width={64} tickFormatter={(v: number) => formatCompactMoney(v, currency)} />
          <ChartTooltip
            cursor={{ fill: "var(--muted)" }}
            content={<MoneyTooltip currency={currency} labels={LABELS} labelFormatter={(l) => fullFormat.format(toDate(l))} />}
          />
          <Bar dataKey="sold" fill="var(--color-sold)" radius={[3, 3, 0, 0]} maxBarSize={14} />
          <Bar dataKey="redeemed" fill="var(--color-redeemed)" radius={[3, 3, 0, 0]} maxBarSize={14} />
        </BarChart>
      </ChartContainer>
    </div>
  )
}
