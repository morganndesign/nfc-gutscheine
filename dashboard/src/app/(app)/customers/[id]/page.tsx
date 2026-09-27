"use client"

import { use, useState } from "react"
import Link from "next/link"
import { ArrowLeft, EyeOff, Mail, Pencil, Phone } from "lucide-react"
import { toast } from "sonner"
import { StatusBadge } from "@/components/common/status-badge"
import { ReasonDialog } from "@/components/common/reason-dialog"
import { CustomerDialog } from "@/components/common/customer-dialog"
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

function CustomerContent({ id }: { id: string }) {
  const { can } = useAuth()
  const { data, isLoading, refetch } = useCustomer(id)
  const anonymize = useAnonymizeCustomer(id)
  const [editing, setEditing] = useState(false)
  const [erasing, setErasing] = useState(false)

  if (isLoading || !data) return <Skeleton className="h-64 w-full rounded-2xl" />
  const c = data.data

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <Button variant="ghost" size="sm" asChild className="-ml-2">
          <Link href="/customers">
            <ArrowLeft /> Customers
          </Link>
        </Button>
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">{c.anonymized ? "Anonymized customer" : c.full_name}</h1>
            <p className="text-muted-foreground text-sm">Customer since {formatDate(c.created_at)}</p>
          </div>
          {can("customers.manage") && !c.anonymized ? (
            <div className="flex gap-2">
              <Button variant="outline" onClick={() => setEditing(true)}>
                <Pencil /> Edit
              </Button>
              <Button variant="outline" className="text-destructive" onClick={() => setErasing(true)}>
                <EyeOff /> Anonymize (GDPR)
              </Button>
            </div>
          ) : null}
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle>Contact</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            <p className="flex items-center gap-2">
              <Mail className="text-muted-foreground size-4" /> {c.email ?? "—"}
            </p>
            <p className="flex items-center gap-2">
              <Phone className="text-muted-foreground size-4" /> {c.phone ?? "—"}
            </p>
            <p className="text-muted-foreground">Marketing consent: {c.marketing_consent ? "yes" : "no"}</p>
            {c.notes ? <p className="bg-surface text-muted-foreground rounded-xl p-3 whitespace-pre-line">{c.notes}</p> : null}
          </CardContent>
        </Card>
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Gift cards · {formatMoney(c.gift_cards_balance ?? 0, data.gift_cards[0]?.currency ?? "EUR")} open</CardTitle>
          </CardHeader>
          <CardContent className="px-0">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-6">Card</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Balance</TableHead>
                  <TableHead className="pr-6">Expires</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.gift_cards.map((card) => (
                  <TableRow key={card.id}>
                    <TableCell className="pl-6">
                      <Link href={`/cards/${card.id}`} className="card-number hover:underline">
                        {card.card_number_formatted}
                      </Link>
                    </TableCell>
                    <TableCell>
                      <StatusBadge status={card.status} />
                    </TableCell>
                    <TableCell className="tabular text-right">{formatMoney(card.balance, card.currency)}</TableCell>
                    <TableCell className="text-muted-foreground pr-6">{formatDate(card.expires_at)}</TableCell>
                  </TableRow>
                ))}
                {!data.gift_cards.length ? (
                  <TableRow>
                    <TableCell colSpan={4} className="text-muted-foreground py-8 text-center">
                      No cards.
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
        title="Anonymize customer"
        description="Irreversibly removes name, e-mail, phone and notes (GDPR right to erasure). Cards and their balances stay valid."
        confirmLabel="Anonymize"
        destructive
        reasonRequired="none"
        pending={anonymize.isPending}
        onConfirm={async () => {
          try {
            await anonymize.mutateAsync()
            toast.success("Customer anonymized")
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
