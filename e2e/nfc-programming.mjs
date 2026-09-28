// End-to-end test of NFC programming v2 in a real browser (Chromium, Pixel 7 profile) against the
// running stack. Chromium has no NFC hardware here, so `window.NDEFReader` is replaced by a simulated
// field with NTAG213 / NTAG215 / NTAG216 / NTAG 424 tags that behaves like Chrome on Android:
// the tag stays connected while held, writes that exceed the chip memory fail with NetworkError,
// and a new scan delivers the tag currently on the phone.
//
//   station, one session, no reload — every failure is retried right away with "Try again":
//     NTAG215 → verified + locked · previous tag ignored · NTAG213 → verified ·
//     tag of another active card → refused, not written · NTAG 424 → wrong tag type · locked tag ·
//     tag removed during the write · server unavailable · verification failed · network timeout ·
//     one card skipped · progress, totals, elapsed time and averages
//   single card: the same (locked) tag programmed twice → recognised, nothing written
//   waiter: programmed card scanned with its chip → redeemed; its link on another chip (clone) → rejected
//   server: chips, verified_at, tag types, timings and the attempt log match what happened;
//           the measured timings are printed (simulated tags — not hardware numbers)
//
// Same requirements as pilot-journey.mjs (API + web app, log mailer, platform admin).
//   cd e2e && npm install && node nfc-programming.mjs
import { chromium, devices } from 'playwright'
import { AxeBuilder } from '@axe-core/playwright'
import assert from 'node:assert/strict'
import { invitationLink } from './lib/mail.mjs'

const BASE = process.env.BASE_URL ?? 'http://localhost:3000'
const ADMIN_EMAIL = process.env.ADMIN_EMAIL ?? 'admin@giftcardpro.test'
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD ?? 'Password123!'
const run = Date.now().toString(36)

const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {})
const errors = []
const step = (n, text) => console.log(`${String(n).padStart(2)}. ${text}`)

// ------------------------------------------------------------------ simulated NFC field (runs in the page)
function installFakeNfc() {
  const enc = new TextEncoder()
  const field = { tag: null, readers: new Set(), tags: new Map(), corruptNextUrlWrite: false, removeDuringNextUrlWrite: false }
  const recordSize = (r) => {
    const payload = r.recordType === 'url' ? 1 + enc.encode(r.data.replace(/^https?:\/\/(www\.)?/, '')).length : r.size
    const type = r.recordType === 'url' ? 1 : enc.encode(r.mediaType).length
    return 2 + (payload < 256 ? 1 : 4) + type + payload
  }
  const messageSize = (records) => records.reduce((s, r) => s + recordSize(r), 0)
  const readingEvent = (tag) => {
    const e = new Event('reading')
    e.serialNumber = tag.serial
    e.message = {
      records: tag.records.map((r) =>
        r.recordType === 'url'
          ? { recordType: 'url', data: new DataView(enc.encode(r.data).buffer) }
          : { recordType: 'mime', mediaType: r.mediaType, data: new DataView(new ArrayBuffer(r.size)) },
      ),
    }
    return e
  }
  const waitForTag = (signal) =>
    new Promise((resolve, reject) => {
      const poll = () => {
        if (signal?.aborted) return reject(new DOMException('aborted', 'AbortError'))
        if (field.tag) return resolve(field.tag)
        setTimeout(poll, 20)
      }
      poll()
    })

  class NDEFReader extends EventTarget {
    async scan(options = {}) {
      field.readers.add(this)
      options.signal?.addEventListener('abort', () => field.readers.delete(this))
      // A new scan reads the tag that is already on the phone (fresh read of its memory).
      const tag = field.tag
      if (tag) setTimeout(() => field.readers.has(this) && field.tag === tag && this.dispatchEvent(readingEvent(tag)), 40)
    }
    async write(message, options = {}) {
      const tag = await waitForTag(options.signal)
      await new Promise((r) => setTimeout(r, 30))
      const records = message.records.map((r) =>
        r.recordType === 'url' ? { recordType: 'url', data: r.data } : { recordType: r.recordType, mediaType: r.mediaType, size: r.data.byteLength },
      )
      const size = messageSize(records)
      if (tag.readOnly || size + (size < 255 ? 2 : 4) + 1 > tag.memory) throw new DOMException('Failed to write due to an IO error', 'NetworkError')
      if (records[0].recordType === 'url' && field.removeDuringNextUrlWrite) {
        field.removeDuringNextUrlWrite = false
        field.tag = null
        throw new DOMException('Failed to write due to an IO error', 'NetworkError')
      }
      tag.writes += 1
      if (records[0].recordType === 'url' && field.corruptNextUrlWrite) {
        field.corruptNextUrlWrite = false
        tag.records = [{ recordType: 'url', data: records[0].data.slice(0, -4) }]
      } else {
        tag.records = records
      }
    }
    async makeReadOnly(options = {}) {
      const tag = await waitForTag(options.signal)
      tag.readOnly = true
    }
  }

  window.NDEFReader = NDEFReader
  window.__nfc = {
    /** Holds a tag to the phone (a tag keeps its memory between presentations). */
    present(spec) {
      let tag = field.tags.get(spec.serial)
      if (!tag) {
        tag = { serial: spec.serial, memory: spec.memory, records: spec.url ? [{ recordType: 'url', data: spec.url }] : [], readOnly: !!spec.readOnly, writes: 0 }
        field.tags.set(spec.serial, tag)
      }
      field.tag = tag
      for (const reader of field.readers) reader.dispatchEvent(readingEvent(tag))
    },
    remove() {
      field.tag = null
    },
    inspect(serial) {
      const tag = field.tags.get(serial)
      return tag && { url: tag.records.find((r) => r.recordType === 'url')?.data ?? null, records: tag.records.length, readOnly: tag.readOnly, writes: tag.writes }
    },
    corruptNextUrlWrite() {
      field.corruptNextUrlWrite = true
    },
    removeDuringNextUrlWrite() {
      field.removeDuringNextUrlWrite = true
    },
  }
}

