"use client"

import { useSyncExternalStore } from "react"
import { isWebNfcSupported } from "@/lib/nfc"
import { isQrScanSupported } from "@/components/waiter/qr-scanner"

const subscribe = () => () => undefined

/**
 * Browser capabilities, hydration-safe: the server render (and the first client render) report
 * "unsupported", the real values apply right after hydration — no mismatch warnings, no flicker bugs.
 */
export function useCapabilities(): { nfc: boolean; qr: boolean } {
  const nfc = useSyncExternalStore(subscribe, isWebNfcSupported, () => false)
  const qr = useSyncExternalStore(subscribe, isQrScanSupported, () => false)
  return { nfc, qr }
}
