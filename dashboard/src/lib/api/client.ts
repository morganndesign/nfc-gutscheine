import { getDeviceId } from "@/lib/device"
import { CATALOGS, type MessageKey } from "@/lib/i18n/catalog"
import { format } from "@/lib/i18n/format"
import { currentLanguage } from "@/lib/i18n/state"

/**
 * Thin fetch wrapper for the Laravel API.
 *
 * - Same-origin requests (the reverse proxy / Next rewrites route /api and /sanctum to Laravel),
 *   so Sanctum session cookies are first-party, httpOnly and SameSite=Lax.
 * - CSRF: Laravel sets the XSRF-TOKEN cookie; it is echoed as the X-XSRF-TOKEN header on
 *   every state-changing request.
 * - X-Device-Id identifies the waiter device (revocable by managers).
 */

export interface ApiErrorBody {
  message?: string
  code?: string
  errors?: Record<string, string[]>
  context?: Record<string, unknown>
  retry_after?: number
}

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly body: ApiErrorBody,
  ) {
    super(body.message ?? `Request failed (${status})`)
    this.name = "ApiError"
  }

  get code(): string | undefined {
    return this.body.code
  }

  get fieldErrors(): Record<string, string[]> {
    return this.body.errors ?? {}
  }
}

function readCookie(name: string): string | null {
  if (typeof document === "undefined") return null
  const match = document.cookie.split("; ").find((row) => row.startsWith(`${name}=`))
  return match ? decodeURIComponent(match.split("=")[1] ?? "") : null
}

let csrfPromise: Promise<void> | null = null

async function ensureCsrfCookie(force = false): Promise<void> {
  if (!force && readCookie("XSRF-TOKEN")) return
  csrfPromise ??= fetch("/sanctum/csrf-cookie", { credentials: "include" }).then(() => undefined)
  try {
    await csrfPromise
  } finally {
    csrfPromise = null
  }
}

/** Warms up the XSRF-TOKEN cookie (no-op when it already exists). */
export function prefetchCsrfCookie(): Promise<void> {
  return ensureCsrfCookie().catch(() => undefined)
}

type Query = Record<string, string | number | boolean | null | undefined | string[]>

export interface RequestOptions {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE"
  body?: unknown
  query?: Query
  idempotencyKey?: string
  signal?: AbortSignal
  raw?: boolean
}

export function buildQuery(query?: Query): string {
  if (!query) return ""
  const params = new URLSearchParams()
  for (const [key, value] of Object.entries(query)) {
    if (value === undefined || value === null || value === "") continue
    if (Array.isArray(value)) {
      if (value.length) params.set(key, value.join(","))
    } else {
      params.set(key, String(value))
    }
  }
  const s = params.toString()
  return s ? `?${s}` : ""
}

async function send(path: string, options: RequestOptions, retry: boolean): Promise<Response> {
  const method = options.method ?? "GET"
  const mutating = method !== "GET"
  if (mutating) await ensureCsrfCookie()

  const headers: Record<string, string> = {
    Accept: "application/json",
    "X-Requested-With": "XMLHttpRequest",
    // Validation messages come back in the user's language.
    "Accept-Language": currentLanguage(),
  }
  const form = options.body instanceof FormData
  if (options.body !== undefined && !form) headers["Content-Type"] = "application/json"
  const xsrf = readCookie("XSRF-TOKEN")
  if (xsrf) headers["X-XSRF-TOKEN"] = xsrf
  const deviceId = getDeviceId()
  if (deviceId) headers["X-Device-Id"] = deviceId
  if (options.idempotencyKey) headers["Idempotency-Key"] = options.idempotencyKey

  const response = await fetch(`/api/v1${path}${buildQuery(options.query)}`, {
    method,
    headers,
    credentials: "include",
    body: form ? (options.body as FormData) : options.body !== undefined ? JSON.stringify(options.body) : undefined,
    signal: options.signal,
  })

  // Expired CSRF token: refresh once and retry.
  if (response.status === 419 && retry) {
    await ensureCsrfCookie(true)
    return send(path, options, false)
  }

  return response
}

export async function apiRaw(path: string, options: RequestOptions = {}): Promise<Response> {
  const response = await send(path, options, true)
  if (!response.ok) {
    const body = (await response.json().catch(() => ({}))) as ApiErrorBody
    throw new ApiError(response.status, body)
  }
  return response
}

export async function api<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const response = await apiRaw(path, options)
  if (response.status === 204) return undefined as T
  return (await response.json()) as T
}

/** Downloads a streamed export (CSV) with the current session. */
export async function downloadFile(path: string, query: Query, fallbackName: string): Promise<void> {
  const response = await apiRaw(path, { query })
  const blob = await response.blob()
  const disposition = response.headers.get("Content-Disposition") ?? ""
  const name = /filename="?([^"]+)"?/.exec(disposition)?.[1] ?? fallbackName
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  a.download = name
  document.body.appendChild(a)
  a.click()
  a.remove()
  URL.revokeObjectURL(url)
}

export function newIdempotencyKey(): string {
  return crypto.randomUUID()
}

function text(key: MessageKey, params?: Record<string, string | number>): string {
  const language = currentLanguage()
  return format(language, CATALOGS[language][key] ?? CATALOGS.en[key], params)
}

/**
 * What to tell the user about a failed request, in their language: the translation of the error code when there is
 * one (`errors.<CODE>`), else the server's (localised) validation message, else its message.
 */
export function errorMessage(error: unknown, fallback?: string): string {
  const generic = fallback ?? text("errors.generic")
  if (error instanceof ApiError) {
    const key = `errors.${error.code ?? ""}`
    if (error.code && key in CATALOGS.en) return text(key as MessageKey)
    const first = Object.values(error.fieldErrors)[0]?.[0]
    return first ?? error.message ?? generic
  }
  // fetch() rejects with a TypeError when the device is offline or the server is unreachable.
  if (error instanceof TypeError) return text("errors.offline")
  if (error instanceof Error && error.name !== "AbortError") return error.message || generic
  return generic
}
