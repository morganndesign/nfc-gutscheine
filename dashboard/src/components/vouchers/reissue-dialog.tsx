"use client"

import { useState } from "react"
import { AlertTriangle, Loader2, Printer } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { PrintableVoucherSheet } from "@/components/vouchers/printable-voucher-sheet"
import { useReissueQr } from "@/lib/api/hooks"
import { errorMessage } from "@/lib/api/client"
import type { Voucher } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"

/** A new QR for a lost or unprinted sheet: the old QR stops at once; the new one is shown once, to print. */
export function ReissueDialog({ voucher, open, onOpenChange }: { voucher: Voucher; open: boolean; onOpenChange: (open: boolean) => void }) {
  const { user } = useAuth()
  const restaurant = user?.restaurant
  const [reason, setReason] = useState("")
  const [error, setError] = useState<string | null>(null)
  const [qrSvg, setQrSvg] = useState<string | null>(null)
  const [printed, setPrinted] = useState(false)
  const mutation = useReissueQr()

  const close = (o: boolean) => {
    // A new QR that was not printed is lost with the dialog: ask once.
    if (!o && qrSvg && !printed && !window.confirm("The new QR code has not been printed. Close anyway? It cannot be shown again.")) return
    if (!o) {
      setReason("")
      setError(null)
      setQrSvg(null)
      setPrinted(false)
    }
    onOpenChange(o)
  }

  return (
    <Dialog open={open} onOpenChange={close}>
      <DialogContent className={qrSvg ? "sm:max-w-2xl" : "sm:max-w-md"}>
        <DialogHeader>
          <DialogTitle>New QR code</DialogTitle>
          <DialogDescription>
            {qrSvg
              ? "Print the new voucher now. The previous QR code no longer works."
              : "For a lost or never printed voucher. The previous QR code stops working at once; balance and history stay."}
          </DialogDescription>
        </DialogHeader>
        {qrSvg ? (
          <div className="space-y-4">
            <PrintableVoucherSheet
              qrSvg={qrSvg}
              restaurantName={restaurant?.name ?? ""}
              brandColor={restaurant?.settings.brand_color}
              locale={restaurant?.locale}
              recipientName={voucher.recipient_name}
              expiresAt={voucher.expires_at}
              value={voucher.initial_value}
              currency={voucher.currency}
            />
            <div className="flex items-start gap-2 rounded-xl border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:border-amber-500/30 dark:bg-amber-500/10 dark:text-amber-200">
              <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
              <span>The QR code is shown only once. To send it by e-mail, choose “Save as PDF” in the print dialog.</span>
            </div>
            <DialogFooter>
              <Button
                onClick={() => {
                  window.print()
                  setPrinted(true)
                }}
              >
                <Printer /> Print voucher
              </Button>
            </DialogFooter>
          </div>
        ) : (
          <form
            className="space-y-4"
            onSubmit={async (e) => {
              e.preventDefault()
              setError(null)
              try {
                const result = await mutation.mutateAsync({ voucherId: voucher.id, reason: reason.trim() })
                setQrSvg(result.printable.qr_svg)
              } catch (err) {
                setError(errorMessage(err))
              }
            }}
          >
            <div className="space-y-2">
              <Label htmlFor="reissue-reason">Reason</Label>
              <Textarea id="reissue-reason" value={reason} onChange={(e) => setReason(e.target.value)} maxLength={500} placeholder="e.g. guest lost the voucher" />
            </div>
            {error ? <p className="bg-destructive/10 text-destructive rounded-lg px-3 py-2 text-sm">{error}</p> : null}
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => close(false)}>
                Cancel
              </Button>
              <Button type="submit" disabled={reason.trim().length < 3 || mutation.isPending}>
                {mutation.isPending ? <Loader2 className="animate-spin" /> : null}
                Issue new QR code
              </Button>
            </DialogFooter>
          </form>
        )}
      </DialogContent>
    </Dialog>
  )
}
