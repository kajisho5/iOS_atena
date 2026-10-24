#!/usr/bin/env python3
"""Generate high-fidelity SVG design sheets for the app (docs/design/*.svg).

Pure standard library. Run: python3 tools/gen_design_svgs.py
"""
from __future__ import annotations

import os
from xml.sax.saxutils import escape

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "docs", "design")

SANS = "-apple-system, 'SF Pro Text', 'Hiragino Sans', 'Hiragino Kaku Gothic ProN', 'Noto Sans CJK JP', sans-serif"
MINCHO = "'Hiragino Mincho ProN', 'IPAMincho', 'Noto Serif CJK JP', serif"

# Design tokens (mirror of the planned asset catalog colors + system colors).
LIGHT = dict(
    bg="#F2F2F7", cell="#FFFFFF", label="#000000", secondary="#5E5E63", tertiary="#8A8A8E",
    separator="#C6C6C8", accent="#24569B", on_accent="#FFFFFF", fill="#E5E5EA",
    success="#1E7B34", warning="#B04A00", warning_fill="#FFF1E5", glass="#FFFFFF", glass_op=0.82,
    glass_stroke="#D1D1D6", preview_bg="#E5E5EA", paper="#FFFFFF", ink="#1A1A1A",
    postal="#E0322B", guide="#B8B8BE", destructive="#C4261D", toggle_on="#34C759", grabber="#C7C7CC",
)
DARK = dict(
    bg="#000000", cell="#1C1C1E", label="#FFFFFF", secondary="#AEAEB2", tertiary="#8E8E93",
    separator="#38383A", accent="#8DB3EC", on_accent="#000000", fill="#2C2C2E",
    success="#5BD37A", warning="#FFB35C", warning_fill="#3A2614", glass="#2C2C2E", glass_op=0.86,
    glass_stroke="#48484A", preview_bg="#111113", paper="#FAFAF7", ink="#1A1A1A",
    postal="#E0322B", guide="#6E6E73", destructive="#FF6961", toggle_on="#30D158", grabber="#5A5A5E",
)

W, H = 393, 852  # iPhone 16 / 15 logical points
IPAD_W, IPAD_H = 1194, 834  # iPad 11-inch landscape


class Canvas:
    def __init__(self) -> None:
        self.parts: list[str] = []

    def add(self, s: str) -> None:
        self.parts.append(s)

    def rect(self, x, y, w, h, fill="none", rx=0, stroke=None, sw=1, op=None, dash=None):
        a = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}"'
        if stroke:
            a += f' stroke="{stroke}" stroke-width="{sw}"'
        if op is not None:
            a += f' fill-opacity="{op}"'
        if dash:
            a += f' stroke-dasharray="{dash}"'
        self.add(a + "/>")

    def text(self, x, y, s, size=17, fill="#000", weight=400, anchor="start", family=SANS, extra=""):
        self.add(
            f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}" {extra}>{escape(s)}</text>'
        )

    def vtext(self, x, y, s, size, fill, family=MINCHO, spacing=0, weight=400):
        # Vertical (tategaki) text; x is the center of the column, y the top.
        self.add(
            f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" font-weight="{weight}" fill="{fill}" '
            f'style="writing-mode: vertical-rl; text-orientation: mixed; letter-spacing:{spacing}px">{escape(s)}</text>'
        )

    def line(self, x1, y1, x2, y2, stroke, sw=1, dash=None):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        self.add(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke}" stroke-width="{sw}"{d}/>')

    def path(self, d, fill="none", stroke=None, sw=1.6, cap="round", join="round"):
        s = f' stroke="{stroke}" stroke-width="{sw}" stroke-linecap="{cap}" stroke-linejoin="{join}"' if stroke else ""
        self.add(f'<path d="{d}" fill="{fill}"{s}/>')

    def circle(self, cx, cy, r, fill="none", stroke=None, sw=1.5):
        s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        self.add(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"{s}/>')

    def group(self, tx, ty, inner: "Canvas", scale=1.0, clip_id=None):
        clip = f' clip-path="url(#{clip_id})"' if clip_id else ""
        self.add(f'<g transform="translate({tx},{ty}) scale({scale})"{clip}>' + "".join(inner.parts) + "</g>")

    def svg(self, w, h, defs="") -> str:
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f"<defs>{defs}</defs>" + "".join(self.parts) + "</svg>\n"
        )


# ---------------------------------------------------------------------------
# Simplified SF Symbol-like glyphs (design reference only; the app uses SF Symbols).
# ---------------------------------------------------------------------------

