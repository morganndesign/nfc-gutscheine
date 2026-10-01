"use client"

import { useState } from "react"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { useUpdateVoucher } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { Voucher } from "@/lib/api/types"
import { useT } from "@/lib/i18n"

/** Recipient and internal notes. The expiry changes only through reinstatement (owner, with a reason). */
export function EditVoucherDialog({ voucher, open, onOpenChange }: { voucher: Voucher; open: boolean; onOpenChange: (o: boolean) => void }) {
  const t = useT()
  const [recipient, setRecipient] = useState(voucher.recipient_name ?? "")
  const [notes, setNotes] = useState(voucher.notes ?? "")
  const update = useUpdateVoucher(voucher.id)

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t("vouchers.edit.title")}</DialogTitle>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            try {
              await update.mutateAsync({ recipient_name: recipient || null, notes: notes || null })
              toast.success(t("vouchers.updated"))
              onOpenChange(false)
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="recipient">{t("vouchers.field.recipient")}</Label>
            <Input id="recipient" value={recipient} onChange={(e) => setRecipient(e.target.value)} maxLength={160} />
          </div>
          <div className="space-y-2">
            <Label htmlFor="notes">{t("vouchers.field.notes")}</Label>
            <Textarea id="notes" rows={4} value={notes} onChange={(e) => setNotes(e.target.value)} maxLength={2000} />
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={update.isPending}>
              {update.isPending ? <Loader2 className="animate-spin" /> : null} {t("common.save")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
