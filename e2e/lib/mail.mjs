// Invitation links for the e2e journeys. Local development sends e-mail with MAIL_MAILER=failover: to Mailpit
// when it runs (http://localhost:8025, API /api/v1), otherwise to the Laravel log. Both are read here, Mailpit first.
import assert from 'node:assert/strict'
import fs from 'node:fs'

const MAILPIT = process.env.MAILPIT_URL ?? 'http://localhost:8025'
const LOG_DIR = process.env.LARAVEL_LOG_DIR ?? new URL('../../backend/storage/logs/', import.meta.url).pathname
const LINK = /reset-password#token=([a-f0-9]{64})&(?:amp;)?email=([^&\s"\]<)]+)/g

function lastToken(text, email) {
  let token = null
  for (let m; (m = LINK.exec(text)); ) if (decodeURIComponent(m[2]) === email) token = m[1]
  LINK.lastIndex = 0
  return token
}

async function fromMailpit(email) {
  try {
    const list = await fetch(`${MAILPIT}/api/v1/search?limit=5&query=${encodeURIComponent(`to:"${email}"`)}`)
    if (!list.ok) return null
    const { messages = [] } = await list.json()
    for (const summary of messages) {
      // Newest first.
      const message = await (await fetch(`${MAILPIT}/api/v1/message/${summary.ID}`)).json()
      const token = lastToken(`${message.Text ?? ''}\n${message.HTML ?? ''}`, email)
      if (token) return token
    }
  } catch {
    // Mailpit not running: the e-mail went to the log.
  }
  return null
}

function fromLog(email) {
  if (!fs.existsSync(LOG_DIR)) return null
  const text = fs.readdirSync(LOG_DIR).filter((f) => f.endsWith('.log')).map((f) => fs.readFileSync(LOG_DIR + f, 'utf8')).join('\n')
  return lastToken(text, email)
}

/** The newest invitation link for `email`, waiting up to 10 s for the e-mail to arrive. */
export async function invitationLink(base, email) {
  for (let i = 0; i < 20; i++) {
    const token = (await fromMailpit(email)) ?? fromLog(email)
    if (token) return `${base}/reset-password#token=${token}&email=${encodeURIComponent(email)}&invite=1`
    await new Promise((r) => setTimeout(r, 500))
  }
  assert.fail(`invitation e-mail for ${email} found neither in Mailpit (${MAILPIT}) nor in ${LOG_DIR}`)
}

// Sign-in codes (decision 2026-10-05): "<6 digits> ist Ihr Anmeldecode …" / "… is your … sign-in code" in the subject.
const CODE = /To:\s*([^\r\n]+)\r?\n(?:[^\r\n]*\r?\n){0,6}?Subject:\s*(?:=\?utf-8\?q\?)?(\d{6})[ _]/gi

function codesFromLog(email) {
  if (!fs.existsSync(LOG_DIR)) return []
  const text = fs.readdirSync(LOG_DIR).filter((f) => f.endsWith('.log')).map((f) => fs.readFileSync(LOG_DIR + f, 'utf8')).join('\n')
  const codes = []
  for (let m; (m = CODE.exec(text)); ) if (m[1].toLowerCase().includes(email.toLowerCase())) codes.push(m[2])
  CODE.lastIndex = 0
  return codes
}

async function codesFromMailpit(email) {
  try {
    const list = await fetch(`${MAILPIT}/api/v1/search?limit=50&query=${encodeURIComponent(`to:"${email}"`)}`)
    if (!list.ok) return null
    const { messages = [] } = await list.json()
    return messages.map((m) => /^(\d{6}) /.exec(m.Subject ?? '')?.[1]).filter(Boolean).reverse()
  } catch {
    return null
  }
}

/** How many sign-in codes `email` has received so far (call before submitting the password). */
export async function loginCodeCount(email) {
  return ((await codesFromMailpit(email)) ?? codesFromLog(email)).length
}

/** The sign-in code sent after `before` earlier ones, waiting up to 10 s. */
export async function loginCode(email, before) {
  for (let i = 0; i < 20; i++) {
    const codes = (await codesFromMailpit(email)) ?? codesFromLog(email)
    if (codes.length > before) return codes[codes.length - 1]
    await new Promise((r) => setTimeout(r, 500))
  }
  assert.fail(`sign-in code for ${email} found neither in Mailpit (${MAILPIT}) nor in ${LOG_DIR}`)
}

/** Dashboard sign-in in a browser page: password, then the e-mailed code unless the browser is trusted. */
export async function signInWithCode(page, base, email, password) {
  const before = await loginCodeCount(email)
  await page.goto(`${base}/login`)
  await page.fill('#email', email)
  await page.fill('#password', password)
  await page.click('button[type=submit]')
  const step = await Promise.race([
    page.waitForURL((u) => !u.pathname.startsWith('/login')).then(() => 'in'),
    page.locator('#code').waitFor().then(() => 'code'),
  ])
  if (step === 'code') {
    await page.fill('#code', await loginCode(email, before))
    await page.waitForURL((u) => !u.pathname.startsWith('/login'))
  }
}
