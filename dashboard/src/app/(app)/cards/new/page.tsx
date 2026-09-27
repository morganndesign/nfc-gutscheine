"use client"

import { useMemo, useRef, useState } from "react"
import Link from "next/link"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { ArrowLeft, Check, Loader2, Printer } from "lucide-react"
import { toast } from "sonner"
import { PageHeader } from "@/components/common/page-header"
import { MoneyInput } from "@/components/common/money-input"
import { CardVisual } from "@/components/cards/card-visual"
import { NfcWriter } from "@/components/cards/nfc-writer"
import { RequirePermission } from "@/components/layout/auth-guard"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"
import { Segmented } from "@/components/common/segmented"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useCreateCard, useCustomers } from "@/lib/api/hooks"
import { ApiError, errorMessage, newIdempotencyKey } from "@/lib/api/client"
import type { GiftCard, NfcPayload, NfcTagType } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { useDebounce } from "@/hooks/use-debounce"
import { centsToInput, formatMoney, formatMoneyShort, parseMoneyInput } from "@/lib/money"
import { TAG_TYPES } from "@/lib/nfc"
import { cn } from "@/lib/utils"
import { todayInput } from "@/lib/format"

const PRESETS = [2500, 5000, 7500, 10000, 15000]

/** Today + N months in the restaurant's timezone, clamped to the month's last day (like the server). */
function defaultExpiry(months: number): string {
  if (!months) return ""
  const [y, m, d] = todayInput().split("-").map(Number)
  const target = new Date(Date.UTC(y, m - 1 + months, 1))
  const lastDay = new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0)).getUTCDate()
  target.setUTCDate(Math.min(d, lastDay))
  return target.toISOString().slice(0, 10)
}

