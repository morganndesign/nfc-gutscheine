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
import { useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

type EditableSettings = Omit<RestaurantSettings, "platform_limits">
type MoneyKey = "min_voucher_value" | "max_voucher_balance" | "max_debit_per_transaction" | "max_debit_per_voucher_per_day"

const TOGGLES: { key: "allow_reload" | "allow_partial_redemption" | "send_customer_emails" | "public_balance"; label: MessageKey; description: MessageKey }[] =
  [
    { key: "allow_reload", label: "voucherRules.allowReload", description: "voucherRules.allowReloadHint" },
    { key: "allow_partial_redemption", label: "voucherRules.partial", description: "voucherRules.partialHint" },
    { key: "send_customer_emails", label: "voucherRules.customerEmails", description: "voucherRules.customerEmailsHint" },
    { key: "public_balance", label: "voucherRules.publicBalance", description: "voucherRules.publicBalanceHint" },
  ]

const MONEY: { key: MoneyKey; label: MessageKey; hint: MessageKey; ceiling?: keyof RestaurantSettings["platform_limits"] }[] = [
  { key: "min_voucher_value", label: "voucherRules.minValue", hint: "voucherRules.minValueHint" },
  { key: "max_voucher_balance", label: "voucherRules.maxBalance", hint: "voucherRules.maxBalanceHint", ceiling: "max_voucher_balance" },
  { key: "max_debit_per_transaction", label: "voucherRules.maxPerRedemption", hint: "voucherRules.maxPerRedemptionHint", ceiling: "max_debit_per_transaction" },
  { key: "max_debit_per_voucher_per_day", label: "voucherRules.maxPerDay", hint: "voucherRules.maxPerDayHint", ceiling: "max_debit_per_voucher_per_day" },
]

export function VoucherSettingsForm({ settings }: { settings: RestaurantSettings }) {
  const t = useT()
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
        <CardTitle>{t("voucherRules.title")}</CardTitle>
        <CardDescription>{t("voucherRules.description")}</CardDescription>
      </CardHeader>
      <form method="post"
        className="contents"
        onSubmit={async (e) => {
          e.preventDefault()
          const amounts = {} as Record<MoneyKey, number>
          for (const m of MONEY) {
            const cents = parseMoneyInput(money[m.key] ?? "")
            if (cents === null || cents <= 0) {
              toast.error(t("voucherRules.invalidAmount", { field: t(m.label) }))
              return
            }
            amounts[m.key] = cents
          }
          try {
            await update.mutateAsync({
              ...amounts,
              validity_months: limitedValidity ? state.validity_months : null,
              max_redemptions_per_voucher_per_hour: state.max_redemptions_per_voucher_per_hour,
              receipt_footer: state.receipt_footer,
              ...Object.fromEntries(TOGGLES.map((toggle) => [toggle.key, state[toggle.key]])),
            })
            toast.success(t("voucherRules.saved"))
          } catch (err) {
            toast.error(errorMessage(err))
          }
        }}
      >
        <CardContent className="space-y-6">
          <div className="grid gap-4 sm:grid-cols-2">
            {MONEY.map((m) => (
              <div key={m.key} className="space-y-2">
                <Label htmlFor={m.key}>{t(m.label)}</Label>
                <MoneyInput id={m.key} value={money[m.key]} onChange={(e) => setMoney((s) => ({ ...s, [m.key]: e.target.value }))} />
                <p className="text-muted-foreground text-xs">
                  {t(m.hint)}
                  {m.ceiling ? ` ${t("voucherRules.platformMax", { amount: formatMoney(limits[m.ceiling], currency) })}` : ""}
                </p>
              </div>
            ))}
            <div className="space-y-2">
              <Label htmlFor="velocity">{t("voucherRules.velocity")}</Label>
              <Input
                id="velocity"
                type="number"
                min={0}
                max={1000}
                value={state.max_redemptions_per_voucher_per_hour}
                onChange={(e) => setState((s) => ({ ...s, max_redemptions_per_voucher_per_hour: Number(e.target.value) }))}
              />
              <p className="text-muted-foreground text-xs">{t("voucherRules.velocityHint")}</p>
            </div>
            <div className="space-y-2">
              <Label htmlFor="validity">{t("voucherRules.validity")}</Label>
              <label className="flex items-center gap-2 text-sm">
                <Switch
                  checked={limitedValidity}
                  onCheckedChange={(v) => {
                    setLimitedValidity(v)
                    if (v && state.validity_months === null) setState((s) => ({ ...s, validity_months: limits.min_validity_months }))
                  }}
                />
                {t("voucherRules.limitValidity")}
              </label>
              {limitedValidity ? (
                <Input
                  id="validity"
                  type="number"
                  aria-label={t("voucherRules.validityMonths")}
                  min={limits.min_validity_months}
                  max={360}
                  value={state.validity_months ?? limits.min_validity_months}
                  onChange={(e) => setState((s) => ({ ...s, validity_months: Number(e.target.value) }))}
                />
              ) : null}
              <p className="text-muted-foreground text-xs">{t("voucherRules.validityHint", { years: limits.min_validity_months / 12 })}</p>
            </div>
          </div>
          <div className="divide-y rounded-2xl border">
            {TOGGLES.map((toggle) => (
              <label key={toggle.key} className="flex items-center justify-between gap-4 p-4">
                <span className="text-sm">
                  <span className="font-medium">{t(toggle.label)}</span>
                  <span className="text-muted-foreground block">{t(toggle.description)}</span>
                </span>
                <Switch checked={Boolean(state[toggle.key])} onCheckedChange={(v) => setState((s) => ({ ...s, [toggle.key]: v }))} />
              </label>
            ))}
          </div>
          <div className="space-y-2">
            <Label htmlFor="footer">{t("voucherRules.footer")}</Label>
            <Textarea
              id="footer"
              rows={2}
              maxLength={500}
              value={state.receipt_footer ?? ""}
              onChange={(e) => setState((s) => ({ ...s, receipt_footer: e.target.value || null }))}
              placeholder={t("voucherRules.footerPlaceholder")}
            />
          </div>
        </CardContent>
        <CardFooter className="justify-end">
          <Button type="submit" disabled={update.isPending}>
            {update.isPending ? <Loader2 className="animate-spin" /> : null} {t("voucherRules.save")}
          </Button>
        </CardFooter>
      </form>
    </Card>
  )
}