def icon(c: Canvas, name: str, x: float, y: float, s: float, color: str, sw: float = 1.7):
    """Draw a glyph centered at (x, y) with nominal size s."""
    h = s / 2
    if name == "plus":
        c.path(f"M{x-h*0.75},{y} L{x+h*0.75},{y} M{x},{y-h*0.75} L{x},{y+h*0.75}", stroke=color, sw=sw + 0.3)
    elif name == "xmark":
        k = h * 0.55
        c.path(f"M{x-k},{y-k} L{x+k},{y+k} M{x+k},{y-k} L{x-k},{y+k}", stroke=color, sw=sw + 0.2)
    elif name == "chevron.right":
        k = h * 0.4
        c.path(f"M{x-k*0.6},{y-k} L{x+k*0.6},{y} L{x-k*0.6},{y+k}", stroke=color, sw=sw)
    elif name == "chevron.left":
        k = h * 0.5
        c.path(f"M{x+k*0.6},{y-k} L{x-k*0.6},{y} L{x+k*0.6},{y+k}", stroke=color, sw=sw + 0.4)
    elif name == "chevron.updown":
        k = h * 0.35
        c.path(f"M{x-k},{y-k*0.4} L{x},{y-k*1.3} L{x+k},{y-k*0.4} M{x-k},{y+k*0.4} L{x},{y+k*1.3} L{x+k},{y+k*0.4}", stroke=color, sw=sw)
    elif name == "checkmark":
        c.path(f"M{x-h*0.6},{y} L{x-h*0.15},{y+h*0.45} L{x+h*0.65},{y-h*0.5}", stroke=color, sw=sw + 0.4)
    elif name == "checkmark.circle.fill":
        c.circle(x, y, h, fill=color)
        c.path(f"M{x-h*0.45},{y} L{x-h*0.1},{y+h*0.35} L{x+h*0.5},{y-h*0.35}", stroke="#FFFFFF", sw=sw)
    elif name == "circle":
        c.circle(x, y, h * 0.92, stroke=color, sw=1.4)
    elif name == "person.2":
        c.circle(x - h * 0.28, y - h * 0.3, h * 0.28, fill=color)
        c.path(f"M{x-h*0.85},{y+h*0.7} Q{x-h*0.85},{y+h*0.05} {x-h*0.28},{y+h*0.05} Q{x+h*0.29},{y+h*0.05} {x+h*0.29},{y+h*0.7} Z", fill=color)
        c.circle(x + h * 0.42, y - h * 0.38, h * 0.22, fill=color)
        c.path(f"M{x+h*0.36},{y+h*0.0} Q{x+h*0.9},{y-h*0.05} {x+h*0.92},{y+h*0.55} L{x+h*0.4},{y+h*0.55} Z", fill=color)
    elif name == "envelope":
        c.rect(x - h * 0.85, y - h * 0.58, h * 1.7, h * 1.16, rx=h * 0.18, stroke=color, sw=sw)
        c.path(f"M{x-h*0.8},{y-h*0.5} L{x},{y+h*0.1} L{x+h*0.8},{y-h*0.5}", stroke=color, sw=sw)
    elif name == "gearshape":
        import math
        pts = []
        for i in range(16):
            r = h * (0.92 if i % 2 == 0 else 0.7)
            a = math.pi * 2 * i / 16
            pts.append(f"{x + r * math.cos(a):.2f},{y + r * math.sin(a):.2f}")
        c.path("M" + " L".join(pts) + " Z", fill=color)
        c.circle(x, y, h * 0.3, fill="#FFFFFF" if color != "#FFFFFF" else "#000")
    elif name == "folder":
        c.path(f"M{x-h*0.85},{y-h*0.5} L{x-h*0.3},{y-h*0.5} L{x-h*0.15},{y-h*0.32} L{x+h*0.85},{y-h*0.32} L{x+h*0.85},{y+h*0.6} L{x-h*0.85},{y+h*0.6} Z", stroke=color, sw=sw)
    elif name == "printer":
        c.rect(x - h * 0.5, y - h * 0.85, h * 1.0, h * 0.5, stroke=color, sw=sw)
        c.rect(x - h * 0.9, y - h * 0.35, h * 1.8, h * 0.85, rx=h * 0.15, stroke=color, sw=sw)
        c.rect(x - h * 0.5, y + h * 0.15, h * 1.0, h * 0.7, fill=color)
    elif name == "tray":
        c.path(f"M{x-h*0.85},{y} L{x-h*0.55},{y-h*0.6} L{x+h*0.55},{y-h*0.6} L{x+h*0.85},{y} L{x+h*0.85},{y+h*0.6} L{x-h*0.85},{y+h*0.6} Z M{x-h*0.85},{y} L{x-h*0.3},{y} L{x-h*0.2},{y+h*0.2} L{x+h*0.2},{y+h*0.2} L{x+h*0.3},{y} L{x+h*0.85},{y}", stroke=color, sw=sw)
    elif name == "magnifyingglass":
        c.circle(x - h * 0.15, y - h * 0.15, h * 0.5, stroke=color, sw=sw)
        c.path(f"M{x+h*0.22},{y+h*0.22} L{x+h*0.7},{y+h*0.7}", stroke=color, sw=sw + 0.4)
    elif name == "ellipsis":
        for dx in (-0.55, 0, 0.55):
            c.circle(x + h * dx, y, h * 0.13, fill=color)
    elif name == "exclamationmark.triangle.fill":
        c.path(f"M{x},{y-h*0.85} L{x+h*0.95},{y+h*0.75} L{x-h*0.95},{y+h*0.75} Z", fill=color)
        c.path(f"M{x},{y-h*0.3} L{x},{y+h*0.2}", stroke="#FFFFFF", sw=sw)
        c.circle(x, y + h * 0.48, h * 0.09, fill="#FFFFFF")
    elif name == "square.and.arrow.up":
        c.path(f"M{x-h*0.3},{y-h*0.2} L{x-h*0.7},{y-h*0.2} L{x-h*0.7},{y+h*0.9} L{x+h*0.7},{y+h*0.9} L{x+h*0.7},{y-h*0.2} L{x+h*0.3},{y-h*0.2}", stroke=color, sw=sw)
        c.path(f"M{x},{y+h*0.35} L{x},{y-h*0.95} M{x-h*0.35},{y-h*0.6} L{x},{y-h*0.95} L{x+h*0.35},{y-h*0.6}", stroke=color, sw=sw)
    elif name == "doc.text":
        c.path(f"M{x-h*0.65},{y-h*0.9} L{x+h*0.25},{y-h*0.9} L{x+h*0.65},{y-h*0.5} L{x+h*0.65},{y+h*0.9} L{x-h*0.65},{y+h*0.9} Z", stroke=color, sw=sw)
        for dy in (-0.15, 0.2, 0.55):
            c.line(x - h * 0.35, y + h * dy, x + h * 0.35, y + h * dy, color, sw * 0.8)
    elif name == "person.crop.circle":
        c.circle(x, y, h * 0.92, stroke=color, sw=sw)
        c.circle(x, y - h * 0.2, h * 0.3, fill=color)
        c.path(f"M{x-h*0.55},{y+h*0.62} Q{x},{y+h*0.05} {x+h*0.55},{y+h*0.62}", fill=color)
    elif name == "arrow.up.and.down.and.arrow.left.and.right":
        k = h * 0.85
        c.path(f"M{x},{y-k} L{x},{y+k} M{x-k},{y} L{x+k},{y} M{x-k*0.3},{y-k*0.7} L{x},{y-k} L{x+k*0.3},{y-k*0.7} M{x-k*0.3},{y+k*0.7} L{x},{y+k} L{x+k*0.3},{y+k*0.7} M{x-k*0.7},{y-k*0.3} L{x-k},{y} L{x-k*0.7},{y+k*0.3} M{x+k*0.7},{y-k*0.3} L{x+k},{y} L{x+k*0.7},{y+k*0.3}", stroke=color, sw=sw)
    elif name == "arrow.clockwise":
        c.path(f"M{x+h*0.65},{y-h*0.1} A{h*0.68},{h*0.68} 0 1 1 {x+h*0.35},{y-h*0.55}", stroke=color, sw=sw)
        c.path(f"M{x+h*0.05},{y-h*0.7} L{x+h*0.42},{y-h*0.6} L{x+h*0.4},{y-h*0.2}", stroke=color, sw=sw)
    elif name == "lock.fill":
        c.path(f"M{x-h*0.4},{y-h*0.1} L{x-h*0.4},{y-h*0.4} A{h*0.4},{h*0.4} 0 0 1 {x+h*0.4},{y-h*0.4} L{x+h*0.4},{y-h*0.1}", stroke=color, sw=sw)
        c.rect(x - h * 0.65, y - h * 0.12, h * 1.3, h * 0.95, rx=h * 0.15, fill=color)
    elif name == "hand.raised":
        c.rect(x - h * 0.55, y - h * 0.4, h * 1.1, h * 1.2, rx=h * 0.45, stroke=color, sw=sw)
        for dx in (-0.35, -0.05, 0.25):
            c.line(x + h * dx, y - h * 0.4, x + h * dx, y - h * 0.9, color, sw)
    elif name == "textformat":
        c.text(x, y + h * 0.45, "Aa", size=s * 0.8, fill=color, weight=600, anchor="middle")
    elif name == "tag":
        c.path(f"M{x-h*0.85},{y-h*0.2} L{x-h*0.85},{y-h*0.85} L{x-h*0.2},{y-h*0.85} L{x+h*0.85},{y+h*0.2} L{x+h*0.2},{y+h*0.85} Z", stroke=color, sw=sw)
        c.circle(x - h * 0.45, y - h * 0.45, h * 0.12, fill=color)
    elif name == "info.circle":
        c.circle(x, y, h * 0.9, stroke=color, sw=sw)
        c.line(x, y - h * 0.05, x, y + h * 0.5, color, sw + 0.3)
        c.circle(x, y - h * 0.38, h * 0.1, fill=color)


# ---------------------------------------------------------------------------
# iOS chrome components
# ---------------------------------------------------------------------------

def status_bar(c: Canvas, t, w=W, dark_content=None):
    col = t["label"] if dark_content is None else dark_content
    if w != W:
        # iPad: slim status bar, time at the leading edge.
        c.text(28, 19, "9:41  10月24日(土)", size=13, fill=col, weight=600)
        c.add('<g transform="translate(0,-16) scale(1)">')
    else:
        c.text(52, 37, "9:41", size=17, fill=col, weight=600, anchor="middle")
        # Dynamic Island
        c.rect(w / 2 - 63, 11, 126, 37, fill="#000000", rx=18.5)
    # Right indicators: signal, wifi, battery
    x = w - 98
    for i, hh in enumerate((4, 6.5, 9, 11.5)):
        c.rect(x + i * 5.2, 36 - hh, 3.3, hh, fill=col, rx=0.8)
    c.path(f"M{x+27},{29} Q{x+34},{22} {x+41},{29}", stroke=col, sw=2)
    c.path(f"M{x+30},{32} Q{x+34},{28} {x+38},{32}", stroke=col, sw=2)
    c.circle(x + 34, 35, 1.4, fill=col)
    c.rect(x + 48, 25, 24, 12, rx=3.6, stroke=col, sw=1, op=None)
    c.rect(x + 50, 27, 18, 8, fill=col, rx=2)
    c.rect(x + 73, 29, 1.6, 4, fill=col, rx=0.8)
    if w != W:
        c.add("</g>")


def home_indicator(c: Canvas, t, w=W, h=H):
    c.rect(w / 2 - 67, h - 13, 134, 5, fill=t["label"], rx=2.5)


def glass_button(c: Canvas, t, x, y, w, h, label=None, icon_name=None, color=None, bold=False, prominent=False):
    """Liquid Glass style toolbar control (capsule)."""
    if prominent:
        c.rect(x, y, w, h, fill=t["accent"], rx=h / 2)
        fg = t["on_accent"]
    else:
        c.rect(x, y, w, h, fill=t["glass"], rx=h / 2, op=t["glass_op"], stroke=t["glass_stroke"], sw=0.6)
        fg = color or t["label"]
    if icon_name:
        icon(c, icon_name, x + w / 2, y + h / 2, 20, fg)
    if label:
        c.text(x + w / 2, y + h / 2 + 6, label, size=17, fill=fg, weight=600 if bold else 400, anchor="middle")


