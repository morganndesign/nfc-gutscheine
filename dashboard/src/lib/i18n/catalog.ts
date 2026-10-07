import { common } from "@/lib/i18n/messages/common"
import { design } from "@/lib/i18n/messages/design"
import { errors } from "@/lib/i18n/messages/errors"
import { admin } from "@/lib/i18n/messages/admin"
import { layout } from "@/lib/i18n/messages/layout"
import { manage } from "@/lib/i18n/messages/manage"
import { online } from "@/lib/i18n/messages/online"
import { pos } from "@/lib/i18n/messages/pos"
import { operations } from "@/lib/i18n/messages/operations"
import { vouchers } from "@/lib/i18n/messages/vouchers"

/**
 * Every area's texts. Add an area here when you create `messages/<area>.ts`; keys are `<area>.<name>` and must be
 * unique across areas.
 */
const AREAS = [common, errors, design, layout, vouchers, operations, admin, manage, online, pos] as const

type Area = (typeof AREAS)[number]
type Union<T> = T extends unknown ? keyof T : never
export type MessageKey = Union<Area["en"]>

function merge(language: "en" | "de" | "bs"): Record<MessageKey, string> {
  return Object.assign({}, ...AREAS.map((a) => a[language])) as Record<MessageKey, string>
}

export const CATALOGS = { en: merge("en"), de: merge("de"), bs: merge("bs") }
