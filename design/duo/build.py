#!/usr/bin/env python3
"""Builds the iPhone Duo design mocks for 「宛名印刷 はがき・封筒」 (hig-design-skill).

Positions of system UI on iPhone Duo (side column, camera, fold band) are approximations:
Apple has not published them. Side column width (84pt) and bottom inset (34pt) are the safe
areas measured on the Xcode 27.1 iPhone Duo simulator. All names and addresses are fictional.
Run: python3 design/duo/build.py, then export_png.py / check_mocks.py on design/duo/mocks.
"""
from pathlib import Path
from xml.sax.saxutils import escape

OUT = Path(__file__).resolve().parent / "mocks"
OUT.mkdir(exist_ok=True)
FONT = "-apple-system, 'SF Pro Text', 'Hiragino Sans', 'Noto Sans JP', 'Noto Sans CJK JP', sans-serif"
MINCHO = "'Hiragino Mincho ProN', 'Noto Serif CJK JP', 'Noto Serif JP', serif"

# App colour tokens (Assets.xcassets) + system colours (approximate values from hig-specs.md).
THEMES = {
    "light": dict(bg="#F2F2F7", cell="#FFFFFF", label="#000000", sec="#5E5E63", sep="#C6C6C8",
                  accent="#24569B", on_accent="#FFFFFF", glass="#FFFFFF", glass_op=0.85, glass_stroke="#D1D1D6",
                  success="#1E7B34", warn="#B04A00", warn_fill="#FFF1E5", preview="#E5E5EA", paper="#FFFFFF",
                  ink="#1A1A1A", postal="#E0322B", guide="#B8B8BE", sheet="#FFFFFF", field="#F2F2F7",
                  tint="#E3EAF4", kb="#D1D3D9", seg="#E3E3E8", seg_on="#FFFFFF"),
    "dark": dict(bg="#000000", cell="#1C1C1E", label="#FFFFFF", sec="#AEAEB2", sep="#38383A",
                 accent="#8DB3EC", on_accent="#000000", glass="#2C2C2E", glass_op=0.85, glass_stroke="#48484A",
                 success="#5BD37A", warn="#FFB35C", warn_fill="#3A2614", preview="#111113", paper="#FAFAF7",
                 ink="#1A1A1A", postal="#E0322B", guide="#6E6E73", sheet="#1C1C1E", field="#2C2C2E",
                 tint="#24303F", kb="#2C2C2E", seg="#2C2C2E", seg_on="#636366"),
}

RECIPIENTS = [  # fictional
    ("青木 健", "様", "〒150-0001 東京都渋谷区見本町2-3-1", "印刷済み 12/1"),
    ("伊藤 美咲", "様", "〒220-0012 神奈川県横浜市西区見本台4-5-6", None),
    ("株式会社見本商事", "御中", "〒530-0001 大阪府大阪市北区見本通1-1-1", None),
    ("佐藤 一郎", "先生", "〒460-0008 愛知県名古屋市中区見本町3-2", None),
    ("山田 太郎", "様", "〒104-0061 東京都中央区見本町1-13-3", "印刷済み 12/1"),
]

OUTER = (466, 678)
INNER_L = (951, 669)
INNER_P = (669, 951)
SIDE = 84      # trailing side column (measured safe area)
BOTTOM = 34    # bottom safe area (measured)
FOLD = 13      # half width of the fold band (rule of thumb from hig-specs.md, not an Apple value)


def T(x, y, s, size, fill, weight=400, anchor="start", bg=None, font=None, extra=""):
    b = f' data-bg="{bg}"' if bg else ""
    return (f'<text x="{x:g}" y="{y:g}" font-family="{font or FONT}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}"{b}{extra}>{escape(s)}</text>')


def svg(w, h, bg, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" '
            f'data-bg="{bg}"><rect width="100%" height="100%" fill="{bg}"/>{body}</svg>\n')


