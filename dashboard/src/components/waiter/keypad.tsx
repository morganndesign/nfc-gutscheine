"use client"

import { Delete } from "lucide-react"
import { cn } from "@/lib/utils"

const KEYS = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "00", "0", "del"] as const

/**
 * POS-style numeric keypad: digits shift in from the right (typing 1 8 5 0 → 18,50).
 */
export function Keypad({ value, onChange, maxCents }: { value: number; onChange: (cents: number) => void; maxCents?: number }) {
  const press = (key: (typeof KEYS)[number]) => {
    if (typeof navigator !== "undefined" && "vibrate" in navigator) navigator.vibrate?.(8)
    if (key === "del") {
      onChange(Math.floor(value / 10))
      return
    }
    const next = Number(`${value}${key}`)
    if (next > 99_999_999) return
    onChange(maxCents !== undefined && next > maxCents ? value : next)
  }

  return (
    <div className="short:gap-1.5 grid grid-cols-3 gap-2" role="group" aria-label="Amount keypad">
      {KEYS.map((key) => (
        <button
          key={key}
          type="button"
          onClick={() => press(key)}
          aria-label={key === "del" ? "Delete last digit" : key}
          className={cn(
            "bg-muted tabular active:bg-accent short:h-12 short:text-xl flex h-16 items-center justify-center rounded-2xl text-2xl font-medium transition select-none active:scale-95",
            key === "del" && "text-muted-foreground",
          )}
        >
          {key === "del" ? <Delete className="size-6" /> : key}
        </button>
      ))}
    </div>
  )
}
