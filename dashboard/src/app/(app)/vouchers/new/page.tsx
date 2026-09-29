"use client"

import { useEffect, useMemo, useRef, useState } from "react"
import Link from "next/link"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { AlertTriangle, ArrowLeft, Check, Loader2, Printer } from "lucide-react"
import { toast } from "sonner"
import { PageHeader } from "@/components/common/page-header"
import { MoneyInput } from "@/components/common/money-input"
import { Segmented } from "@/components/common/segmented"
import { RequirePermission } from "@/components/layout/auth-guard"
import { PaymentFields, paymentComplete } from "@/components/vouchers/payment-fields"
import { PrintableVoucherSheet } from "@/components/vouchers/printable-voucher-sheet"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { type PaymentInput, type SaleResult, useCustomers, useSellVoucher } from "@/lib/api/hooks"
import { ApiError, errorMessage, newIdempotencyKey } from "@/lib/api/client"
import { useAuth } from "@/lib/auth"
import { useDebounce } from "@/hooks/use-debounce"
import { centsToInput, formatMoney, formatMoneyShort, parseMoneyInput } from "@/lib/money"
import { SALE_CODES, forgetPendingKey, isUncertainOutcome, pendingKey, rememberPendingKey } from "@/lib/outcome"
import { cn } from "@/lib/utils"

const PRESETS = [2500, 5000, 7500, 10000, 15000]

