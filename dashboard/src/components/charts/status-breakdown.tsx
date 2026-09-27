import { StatusBadge } from "@/components/common/status-badge"
import { formatMoney } from "@/lib/money"
import type { CardStatus } from "@/lib/api/types"
import { ChartEmpty } from "@/components/charts/chart-empty"

/** Card count per status as labelled bars (single hue — magnitude, not identity). */
export function StatusBreakdown({ data, currency }: { data: { status: CardStatus; count: number; balance: number }[]; currency: string }) {
  const order: CardStatus[] = ["active", "inactive", "redeemed", "blocked", "expired", "replaced"]
  const rows = order.map((s) => data.find((d) => d.status === s) ?? { status: s, count: 0, balance: 0 }).filter((r) => r.count > 0)
  const max = Math.max(1, ...rows.map((r) => r.count))

  if (!rows.length) return <ChartEmpty className="h-48" title="No cards yet" description="Issued cards appear here grouped by status." />

  return (
    <ul className="space-y-3">
      {rows.map((row) => (
        <li key={row.status} className="space-y-1.5">
          <div className="flex items-center justify-between text-sm">
            <StatusBadge status={row.status} />
            <span className="tabular text-muted-foreground">
              <span className="text-foreground font-medium">{row.count}</span>
              {row.balance > 0 ? ` · ${formatMoney(row.balance, currency)}` : ""}
            </span>
          </div>
          <div className="bg-muted h-1.5 overflow-hidden rounded-full">
            <div className="h-full rounded-full bg-[var(--chart-1)]" style={{ width: `${(row.count / max) * 100}%` }} />
          </div>
        </li>
      ))}
    </ul>
  )
}