// ------------------------------------------------------------------ helpers
async function newPage(options, who, nfc = false) {
  const context = await browser.newContext(options)
  if (nfc) await context.addInitScript(installFakeNfc)
  const page = await context.newPage()
  page.on('pageerror', (e) => errors.push(`${who}: ${e.message}`))
  page.on('console', (m) => m.type() === 'error' && !/401|409|422|Failed to load resource/.test(m.text()) && errors.push(`${who}: ${m.text()}`))
  return page
}


async function signIn(page, email, password) {
  await page.goto(`${BASE}/login`)
  await page.fill('#email', email)
  await page.fill('#password', password)
  await page.click('button[type=submit]')
  await page.waitForURL((u) => !u.pathname.startsWith('/login'))
}

/** Calls the API with the page's own session, device id and CSRF token. */
function apiCall(page, method, path, body) {
  return page.evaluate(
    async ({ method, path, body }) => {
      const cookie = document.cookie.split('; ').find((c) => c.startsWith('XSRF-TOKEN='))
      const res = await fetch(`/api/v1${path}`, {
        method,
        credentials: 'include',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-Device-Id': localStorage.getItem('gcp.device-id') ?? '',
          'X-XSRF-TOKEN': cookie ? decodeURIComponent(cookie.split('=')[1]) : '',
          'Idempotency-Key': crypto.randomUUID(),
        },
        body: body ? JSON.stringify(body) : undefined,
      })
      return { status: res.status, json: await res.json().catch(() => null) }
    },
    { method, path, body },
  )
}

// Chip serials are unique per run: chips stay bound across runs (platform-wide uniqueness).
const runHex = (BigInt(Date.now()) & 0xffffffffffn).toString(16).padStart(10, '0')
const serial = (n) => `04:${runHex.match(/../g).join(':')}:${n.toString(16).padStart(2, '0')}`
const uidOf = (s) => s.replace(/:/g, '').toUpperCase()

const nfc = (page, fn, arg) => page.evaluate(({ fn, arg }) => window.__nfc[fn](arg), { fn, arg })

