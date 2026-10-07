// End-to-end acceptance test: the complete first day of a pilot restaurant, in real browsers.
//
//   platform admin onboards a restaurant → owner accepts the invitation → owner invites a waiter →
//   owner sells a printable voucher (cash) → waiter scans its QR on a phone and redeems → owner reloads and
//   blocks the voucher → the waiter's next scan shows it blocked → ledger export → accessibility scan.
//
// The phone camera is simulated: Chromium's fake camera feeds the video, and BarcodeDetector is replaced by one
// that "sees" the printed voucher's QR payload (taken from the sale response, exactly what is printed).
//
// Requirements: API + web app running locally with MAIL_MAILER=log and LOG_LEVEL=debug (invitation links
// are read from the Laravel log), and a platform admin (php artisan platform:create-admin).
// Every run creates a new restaurant with unique e-mail addresses, so it can be repeated.
//
//   cd e2e && npm install && ADMIN_EMAIL=… ADMIN_PASSWORD=… npm test
import { chromium, devices } from 'playwright'
import { AxeBuilder } from '@axe-core/playwright'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { invitationLink, signInWithCode } from './lib/mail.mjs'
import { englishAccount, englishContext } from './lib/english.mjs'

const BASE = process.env.BASE_URL ?? 'http://localhost:3000'
const ADMIN_EMAIL = process.env.ADMIN_EMAIL ?? 'admin@giftcardpro.test'
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD ?? 'Password123!'
const run = Date.now().toString(36)

const browser = await chromium.launch({
  ...(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {}),
  // A fake camera for the waiter's QR scan (see the header).
  args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream'],
})
const errors = []
const step = (n, text) => console.log(`${String(n).padStart(2)}. ${text}`)

async function newPage(options, who) {
  const page = await (await englishContext(await browser.newContext(options))).newPage()
  page.on('pageerror', (e) => errors.push(`${who}: ${e.message}`))
  page.on('console', (m) => m.type() === 'error' && !/401|Failed to load resource/.test(m.text()) && errors.push(`${who}: ${m.text()}`))
  return page
}


async function signIn(page, email, password) {
  await signInWithCode(page, BASE, email, password)
  await englishAccount(page)
}

async function acceptInvitation(page, email, password) {
  await page.goto(await invitationLink(BASE, email))
  await page.getByText('Welcome to GiftCard Pro').waitFor()
  await page.fill('#password', password)
  await page.fill('#confirmation', password)
  await page.click('button[type=submit]')
  await page.waitForURL('**/login**')
  await signIn(page, email, password)
}

// Audit S6: every page carries its own script nonce; no inline script runs without it.
{
  const policies = []
  for (let i = 0; i < 2; i++) {
    const res = await fetch(`${BASE}/login`, { redirect: 'manual' })
    policies.push(res.headers.get('content-security-policy') ?? '')
  }
  const script = policies[0].split(';').map((d) => d.trim()).find((d) => d.startsWith('script-src')) ?? ''
  assert.match(script, /'nonce-[A-Za-z0-9+/=]+' 'strict-dynamic'/, 'script-src with a nonce')
  assert.doesNotMatch(script, /unsafe-inline/, 'no inline scripts without a nonce')
  assert.notEqual(policies[0], policies[1], 'a new nonce per response')
}

const desktop = { viewport: { width: 1440, height: 900 } }
const owner = { email: `owner-${run}@pilot.test`, password: `Owner-${run}-2026` }
const waiter = { email: `waiter-${run}@pilot.test`, password: `Waiter-${run}-2026` }

// 1. Platform admin onboards the restaurant
const admin = await newPage(desktop, 'admin')
await signIn(admin, ADMIN_EMAIL, ADMIN_PASSWORD)
await admin.getByRole('button', { name: /Onboard restaurant/ }).first().click()
await admin.fill('#r-name', `Pilot ${run}`)
await admin.fill('#r-email', `office-${run}@pilot.test`)
await admin.fill('#o-name', 'Olivia Owner')
await admin.fill('#o-email', owner.email)
await admin.getByRole('button', { name: 'Create restaurant' }).click()
await admin.waitForURL('**/admin/restaurants/**')
step(1, 'restaurant onboarded, owner invited')

