"use client"

import { useCallback, useEffect, useRef, useState } from "react"
import { useQueryClient } from "@tanstack/react-query"
import { api, newIdempotencyKey } from "@/lib/api/client"
import { keys } from "@/lib/api/hooks"
import { WebNfcDriver } from "@/lib/nfc"
import { apiFailure, programCard, type CheckResult, type ProgramResult, type ProgrammingApi, type ProgressEvent } from "@/lib/nfc-programming"

/** Longest wait for one programming request before the operator is told "Network timeout". */
export const PROGRAMMING_REQUEST_TIMEOUT_MS = 15000

async function call<T>(path: string, body: unknown): Promise<T> {
  try {
    return await api<T>(path, { method: "POST", body, signal: AbortSignal.timeout(PROGRAMMING_REQUEST_TIMEOUT_MS) })
  } catch (err) {
    throw apiFailure(err)
  }
}

/** The dashboard API behind the programming workflow (POST /cards/{id}/nfc/check, …/nfc, …/nfc/lock, …/nfc/attempts). */
export const programmingApi: ProgrammingApi = {
  check: async (cardId, body) => (await call<{ data: CheckResult }>(`/cards/${cardId}/nfc/check`, body)).data,
  bind: (cardId, body) => call(`/cards/${cardId}/nfc`, body),
  confirmLock: (cardId, body) => call(`/cards/${cardId}/nfc/lock`, body),
  report: (cardId, body) => call(`/cards/${cardId}/nfc/attempts`, body),
}

export interface ProgrammerState extends Partial<ProgressEvent> {
  running: boolean
}

/**
 * One NFC session (one scanning reader, one permission prompt) for as many cards as needed.
 * `program()` runs the full read → check → detect → write → verify → bind (→ lock) workflow.
 */
export function useNfcProgrammer() {
  const qc = useQueryClient()
  const driver = useRef<WebNfcDriver | null>(null)
  const abort = useRef<AbortController | null>(null)
  const [state, setState] = useState<ProgrammerState>({ running: false })

  useEffect(
    () => () => {
      abort.current?.abort()
      driver.current?.close()
    },
    [],
  )

  const program = useCallback(
    async (card: { id: string; url: string }, options: { lock: boolean; ignoreSerials?: string[]; onlyIfUnprogrammed?: boolean }): Promise<ProgramResult> => {
      driver.current ??= new WebNfcDriver()
      const controller = new AbortController()
      abort.current = controller
      setState({ running: true, step: "waiting" })
      try {
        return await programCard(
          {
            cardId: card.id,
            expectedUrl: card.url,
            lock: options.lock,
            attemptId: newIdempotencyKey(),
            signal: controller.signal,
            ignoreSerials: options.ignoreSerials,
            onlyIfUnprogrammed: options.onlyIfUnprogrammed,
            onProgress: (event) => setState({ running: true, ...event }),
          },
          { driver: driver.current, api: programmingApi },
        )
      } finally {
        // A newer run may already have started (skip / retry): leave its state alone.
        if (abort.current === controller) {
          abort.current = null
          setState((s) => ({ ...s, running: false }))
        }
        void qc.invalidateQueries({ queryKey: keys.card(card.id) })
        void qc.invalidateQueries({ queryKey: keys.cards })
      }
    },
    [qc],
  )

  const cancel = useCallback(() => abort.current?.abort(), [])

  /** Ends the NFC session (stops scanning). */
  const close = useCallback(() => {
    abort.current?.abort()
    driver.current?.close()
    driver.current = null
  }, [])

  return { state, program, cancel, close }
}
