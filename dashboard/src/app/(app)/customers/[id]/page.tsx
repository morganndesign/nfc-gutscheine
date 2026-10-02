"use client"

import { use, useState } from "react"
import Link from "next/link"
import { ArrowLeft, EyeOff, Mail, Pencil, Phone } from "lucide-react"
import { toast } from "sonner"
import { StatusBadge, displayStatus } from "@/components/common/status-badge"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { CustomerDialog } from "@/components/common/customer-dialog"
import { QueryError } from "@/components/common/query-error"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useAnonymizeCustomer, useCustomer } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import { useAuth } from "@/lib/auth"
import { formatDate } from "@/lib/format"
import { formatMoney } from "@/lib/money"
import { useT } from "@/lib/i18n"

function CustomerContent({ id }: { id: string }) {
  const { can } = useAuth()
  const { data, isLoading, error, refetch } = useCustomer(id)
  const anonymize = useAnonymizeCustomer(id)
  const [editing, setEditing] = useState(false)
  const [erasing, setErasing] = useState(false)
  const t = useT()

  if (error && !data) return <QueryError error={error} onRetry={() => void refetch()} />
  if (isLoading || !data) return <Skeleton className="h-64 w-full rounded-2xl" />
  const c = data.data

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <Button variant="ghost" size="sm" asChild className="-ml-2">
          <Link href="/customers">
            <ArrowLeft /> {t("nav.customers")}
          </Link>
        </Button>
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">{c.anonymized ? t("customer.anonymized") : c.full_name}</h1>
            <p className="text-muted-foreground text-sm">{t("customer.since", { date: formatDate(c.created_at) })}</p>
          </div>
          {can("customers.manage") && !c.anonymized ? (
            <div className="flex gap-2">
              <Button variant="outline" onClick={() => setEditing(true)}>
                <Pencil /> {t("common.edit")}
              </Button>
              <Button variant="outline" className="text-destructive" onClick={() => setErasing(true)}>
                <EyeOff /> {t("customer.anonymize")}
              </Button>
            </div>
          ) : null}
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle>{t("customer.contact")}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            <p className="flex items-center gap-2">
              <Mail className="text-muted-foreground size-4" /> {c.email ?? "—"}
            </p>
            <p className="flex items-center gap-2">
              <Phone className="text-muted-foreground size-4" /> {c.phone ?? "—"}
            </p>
            <p className="text-muted-foreground">{c.marketing_consent ? t("customer.marketingYes") : t("customer.marketingNo")}</p>
            {c.notes ? <p className="bg-surface text-muted-foreground rounded-xl p-3 whitespace-pre-line">{c.notes}</p> : null}
          </CardContent>
        </Card>
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>{t("customer.vouchersTitle", { amount: formatMoney(c.vouchers_balance ?? 0, data.vouchers[0]?.currency ?? "EUR") })}</CardTitle>
          </CardHeader>
          <CardContent className="px-0">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-6">{t("ops.col.voucher")}</TableHead>
                  <TableHead>{t("ops.col.status")}</TableHead>
                  <TableHead className="text-right">{t("ops.col.balance")}</TableHead>
                  <TableHead className="pr-6">{t("ops.col.expires")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.vouchers.map((voucher) => (
                  <TableRow key={voucher.id}>
                    <TableCell className="pl-6">
                      <Link href={`/vouchers/${voucher.id}`} className="card-number hover:underline">
                        {voucher.voucher_number_formatted}
                      </Link>
                    </TableCell>
                    <TableCell>
                      <StatusBadge status={displayStatus(voucher)} />
                    </TableCell>
                    <TableCell className="tabular text-right">{formatMoney(voucher.balance, voucher.currency)}</TableCell>
                    <TableCell className="text-muted-foreground pr-6">{formatDate(voucher.expires_at)}</TableCell>
                  </TableRow>
                ))}
                {!data.vouchers.length ? (
                  <TableRow>
                    <TableCell colSpan={4} className="text-muted-foreground py-8 text-center">
                      {t("customer.noVouchers")}
                    </TableCell>
                  </TableRow>
                ) : null}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </div>

      <CustomerDialog
        customer={c}
        open={editing}
        onOpenChange={(o) => {
          setEditing(o)
          if (!o) void refetch()
        }}
      />
      <ReasonDialog
        open={erasing}
        onOpenChange={setErasing}
        title={t("customer.anonymizeTitle")}
        description={t("customer.anonymizeDescription")}
        confirmLabel={t("customer.anonymizeConfirm")}
        destructive
        reasonRequired="none"
        pending={anonymize.isPending}
        onConfirm={async () => {
          try {
            await anonymize.mutateAsync()
            toast.success(t("customer.anonymizedToast"))
            setErasing(false)
            void refetch()
          } catch (e) {
            toast.error(errorMessage(e))
          }
        }}
      />
    </div>
  )
}

export default function CustomerPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  return (
    <RequirePermission permission="customers.view">
      <CustomerContent id={id} />
    </RequirePermission>
  )
}
