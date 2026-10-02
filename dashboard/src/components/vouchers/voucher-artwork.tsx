"use client"

import { useLayoutEffect, useRef, useState, type CSSProperties, type ReactNode } from "react"
import type { VoucherFormat, VoucherTemplate } from "@/lib/api/types"
import { guestCopy, guestLocale } from "@/lib/guest-copy"
import { formatDate } from "@/lib/format"
import { formatMoney } from "@/lib/money"

/**
 * The printed voucher (P0-03), drawn at its real paper size. Four templates share one content model: the restaurant
 * (logo or name), a headline, the value that was bought (ADR-003: part of the design, not a balance), the recipient,
 * a personal message and the QR — the voucher itself; no voucher number is printed. Everything is sized in `--u`
 * (1 % of the paper width), so A4, A5 and A6 are the same design at three scales, and the QR always keeps a white
 * quiet zone and at least 3 cm on A6.
 */

export const PAPER: Record<VoucherFormat, { width: number; height: number; label: string }> = {
  a4: { width: 210, height: 297, label: "A4" },
  a5: { width: 148, height: 210, label: "A5" },
  a6: { width: 105, height: 148, label: "A6" },
}

export interface VoucherLook {
  template: VoucherTemplate
  format: VoucherFormat
  brandColor: string
  accentColor: string
  headline: string | null
  message: string | null
}

export interface VoucherContent {
  restaurantName: string
  /** data: URL of the logo, if any. */
  logo: string | null
  /** The restaurant's locale: guests read the restaurant's language and number format. */
  locale: string | null | undefined
  /** The value sold, in minor units. */
  value: number
  currency: string
  recipientName: string | null | undefined
  expiresAt: string | null
  /** The voucher's QR as SVG; null draws a sample (settings preview). */
  qrSvg: string | null
}

// ------------------------------------------------------------------------------------------ colour

function rgb(hex: string): [number, number, number] {
  const h = /^#?([0-9a-f]{6})$/i.exec(hex)?.[1] ?? "18181b"
  return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16)) as [number, number, number]
}

function luminance(hex: string): number {
  const [r, g, b] = rgb(hex).map((c) => {
    const v = c / 255
    return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4
  })
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

function contrast(a: string, b: string): number {
  const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p)
  return (x + 0.05) / (y + 0.05)
}

/** Readable ink on a background: white or near-black, whichever contrasts more. */
function inkOn(background: string): string {
  return contrast(background, "#ffffff") >= contrast(background, "#141414") ? "#ffffff" : "#141414"
}

/** The accent where it stays readable on `background`, else the background's ink. */
function accentOn(background: string, accent: string): string {
  return contrast(background, accent) >= 2.2 ? accent : inkOn(background)
}

function mix(hex: string, other: string, amount: number): string {
  const a = rgb(hex)
  const b = rgb(other)
  return `#${a
    .map((c, i) =>
      Math.round(c + (b[i] - c) * amount)
        .toString(16)
        .padStart(2, "0"),
    )
    .join("")}`
}

// ------------------------------------------------------------------------------------------ parts

const SANS = "var(--font-geist-sans), ui-sans-serif, system-ui, sans-serif"
const SERIF = "'Iowan Old Style', 'Palatino Linotype', Palatino, Georgia, 'Times New Roman', serif"

/** n % of the paper width. */
const u = (n: number) => `calc(var(--u) * ${n})`

function svgSrc(svg: string): string {
  const bytes = new TextEncoder().encode(svg)
  let binary = ""
  bytes.forEach((b) => (binary += String.fromCharCode(b)))
  return `data:image/svg+xml;base64,${btoa(binary)}`
}

