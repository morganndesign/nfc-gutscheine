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

const schema = z
  .object({
    first_name: z.string().max(100),
    last_name: z.string().max(100),
    email: z.union([z.literal(""), z.string().email("Invalid e-mail address")]),
    phone: z
      .string()
      .max(40)
      .regex(/^[0-9+\-\s()/]*$/, "Invalid phone number"),
    notes: z.string().max(2000),
    marketing_consent: z.boolean(),
  })
  .refine((v) => v.first_name || v.last_name || v.email || v.phone, { message: "Enter at least a name, e-mail or phone.", path: ["first_name"] })
type Values = z.infer<typeof schema>

export function CustomerDialog({ customer, open, onOpenChange }: { customer?: Customer; open: boolean; onOpenChange: (o: boolean) => void }) {
  const save = useSaveCustomer(customer?.id)
  const form = useForm<Values>({ resolver: zodResolver(schema) })

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
          <DialogTitle>{customer ? "Edit customer" : "New customer"}</DialogTitle>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={form.handleSubmit(async (v) => {
            try {
              await save.mutateAsync({ ...v, email: v.email || null, phone: v.phone || null, notes: v.notes || null })
              toast.success(customer ? "Customer updated" : "Customer created")
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
              <Label htmlFor="c-first">First name</Label>
              <Input id="c-first" {...form.register("first_name")} />
              {errors.first_name ? <p className="text-destructive text-xs">{errors.first_name.message}</p> : null}
            </div>
            <div className="space-y-2">
              <Label htmlFor="c-last">Last name</Label>
              <Input id="c-last" {...form.register("last_name")} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="c-email">E-mail</Label>
              <Input id="c-email" type="email" {...form.register("email")} />
              {errors.email ? <p className="text-destructive text-xs">{errors.email.message}</p> : null}
            </div>
            <div className="space-y-2">
              <Label htmlFor="c-phone">Phone</Label>
              <Input id="c-phone" type="tel" {...form.register("phone")} />
              {errors.phone ? <p className="text-destructive text-xs">{errors.phone.message}</p> : null}
            </div>
          </div>
          <div className="space-y-2">
            <Label htmlFor="c-notes">Notes</Label>
            <Textarea id="c-notes" rows={3} {...form.register("notes")} />
          </div>
          <label className="flex items-center justify-between rounded-xl border p-3 text-sm">
            <span>
              <span className="font-medium">Marketing consent</span>
              <span className="text-muted-foreground block text-xs">Customer agreed to receive newsletters (GDPR).</span>
            </span>
            <Switch checked={form.watch("marketing_consent")} onCheckedChange={(v) => form.setValue("marketing_consent", v)} />
          </label>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={save.isPending}>
              {save.isPending ? <Loader2 className="animate-spin" /> : null} Save
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
