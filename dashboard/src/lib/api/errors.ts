/** Errors of the Laravel API and what to tell the user about them (no React, no i18n: usable in tests). */

export interface ApiErrorBody {
  message?: string
  code?: string
  errors?: Record<string, string[]>
  context?: Record<string, unknown>
  retry_after?: number
}

export class ApiError extends Error {
  readonly status: number
  readonly body: ApiErrorBody

  constructor(status: number, body: ApiErrorBody) {
    super(body.message ?? `Request failed (${status})`)
    this.name = "ApiError"
    this.status = status
    this.body = body
  }

  get code(): string | undefined {
    return this.body.code
  }

  get fieldErrors(): Record<string, string[]> {
    return this.body.errors ?? {}
  }
}

/** Which text explains a failed request: a translated error code, a (server-localised) validation message, or ours. */
export type ErrorText = { kind: "code"; code: string } | { kind: "field"; message: string } | { kind: "offline" } | { kind: "generic" }

/**
 * Only two things the server sends are fit for the user: an error code we translate, and validation messages (the
 * server localises those via Accept-Language). Every other server `message` is English developer text ("Server Error",
 * "Too many requests. Please slow down.", "Request failed (502)" for a proxy page) and is never shown.
 */
export function errorText(error: unknown, translatable: (code: string) => boolean): ErrorText {
  if (error instanceof ApiError) {
    if (error.code && translatable(error.code)) return { kind: "code", code: error.code }
    const first = Object.values(error.fieldErrors)[0]?.[0]
    if (first) return { kind: "field", message: first }
    return { kind: "generic" }
  }
  // fetch() rejects with a TypeError when the device is offline or the server is unreachable.
  if (error instanceof TypeError) return { kind: "offline" }
  return { kind: "generic" }
}
