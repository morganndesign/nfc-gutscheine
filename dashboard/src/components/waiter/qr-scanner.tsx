"use client"

import { useEffect, useRef, useState } from "react"
import { Loader2 } from "lucide-react"

interface DetectedBarcode {
  rawValue: string
}
interface BarcodeDetectorLike {
  detect(source: CanvasImageSource): Promise<DetectedBarcode[]>
}
declare global {
  interface Window {
    BarcodeDetector?: new (options?: { formats: string[] }) => BarcodeDetectorLike
  }
}

export function isQrScanSupported(): boolean {
  return typeof window !== "undefined" && "BarcodeDetector" in window && !!navigator.mediaDevices?.getUserMedia
}

/** Camera QR scanner using the native BarcodeDetector API (no third-party code). */
export function QrScanner({ onResult, onError }: { onResult: (value: string) => void; onError: (message: string) => void }) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const [ready, setReady] = useState(false)
  // The camera starts once per mount; the latest callbacks are read through refs so that a re-render of the
  // parent never restarts (and races) the camera.
  const onResultRef = useRef(onResult)
  const onErrorRef = useRef(onError)
  useEffect(() => {
    onResultRef.current = onResult
    onErrorRef.current = onError
  })

  useEffect(() => {
    let stream: MediaStream | null = null
    let timer: ReturnType<typeof setInterval> | null = null
    let stopped = false

    const start = async () => {
      try {
        const Detector = window.BarcodeDetector
        if (!Detector) throw new Error("QR scanning is not supported on this device.")
        const detector = new Detector({ formats: ["qr_code"] })
        const acquired = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" }, audio: false })
        if (stopped) {
          // Unmounted while the permission prompt was open: release the camera at once.
          acquired.getTracks().forEach((t) => t.stop())
          return
        }
        stream = acquired
        const video = videoRef.current
        if (!video) return
        video.srcObject = stream
        await video.play()
        if (stopped) return
        setReady(true)
        timer = setInterval(async () => {
          if (stopped || video.readyState < 2) return
          try {
            const codes = await detector.detect(video)
            const hit = codes[0]?.rawValue
            if (hit && !stopped) {
              stopped = true
              onResultRef.current(hit)
            }
          } catch {
            /* frame not decodable — keep trying */
          }
        }, 200)
      } catch (e) {
        if (stopped) return
        onErrorRef.current(e instanceof Error && e.name === "NotAllowedError" ? "Camera access was denied." : (e as Error).message || "Camera unavailable.")
      }
    }

    void start()
    return () => {
      stopped = true
      if (timer) clearInterval(timer)
      stream?.getTracks().forEach((t) => t.stop())
    }
  }, [])

  return (
    <div className="relative aspect-square w-full overflow-hidden rounded-3xl bg-black">
      <video ref={videoRef} className="size-full object-cover" playsInline muted />
      {!ready ? (
        <div className="absolute inset-0 flex items-center justify-center text-white">
          <Loader2 className="size-6 animate-spin" />
        </div>
      ) : (
        <div className="pointer-events-none absolute inset-[18%] rounded-3xl border-4 border-white/80" />
      )}
    </div>
  )
}
