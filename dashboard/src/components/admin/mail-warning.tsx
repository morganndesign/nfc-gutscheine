"use client"

import Link from "next/link"
import { MailWarning as MailWarningIcon } from "lucide-react"
import { useMailStatus } from "@/lib/api/hooks"

/**
 * Shown on the platform pages while e-mails are not delivered (MAIL_MAILER=log): invitations, password
 * links and voucher e-mails would silently go to the log only.
 */
export function MailWarning({ showLink = true }: { showLink?: boolean }) {
  const { data } = useMailStatus()
  if (!data || data.delivers) return null

  return (
    // Darker reds than the "destructive" token: readable (WCAG AA) on the tinted background.
    <div role="alert" className="border-destructive/40 flex gap-3 rounded-2xl border bg-red-50 p-4 text-sm text-red-800 dark:bg-red-950/40 dark:text-red-200">
      <MailWarningIcon className="mt-0.5 size-4 shrink-0" />
      <div className="space-y-1">
        <p className="font-medium">E-mails are not delivered — invitations do not reach anyone.</p>
        <p>{data.problem}</p>
        {showLink ? (
          <Link href="/admin/settings" className="underline underline-offset-2">
            Check mail delivery
          </Link>
        ) : null}
      </div>
    </div>
  )
}
