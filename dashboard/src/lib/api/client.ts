import { getDeviceId } from "@/lib/device"

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

const ACTING_RESTAURANT_KEY = "gcp.acting-restaurant"

/** Platform admins can operate inside a restaurant; stored per browser tab. */
export function setActingRestaurant(id: string | null): void {
  try {
    if (id) sessionStorage.setItem(ACTING_RESTAURANT_KEY, id)
    else sessionStorage.removeItem(ACTING_RESTAURANT_KEY)
  } catch {
    /* storage unavailable */
  }
}

export function getActingRestaurant(): string | null {
  try {
    return sessionStorage.getItem(ACTING_RESTAURANT_KEY)
  } catch {
    return null
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
  }
  if (options.body !== undefined) headers["Content-Type"] = "application/json"
  const xsrf = readCookie("XSRF-TOKEN")
  if (xsrf) headers["X-XSRF-TOKEN"] = xsrf
  const deviceId = getDeviceId()
  if (deviceId) headers["X-Device-Id"] = deviceId
  const acting = getActingRestaurant()
  if (acting) headers["X-Restaurant-Id"] = acting
  if (options.idempotencyKey) headers["Idempotency-Key"] = options.idempotencyKey

  const response = await fetch(`/api/v1${path}${buildQuery(options.query)}`, {
    method,
    headers,
    credentials: "include",
    body: options.body !== undefined ? JSON.stringify(options.body) : undefined,
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

export function errorMessage(error: unknown, fallback = "Something went wrong. Please try again."): string {
  if (error instanceof ApiError) {
    const first = Object.values(error.fieldErrors)[0]?.[0]
    return first ?? error.message ?? fallback
  }
  // fetch() rejects with a TypeError when the device is offline or the server is unreachable.
  if (error instanceof TypeError) return "No connection to the server. Check the internet connection and try again."
  if (error instanceof Error && error.name !== "AbortError") return error.message || fallback
  return fallback
}