/** A plausible QR for previews (deterministic, never scannable). */
function sampleQr(): string {
  const n = 25
  let seed = 7
  const rand = () => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648
  const cells: string[] = []
  const finder = (x: number, y: number) => x >= 0 && x < 7 && y >= 0 && y < 7
  for (let y = 0; y < n; y++) {
    for (let x = 0; x < n; x++) {
      const inFinder = finder(x, y) || finder(x - (n - 7), y) || finder(x, y - (n - 7))
      if (inFinder) {
        const fx = x >= n - 7 ? x - (n - 7) : x
        const fy = y >= n - 7 ? y - (n - 7) : y
        const ring = fx === 0 || fx === 6 || fy === 0 || fy === 6
        const core = fx >= 2 && fx <= 4 && fy >= 2 && fy <= 4
        if (ring || core) cells.push(`<rect x="${x}" y="${y}" width="1" height="1"/>`)
      } else if (rand() > 0.52) {
        cells.push(`<rect x="${x}" y="${y}" width="1" height="1"/>`)
      }
    }
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${n} ${n}" shape-rendering="crispEdges"><g fill="#111">${cells.join("")}</g></svg>`
}

const SAMPLE_QR = sampleQr()

function Qr({ svg, size, frame }: { svg: string | null; size: number; frame?: string }) {
  return (
    <div
      style={{
        background: "#ffffff",
        padding: u(size * 0.07),
        borderRadius: u(1.6),
        boxShadow: frame ? `0 0 0 ${u(0.35)} ${frame}` : undefined,
        lineHeight: 0,
      }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element -- generated QR, never optimised or cached */}
      <img src={svgSrc(svg ?? SAMPLE_QR)} alt="QR" style={{ width: u(size), height: u(size), display: "block", imageRendering: "pixelated" }} />
    </div>
  )
}

function Brand({ content, color, align, size }: { content: VoucherContent; color: string; align: "left" | "center"; size: number }) {
  if (content.logo) {
    return (
      // eslint-disable-next-line @next/next/no-img-element -- data: URL, already re-encoded by the server
      <img
        src={content.logo}
        alt={content.restaurantName}
        style={{ maxHeight: u(size), maxWidth: u(size * 3.2), objectFit: "contain", display: "block", margin: align === "center" ? "0 auto" : undefined }}
      />
    )
  }
  return (
    <div style={{ color, fontSize: u(size * 0.42), fontWeight: 650, letterSpacing: "-0.01em", lineHeight: 1.1, textAlign: align }}>
      {content.restaurantName}
    </div>
  )
}

function Fine({ children, color, align = "left" }: { children: ReactNode; color: string; align?: "left" | "center" }) {
  return <div style={{ fontSize: u(2.05), lineHeight: 1.45, color, textAlign: align }}>{children}</div>
}

function texts(content: VoucherContent, look: VoucherLook) {
  const copy = guestCopy(content.locale)
  return {
    copy,
    headline: look.headline?.trim() || copy.headline,
    value: formatMoney(content.value, content.currency, guestLocale(content.locale)),
    recipient: content.recipientName ? `${copy.for} ${content.recipientName}` : null,
    validity: content.expiresAt ? `${copy.validUntil} ${formatDate(content.expiresAt, guestLocale(content.locale))}` : copy.noExpiry,
  }
}

// ------------------------------------------------------------------------------------------ templates

/** Light page, the brand colour as a wide band carrying the value; QR and the small print below. */
function Classic({ look, content }: { look: VoucherLook; content: VoucherContent }) {
  const t = texts(content, look)
  const ink = inkOn(look.brandColor)
  const accent = accentOn(look.brandColor, look.accentColor)
  const rule = accentOn("#ffffff", look.accentColor)
  return (
    <div data-fit style={{ display: "flex", flexDirection: "column", height: "100%", background: "#ffffff", color: "#141414", overflow: "hidden" }}>
      <div style={{ padding: `${u(8)} ${u(9)} ${u(5)}`, display: "flex", alignItems: "center", justifyContent: "space-between", gap: u(4) }}>
        <Brand content={content} color="#141414" align="left" size={11} />
        <div style={{ fontSize: u(2.2), letterSpacing: "0.32em", textTransform: "uppercase", color: rule, fontWeight: 600 }}>{t.copy.voucher}</div>
      </div>
      {/* The band shrinks with the page and clips its own overflow: it is measured too, or a long message is cut off. */}
      <div
        data-fit
        style={{
          background: look.brandColor,
          color: ink,
          margin: `0 ${u(5)}`,
          borderRadius: u(3),
          padding: `${u(9)} ${u(8)}`,
          flex: "1 1 auto",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          position: "relative",
          overflow: "hidden",
        }}
      >
        <div
          aria-hidden
          style={{
            position: "absolute",
            right: u(-14),
            top: u(-14),
            width: u(52),
            height: u(52),
            borderRadius: "50%",
            border: `${u(0.5)} solid ${accent}`,
            opacity: 0.35,
          }}
        />
        <div
          aria-hidden
          style={{
            position: "absolute",
            right: u(-6),
            top: u(-6),
            width: u(36),
            height: u(36),
            borderRadius: "50%",
            border: `${u(0.5)} solid ${accent}`,
            opacity: 0.25,
          }}
        />
        <div style={{ position: "relative" }}>
          <div style={{ fontFamily: SERIF, fontSize: u(6.4), lineHeight: 1.12, fontStyle: "italic", maxWidth: "80%" }}>{t.headline}</div>
          {t.recipient ? <div style={{ marginTop: u(2.4), fontSize: u(3), opacity: 0.85 }}>{t.recipient}</div> : null}
        </div>
        <div style={{ position: "relative" }}>
          <div style={{ fontSize: u(2.1), letterSpacing: "0.28em", textTransform: "uppercase", color: accent, fontWeight: 600 }}>{t.copy.value}</div>
          <div style={{ fontSize: u(14), fontWeight: 700, letterSpacing: "-0.035em", lineHeight: 1, marginTop: u(1.2), fontVariantNumeric: "tabular-nums" }}>
            {t.value}
          </div>
          {look.message ? <div style={{ marginTop: u(4), fontSize: u(2.8), lineHeight: 1.45, opacity: 0.9, maxWidth: "88%" }}>{look.message}</div> : null}
        </div>
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: u(6), padding: `${u(6)} ${u(9)} ${u(8)}` }}>
        <Qr svg={content.qrSvg} size={30} frame={rule} />
        <div style={{ display: "grid", gap: u(1.6) }}>
          <div style={{ fontSize: u(3), fontWeight: 600 }}>{t.copy.howTo}</div>
          <Fine color="#5b5b5b">{t.validity}</Fine>
          <Fine color="#5b5b5b">{t.copy.keepSafe}</Fine>
          {content.logo ? <Fine color="#8a8a8a">{content.restaurantName}</Fine> : null}
        </div>
      </div>
    </div>
  )
}

