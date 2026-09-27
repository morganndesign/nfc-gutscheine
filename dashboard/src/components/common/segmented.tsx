"use client"

import type { ReactNode } from "react"
import { cn } from "@/lib/utils"

/**
 * A segmented control (looks like the tab list) for choosing one option that filters or switches the
 * content in place. Unlike Tabs it has no panels, so it is announced as a radio group.
 */
export function Segmented<T extends string>({
  value,
  onChange,
  options,
  label,
  className,
}: {
  value: T
  onChange: (value: T) => void
  options: { value: T; label: ReactNode }[]
  label: string
  className?: string
}) {
  return (
    <div role="radiogroup" aria-label={label} className={cn("bg-muted inline-flex h-8 w-fit items-center rounded-lg p-[3px]", className)}>
      {options.map((o) => {
        const active = o.value === value
        return (
          <button
            key={o.value}
            type="button"
            role="radio"
            aria-checked={active}
            onClick={() => onChange(o.value)}
            className={cn(
              "focus-visible:ring-ring/50 inline-flex h-full flex-1 items-center justify-center rounded-md border border-transparent px-2 text-sm font-medium whitespace-nowrap transition-all outline-none focus-visible:ring-[3px]",
              active
                ? "bg-background text-foreground dark:border-input dark:bg-input/30 shadow-sm"
                : "text-foreground/70 hover:text-foreground dark:text-muted-foreground dark:hover:text-foreground",
            )}
          >
            {o.label}
          </button>
        )
      })}
    </div>
  )
}
