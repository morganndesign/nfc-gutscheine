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

function CustomersContent() {
  const { user, can } = useAuth()
  const router = useRouter()
  const [search, setSearch] = useState("")
  const [page, setPage] = useState(1)
  const [creating, setCreating] = useState(false)
  const { data, isLoading } = useCustomers(useDebounce(search), page)
  const currency = user?.restaurant?.currency ?? "EUR"

  return (
    <div className="space-y-6">
      <PageHeader
        title="Customers"
        description="Buyers and holders of your gift cards."
        actions={
          can("customers.manage") ? (
            <Button onClick={() => setCreating(true)}>
              <Plus /> New customer
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
              placeholder="Search name, e-mail or phone…"
              className="h-9 pl-9"
              aria-label="Search customers"
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
                  <TableHead className="pl-4">Name</TableHead>
                  <TableHead className="hidden md:table-cell">E-mail</TableHead>
                  <TableHead className="hidden lg:table-cell">Phone</TableHead>
                  <TableHead className="text-right">Cards</TableHead>
                  <TableHead className="text-right">Balance</TableHead>
                  <TableHead className="hidden pr-4 md:table-cell">Since</TableHead>
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
                    <TableCell className="tabular text-right">{c.gift_cards_count ?? 0}</TableCell>
                    <TableCell className="tabular text-right">{formatMoney(c.gift_cards_balance ?? 0, currency)}</TableCell>
                    <TableCell className="text-muted-foreground hidden pr-4 md:table-cell">{formatDate(c.created_at)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            <PaginationBar page={data.meta} onPageChange={setPage} />
          </>
        ) : (
          <EmptyState icon={UserSquare2} title="No customers" description="Customers are created when you issue a card with customer details." />
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