def nav_bar(c: Canvas, t, title=None, large_title=None, left=None, right=None, subtitle=None, w=W, x0=0, y0=54):
    """left/right: list of (kind, value) where kind in {'icon','text','textbold','prominent'}."""
    lx = x0 + 16
    for kind, val in left or []:
        if kind == "icon":
            glass_button(c, t, lx, y0 + 2, 44, 44, icon_name=val)
            lx += 52
        else:
            tw = len(val) * 17 + 28
            glass_button(c, t, lx, y0 + 2, tw, 44, label=val, bold=(kind == "textbold"))
            lx += tw + 8
    rx = x0 + w - 16
    for kind, val in reversed(right or []):
        if kind == "icon":
            rx -= 44
            glass_button(c, t, rx, y0 + 2, 44, 44, icon_name=val)
            rx -= 8
        elif kind == "icongroup":
            gw = 44 * len(val)
            rx -= gw
            c.rect(rx, y0 + 2, gw, 44, fill=t["glass"], rx=22, op=t["glass_op"], stroke=t["glass_stroke"], sw=0.6)
            for i, nm in enumerate(val):
                icon(c, nm, rx + 22 + i * 44, y0 + 24, 20, t["label"])
            rx -= 8
        else:
            tw = len(val) * 17 + 28
            rx -= tw
            glass_button(c, t, rx, y0 + 2, tw, 44, label=val, bold=(kind in ("textbold", "prominent")), prominent=(kind == "prominent"))
            rx -= 8
    if title:
        c.text(x0 + w / 2, y0 + 30 if not subtitle else y0 + 22, title, size=17, fill=t["label"], weight=600, anchor="middle")
        if subtitle:
            c.text(x0 + w / 2, y0 + 40, subtitle, size=12, fill=t["secondary"], anchor="middle")
    if large_title:
        c.text(x0 + 16, y0 + 92, large_title, size=34, fill=t["label"], weight=700)


def tab_bar(c: Canvas, t, selected=0, w=W, h=H):
    y = h - 34 - 62
    x = 20
    bw = w - 40
    c.rect(x, y, bw, 62, fill=t["glass"], rx=31, op=t["glass_op"], stroke=t["glass_stroke"], sw=0.6)
    items = [("person.2", "宛先"), ("envelope", "レイアウト"), ("gearshape", "設定")]
    seg = bw / 3
    for i, (ic, lab) in enumerate(items):
        cx = x + seg * i + seg / 2
        col = t["accent"] if i == selected else t["label"]
        if i == selected:
            c.rect(x + seg * i + 6, y + 5, seg - 12, 52, fill=t["fill"], rx=26)
        icon(c, ic, cx, y + 22, 22, col)
        c.text(cx, y + 50, lab, size=10, fill=col, weight=600 if i == selected else 500, anchor="middle")


def section_header(c: Canvas, t, x, y, s):
    c.text(x + 16, y, s, size=13, fill=t["secondary"], weight=400)


def section_footer(c: Canvas, t, x, y, s, wmax=None):
    c.text(x + 16, y, s, size=13, fill=t["secondary"])


def inset_group(c: Canvas, t, x, y, w, rows, row_h=52):
    """rows: list of callables(c, rx, ry, rw, rh) drawing row content; returns bottom y."""
    total = sum(rh if isinstance(rh, (int, float)) else row_h for _, rh in rows)
    c.rect(x, y, w, total, fill=t["cell"], rx=14)
    cy = y
    for i, (fn, rh) in enumerate(rows):
        rh = rh or row_h
        fn(c, x, cy, w, rh)
        if i < len(rows) - 1:
            c.line(x + 16 + (getattr(fn, "inset", 0)), cy + rh, x + w, cy + rh, t["separator"], 0.6)
        cy += rh
    return cy


def row_value(t, label, value=None, chevron=True, icon_name=None, icon_bg=None, value_color=None, badge=None, label_color=None):
    def fn(c, x, y, w, h):
        lx = x + 16
        if icon_name:
            c.rect(x + 16, y + h / 2 - 15, 30, 30, fill=icon_bg or t["accent"], rx=7)
            icon(c, icon_name, x + 31, y + h / 2, 18, "#FFFFFF")
            lx = x + 58
        c.text(lx, y + h / 2 + 6, label, size=17, fill=label_color or t["label"])
        rx = x + w - 16
        if chevron:
            icon(c, "chevron.right", rx - 5, y + h / 2, 16, t["tertiary"], 1.8)
            rx -= 20
        if value:
            c.text(rx, y + h / 2 + 6, value, size=17, fill=value_color or t["secondary"], anchor="end")
        if badge:
            badge(c, rx, y, h)
    fn.inset = 42 if icon_name else 0
    return fn


def row_toggle(t, label, on=True, sub=None):
    def fn(c, x, y, w, h):
        c.text(x + 16, y + (h / 2 + 6 if not sub else h / 2 - 2), label, size=17, fill=t["label"])
        if sub:
            c.text(x + 16, y + h / 2 + 17, sub, size=13, fill=t["secondary"])
        tx = x + w - 16 - 64
        c.rect(tx, y + h / 2 - 14, 64, 28, fill=t["toggle_on"] if on else t["fill"], rx=14)
        c.circle(tx + (49 if on else 15), y + h / 2, 12, fill="#FFFFFF")
    return fn


def row_field(t, label, value, placeholder=False, label_w=96):
    def fn(c, x, y, w, h):
        c.text(x + 16, y + h / 2 + 6, label, size=17, fill=t["label"])
        c.text(x + 16 + label_w, y + h / 2 + 6, value, size=17, fill=t["tertiary"] if placeholder else t["label"])
    fn.inset = 0
    return fn


def row_text(t, s, color=None, weight=400, icon_name=None, center=False):
    def fn(c, x, y, w, h):
        if icon_name:
            icon(c, icon_name, x + 30, y + h / 2, 20, color or t["accent"])
            c.text(x + 52, y + h / 2 + 6, s, size=17, fill=color or t["accent"], weight=weight)
        elif center:
            c.text(x + w / 2, y + h / 2 + 6, s, size=17, fill=color or t["accent"], weight=weight, anchor="middle")
        else:
            c.text(x + 16, y + h / 2 + 6, s, size=17, fill=color or t["label"], weight=weight)
    return fn


def search_field(c: Canvas, t, x, y, w, text="検索"):
    c.rect(x, y, w, 40, fill=t["fill"], rx=20)
    icon(c, "magnifyingglass", x + 22, y + 20, 18, t["secondary"])
    c.text(x + 40, y + 26, text, size=17, fill=t["secondary"])


def segmented(c: Canvas, t, x, y, w, items, sel=0, h=34):
    c.rect(x, y, w, h, fill=t["fill"], rx=h / 2)
    sw = w / len(items)
    c.rect(x + sel * sw + 3, y + 3, sw - 6, h - 6, fill=t["cell"], rx=(h - 6) / 2)
    for i, s in enumerate(items):
        c.text(x + sw * i + sw / 2, y + h / 2 + 5, s, size=14, fill=t["label"], weight=600 if i == sel else 500, anchor="middle")


def pill(c: Canvas, x, y, s, fg, bg, icon_name=None, size=12, anchor_end=False):
    w = len(s) * size + (22 if icon_name else 12)
    if anchor_end:
        x -= w
    c.rect(x, y, w, size + 10, fill=bg, rx=(size + 10) / 2)
    tx = x + 6
    if icon_name:
        icon(c, icon_name, x + 11, y + (size + 10) / 2, size, fg, 1.4)
        tx = x + 19
    c.text(tx, y + size + 3, s, size=size, fill=fg, weight=600)
    return w


# ---------------------------------------------------------------------------
# Paper (address side) rendering — mirrors AddressRenderer's planned geometry.
# ---------------------------------------------------------------------------

