"use client"

import { useState } from "react"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { MoneyInput } from "@/components/common/money-input"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"
import { Textarea } from "@/components/ui/textarea"
import { useUpdateVoucherSettings } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import { useAuth } from "@/lib/auth"
import type { RestaurantSettings } from "@/lib/api/types"
import { centsToInput, formatMoney, parseMoneyInput } from "@/lib/money"

type EditableSettings = Omit<RestaurantSettings, "platform_limits">
type MoneyKey = "min_voucher_value" | "max_voucher_balance" | "max_debit_per_transaction" | "max_debit_per_voucher_per_day"

const TOGGLES: { key: "allow_reload" | "allow_partial_redemption" | "send_customer_emails"; label: string; description: string }[] = [
  { key: "allow_reload", label: "Allow reloading", description: "Vouchers can be topped up with additional value (always with a payment)." },
  { key: "allow_partial_redemption", label: "Partial redemption", description: "Guests can spend part of the balance and keep the rest." },
  {
    key: "send_customer_emails",
    label: "Customer e-mails",
    description: "Confirmations and reminders to registered customers. They never contain an amount or a link.",
  },
]

const MONEY: { key: MoneyKey; label: string; hint: string; ceiling?: keyof RestaurantSettings["platform_limits"] }[] = [
  { key: "min_voucher_value", label: "Minimum voucher value", hint: "Smallest value that can be sold." },
  { key: "max_voucher_balance", label: "Maximum voucher balance", hint: "Applies to sales, reloads and corrections.", ceiling: "max_voucher_balance" },
  { key: "max_debit_per_transaction", label: "Maximum per redemption", hint: "Every single payment with a voucher.", ceiling: "max_debit_per_transaction" },
  {
    key: "max_debit_per_voucher_per_day",
    label: "Maximum per voucher and day",
    hint: "Sum of all payments of one voucher on one day.",
    ceiling: "max_debit_per_voucher_per_day",
  },
]

export function VoucherSettingsForm({ settings }: { settings: RestaurantSettings }) {
  const update = useUpdateVoucherSettings()
  const currency = useAuth().user?.restaurant?.currency ?? "EUR"
  const limits = settings.platform_limits
  const [state, setState] = useState<EditableSettings>(settings)
  const [limitedValidity, setLimitedValidity] = useState(settings.validity_months !== null)
  const [money, setMoney] = useState<Record<MoneyKey, string>>(
    () => Object.fromEntries(MONEY.map((m) => [m.key, centsToInput(settings[m.key])])) as Record<MoneyKey, string>,
  )

  return (
    <Card>
      <CardHeader>
        <CardTitle>Voucher rules</CardTitle>
        <CardDescription>Limits and policies enforced by the server for every sale, reload and redemption.</CardDescription>
      </CardHeader>
      <form
        className="contents"
        onSubmit={async (e) => {
          e.preventDefault()
          const amounts = {} as Record<MoneyKey, number>
          for (const m of MONEY) {
            const cents = parseMoneyInput(money[m.key] ?? "")
            if (cents === null || cents <= 0) {
              toast.error(`${m.label}: enter a valid amount`)
              return
            }
            amounts[m.key] = cents
          }
          try {
            await update.mutateAsync({
              ...amounts,
              validity_months: limitedValidity ? state.validity_months : null,
              max_redemptions_per_voucher_per_hour: state.max_redemptions_per_voucher_per_hour,
              brand_color: state.brand_color,
              receipt_footer: state.receipt_footer,
              ...Object.fromEntries(TOGGLES.map((t) => [t.key, state[t.key]])),
            })
            toast.success("Voucher rules saved")
          } catch (err) {
            toast.error(errorMessage(err))
          }
        }}
      >
        <CardContent className="space-y-6">
          <div className="grid gap-4 sm:grid-cols-2">
            {MONEY.map((m) => (
              <div key={m.key} className="space-y-2">
                <Label htmlFor={m.key}>{m.label}</Label>
                <MoneyInput id={m.key} value={money[m.key]} onChange={(e) => setMoney((s) => ({ ...s, [m.key]: e.target.value }))} />
                <p className="text-muted-foreground text-xs">
                  {m.hint}
                  {m.ceiling ? ` Platform maximum ${formatMoney(limits[m.ceiling], currency)}.` : ""}
                </p>
              </div>
            ))}
            <div className="space-y-2">
              <Label htmlFor="velocity">Max. redemptions per voucher per hour</Label>
              <Input
                id="velocity"
                type="number"
                min={0}
                max={1000}
                value={state.max_redemptions_per_voucher_per_hour}
                onChange={(e) => setState((s) => ({ ...s, max_redemptions_per_voucher_per_hour: Number(e.target.value) }))}
              />
              <p className="text-muted-foreground text-xs">Fraud protection. 0 disables the limit.</p>
            </div>
            <div className="space-y-2">
              <Label htmlFor="validity">Validity</Label>
              <label className="flex items-center gap-2 text-sm">
                <Switch
                  checked={limitedValidity}
                  onCheckedChange={(v) => {
                    setLimitedValidity(v)
                    if (v && state.validity_months === null) setState((s) => ({ ...s, validity_months: limits.min_validity_months }))
                  }}
                />
                Limit the validity of new vouchers
              </label>
              {limitedValidity ? (
                <Input
                  id="validity"
                  type="number"
                  min={limits.min_validity_months}
                  max={360}
                  value={state.validity_months ?? limits.min_validity_months}
                  onChange={(e) => setState((s) => ({ ...s, validity_months: Number(e.target.value) }))}
                />
              ) : null}
              <p className="text-muted-foreground text-xs">
                Recommended: no expiry. In Austria paid vouchers are valid for 30 years unless validly limited, and limits under{" "}
                {limits.min_validity_months / 12} years are not admissible. An expired voucher keeps its balance and can be reinstated.
              </p>
            </div>
            <div className="space-y-2">
              <Label htmlFor="brand">Brand color</Label>
              <div className="flex gap-2">
                <input
                  type="color"
                  aria-label="Pick brand color"
                  value={state.brand_color}
                  onChange={(e) => setState((s) => ({ ...s, brand_color: e.target.value.toUpperCase() }))}
                  className="h-9 w-12 cursor-pointer rounded-lg border bg-transparent p-1"
                />
                <Input id="brand" value={state.brand_color} onChange={(e) => setState((s) => ({ ...s, brand_color: e.target.value }))} className="font-mono" />
              </div>
            </div>
          </div>
          <div className="divide-y rounded-2xl border">
            {TOGGLES.map((t) => (
              <label key={t.key} className="flex items-center justify-between gap-4 p-4">
                <span className="text-sm">
                  <span className="font-medium">{t.label}</span>
                  <span className="text-muted-foreground block">{t.description}</span>
                </span>
                <Switch checked={Boolean(state[t.key])} onCheckedChange={(v) => setState((s) => ({ ...s, [t.key]: v }))} />
              </label>
            ))}
          </div>
          <div className="space-y-2">
            <Label htmlFor="footer">E-mail footer</Label>
            <Textarea
              id="footer"
              rows={2}
              maxLength={500}
              value={state.receipt_footer ?? ""}
              onChange={(e) => setState((s) => ({ ...s, receipt_footer: e.target.value || null }))}
              placeholder="e.g. company register, address, terms"
            />
          </div>
        </CardContent>
        <CardFooter className="justify-end">
          <Button type="submit" disabled={update.isPending}>
            {update.isPending ? <Loader2 className="animate-spin" /> : null} Save rules
          </Button>
        </CardFooter>
      </form>
    </Card>
  )
}
