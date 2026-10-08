// Read-only check of a running GiftCard Pro deployment (security/README.md). Safe for production: only GET/OPTIONS
// requests, no sign-in, nothing is written. It checks what the server itself is responsible for: HTTPS, security
// headers, cookies, CORS, debug output and that internal files are never served.
//
//   node security/check-deployment.mjs                         # https://app.giftcardpro.at
//   BASE_URL=http://127.0.0.1:3000 node security/check-deployment.mjs   # local (HTTPS checks skipped)

const BASE = (process.env.BASE_URL ?? "https://app.giftcardpro.at").replace(/\/$/, "")
const HTTPS = BASE.startsWith("https://")
const results = []

async function get(path, init = {}) {
  return fetch(BASE + path, { redirect: "manual", ...init, headers: { "User-Agent": "GiftCardPro-deployment-check", ...(init.headers ?? {}) } })
}

async function check(name, fn) {
  try {
    const skipped = await fn()
    results.push({ name, ok: true, note: skipped === "skip" ? "skipped" : "" })
  } catch (e) {
    results.push({ name, ok: false, note: e.message })
  }
}

function expect(condition, message) {
  if (!condition) throw new Error(message)
}

await check("HTTP is redirected to HTTPS", async () => {
  if (!HTTPS) return "skip"
  const res = await fetch(BASE.replace("https://", "http://") + "/", { redirect: "manual" })
  expect([301, 302, 307, 308].includes(res.status), `status ${res.status}`)
  expect((res.headers.get("location") ?? "").startsWith("https://"), `location ${res.headers.get("location")}`)
})

await check("HSTS for at least one year", async () => {
  if (!HTTPS) return "skip"
  const hsts = (await get("/login")).headers.get("strict-transport-security") ?? ""
  const age = Number(/max-age=(\d+)/.exec(hsts)?.[1] ?? 0)
  expect(age >= 31536000, `Strict-Transport-Security "${hsts}"`)
})

