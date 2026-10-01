"use client"

import { useState } from "react"
import { Download, Loader2 } from "lucide-react"
import { toast } from "sonner"
import { PageHeader } from "@/components/common/page-header"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableFooter, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useCashUp } from "@/lib/api/hooks"
import { downloadFile, errorMessage } from "@/lib/api/client"
import { useAuth } from "@/lib/auth"
import { todayInput } from "@/lib/format"
import { formatMoney } from "@/lib/money"
import { hasMessage, useT } from "@/lib/i18n"

function CashUpView() {
  const { user, can } = useAuth()
  const today = todayInput(0, user?.restaurant?.timezone)
  const [date, setDate] = useState(today)
  const [exporting, setExporting] = useState(false)
  const { data, isLoading, error } = useCashUp(date)
  const t = useT()
  const methodLabel = (method: string) => {
    const key = `ops.method.${method}`
    return hasMessage(key) ? t(key) : method
  }
  const money = (cents: number) => formatMoney(cents, data?.currency ?? user?.restaurant?.currency ?? "EUR")

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("nav.cashUp")}
        description={t("cashUp.description")}
        actions={
          <div className="flex flex-wrap items-center gap-2">
            <Input
              type="date"
              value={date}
              max={today}
              onChange={(e) => e.target.value && setDate(e.target.value)}
              className="w-40"
              aria-label={t("cashUp.day")}
            />
            {can("transactions.export") ? (
              <Button
                variant="outline"
                disabled={exporting}
                onClick={async () => {
                  setExporting(true)
                  try {
                    await downloadFile("/reports/payments/export", { from: date, to: date }, `payments-${date}.csv`)
                  } catch (e) {
                    toast.error(errorMessage(e))
                  } finally {
                    setExporting(false)
                  }
                }}
              >
                {exporting ? <Loader2 className="animate-spin" /> : <Download />} {t("cashUp.exportPayments")}
              </Button>
            ) : null}
          </div>
        }
      />
      {error ? <p className="text-destructive text-sm">{errorMessage(error)}</p> : null}
      {isLoading || !data ? (
        <Skeleton className="h-64 w-full" />
      ) : (
        <>
          <Card>
            <CardHeader>
              <CardTitle>{t("cashUp.perMethod")}</CardTitle>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t("cashUp.method")}</TableHead>
                    <TableHead className="text-right">{t("cashUp.received")}</TableHead>
                    <TableHead className="text-right">{t("cashUp.paidBack")}</TableHead>
                    <TableHead className="text-right">{t("cashUp.net")}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {data.methods.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={4} className="text-muted-foreground text-center">
                        {t("cashUp.noMoney")}
                      </TableCell>
                    </TableRow>
                  ) : (
                    data.methods.map((m) => (
                      <TableRow key={m.method}>
                        <TableCell>{methodLabel(m.method)}</TableCell>
                        <TableCell className="text-right tabular-nums">{money(m.received)}</TableCell>
                        <TableCell className="text-right tabular-nums">{m.paid_out ? `−${money(m.paid_out)}` : "—"}</TableCell>
                        <TableCell className="text-right font-medium tabular-nums">{money(m.net)}</TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
                <TableFooter>
                  <TableRow>
                    <TableCell>{t("cashUp.total")}</TableCell>
                    <TableCell className="text-right tabular-nums">{money(data.total_received)}</TableCell>
                    <TableCell className="text-right tabular-nums">{data.total_paid_out ? `−${money(data.total_paid_out)}` : "—"}</TableCell>
                    <TableCell className="text-right tabular-nums">{money(data.total_received - data.total_paid_out)}</TableCell>
                  </TableRow>
                </TableFooter>
              </Table>
            </CardContent>
          </Card>

          <div className="grid gap-6 lg:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)]">
            <Card>
              <CardHeader>
                <CardTitle>{t("cashUp.perPerson")}</CardTitle>
              </CardHeader>
              <CardContent>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t("cashUp.person")}</TableHead>
                      <TableHead>{t("cashUp.method")}</TableHead>
                      <TableHead className="text-right">{t("cashUp.received")}</TableHead>
                      <TableHead className="text-right">{t("cashUp.paidBack")}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {data.staff.map((s) => (
                      <TableRow key={`${s.user?.id ?? "system"}-${s.method}`}>
                        <TableCell>{s.user?.name ?? "—"}</TableCell>
                        <TableCell>{methodLabel(s.method)}</TableCell>
                        <TableCell className="text-right tabular-nums">{money(s.received)}</TableCell>
                        <TableCell className="text-right tabular-nums">{s.paid_out ? `−${money(s.paid_out)}` : "—"}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>
            <Card>
              <CardHeader>
                <CardTitle>{t("cashUp.alsoToday")}</CardTitle>
              </CardHeader>
              <CardContent>
                <dl className="divide-y text-sm">
                  <div className="flex justify-between py-2.5">
                    <dt className="text-muted-foreground">{t("cashUp.reversedReloads")}</dt>
                    <dd className="tabular-nums">{money(data.reversed_reloads)}</dd>
                  </div>
                  <div className="flex justify-between py-2.5">
                    <dt className="text-muted-foreground">{t("cashUp.complimentary")}</dt>
                    <dd className="tabular-nums">{money(data.complimentary)}</dd>
                  </div>
                  <div className="flex justify-between py-2.5">
                    <dt className="text-muted-foreground">{t("cashUp.outstanding")}</dt>
                    <dd className="font-medium tabular-nums">{money(data.outstanding_end_of_day)}</dd>
                  </div>
                </dl>
              </CardContent>
            </Card>
          </div>
        </>
      )}
    </div>
  )
}

export default function CashUpPage() {
  return (
    <RequirePermission permission="transactions.view">
      <CashUpView />
    </RequirePermission>
  )
}