/** White, quiet, typographic: a thin accent line, a large value in the brand colour, the QR in its own corner. */
function Minimal({ look, content }: { look: VoucherLook; content: VoucherContent }) {
  const t = texts(content, look)
  const brand = accentOn("#ffffff", look.brandColor)
  const accent = accentOn("#ffffff", look.accentColor)
  return (
    <div
      data-fit
      style={{
        height: "100%",
        background: "#ffffff",
        color: "#141414",
        padding: `${u(11)} ${u(11)}`,
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
      }}
    >
      <Brand content={content} color="#141414" align="left" size={10} />
      <div style={{ marginTop: u(16), fontSize: u(2.2), letterSpacing: "0.4em", textTransform: "uppercase", color: "#6b6b6b" }}>{t.copy.voucher}</div>
      <div style={{ width: u(12), height: u(0.6), background: accent, margin: `${u(3.5)} 0` }} />
      <div style={{ fontSize: u(5.6), fontWeight: 300, lineHeight: 1.18, letterSpacing: "-0.01em", maxWidth: "85%" }}>{t.headline}</div>
      <div
        style={{
          fontSize: u(17),
          fontWeight: 700,
          letterSpacing: "-0.045em",
          lineHeight: 1,
          color: brand,
          marginTop: u(7),
          fontVariantNumeric: "tabular-nums",
        }}
      >
        {t.value}
      </div>
      {t.recipient ? <div style={{ marginTop: u(3), fontSize: u(3), color: "#3c3c3c" }}>{t.recipient}</div> : null}
      {look.message ? <div style={{ marginTop: u(5), fontSize: u(2.8), lineHeight: 1.5, color: "#3c3c3c", maxWidth: "75%" }}>{look.message}</div> : null}
      <div style={{ flex: "1 1 auto" }} />
      <div
        style={{ display: "flex", alignItems: "flex-end", justifyContent: "space-between", gap: u(6), borderTop: `${u(0.25)} solid #e4e4e4`, paddingTop: u(6) }}
      >
        <div style={{ display: "grid", gap: u(1.6), maxWidth: "52%" }}>
          <div style={{ fontSize: u(2.8), fontWeight: 600 }}>{t.copy.howTo}</div>
          <Fine color="#6b6b6b">{t.validity}</Fine>
          <Fine color="#6b6b6b">{t.copy.keepSafe}</Fine>
        </div>
        <Qr svg={content.qrSvg} size={28} />
      </div>
    </div>
  )
}

