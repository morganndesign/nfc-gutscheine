#!/usr/bin/env python3
"""Renders the GiftCard Waiter app mark and every platform file derived from it.

Spec: 10 §2.1 (iOS app icon), §2.2 (Android adaptive icon), §2.3 (splash),
§3.3 (custom glyph `ic_card_arcs`), 03a §1 (S01 splash).

One geometry, many outputs ("one master, generated outputs", 10 §1):

  assets/icons/ic_card_arcs.svg                     glyph (24 grid, 2 arcs, currentColor)
  tool/brand/app-mark*.svg                          1024 masters (default, dark, tinted,
                                                    monochrome, launch)
  ios/Runner/Assets.xcassets/AppIcon.appiconset     single-size 1024 icon + dark + tinted
  ios/Runner/Assets.xcassets/LaunchMark.imageset    launch mark PDF (light + dark)
  ios/Runner/Assets.xcassets/LaunchBackground.colorset
  android/app/src/main/res/drawable/ic_launcher_{background,foreground,monochrome}.xml
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher{,_round}.xml
  android/app/src/main/res/mipmap-*/ic_launcher.png legacy raster (pre-API-26 fallback)
  android/app/src/main/res/drawable/splash_icon.xml Android 12+ splash icon (288 dp canvas)
  android/app/src/main/res/drawable{,-night}-*/splash_icon_legacy.png  API 28–30 splash

Requirements: Python 3.10+, Pillow, cairosvg (`pip install cairosvg pillow`).
Run from the app root:  python3 tool/render_brand_assets.py
"""

from __future__ import annotations

import io
import json
import math
import os
import shutil

import cairosvg
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Tokens (04 Appendix A) used by the brand assets.
INK = "#0F172A"                       # color.brand.ink
WHITE = "#FFFFFF"
SAFFRON = {"light": "#E8A33D", "dark": "#F0B454"}   # color.accent.saffron
CANVAS = {"light": "#FAFAFA", "dark": "#0A0A0C"}    # color.bg.canvas
FG_PRIMARY = {"light": "#18181B", "dark": "#F4F4F5"}  # color.fg.primary
TINT_GREY = "#D4D4D8"                 # light grey arcs of the tinted icon (10 §2.1)

# ---------------------------------------------------------------- geometry
# The card: ID-1 proportion (1.586 : 1), 2-unit corner radius on a 20-unit
# card, tilted −8° (10 §3.3). NFC arcs sit outside the card's top-right
# corner, opening to the upper right like the printed card's arcs.
CARD_W, CARD_H = 20.0, 20.0 / 1.586
CARD_R = 2.0             # refined below so the glyph radius is 2 grid units
TILT = -8.0
ARC_INSET = 2.0          # arc centre: inset from the corner along both edges
ARC_R0 = 5.0             # first arc radius (clears the rounded corner)
ARC_STEP = 3.0           # radial spacing of the arcs, card units
GLYPH_STROKE = 1.75      # icon base stroke (04 §11.2)


def _rot(x: float, y: float, deg: float) -> tuple[float, float]:
    t = math.radians(deg)
    return x * math.cos(t) - y * math.sin(t), x * math.sin(t) + y * math.cos(t)


