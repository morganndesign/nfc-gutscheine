"use client"

import { useRef, useState } from "react"
import { Check, ImageUp, Loader2, Printer, Trash2 } from "lucide-react"
import { toast } from "sonner"
import { useConfirm } from "@/components/common/confirm"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { useWidth, VoucherPrintPage } from "@/components/vouchers/printable-voucher-sheet"
import { PAPER, ScaledArtwork, type VoucherContent, type VoucherLook } from "@/components/vouchers/voucher-artwork"
import { errorMessage } from "@/lib/api/client"
import { useLogoImage, useRestaurantLogo, useUpdateVoucherSettings } from "@/lib/api/hooks"
import type { RestaurantSettings, VoucherFormat, VoucherTemplate } from "@/lib/api/types"
import { useAuth } from "@/lib/auth"
import { guestCopy } from "@/lib/guest-copy"
import { useT } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/catalog"
import { cn } from "@/lib/utils"

const TEMPLATES: VoucherTemplate[] = ["classic", "minimal", "bold", "elegant"]
const FORMATS: VoucherFormat[] = ["a6", "a5", "a4"]

/** Colour pairs that work on paper (main colour, accent). */
const PALETTES: [string, string][] = [
  ["#0F172A", "#C9A86A"],
  ["#7A1F2B", "#E8C27A"],
  ["#1F3D2B", "#D9B26F"],
  ["#14213D", "#FCA311"],
  ["#2B2B2B", "#E07A5F"],
  ["#F4EDE4", "#9C2F2F"],
  ["#0B4F6C", "#F2C14E"],
  ["#3D2C8D", "#F7B2BD"],
]

const HEX = /^#[0-9A-Fa-f]{6}$/
const MAX_LOGO = 2 * 1024 * 1024

function ColorField({ id, label, value, onChange }: { id: string; label: string; value: string; onChange: (v: string) => void }) {
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>{label}</Label>
      <div className="flex gap-2">
        <input
          type="color"
          aria-label={label}
          value={HEX.test(value) ? value : "#000000"}
          onChange={(e) => onChange(e.target.value.toUpperCase())}
          className="h-9 w-12 shrink-0 cursor-pointer rounded-lg border bg-transparent p-1"
        />
        <Input id={id} value={value} maxLength={7} onChange={(e) => onChange(e.target.value)} className="font-mono" aria-invalid={!HEX.test(value)} />
      </div>
    </div>
  )
}

