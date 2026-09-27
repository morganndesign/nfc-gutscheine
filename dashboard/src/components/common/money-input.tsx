"use client"

import { forwardRef } from "react"
import { Input } from "@/components/ui/input"
import { useAuth } from "@/lib/auth"
import { centsToInput, currencySymbol } from "@/lib/money"
import { cn } from "@/lib/utils"

/**
 * Text input for amounts ("12,50" / "12.50") in the restaurant's currency.
 * Parsing to cents happens with parseMoneyInput().
 */
export const MoneyInput = forwardRef<HTMLInputElement, React.ComponentProps<"input">>(function MoneyInput({ className, ...props }, ref) {
  const { user } = useAuth()
  const symbol = currencySymbol(user?.restaurant?.currency ?? "EUR")

  return (
    <div className="relative">
      <span className="text-muted-foreground pointer-events-none absolute inset-y-0 left-3 flex items-center text-sm" aria-hidden>
        {symbol}
      </span>
      <Input
        ref={ref}
        inputMode="decimal"
        autoComplete="off"
        className={cn("tabular", symbol.length > 1 ? "pl-11" : "pl-7", className)}
        placeholder={centsToInput(0)}
        {...props}
      />
    </div>
  )
})