class Mark:
    """Card + arcs in a local frame (card centre at the origin)."""

    def __init__(self, arcs: int):
        self.arcs = arcs
        # Arc centre just inside the top-right corner, so the arcs emanate
        # from the corner and clear the card edge.
        self.corner = _rot(CARD_W / 2 - ARC_INSET, -CARD_H / 2 + ARC_INSET, TILT)
        self.radii = [ARC_R0 + ARC_STEP * i for i in range(arcs)]

    def card_points(self, n: int = 180) -> list[tuple[float, float]]:
        """Outline samples of the rotated rounded rectangle (for fitting)."""
        pts = []
        hw, hh, r = CARD_W / 2, CARD_H / 2, CARD_R
        for cx, cy, a0 in ((hw - r, -hh + r, -90), (hw - r, hh - r, 0),
                           (-hw + r, hh - r, 90), (-hw + r, -hh + r, 180)):
            for i in range(n // 4 + 1):
                a = math.radians(a0 + 90 * i / (n // 4))
                pts.append(_rot(cx + r * math.cos(a), cy + r * math.sin(a), TILT))
        return pts

    def arc_points(self, n: int = 40) -> list[tuple[float, float]]:
        pts = []
        for r in self.radii:
            for i in range(n + 1):
                a = math.radians(TILT + 90 * i / n)   # compass 0..90, tilted
                pts.append((self.corner[0] + r * math.sin(a),
                            self.corner[1] - r * math.cos(a)))
        return pts


class Placement:
    """Uniform scale + translation from mark units to artboard units."""

    def __init__(self, s: float, tx: float, ty: float):
        self.s, self.tx, self.ty = s, tx, ty

    def p(self, x: float, y: float) -> tuple[float, float]:
        return x * self.s + self.tx, y * self.s + self.ty


def fit_box(mark: Mark, box: tuple[float, float, float, float], pad: float) -> Placement:
    """Fits the mark (plus [pad] artboard units of stroke) centred in [box]."""
    pts = mark.card_points() + mark.arc_points()
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    x0, y0, x1, y1 = box
    s = min((x1 - x0 - 2 * pad) / w, (y1 - y0 - 2 * pad) / h)
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    return Placement(s, (x0 + x1) / 2 - cx * s, (y0 + y1) / 2 - cy * s)


def fit_circle(mark: Mark, centre: tuple[float, float], radius: float, pad: float) -> Placement:
    """Fits the mark inside a circle (Android safe zones), centred on its bbox."""
    pts = mark.card_points() + mark.arc_points()
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    far = max(math.hypot(x - cx, y - cy) for x, y in pts)
    s = (radius - pad) / far
    return Placement(s, centre[0] - cx * s, centre[1] - cy * s)


def _f(v: float) -> str:
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def card_path(mark: Mark, pl: Placement) -> str:
    """Rounded, rotated card as an SVG path (arcs as SVG 'A' commands)."""
    hw, hh, r = CARD_W / 2, CARD_H / 2, CARD_R
    # Corners clockwise from top-left; each: (start of edge after corner arc).
    seq = [
        ((-hw + r, -hh), (hw - r, -hh)),
        ((hw, -hh + r), (hw, hh - r)),
        ((hw - r, hh), (-hw + r, hh)),
        ((-hw, hh - r), (-hw, -hh + r)),
    ]
    rr = _f(r * pl.s)

    def q(x: float, y: float) -> str:
        X, Y = pl.p(*_rot(x, y, TILT))
        return f"{_f(X)} {_f(Y)}"

    d = f"M{q(*seq[0][0])}"
    for i, (_, end) in enumerate(seq):
        d += f"L{q(*end)}"
        nxt = seq[(i + 1) % 4][0]
        d += f"A{rr} {rr} 0 0 1 {q(*nxt)}"
    return d + "Z"


def arc_paths(mark: Mark, pl: Placement) -> list[str]:
    out = []
    for r in mark.radii:
        a0, a1 = math.radians(TILT), math.radians(TILT + 90)
        x0, y0 = pl.p(mark.corner[0] + r * math.sin(a0), mark.corner[1] - r * math.cos(a0))
        x1, y1 = pl.p(mark.corner[0] + r * math.sin(a1), mark.corner[1] - r * math.cos(a1))
        R = _f(r * pl.s)
        out.append(f"M{_f(x0)} {_f(y0)}A{R} {R} 0 0 1 {_f(x1)} {_f(y1)}")
    return out


# ------------------------------------------------------------------ SVG

def svg_doc(size: float, body: str, bg: str | None = None) -> str:
    rect = f'<rect width="{_f(size)}" height="{_f(size)}" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{_f(size)}" height="{_f(size)}" '
            f'viewBox="0 0 {_f(size)} {_f(size)}">{rect}{body}</svg>\n')


def mark_body(mark: Mark, pl: Placement, *, card_fill: str | None, card_stroke: str | None,
              card_opacity: float, arc_color: str, stroke: float) -> str:
    card = card_path(mark, pl)
    attrs = f'fill="{card_fill or "none"}"'
    if card_stroke:
        attrs += (f' stroke="{card_stroke}" stroke-width="{_f(stroke)}" '
                  f'stroke-linejoin="round"')
    if card_opacity < 1:
        attrs += f' opacity="{_f(card_opacity)}"'
    arcs = "".join(
        f'<path d="{d}" fill="none" stroke="{arc_color}" stroke-width="{_f(stroke)}" '
        f'stroke-linecap="round"/>' for d in arc_paths(mark, pl))
    return f'<path d="{card}" {attrs}/>{arcs}'


def write(path: str, data: str | bytes) -> None:
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "wb") as fh:
        fh.write(data.encode() if isinstance(data, str) else data)


def png(svg: str, px: int) -> Image.Image:
    return Image.open(io.BytesIO(cairosvg.svg2png(
        bytestring=svg.encode(), output_width=px, output_height=px))).convert("RGBA")


# ------------------------------------------------------------ the glyph

GLYPH = Mark(arcs=2)          # "two arcs at this size" (10 §3.3)
GLYPH_PL = fit_box(GLYPH, (2, 2, 22, 22), GLYPH_STROKE / 2)
# Icon rectangles have a 2-unit corner radius on the 24 grid (04 §11.1);
# the card is scaled to fit the live area, so the radius is set in grid
# units and the fit repeated until it is stable.
for _ in range(4):
    CARD_R = 2.0 / GLYPH_PL.s
    GLYPH_PL = fit_box(GLYPH, (2, 2, 22, 22), GLYPH_STROKE / 2)


def glyph_svg() -> str:
    arcs = "".join(f'<path id="accent-arc-{i + 1}" stroke="currentColor" d="{d}"/>'
                   for i, d in enumerate(arc_paths(GLYPH, GLYPH_PL)))
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" '
            'fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" '
            f'stroke-linejoin="round"><path id="card" d="{card_path(GLYPH, GLYPH_PL)}"/>{arcs}</svg>\n')


