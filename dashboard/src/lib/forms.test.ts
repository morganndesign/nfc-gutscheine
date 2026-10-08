import assert from "node:assert/strict"
import { readdirSync, readFileSync, statSync } from "node:fs"
import { join } from "node:path"
import { test } from "node:test"

/**
 * Security sweep (security/README.md): a form submitted before the page's JavaScript has loaded must never put what
 * was typed (e-mail, password, names) into the URL — browser history, proxy logs. Every form is method="post".
 */
function files(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name)
    return statSync(path).isDirectory() ? files(path) : path.endsWith(".tsx") ? [path] : []
  })
}

test("every form posts, so typed values never land in the URL", () => {
  const offenders: string[] = []
  for (const file of files(new URL("..", import.meta.url).pathname)) {
    readFileSync(file, "utf8")
      .split("\n")
      .forEach((line, i) => {
        if (/<form(\s|$)/.test(line) && !line.includes('method="post"')) offenders.push(`${file}:${i + 1}`)
      })
  }
  assert.deepEqual(offenders, [])
})
