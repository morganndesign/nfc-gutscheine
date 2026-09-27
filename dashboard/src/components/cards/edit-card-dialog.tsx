"use client"

import { useState } from "react"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { useUpdateCard } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { GiftCard } from "@/lib/api/types"
import { isoToDateInput, todayInput } from "@/lib/format"

export function EditCardDialog({ card, open, onOpenChange }: { card: GiftCard; open: boolean; onOpenChange: (o: boolean) => void }) {
  const [recipient, setRecipient] = useState(card.recipient_name ?? "")
  const [notes, setNotes] = useState(card.notes ?? "")
  const [expires, setExpires] = useState(isoToDateInput(card.expires_at))
  const update = useUpdateCard(card.id)
  const closed = card.status === "expired" || card.status === "replaced"

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Edit card details</DialogTitle>
        </DialogHeader>
        <form
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            try {
              await update.mutateAsync({
                recipient_name: recipient || null,
                notes: notes || null,
                ...(closed ? {} : { expires_at: expires || null }),
              })
              toast.success("Card updated")
              onOpenChange(false)
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="recipient">Recipient</Label>
            <Input id="recipient" value={recipient} onChange={(e) => setRecipient(e.target.value)} maxLength={160} />
          </div>
          {!closed ? (
            <div className="space-y-2">
              <Label htmlFor="expires">Valid until</Label>
              <Input id="expires" type="date" min={todayInput(1)} value={expires} onChange={(e) => setExpires(e.target.value)} />
              <p className="text-muted-foreground text-xs">Leave empty for no expiry.</p>
            </div>
          ) : null}
          <div className="space-y-2">
            <Label htmlFor="notes">Internal notes</Label>
            <Textarea id="notes" rows={4} value={notes} onChange={(e) => setNotes(e.target.value)} maxLength={2000} />
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={update.isPending}>
              {update.isPending ? <Loader2 className="animate-spin" /> : null} Save
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
