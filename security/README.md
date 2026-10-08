# Security checks

One command runs every automated security check; each part can also run on its own.

```bash
security/run.sh                      # all
security/run.sh tests secrets        # some: tests secrets deps code deployment zap
DEPLOY_URL=https://staging.giftcardpro.at security/run.sh deployment
```

| Step | What it proves | Tool | Where it runs |
|---|---|---|---|
| `tests` | Tenant isolation, roles, attacks on cards, QR, payments, sign-in and the POS API (`tests/Feature/Abuse`, `Security`, `Partner`, permission matrix …) and the **security sweep** below | PHPUnit | local, CI (`ci.yml`) |
| `secrets` | No key, password or token anywhere in the code or the git history | gitleaks (`.gitleaks.toml`, `.gitleaksignore`) | local, CI on every push |
| `deps` | No library with a known vulnerability (composer, npm, Flutter) | osv-scanner (`osv-scanner.toml`), composer audit, npm audit | local, CI on every push |
| `code` | No dangerous code pattern (injection, XSS, weak crypto, secrets) | semgrep (OWASP Top 10, PHP, TypeScript, React, Next.js, JWT) | local, CI on every push |
| `deployment` | HTTPS and HSTS, security headers and CSP, cookies, CORS, no debug output, no server versions, internal files never served, 401 without a session | `check-deployment.mjs` — **read-only** (GET/OPTIONS, no sign-in, nothing written) | production weekly (Monday) in CI, any time locally |
| `zap` | OWASP ZAP baseline of the dashboard and an active scan of the POS partner API from its OpenAPI file | ZAP in Docker (`zap-rules.tsv`, `zap-api-rules.tsv`) | **local stack only** (refuses public hosts), CI weekly |

Reports of the ZAP scans: `security/reports/` (not committed).

## Security sweep (`backend/tests/Feature/Security/SecuritySweepTest.php`)

Data-driven over the whole route list, so every new route is covered without writing a test for it:

- **Tenant isolation:** the owner of restaurant B calls every route that names a record of restaurant A (voucher,
  transaction, customer, user, device, card, card batch, POS connection and code, access token, restaurant) → only
  403/404, and nothing of A changes. A new route parameter fails the test until it is added.
- **Robustness:** every route with malformed input (wrong types, out of range, 100 000 characters, deep nesting,
  control characters, odd query strings) → never a server error.
- **No secrets in answers:** no password, token/key/code hash, bcrypt hash or full `gcpp_`/`gcpc_` key in any
  answer of any GET route.
- **Fields that grant power are ignored:** role, restaurant, platform admin, permissions, status in request bodies.
- **Rate limits:** every route callable without a session has one.

The dashboard test `src/lib/forms.test.ts` keeps every form `method="post"`: a form sent before the page's
JavaScript loaded never puts an e-mail or password into the URL (found by ZAP, 2026-10-08).

## Accepted findings (reviewed, with reasons)

- `osv-scanner.toml`: `braces` (no fix yet) only in the shadcn CLI, a development tool — expires 2027-01-08.
- `zap-rules.tsv`: CSP `style-src 'unsafe-inline'` (React/Radix inline styles; scripts need the per-page nonce),
  CSP on plain-text files, anti-CSRF tokens in forms (the API takes the XSRF header), informational notes.
- `.gitleaksignore`, `.gitleaks.toml`: test fixtures, local evidence logs and empty example values.

## Not automated (recommended)

| Check | Why | When |
|---|---|---|
| External penetration test by a specialist firm | Business-logic attacks and chained bugs that tools miss; restaurants and POS partners may ask for the report | before the first larger rollout, then yearly |
| Real NFC cards with a Proxmark / cloned card | The card security model with real hardware, not the simulated chip | once per key set / card batch |
| Restore drill of a backup | A backup is only proven by restoring it (off-site backup is still open) | quarterly |
| Mobile app review (MobSF static scan of the APK and IPA) | Token storage, certificate handling, debug flags in the release build | every app release |
| TLS rating (SSL Labs) of app.giftcardpro.at | Protocols and ciphers of the Coolify proxy | after proxy changes |
