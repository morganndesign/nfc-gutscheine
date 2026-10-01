"use client"

import { useState } from "react"
import { Check, Copy } from "lucide-react"
import { Button } from "@/components/ui/button"
import { useT } from "@/lib/i18n"

export function CopyButton({ value, label }: { value: string; label?: string }) {
  const t = useT()
  const [copied, setCopied] = useState(false)
  return (
    <Button
      type="button"
      variant="outline"
      size="sm"
      onClick={async () => {
        await navigator.clipboard.writeText(value)
        setCopied(true)
        setTimeout(() => setCopied(false), 1500)
      }}
    >
      {copied ? <Check /> : <Copy />} {copied ? t("copyButton.copied") : (label ?? t("copyButton.copy"))}
    </Button>
  )
}