export function VoucherDesignForm({ settings }: { settings: RestaurantSettings }) {
  const t = useT()
  const confirm = useConfirm()
  const { user } = useAuth()
  const restaurant = user?.restaurant
  const update = useUpdateVoucherSettings()
  const logoMutation = useRestaurantLogo()
  const logo = useLogoImage(settings.logo_url)
  const file = useRef<HTMLInputElement>(null)
  const [previewRef, previewWidth] = useWidth<HTMLDivElement>(340)

  const initial: VoucherLook = {
    template: settings.voucher_design.template,
    format: settings.voucher_design.format,
    brandColor: settings.brand_color,
    accentColor: settings.voucher_design.accent_color,
    headline: settings.voucher_design.headline,
    message: settings.voucher_design.message,
  }
  const [look, setLook] = useState<VoucherLook>(initial)
  const set = <K extends keyof VoucherLook>(key: K, value: VoucherLook[K]) => setLook((l) => ({ ...l, [key]: value }))
  const dirty = JSON.stringify(look) !== JSON.stringify(initial)
  const valid = HEX.test(look.brandColor) && HEX.test(look.accentColor)
  const copy = guestCopy(restaurant?.locale)

  const sample: VoucherContent = {
    restaurantName: restaurant?.name ?? "",
    logo: logo.data ?? null,
    locale: restaurant?.locale,
    value: 5000,
    currency: restaurant?.currency ?? "EUR",
    recipientName: t("design.sampleRecipient"),
    expiresAt: null,
    qrSvg: null,
  }
  const safeLook: VoucherLook = valid ? look : { ...look, brandColor: initial.brandColor, accentColor: initial.accentColor }

  const save = async () => {
    try {
      await update.mutateAsync({
        brand_color: look.brandColor.toUpperCase(),
        voucher_template: look.template,
        voucher_format: look.format,
        accent_color: look.accentColor.toUpperCase(),
        voucher_headline: look.headline?.trim() || null,
        voucher_message: look.message?.trim() || null,
      })
      toast.success(t("design.saved"))
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  const upload = async (picked: File | undefined) => {
    if (!picked) return
    if (picked.size > MAX_LOGO) {
      toast.error(t("design.logoTooBig"))
      return
    }
    try {
      await logoMutation.mutateAsync(picked)
      toast.success(t("design.logoSaved"))
    } catch (e) {
      toast.error(errorMessage(e))
    } finally {
      if (file.current) file.current.value = ""
    }
  }

  const removeLogo = async () => {
    const ok = await confirm({
      title: t("design.logoRemoveTitle"),
      description: t("design.logoRemoveBody"),
      confirmLabel: t("design.logoRemove"),
      destructive: true,
    })
    if (!ok) return
    try {
      await logoMutation.mutateAsync(null)
      toast.success(t("design.logoRemoved"))
    } catch (e) {
      toast.error(errorMessage(e))
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("design.title")}</CardTitle>
        <CardDescription>{t("design.description")}</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_minmax(0,340px)]">
          <div className="space-y-8">
            {/* Template */}
            <section className="space-y-3">
              <h3 className="text-sm font-medium">{t("design.template")}</h3>
              <div role="radiogroup" aria-label={t("design.template")} className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                {TEMPLATES.map((template) => {
                  const active = look.template === template
                  return (
                    <button
                      key={template}
                      type="button"
                      role="radio"
                      aria-checked={active}
                      onClick={() => set("template", template)}
                      className={cn(
                        "group relative flex flex-col items-center gap-2 rounded-2xl border p-2 text-left transition",
                        active ? "border-primary ring-primary/20 ring-4" : "hover:border-foreground/30",
                      )}
                    >
                      <div className="pointer-events-none">
                        <ScaledArtwork look={{ ...safeLook, template, format: "a6" }} content={sample} width={112} />
                      </div>
                      <span className="w-full px-1 text-sm font-medium">{t(`design.template.${template}` as MessageKey)}</span>
                      <span className="text-muted-foreground w-full px-1 text-xs leading-snug">{t(`design.template.${template}.hint` as MessageKey)}</span>
                      {active ? (
                        <span className="bg-primary text-primary-foreground absolute top-3 right-3 flex size-5 items-center justify-center rounded-full">
                          <Check className="size-3" />
                        </span>
                      ) : null}
                    </button>
                  )
                })}
              </div>
            </section>

            {/* Format */}
            <section className="space-y-3">
              <h3 className="text-sm font-medium">{t("design.format")}</h3>
              <div role="radiogroup" aria-label={t("design.format")} className="flex flex-wrap gap-2">
                {FORMATS.map((format) => {
                  const active = look.format === format
                  const paper = PAPER[format]
                  return (
                    <button
                      key={format}
                      type="button"
                      role="radio"
                      aria-checked={active}
                      onClick={() => set("format", format)}
                      className={cn(
                        "flex items-center gap-3 rounded-xl border px-3 py-2 text-sm transition",
                        active ? "border-primary bg-primary/5 font-medium" : "hover:border-foreground/30",
                      )}
                    >
                      <span
                        aria-hidden
                        className="border-foreground/40 inline-block rounded-[2px] border"
                        style={{ width: paper.width / 9, height: paper.height / 9 }}
                      />
                      {t(`design.format.${format}` as MessageKey)}
                    </button>
                  )
                })}
              </div>
            </section>

            {/* Colours */}
            <section className="space-y-3">
              <h3 className="text-sm font-medium">{t("design.colors")}</h3>
              <div className="grid gap-4 sm:grid-cols-2">
                <ColorField id="design-brand" label={t("design.brandColor")} value={look.brandColor} onChange={(v) => set("brandColor", v)} />
                <ColorField id="design-accent" label={t("design.accentColor")} value={look.accentColor} onChange={(v) => set("accentColor", v)} />
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-muted-foreground mr-1 text-xs">{t("design.palettes")}</span>
                {PALETTES.map(([main, accent]) => (
                  <button
                    key={main + accent}
                    type="button"
                    aria-label={`${main} / ${accent}`}
                    onClick={() => setLook((l) => ({ ...l, brandColor: main, accentColor: accent }))}
                    className="flex h-7 overflow-hidden rounded-full border shadow-xs transition hover:scale-105"
                  >
                    <span className="w-6" style={{ background: main }} />
                    <span className="w-3" style={{ background: accent }} />
                  </button>
                ))}
              </div>
            </section>

            {/* Texts */}
            <section className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="design-headline">{t("design.headline")}</Label>
                <Input
                  id="design-headline"
                  value={look.headline ?? ""}
                  maxLength={60}
                  placeholder={copy.headline}
                  onChange={(e) => set("headline", e.target.value)}
                />
                <p className="text-muted-foreground text-xs">{t("design.headlineHint", { fallback: copy.headline })}</p>
              </div>
              <div className="space-y-2">
                <Label htmlFor="design-message">{t("design.message")}</Label>
                <Textarea
                  id="design-message"
                  value={look.message ?? ""}
                  maxLength={240}
                  rows={3}
                  placeholder={t("design.messagePlaceholder")}
                  onChange={(e) => set("message", e.target.value)}
                />
                <p className="text-muted-foreground text-xs">{t("design.charactersLeft", { count: 240 - (look.message?.length ?? 0) })}</p>
              </div>
            </section>

            {/* Logo */}
            <section className="space-y-3">
              <h3 className="text-sm font-medium">{t("design.logo")}</h3>
              <div className="flex flex-wrap items-center gap-4 rounded-2xl border p-4">
                <div className="bg-muted/60 flex h-20 w-36 items-center justify-center rounded-xl bg-[linear-gradient(45deg,transparent_25%,rgba(0,0,0,.04)_25%,rgba(0,0,0,.04)_50%,transparent_50%,transparent_75%,rgba(0,0,0,.04)_75%)] bg-[length:12px_12px] p-2">
                  {logo.data ? (
                    // eslint-disable-next-line @next/next/no-img-element -- data: URL from our API
                    <img src={logo.data} alt={t("design.logo")} className="max-h-full max-w-full object-contain" />
                  ) : (
                    <span className="text-muted-foreground text-xs">{t("design.noLogo")}</span>
                  )}
                </div>
                <div className="min-w-0 flex-1 space-y-2">
                  <p className="text-muted-foreground text-xs">{t("design.logoHint")}</p>
                  <div className="flex flex-wrap gap-2">
                    <input ref={file} type="file" accept="image/png,image/jpeg" className="hidden" onChange={(e) => void upload(e.target.files?.[0])} />
                    <Button type="button" variant="outline" size="sm" disabled={logoMutation.isPending} onClick={() => file.current?.click()}>
                      {logoMutation.isPending ? <Loader2 className="animate-spin" /> : <ImageUp />}
                      {settings.logo_url ? t("design.logoReplace") : t("design.logoUpload")}
                    </Button>
                    {settings.logo_url ? (
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        className="text-destructive"
                        disabled={logoMutation.isPending}
                        onClick={() => void removeLogo()}
                      >
                        <Trash2 /> {t("design.logoRemove")}
                      </Button>
                    ) : null}
                  </div>
                </div>
              </div>
            </section>
          </div>

          {/* Preview */}
          <aside className="space-y-3 lg:sticky lg:top-6 lg:self-start">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-medium">{t("design.preview")}</h3>
              <span className="text-muted-foreground text-xs">{PAPER[look.format].label}</span>
            </div>
            <div ref={previewRef} className="bg-muted/50 flex justify-center rounded-2xl p-4">
              <ScaledArtwork look={safeLook} content={sample} width={Math.min(previewWidth - 32, 300)} />
            </div>
            <div className="flex flex-wrap gap-2">
              <Button type="button" className="flex-1" disabled={!dirty || !valid || update.isPending} onClick={() => void save()}>
                {update.isPending ? <Loader2 className="animate-spin" /> : null}
                {t("common.save")}
              </Button>
              <Button type="button" variant="outline" onClick={() => window.print()} disabled={logo.isLoading}>
                <Printer /> {t("design.testPrint")}
              </Button>
            </div>
            {dirty ? <p className="text-xs font-medium text-amber-600 dark:text-amber-400">{t("design.unsaved")}</p> : null}
            <p className="text-muted-foreground text-xs">{t("design.testPrintHint")}</p>
          </aside>
        </div>
      </CardContent>
      <VoucherPrintPage look={safeLook} content={sample} />
    </Card>
  )
}