// 2. Owner accepts the invitation and sees the getting-started panel
const o = await newPage(desktop, 'owner')
await acceptInvitation(o, owner.email, owner.password)
await o.getByText('Welcome to GiftCard Pro').waitFor()
step(2, 'owner signed in; getting-started panel shown')

// 3. Owner invites a waiter
await o.goto(`${BASE}/team`)
await o.getByRole('button', { name: /Invite/ }).first().click()
await o.fill('#u-name', 'Walter Waiter')
await o.fill('#u-email', waiter.email)
await o.getByRole('button', { name: 'Send invitation' }).click()
await o.getByText('Invited', { exact: true }).first().waitFor()
step(3, 'waiter invited')

// 4. Owner sells a €100 printable voucher to a new customer, paid in cash
await o.goto(`${BASE}/vouchers/new`)
await o.getByRole('button', { name: /^€\s?100$/ }).click()
await o.getByRole('radio', { name: 'New', exact: true }).click()
await o.fill('#first_name', 'Klara')
await o.fill('#email', `klara-${run}@example.com`)
const [saleResponse] = await Promise.all([
  o.waitForResponse((r) => r.url().endsWith('/api/v1/vouchers') && r.request().method() === 'POST'),
  o.getByRole('button', { name: 'Sell voucher' }).click(),
])
const sale = await saleResponse.json()
const qr = sale.printable.payload
assert.match(qr, /^GCPV1\.[A-Za-z0-9_-]{43}$/)
await o.getByRole('heading', { name: 'Voucher sold' }).waitFor()
await o.getByRole('img', { name: /QR/ }).waitFor()
assert.equal(await o.getByText(sale.data.voucher_number_formatted).count(), 0, 'the voucher number is never on the printable sheet')
await o.getByRole('link', { name: 'Open voucher' }).click()
await o.waitForURL(/\/vouchers\/[0-9a-f-]{36}$/)
await o.getByRole('button', { name: 'More actions' }).waitFor()
step(4, `voucher sold: ${sale.data.voucher_number_formatted}`)

// 5. Waiter scans the printed QR on a phone and redeems €24,90 — timed
const w = await newPage({ ...devices['Pixel 7'], permissions: ['camera'] }, 'waiter')
await w.addInitScript((payload) => {
  window.BarcodeDetector = class {
    async detect() {
      return [{ rawValue: payload }]
    }
  }
}, qr)
await acceptInvitation(w, waiter.email, waiter.password)
await w.waitForURL('**/waiter')
const t0 = Date.now()
await w.getByRole('button', { name: 'Scan voucher QR code' }).click()
await w.getByRole('button', { name: /Full balance/ }).waitFor()
for (const k of ['2', '4', '9', '0']) await w.getByRole('button', { name: k, exact: true }).click()
await w.getByRole('button', { name: /^Redeem/ }).click()
await w.getByText('Remaining balance').waitFor()
const seconds = (Date.now() - t0) / 1000
assert.ok(seconds < 5, `waiter flow took ${seconds}s`)
step(5, `waiter scanned and redeemed € 24,90 in ${seconds.toFixed(2)} s`)

// 6. Owner reloads €20 (cash), then blocks the voucher
await o.reload()
await o.getByRole('button', { name: /Reload/ }).click()
await o.fill('#amount', '20')
await o.getByRole('dialog').getByRole('button', { name: /^Reload/ }).click()
await o.getByText(/loaded/).first().waitFor()
await o.getByRole('button', { name: 'More actions' }).click()
await o.getByRole('menuitem', { name: 'Block voucher' }).click()
await o.getByRole('button', { name: 'Reported lost', exact: true }).click()
await o.getByRole('dialog').getByRole('button', { name: 'Block voucher' }).click()
await o.getByText(/Blocked .*Reported lost/).waitFor()
step(6, 'reloaded € 20 and blocked the voucher')

