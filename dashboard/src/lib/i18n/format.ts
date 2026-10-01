/** Pure helpers of the UI language (no React): usable in tests and formatters. */

export type Language = "de" | "en" | "bs"

export type Params = Record<string, string | number | null | undefined>

export function toLanguage(value: string | null | undefined): Language {
  const code = (value ?? "").toLowerCase().slice(0, 2)
  if (code === "en") return "en"
  if (code === "bs" || code === "hr" || code === "sr") return "bs"
  return "de"
}

/** BCP 47 tag for Intl (dates, relative times) in the UI language. */
export function intlTag(language: Language): string {
  return { de: "de-AT", en: "en-GB", bs: "bs-BA" }[language]
}

const pluralRules = new Map<string, Intl.PluralRules>()

function plural(language: Language, count: number): string {
  let rules = pluralRules.get(language)
  if (!rules) {
    rules = new Intl.PluralRules(intlTag(language))
    pluralRules.set(language, rules)
  }
  return rules.select(count)
}

/**
 * `{name}` placeholders and ICU-style plurals: `{count, plural, one {# voucher} other {# vouchers}}` (`#` is the
 * number; Bosnian uses one/few/other).
 */
export function format(language: Language, template: string, params: Params = {}): string {
  let out = ""
  let i = 0
  while (i < template.length) {
    const open = template.indexOf("{", i)
    if (open < 0) {
      out += template.slice(i)
      break
    }
    out += template.slice(i, open)
    // Find the matching brace (plural branches nest one level).
    let depth = 0
    let close = open
    for (; close < template.length; close++) {
      if (template[close] === "{") depth++
      else if (template[close] === "}" && --depth === 0) break
    }
    const body = template.slice(open + 1, close)
    const match = /^(\w+),\s*plural,\s*([\s\S]*)$/.exec(body)
    if (match) {
      const count = Number(params[match[1]] ?? 0)
      const branches = new Map<string, string>()
      const re = /(=?\w+)\s*\{([^{}]*)\}/g
      let m: RegExpExecArray | null
      while ((m = re.exec(match[2])) !== null) branches.set(m[1], m[2])
      const branch = branches.get(`=${count}`) ?? branches.get(plural(language, count)) ?? branches.get("other") ?? ""
      out += format(language, branch.replaceAll("#", new Intl.NumberFormat(intlTag(language)).format(count)), params)
    } else {
      const value = params[body]
      out += value === null || value === undefined ? "" : String(value)
    }
    i = close + 1
  }
  return out
}
