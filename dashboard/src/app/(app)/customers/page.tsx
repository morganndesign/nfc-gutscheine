"use client"

import { useState } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { Plus, Search, UserSquare2 } from "lucide-react"
import { PageHeader } from "@/components/common/page-header"
import { EmptyState } from "@/components/common/empty-state"
import { PaginationBar } from "@/components/common/pagination-bar"
import { CustomerDialog } from "@/components/common/customer-dialog"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useDebounce } from "@/hooks/use-debounce"
import { useCustomers } from "@/lib/api/hooks"
import { useAuth } from "@/lib/auth"
import { formatDate } from "@/lib/format"
import { formatMoney } from "@/lib/money"
import { useT } from "@/lib/i18n"

function CustomersContent() {
  const { user, can } = useAuth()
  const router = useRouter()
  const [search, setSearch] = useState("")
  const [page, setPage] = useState(1)
  const [creating, setCreating] = useState(false)
  const { data, isLoading } = useCustomers(useDebounce(search), page)
  const currency = user?.restaurant?.currency ?? "EUR"
  const t = useT()

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("nav.customers")}
        description={t("customers.description")}
        actions={
          can("customers.manage") ? (
            <Button onClick={() => setCreating(true)}>
              <Plus /> {t("customers.new")}
            </Button>
          ) : null
        }
      />
      <div className="bg-card overflow-hidden rounded-2xl border">
        <div className="border-b p-3">
          <div className="relative">
            <Search className="text-muted-foreground absolute top-1/2 left-3 size-4 -translate-y-1/2" />
            <Input
              value={search}
              onChange={(e) => (setSearch(e.target.value), setPage(1))}
              placeholder={t("customers.searchPlaceholder")}
              className="h-9 pl-9"
              aria-label={t("customers.searchLabel")}
            />
          </div>
        </div>
        {isLoading ? (
          <div className="space-y-2 p-4">
            {Array.from({ length: 6 }).map((_, i) => (
              <Skeleton key={i} className="h-10 w-full" />
            ))}
          </div>
        ) : data?.data.length ? (
          <>
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-4">{t("ops.col.name")}</TableHead>
                  <TableHead className="hidden md:table-cell">{t("ops.col.email")}</TableHead>
                  <TableHead className="hidden lg:table-cell">{t("ops.col.phone")}</TableHead>
                  <TableHead className="text-right">{t("customers.col.vouchers")}</TableHead>
                  <TableHead className="text-right">{t("ops.col.balance")}</TableHead>
                  <TableHead className="hidden pr-4 md:table-cell">{t("customers.col.since")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.data.map((c) => (
                  <TableRow key={c.id} className="cursor-pointer" onClick={() => router.push(`/customers/${c.id}`)}>
                    <TableCell className="pl-4 font-medium">
                      <Link
                        href={`/customers/${c.id}`}
                        className="hover:underline focus-visible:underline focus-visible:outline-none"
                        onClick={(e) => e.stopPropagation()}
                      >
                        {c.full_name}
                      </Link>
                    </TableCell>
                    <TableCell className="text-muted-foreground hidden md:table-cell">{c.email ?? "—"}</TableCell>
                    <TableCell className="text-muted-foreground hidden lg:table-cell">{c.phone ?? "—"}</TableCell>
                    <TableCell className="tabular text-right">{c.vouchers_count ?? 0}</TableCell>
                    <TableCell className="tabular text-right">{formatMoney(c.vouchers_balance ?? 0, currency)}</TableCell>
                    <TableCell className="text-muted-foreground hidden pr-4 md:table-cell">{formatDate(c.created_at)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            <PaginationBar page={data.meta} onPageChange={setPage} />
          </>
        ) : (
          <EmptyState icon={UserSquare2} title={t("customers.emptyTitle")} description={t("customers.emptyDescription")} />
        )}
      </div>
      <CustomerDialog open={creating} onOpenChange={setCreating} />
    </div>
  )
}

export default function CustomersPage() {
  return (
    <RequirePermission permission="customers.view">
      <CustomersContent />
    </RequirePermission>
  )
}
