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