def mix(fg, bg, a):
    f = [int(fg[i:i + 2], 16) for i in (1, 3, 5)]
    g = [int(bg[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x * a + y * (1 - a)):02X}" for x, y in zip(f, g))


def glass_btn(cx, cy, t, r=22):
    return (f'<circle cx="{cx:g}" cy="{cy:g}" r="{r}" fill="{t["glass"]}" fill-opacity="{t["glass_op"]}" '
            f'stroke="{t["glass_stroke"]}"/>')


def sym(kind, cx, cy, c, w=2.2):
    """Line stand-ins for SF Symbols (the app uses the real symbols)."""
    g = f'<g fill="none" stroke="{c}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round">'
    d = {
        "chevron.backward": f'<path d="M{cx+4} {cy-9}l-9 9 9 9"/>',
        "chevron.forward": f'<path d="M{cx-4} {cy-9}l9 9-9 9"/>',
        "xmark": f'<path d="M{cx-7} {cy-7}l14 14M{cx+7} {cy-7}l-14 14"/>',
        "checkmark": f'<path d="M{cx-8} {cy+1}l5 6 11-13"/>',
        "ellipsis": "",
        "plus": f'<path d="M{cx} {cy-9}v18M{cx-9} {cy}h18"/>',
        "printer": f'<path d="M{cx-6} {cy-9}h12v5M{cx-10} {cy-4}h20v10h-4M{cx-10} {cy+6}h4M{cx-6} {cy+2}h12v8h-12z"/>',
        "pencil": f'<path d="M{cx-8} {cy+8}l2-6 10-10 4 4-10 10z"/>',
        "magnifyingglass": f'<circle cx="{cx-2}" cy="{cy-2}" r="7"/><path d="M{cx+3} {cy+3}l5 5"/>',
        "sidebar.left": f'<rect x="{cx-11}" y="{cy-9}" width="22" height="18" rx="3"/><path d="M{cx-4} {cy-9}v18"/>',
        "square.and.arrow.up": f'<path d="M{cx} {cy-10}v13M{cx-5} {cy-5}l5-5 5 5M{cx-8} {cy-1}h-2v11h20v-11h-2"/>',
        "person.2": f'<circle cx="{cx-5}" cy="{cy-4}" r="4"/><path d="M{cx-13} {cy+9}a8 7 0 0 1 16 0"/>'
                    f'<circle cx="{cx+6}" cy="{cy-5}" r="3.5"/><path d="M{cx+5} {cy+2}a7 6 0 0 1 8 6"/>',
    }[kind]
    if kind == "ellipsis":
        return "".join(f'<circle cx="{cx+dx}" cy="{cy}" r="2.2" fill="{c}"/>' for dx in (-7, 0, 7))
    return g + d + "</g>"


def tab_icon(kind, cx, cy, c, cut):
    """Filled stand-ins for the tab symbols (person.2.fill / envelope.fill / gearshape.fill)."""
    if kind == "person":
        return (f'<circle cx="{cx-5}" cy="{cy-5}" r="5" fill="{c}"/><path d="M{cx-14} {cy+9}a9 8 0 0 1 18 0z" fill="{c}"/>'
                f'<circle cx="{cx+7}" cy="{cy-6}" r="4" fill="{c}"/><path d="M{cx+3} {cy+9}h11a7 7 0 0 0-11-6z" fill="{c}"/>')
    if kind == "envelope":
        return (f'<rect x="{cx-11}" y="{cy-8}" width="22" height="16" rx="2.5" fill="{c}"/>'
                f'<path d="M{cx-10} {cy-6}l10 7 10-7" fill="none" stroke="{cut}" stroke-width="1.6"/>')
    teeth = "".join(f'<rect x="{cx-2.5}" y="{cy-12}" width="5" height="6" rx="1" fill="{c}" '
                    f'transform="rotate({a} {cx} {cy})"/>' for a in range(0, 360, 45))
    return (teeth + f'<circle cx="{cx}" cy="{cy}" r="8.5" fill="{c}"/><circle cx="{cx}" cy="{cy}" r="3.4" fill="{cut}"/>')


def side_column(w, h, t, tools=(), tabs=True, active=0, camera=True):
    """Trailing column on the outer display and the inner landscape display:
    camera (outer only) → status bar → toolbar → tab bar (bottom-aligned).

    Toolbar and tab bar positions are measured on the Xcode 27.1 iPhone Duo simulator (app build):
    column centre 48.5pt from the trailing edge; outer toolbar buttons 50pt round, first centre at
    y = 198, 60pt apart; tab bar 49 × 164pt ending 23pt above the bottom edge. Camera and status bar
    are drawn by the system and were not captured: their positions are an approximation."""
    cx = w - 48.5
    p = []
    if camera:
        p.append(f'<rect x="{cx-15}" y="14" width="30" height="30" rx="15" fill="#000000"/>')
        p.append(T(cx, 74, "9:41", 15, t["label"], 600, "middle"))
        battery_y = 88
        y = 198
    else:
        p.append(T(cx, 34, "9:41", 15, t["label"], 600, "middle"))
        battery_y = 48
        y = 110  # inner display: not measured (the app had no symbol toolbar items there); approximation
    p.append(f'<rect x="{cx-12}" y="{battery_y}" width="22" height="11" rx="3" fill="none" stroke="{t["label"]}" '
             f'stroke-opacity="0.45"/><rect x="{cx-10}" y="{battery_y+2}" width="16" height="7" rx="1.5" fill="{t["label"]}"/>')
    assert not tools or y - 25 - (battery_y + 11) >= 16  # keep the status bar clear of the toolbar
    for kind, color in tools:  # toolbar: back/close first, then the emphasized action, then the rest
        if kind == "checkmark":
            p.append(f'<circle cx="{cx}" cy="{y}" r="25" fill="{t["accent"]}"/>' + sym(kind, cx, y, t["on_accent"], 2.6))
        else:
            p.append(glass_btn(cx, y, t, r=25) + sym(kind, cx, y, color or t["label"]))
        y += 60
    if tabs:
        tw, th = 49, 164
        ty = h - 23 - th
        p.append(f'<rect x="{cx-tw/2}" y="{ty}" width="{tw}" height="{th}" rx="{tw/2}" fill="{t["glass"]}" '
                 f'fill-opacity="{t["glass_op"]}" stroke="{t["glass_stroke"]}"/>')
        step = th / 3
        for k, kind in enumerate(("person", "envelope", "gear")):
            ky = ty + step * k + step / 2
            on = k == active
            cut = mix(t["accent"], t["glass"], 0.14) if on else t["glass"]
            if on:
                p.append(f'<rect x="{cx-20.5}" y="{ky-24}" width="41" height="48" rx="20.5" fill="{cut}"/>')
            p.append(tab_icon(kind, cx, ky, t["accent"] if on else t["label"], cut))
    return "".join(p)


def segmented(x, y, wdt, t, labels=("すべて", "未印刷", "印刷済み"), on=0, size=15):
    h = 34
    p = [f'<rect x="{x}" y="{y}" width="{wdt}" height="{h}" rx="17" fill="{t["seg"]}"/>']
    sw = wdt / len(labels)
    for i, lab in enumerate(labels):
        bg = t["seg"]
        if i == on:
            bg = t["seg_on"]
            p.append(f'<rect x="{x+i*sw+2:g}" y="{y+2}" width="{sw-4:g}" height="{h-4}" rx="15" fill="{bg}"/>')
        p.append(T(x + i * sw + sw / 2, y + 22, lab, size, t["label"], 600 if i == on else 400, "middle", bg=bg))
    return "".join(p)


def badge(x, y, text, t, bg):
    w = 14 * len(text) * 0.62 + 30
    fill = mix(t["success"], bg, 0.14)
    return (f'<rect x="{x-w:g}" y="{y-17}" width="{w:g}" height="24" rx="12" fill="{fill}"/>'
            + sym("checkmark", x - w + 15, y - 5, t["success"], 1.8).replace("l5 6 11-13", "l3 4 7-9")
            + T(x - 10, y, text, 13, t["success"], 600, "end", bg=fill))


def rows(x, y, wdt, t, n=5, sel=None, trunc=20, fold_ok=False):
    p = [f'<g{" data-fold-ok=\"1\"" if fold_ok else ""}>',
         f'<rect x="{x}" y="{y}" width="{wdt}" height="{n*72}" rx="22" fill="{t["cell"]}"/>']
    for i, (name, hon, addr, printed) in enumerate(RECIPIENTS[:n]):
        cy = y + i * 72
        bg = t["cell"]
        if sel == i:
            bg = mix(t["accent"], t["cell"], 0.16)
            p.append(f'<rect x="{x+6}" y="{cy+5}" width="{wdt-12}" height="62" rx="16" fill="{bg}"/>')
        p.append(T(x + 18, cy + 30, name, 17, t["label"], 600, bg=bg)
                 + T(x + 18 + 17 * len(name.replace(" ", "")) + (5 if " " in name else 0) + 6, cy + 30, hon, 13, t["label"], 400, bg=bg))
        a = addr if len(addr) <= trunc else addr[:trunc] + "…"
        p.append(T(x + 18, cy + 54, a, 15, t["sec"], 400, bg=bg))
        if printed and wdt >= 300:
            p.append(badge(x + wdt - 34, cy + 31, printed, t, bg))
        p.append(sym("chevron.forward", x + wdt - 18, cy + 36, t["sec"], 1.8).replace('stroke-width="1.8"', 'stroke-width="1.8" stroke-opacity="0.6"'))
        if i < n - 1:
            p.append(f'<rect x="{x+18}" y="{cy+71.5}" width="{wdt-18}" height="0.5" fill="{t["sep"]}"/>')
    p.append("</g>")
    return "".join(p)


def paper(x, y, w, t, name=("山田", "太郎"), addr="東京都中央区見本町一―一三―三", code="1040061",
          joint="花子", building="サンプルハイツ二〇三", sender=True, shadow=True):
    """Postcard (100×148) with 7 postal boxes and vertical text: address (2 columns), name with the
    joint name next to it (honorifics aligned), sender at the lower left. Paper stays white in dark mode."""
    h = w * 1.48
    p = []
    if shadow:
        p.append(f'<rect x="{x+1}" y="{y+2}" width="{w}" height="{h:g}" rx="2" fill="#000000" fill-opacity="0.12"/>')
    p.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h:g}" rx="2" fill="{t["paper"]}"/>')
    s = w / 100  # pt per mm
    bx = [0, 7.0, 14.0, 21.6, 28.4, 35.2, 42.0]
    left = x + w - 8 * s - 47.7 * s
    for k, off in enumerate(bx):
        p.append(f'<rect x="{left+off*s:g}" y="{y+12*s:g}" width="{5.7*s:g}" height="{8*s:g}" fill="none" '
                 f'stroke="{t["postal"]}" stroke-width="{max(0.8, 0.35*s):g}"/>')
    for k, ch in enumerate(code):
        p.append(T(left + (bx[k] + 2.85) * s, y + 18.4 * s, ch, max(11, round(5 * s)), t["ink"], 400, "middle",
                   bg=t["paper"], font=MINCHO))
    a_size = max(11, round(4.6 * s))
    ax = x + w - 14 * s
    for k, ch in enumerate(addr):
        p.append(T(ax, y + 30 * s + k * a_size * 1.02, ch, a_size, t["ink"], 400, "middle", bg=t["paper"], font=MINCHO))
    if building:
        for k, ch in enumerate(building):
            p.append(T(ax - a_size * 1.3, y + 42 * s + k * a_size * 1.02, ch, a_size, t["ink"], 400, "middle",
                       bg=t["paper"], font=MINCHO))
    n_size = max(14, round(10 * s))
    step = n_size * 1.12
    nx = x + w / 2 + (6 * s if joint else 4 * s)
    k = 0
    for part in name:
        for ch in part:
            p.append(T(nx, y + 44 * s + k * step, ch, n_size, t["ink"], 400, "middle", bg=t["paper"], font=MINCHO))
            k += 1
        k += 0.4
    hon_y = y + 44 * s + (k + 0.3) * step
    p.append(T(nx, hon_y, "様", n_size, t["ink"], 400, "middle", bg=t["paper"], font=MINCHO))
    if joint:
        jx = nx - n_size * 1.3
        for j, ch in enumerate(joint):
            p.append(T(jx, hon_y - (len(joint) + 0.3 - j) * step, ch, n_size, t["ink"], 400, "middle",
                       bg=t["paper"], font=MINCHO))
        p.append(T(jx, hon_y, "様", n_size, t["ink"], 400, "middle", bg=t["paper"], font=MINCHO))
    if sender and s >= 1.9:
        sz = 11
        sx = x + 12 * s
        for k2, ch in enumerate("東京都見本区見本町二―五"):
            p.append(T(sx + sz * 1.2, y + h - 80 * s + k2 * sz * 1.02, ch, sz, t["ink"], 400, "middle", bg=t["paper"], font=MINCHO))
        for k2, ch in enumerate("田中一郎"):
            p.append(T(sx, y + h - 40 * s + k2 * sz * 1.1, ch, sz, t["ink"], 400, "middle", bg=t["paper"], font=MINCHO))
    return "".join(p)


