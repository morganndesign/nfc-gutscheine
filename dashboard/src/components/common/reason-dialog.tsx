"use client"

import { useState, type ReactNode } from "react"
import { Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { useT } from "@/lib/i18n"

/**
 * Confirmation dialog that optionally collects a reason (stored in the audit log).
 */
export function ReasonDialog({
  open,
  onOpenChange,
  title,
  description,
  confirmLabel,
  destructive,
  reasonRequired = true,
  reasonLabel,
  pending,
  onConfirm,
  suggestions,
  children,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  title: string
  description?: ReactNode
  confirmLabel: string
  destructive?: boolean
  reasonRequired?: boolean | "none"
  reasonLabel?: string
  pending?: boolean
  onConfirm: (reason: string) => void
  /** One-tap reasons for the common cases; the text can still be edited. */
  suggestions?: string[]
  children?: ReactNode
}) {
  const t = useT()
  const [reason, setReason] = useState("")
  const needsReason = reasonRequired === true
  const showReason = reasonRequired !== "none"

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!o) setReason("")
        onOpenChange(o)
      }}
    >
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          {description ? <DialogDescription>{description}</DialogDescription> : null}
        </DialogHeader>
        {children}
        {showReason ? (
          <div className="space-y-2">
            <Label htmlFor="reason">
              {reasonLabel ?? t("reasonDialog.reason")}
              {needsReason ? null : <span className="text-muted-foreground"> {t("reasonDialog.optional")}</span>}
            </Label>
            {suggestions?.length ? (
              <div className="flex flex-wrap gap-1.5" role="group" aria-label={t("reasonDialog.suggestions")}>
                {suggestions.map((s) => (
                  <button
                    key={s}
                    type="button"
                    onClick={() => setReason(s)}
                    aria-pressed={reason === s}
                    className="hover:bg-muted aria-pressed:border-primary aria-pressed:bg-primary aria-pressed:text-primary-foreground focus-visible:ring-ring/50 rounded-full border px-3 py-1 text-xs font-medium transition outline-none focus-visible:ring-[3px]"
                  >
                    {s}
                  </button>
                ))}
              </div>
            ) : null}
            <Textarea
              id="reason"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && (e.metaKey || e.ctrlKey) && !(needsReason && reason.trim().length < 3)) onConfirm(reason.trim())
              }}
              maxLength={500}
              rows={3}
              autoFocus={!suggestions?.length}
              placeholder={suggestions?.length ? t("reasonDialog.otherPlaceholder") : undefined}
            />
          </div>
        ) : null}
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={pending}>
            {t("common.cancel")}
          </Button>
          <Button
            variant={destructive ? "destructive" : "default"}
            disabled={pending || (needsReason && reason.trim().length < 3)}
            onClick={() => onConfirm(reason.trim())}
          >
            {pending ? <Loader2 className="animate-spin" /> : null} {confirmLabel}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