// ------------------------------------------------------------------ setup: a new restaurant with an owner and six cards
const desktop = { viewport: { width: 1440, height: 900 } }
const owner = { email: `nfc-owner-${run}@pilot.test`, password: `Owner-${run}-2026` }

const admin = await newPage(desktop, 'admin')
await signIn(admin, ADMIN_EMAIL, ADMIN_PASSWORD)
await admin.getByRole('button', { name: /Onboard restaurant/ }).first().click()
await admin.fill('#r-name', `NFC ${run}`)
await admin.fill('#r-email', `nfc-office-${run}@pilot.test`)
await admin.fill('#o-name', 'Nora Owner')
await admin.fill('#o-email', owner.email)
await admin.getByRole('button', { name: 'Create restaurant' }).click()
await admin.waitForURL('**/admin/restaurants/**')

const phone = await newPage({ ...devices['Pixel 7'] }, 'owner-phone', true)
await phone.goto(await invitationLink(BASE, owner.email))
await phone.getByText('Welcome to GiftCard Pro').waitFor()
await phone.fill('#password', owner.password)
await phone.fill('#confirmation', owner.password)
await phone.click('button[type=submit]')
await phone.waitForURL('**/login**')
await signIn(phone, owner.email, owner.password)

await apiCall(phone, 'GET', '/auth/me')
const CARDS = 10
const created = []
for (let i = 0; i < CARDS; i++) {
  const res = await apiCall(phone, 'POST', '/cards', { value: 2500 + i * 500 })
  assert.equal(res.status, 201, JSON.stringify(res.json))
  created.push(res.json.data)
}
const byNumber = Object.fromEntries(created.map((c) => [c.card_number, c]))
step(1, `restaurant onboarded, owner signed in on a phone with NFC, ${created.length} cards created`)

// ------------------------------------------------------------------ station
await phone.goto(`${BASE}/cards/program`)
await phone.getByRole('heading', { name: 'Program NFC tags' }).waitFor()
await phone.getByRole('switch', { name: 'Lock each tag after verifying' }).click()
await phone.getByRole('button', { name: 'Start programming' }).click()

const dump = async (e) => {
  const main = await phone.evaluate(() => document.body.innerText).catch((x) => String(x))
  throw new Error(`${e.message}\n--- page ---\n${main.slice(0, 2000)}`)
}
const currentCard = async () => {
  const text = (await phone.getByTestId('station-card-number').textContent()).replace(/\D/g, '')
  assert.ok(byNumber[text], `unknown card on screen: ${text}`)
  return byNumber[text]
}
const waitForLogRows = (n) =>
  phone.waitForFunction((n) => document.querySelectorAll('[data-testid=station-log] tr').length >= n, n, { timeout: 20000 }).catch(dump)
const cardApi = async (id) => (await apiCall(phone, 'GET', `/cards/${id}`)).json.data
const nextCardAfter = async (previous) => {
  await phone
    .waitForFunction((prev) => document.querySelector('[data-testid=station-card-number]')?.textContent.replace(/\D/g, '') !== prev, previous.card_number)
    .catch(dump)
  return currentCard()
}
/** Waits for the error panel of one failure class and checks its title. */
const expectError = async (code, title) => {
  const panel = phone.locator(`[role=alert][data-error-code="${code}"]`)
  await panel.waitFor({ timeout: 25000 }).catch(dump)
  const text = await panel.innerText()
  assert.ok(text.includes(title), `${code}: "${text}" should contain "${title}"`)
  return text
}
const retry = () => phone.getByRole('button', { name: 'Try again' }).click()
const progressText = () => phone.getByTestId('station-progress').innerText()

// Card 1: blank NTAG215 → detected, written, read back, verified, saved, locked.
const c1 = await currentCard()
await phone.getByText('Hold a blank tag against the back of the phone.').waitFor()
await nfc(phone, 'present', { serial: serial(1), memory: 504 })
await waitForLogRows(1)
const t1 = await nfc(phone, 'inspect', serial(1))
const s1 = await cardApi(c1.id)
assert.equal(t1.url, s1.card_url, 'tag carries exactly the card URL')
assert.equal(t1.records, 1, 'probe records were replaced by the URL')
assert.equal(t1.readOnly, true)
assert.equal(s1.nfc.uid, uidOf(serial(1)))
assert.equal(s1.nfc.tag_type, 'ntag215')
assert.ok(s1.nfc.verified_at)
assert.equal(s1.nfc.locked, true)
assert.equal(await progressText(), `1 / ${CARDS} cards programmed`)
step(2, `station: ${c1.card_number} ← NTAG215 ${uidOf(serial(1))} detected, written, verified, saved, locked · progress 1 / ${CARDS}`)