AOKI = dict(name=("青木", "健"), addr="東京都渋谷区見本町二―三―一", code="1500001", joint=None, building=None)
WARNING = "2026年12月1日に印刷済みの宛先です"


def bottom_bar(x0, x1, h, t, buttons, regular=False):
    """BottomActionBar: compact = side by side filling the width; regular = label-sized at the trailing edge
    (keeps buttons off the inner display's fold)."""
    bar_h = 76
    y = h - BOTTOM - bar_h + 8
    p = [f'<rect x="{x0}" y="{h-BOTTOM-bar_h}" width="{x1-x0}" height="{bar_h+BOTTOM}" fill="{t["bg"]}" fill-opacity="0.92"/>',
         f'<rect x="{x0}" y="{h-BOTTOM-bar_h}" width="{x1-x0}" height="0.5" fill="{t["sep"]}"/>']
    if regular:
        x = x1 - 16
        for label, prominent, icon in reversed(buttons):
            bw = 17 * len(label) + 64
            x -= bw
            p.append(_btn(x, y, bw, label, prominent, icon, t))
            x -= 12
    else:
        n = len(buttons)
        widths = [110 if (not prominent and n > 1) else None for _, prominent, _ in buttons]
        free = (x1 - x0 - 32 - 12 * (n - 1) - sum(w for w in widths if w)) / max(1, sum(1 for w in widths if not w))
        x = x0 + 16
        for (label, prominent, icon), wd in zip(buttons, widths):
            bw = wd or free
            p.append(_btn(x, y, bw, label, prominent, icon, t))
            x += bw + 12
    return "".join(p)