/** Full-bleed brand colour, a huge value in the accent, the QR on a white card. */
function Bold({ look, content }: { look: VoucherLook; content: VoucherContent }) {
  const t = texts(content, look)
  const ink = inkOn(look.brandColor)
  const accent = accentOn(look.brandColor, look.accentColor)
  const soft = mix(look.brandColor, ink, 0.12)
  return (
    <div
      data-fit
      style={{
        height: "100%",
        background: look.brandColor,
        color: ink,
        padding: u(9),
        display: "flex",
        flexDirection: "column",
        position: "relative",
        overflow: "hidden",
      }}
    >
      <div aria-hidden style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
        <div style={{ position: "absolute", left: u(-30), bottom: u(-40), width: u(120), height: u(120), borderRadius: "50%", background: soft }} />
      </div>
      <div style={{ position: "relative", display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: u(4) }}>
        <div style={{ background: content.logo ? "#ffffff" : "transparent", borderRadius: u(2.5), padding: content.logo ? `${u(2.2)} ${u(3)}` : 0 }}>
          <Brand content={content} color={ink} align="left" size={9} />
        </div>
        <div
          style={{
            border: `${u(0.4)} solid ${accent}`,
            color: accent,
            borderRadius: 999,
            padding: `${u(1)} ${u(3)}`,
            fontSize: u(2.1),
            letterSpacing: "0.3em",
            textTransform: "uppercase",
            fontWeight: 700,
          }}
        >
          {t.copy.voucher}
        </div>
      </div>
      <div style={{ position: "relative", marginTop: u(14), fontSize: u(8.5), fontWeight: 800, lineHeight: 1.02, letterSpacing: "-0.03em", maxWidth: "92%" }}>
        {t.headline}
      </div>
      <div
        style={{
          position: "relative",
          fontSize: u(22),
          fontWeight: 800,
          letterSpacing: "-0.055em",
          lineHeight: 0.95,
          color: accent,
          marginTop: u(6),
          fontVariantNumeric: "tabular-nums",
        }}
      >
        {t.value}
      </div>
      {t.recipient ? <div style={{ position: "relative", marginTop: u(3.5), fontSize: u(3.2), fontWeight: 600 }}>{t.recipient}</div> : null}
      {look.message ? (
        <div style={{ position: "relative", marginTop: u(3.5), fontSize: u(2.9), lineHeight: 1.45, opacity: 0.9, maxWidth: "80%" }}>{look.message}</div>
      ) : null}
      <div style={{ flex: "1 1 auto" }} />
      <div
        style={{
          position: "relative",
          background: "#ffffff",
          color: "#141414",
          borderRadius: u(4),
          padding: u(5),
          display: "flex",
          gap: u(5),
          alignItems: "center",
        }}
      >
        <Qr svg={content.qrSvg} size={27} />
        <div style={{ display: "grid", gap: u(1.6) }}>
          <div style={{ fontSize: u(3), fontWeight: 700 }}>{t.copy.howTo}</div>
          <Fine color="#5b5b5b">{t.validity}</Fine>
          <Fine color="#5b5b5b">{t.copy.keepSafe}</Fine>
        </div>
      </div>
    </div>
  )
}

/** Dark and festive: a double frame in the accent colour, serif type, everything centred. */
function Elegant({ look, content }: { look: VoucherLook; content: VoucherContent }) {
  const t = texts(content, look)
  const ground = luminance(look.brandColor) > 0.35 ? mix(look.brandColor, "#000000", 0.72) : look.brandColor
  const ink = inkOn(ground)
  const accent = accentOn(ground, look.accentColor)
  return (
    <div style={{ height: "100%", background: ground, color: ink, padding: u(5) }}>
      <div style={{ height: "100%", border: `${u(0.35)} solid ${accent}`, padding: u(1.4) }}>
        <div
          data-fit
          style={{
            height: "100%",
            border: `${u(0.15)} solid ${accent}`,
            padding: `${u(7)} ${u(7)} ${u(6)}`,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            textAlign: "center",
            overflow: "hidden",
          }}
        >
          {content.logo ? (
            <div style={{ background: "#ffffff", borderRadius: u(2), padding: `${u(2)} ${u(3)}` }}>
              <Brand content={content} color="#141414" align="center" size={9} />
            </div>
          ) : (
            <div style={{ fontFamily: SERIF, fontSize: u(4.4), letterSpacing: "0.08em" }}>{content.restaurantName}</div>
          )}
          <div style={{ marginTop: u(5), fontSize: u(2.1), letterSpacing: "0.5em", textTransform: "uppercase", color: accent }}>{t.copy.voucher}</div>
          <div style={{ display: "flex", alignItems: "center", gap: u(2.5), color: accent, margin: `${u(2.4)} 0`, fontSize: u(2.2) }}>
            <span style={{ width: u(10), height: u(0.2), background: accent }} />◆<span style={{ width: u(10), height: u(0.2), background: accent }} />
          </div>
          <div style={{ fontFamily: SERIF, fontStyle: "italic", fontSize: u(6.6), lineHeight: 1.12, maxWidth: "90%" }}>{t.headline}</div>
          {t.recipient ? <div style={{ marginTop: u(3), fontFamily: SERIF, fontSize: u(3.3), opacity: 0.9 }}>{t.recipient}</div> : null}
          <div
            style={{ fontFamily: SERIF, fontSize: u(13.5), lineHeight: 1, marginTop: u(4.5), color: accent, fontVariantNumeric: "lining-nums tabular-nums" }}
          >
            {t.value}
          </div>
          {look.message ? <div style={{ marginTop: u(3), fontSize: u(2.6), lineHeight: 1.45, opacity: 0.88, maxWidth: "82%" }}>{look.message}</div> : null}
          <div style={{ flex: "1 1 auto", minHeight: u(4) }} />
          <Qr svg={content.qrSvg} size={23} frame={accent} />
          <div style={{ marginTop: u(3), fontSize: u(2.5), fontWeight: 500 }}>{t.copy.howTo}</div>
          <div style={{ marginTop: u(1.2), display: "grid", gap: u(0.8) }}>
            <Fine color={mix(ink, ground, 0.3)} align="center">
              {t.validity}
            </Fine>
            <Fine color={mix(ink, ground, 0.3)} align="center">
              {t.copy.keepSafe}
            </Fine>
          </div>
        </div>
      </div>
    </div>
  )
}

