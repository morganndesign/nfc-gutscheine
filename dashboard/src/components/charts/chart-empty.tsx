import { BarChart3 } from "lucide-react"
import { cn } from "@/lib/utils"

/** Placeholder for a chart without data: a calm message instead of an axis full of "€ 0". */
export function ChartEmpty({ title, description, className }: { title: string; description?: string; className?: string }) {
  return (
    <div className={cn("flex flex-col items-center justify-center gap-2 rounded-xl border border-dashed text-center", className)}>
      <span className="bg-muted text-muted-foreground flex size-10 items-center justify-center rounded-full">
        <BarChart3 className="size-5" aria-hidden />
      </span>
      <p className="text-sm font-medium">{title}</p>
      {description ? <p className="text-muted-foreground max-w-xs text-xs">{description}</p> : null}
    </div>
  )
}
