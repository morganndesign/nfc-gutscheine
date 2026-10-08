"use client"

import { useState } from "react"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useUpdateRestaurantProfile } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { Restaurant } from "@/lib/api/types"
import { useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

// European time zones (the markets GiftCard Pro serves); Intl provides the canonical IANA list.
const TIMEZONES: string[] =
  typeof Intl.supportedValuesOf === "function"
    ? Intl.supportedValuesOf("timeZone").filter((tz) => tz.startsWith("Europe/"))
    : ["Europe/Vienna", "Europe/Berlin", "Europe/Zurich"]

const FIELDS: { key: keyof Restaurant; label: MessageKey; type?: string; span?: boolean }[] = [
  { key: "name", label: "restaurantProfile.name", span: true },
  { key: "legal_name", label: "restaurantProfile.legalName" },
  { key: "vat_number", label: "restaurantProfile.vatNumber" },
  { key: "email", label: "manage.field.email", type: "email" },
  { key: "phone", label: "restaurantProfile.phone", type: "tel" },
  { key: "website", label: "restaurantProfile.website", type: "url", span: true },
  { key: "address_line1", label: "restaurantProfile.street", span: true },
  { key: "postal_code", label: "restaurantProfile.postalCode" },
  { key: "city", label: "restaurantProfile.city" },
]

export function RestaurantProfileForm({ restaurant }: { restaurant: Restaurant }) {
  const t = useT()
  const update = useUpdateRestaurantProfile()
  const [values, setValues] = useState<Record<string, string>>(() =>
    Object.fromEntries([
      ...FIELDS.map((f) => [f.key, (restaurant[f.key] as string | null) ?? ""]),
      ["locale", restaurant.locale],
      ["timezone", restaurant.timezone],
      ["country", restaurant.country],
    ]),
  )

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("restaurantProfile.title")}</CardTitle>
        <CardDescription>{t("restaurantProfile.description")}</CardDescription>
      </CardHeader>
      <form method="post"
        className="contents"
        onSubmit={async (e) => {
          e.preventDefault()
          try {
            const body = Object.fromEntries(Object.entries(values).map(([k, v]) => [k, v === "" ? null : v]))
            await update.mutateAsync(body as Partial<Restaurant>)
            toast.success(t("restaurantProfile.saved"))
          } catch (err) {
            toast.error(errorMessage(err))
          }
        }}
      >
        <CardContent className="grid gap-4 sm:grid-cols-2">
          {FIELDS.map((f) => (
            <div key={f.key} className={f.span ? "space-y-2 sm:col-span-2" : "space-y-2"}>
              <Label htmlFor={f.key}>{t(f.label)}</Label>
              <Input
                id={f.key}
                type={f.type ?? "text"}
                value={values[f.key] ?? ""}
                onChange={(e) => setValues((v) => ({ ...v, [f.key]: e.target.value }))}
                required={f.key === "name"}
              />
            </div>
          ))}
          <div className="space-y-2">
            <Label htmlFor="locale">{t("restaurantProfile.locale")}</Label>
            <Select value={values.locale} onValueChange={(v) => setValues((s) => ({ ...s, locale: v }))}>
              <SelectTrigger id="locale" className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="de-AT">Deutsch (Österreich)</SelectItem>
                <SelectItem value="de-DE">Deutsch (Deutschland)</SelectItem>
                <SelectItem value="de-CH">Deutsch (Schweiz)</SelectItem>
                <SelectItem value="en-GB">English (UK)</SelectItem>
                <SelectItem value="en-US">English (US)</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-2">
            <Label htmlFor="timezone">{t("restaurantProfile.timezone")}</Label>
            <Select value={values.timezone} onValueChange={(v) => setValues((s) => ({ ...s, timezone: v }))}>
              <SelectTrigger id="timezone" className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {TIMEZONES.map((tz) => (
                  <SelectItem key={tz} value={tz}>
                    {tz.replace("_", " ")}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardContent>
        <CardFooter className="justify-end">
          <Button type="submit" disabled={update.isPending}>
            {update.isPending ? <Loader2 className="animate-spin" /> : null} {t("common.save")}
          </Button>
        </CardFooter>
      </form>
    </Card>
  )
}