function SaleComplete({ sale, onNext }: { sale: SaleResult; onNext: () => void }) {
  const { user } = useAuth()
  const restaurant = user?.restaurant
  const [printed, setPrinted] = useState(false)
  const printable = sale.printable

  // The QR exists only in this response: warn before the page is left without printing it.
  useEffect(() => {
    if (!printable || printed) return
    const warn = (e: BeforeUnloadEvent) => e.preventDefault()
    window.addEventListener("beforeunload", warn)
    return () => window.removeEventListener("beforeunload", warn)
  }, [printable, printed])

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageHeader
        title={sale.replayed ? "Voucher was already sold" : "Voucher sold"}
        description={`${formatMoney(sale.data.initial_value, sale.data.currency)} · paid by ${sale.payment.method_label.toLowerCase()}`}
      />
      {printable ? (
        <div className="grid gap-6 md:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
          <PrintableVoucherSheet
            qrSvg={printable.qr_svg}
            restaurantName={restaurant?.name ?? ""}
            brandColor={restaurant?.settings.brand_color}
            locale={restaurant?.locale}
            recipientName={sale.data.recipient_name}
            expiresAt={sale.data.expires_at}
            value={sale.data.initial_value}
            currency={sale.data.currency}
          />
          <div className="space-y-4">
            <div className="flex items-start gap-2 rounded-2xl border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-900 dark:border-amber-500/30 dark:bg-amber-500/10 dark:text-amber-200">
              <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
              <span>Print or save the voucher now. For security, the QR code is shown only once and cannot be displayed again.</span>
            </div>
            <Button
              size="lg"
              className="w-full"
              onClick={() => {
                window.print()
                setPrinted(true)
              }}
            >
              <Printer /> Print voucher
            </Button>
            <p className="text-muted-foreground text-xs">To send it by e-mail, choose “Save as PDF” in the print dialog.</p>
            <div className="flex flex-wrap gap-2">
              <Button variant="outline" asChild>
                <Link href={`/vouchers/${sale.data.id}`}>Open voucher</Link>
              </Button>
              <Button variant="outline" onClick={onNext}>
                Sell another
              </Button>
            </div>
          </div>
        </div>
      ) : (
        <Card>
          <CardContent className="space-y-4 pt-6 text-sm">
            <p>
              This sale was completed earlier on this or another device, so its QR code can no longer be shown here. If the guest did not receive a printed
              voucher, block this voucher and sell a new one.
            </p>
            <div className="flex flex-wrap gap-2">
              <Button variant="outline" asChild>
                <Link href={`/vouchers/${sale.data.id}`}>Open voucher</Link>
              </Button>
              <Button variant="outline" onClick={onNext}>
                Sell another
              </Button>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}

function SellVoucherContent() {
  const { user } = useAuth()
  const settings = user?.restaurant?.settings
  const currency = user?.restaurant?.currency ?? "EUR"
  const sell = useSellVoucher()
  const idempotencyKey = useRef(newIdempotencyKey())
  const [sale, setSale] = useState<SaleResult | null>(null)
  const [payment, setPayment] = useState<PaymentInput>({ method: "cash" })
  const [uncertain, setUncertain] = useState(false)
  const [customerMode, setCustomerMode] = useState<"none" | "existing" | "new">("none")
  const [customerSearch, setCustomerSearch] = useState("")
  const customers = useCustomers(useDebounce(customerSearch), 1)
  const min = settings?.min_voucher_value ?? 1
  const max = settings?.max_voucher_balance ?? 100_000_000

  const schema = useMemo(
    () =>
      z.object({
        value: z.string().refine(
          (v) => {
            const cents = parseMoneyInput(v)
            return cents !== null && cents >= min && cents <= max
          },
          `Enter an amount between ${formatMoney(min, currency)} and ${formatMoney(max, currency)}`,
        ),
        customer_id: z.string().optional(),
        first_name: z.string().max(100).optional(),
        last_name: z.string().max(100).optional(),
        email: z.union([z.literal(""), z.string().email("Invalid e-mail")]).optional(),
        phone: z.string().max(40).optional(),
        recipient_name: z.string().max(160).optional(),
        notes: z.string().max(2000).optional(),
      }),
    [min, max, currency],
  )
  type Values = z.infer<typeof schema>

  const form = useForm<Values>({ resolver: zodResolver(schema), defaultValues: { value: centsToInput(5000), email: "" } })
  const valueCents = parseMoneyInput(form.watch("value")) ?? 0
  const { errors, isSubmitting } = form.formState

  // Leaving while the outcome is unknown asks first; the key also survives in this tab for the same sale.
  useEffect(() => {
    if (!uncertain) return
    const warn = (e: BeforeUnloadEvent) => e.preventDefault()
    window.addEventListener("beforeunload", warn)
    return () => window.removeEventListener("beforeunload", warn)
  }, [uncertain])

  const onSubmit = form.handleSubmit(async (v) => {
    if (!paymentComplete(payment)) {
      form.setError("root", { message: "Complete the payment details." })
      return
    }
    const scope = `sale:${parseMoneyInput(v.value) ?? 0}:${payment.method}:${payment.reference ?? ""}`
    const stored = uncertain ? null : pendingKey(scope)
    if (stored) idempotencyKey.current = stored
    const unanswered = uncertain || stored !== null
    try {
      const result = await sell.mutateAsync({
        idempotencyKey: idempotencyKey.current,
        input: {
          value: parseMoneyInput(v.value) ?? 0,
          form: "printable",
          payment,
          customer_id: customerMode === "existing" ? v.customer_id || null : null,
          customer:
            customerMode === "new"
              ? { first_name: v.first_name || undefined, last_name: v.last_name || undefined, email: v.email || undefined, phone: v.phone || undefined }
              : null,
          recipient_name: v.recipient_name || null,
          notes: v.notes || null,
        },
      })
      forgetPendingKey(scope)
      setUncertain(false)
      setSale(result)
      toast.success(result.replayed ? "The sale was already booked" : "Voucher sold")
    } catch (e) {
      if (isUncertainOutcome(e, { unanswered, finalCodes: SALE_CODES })) {
        // The sale may have been booked. Sending the same key again returns it (and a fresh QR) instead of selling twice.
        rememberPendingKey(scope, idempotencyKey.current)
        setUncertain(true)
        form.setError("root", {
          message: "No answer from the server: it is not known whether the voucher was sold. Press “Check sale” — it is never sold twice.",
        })
        return
      }
      forgetPendingKey(scope)
      setUncertain(false)
      if (e instanceof ApiError && e.status === 422 && e.code === "VALIDATION_FAILED") {
        for (const [field, messages] of Object.entries(e.fieldErrors)) {
          const key = field.replace("customer.", "") as keyof Values
          form.setError(key in form.getValues() ? key : "root", { message: messages[0] })
        }
      } else {
        form.setError("root", { message: errorMessage(e) })
      }
      idempotencyKey.current = newIdempotencyKey()
    }
  })

  if (sale) {
    return (
      <SaleComplete
        sale={sale}
        onNext={() => {
          setSale(null)
          setPayment({ method: "cash" })
          idempotencyKey.current = newIdempotencyKey()
          form.reset({ ...form.getValues(), recipient_name: "", notes: "", first_name: "", last_name: "", email: "", phone: "", customer_id: "" })
        }}
      />
    )
  }

  return (
    <form onSubmit={onSubmit} className="mx-auto max-w-3xl space-y-6" noValidate>
      <div className="space-y-2">
        <Button variant="ghost" size="sm" asChild className="-ml-2">
          <Link href="/vouchers">
            <ArrowLeft /> Vouchers
          </Link>
        </Button>
        <PageHeader title="Sell a voucher" description="A printable voucher with a QR code, printed right after the sale." />
      </div>

      <fieldset disabled={uncertain} className="contents">
        <Card>
          <CardHeader>
            <CardTitle>Value</CardTitle>
            <CardDescription>
              Between {formatMoneyShort(min, currency)} and {formatMoneyShort(max, currency)}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex flex-wrap gap-2">
              {PRESETS.filter((p) => p >= min && p <= max).map((p) => (
                <button
                  type="button"
                  key={p}
                  aria-pressed={valueCents === p}
                  onClick={() => form.setValue("value", centsToInput(p), { shouldValidate: true })}
                  className={cn(
                    "tabular hover:bg-muted focus-visible:ring-ring/50 min-h-9 rounded-full border px-4 py-1.5 text-sm font-medium transition outline-none focus-visible:ring-[3px]",
                    valueCents === p && "border-primary bg-primary text-primary-foreground hover:bg-primary",
                  )}
                >
                  {formatMoneyShort(p, currency)}
                </button>
              ))}
            </div>
            <div className="space-y-2 sm:max-w-xs">
              <Label htmlFor="value">Amount</Label>
              <MoneyInput id="value" className="h-11 text-lg" aria-invalid={!!errors.value} {...form.register("value")} />
              {errors.value ? <p className="text-destructive text-xs">{errors.value.message}</p> : null}
            </div>
            <p className="text-muted-foreground text-xs">
              {settings?.validity_months ? `Valid for ${settings.validity_months} months.` : "Valid without an expiry date."}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Payment</CardTitle>
            <CardDescription>How the guest paid. Every sale is recorded with its payment.</CardDescription>
          </CardHeader>
          <CardContent>
            <PaymentFields value={payment} onChange={setPayment} />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Customer</CardTitle>
            <CardDescription>Optional. With an e-mail address the customer receives a receipt with the amount (never the QR code or a link).</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <Segmented
              label="Customer"
              value={customerMode}
              onChange={setCustomerMode}
              className="grid w-full grid-cols-3 sm:inline-flex sm:w-auto"
              options={[
                { value: "none", label: "Anonymous" },
                { value: "existing", label: "Existing" },
                { value: "new", label: "New" },
              ]}
            />
            {customerMode === "existing" ? (
              <div className="space-y-2">
                <Input placeholder="Search customers…" value={customerSearch} onChange={(e) => setCustomerSearch(e.target.value)} />
                <div className="max-h-56 overflow-y-auto rounded-xl border">
                  {customers.data?.data.length ? (
                    customers.data.data.map((c) => (
                      <button
                        type="button"
                        key={c.id}
                        onClick={() => form.setValue("customer_id", c.id)}
                        className={cn(
                          "hover:bg-muted flex w-full items-center justify-between px-3 py-2 text-left text-sm",
                          form.watch("customer_id") === c.id && "bg-muted",
                        )}
                      >
                        <span>
                          <span className="font-medium">{c.full_name}</span>
                          {c.email ? <span className="text-muted-foreground"> · {c.email}</span> : null}
                        </span>
                        {form.watch("customer_id") === c.id ? <Check className="size-4" /> : null}
                      </button>
                    ))
                  ) : (
                    <p className="text-muted-foreground p-4 text-center text-sm">No customers found.</p>
                  )}
                </div>
              </div>
            ) : null}
            {customerMode === "new" ? (
              <div className="grid gap-4 sm:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="first_name">First name</Label>
                  <Input id="first_name" autoComplete="off" {...form.register("first_name")} />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="last_name">Last name</Label>
                  <Input id="last_name" autoComplete="off" {...form.register("last_name")} />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="email">E-mail</Label>
                  <Input id="email" type="email" autoComplete="off" aria-invalid={!!errors.email} {...form.register("email")} />
                  {errors.email ? <p className="text-destructive text-xs">{errors.email.message}</p> : null}
                </div>
                <div className="space-y-2">
                  <Label htmlFor="phone">Phone</Label>
                  <Input id="phone" type="tel" autoComplete="off" {...form.register("phone")} />
                </div>
              </div>
            ) : null}
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="recipient_name">Recipient name (printed on the voucher)</Label>
                <Input id="recipient_name" placeholder="Optional" {...form.register("recipient_name")} />
              </div>
            </div>
            <div className="space-y-2">
              <Label htmlFor="notes">Internal notes</Label>
              <Textarea id="notes" rows={3} placeholder="Visible to staff only" {...form.register("notes")} />
            </div>
          </CardContent>
        </Card>
      </fieldset>

      {errors.root ? (
        <p
          role="alert"
          className={cn(
            "rounded-xl px-4 py-3 text-sm",
            uncertain ? "bg-amber-50 text-amber-900 dark:bg-amber-500/10 dark:text-amber-200" : "bg-destructive/10 text-destructive",
          )}
        >
          {errors.root.message}
        </p>
      ) : null}

      <div className="bg-background/90 sticky bottom-4 flex items-center justify-between gap-4 rounded-2xl border p-3 pl-5 shadow-lg backdrop-blur">
        <span className="text-muted-foreground text-sm">
          Voucher value <span className="text-foreground tabular ml-1 text-base font-semibold">{formatMoney(valueCents, currency)}</span>
        </span>
        <Button type="submit" size="lg" disabled={isSubmitting}>
          {isSubmitting ? <Loader2 className="animate-spin" /> : null} {uncertain ? "Check sale" : "Sell voucher"}
        </Button>
      </div>
    </form>
  )
}

export default function SellVoucherPage() {
  return (
    <RequirePermission permission="vouchers.sell">
      <SellVoucherContent />
    </RequirePermission>
  )
}
