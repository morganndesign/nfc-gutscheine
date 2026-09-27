"use client"

import { formatMoney } from "@/lib/money"

interface Item {
  name?: string | number
  value?: number | string
  color?: string
  dataKey?: string | number
}

/** Tooltip body for money series: label + one row per series with the series swatch. */
export function MoneyTooltip({
  active,
  payload,
  label,
  currency,
  labels,
  labelFormatter,
}: {
  active?: boolean
  payload?: Item[]
  label?: string | number
  currency: string
  labels: Record<string, string>
  labelFormatter?: (label: string) => string
}) {
  if (!active || !payload?.length) return null
  return (
    <div className="bg-popover min-w-44 rounded-xl border px-3 py-2 text-xs shadow-lg">
      <div className="text-foreground mb-1.5 font-medium">{labelFormatter ? labelFormatter(String(label)) : label}</div>
      <div className="space-y-1">
        {payload.map((item) => (
          <div key={String(item.dataKey)} className="flex items-center justify-between gap-4">
            <span className="text-muted-foreground flex items-center gap-2">
              <span className="size-2.5 rounded-[3px]" style={{ background: item.color }} aria-hidden />
              {labels[String(item.dataKey)] ?? item.name}
            </span>
            <span className="text-foreground tabular font-medium">{formatMoney(Number(item.value ?? 0), currency)}</span>
          </div>
        ))}
      </div>
    </div>
  )
}