def hagaki(c: Canvas, t, x, y, scale, recipient, sender=True, overflow=False, show_guides=True, kanji=True):
    """Draw a 100x148mm postcard at (x,y) with px-per-mm `scale` (vertical layout)."""
    mm = scale
    pw, ph = 100 * mm, 148 * mm
    c.rect(x + 2, y + 3, pw, ph, fill="#000000", op=0.18, rx=2)
    c.rect(x, y, pw, ph, fill=t["paper"], rx=1.5)
    if show_guides:
        c.rect(x, y, pw, ph, stroke=t["guide"], sw=0.8, rx=1.5)
        # Stamp area guide (top-left)
        c.rect(x + 8 * mm, y + 8 * mm, 22 * mm, 27 * mm, stroke=t["guide"], sw=0.7, dash="3 2")
        c.text(x + 19 * mm, y + 23 * mm, "切手", size=max(7, 3.2 * mm), fill=t["guide"], anchor="middle")
        # Postal code frames (JIS spec 1: 12mm from top, 8mm from right). Box sizes are provisional.
        bx_right = x + pw - 8 * mm
        top = y + 12 * mm
        widths = [(5.7, 7.0)] * 3 + [(5.7, 6.8)] * 4
        positions = []
        cur = bx_right
        for i in range(6, -1, -1):
            bw = 5.7 * mm
            positions.insert(0, cur - bw)
            cur -= (6.8 if i >= 3 else 7.0) * mm
            if i == 3:
                cur -= 0.8 * mm
        for i, px in enumerate(positions):
            c.rect(px, top, 5.7 * mm, 8 * mm, stroke=t["postal"], sw=1.2 if i < 3 else 0.8)
    digits = recipient["zip"]
    bx_right = x + pw - 8 * mm
    top = y + 12 * mm
    cur = bx_right
    pos = []
    for i in range(6, -1, -1):
        pos.insert(0, cur - 5.7 * mm)
        cur -= (6.8 if i >= 3 else 7.0) * mm
        if i == 3:
            cur -= 0.8 * mm
    for i, d in enumerate(digits):
        c.text(pos[i] + 2.85 * mm, top + 6.6 * mm, d, size=6.2 * mm, fill=t["ink"], anchor="middle", family="'Hiragino Sans', 'Noto Sans CJK JP', sans-serif", weight=500)
    # Address column(s) — right side
    addr1 = recipient["addr1_k"] if kanji else recipient["addr1"]
    c.vtext(x + 84 * mm, y + 27 * mm, addr1, 5.4 * mm, t["ink"], spacing=0.3 * mm)
    if recipient.get("addr2"):
        c.vtext(x + 76 * mm, y + 44 * mm, recipient["addr2"], 5.0 * mm, t["ink"], spacing=0.2 * mm)
    # Name — centered, large
    c.vtext(x + 50 * mm, y + 34 * mm, recipient["name_v"], 10.5 * mm, t["ink"], spacing=1.6 * mm)
    if recipient.get("joint_v"):
        c.vtext(x + 38 * mm, y + 34 * mm + 10.5 * mm * len(recipient["family"]) + 1.6 * mm * len(recipient["family"]), recipient["joint_v"], 10.5 * mm, t["ink"], spacing=1.6 * mm)
    if sender:
        c.vtext(x + 17 * mm, y + 82 * mm, "東京都見本区見本町二-五", 3.2 * mm, t["ink"], spacing=0.1 * mm)
        c.vtext(x + 11 * mm, y + 96 * mm, "田中一郎", 4.6 * mm, t["ink"], spacing=0.6 * mm)
        # Sender postal code (small, bottom-left), provisional
        for i, d in enumerate("1230045"):
            c.text(x + (5 + i * 3.6 + (1.2 if i >= 3 else 0)) * mm, y + 141 * mm, d, size=3.2 * mm, fill=t["ink"], family="'Hiragino Sans', 'Noto Sans CJK JP', sans-serif")
    if overflow:
        c.rect(x + 78.5 * mm, y + 26 * mm, 11 * mm, 112 * mm, stroke=t["warning"], sw=1.6, dash="4 3")


RECIPIENT = dict(
    zip="1040061",
    addr1="東京都中央区見本町1-13-3",
    addr1_k="東京都中央区見本町一-一三-三",
    addr2="サンプルハイツ二〇三号",
    name_v="山田太郎様",
    family="山田",
    joint_v="花子様",
)


# ---------------------------------------------------------------------------
# Screens (iPhone)
# ---------------------------------------------------------------------------

def bottom_bar(c: Canvas, t, buttons):
    """iPhone bottom action bar above the tab bar. buttons: list of (label, icon, prominent, width)."""
    top = H - 34 - 62 - 76
    c.rect(0, top, W, 72, fill=t["bg"], op=0.94)
    c.line(0, top, W, top, t["separator"], 0.6)
    x = 16
    for label, icon_name, prominent, width in buttons:
        fill = t["accent"] if prominent else t["fill"]
        fg = t["on_accent"] if prominent else t["accent"]
        c.rect(x, top + 11, width, 50, fill=fill, rx=25)
        tw = len(label) * 17
        icon(c, icon_name, x + width / 2 - tw / 2 - 6, top + 36, 18, fg)
        c.text(x + width / 2 + 12, top + 42, label, size=17, fill=fg, weight=600, anchor="middle")
        x += width + 10


def screen_groups(t) -> Canvas:
    c = Canvas()
    c.rect(0, 0, W, H, fill=t["bg"])
    status_bar(c, t)
    nav_bar(c, t, large_title="宛先", right=[("icon", "ellipsis")])
    y = 172
    search_field(c, t, 16, y, W - 32, "氏名・住所で検索")
    y += 60
    def cnt(n):
        def b(c, rx, ry, rh):
            c.text(rx, ry + rh / 2 + 6, n, size=17, fill=t["secondary"], anchor="end")
        return b
    y = inset_group(c, t, 16, y, W - 32, [
        (row_value(t, "すべての宛先", icon_name="person.2", icon_bg=t["accent"], badge=cnt("128")), 52),
        (row_value(t, "未印刷", icon_name="tray", icon_bg="#B04A00" if t is LIGHT else "#C25A12", badge=cnt("42")), 52),
    ])
    y += 36
    section_header(c, t, 16, y - 8, "グループ")
    y = inset_group(c, t, 16, y, W - 32, [
        (row_value(t, "年賀状2026", icon_name="folder", icon_bg="#5E5CE6" if t is DARK else "#4B49C8", badge=cnt("86")), 52),
        (row_value(t, "仕事関係", icon_name="folder", icon_bg="#5E5CE6" if t is DARK else "#4B49C8", badge=cnt("32")), 52),
        (row_value(t, "親戚", icon_name="folder", icon_bg="#5E5CE6" if t is DARK else "#4B49C8", badge=cnt("10")), 52),
        (row_text(t, "グループを追加", icon_name="plus", color=t["accent"]), 52),
    ])
    section_footer(c, t, 16, y + 24, "グループ単位で一括印刷できます。")
    bottom_bar(c, t, [("宛先を追加", "plus", False, W - 32)])
    tab_bar(c, t, 0)
    home_indicator(c, t)
    return c


def recipient_row(t, name, honor, joint, zipc, addr, status=None, memo=None, big=False):
    def fn(c, x, y, w, h):
        c.text(x + 16, y + 30, name, size=17, fill=t["label"], weight=600)
        nw = len(name) * 17
        c.text(x + 16 + nw + 4, y + 30, honor, size=15, fill=t["label"])
        if joint:
            c.text(x + 16 + nw + 4 + len(honor) * 15 + 10, y + 30, f"・{joint}", size=15, fill=t["secondary"])
        c.text(x + 16, y + 54, f"〒{zipc[:3]}-{zipc[3:]}  {addr}", size=15, fill=t["secondary"])
        bx = x + w - 16
        if status == "printed":
            pill(c, bx, y + 12, "印刷済み 12/1", t["success"], t["fill"], icon_name="checkmark", anchor_end=True)
        elif status == "overflow":
            pill(c, bx, y + 12, "はみ出し", t["warning"], t["warning_fill"], icon_name="exclamationmark.triangle.fill", anchor_end=True)
        if memo:
            pill(c, x + 16, y + 64, memo, t["secondary"], t["fill"], size=12)
    return fn


def screen_recipients(t) -> Canvas:
    c = Canvas()
    c.rect(0, 0, W, H, fill=t["bg"])
    status_bar(c, t)
    nav_bar(c, t, left=[("icon", "chevron.left")], right=[("icon", "ellipsis")])
    c.text(16, 146, "年賀状2026", size=34, fill=t["label"], weight=700)
    c.text(16, 170, "86件 ・ 未印刷 42件", size=15, fill=t["secondary"])
    search_field(c, t, 16, 186, W - 32, "氏名・住所で検索")
    segmented(c, t, 16, 238, W - 32, ["すべて", "未印刷", "印刷済み"], sel=0)
    y = 290
    rows = [
        (recipient_row(t, "青木 健", "様", None, "1500001", "東京都渋谷区見本…", "printed"), 76),
        (recipient_row(t, "伊藤 美咲", "様", None, "2200012", "神奈川県横浜市西区…", None), 76),
        (recipient_row(t, "株式会社見本商事", "御中", None, "5300001", "大阪府大阪市北区見…", "overflow"), 76),
        (recipient_row(t, "佐藤 一郎", "先生", None, "4600008", "愛知県名古屋市中区…", None, memo="喪中（2026）"), 92),
        (recipient_row(t, "山田 太郎", "様", "花子", "1040061", "東京都中央区見本町…", "printed"), 76),
    ]
    y = inset_group(c, t, 16, y, W - 32, rows)
    bottom_bar(c, t, [("追加", "plus", False, 120), ("一括印刷", "printer", True, W - 32 - 130)])
    tab_bar(c, t, 0)
    home_indicator(c, t)
    return c


