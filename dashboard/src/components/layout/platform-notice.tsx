"use client"

import { Info } from "lucide-react"
import { useAuth } from "@/lib/auth"

/** Platform-wide announcement (System settings → maintenance notice). */
export function PlatformNotice() {
  const { user } = useAuth()
  const notice = user?.platform?.notice?.trim()
  if (!notice) return null

  return (
    <div role="status" className="flex items-center gap-2 bg-sky-50 px-4 py-2 text-sm text-sky-900 dark:bg-sky-500/10 dark:text-sky-200">
      <Info className="size-4 shrink-0" aria-hidden />
      <span>{notice}</span>
    </div>
  )
}