def _btn(x, y, bw, label, prominent, icon, t, bh=52, plain=None):
    fill = t["accent"] if prominent else (plain or t["seg"])
    fg = t["on_accent"] if prominent else t["accent"]
    tw = 17 * len(label) + (28 if icon else 0)
    sx = x + bw / 2 - tw / 2
    out = f'<rect x="{x:g}" y="{y}" width="{bw:g}" height="{bh}" rx="{bh/2:g}" fill="{fill}"/>'
    if icon:
        out += sym(icon, sx + 10, y + bh / 2, fg)
        sx += 28
    return out + T(sx, y + bh / 2 + 6, label, 17, fg, 600, bg=fill)


# ---------------------------------------------------------------- outer display (466 × 678)

def outer_list(theme):
    t = THEMES[theme]
    w, h = OUTER
    cw = w - SIDE
    b = [side_column(w, h, t, tools=[("chevron.backward", None), ("ellipsis", None)])]
    b.append(T(20, 62, "年賀状2026", 34, t["label"], 700))
    b.append(f'<rect x="16" y="78" width="{cw-24}" height="36" rx="18" fill="{t["seg"]}"/>'
             + sym("magnifyingglass", 36, 96, t["sec"], 2) + T(52, 102, "氏名・住所で検索", 17, t["sec"], 400, bg=t["seg"]))
    b.append(T(20, 140, "5件・未印刷 3件", 15, t["sec"]))
    b.append(T(cw - 8, 140, "無料版：あと5件", 15, t["sec"], 400, "end"))
    b.append(segmented(16, 152, cw - 24, t))
    b.append(rows(16, 198, cw - 24, t, n=5, trunc=17))
    b.append(bottom_bar(0, cw, h, t, [("追加", False, "plus"), ("一括印刷", True, "printer")]))
    return svg(w, h, t["bg"], "".join(b))