def screen_edit(t) -> Canvas:
    c = Canvas()
    c.rect(0, 0, W, H, fill="#000000")
    status_bar(c, t, dark_content="#FFFFFF")
    # Sheet presentation (page sheet)
    c.rect(0, 64, W, H - 64, fill=t["bg"], rx=38)
    c.rect(W / 2 - 18, 70, 36, 5, fill=t["grabber"], rx=2.5)
    nav_bar(c, t, title="宛先を編集", left=[("icon", "xmark")], right=[("prominent", "保存")], y0=84)
    y = 154
    section_header(c, t, 16, y, "氏名")
    y = inset_group(c, t, 16, y + 8, W - 32, [
        (row_field(t, "氏名", "山田 太郎"), 48),
        (row_field(t, "ふりがな", "やまだ たろう"), 48),
        (row_value(t, "敬称", "様"), 48),
    ])
    y += 30
    section_header(c, t, 16, y, "連名")
    y = inset_group(c, t, 16, y + 8, W - 32, [
        (row_field(t, "連名1", "花子", label_w=72), 48),
        (row_text(t, "連名を追加", icon_name="plus", color=t["accent"]), 48),
    ])
    y += 30
    section_header(c, t, 16, y, "住所")
    y = inset_group(c, t, 16, y + 8, W - 32, [
        (row_field(t, "郵便番号", "104-0061"), 48),
        (row_field(t, "住所", "東京都中央区見本町1-13-3"), 48),
        (row_field(t, "建物名", "サンプルハイツ203"), 48),
    ])
    y += 30
    section_header(c, t, 16, y, "メモ")
    y = inset_group(c, t, 16, y + 8, W - 32, [
        (row_field(t, "", "例: 喪中、転居予定", placeholder=True, label_w=0), 48),
    ])
    y += 30
    section_header(c, t, 16, y, "グループ")
    def grp(name, on):
        def fn(c, x, yy, w, h):
            c.text(x + 16, yy + h / 2 + 6, name, size=17, fill=t["label"])
            if on:
                icon(c, "checkmark", x + w - 28, yy + h / 2, 18, t["accent"])
        return fn
    inset_group(c, t, 16, y + 8, W - 32, [(grp("年賀状2026", True), 48), (grp("仕事関係", False), 48)])
    home_indicator(c, t)
    return c


def bottom_action_bar(c: Canvas, t, y, w=W, x0=0, primary="42件を印刷", secondary="PDF"):
    c.rect(x0 + 16, y, 110, 52, fill=t["glass"], rx=26, op=t["glass_op"], stroke=t["glass_stroke"], sw=0.6)
    icon(c, "square.and.arrow.up", x0 + 44, y + 25, 20, t["accent"])
    c.text(x0 + 82, y + 32, secondary, size=17, fill=t["accent"], weight=600, anchor="middle")
    c.rect(x0 + 136, y, w - 152, 52, fill=t["accent"], rx=26)
    icon(c, "printer", x0 + 136 + (w - 152) / 2 - 58, y + 26, 20, t["on_accent"])
    c.text(x0 + 136 + (w - 152) / 2 + 12, y + 32, primary, size=17, fill=t["on_accent"], weight=600, anchor="middle")


def screen_preview(t) -> Canvas:
    c = Canvas()
    c.rect(0, 0, W, H, fill=t["preview_bg"])
    status_bar(c, t)
    nav_bar(c, t, title="印刷プレビュー", subtitle="年賀状2026 ・ はがき 縦書き", left=[("icon", "xmark")], right=[("icon", "ellipsis")])
    # Warning banner (double print)
    c.rect(16, 112, W - 32, 44, fill=t["warning_fill"], rx=12)
    icon(c, "exclamationmark.triangle.fill", 38, 134, 18, t["warning"])
    c.text(56, 140, "12月1日に印刷済みの宛先です", size=15, fill=t["warning"], weight=600)
    # Paper fit area: from y=168 to y=H-34-52-64 (page controls)
    area_top, area_bottom = 168, H - 34 - 52 - 64
    avail_h = area_bottom - area_top - 12
    scale = min((W - 64) / 100, avail_h / 148)
    pw = 100 * scale
    hagaki(c, t, (W - pw) / 2, area_top + 6, scale, RECIPIENT)
    # Page controls
    py = area_bottom + 8
    glass_button(c, t, W / 2 - 112, py, 44, 44, icon_name="chevron.left")
    c.text(W / 2, py + 28, "3 / 42", size=17, fill=t["label"], weight=600, anchor="middle")
    glass_button(c, t, W / 2 + 68, py, 44, 44, icon_name="chevron.right")
    bottom_action_bar(c, t, H - 34 - 52)
    home_indicator(c, t)
    return c


def screen_layout(t) -> Canvas:
    c = Canvas()
    c.rect(0, 0, W, H, fill=t["bg"])
    status_bar(c, t)
    nav_bar(c, t, large_title="レイアウト")
    # Preview panel
    c.rect(16, 168, W - 32, 236, fill=t["preview_bg"], rx=16)
    scale = 212 / 148
    hagaki(c, t, (W - 100 * scale) / 2, 178, scale, RECIPIENT)
    y = 428
    y = inset_group(c, t, 16, y, W - 32, [
        (row_value(t, "用紙", "はがき"), 48),
        (lambda c, x, yy, w, h: (c.text(x + 16, yy + h / 2 + 6, "書き方", size=17, fill=t["label"]), segmented(c, t, x + w - 196, yy + 8, 180, ["縦書き", "横書き"], 0, 32)), 48),
        (row_value(t, "フォント", "明朝"), 48),
        (row_toggle(t, "数字を漢数字に変換", True), 48),
    ])
    y += 20
    y = inset_group(c, t, 16, y, W - 32, [
        (row_toggle(t, "差出人を印刷", True), 48),
        (row_value(t, "差出人", "自宅"), 48),
    ])
    tab_bar(c, t, 1)
    home_indicator(c, t)
    return c


def screen_paywall(t) -> Canvas:
    c = Canvas()
    c.rect(0, 0, W, H, fill="#000000")
    status_bar(c, t, dark_content="#FFFFFF")
    c.rect(0, 64, W, H - 64, fill=t["bg"], rx=38)
    c.rect(W / 2 - 18, 70, 36, 5, fill=t["grabber"], rx=2.5)
    glass_button(c, t, W - 60, 86, 44, 44, icon_name="xmark")
    # Hero
    c.rect(W / 2 - 40, 132, 80, 80, fill=t["accent"], rx=20)
    icon(c, "envelope", W / 2, 172, 40, t["on_accent"], 2.4)
    c.text(W / 2, 252, "Pro（買い切り）", size=28, fill=t["label"], weight=700, anchor="middle")
    c.text(W / 2, 282, "一度の購入で、ずっと使えます。", size=17, fill=t["secondary"], anchor="middle")
    def feat(ic, s, sub):
        def fn(c, x, y, w, h):
            c.rect(x + 16, y + h / 2 - 16, 32, 32, fill=t["accent"], rx=8)
            icon(c, ic, x + 32, y + h / 2, 18, t["on_accent"])
            c.text(x + 60, y + h / 2 - 2, s, size=17, fill=t["label"], weight=600)
            c.text(x + 60, y + h / 2 + 18, sub, size=13, fill=t["secondary"])
        fn.inset = 44
        return fn
    y = inset_group(c, t, 16, 306, W - 32, [
        (feat("person.2", "宛先を無制限に登録", "無料版は10件まで"), 64),
        (feat("doc.text", "CSVで一括取り込み", "Excelの住所録から読み込めます"), 64),
        (feat("square.and.arrow.up", "PDFで書き出し", "保存・共有ができます"), 64),
    ])
    # Honest statements
    y += 16
    c.rect(16, y, W - 32, 128, fill=t["cell"], rx=14)
    icon(c, "checkmark.circle.fill", 40, y + 28, 20, t["success"])
    c.text(60, y + 26, "これは買い切りです。", size=15, fill=t["label"], weight=600)
    c.text(60, y + 46, "毎月・毎週の支払いは発生しません", size=15, fill=t["label"], weight=600)
    icon(c, "checkmark.circle.fill", 40, y + 76, 20, t["success"])
    c.text(60, y + 82, "広告は今後も入れません", size=15, fill=t["label"], weight=600)
    icon(c, "info.circle", 40, y + 108, 20, t["secondary"])
    c.text(60, y + 114, "印刷は無料版でも回数無制限・透かしなし", size=13, fill=t["secondary"])
    # CTA
    by = H - 34 - 150
    c.rect(16, by, W - 32, 56, fill=t["accent"], rx=28)
    c.text(W / 2, by + 35, "¥800で購入", size=19, fill=t["on_accent"], weight=700, anchor="middle")
    c.text(W / 2, by + 88, "購入の復元", size=17, fill=t["accent"], weight=600, anchor="middle")
    c.text(W / 2, by + 124, "利用規約  ・  プライバシーポリシー", size=13, fill=t["secondary"], anchor="middle")
    home_indicator(c, t)
    return c