// 7. The blocked voucher is refused at the table
await w.getByRole('button', { name: 'Next voucher' }).click()
await w.getByRole('button', { name: 'Scan voucher QR code' }).click()
await w.getByText('This voucher is blocked').waitFor()
step(7, 'blocked voucher shown as blocked to the waiter')

// 8. Ledger export opens in Austrian Excel (decimal comma, readable types)
await o.goto(`${BASE}/transactions`)
const [download] = await Promise.all([o.waitForEvent('download'), o.getByRole('button', { name: 'Export CSV' }).click()])
const csv = fs.readFileSync(await download.path(), 'utf8')
assert.match(csv, /;Sale;/)
assert.match(csv, /;-24,90;/)
step(8, `export ok (${csv.trim().split('\n').length - 1} rows)`)

// 9. No accessibility violations on the owner's main screens
for (const url of ['/dashboard', '/vouchers', '/vouchers/new', '/transactions']) {
  await o.goto(BASE + url)
  await o.waitForLoadState('networkidle')
  const { violations } = await new AxeBuilder({ page: o }).withTags(['wcag2a', 'wcag2aa']).analyze()
  assert.deepEqual(violations.map((v) => v.id), [], `axe violations on ${url}`)
}
step(9, 'accessibility scan clean')

// 10. Online sales: the owner sees the Stripe connection (no keys to enter); the guest page of a shop that is not
// switched on says so, without a sign-in.
await o.goto(`${BASE}/settings?tab=online`)
await o.getByText('Payments with Stripe').waitFor()
// Without the platform's Stripe key (this test server) the tab says so; with it, the owner connects with one button.
await o.getByText(/Online sales are not set up on this server yet|Not connected yet/).waitFor()
assert.equal(await o.locator('input[name*="secret" i], input[name*="key" i]').count(), 0, 'no Stripe key fields')
const guest = await newPage(desktop, 'guest')
await guest.goto(`${BASE}/g/pilot-${run}`)
await guest.getByText('Vouchers are not available online right now').waitFor()
assert.ok(!guest.url().includes('/login'), 'the shop page needs no sign-in')
const shopCsp = (await guest.request.get(`${BASE}/g/pilot-${run}`)).headers()['content-security-policy'] ?? ''
assert.match(shopCsp, /'nonce-/)
const { violations: shopViolations } = await new AxeBuilder({ page: guest }).withTags(['wcag2a', 'wcag2aa']).analyze()
assert.deepEqual(shopViolations.map((v) => v.id), [], 'axe violations on the shop page')
step(10, 'online tab shows the Stripe connection; closed shop page public and clean')

// 11. POS systems: the owner creates a one-time connection code for the POS provider.
await o.goto(`${BASE}/settings?tab=pos`)
await o.getByRole('button', { name: 'Create connection code' }).click()
await o.getByText(/^[A-Z2-9]{4}-[A-Z2-9]{4}$/).waitFor()
await o.getByText('No till system connected yet.').waitFor()
// The code is listed as not used yet (without the code itself) and can be revoked.
await o.getByText('Codes not used yet').waitFor()
const { violations: posViolations } = await new AxeBuilder({ page: o }).withTags(['wcag2a', 'wcag2aa']).analyze()
assert.deepEqual(posViolations.map((v) => v.id), [], 'axe violations on the POS tab')
await o.getByRole('button', { name: 'Revoke' }).click()
await o.getByRole('alertdialog').getByRole('button', { name: 'Revoke' }).click()
await o.getByText('Code revoked').waitFor()
await o.getByText('Codes not used yet').waitFor({ state: 'detached' })
step(11, 'POS tab creates a connection code, lists and revokes it')

await browser.close()
assert.deepEqual(errors, [], 'browser console errors')
console.log('\nPilot journey passed.')
