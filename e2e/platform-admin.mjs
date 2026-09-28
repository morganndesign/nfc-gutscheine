// End-to-end acceptance test: platform administration, in a real browser.
//
//   onboard a restaurant (owner invited) → list shows owner / e-mail / status / invitation → edit →
//   invite again with a corrected e-mail address → owner accepts → disable / enable → archive / restore →
//   delete refused for a restaurant with gift cards → delete an empty restaurant with typed confirmation →
//   audit log filtered by restaurant → accessibility scan of the admin screens.
//
// Requirements: as pilot-journey.mjs (API + web app with MAIL_MAILER=log and LOG_LEVEL=debug, a platform
// admin). With the log mailer the platform reports e-mails as "not delivered", which this test expects.
//
//   cd e2e && npm install && ADMIN_EMAIL=… ADMIN_PASSWORD=… npm run test:admin
import { chromium } from 'playwright'
import { AxeBuilder } from '@axe-core/playwright'
import assert from 'node:assert/strict'
import fs from 'node:fs'

const BASE = process.env.BASE_URL ?? 'http://localhost:3000'
const ADMIN_EMAIL = process.env.ADMIN_EMAIL ?? 'admin@giftcardpro.test'
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD ?? 'Password123!'
const LOG_DIR = process.env.LARAVEL_LOG_DIR ?? new URL('../backend/storage/logs/', import.meta.url).pathname
const run = Date.now().toString(36)

const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {})
const errors = []
const step = (n, text) => console.log(`${String(n).padStart(2)}. ${text}`)

async function newPage(who) {
  const page = await (await browser.newContext({ viewport: { width: 1440, height: 900 } })).newPage()
  page.on('pageerror', (e) => errors.push(`${who}: ${e.message}`))
  // 4xx answers the test provokes on purpose (refused delete, undelivered invitation) are not errors.
  page.on('console', (m) => m.type() === 'error' && !/40[19]|422|Failed to load resource/.test(m.text()) && errors.push(`${who}: ${m.text()}`))
  return page
}

