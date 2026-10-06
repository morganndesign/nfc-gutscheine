import { NextResponse, type NextRequest } from "next/server"

/**
 * Content Security Policy with a fresh nonce per page (audit S6): only scripts that carry this response's nonce run
 * — Next.js stamps it on its own scripts, next-themes on its theme script — and the scripts they load
 * (`'strict-dynamic'`). An injected inline script has no nonce and is blocked. Styles stay `'unsafe-inline'`
 * (component libraries set inline styles; they cannot run code).
 */
export function middleware(request: NextRequest) {
  const nonce = btoa(crypto.randomUUID())
  const development = process.env.NODE_ENV === "development"
  const policy = [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${development ? " 'unsafe-eval'" : ""}`,
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob:",
    "font-src 'self' data:",
    "connect-src 'self'",
    "object-src 'none'",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action 'self'",
  ].join("; ")

  // Next.js reads the nonce from the request's policy and puts it on the scripts it renders.
  const headers = new Headers(request.headers)
  headers.set("x-nonce", nonce)
  headers.set("Content-Security-Policy", policy)
  const response = NextResponse.next({ request: { headers } })
  response.headers.set("Content-Security-Policy", policy)
  return response
}

export const config = {
  // Pages only: Next's static files carry no policy of their own; /api and /sanctum are Laravel's.
  matcher: [
    {
      source: "/((?!api/|sanctum/|_next/static|_next/image|favicon|icons/|manifest.webmanifest|robots.txt).*)",
      missing: [
        { type: "header", key: "next-router-prefetch" },
        { type: "header", key: "purpose", value: "prefetch" },
      ],
    },
  ],
}
