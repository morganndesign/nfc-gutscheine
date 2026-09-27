import type { NextConfig } from "next"

// Where `next dev` forwards /api and /sanctum (dashboard/.env.local, see .env.example). No default:
// in production Caddy routes those paths to Laravel and this stays unset, so the production build
// never contains a development address.
const backend = process.env.BACKEND_INTERNAL_URL?.trim() || undefined
if (!backend && process.env.NODE_ENV === "development") {
  throw new Error("BACKEND_INTERNAL_URL is not set. Run: cp .env.example .env.local (dashboard/)")
}

const securityHeaders = [
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  // NFC must stay enabled for the waiter app; camera for QR scanning.
  { key: "Permissions-Policy", value: "camera=(self), microphone=(), geolocation=(), nfc=(self)" },
  {
    key: "Content-Security-Policy",
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline'" + (process.env.NODE_ENV === "development" ? " 'unsafe-eval'" : ""),
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: blob:",
      "font-src 'self' data:",
      "connect-src 'self'",
      "frame-ancestors 'none'",
      "base-uri 'self'",
      "form-action 'self'",
    ].join("; "),
  },
]

const nextConfig: NextConfig = {
  output: "standalone",
  poweredByHeader: false,
  reactStrictMode: true,
  typedRoutes: false,
  devIndicators: false,
  async headers() {
    return [{ source: "/:path*", headers: securityHeaders }]
  },
  // In production the reverse proxy (Caddy) routes /api and /sanctum to Laravel before they
  // reach Next.js; these rewrites make the same-origin setup work in local development too.
  async rewrites() {
    if (!backend) return []
    return [
      { source: "/api/:path*", destination: `${backend}/api/:path*` },
      { source: "/sanctum/:path*", destination: `${backend}/sanctum/:path*` },
    ]
  },
}

export default nextConfig