// Card 2: the programmed tag is still on the phone and is read again → ignored; then a blank NTAG213.
const c2 = await nextCardAfter(c1)
await nfc(phone, 'present', { serial: serial(1), memory: 504 })
await phone.getByText('Remove the tag you just programmed').waitFor()
assert.equal((await nfc(phone, 'inspect', serial(1))).writes, t1.writes, 'previous tag not touched again')
await nfc(phone, 'present', { serial: serial(2), memory: 144 })
await waitForLogRows(2)
const s2 = await cardApi(c2.id)
assert.equal(s2.nfc.tag_type, 'ntag213')
assert.equal(s2.nfc.uid, uidOf(serial(2)))
assert.equal((await nfc(phone, 'inspect', serial(2))).url, s2.card_url)
step(3, `station: previous tag ignored; ${c2.card_number} ← NTAG213 verified`)

const recovered = []

// Card 3: tag of card 1 (another active card) → refused before anything is written → try again with a blank tag.
const c3 = await nextCardAfter(c2)
const writesBefore = (await nfc(phone, 'inspect', serial(1))).writes
await nfc(phone, 'present', { serial: serial(2), memory: 144 }) // card 2's tag is "previous" → ignored
await nfc(phone, 'present', { serial: serial(1), memory: 504 })
await expectError('TAG_LINKED_TO_OTHER_CARD', 'Tag belongs to another active card')
assert.equal((await nfc(phone, 'inspect', serial(1))).writes, writesBefore, 'refused tag was not written')
assert.equal((await cardApi(c3.id)).nfc.uid, null)
await retry()
await nfc(phone, 'present', { serial: serial(3), memory: 504 })
await waitForLogRows(3)
recovered.push('tag of another active card')

// Card 4: NTAG 424 DNA (256-byte NDEF file) → wrong tag type → try again with an NTAG216.
const c4 = await nextCardAfter(c3)
await nfc(phone, 'present', { serial: serial(40), memory: 256 })
await expectError('TAG_UNSUPPORTED', 'Wrong tag type')
assert.equal((await cardApi(c4.id)).nfc.uid, null)
await retry()
await nfc(phone, 'present', { serial: serial(4), memory: 888 })
await waitForLogRows(4)
assert.equal((await cardApi(c4.id)).nfc.tag_type, 'ntag216')
recovered.push('wrong tag type (NTAG 424)')

// Card 5: a locked tag with foreign content → "Tag is locked", its content untouched → try again.
const c5 = await nextCardAfter(c4)
await nfc(phone, 'present', { serial: serial(50), memory: 504, url: 'https://example.com/menu', readOnly: true })
await expectError('TAG_READ_ONLY', 'Tag is locked')
assert.equal((await nfc(phone, 'inspect', serial(50))).url, 'https://example.com/menu')
await retry()
await nfc(phone, 'present', { serial: serial(5), memory: 504 })
await waitForLogRows(5)
recovered.push('locked tag')

// Card 6: the tag is pulled away while the card link is being written → "Tag removed too early" → hold it again.
const c6 = await nextCardAfter(c5)
await nfc(phone, 'removeDuringNextUrlWrite')
await nfc(phone, 'present', { serial: serial(6), memory: 504 })
await expectError('TAG_REMOVED', 'Tag removed too early')
assert.equal((await cardApi(c6.id)).nfc.uid, null)
await retry()
await nfc(phone, 'present', { serial: serial(6), memory: 504 })
await waitForLogRows(6)
assert.equal((await nfc(phone, 'inspect', serial(6))).url, (await cardApi(c6.id)).card_url)
recovered.push('tag removed during writing')