def outer_empty(theme):
    t = THEMES[theme]
    w, h = OUTER
    cw = w - SIDE
    b = [side_column(w, h, t, tools=[("chevron.backward", None), ("ellipsis", None)])]
    b.append(T(20, 62, "年賀状2026", 34, t["label"], 700))
    cx = cw / 2
    b.append(sym("person.2", cx, 200, t["sec"], 3).replace(f'cx="{cx-5}"', f'cx="{cx-5}"'))
    b.append(T(cx, 262, "このグループには宛先がありません", 20, t["label"], 700, "middle"))
    b.append(T(cx, 292, "手入力・連絡先・CSVから追加できます。", 15, t["sec"], 400, "middle"))
    b.append(T(cx, 314, "無料版は10件まで登録できます。", 15, t["sec"], 400, "middle"))
    for i, (lab, prom) in enumerate((("手入力で追加", True), ("連絡先から追加", False), ("CSVから取り込む", False))):
        b.append(_btn(cx - 120, 344 + i * 64, 240, lab, prom, None, t))
    return svg(w, h, t["bg"], "".join(b))


def outer_ax5(theme):
    """Largest text size (AX5): the title wraps, the summary stays (own lines), the address wraps in
    full, the badge moves to its own line, the two bottom buttons stack (ViewThatFits). Search and the
    segmented control scroll above (out of view here). Bars keep their size."""
    t = THEMES[theme]
    w, h = OUTER
    cw = w - SIDE
    b = [side_column(w, h, t, tools=[("chevron.backward", None), ("ellipsis", None)])]
    b.append(T(20, 64, "年賀状", 60, t["label"], 700))
    b.append(T(20, 126, "2026", 60, t["label"], 700))
    b.append(T(20, 176, "5件・未印刷3件", 49, t["sec"]))
    b.append(T(20, 232, "無料版：あと5件", 49, t["sec"]))
    b.append(f'<rect x="16" y="252" width="{cw-24}" height="420" rx="22" fill="{t["cell"]}"/>')
    b.append(T(32, 308, "青木 健 様", 53, t["label"], 600, bg=t["cell"]))
    pill = mix(t["success"], t["cell"], 0.14)
    b.append(f'<rect x="32" y="324" width="236" height="44" rx="22" fill="{pill}"/>')
    b.append(T(50, 357, "✓ 印刷済み 12/1", 28, t["success"], 600, bg=pill))
    y = 420
    for text in ("〒150-0001", "東京都渋谷区", "見本町2-3-1"):
        b.append(T(32, y, text, 49, t["sec"], 400, bg=t["cell"]))
        y += 58
    bar_top = h - BOTTOM - 140
    b.append(f'<rect x="0" y="{bar_top}" width="{cw}" height="{140+BOTTOM}" fill="{t["bg"]}" fill-opacity="0.96"/>'
             f'<rect x="0" y="{bar_top}" width="{cw}" height="0.5" fill="{t["sep"]}"/>')
    b.append(_btn(16, bar_top + 10, cw - 32, "一括印刷", True, "printer", t, 58))
    b.append(_btn(16, bar_top + 78, cw - 32, "宛先を追加", False, "plus", t, 58))
    return svg(w, h, t["bg"], "".join(b))


def outer_detail(theme):
    t = THEMES[theme]
    w, h = OUTER
    cw = w - SIDE
    b = [side_column(w, h, t, tools=[("chevron.backward", None), ("pencil", t["accent"])])]
    b.append(T(20, 62, "山田 太郎 様", 34, t["label"], 700))
    b.append(T(20, 90, "連名：花子 様", 15, t["sec"]))
    pw = 196
    b.append(paper(cw / 2 - pw / 2, 108, pw, t))
    b.append(T(20, 434, "住所", 15, t["sec"], 600))
    b.append(f'<rect x="16" y="444" width="{cw-24}" height="96" rx="22" fill="{t["cell"]}"/>')
    b.append(T(34, 476, "〒104-0061", 17, t["label"], 400, bg=t["cell"]))
    b.append(T(34, 504, "東京都中央区見本町1-13-3", 17, t["label"], 400, bg=t["cell"]))
    b.append(T(34, 528, "サンプルハイツ203", 15, t["sec"], 400, bg=t["cell"]))
    b.append(bottom_bar(0, cw, h, t, [("この宛先を印刷", True, "printer")]))
    return svg(w, h, t["bg"], "".join(b))