def screen_csv(t) -> Canvas:
    c = Canvas()
    c.rect(0, 0, W, H, fill="#000000")
    status_bar(c, t, dark_content="#FFFFFF")
    c.rect(0, 64, W, H - 64, fill=t["bg"], rx=38)
    c.rect(W / 2 - 18, 70, 36, 5, fill=t["grabber"], rx=2.5)
    nav_bar(c, t, title="列の対応を確認", subtitle="住所録.csv", left=[("icon", "chevron.left")], right=[("prominent", "取り込む")], y0=84)
    y = 150
    y = inset_group(c, t, 16, y, W - 32, [
        (row_value(t, "文字コード", "Shift_JIS（自動）"), 46),
        (row_toggle(t, "1行目は見出し", True), 46),
    ])
    y += 30
    section_header(c, t, 16, y, "列の対応（アプリの項目 ← CSVの列）")
    def mp(label, col, unused=False):
        def fn(c, x, yy, w, h):
            c.text(x + 16, yy + h / 2 + 6, label, size=17, fill=t["label"])
            c.text(x + w - 40, yy + h / 2 + 6, col, size=17, fill=t["secondary"] if unused else t["accent"], anchor="end")
            icon(c, "chevron.updown", x + w - 24, yy + h / 2, 16, t["secondary"] if unused else t["accent"], 1.5)
        return fn
    y = inset_group(c, t, 16, y + 8, W - 32, [
        (mp("氏名", "名前"), 44), (mp("ふりがな", "使わない", True), 44), (mp("連名", "連名"), 44),
        (mp("郵便番号", "〒"), 44), (mp("住所", "住所"), 44), (mp("住所2", "使わない", True), 44), (mp("メモ", "備考"), 44),
    ])
    y += 30
    section_header(c, t, 16, y, "プレビュー（先頭5行）")
    y += 8
    c.rect(16, y, W - 32, 150, fill=t["cell"], rx=14)
    cols = [("氏名", 24), ("郵便番号", 118), ("住所", 206)]
    for s, cx in cols:
        c.text(16 + cx, y + 24, s, size=12, fill=t["secondary"], weight=600)
    c.line(32, y + 34, W - 32, y + 34, t["separator"], 0.6)
    data = [("青木 健", "1500001", "東京都渋谷区見本…"), ("伊藤 美咲", "2200012", "神奈川県横浜市…"), ("株式会社見本商事", "5300001", "大阪府大阪市北区…"), ("佐藤 一郎", "4600008", "愛知県名古屋市…")]
    for i, row in enumerate(data):
        for (s, cx), v in zip(cols, row):
            c.text(16 + cx, y + 56 + i * 26, v if len(v) <= (5 if cx == 24 else 8) else v[:(5 if cx == 24 else 7)] + "…", size=13, fill=t["label"])
    y += 150
    c.rect(16, y + 14, W - 32, 50, fill=t["warning_fill"], rx=12)
    icon(c, "exclamationmark.triangle.fill", 36, y + 39, 16, t["warning"])
    c.text(52, y + 35, "86行中 84件を取り込みます", size=14, fill=t["warning"], weight=600)
    c.text(52, y + 54, "重複の可能性 2件はスキップ（変更できます）", size=13, fill=t["warning"])
    home_indicator(c, t)
    return c


def screen_settings(t) -> Canvas:
    c = Canvas()
    c.rect(0, 0, W, H, fill=t["bg"])
    status_bar(c, t)
    nav_bar(c, t, large_title="設定")
    y = 176
    section_header(c, t, 16, y, "差出人と印刷")
    y = inset_group(c, t, 16, y + 8, W - 32, [
        (row_value(t, "差出人プロフィール", "2件", icon_name="person.crop.circle", icon_bg="#2E7D5B"), 44),
        (row_value(t, "印刷位置の調整", None, icon_name="arrow.up.and.down.and.arrow.left.and.right", icon_bg="#6B6B70"), 44),
    ])
    y += 26
    section_header(c, t, 16, y, "Pro")
    def owned(c, rx, ry, rh):
        pill(c, rx, ry + rh / 2 - 11, "購入済み", t["success"], t["fill"], icon_name="checkmark", anchor_end=True)
    y = inset_group(c, t, 16, y + 8, W - 32, [
        (row_value(t, "Pro（買い切り）", None, icon_name="tag", icon_bg=t["accent"] if t is LIGHT else "#3D6CB0", badge=owned), 44),
        (row_text(t, "購入の復元", icon_name="arrow.clockwise", color=t["accent"]), 44),
    ])
    y += 26
    section_header(c, t, 16, y, "データ")
    y = inset_group(c, t, 16, y + 8, W - 32, [
        (row_text(t, "CSVテンプレートを書き出す", icon_name="square.and.arrow.up", color=t["accent"]), 44),
        (row_text(t, "印刷記録をリセット…", color=t["destructive"]), 44),
    ])
    y += 26
    section_header(c, t, 16, y, "このアプリについて")
    y = inset_group(c, t, 16, y + 8, W - 32, [
        (row_value(t, "プライバシーポリシー", None, icon_name="hand.raised", icon_bg="#3478F6" if t is LIGHT else "#0A84FF"), 44),
        (row_value(t, "利用規約", None, icon_name="doc.text", icon_bg="#6B6B70"), 44),
        (row_value(t, "バージョン", "1.0.0", chevron=False), 44),
    ])
    c.text(32, y + 22, "広告なし。宛先データはこの端末内だけに保存されます。", size=13, fill=t["secondary"])
    tab_bar(c, t, 2)
    home_indicator(c, t)
    return c


def screen_empty(t) -> Canvas:
    c = Canvas()
    c.rect(0, 0, W, H, fill=t["bg"])
    status_bar(c, t)
    nav_bar(c, t, large_title="すべての宛先", left=[("icon", "chevron.left")], right=[("icongroup", ["plus", "ellipsis"])])
    cy = 330
    icon(c, "person.2", W / 2, cy, 64, t["tertiary"])
    c.text(W / 2, cy + 74, "宛先がありません", size=22, fill=t["label"], weight=700, anchor="middle")
    c.text(W / 2, cy + 104, "宛先を登録すると、ここに一覧で表示されます。", size=15, fill=t["secondary"], anchor="middle")
    by = cy + 140
    c.rect(W / 2 - 120, by, 240, 50, fill=t["accent"], rx=25)
    c.text(W / 2, by + 32, "手入力で追加", size=17, fill=t["on_accent"], weight=600, anchor="middle")
    c.rect(W / 2 - 120, by + 62, 240, 50, fill=t["fill"], rx=25)
    c.text(W / 2, by + 94, "連絡先から取り込む", size=17, fill=t["accent"], weight=600, anchor="middle")
    c.rect(W / 2 - 120, by + 124, 240, 50, fill=t["fill"], rx=25)
    c.text(W / 2 - 14, by + 156, "CSVから取り込む", size=17, fill=t["accent"], weight=600, anchor="middle")
    pill(c, W / 2 + 62, by + 138, "Pro", t["accent"], t["cell"], size=12)
    tab_bar(c, t, 0)
    home_indicator(c, t)
    return c