await check("Dashboard pages send the security headers", async () => {
  const res = await get("/login")
  expect(res.status === 200, `status ${res.status}`)
  const h = res.headers
  expect(h.get("x-content-type-options") === "nosniff", "X-Content-Type-Options")
  const csp = h.get("content-security-policy") ?? ""
  expect(h.get("x-frame-options") === "DENY" || /frame-ancestors 'none'/.test(csp), "no frame protection")
  // Scripts only with the per-page nonce (audit S6); a nonce makes browsers ignore 'unsafe-inline'.
  expect(/script-src[^;]*'nonce-/.test(csp), `CSP without a script nonce: "${csp.slice(0, 120)}"`)
  expect(/default-src 'self'/.test(csp), "CSP without default-src 'self'")
  expect(!!h.get("referrer-policy"), "Referrer-Policy")
})

await check("API answers send nosniff", async () => {
  const res = await get("/api/v1/auth/me", { headers: { Accept: "application/json" } })
  expect(res.headers.get("x-content-type-options") === "nosniff", "X-Content-Type-Options")
})

await check("No server software or version is disclosed", async () => {
  for (const path of ["/login", "/api/v1/app/config?platform=android&version=2.0.0", "/up"]) {
    const h = (await get(path)).headers
    expect(!h.get("x-powered-by"), `X-Powered-By on ${path}: ${h.get("x-powered-by")}`)
    const server = h.get("server") ?? ""
    expect(!/\d/.test(server), `Server header with a version on ${path}: ${server}`)
  }
})

await check("Internal files are never served", async () => {
  const paths = [
    "/.env", "/.env.production", "/.git/HEAD", "/.git/config", "/composer.json", "/composer.lock", "/package.json",
    "/artisan", "/storage/logs/laravel.log", "/api/../.env", "/vendor/autoload.php", "/index.php.bak",
    "/phpinfo.php", "/telescope", "/horizon", "/_ignition/health-check", "/server-status", "/.DS_Store",
    "/backend/.env", "/docker-compose.yml",
  ]
  const exposed = []
  for (const path of paths) {
    const res = await get(path)
    const body = res.status === 200 ? await res.text() : ""
    // The dashboard answers unknown paths with its own page (or a redirect to sign-in); that is fine as long as the
    // file's content is not in it.
    if (res.status === 200 && /APP_KEY=|DB_PASSWORD|\[core\]|"require"\s*:|<\?php|phpinfo\(\)|local\.ERROR|production\.ERROR/.test(body)) exposed.push(path)
  }
  expect(exposed.length === 0, `served: ${exposed.join(", ")}`)
})

await check("Errors carry no debug details (APP_DEBUG off)", async () => {
  const bodies = []
  bodies.push(await (await get("/api/v1/auth/me", { headers: { Accept: "application/json" } })).text())
  bodies.push(await (await get("/api/v1/does-not-exist", { headers: { Accept: "application/json" } })).text())
  bodies.push(await (await get("/api/v1/shop/%ff", { headers: { Accept: "application/json" } })).text())
  for (const body of bodies) expect(!/"(exception|trace|file|line)"\s*:|Stack trace|vendor\/laravel|Whoops/.test(body), `debug output: ${body.slice(0, 160)}`)
})

await check("Unauthenticated API calls are refused with 401", async () => {
  for (const path of ["/api/v1/auth/me", "/api/v1/vouchers", "/api/v1/admin/restaurants", "/api/v1/users"]) {
    const res = await get(path, { headers: { Accept: "application/json" } })
    expect(res.status === 401, `${path} → ${res.status}`)
  }
  const partner = await get("/api/partner/v1/me", { headers: { Accept: "application/json" } })
  expect(partner.status === 401, `partner API → ${partner.status}`)
})

await check("Session cookies are Secure, HttpOnly and SameSite", async () => {
  const res = await get("/sanctum/csrf-cookie", { headers: { Accept: "application/json" } })
  const cookies = res.headers.getSetCookie()
  expect(cookies.length > 0, "no cookies set")
  for (const c of cookies) {
    const name = c.split("=")[0]
    if (HTTPS) expect(/;\s*secure/i.test(c), `${name} without Secure`)
    expect(/;\s*samesite=(lax|strict)/i.test(c), `${name} without SameSite`)
    // The XSRF-TOKEN cookie is read by the dashboard's JavaScript by design; the session cookie never is.
    if (name !== "XSRF-TOKEN") expect(/;\s*httponly/i.test(c), `${name} without HttpOnly`)
  }
})

await check("CORS does not open the API to other websites", async () => {
  const res = await get("/api/v1/auth/me", { headers: { Origin: "https://example.org", Accept: "application/json" } })
  const allowed = res.headers.get("access-control-allow-origin")
  expect(!allowed || (allowed !== "*" && allowed !== "https://example.org") || res.headers.get("access-control-allow-credentials") !== "true", `allows ${allowed} with credentials`)
  expect(allowed !== "https://example.org", `reflects a foreign origin: ${allowed}`)
  const preflight = await get("/api/v1/vouchers", { method: "OPTIONS", headers: { Origin: "https://example.org", "Access-Control-Request-Method": "POST" } })
  expect(preflight.headers.get("access-control-allow-origin") !== "https://example.org", "preflight allows a foreign origin")
})

await check("TRACE is not allowed", async () => {
  const res = await fetch(BASE + "/", { method: "TRACE" }).catch(() => null)
  expect(!res || res.status >= 400, `TRACE → ${res?.status}`)
})

await check("Guest tap page sends no referrer (its URL carries card values)", async () => {
  const res = await get("/t/ks-0000-00?e=00&m=00")
  if (res.status === 404) return "skip"
  expect(res.headers.get("referrer-policy") === "no-referrer", `Referrer-Policy ${res.headers.get("referrer-policy")}`)
})

const failed = results.filter((r) => !r.ok)
for (const r of results) console.log(`${r.ok ? (r.note === "skipped" ? "–" : "✓") : "✗"} ${r.name}${r.note && r.note !== "skipped" ? ` — ${r.note}` : r.note ? " (skipped)" : ""}`)
console.log(`\n${BASE}: ${results.length - failed.length}/${results.length} checks passed.`)
process.exit(failed.length ? 1 : 0)