# Launch mark (S01): the glyph at 96 pt in color.fg.primary with saffron arcs
# (10 §2.3). Stroke: the 48-pt mark uses icon.48's 2.5 pt; at 96 pt the
# same proportion gives 5 pt. The Flutter S01 frame paints ic_card_arcs at
# 96 pt with stroke 5 so the native → Flutter hand-off is invisible.
LAUNCH_SIZE = 96.0
LAUNCH_STROKE = 5.0


def launch_svg(theme: str, size: float = LAUNCH_SIZE) -> str:
    k = size / 24
    pl = Placement(GLYPH_PL.s * k, GLYPH_PL.tx * k, GLYPH_PL.ty * k)
    return svg_doc(size, mark_body(GLYPH, pl, card_fill=None, card_stroke=FG_PRIMARY[theme],
                                   card_opacity=1, arc_color=SAFFRON[theme],
                                   stroke=LAUNCH_STROKE * size / LAUNCH_SIZE))


# ------------------------------------------------------------ app icon

ICON = Mark(arcs=3)           # app icon: three saffron arcs (10 §2.1)
# Arc stroke keeps the glyph's stroke-to-spacing proportion; content stays
# inside the central 824 × 824 area including the stroke (10 §2.1).
_ICON_BOX = (100, 100, 924, 924)
ICON_PL = fit_box(ICON, _ICON_BOX, 0)
ICON_PL = fit_box(ICON, _ICON_BOX, GLYPH_STROKE * ICON_PL.s / GLYPH_PL.s / 2)
ICON_STROKE = GLYPH_STROKE * ICON_PL.s / GLYPH_PL.s


def icon_default() -> str:
    return svg_doc(1024, mark_body(ICON, ICON_PL, card_fill=WHITE, card_stroke=None,
                                   card_opacity=1, arc_color=SAFFRON["light"],
                                   stroke=ICON_STROKE), bg=INK)


def icon_dark() -> str:
    return svg_doc(1024, mark_body(ICON, ICON_PL, card_fill=None, card_stroke=WHITE,
                                   card_opacity=0.9, arc_color=SAFFRON["dark"],
                                   stroke=ICON_STROKE))


def icon_tinted() -> str:
    return svg_doc(1024, mark_body(ICON, ICON_PL, card_fill=WHITE, card_stroke=None,
                                   card_opacity=1, arc_color=TINT_GREY, stroke=ICON_STROKE))


def icon_monochrome() -> str:
    return svg_doc(1024, mark_body(ICON, ICON_PL, card_fill=WHITE, card_stroke=None,
                                   card_opacity=1, arc_color=WHITE, stroke=ICON_STROKE))


# --------------------------------------------------------- Android XML