def screen_recipients_ax(t) -> Canvas:
    """Dynamic Type accessibility5 — rows stack vertically, no truncation."""
    c = Canvas()
    c.rect(0, 0, W, H, fill=t["bg"])
    status_bar(c, t)
    nav_bar(c, t, left=[("icon", "chevron.left")], right=[("icon", "ellipsis")])
    c.text(16, 156, "年賀状", size=44, fill=t["label"], weight=700)
    c.text(16, 206, "2026", size=44, fill=t["label"], weight=700)
    y = 236
    def axrow(name, honor, zipc, addr_lines, status):
        def fn(c, x, yy, w, h):
            c.text(x + 16, yy + 44, name, size=34, fill=t["label"], weight=600)
            c.text(x + 16, yy + 86, honor, size=34, fill=t["label"])
            ly = yy + 126
            c.text(x + 16, ly, f"〒{zipc[:3]}-{zipc[3:]}", size=28, fill=t["secondary"])
            for i, ln in enumerate(addr_lines):
                c.text(x + 16, ly + 36 * (i + 1), ln, size=28, fill=t["secondary"])
            if status:
                pill(c, x + 16, ly + 36 * len(addr_lines) + 16, "印刷済み 12/1", t["success"], t["fill"], icon_name="checkmark", size=24)
        return fn
    inset_group(c, t, 16, y, W - 32, [
        (axrow("青木 健", "様", "1500001", ["東京都渋谷区", "見本町2-3-1"], True), 300),
        (axrow("伊藤 美咲", "様", "2200012", ["神奈川県横浜市"], False), 230),
    ])
    tab_bar(c, t, 0)
    home_indicator(c, t)
    return c


# ---------------------------------------------------------------------------
# iPad (landscape 11-inch)
# ---------------------------------------------------------------------------

def ipad_split(t) -> Canvas:
    c = Canvas()
    c.rect(0, 0, IPAD_W, IPAD_H, fill=t["bg"])
    # Sidebar (floating glass panel in iPadOS 26)
    sbw = 300
    c.rect(10, 10, sbw, IPAD_H - 20, fill=t["cell"], rx=26, stroke=t["glass_stroke"], sw=0.6)
    status_bar(c, t, w=IPAD_W)
    c.text(32, 108, "宛先", size=28, fill=t["label"], weight=700)
    def sb(y, ic, s, n, sel=False):
        if sel:
            c.rect(22, y - 22, sbw - 24, 44, fill=t["accent"], rx=12)
        col = t["on_accent"] if sel else t["label"]
        icon(c, ic, 46, y, 20, t["on_accent"] if sel else t["accent"])
        c.text(70, y + 6, s, size=17, fill=col)
        c.text(sbw - 14, y + 6, n, size=17, fill=t["on_accent"] if sel else t["secondary"], anchor="end")
    sb(150, "person.2", "すべての宛先", "128")
    sb(196, "tray", "未印刷", "42")
    c.text(32, 248, "グループ", size=13, fill=t["secondary"], weight=600)
    sb(282, "folder", "年賀状2026", "86", True)
    sb(328, "folder", "仕事関係", "32")
    sb(374, "folder", "親戚", "10")
    icon(c, "plus", 46, 420, 18, t["accent"])
    c.text(70, 426, "グループを追加", size=17, fill=t["accent"])
    # Tab switcher at top (iPadOS 26 style) — tabs move into the top area on iPad
    tx = IPAD_W / 2 - 150
    c.rect(tx + 120, 16, 300, 44, fill=t["glass"], rx=22, op=t["glass_op"], stroke=t["glass_stroke"], sw=0.6)
    for i, s in enumerate(["宛先", "レイアウト", "設定"]):
        cx = tx + 120 + 50 + i * 100
        if i == 0:
            c.rect(cx - 46, 20, 92, 36, fill=t["fill"], rx=18)
        c.text(cx, 44, s, size=15, fill=t["accent"] if i == 0 else t["label"], weight=600, anchor="middle")
    # Content column
    cx0 = sbw + 20
    cw = 400
    c.text(cx0 + 16, 112, "年賀状2026", size=28, fill=t["label"], weight=700)
    c.text(cx0 + 16, 136, "86件 ・ 未印刷 42件", size=15, fill=t["secondary"])
    nav_bar(c, t, right=[("icongroup", ["printer", "plus", "ellipsis"])], w=cw, x0=cx0, y0=60)
    search_field(c, t, cx0 + 16, 152, cw - 32, "氏名・住所で検索")
    segmented(c, t, cx0 + 16, 204, cw - 32, ["すべて", "未印刷", "印刷済み"], 0)
    rows = [
        (recipient_row(t, "青木 健", "様", None, "1500001", "東京都渋谷区見本町…", "printed"), 76),
        (recipient_row(t, "伊藤 美咲", "様", None, "2200012", "神奈川県横浜市西区…", None), 76),
        (recipient_row(t, "株式会社見本商事", "御中", None, "5300001", "大阪府大阪市北区…", "overflow"), 76),
        (recipient_row(t, "佐藤 一郎", "先生", None, "4600008", "愛知県名古屋市中区…", None, memo="喪中（2026）"), 92),
        (recipient_row(t, "山田 太郎", "様", "花子", "1040061", "東京都中央区見本町…", "printed"), 76),
    ]
    # Highlight selected row (Yamada)
    inset_group(c, t, cx0 + 16, 254, cw - 32, rows)
    c.rect(cx0 + 16, 254 + 76 * 3 + 92, cw - 32, 76, fill=t["accent"], op=0.12, rx=0)
    # Detail column
    dx0 = cx0 + cw
    dw = IPAD_W - dx0
    c.line(dx0, 0, dx0, IPAD_H, t["separator"], 0.6)
    nav_bar(c, t, right=[("text", "編集")], w=dw, x0=dx0, y0=60)
    c.text(dx0 + 24, 112, "山田 太郎 様", size=28, fill=t["label"], weight=700)
    c.text(dx0 + 24, 138, "連名: 花子 様", size=15, fill=t["secondary"])
    c.rect(dx0 + 24, 156, 210, 300, fill=t["preview_bg"], rx=16)
    sc = 276 / 148
    hagaki(c, t, dx0 + 24 + (210 - 100 * sc) / 2, 168, sc, RECIPIENT)
    ix = dx0 + 254
    c.text(ix, 176, "〒104-0061", size=17, fill=t["label"])
    c.text(ix, 202, "東京都中央区見本町1-13-3", size=17, fill=t["label"])
    c.text(ix, 228, "サンプルハイツ203", size=17, fill=t["label"])
    c.text(ix, 268, "グループ", size=13, fill=t["secondary"], weight=600)
    c.text(ix, 292, "年賀状2026", size=17, fill=t["label"])
    c.text(ix, 332, "印刷履歴", size=13, fill=t["secondary"], weight=600)
    pill(c, ix, 342, "2026/12/01 はがき", t["success"], t["fill"], icon_name="checkmark")
    c.rect(dx0 + 24, 480, dw - 48, 52, fill=t["accent"], rx=26)
    icon(c, "printer", dx0 + dw / 2 - 80, 506, 20, t["on_accent"])
    c.text(dx0 + dw / 2 + 10, 513, "この宛先を印刷", size=17, fill=t["on_accent"], weight=600, anchor="middle")
    home_indicator(c, t, w=IPAD_W, h=IPAD_H)
    return c


def ipad_preview(t) -> Canvas:
    c = Canvas()
    c.rect(0, 0, IPAD_W, IPAD_H, fill=t["preview_bg"])
    status_bar(c, t, w=IPAD_W)
    panel_w = 320
    nav_bar(c, t, title="印刷プレビュー", subtitle="年賀状2026 ・ はがき 縦書き", left=[("icon", "xmark")], w=IPAD_W - panel_w, x0=0, y0=24)
    # Paper area fits the whole sheet
    top, bottom = 84, IPAD_H - 24
    avail_w, avail_h = IPAD_W - panel_w - 64, bottom - top - 16
    scale = min(avail_w / 100, avail_h / 148)
    pw = 100 * scale
    hagaki(c, t, (IPAD_W - panel_w - pw) / 2, top + 4, scale, RECIPIENT)
    # Dimension annotation
    c.text((IPAD_W - panel_w) / 2, bottom + 12, "", size=1, fill=t["secondary"])
    # Side panel
    px = IPAD_W - panel_w
    c.rect(px, 0, panel_w, IPAD_H, fill=t["bg"])
    c.line(px, 0, px, IPAD_H, t["separator"], 0.6)
    c.text(px + 20, 96, "3 / 42", size=28, fill=t["label"], weight=700)
    glass_button(c, t, px + panel_w - 120, 66, 44, 44, icon_name="chevron.left")
    glass_button(c, t, px + panel_w - 64, 66, 44, 44, icon_name="chevron.right")
    c.text(px + 20, 140, "山田 太郎 様 ・ 花子 様", size=17, fill=t["label"], weight=600)
    c.text(px + 20, 164, "〒104-0061 東京都中央区見本町…", size=15, fill=t["secondary"])
    c.rect(px + 16, 184, panel_w - 32, 64, fill=t["warning_fill"], rx=12)
    icon(c, "exclamationmark.triangle.fill", px + 38, 206, 18, t["warning"])
    c.text(px + 56, 212, "12月1日に印刷済み", size=15, fill=t["warning"], weight=600)
    c.text(px + 56, 234, "二重印刷にご注意ください", size=13, fill=t["warning"])
    c.text(px + 20, 284, "印刷する範囲", size=13, fill=t["secondary"], weight=600)
    segmented(c, t, px + 16, 296, panel_w - 32, ["未印刷のみ（42）", "全件（86）"], 0)
    c.text(px + 20, 364, "用紙", size=13, fill=t["secondary"], weight=600)
    c.rect(px + 16, 374, panel_w - 32, 96, fill=t["cell"], rx=14)
    c.text(px + 32, 404, "はがき 100×148mm", size=17, fill=t["label"])
    c.line(px + 32, 420, px + panel_w - 16, 420, t["separator"], 0.6)
    c.text(px + 32, 452, "位置調整  上+0.5 / 左-1.0 mm", size=15, fill=t["secondary"])
    # Actions
    c.rect(px + 16, IPAD_H - 160, panel_w - 32, 56, fill=t["accent"], rx=28)
    icon(c, "printer", px + panel_w / 2 - 62, IPAD_H - 132, 20, t["on_accent"])
    c.text(px + panel_w / 2 + 12, IPAD_H - 125, "42件を印刷", size=19, fill=t["on_accent"], weight=700, anchor="middle")
    c.rect(px + 16, IPAD_H - 92, panel_w - 32, 52, fill=t["fill"], rx=26)
    icon(c, "square.and.arrow.up", px + panel_w / 2 - 66, IPAD_H - 66, 20, t["accent"])
    c.text(px + panel_w / 2 + 6, IPAD_H - 59, "PDFで書き出す", size=17, fill=t["accent"], weight=600, anchor="middle")
    home_indicator(c, t, w=IPAD_W, h=IPAD_H)
    return c


