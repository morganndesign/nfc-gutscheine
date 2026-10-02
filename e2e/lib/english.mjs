// The dashboard speaks German by default (per-user language, de/en/bs). The acceptance tests read English labels, so
// every browser context starts in English and every signed-in account is switched to English, like a user would in
// the account menu.

/** Pre-login pages (login, invitation, reset) follow the stored choice. */
export async function englishContext(context) {
  await context.addInitScript(() => {
    try {
      window.localStorage.setItem('gcp.language', 'en')
    } catch {
      // No storage: the page stays in its default language.
    }
  })
  return context
}

/** The signed-in account's own language (users.locale), then a reload so the UI follows it. */
export async function englishAccount(page) {
  const status = await page.evaluate(async () => {
    const xsrf = decodeURIComponent((document.cookie.match(/(?:^|; )XSRF-TOKEN=([^;]+)/) ?? [])[1] ?? '')
    const response = await fetch('/api/v1/auth/language', {
      method: 'PUT',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-XSRF-TOKEN': xsrf },
      body: JSON.stringify({ locale: 'en' }),
    })
    return response.status
  })
  if (status !== 200) throw new Error(`Switching the account to English failed: HTTP ${status}`)
  await page.reload()
}
