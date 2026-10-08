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
import { PAYMENT_METHOD_LABELS, PaymentFields, paymentComplete } from "@/components/vouchers/payment-fields"
import { PrintableVoucherSheet, useVoucherLook } from "@/components/vouchers/printable-voucher-sheet"
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
import { useT } from "@/lib/i18n"
import { cn } from "@/lib/utils"

const PRESETS = [2500, 5000, 7500, 10000, 15000]

function SaleComplete({ sale, onNext }: { sale: SaleResult; onNext: () => void }) {
  const t = useT()
  const [printed, setPrinted] = useState(false)
  const { ready } = useVoucherLook()
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
        title={sale.replayed ? t("vouchers.sale.alreadySold") : t("vouchers.sale.sold")}
        description={t("vouchers.sale.summary", {
          amount: formatMoney(sale.data.initial_value, sale.data.currency),
          method: t(PAYMENT_METHOD_LABELS[sale.payment.method]),
        })}
      />
      {printable ? (
        <div className="grid gap-6 md:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
          <PrintableVoucherSheet
            qrSvg={printable.qr_svg}
            recipientName={sale.data.recipient_name}
            giftMessage={sale.data.gift_message}
            expiresAt={sale.data.expires_at}
            value={sale.data.initial_value}
            currency={sale.data.currency}
          />
          <div className="space-y-4">
            <div className="flex items-start gap-2 rounded-2xl border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-900 dark:border-amber-500/30 dark:bg-amber-500/10 dark:text-amber-200">
              <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
              <span>{t("vouchers.sale.printWarning")}</span>
            </div>
            <Button
              size="lg"
              className="w-full"
              disabled={!ready}
              onClick={() => {
                window.print()
                setPrinted(true)
              }}
            >
              <Printer /> {t("vouchers.printVoucher")}
            </Button>
            <p className="text-muted-foreground text-xs">{t("vouchers.pdfHint")}</p>
            <div className="flex flex-wrap gap-2">
              <Button variant="outline" asChild>
                <Link href={`/vouchers/${sale.data.id}`}>{t("vouchers.openVoucher")}</Link>
              </Button>
              <Button variant="outline" onClick={onNext}>
                {t("vouchers.sale.sellAnother")}
              </Button>
            </div>
          </div>
        </div>
      ) : (
        <Card>
          <CardContent className="space-y-4 pt-6 text-sm">
            <p>{t("vouchers.sale.replayedBody")}</p>
            <div className="flex flex-wrap gap-2">
              <Button variant="outline" asChild>
                <Link href={`/vouchers/${sale.data.id}`}>{t("vouchers.openVoucher")}</Link>
              </Button>
              <Button variant="outline" onClick={onNext}>
                {t("vouchers.sale.sellAnother")}
              </Button>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}

function SellVoucherContent() {
  const { user, refresh } = useAuth()
  const t = useT()
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
          t("vouchers.sale.amountRange", { min: formatMoney(min, currency), max: formatMoney(max, currency) }),
        ),
        customer_id: z.string().optional(),
        first_name: z.string().max(100).optional(),
        last_name: z.string().max(100).optional(),
        email: z.union([z.literal(""), z.string().email(t("vouchers.sale.invalidEmail"))]).optional(),
        phone: z.string().max(40).optional(),
        recipient_name: z.string().max(160).optional(),
        gift_message: z.string().max(300).optional(),
        notes: z.string().max(2000).optional(),
      }),
    [min, max, currency, t],
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
      form.setError("root", { message: t("vouchers.sale.completePayment") })
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
          gift_message: v.gift_message?.trim() || null,
          notes: v.notes || null,
        },
      })
      forgetPendingKey(scope)
      setUncertain(false)
      setSale(result)
      toast.success(result.replayed ? t("vouchers.sale.replayedToast") : t("vouchers.sale.sold"))
    } catch (e) {
      // The owner took the loyalty right back meanwhile: the payment choices follow at once (audit L4).
      if (e instanceof ApiError && e.code === "COMPLIMENTARY_NOT_ALLOWED") void refresh()
      if (isUncertainOutcome(e, { unanswered, finalCodes: SALE_CODES })) {
        // The sale may have been booked. Sending the same key again returns it (and a fresh QR) instead of selling twice.
        rememberPendingKey(scope, idempotencyKey.current)
        setUncertain(true)
        form.setError("root", {
          message: t("vouchers.sale.uncertain"),
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
          form.reset({
            ...form.getValues(),
            recipient_name: "",
            gift_message: "",
            notes: "",
            first_name: "",
            last_name: "",
            email: "",
            phone: "",
            customer_id: "",
          })
        }}
      />
    )
  }

  return (
    <form method="post" onSubmit={onSubmit} className="mx-auto max-w-3xl space-y-6" noValidate>
      <div className="space-y-2">
        <Button variant="ghost" size="sm" asChild className="-ml-2">
          <Link href="/vouchers">
            <ArrowLeft /> {t("vouchers.title")}
          </Link>
        </Button>
        <PageHeader title={t("vouchers.sale.title")} description={t("vouchers.sale.description")} />
      </div>

      <fieldset disabled={uncertain} className="contents">
        <Card>
          <CardHeader>
            <CardTitle>{t("vouchers.sale.value")}</CardTitle>
            <CardDescription>{t("vouchers.sale.between", { min: formatMoneyShort(min, currency), max: formatMoneyShort(max, currency) })}</CardDescription>
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
              <Label htmlFor="value">{t("vouchers.field.amount")}</Label>
              <MoneyInput id="value" className="h-11 text-lg" aria-invalid={!!errors.value} {...form.register("value")} />
              {errors.value ? <p className="text-destructive text-xs">{errors.value.message}</p> : null}
            </div>
            <p className="text-muted-foreground text-xs">
              {settings?.validity_months ? t("vouchers.sale.validFor", { months: settings.validity_months }) : t("vouchers.sale.noExpiryHint")}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t("payment.label")}</CardTitle>
            <CardDescription>{t("vouchers.sale.paymentDescription")}</CardDescription>
          </CardHeader>
          <CardContent>
            <PaymentFields value={payment} onChange={setPayment} />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t("vouchers.col.customer")}</CardTitle>
            {/* The PDF goes out only when guest e-mails are on (audit T3). */}
            <CardDescription>{t(settings?.send_customer_emails === false ? "vouchers.sale.customerDescriptionNoMail" : "vouchers.sale.customerDescription")}</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <Segmented
              label={t("vouchers.col.customer")}
              value={customerMode}
              onChange={setCustomerMode}
              className="grid w-full grid-cols-3 sm:inline-flex sm:w-auto"
              options={[
                { value: "none", label: t("vouchers.anonymous") },
                { value: "existing", label: t("vouchers.sale.customerExisting") },
                { value: "new", label: t("vouchers.sale.customerNew") },
              ]}
            />
            {customerMode === "existing" ? (
              <div className="space-y-2">
                <Input placeholder={t("vouchers.sale.searchCustomers")} value={customerSearch} onChange={(e) => setCustomerSearch(e.target.value)} />
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
                    <p className="text-muted-foreground p-4 text-center text-sm">{t("vouchers.sale.noCustomers")}</p>
                  )}
                </div>
              </div>
            ) : null}
            {customerMode === "new" ? (
              <div className="grid gap-4 sm:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="first_name">{t("vouchers.sale.firstName")}</Label>
                  <Input id="first_name" autoComplete="off" {...form.register("first_name")} />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="last_name">{t("vouchers.sale.lastName")}</Label>
                  <Input id="last_name" autoComplete="off" {...form.register("last_name")} />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="email">{t("vouchers.sale.email")}</Label>
                  <Input id="email" type="email" autoComplete="off" aria-invalid={!!errors.email} {...form.register("email")} />
                  {errors.email ? <p className="text-destructive text-xs">{errors.email.message}</p> : null}
                </div>
                <div className="space-y-2">
                  <Label htmlFor="phone">{t("vouchers.sale.phone")}</Label>
                  <Input id="phone" type="tel" autoComplete="off" {...form.register("phone")} />
                </div>
              </div>
            ) : null}
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="recipient_name">{t("vouchers.sale.recipientPrinted")}</Label>
                <Input id="recipient_name" placeholder={t("vouchers.sale.optional")} maxLength={160} {...form.register("recipient_name")} />
              </div>
            </div>
            <div className="space-y-2">
              <Label htmlFor="gift_message">{t("vouchers.sale.giftMessage")}</Label>
              <Textarea
                id="gift_message"
                rows={3}
                maxLength={300}
                placeholder={t("vouchers.sale.giftMessagePlaceholder")}
                aria-describedby="gift_message_hint"
                {...form.register("gift_message")}
              />
              <p id="gift_message_hint" className="text-muted-foreground text-xs">
                {t("vouchers.sale.giftMessageHint")}
              </p>
            </div>
            <div className="space-y-2">
              <Label htmlFor="notes">{t("vouchers.field.notes")}</Label>
              <Textarea id="notes" rows={3} placeholder={t("vouchers.sale.notesPlaceholder")} {...form.register("notes")} />
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
          {t("vouchers.sale.voucherValue")} <span className="text-foreground tabular ml-1 text-base font-semibold">{formatMoney(valueCents, currency)}</span>
        </span>
        <Button type="submit" size="lg" disabled={isSubmitting}>
          {isSubmitting ? <Loader2 className="animate-spin" /> : null} {uncertain ? t("vouchers.sale.check") : t("vouchers.sell")}
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
