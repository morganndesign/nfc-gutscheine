"use client"

import { ChevronLeft, ChevronRight } from "lucide-react"
import { Button } from "@/components/ui/button"
import type { Paginated } from "@/lib/api/types"
import { useT } from "@/lib/i18n"

export function PaginationBar<T>({ page, onPageChange }: { page?: Paginated<T>["meta"]; onPageChange: (page: number) => void }) {
  const t = useT()
  if (!page || page.total === 0) return null
  return (
    <div className="text-muted-foreground flex items-center justify-between gap-4 border-t px-4 py-3 text-sm">
      <span className="tabular">{t("pagination.range", { from: page.from, to: page.to, total: page.total })}</span>
      <div className="flex items-center gap-1">
        <Button variant="outline" size="sm" disabled={page.current_page <= 1} onClick={() => onPageChange(page.current_page - 1)}>
          <ChevronLeft /> {t("pagination.previous")}
        </Button>
        <Button variant="outline" size="sm" disabled={page.current_page >= page.last_page} onClick={() => onPageChange(page.current_page + 1)}>
          {t("pagination.next")} <ChevronRight />
        </Button>
      </div>
    </div>
  )
}