def outer_preview(theme):
    """S-07 full-screen cover: no tab bar; close at the top of the side column."""
    t = THEMES[theme]
    w, h = OUTER
    cw = w - SIDE
    b = [side_column(w, h, t, tools=[("xmark", None)], tabs=False)]
    b.append(f'<rect x="0" y="0" width="{cw}" height="{h}" fill="{t["preview"]}"/>')
    b.append(T(cw / 2, 40, "印刷プレビュー", 17, t["label"], 600, "middle", bg=t["preview"]))
    b.append(T(cw / 2, 60, "はがき・縦書き", 13, t["sec"], 400, "middle", bg=t["preview"]))
    b.append(f'<rect x="16" y="76" width="{cw-32}" height="40" rx="14" fill="{t["warn_fill"]}"/>')
    b.append(T(30, 102, WARNING, 15, t["warn"], 600, bg=t["warn_fill"]))
    pw = 196
    b.append(paper(cw / 2 - pw / 2, 128, pw, t, **AOKI))
    py = 128 + pw * 1.48 + 16
    b.append(glass_btn(cw / 2 - 70, py + 22, t) + sym("chevron.backward", cw / 2 - 70, py + 22, t["sec"]))
    b.append(T(cw / 2, py + 29, "1 / 5", 17, t["label"], 600, "middle", bg=t["preview"]))
    b.append(glass_btn(cw / 2 + 70, py + 22, t) + sym("chevron.forward", cw / 2 + 70, py + 22, t["accent"]))
    by = h - BOTTOM - 120
    b.append(_btn(16, by, cw - 32, "5件を印刷", True, "printer", t))
    b.append(_btn(16, by + 62, cw - 32, "PDFで書き出す（Pro）", False, "square.and.arrow.up", t, plain=t["cell"]))
    return svg(w, h, t["preview"], "".join(b))


def outer_editor(theme):
    """S-04 editor sheet with the keyboard up. On the outer display the sheet's buttons sit in the
    side column (cancel first, save emphasized). The focused field stays above the keyboard."""
    t = THEMES[theme]
    w, h = OUTER
    cw = w - SIDE
    s = t["sheet"]
    b = [f'<rect x="0" y="0" width="{w}" height="{h}" fill="{s}"/>',
         side_column(w, h, t, tools=[("xmark", None), ("checkmark", None)], tabs=False)]
    b.append(T(cw / 2, 40, "宛先を編集", 17, t["label"], 600, "middle", bg=s))
    f = t["field"]
    fields = [("氏名", "山田 太郎"), ("ふりがな", "やまだ たろう"), ("郵便番号", "104-0061"), ("住所", "東京都中央区見本町1-13-3")]
    for i, (lab, val) in enumerate(fields):
        y = 64 + i * 72
        b.append(T(20, y + 14, lab, 13, t["sec"], 600, bg=s))
        b.append(f'<rect x="16" y="{y+22}" width="{cw-32}" height="40" rx="12" fill="{f}"'
                 + (f' stroke="{t["accent"]}" stroke-width="2"' if i == 2 else "") + "/>")
        b.append(T(30, y + 48, val, 17, t["label"], 400, bg=f))
        if i == 2:
            b.append(f'<rect x="{30+17*len(val)*0.6:g}" y="{y+31}" width="2" height="22" fill="{t["accent"]}"/>')
    kb_top = h - 252
    acc = kb_top - 48
    b.append(f'<rect x="0" y="{acc}" width="{cw}" height="48" fill="{t["field"]}"/>')
    b.append(T(20, acc + 30, "次へ", 17, t["accent"], 400, bg=t["field"]))
    b.append(T(cw - 20, acc + 30, "キーボードを閉じる", 17, t["accent"], 600, "end", bg=t["field"]))
    b.append(f'<rect x="0" y="{kb_top}" width="{cw}" height="{h-kb_top}" fill="{t["kb"]}"/>')
    b.append(T(cw / 2, kb_top + 120, "（システムのキーボード・数字）", 15, t["label"], 400, "middle", bg=t["kb"]))
    return svg(w, h, s, "".join(b))


def outer_paywall(theme):
    """S-13 Pro sheet, opened when saving the 11th recipient. One-time purchase, local price,
    restore, terms and privacy."""
    t = THEMES[theme]
    w, h = OUTER
    cw = w - SIDE
    s = t["sheet"]
    f = t["field"]
    b = [f'<rect x="0" y="0" width="{w}" height="{h}" fill="{s}"/>',
         side_column(w, h, t, tools=[("xmark", None)], tabs=False)]
    b.append(T(20, 60, "無料版は10件までです", 28, t["label"], 700, bg=s))
    b.append(T(20, 92, "登録済みの宛先はそのまま使えます。", 15, t["label"], 400, bg=s))
    b.append(f'<rect x="16" y="112" width="{cw-32}" height="188" rx="22" fill="{f}"/>')
    b.append(T(34, 146, "宛名印刷 Pro（買い切り）", 20, t["label"], 700, bg=f))
    b.append(T(34, 172, "定期的な支払いはありません", 15, t["sec"], 400, bg=f))
    for i, line in enumerate(("宛先を無制限に登録", "CSVの取り込み件数も無制限", "PDFで書き出し")):
        y = 206 + i * 30
        b.append(sym("checkmark", 42, y - 6, t["accent"], 2).replace("l5 6 11-13", "l4 5 9-11"))
        b.append(T(60, y, line, 17, t["label"], 400, bg=f))
    b.append(_btn(16, 322, cw - 32, "¥800 で購入", True, None, t))
    b.append(T(cw / 2, 410, "購入を復元", 17, t["accent"], 400, "middle", bg=s))
    b.append(T(cw / 2, 454, "利用規約", 17, t["accent"], 400, "middle", bg=s))
    b.append(T(cw / 2, 498, "プライバシーポリシー", 17, t["accent"], 400, "middle", bg=s))
    b.append(T(cw / 2, 540, "価格は App Store の表示に従います", 13, t["sec"], 400, "middle", bg=s))
    return svg(w, h, s, "".join(b))