function NewCardContent() {
  const { user } = useAuth()
  const settings = user?.restaurant?.settings
  const currency = user?.restaurant?.currency ?? "EUR"
  const create = useCreateCard()
  const idempotencyKey = useRef(newIdempotencyKey())
  const [created, setCreated] = useState<{ card: GiftCard; nfc: NfcPayload } | null>(null)
  const [customerMode, setCustomerMode] = useState<"none" | "existing" | "new">("none")
  const [customerSearch, setCustomerSearch] = useState("")
  const customers = useCustomers(useDebounce(customerSearch), 1)

  const schema = useMemo(
    () =>
      z.object({
        value: z.string().refine(
          (v) => {
            const cents = parseMoneyInput(v)
            return cents !== null && cents >= (settings?.min_card_value ?? 1) && cents <= (settings?.max_card_value ?? 100_000_000)
          },
          `Enter an amount between ${formatMoney(settings?.min_card_value ?? 0, currency)} and ${formatMoney(settings?.max_card_value ?? 0, currency)}`,
        ),
        expires_at: z.string().optional(),
        customer_id: z.string().optional(),
        first_name: z.string().max(100).optional(),
        last_name: z.string().max(100).optional(),
        email: z.union([z.literal(""), z.string().email("Invalid e-mail")]).optional(),
        phone: z.string().max(40).optional(),
        recipient_name: z.string().max(160).optional(),
        notes: z.string().max(2000).optional(),
        activate: z.boolean(),
        nfc_tag_type: z.string(),
      }),
    [settings, currency],
  )
  type Values = z.infer<typeof schema>

  const form = useForm<Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      value: centsToInput(5000),
      expires_at: defaultExpiry(settings?.default_validity_months ?? 36),
      activate: true,
      nfc_tag_type: "ntag215",
      email: "",
    },
  })
  const valueCents = parseMoneyInput(form.watch("value")) ?? 0
  const { errors, isSubmitting } = form.formState

  const onSubmit = form.handleSubmit(async (v) => {
    try {
      const result = await create.mutateAsync({
        idempotencyKey: idempotencyKey.current,
        input: {
          value: parseMoneyInput(v.value) ?? 0,
          expires_at: v.expires_at || null,
          customer_id: customerMode === "existing" ? v.customer_id || null : null,
          customer:
            customerMode === "new"
              ? { first_name: v.first_name || undefined, last_name: v.last_name || undefined, email: v.email || undefined, phone: v.phone || undefined }
              : null,
          recipient_name: v.recipient_name || null,
          notes: v.notes || null,
          activate: v.activate,
          nfc_tag_type: v.nfc_tag_type as NfcTagType,
        },
      })
      setCreated({ card: result.data, nfc: { ...result.nfc, lock_after_write: settings?.lock_nfc_tags_after_write } })
      toast.success("Gift card created")
    } catch (e) {
      if (e instanceof ApiError && e.status === 422 && e.code === "VALIDATION_FAILED") {
        for (const [field, messages] of Object.entries(e.fieldErrors)) {
          const key = field.replace("customer.", "") as keyof Values
          form.setError(key in form.getValues() ? key : "root", { message: messages[0] })
        }
      } else {
        form.setError("root", { message: errorMessage(e) })
      }
      // Rejected requests created nothing: use a fresh key. Network errors keep the key so a retry is idempotent.
      if (e instanceof ApiError && e.status < 500) idempotencyKey.current = newIdempotencyKey()
    }
  })

  if (created) {
    return (
      <div className="mx-auto max-w-3xl space-y-6">
        <PageHeader title="Card created" description="Write the card to an NFC tag or print it." />
        <div className="grid gap-6 md:grid-cols-[minmax(0,1fr)_minmax(0,1.3fr)]">
          <div className="space-y-4">
            <CardVisual
              restaurantName={user?.restaurant?.name ?? ""}
              cardNumber={created.card.card_number_formatted}
              balance={created.card.balance}
              currency={created.card.currency}
              expiresAt={created.card.expires_at}
              status={created.card.status}
              brandColor={settings?.brand_color}
            />
            <div className="flex flex-wrap gap-2">
              <Button variant="outline" asChild>
                <Link href={`/cards/${created.card.id}`}>Open card</Link>
              </Button>
              <Button variant="outline" asChild>
                <Link href={`/print/cards/${created.card.id}`} target="_blank">
                  <Printer /> Print
                </Link>
              </Button>
              <Button
                onClick={() => {
                  setCreated(null)
                  idempotencyKey.current = newIdempotencyKey()
                  form.reset({ ...form.getValues(), recipient_name: "", notes: "", first_name: "", last_name: "", email: "", phone: "", customer_id: "" })
                }}
              >
                Create another
              </Button>
            </div>
          </div>
          <Card>
            <CardHeader>
              <CardTitle>Program the card</CardTitle>
              <CardDescription>The tag stores only a secure link. Balance and customer data stay on the server.</CardDescription>
            </CardHeader>
            <CardContent>
              <NfcWriter cardId={created.card.id} payload={created.nfc} />
            </CardContent>
          </Card>
        </div>
      </div>
    )
  }

  return (
    <form onSubmit={onSubmit} className="mx-auto max-w-3xl space-y-6" noValidate>
      <div className="space-y-2">
        <Button variant="ghost" size="sm" asChild className="-ml-2">
          <Link href="/cards">
            <ArrowLeft /> Gift cards
          </Link>
        </Button>
        <PageHeader title="New gift card" description="Issue a card and load its initial value." />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Value</CardTitle>
          <CardDescription>
            Between {formatMoneyShort(settings?.min_card_value, currency)} and {formatMoneyShort(settings?.max_card_value, currency)}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex flex-wrap gap-2">
            {PRESETS.filter((p) => p >= (settings?.min_card_value ?? 0) && p <= (settings?.max_card_value ?? Infinity)).map((p) => (
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
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="value">Amount</Label>
              <MoneyInput id="value" className="h-11 text-lg" aria-invalid={!!errors.value} {...form.register("value")} />
              {errors.value ? <p className="text-destructive text-xs">{errors.value.message}</p> : null}
            </div>
            <div className="space-y-2">
              <Label htmlFor="expires_at">Valid until</Label>
              <Input id="expires_at" type="date" className="h-11" min={todayInput(1)} {...form.register("expires_at")} />
              {errors.expires_at ? (
                <p className="text-destructive text-xs">{errors.expires_at.message}</p>
              ) : (
                <p className="text-muted-foreground text-xs">Leave empty for no expiry.</p>
              )}
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Customer</CardTitle>
          <CardDescription>Optional. With an e-mail address the customer receives the card confirmation.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <Segmented
            label="Customer"
            value={customerMode}
            onChange={setCustomerMode}
            className="grid w-full grid-cols-3 sm:inline-flex sm:w-auto"
            options={[
              { value: "none", label: "Anonymous" },
              {
                value: "existing",
                label: (
                  <>
                    Existing<span className="hidden sm:inline">&nbsp;customer</span>
                  </>
                ),
              },
              {
                value: "new",
                label: (
                  <>
                    New<span className="hidden sm:inline">&nbsp;customer</span>
                  </>
                ),
              },
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
              <Label htmlFor="recipient_name">Recipient name (printed on the card)</Label>
              <Input id="recipient_name" placeholder="Optional" {...form.register("recipient_name")} />
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Card</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="nfc_tag_type">Card type</Label>
              <Select value={form.watch("nfc_tag_type")} onValueChange={(v) => form.setValue("nfc_tag_type", v)}>
                <SelectTrigger id="nfc_tag_type" className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {TAG_TYPES.map((t) => (
                    <SelectItem key={t.value} value={t.value}>
                      {t.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <label className="flex items-center justify-between gap-3 rounded-xl border p-3 text-sm">
              <span>
                <span className="font-medium">Activate immediately</span>
                <span className="text-muted-foreground block text-xs">Off: card can be redeemed only after activation</span>
              </span>
              <Switch checked={form.watch("activate")} onCheckedChange={(v) => form.setValue("activate", v)} />
            </label>
          </div>
          <div className="space-y-2">
            <Label htmlFor="notes">Internal notes</Label>
            <Textarea id="notes" rows={3} placeholder="Visible to staff only" {...form.register("notes")} />
          </div>
        </CardContent>
      </Card>

      {errors.root ? (
        <p role="alert" className="bg-destructive/10 text-destructive rounded-xl px-4 py-3 text-sm">
          {errors.root.message}
        </p>
      ) : null}

      <div className="bg-background/90 sticky bottom-4 flex items-center justify-between gap-4 rounded-2xl border p-3 pl-5 shadow-lg backdrop-blur">
        <span className="text-muted-foreground text-sm">
          Card value <span className="text-foreground tabular ml-1 text-base font-semibold">{formatMoney(valueCents, currency)}</span>
        </span>
        <Button type="submit" size="lg" disabled={isSubmitting}>
          {isSubmitting ? <Loader2 className="animate-spin" /> : null} Create card
        </Button>
      </div>
    </form>
  )
}

export default function NewCardPage() {
  return (
    <RequirePermission permission="cards.create">
      <NewCardContent />
    </RequirePermission>
  )
}
