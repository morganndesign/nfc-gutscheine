"use client"

import { useEffect } from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"
import { Textarea } from "@/components/ui/textarea"
import { useSaveCustomer } from "@/lib/api/hooks"
import { ApiError, errorMessage } from "@/lib/api/client"
import type { Customer } from "@/lib/api/types"
import { useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"

// Messages are translation keys, translated when shown (server validation messages pass through unchanged).
const TOO_LONG: MessageKey = "customerDialog.tooLong"
const schema = z
  .object({
    first_name: z.string().max(100, TOO_LONG),
    last_name: z.string().max(100, TOO_LONG),
    email: z.union([z.literal(""), z.string().email("customerDialog.invalidEmail" satisfies MessageKey)]),
    phone: z
      .string()
      .max(40, TOO_LONG)
      .regex(/^[0-9+\-\s()/]*$/, "customerDialog.invalidPhone" satisfies MessageKey),
    notes: z.string().max(2000, TOO_LONG),
    marketing_consent: z.boolean(),
  })
  .refine((v) => v.first_name || v.last_name || v.email || v.phone, {
    message: "customerDialog.required" satisfies MessageKey,
    path: ["first_name"],
  })
type Values = z.infer<typeof schema>

export function CustomerDialog({ customer, open, onOpenChange }: { customer?: Customer; open: boolean; onOpenChange: (o: boolean) => void }) {
  const save = useSaveCustomer(customer?.id)
  const form = useForm<Values>({ resolver: zodResolver(schema) })
  const t = useT()
  const msg = (message?: string) => (message ? t(message as MessageKey) : null)

  useEffect(() => {
    if (open) {
      form.reset({
        first_name: customer?.first_name ?? "",
        last_name: customer?.last_name ?? "",
        email: customer?.email ?? "",
        phone: customer?.phone ?? "",
        notes: customer?.notes ?? "",
        marketing_consent: customer?.marketing_consent ?? false,
      })
    }
  }, [open, customer, form])

  const { errors } = form.formState

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{customer ? t("customerDialog.editTitle") : t("customers.new")}</DialogTitle>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={form.handleSubmit(async (v) => {
            try {
              await save.mutateAsync({ ...v, email: v.email || null, phone: v.phone || null, notes: v.notes || null })
              toast.success(customer ? t("customerDialog.updated") : t("customerDialog.created"))
              onOpenChange(false)
            } catch (e) {
              if (e instanceof ApiError && e.code === "VALIDATION_FAILED") {
                Object.entries(e.fieldErrors).forEach(([f, m]) => form.setError(f as keyof Values, { message: m[0] }))
              } else toast.error(errorMessage(e))
            }
          })}
        >
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="c-first">{t("customerDialog.firstName")}</Label>
              <Input id="c-first" {...form.register("first_name")} />
              {errors.first_name ? <p className="text-destructive text-xs">{msg(errors.first_name.message)}</p> : null}
            </div>
            <div className="space-y-2">
              <Label htmlFor="c-last">{t("customerDialog.lastName")}</Label>
              <Input id="c-last" {...form.register("last_name")} />
              {errors.last_name ? <p className="text-destructive text-xs">{msg(errors.last_name.message)}</p> : null}
            </div>
            <div className="space-y-2">
              <Label htmlFor="c-email">{t("ops.col.email")}</Label>
              <Input id="c-email" type="email" {...form.register("email")} />
              {errors.email ? <p className="text-destructive text-xs">{msg(errors.email.message)}</p> : null}
            </div>
            <div className="space-y-2">
              <Label htmlFor="c-phone">{t("ops.col.phone")}</Label>
              <Input id="c-phone" type="tel" {...form.register("phone")} />
              {errors.phone ? <p className="text-destructive text-xs">{msg(errors.phone.message)}</p> : null}
            </div>
          </div>
          <div className="space-y-2">
            <Label htmlFor="c-notes">{t("customerDialog.notes")}</Label>
            <Textarea id="c-notes" rows={3} {...form.register("notes")} />
            {errors.notes ? <p className="text-destructive text-xs">{msg(errors.notes.message)}</p> : null}
          </div>
          <label className="flex items-center justify-between rounded-xl border p-3 text-sm">
            <span>
              <span className="font-medium">{t("customerDialog.marketing")}</span>
              <span className="text-muted-foreground block text-xs">{t("customerDialog.marketingHint")}</span>
            </span>
            <Switch checked={form.watch("marketing_consent")} onCheckedChange={(v) => form.setValue("marketing_consent", v)} />
          </label>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={save.isPending}>
              {save.isPending ? <Loader2 className="animate-spin" /> : null} {t("common.save")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