# ---------------------------------------------------------------- inner display

def pane_split(w, folded):
    """List pane width / detail start. Fully open: list narrower. Folded: equal halves about the fold."""
    if folded:
        return w / 2 - FOLD - 16 - 8, w / 2 + FOLD
    return 330, 16 + 330 + 16


def inner_l_recipients(theme, folded=False):
    t = THEMES[theme]
    w, h = INNER_L
    lw, dx = pane_split(w, folded)
    dw = w - SIDE - dx - 8
    b = [side_column(w, h, t, tools=[("pencil", t["accent"]), ("ellipsis", None)], camera=False)]
    # List pane (its controls sit at the top of the pane).
    b.append(f'<rect x="8" y="8" width="{lw+16:g}" height="{h-16}" rx="28" fill="{t["cell"]}"/>')
    b.append(sym("sidebar.left", 34, 36, t["label"]) + sym("ellipsis", lw - 8, 36, t["label"]))
    b.append(T(24, 96, "年賀状2026", 28, t["label"], 700, bg=t["cell"]))
    b.append(T(24, 122, "5件・未印刷 3件", 15, t["sec"], 400, bg=t["cell"]))
    b.append(T(lw + 8, 122, "無料版：あと5件", 15, t["sec"], 400, "end", bg=t["cell"]))
    b.append(f'<rect x="20" y="134" width="{lw-8:g}" height="36" rx="18" fill="{t["seg"]}"/>'
             + sym("magnifyingglass", 40, 152, t["sec"], 2) + T(56, 158, "氏名・住所で検索", 17, t["sec"], 400, bg=t["seg"]))
    b.append(segmented(20, 180, lw - 8, t, size=13 if folded else 15))
    b.append(rows(16, 224, lw, t, n=5, sel=4, trunc=14 if folded else 15, fold_ok=True)
             .replace(f'fill="{t["cell"]}"/>', f'fill="{t["cell"]}" fill-opacity="0"/>', 1))
    b.append(bottom_bar(8, lw + 24, h, t, [("追加", False, "plus"), ("一括印刷", True, "printer")])
             .replace(f'fill="{t["bg"]}" fill-opacity="0.92"', f'fill="{t["cell"]}" fill-opacity="0.96"'))
    # Detail pane.
    b.append(T(dx + 8, 62, "山田 太郎 様", 28, t["label"], 700))
    b.append(T(dx + 8, 84, "連名：花子 様", 15, t["sec"]))
    pw = min(210, dw - 40)
    b.append(paper(dx + dw / 2 - pw / 2, 96, pw, t))
    cy0 = 96 + pw * 1.48 + 14
    b.append(f'<rect x="{dx+8}" y="{cy0:g}" width="{dw-16:g}" height="96" rx="20" fill="{t["cell"]}"/>')
    b.append(T(dx + 26, cy0 + 30, "〒104-0061", 17, t["label"], 400, bg=t["cell"]))
    b.append(T(dx + 26, cy0 + 56, "東京都中央区見本町1-13-3", 17, t["label"], 400, bg=t["cell"]))
    b.append(T(dx + 26, cy0 + 80, "サンプルハイツ203", 15, t["sec"], 400, bg=t["cell"]))
    b.append(bottom_bar(dx, w - SIDE, h, t, [("この宛先を印刷", True, "printer")], regular=True))
    return svg(w, h, t["bg"], "".join(b))


def inner_l_preview(theme, folded=False):
    t = THEMES[theme]
    w, h = INNER_L
    split = w / 2 - FOLD if folded else 560
    px = (w / 2 + FOLD) if folded else 560
    b = [f'<rect x="0" y="0" width="{split:g}" height="{h}" fill="{t["preview"]}"/>',
         side_column(w, h, t, tools=[("xmark", None)], tabs=False, camera=False)]
    b.append(T(split / 2, 36, "印刷プレビュー", 17, t["label"], 600, "middle", bg=t["preview"]))
    b.append(T(split / 2, 56, "はがき・縦書き", 13, t["sec"], 400, "middle", bg=t["preview"]))
    pw = min(380, (h - 100) / 1.48, split - 40)
    b.append(paper(split / 2 - pw / 2, 74, pw, t, **AOKI))
    x0 = px + 20
    x1 = w - SIDE - 16
    pane = t["bg"]
    b.append(glass_btn(x0 + 22, 62, t) + sym("chevron.backward", x0 + 22, 62, t["sec"]))
    b.append(T(x0 + 80, 69, "1 / 5", 17, t["label"], 600, "middle"))
    b.append(glass_btn(x0 + 138, 62, t) + sym("chevron.forward", x0 + 138, 62, t["accent"]))
    b.append(T(x0, 130, "青木 健 様", 22, t["label"], 700))
    b.append(T(x0, 156, "〒150-0001 東京都渋谷区見本町2-3-1", 13 if folded else 15, t["sec"]))
    b.append(f'<rect x="{x0}" y="174" width="{x1-x0:g}" height="60" rx="14" fill="{t["warn_fill"]}"/>')
    b.append(T(x0 + 14, 200, WARNING[:11], 15, t["warn"], 600, bg=t["warn_fill"]))
    b.append(T(x0 + 14, 222, WARNING[11:], 15, t["warn"], 600, bg=t["warn_fill"]))
    b.append(T(x0, 268, "用紙", 13, t["sec"], 600))
    b.append(T(x0, 292, "はがき（100×148mm）", 17, t["label"]))
    b.append(_btn(x0, 320, x1 - x0, "5件を印刷", True, "printer", t))
    b.append(_btn(x0, 384, x1 - x0, "PDFで書き出す（Pro）", False, "square.and.arrow.up", t))
    return svg(w, h, pane, "".join(b))


