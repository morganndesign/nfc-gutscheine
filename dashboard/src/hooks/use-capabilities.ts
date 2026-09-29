"use client"

import { useSyncExternalStore } from "react"
import { isQrScanSupported } from "@/components/waiter/qr-scanner"

const subscribe = () => () => undefined

/**
 * Browser capabilities, hydration-safe: the server render (and the first client render) report
 * "unsupported", the real values apply right after hydration — no mismatch warnings, no flicker bugs.
 * The web app never reads cards: card vouchers are redeemed in the Android and iPhone app (architecture §10.3).
 */
export function useCapabilities(): { qr: boolean } {
  const qr = useSyncExternalStore(subscribe, isQrScanSupported, () => false)
  return { qr }
}
