import { ChevronLeft, ChevronRight } from "lucide-react"
import { Button } from "@/components/ui/button"
import type { Paginated } from "@/lib/api/types"

export function PaginationBar<T>({ page, onPageChange }: { page?: Paginated<T>["meta"]; onPageChange: (page: number) => void }) {
  if (!page || page.total === 0) return null
  return (
    <div className="text-muted-foreground flex items-center justify-between gap-4 border-t px-4 py-3 text-sm">
      <span className="tabular">
        {page.from}–{page.to} of {page.total}
      </span>
      <div className="flex items-center gap-1">
        <Button variant="outline" size="sm" disabled={page.current_page <= 1} onClick={() => onPageChange(page.current_page - 1)}>
          <ChevronLeft /> Previous
        </Button>
        <Button variant="outline" size="sm" disabled={page.current_page >= page.last_page} onClick={() => onPageChange(page.current_page + 1)}>
          Next <ChevronRight />
        </Button>
      </div>
    </div>
  )
}