def vector_drawable(size_dp: float, paths: list[str]) -> str:
    return ('<?xml version="1.0" encoding="utf-8"?>\n'
            '<!-- GENERATED by tool/render_brand_assets.py — do not edit. -->\n'
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            f'    android:width="{_f(size_dp)}dp"\n    android:height="{_f(size_dp)}dp"\n'
            f'    android:viewportWidth="{_f(size_dp)}"\n    android:viewportHeight="{_f(size_dp)}">\n'
            + "".join(paths) + '</vector>\n')


def vd_fill(d: str, color: str) -> str:
    return f'    <path\n        android:fillColor="{color}"\n        android:pathData="{d}" />\n'


def vd_stroke(d: str, color: str, width: float, cap: str = "round") -> str:
    return (f'    <path\n        android:fillColor="#00000000"\n        android:strokeColor="{color}"\n'
            f'        android:strokeWidth="{_f(width)}"\n        android:strokeLineCap="{cap}"\n'
            f'        android:strokeLineJoin="round"\n        android:pathData="{d}" />\n')


def adaptive_layers() -> tuple[str, str, str, Placement, float]:
    # Card + arcs inside the 66 dp safe circle of the 108 dp canvas (10 §2.2).
    pl = fit_circle(ICON, (54, 54), 33, 0)
    stroke = ICON_STROKE * pl.s / ICON_PL.s
    pl = fit_circle(ICON, (54, 54), 33, stroke / 2)
    stroke = ICON_STROKE * pl.s / ICON_PL.s
    card = card_path(ICON, pl)
    arcs = arc_paths(ICON, pl)
    fg = vector_drawable(108, [vd_fill(card, WHITE)] +
                         [vd_stroke(a, SAFFRON["light"], stroke) for a in arcs])
    mono = vector_drawable(108, [vd_fill(card, WHITE)] +
                           [vd_stroke(a, WHITE, stroke) for a in arcs])
    bg = vector_drawable(108, [vd_fill("M0 0h108v108H0z", INK)])
    return fg, mono, bg, pl, stroke


def splash_vector() -> str:
    # 288 dp canvas; the 96 dp mark (identical to S01) sits well inside the
    # 192 dp safe circle (10 §2.3). Colours come from values/values-night.
    k = LAUNCH_SIZE / 24
    off = (288 - LAUNCH_SIZE) / 2
    pl = Placement(GLYPH_PL.s * k, GLYPH_PL.tx * k + off, GLYPH_PL.ty * k + off)
    card = card_path(GLYPH, pl)
    paths = [vd_stroke(card, "@color/splash_mark", LAUNCH_STROKE)]
    paths += [vd_stroke(a, "@color/splash_accent", LAUNCH_STROKE) for a in arc_paths(GLYPH, pl)]
    return vector_drawable(288, paths)


ADAPTIVE_XML = ('<?xml version="1.0" encoding="utf-8"?>\n'
                '<!-- GENERATED by tool/render_brand_assets.py — do not edit. -->\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@drawable/ic_launcher_background" />\n'
                '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
                '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
                '</adaptive-icon>\n')

DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}


