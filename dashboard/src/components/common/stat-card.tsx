import type { LucideIcon } from "lucide-react"
import type { ReactNode } from "react"
import { Skeleton } from "@/components/ui/skeleton"
import { cn } from "@/lib/utils"

export function StatCard({
  label,
  value,
  hint,
  icon: Icon,
  loading,
  className,
}: {
  label: string
  value: ReactNode
  hint?: ReactNode
  icon?: LucideIcon
  loading?: boolean
  className?: string
}) {
  return (
    <div className={cn("bg-card min-w-0 rounded-2xl border p-4 shadow-[0_1px_2px_rgba(0,0,0,0.03)] sm:p-5", className)}>
      <div className="text-muted-foreground flex items-center justify-between gap-2 text-xs sm:text-sm">
        <span>{label}</span>
        {Icon ? <Icon className="size-4" aria-hidden /> : null}
      </div>
      <div className="tabular mt-2 truncate text-xl font-semibold tracking-tight sm:mt-3 sm:text-2xl">
        {loading ? <Skeleton className="h-8 w-28" /> : value}
      </div>
      {hint ? <div className="text-muted-foreground mt-1 text-xs">{loading ? <Skeleton className="h-3 w-20" /> : hint}</div> : null}
    </div>
  )
}