function invitationLink(email) {
  const text = fs.readdirSync(LOG_DIR).filter((f) => f.endsWith('.log')).map((f) => fs.readFileSync(LOG_DIR + f, 'utf8')).join('\n')
  const re = /reset-password\?token=([a-f0-9]{64})&(?:amp;)?email=([^&\s"\]]+)/g
  let token = null
  for (let m; (m = re.exec(text)); ) if (decodeURIComponent(m[2]) === email) token = m[1]
  assert.ok(token, `invitation e-mail for ${email} not found in ${LOG_DIR}`)
  return `${BASE}/reset-password?token=${token}&email=${encodeURIComponent(email)}&invite=1`
}

async function signIn(page, email, password) {
  await page.goto(`${BASE}/login`)
  await page.fill('#email', email)
  await page.fill('#password', password)
  await page.click('button[type=submit]')
  await page.waitForURL((u) => !u.pathname.startsWith('/login'))
}

async function axe(page, where) {
  const { violations } = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze()
  assert.deepEqual(violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target).join(', ')}`), [], `axe violations on ${where}`)
}
const toast = (page, text) => page.locator('[data-sonner-toast]').filter({ hasText: text }).first().waitFor()
const row = (page, name) => page.getByRole('row').filter({ hasText: name })
async function openList(page, search, filter = 'All') {
  await page.goto(`${BASE}/admin`)
  await page.getByRole('radio', { name: filter }).click()
  await page.getByPlaceholder(/Search by restaurant/).fill(search)
  await row(page, search).first().waitFor()
}
async function menu(page, name, item) {
  await page.getByRole('button', { name: `Actions for ${name}` }).click()
  await page.getByRole('menuitem', { name: item }).click()
}

const name = `Admin E2E ${run}`
const typo = `ownr-${run}@admin.test`
const owner = { name: 'Petra Pending', email: `owner-${run}@admin.test`, password: `Owner-${run}-2026` }

// 1. Onboard: restaurant + owner account; the log mailer means "created, invitation not delivered".
const admin = await newPage('admin')
await signIn(admin, ADMIN_EMAIL, ADMIN_PASSWORD)
await admin.goto(`${BASE}/admin`)
await admin.getByRole('alert').filter({ hasText: 'E-mails are not delivered' }).waitFor()
await admin.getByRole('button', { name: /Onboard restaurant/ }).first().click()
await admin.fill('#r-name', name)
await admin.fill('#o-name', owner.name)
await admin.fill('#o-email', typo)
await admin.getByRole('button', { name: 'Create restaurant' }).click()
await toast(admin, 'the invitation was not delivered')
await admin.waitForURL('**/admin/restaurants/**')
const restaurantUrl = admin.url()
await admin.getByText('Invitation not delivered').first().waitFor()
step(1, 'restaurant onboarded; undelivered invitation reported')

// 2. List: Restaurant · Owner · Email · Status · Created · Actions.
await openList(admin, name)
const headers = (await admin.getByRole('columnheader').allInnerTexts()).map((h) => h.trim()).filter(Boolean)
assert.deepEqual(headers, ['Restaurant', 'Owner', 'Email', 'Status', 'Created', 'Actions'])
const cells = await row(admin, name).first().innerText()
for (const text of [owner.name, typo, 'Active', 'Invitation not delivered']) assert.ok(cells.includes(text), `row shows "${text}": ${cells}`)
step(2, 'list shows owner, e-mail, status and invitation state')

// 3. Edit.
await menu(admin, name, 'Edit')
await admin.fill('#edit-city', 'Graz')
await admin.fill('#edit-plan', 'pro')
await admin.getByRole('button', { name: 'Save' }).click()
await toast(admin, 'Restaurant saved')
await admin.goto(restaurantUrl)
await admin.getByText('Plan: pro').waitFor()
await admin.getByText(/Graz/).first().waitFor()
await axe(admin, 'restaurant detail')
step(3, 'restaurant edited (city, plan)')

// 4. Invite again with the corrected address; the correction is kept although delivery is not possible here.
await openList(admin, name)
await menu(admin, name, 'Invite again')
await admin.fill('#invite-email', owner.email)
await admin.getByRole('button', { name: 'Send invitation' }).click()
await toast(admin, 'MAIL_MAILER')
await admin.keyboard.press('Escape')
await openList(admin, name)
assert.ok((await row(admin, name).first().innerText()).includes(owner.email), 'corrected e-mail address shown')
step(4, 'invitation sent again to the corrected address')

// 5. The owner accepts the newest link; the admin sees the account as active.
const ownerPage = await newPage('owner')
await ownerPage.goto(invitationLink(owner.email))
await ownerPage.getByText('Welcome to GiftCard Pro').waitFor()
await ownerPage.fill('#password', owner.password)
await ownerPage.fill('#confirmation', owner.password)
await ownerPage.click('button[type=submit]')
await ownerPage.waitForURL('**/login**')
await signIn(ownerPage, owner.email, owner.password)
await openList(admin, name)
assert.ok(!(await row(admin, name).first().innerText()).includes('Invitation'), 'no invitation badge after acceptance')
await admin.getByRole('button', { name: `Actions for ${name}` }).click()
assert.equal(await admin.getByRole('menuitem', { name: 'Invite again' }).count(), 0, 'no "Invite again" for an active owner')
await admin.keyboard.press('Escape')
step(5, 'owner accepted the invitation and signed in')

// 6. Disable / enable.
await menu(admin, name, 'Disable')
await admin.getByRole('button', { name: 'Unpaid invoice' }).click()
await admin.getByRole('dialog').getByRole('button', { name: 'Disable' }).click()
await toast(admin, 'disabled')
await openList(admin, name, 'Disabled')
await menu(admin, name, 'Enable')
await toast(admin, 'enabled')
step(6, 'disabled and enabled')

// 7. Archive / restore.
await openList(admin, name)
await menu(admin, name, 'Archive')
await admin.getByRole('dialog').getByRole('button', { name: 'Archive' }).click()
await toast(admin, 'archived')
await openList(admin, name, 'Archived')
assert.ok((await row(admin, name).first().innerText()).includes('Archived'))
await menu(admin, name, 'Restore')
await toast(admin, 'restored')
step(7, 'archived and restored')

// 8. A restaurant with gift cards cannot be deleted (only when the demo data exists).
await admin.goto(`${BASE}/admin`)
await admin.getByPlaceholder(/Search by restaurant/).fill('Bella Vista')
if (await row(admin, 'Bella Vista').first().waitFor({ timeout: 5000 }).then(() => true, () => false)) {
  await menu(admin, 'Trattoria Bella Vista', 'Delete')
  await admin.fill('#delete-confirm', 'bella-vista')
  await admin.getByRole('button', { name: 'Delete permanently' }).click()
  await admin.getByRole('dialog').getByText(/cannot be deleted\. Archive it instead/).waitFor()
  await admin.keyboard.press('Escape')
  step(8, 'delete refused for a restaurant with gift cards')
} else {
  step(8, 'delete refusal skipped (no demo data)')
}

// 9. Delete the empty test restaurant: typed confirmation required.
await admin.goto(restaurantUrl)
await admin.getByRole('button', { name: 'Delete' }).click()
const confirmButton = admin.getByRole('button', { name: 'Delete permanently' })
assert.ok(await confirmButton.isDisabled(), 'delete needs the typed confirmation')
const slug = (await admin.getByRole('dialog').locator('label span.font-mono').innerText()).trim()
await admin.fill('#delete-confirm', slug)
await confirmButton.click()
await toast(admin, 'was deleted')
await admin.waitForURL(`${BASE}/admin`)
await admin.getByPlaceholder(/Search by restaurant/).fill(name)
await admin.getByText('No matching restaurants').waitFor()
step(9, 'empty restaurant deleted after typed confirmation')

// 10. Audit trail and accessibility.
await admin.goto(`${BASE}/admin/audit`)
await admin.getByLabel('Filter by action').fill('restaurant.deleted')
await admin.getByRole('row').filter({ hasText: /deleted/i }).first().waitFor()
for (const path of ['/admin', '/admin/settings', '/admin/audit']) {
  await admin.goto(`${BASE}${path}`)
  await admin.waitForLoadState('networkidle')
  await axe(admin, path)
}
step(10, 'audit log filter and accessibility scan clean')

await browser.close()
assert.deepEqual(errors, [], 'browser console errors')
console.log('\nPlatform admin journey passed.')
