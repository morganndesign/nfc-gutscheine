"use client"

import { useRouter } from "next/navigation"
import { useQueryClient } from "@tanstack/react-query"
import { Eye, X } from "lucide-react"
import { Button } from "@/components/ui/button"
import { getActingRestaurant, setActingRestaurant } from "@/lib/api/client"
import { useAuth } from "@/lib/auth"

/** Shown while a platform administrator operates inside a restaurant. */
export function ActingBanner() {
  const { user } = useAuth()
  const qc = useQueryClient()
  const router = useRouter()

  if (!user?.is_platform_admin || !user.restaurant || !getActingRestaurant()) return null

  return (
    <div className="flex items-center justify-between gap-3 bg-amber-100 px-4 py-2 text-sm text-amber-900 dark:bg-amber-500/15 dark:text-amber-200">
      <span className="flex min-w-0 items-center gap-2">
        <Eye className="size-4 shrink-0" aria-hidden />
        <span className="min-w-0">
          Viewing <strong>{user.restaurant.name}</strong> as platform administrator. All actions are audited.
        </span>
      </span>
      <Button
        size="sm"
        variant="ghost"
        onClick={() => {
          setActingRestaurant(null)
          void qc.resetQueries()
          router.push("/admin")
        }}
      >
        <X /> Exit
      </Button>
    </div>
  )
}
