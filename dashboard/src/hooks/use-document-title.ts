"use client"

import { useEffect } from "react"

/** The browser tab's title in the UI language: "Gutscheine · GiftCard Pro" (pages are client-rendered, no metadata). */
export function useDocumentTitle(title: string | null | undefined) {
  useEffect(() => {
    document.title = title ? `${title} · GiftCard Pro` : "GiftCard Pro"
  }, [title])
}