// Card 7: the server cannot be reached → "Server unavailable" → connection back → try again.
const c7 = await nextCardAfter(c6)
await phone.route('**/api/v1/cards/*/nfc/check', (route) => route.abort('internetdisconnected'))
await nfc(phone, 'present', { serial: serial(7), memory: 504 })
await expectError('SERVER_UNAVAILABLE', 'Server unavailable')
assert.equal((await nfc(phone, 'inspect', serial(7))).writes, 0, 'nothing written without the server check')
await phone.unroute('**/api/v1/cards/*/nfc/check')
await retry()
await nfc(phone, 'present', { serial: serial(7), memory: 504 })
await waitForLogRows(7)
recovered.push('server unavailable')

// Card 8: the tag reads back something else → "Verification failed", nothing saved → try again.
const c8 = await nextCardAfter(c7)
await nfc(phone, 'corruptNextUrlWrite')
await nfc(phone, 'present', { serial: serial(8), memory: 504 })
await expectError('URL_MISMATCH', 'Verification failed')
assert.equal((await cardApi(c8.id)).nfc.uid, null, 'nothing saved after a failed verification')
await retry()
await nfc(phone, 'present', { serial: serial(8), memory: 504 })
await waitForLogRows(8)
recovered.push('verification failed')

// Card 9: the save request gets no answer within 15 s → "Network timeout" → try again. The server did save it
// (the answer was lost), so the retry recognises the tag as already programmed instead of writing it again.
const c9 = await nextCardAfter(c8)
await phone.route('**/api/v1/cards/*/nfc', async (route) => {
  if (route.request().method() !== 'POST') return route.continue()
  const response = await route.fetch()
  await new Promise((r) => setTimeout(r, 16000))
  await route.fulfill({ response }).catch(() => undefined)
})
await nfc(phone, 'present', { serial: serial(9), memory: 504 })
await expectError('NETWORK_TIMEOUT', 'Network timeout')
await phone.unroute('**/api/v1/cards/*/nfc')
const writesAfterTimeout = (await nfc(phone, 'inspect', serial(9))).writes
await retry()
await nfc(phone, 'present', { serial: serial(9), memory: 504 })
await waitForLogRows(9)
assert.match(await phone.getByTestId('station-log').locator('tr').first().innerText(), /Already programmed/)
const s9 = await cardApi(c9.id)
assert.equal(s9.nfc.uid, uidOf(serial(9)))
assert.equal(s9.nfc.locked, true, 'the retry still locks the tag saved before the timeout')
assert.equal((await nfc(phone, 'inspect', serial(9))).writes, writesAfterTimeout, 'not written a second time')
step(4, `station: recovered in the same session, without reload, from: ${recovered.join(', ')}, network timeout (saved once)`)