# ---------------------------------------------------------------------------
# Sheets
# ---------------------------------------------------------------------------

def device_frame(sheet: Canvas, x, y, screen: Canvas, w, h, radius, bezel, clip_id, caption, sub=None, frame_color="#1C1C1E"):
    sheet.rect(x - bezel, y - bezel, w + bezel * 2, h + bezel * 2, fill=frame_color, rx=radius + bezel)
    sheet.rect(x - bezel + 1.5, y - bezel + 1.5, w + bezel * 2 - 3, h + bezel * 2 - 3, stroke="#3A3A3C", sw=1.2, rx=radius + bezel - 1.5)
    sheet.group(x, y, screen, clip_id=clip_id)
    sheet.text(x + w / 2, y + h + bezel + 40, caption, size=20, fill="#1C1C1E", weight=700, anchor="middle")
    if sub:
        sheet.text(x + w / 2, y + h + bezel + 66, sub, size=15, fill="#5E5E63", anchor="middle")


def build_sheet(name, title, subtitle, screens, cols, notes):
    gap_x, gap_y = 70, 130
    bezel = 12
    sheet = Canvas()
    rows = (len(screens) + cols - 1) // cols
    sw = 60 + cols * (W + bezel * 2) + (cols - 1) * gap_x + 60
    sh = 150 + rows * (H + bezel * 2 + gap_y) + 40 + 26 * len(notes)
    sheet.rect(0, 0, sw, sh, fill="#F5F5F7")
    sheet.text(60, 70, title, size=34, fill="#1C1C1E", weight=800)
    sheet.text(60, 104, subtitle, size=17, fill="#5E5E63")
    defs = f'<clipPath id="iphone"><rect x="0" y="0" width="{W}" height="{H}" rx="55"/></clipPath>'
    for i, (scr, cap, sub) in enumerate(screens):
        r, col = divmod(i, cols)
        x = 60 + bezel + col * (W + bezel * 2 + gap_x)
        y = 150 + bezel + r * (H + bezel * 2 + gap_y)
        device_frame(sheet, x, y, scr, W, H, 55, bezel, "iphone", cap, sub)
    ny = sh - 26 * len(notes) - 20
    for i, n in enumerate(notes):
        sheet.text(60, ny + i * 26, n, size=15, fill="#3C3C43")
    with open(os.path.join(OUT_DIR, name), "w", encoding="utf-8") as f:
        f.write(sheet.svg(sw, sh, defs))


def build_ipad_sheet(name, title, subtitle, screens, notes):
    bezel = 18
    gap_y = 130
    sheet = Canvas()
    sw = 60 + IPAD_W + bezel * 2 + 60
    sh = 150 + len(screens) * (IPAD_H + bezel * 2 + gap_y) + 26 * len(notes) + 20
    sheet.rect(0, 0, sw, sh, fill="#F5F5F7")
    sheet.text(60, 70, title, size=34, fill="#1C1C1E", weight=800)
    sheet.text(60, 104, subtitle, size=17, fill="#5E5E63")
    defs = f'<clipPath id="ipad"><rect x="0" y="0" width="{IPAD_W}" height="{IPAD_H}" rx="18"/></clipPath>'
    for i, (scr, cap, sub) in enumerate(screens):
        x = 60 + bezel
        y = 150 + bezel + i * (IPAD_H + bezel * 2 + gap_y)
        device_frame(sheet, x, y, scr, IPAD_W, IPAD_H, 18, bezel, "ipad", cap, sub)
    ny = sh - 26 * len(notes) - 10
    for i, n in enumerate(notes):
        sheet.text(60, ny + i * 26, n, size=15, fill="#3C3C43")
    with open(os.path.join(OUT_DIR, name), "w", encoding="utf-8") as f:
        f.write(sheet.svg(sw, sh, defs))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    common_notes = [
        "※ アイコンは SF Symbols の簡略表現。実装では SF Symbols を使用。サンプルの氏名・住所はすべて架空。",
        "※ 郵便番号枠: 位置は日本郵便の JIS 仕様（上端12mm・右端8mm）。枠の幅・間隔は暫定値で、②で一次情報を確認して確定。プレビュー専用で印刷しない。",
    ]
    build_sheet(
        "01-iphone-core-light.svg",
        "iPhone ・ 主要画面（ライト）",
        "iPhone 16 / 393×852pt ・ 縦向き固定 ・ 標準文字サイズ（Large）",
        [
            (screen_groups(LIGHT), "S01 宛先（グループ）", "タブのルート画面。compact 幅ではサイドバーがこの一覧になる"),
            (screen_recipients(LIGHT), "S02 宛先一覧", "下部: 追加 / 一括印刷（親指の届く位置）"),
            (screen_edit(LIGHT), "S04 宛先を編集", "シート ・ Form"),
            (screen_preview(LIGHT), "S07 印刷プレビュー", "用紙全体を表示 ・ 二重印刷の警告"),
            (screen_layout(LIGHT), "S09 レイアウト", "上: ライブプレビュー / 下: 設定"),
            (screen_paywall(LIGHT), "S13 Pro（買い切り）", "ユーザーが操作したときだけ表示"),
        ],
        3,
        common_notes,
    )
    build_sheet(
        "02-iphone-states.svg",
        "iPhone ・ 補助画面・ダークモード・Dynamic Type",
        "ダークでも用紙は紙色のまま ・ 最大文字サイズでは縦に積んで省略しない",
        [
            (screen_csv(LIGHT), "S06 CSV取り込み（列の対応）", "文字コード自動判定 ・ 重複の可能性はスキップ"),
            (screen_settings(LIGHT), "S10 設定", "購入の復元 ・ 規約リンク"),
            (screen_empty(LIGHT), "空状態（宛先0件）", "ContentUnavailableView ・ 次の操作を提示"),
            (screen_recipients(DARK), "S02 宛先一覧（ダーク）", "アセットカタログの Dark 値"),
            (screen_preview(DARK), "S07 印刷プレビュー（ダーク）", "周囲を暗くし、紙は白のまま"),
            (screen_recipients_ax(LIGHT), "S02（Dynamic Type 最大）", "accessibility5 ・ 行を縦積みに切り替え"),
        ],
        3,
        common_notes,
    )
    build_ipad_sheet(
        "03-ipad-landscape.svg",
        "iPad ・ 横向き（11インチ 1194×834pt）",
        "regular 幅: 3カラム表示 / 印刷プレビューは左に用紙全体・右にサイドパネル（320pt）",
        [
            (ipad_split(LIGHT), "宛先タブ（S01＋S02＋S03）", "NavigationSplitView ・ 狭い分割表示では自動で2カラム→1カラム"),
            (ipad_preview(LIGHT), "S07 印刷プレビュー（横向き）", "縮尺 = min(幅比, 高さ比) で用紙全体を必ず表示"),
        ],
        common_notes,
    )


if __name__ == "__main__":
    main()
