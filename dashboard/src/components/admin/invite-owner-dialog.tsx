"use client"

import { useState } from "react"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { useInviteOwner } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import { useT } from "@/lib/i18n"

/** A new owner for the restaurant: a handover, or its only owner lost access. The previous owner stays until removed. */
export function InviteOwnerDialog({ restaurantId, open, onOpenChange }: { restaurantId: string; open: boolean; onOpenChange: (o: boolean) => void }) {
  const t = useT()
  const [name, setName] = useState("")
  const [email, setEmail] = useState("")
  const mutation = useInviteOwner()

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!o) {
          setName("")
          setEmail("")
        }
        onOpenChange(o)
      }}
    >
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t("admin.inviteOwner.title")}</DialogTitle>
          <DialogDescription>{t("admin.inviteOwner.description")}</DialogDescription>
        </DialogHeader>
        <form method="post"
          className="space-y-4"
          onSubmit={async (e) => {
            e.preventDefault()
            try {
              await mutation.mutateAsync({ restaurantId, name: name.trim(), email: email.trim() })
              toast.success(t("admin.invite.sent", { email: email.trim() }))
              onOpenChange(false)
            } catch (err) {
              toast.error(errorMessage(err))
            }
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="owner-name">{t("admin.field.name")}</Label>
            <Input id="owner-name" value={name} onChange={(e) => setName(e.target.value)} maxLength={160} required />
          </div>
          <div className="space-y-2">
            <Label htmlFor="owner-email">{t("admin.field.email")}</Label>
            <Input id="owner-email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} maxLength={191} required />
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={!name.trim() || !email.trim() || mutation.isPending}>
              {mutation.isPending ? <Loader2 className="animate-spin" /> : null}
              {t("admin.invite.send")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