def legacy_launcher(px: int, pl: Placement, stroke: float) -> Image.Image:
    """Pre-adaptive fallback: the adaptive layers under a circular mask."""
    body = mark_body(ICON, pl, card_fill=WHITE, card_stroke=None, card_opacity=1,
                     arc_color=SAFFRON["light"], stroke=stroke)
    full = png(svg_doc(108, body, bg=INK), px * 108 // 72)
    crop = (full.width - px) // 2
    tile = full.crop((crop, crop, crop + px, crop + px))
    mask = Image.new("L", (px * 4, px * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, px * 4 - 1, px * 4 - 1), fill=255)
    out = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    out.paste(tile, (0, 0), mask.resize((px, px), Image.LANCZOS))
    return out


def save_png(img: Image.Image, path: str, rgb: bool = False) -> None:
    buf = io.BytesIO()
    (img.convert("RGB") if rgb else img).save(buf, format="PNG", optimize=True)
    write(path, buf.getvalue())


# ---------------------------------------------------------------- main

def main() -> None:
    res = "android/app/src/main/res"
    xc = "ios/Runner/Assets.xcassets"

    # Glyph + masters.
    write("assets/icons/ic_card_arcs.svg", glyph_svg())
    write("tool/brand/app-mark.svg", icon_default())
    write("tool/brand/app-mark-dark.svg", icon_dark())
    write("tool/brand/app-mark-tinted.svg", icon_tinted())
    write("tool/brand/app-mark-monochrome.svg", icon_monochrome())
    write("tool/brand/launch-mark.svg", launch_svg("light"))
    write("tool/brand/launch-mark-dark.svg", launch_svg("dark"))

    # iOS app icon: single-size catalogue with dark and tinted appearances.
    appicon = os.path.join(ROOT, xc, "AppIcon.appiconset")
    if os.path.isdir(appicon):
        shutil.rmtree(appicon)
    save_png(png(icon_default(), 1024), f"{xc}/AppIcon.appiconset/AppIcon-1024.png", rgb=True)
    save_png(png(icon_dark(), 1024), f"{xc}/AppIcon.appiconset/AppIcon-1024-dark.png")
    save_png(png(icon_tinted(), 1024), f"{xc}/AppIcon.appiconset/AppIcon-1024-tinted.png")
    write(f"{xc}/AppIcon.appiconset/Contents.json", json.dumps({
        "images": [
            {"filename": "AppIcon-1024.png", "idiom": "universal", "platform": "ios",
             "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}],
             "filename": "AppIcon-1024-dark.png", "idiom": "universal", "platform": "ios",
             "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "tinted"}],
             "filename": "AppIcon-1024-tinted.png", "idiom": "universal", "platform": "ios",
             "size": "1024x1024"},
        ],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")

    # iOS launch screen assets (10 §2.3): vector PDF mark + canvas colour set.
    legacy_launch = os.path.join(ROOT, xc, "LaunchImage.imageset")
    if os.path.isdir(legacy_launch):
        shutil.rmtree(legacy_launch)
    write(f"{xc}/LaunchMark.imageset/launch-mark.pdf",
          cairosvg.svg2pdf(bytestring=launch_svg("light").encode()))
    write(f"{xc}/LaunchMark.imageset/launch-mark-dark.pdf",
          cairosvg.svg2pdf(bytestring=launch_svg("dark").encode()))
    write(f"{xc}/LaunchMark.imageset/Contents.json", json.dumps({
        "images": [
            {"filename": "launch-mark.pdf", "idiom": "universal"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}],
             "filename": "launch-mark-dark.pdf", "idiom": "universal"},
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True,
                       "template-rendering-intent": "original"},
    }, indent=2) + "\n")

    def comp(hex_: str) -> dict:
        return {"alpha": "1.000", "blue": f"0x{hex_[5:7]}", "green": f"0x{hex_[3:5]}",
                "red": f"0x{hex_[1:3]}"}

    write(f"{xc}/LaunchBackground.colorset/Contents.json", json.dumps({
        "colors": [
            {"color": {"color-space": "srgb", "components": comp(CANVAS["light"])},
             "idiom": "universal"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}],
             "color": {"color-space": "srgb", "components": comp(CANVAS["dark"])},
             "idiom": "universal"},
        ],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")

    # Android adaptive icon.
    fg, mono, bg, pl, stroke = adaptive_layers()
    write(f"{res}/drawable/ic_launcher_foreground.xml", fg)
    write(f"{res}/drawable/ic_launcher_monochrome.xml", mono)
    write(f"{res}/drawable/ic_launcher_background.xml", bg)
    write(f"{res}/mipmap-anydpi-v26/ic_launcher.xml", ADAPTIVE_XML)
    write(f"{res}/mipmap-anydpi-v26/ic_launcher_round.xml", ADAPTIVE_XML)
    for name, scale in DENSITIES.items():
        save_png(legacy_launcher(int(48 * scale), pl, stroke), f"{res}/mipmap-{name}/ic_launcher.png")

    # Android splash: 12+ vector icon, 9–11 bitmap at 96 dp.
    write(f"{res}/drawable/splash_icon.xml", splash_vector())
    for name, scale in DENSITIES.items():
        px = int(LAUNCH_SIZE * scale)
        save_png(png(launch_svg("light"), px), f"{res}/drawable-{name}/splash_icon_legacy.png")
        save_png(png(launch_svg("dark"), px), f"{res}/drawable-night-{name}/splash_icon_legacy.png")

    print("Brand assets written.")


if __name__ == "__main__":
    main()
