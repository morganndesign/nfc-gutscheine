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
import { useUpdateCardSettings } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { RestaurantSettings } from "@/lib/api/types"
import { centsToInput, parseMoneyInput } from "@/lib/money"

const TOGGLES: { key: keyof RestaurantSettings; label: string; description: string }[] = [
  { key: "allow_reload", label: "Allow reloading", description: "Cards can be topped up with additional value." },
  { key: "allow_partial_redemption", label: "Partial redemption", description: "Guests can spend part of the balance and keep the rest." },
  { key: "public_balance_check", label: "Public balance check", description: "Guests see their balance when they scan their own card." },
  { key: "enforce_nfc_uid_binding", label: "Clone protection", description: "Reject cards whose NFC chip does not match the chip it was written to." },
  { key: "lock_nfc_tags_after_write", label: "Lock tags after writing", description: "Make written NFC tags permanently read-only." },
  { key: "send_customer_emails", label: "Customer e-mails", description: "Send confirmations and reminders to customers with an e-mail address." },
]

const MONEY: { key: keyof RestaurantSettings; label: string; optional?: boolean }[] = [
  { key: "min_card_value", label: "Minimum card value" },
  { key: "max_card_value", label: "Maximum card value" },
  { key: "max_card_balance", label: "Maximum card balance" },
  { key: "max_single_redemption", label: "Maximum single redemption", optional: true },
]

export function CardSettingsForm({ settings }: { settings: RestaurantSettings }) {
  const update = useUpdateCardSettings()
  const [state, setState] = useState<RestaurantSettings>(settings)
  const [money, setMoney] = useState<Record<string, string>>(() =>
    Object.fromEntries(MONEY.map((m) => [m.key, settings[m.key] === null ? "" : centsToInput(settings[m.key] as number)])),
  )

  return (
    <Card>
      <CardHeader>
        <CardTitle>Gift card rules</CardTitle>
        <CardDescription>Limits and policies enforced by the server for every card operation.</CardDescription>
      </CardHeader>
      <form
        className="contents"
        onSubmit={async (e) => {
          e.preventDefault()
          const amounts: Record<string, number | null> = {}
          for (const m of MONEY) {
            const raw = money[m.key] ?? ""
            if (raw === "" && m.optional) {
              amounts[m.key] = null
              continue
            }
            const cents = parseMoneyInput(raw)
            if (cents === null || cents <= 0) {
              toast.error(`${m.label}: enter a valid amount`)
              return
            }
            amounts[m.key] = cents
          }
          try {
            await update.mutateAsync({
              ...amounts,
              default_validity_months: state.default_validity_months,
              max_redemptions_per_card_per_hour: state.max_redemptions_per_card_per_hour,
              card_number_prefix: state.card_number_prefix,
              brand_color: state.brand_color,
              receipt_footer: state.receipt_footer,
              ...Object.fromEntries(TOGGLES.map((t) => [t.key, state[t.key]])),
            })
            toast.success("Card rules saved")
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
                <MoneyInput
                  id={m.key}
                  value={money[m.key]}
                  placeholder={m.optional ? "No limit" : "0,00"}
                  onChange={(e) => setMoney((s) => ({ ...s, [m.key]: e.target.value }))}
                />
              </div>
            ))}
            <div className="space-y-2">
              <Label htmlFor="validity">Default validity (months)</Label>
              <Input
                id="validity"
                type="number"
                min={0}
                max={360}
                value={state.default_validity_months}
                onChange={(e) => setState((s) => ({ ...s, default_validity_months: Number(e.target.value) }))}
              />
              <p className="text-muted-foreground text-xs">0 = no expiry. Check local consumer law before shortening validity.</p>
            </div>
            <div className="space-y-2">
              <Label htmlFor="velocity">Max. redemptions per card per hour</Label>
              <Input
                id="velocity"
                type="number"
                min={0}
                max={1000}
                value={state.max_redemptions_per_card_per_hour}
                onChange={(e) => setState((s) => ({ ...s, max_redemptions_per_card_per_hour: Number(e.target.value) }))}
              />
              <p className="text-muted-foreground text-xs">Fraud protection. 0 disables the limit.</p>
            </div>
            <div className="space-y-2">
              <Label htmlFor="prefix">Card number prefix</Label>
              <Input
                id="prefix"
                inputMode="numeric"
                maxLength={6}
                value={state.card_number_prefix}
                onChange={(e) => setState((s) => ({ ...s, card_number_prefix: e.target.value.replace(/\D/g, "") }))}
                placeholder="None"
              />
              <p className="text-muted-foreground text-xs">Optional digits every new card number starts with.</p>
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