// Card 10: skipped.
await nextCardAfter(c9)
await phone.getByRole('button', { name: 'Skip card' }).click()
await phone.getByText('All cards programmed').waitFor().catch(dump)
assert.equal(await progressText(), `9 / ${CARDS} cards programmed`)
const stats = await phone.getByTestId('station-stats').innerText()
assert.match(stats, /Successful\s+9/)
assert.match(stats, /Failed attempts\s+7/)
assert.match(stats, /Skipped cards\s+1/)
assert.match(stats, /Elapsed\s+\d+:\d\d/)
assert.match(stats, /Avg\. per card\s+\d+\.\d s/)
assert.match(await phone.getByTestId('station-timing').innerText(), /Tag to saved \d+\.\d s on average · write \d+ ms · read back and verify \d+ ms/)
const axe = await new AxeBuilder({ page: phone }).withTags(['wcag2a', 'wcag2aa']).analyze()
assert.deepEqual(axe.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target).join(', ')}`), [], 'accessibility of the programming station')
step(5, `station finished: "9 / ${CARDS} cards programmed", successful 9, failed attempts 7, skipped 1, elapsed and averages shown; axe clean`)

// ------------------------------------------------------------------ the same tag twice (single card dialog)
await phone.goto(`${BASE}/cards/${c1.id}?write=1`)
await phone.getByRole('dialog').getByText('Program card').first().waitFor()
await phone.getByRole('button', { name: 'Write NFC tag' }).click()
// A page load resets the simulated field: the same physical tag (card 1's link, locked) is held again.
await nfc(phone, 'present', { serial: serial(1), memory: 504, url: s1.card_url, readOnly: true })
await phone.getByText('This tag is already programmed for this card').waitFor()
assert.equal((await nfc(phone, 'inspect', serial(1))).writes, 0, 'nothing written the second time')
await phone.keyboard.press('Escape')
await phone.getByTestId('nfc-attempts').getByText(/^Already programmed/).first().waitFor()
step(6, `same (locked) tag programmed twice for ${c1.card_number}: recognised as already programmed, nothing written`)

// ------------------------------------------------------------------ waiter: read → redeem; clone → rejected
const scan = await apiCall(phone, 'POST', '/scan', { method: 'nfc', token: s2.card_url, nfc_uid: serial(2) })
assert.equal(scan.status, 200)
assert.equal(scan.json.data.id, c2.id)
const redeem = await apiCall(phone, 'POST', `/cards/${c2.id}/redeem`, { amount: 1250 })
assert.equal(redeem.status, 201, JSON.stringify(redeem.json))
assert.equal(redeem.json.data.card.balance, c2.balance - 1250)
const clone = await apiCall(phone, 'POST', '/scan', { method: 'nfc', token: s2.card_url, nfc_uid: serial(99) })
assert.equal(clone.status, 403)
assert.equal(clone.json.code, 'NFC_UID_MISMATCH')
const bare = await apiCall(phone, 'POST', '/scan', { method: 'nfc', token: s2.card_url })
assert.equal(bare.json.code, 'NFC_UID_MISMATCH', 'a tap without a chip serial is refused for a bound card')
step(7, `waiter: ${c2.card_number} read with its chip and € 12,50 redeemed; its link on another chip (clone) and a tap without serial rejected`)

// ------------------------------------------------------------------ attempt log and timings
const attempts = []
for (const c of created) attempts.push(...(await apiCall(phone, 'GET', `/cards/${c.id}/nfc/attempts`)).json.data)
const byCode = (code) => attempts.filter((a) => a.error_code === code)
for (const code of ['TAG_LINKED_TO_OTHER_CARD', 'TAG_UNSUPPORTED', 'TAG_READ_ONLY', 'TAG_REMOVED', 'SERVER_UNAVAILABLE', 'URL_MISMATCH']) {
  assert.equal(byCode(code).length, 1, `${code} logged once: ${JSON.stringify(attempts.map((a) => a.error_code))}`)
}
assert.equal(attempts.filter((a) => a.result === 'in_progress').length, 0, 'no attempt left "in progress"')
assert.equal(attempts.filter((a) => a.result === 'already_programmed').length, 2)
// The timed-out save had reached the server: that attempt is logged as succeeded, the retry as already programmed.
assert.deepEqual(attempts.filter((a) => a.gift_card_id === c9.id).map((a) => a.result).sort(), ['already_programmed', 'succeeded'])
const ok = attempts.filter((a) => a.result === 'succeeded' && a.method === 'web_nfc')
assert.equal(ok.length, 9)
const avg = (key) => Math.round(ok.reduce((s, a) => s + a.timings[key], 0) / ok.length)
const max = (key) => Math.max(...ok.map((a) => a.timings[key]))
step(8, `attempt log complete (${attempts.length} attempts, none left in progress)`)
console.log(`\n   Timings of ${ok.length} successful attempts (simulated tags, local server — NOT hardware numbers):`)
console.log(`     detect  avg ${avg('detect_ms')} ms (max ${max('detect_ms')})`)
console.log(`     write   avg ${avg('write_ms')} ms (max ${max('write_ms')})`)
console.log(`     verify  avg ${avg('verify_ms')} ms (max ${max('verify_ms')})`)
console.log(`     total   avg ${avg('total_ms')} ms (max ${max('total_ms')}) — tag read → chip saved`)

assert.deepEqual(errors, [], `browser errors:\n${errors.join('\n')}`)
await browser.close()
console.log('\nNFC programming E2E passed.')