def inner_p_recipients(theme):
    """Inner display, portrait: standard horizontal bars (the portrait exception). Regular width →
    tab bar as a floating capsule at the top centre (text only). List and detail side by side;
    the fold runs across y = 475.5 and only the scrolling list may cross it."""
    t = THEMES[theme]
    w, h = INNER_P
    b = [T(32, 34, "9:41", 15, t["label"], 600)]
    b.append(f'<rect x="{w-58}" y="22" width="26" height="13" rx="4" fill="none" stroke="{t["label"]}" stroke-opacity="0.4"/>'
             f'<rect x="{w-56}" y="24" width="20" height="9" rx="2" fill="{t["label"]}"/>')
    tw = 260
    tx = w / 2 - tw / 2
    b.append(f'<rect x="{tx}" y="52" width="{tw}" height="44" rx="22" fill="{t["glass"]}" fill-opacity="{t["glass_op"]}" stroke="{t["glass_stroke"]}"/>')
    on_bg = mix(t["accent"], t["glass"], 0.14)
    b.append(f'<rect x="{tx+4}" y="56" width="80" height="36" rx="18" fill="{on_bg}"/>')
    for i, lab in enumerate(("宛先", "レイアウト", "設定")):
        cx = tx + 44 + i * 86
        b.append(T(cx, 80, lab, 15, t["accent"] if i == 0 else t["label"], 600 if i == 0 else 400, "middle",
                   bg=on_bg if i == 0 else t["glass"]))
    lw = 320
    b.append(glass_btn(38, 132, t) + sym("sidebar.left", 38, 132, t["label"]))
    b.append(glass_btn(w - 38, 132, t) + sym("ellipsis", w - 38, 132, t["label"]))
    b.append(glass_btn(w - 92, 132, t) + sym("pencil", w - 92, 132, t["accent"]))
    b.append(T(20, 196, "年賀状2026", 28, t["label"], 700))
    b.append(T(20, 222, "5件・未印刷 3件", 15, t["sec"]))
    b.append(T(lw + 16, 222, "無料版：あと5件", 15, t["sec"], 400, "end"))
    b.append(f'<rect x="16" y="234" width="{lw}" height="36" rx="18" fill="{t["seg"]}"/>'
             + sym("magnifyingglass", 36, 252, t["sec"], 2) + T(52, 258, "氏名・住所で検索", 17, t["sec"], 400, bg=t["seg"]))
    b.append(segmented(16, 280, lw, t))
    b.append(rows(16, 326, lw, t, n=5, sel=4, trunc=15, fold_ok=True))
    dx = lw + 32
    b.append(T(dx, 196, "山田 太郎 様", 28, t["label"], 700))
    b.append(T(dx, 222, "連名：花子 様", 15, t["sec"]))
    pw = 150
    assert 238 + pw * 1.48 < h / 2 - FOLD  # postcard stays above the fold band
    b.append(paper(dx + (w - dx - 16) / 2 - pw / 2, 238, pw, t))
    b.append(bottom_bar(0, lw + 32, h, t, [("追加", False, "plus"), ("一括印刷", True, "printer")]))
    b.append(bottom_bar(lw + 32, w, h, t, [("この宛先を印刷", True, "printer")], regular=True))
    return svg(w, h, t["bg"], "".join(b))


files = {}
for th in ("light", "dark"):
    files[f"iphone-duo-outer-S-02-{th}.svg"] = outer_list(th)
    files[f"iphone-duo-outer-S-02-empty-{th}.svg"] = outer_empty(th)
    files[f"iphone-duo-outer-S-02-ax5-{th}.svg"] = outer_ax5(th)
    files[f"iphone-duo-outer-S-03-{th}.svg"] = outer_detail(th)
    files[f"iphone-duo-outer-S-04-keyboard-{th}.svg"] = outer_editor(th)
    files[f"iphone-duo-outer-S-07-{th}.svg"] = outer_preview(th)
    files[f"iphone-duo-outer-S-13-{th}.svg"] = outer_paywall(th)
    files[f"iphone-duo-inner-landscape-S-03-{th}.svg"] = inner_l_recipients(th)
    files[f"iphone-duo-inner-landscape-S-03-folded-{th}.svg"] = inner_l_recipients(th, True)
    files[f"iphone-duo-inner-landscape-S-07-{th}.svg"] = inner_l_preview(th)
    files[f"iphone-duo-inner-landscape-S-07-folded-{th}.svg"] = inner_l_preview(th, True)
    files[f"iphone-duo-inner-S-03-{th}.svg"] = inner_p_recipients(th)
for name, content in files.items():
    (OUT / name).write_text(content, encoding="utf-8")
print(f"wrote {len(files)} SVGs to {OUT}")