const TEMPLATES: Record<VoucherTemplate, (p: { look: VoucherLook; content: VoucherContent }) => ReactNode> = {
  classic: Classic,
  minimal: Minimal,
  bold: Bold,
  elegant: Elegant,
}

/**
 * One voucher at its paper size in millimetres. On screen, wrap it in {@link ScaledArtwork}; in print it fills the
 * page exactly (`@page` margin 0).
 */
export function VoucherArtwork({ look, content, className }: { look: VoucherLook; content: VoucherContent; className?: string }) {
  const paper = PAPER[look.format]
  const Template = TEMPLATES[look.template] ?? Classic
  const root = useRef<HTMLDivElement>(null)
  const [fit, setFit] = useState(1)

  // Long headlines or messages: shrink the whole design (type, spacing, QR) until it fits the page, never clip it.
  useLayoutEffect(() => {
    const el = root.current
    if (!el || el.offsetParent === null) return
    const overflows = () => Array.from(el.querySelectorAll<HTMLElement>("[data-fit]")).some((b) => b.scrollHeight > b.clientHeight + 1)
    el.style.setProperty("--k", "1")
    let k = 1
    if (overflows()) {
      // The largest scale that fits (binary search; layout is re-measured at each step).
      let [low, high] = [0.5, 1]
      for (let i = 0; i < 8; i++) {
        const mid = (low + high) / 2
        el.style.setProperty("--k", String(mid))
        if (overflows()) high = mid
        else low = mid
      }
      k = low
      el.style.setProperty("--k", String(k))
    }
    setFit(k)
  }, [look, content])

  const style = {
    "--k": fit,
    "--u": `calc(${paper.width / 100}mm * var(--k))`,
    width: `${paper.width}mm`,
    height: `${paper.height}mm`,
    fontFamily: SANS,
    overflow: "hidden",
    position: "relative",
    boxSizing: "border-box",
    WebkitPrintColorAdjust: "exact",
    printColorAdjust: "exact",
  } as CSSProperties
  return (
    <div ref={root} className={className} style={style} data-voucher-artwork>
      <Template look={look} content={content} />
    </div>
  )
}

/** px per mm at the CSS reference resolution. */
const MM = 96 / 25.4

/** The artwork scaled to `width` pixels (previews, the sale screen). */
export function ScaledArtwork({ look, content, width }: { look: VoucherLook; content: VoucherContent; width: number }) {
  const paper = PAPER[look.format]
  const scale = width / (paper.width * MM)
  return (
    <div
      style={{
        width,
        height: paper.height * MM * scale,
        overflow: "hidden",
        borderRadius: 12,
        boxShadow: "0 1px 2px rgb(0 0 0 / .06), 0 12px 32px -12px rgb(0 0 0 / .25)",
      }}
    >
      <div style={{ transform: `scale(${scale})`, transformOrigin: "top left" }}>
        <VoucherArtwork look={look} content={content} />
      </div>
    </div>
  )
}
