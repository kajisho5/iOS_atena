#!/usr/bin/env python3
"""Builds App Store style device mockups from simulator screenshots.

Input: a directory with screen-*.png produced by ScreenSnapshotTests (CI artifact "snapshots").
Output: HTML pages in a work directory, rendered to PNG by render.js (Playwright/Chromium).
Usage: python3 tools/mockups/build.py <snapshots-dir> <out-dir>
"""
import base64
import pathlib
import struct
import sys

FONT = "'Hiragino Sans','Hiragino Kaku Gothic ProN','Noto Sans CJK JP',sans-serif"
BG = "linear-gradient(160deg,#2F66B8 0%,#173E73 100%)"


def png_size(path: pathlib.Path) -> tuple[int, int]:
    """Width and height from the PNG IHDR chunk."""
    with path.open("rb") as f:
        header = f.read(24)
    return struct.unpack(">II", header[16:24])


def data_uri(path: pathlib.Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


STATUS_ICONS = """<svg width="78" height="14" viewBox="0 0 78 14"><g fill="{c}">
<rect x="0" y="9" width="3.2" height="4.5" rx="0.8"/><rect x="5" y="6.5" width="3.2" height="7" rx="0.8"/>
<rect x="10" y="4" width="3.2" height="9.5" rx="0.8"/><rect x="15" y="1.5" width="3.2" height="12" rx="0.8"/></g>
<g fill="none" stroke="{c}" stroke-width="1.7" stroke-linecap="round"><path d="M25 5.5 Q32 -0.5 39 5.5"/><path d="M28 8.5 Q32 5 36 8.5"/></g>
<circle cx="32" cy="11.5" r="1.4" fill="{c}"/>
<rect x="46" y="1.5" width="24" height="11.5" rx="3.6" fill="none" stroke="{c}" stroke-opacity="0.45" stroke-width="1"/>
<rect x="48" y="3.5" width="20" height="7.5" rx="2" fill="{c}"/><rect x="71" y="5.3" width="1.6" height="4" rx="0.8" fill="{c}" fill-opacity="0.45"/></svg>"""


def iphone(screen: pathlib.Path, width: int, dark=False, tilt=0) -> str:
    """iPhone frame; `width` is the outer width in CSS px."""
    c = "#FFFFFF" if dark else "#000000"
    bezel = width * 0.035
    radius = width * 0.16
    inner_w = width - bezel * 2
    inner_h = inner_w * 2.1667
    scale = inner_w / 393
    return f"""
<div style="position:relative;width:{width}px;height:{inner_h + bezel * 2}px;transform:rotate({tilt}deg);
  border-radius:{radius}px;background:#1C1C1E;box-shadow:0 40px 80px rgba(0,0,0,.35),inset 0 0 0 {width*0.006}px #4A4A4E;">
  <div style="position:absolute;left:{bezel}px;top:{bezel}px;width:{inner_w}px;height:{inner_h}px;border-radius:{radius - bezel}px;overflow:hidden;background:#fff">
    <img src="{data_uri(screen)}" style="width:100%;height:100%;object-fit:cover;object-position:top;display:block">
    <div style="position:absolute;left:0;top:0;width:100%;height:{54*scale}px;display:flex;align-items:center;justify-content:space-between;padding:0 {28*scale}px 0 {44*scale}px;box-sizing:border-box">
      <span style="font:600 {17*scale}px -apple-system,'SF Pro Text',{FONT};color:{c};padding-top:{6*scale}px">9:41</span>
      <span style="transform:scale({scale});transform-origin:right center;padding-top:{6*scale}px">{STATUS_ICONS.format(c=c)}</span>
    </div>
    <div style="position:absolute;left:50%;top:{11*scale}px;width:{126*scale}px;height:{37*scale}px;margin-left:{-63*scale}px;border-radius:{19*scale}px;background:#000"></div>
  </div>
</div>"""


def ipad(screen: pathlib.Path, width: int) -> str:
    bezel = width * 0.022
    inner_w = width - bezel * 2
    image_w, image_h = png_size(screen)
    inner_h = inner_w * image_h / image_w
    return f"""
<div style="position:relative;width:{width}px;height:{inner_h + bezel*2}px;border-radius:{width*0.035}px;background:#1C1C1E;
  box-shadow:0 40px 90px rgba(0,0,0,.35),inset 0 0 0 {width*0.004}px #4A4A4E">
  <div style="position:absolute;left:{bezel}px;top:{bezel}px;width:{inner_w}px;height:{inner_h}px;border-radius:{width*0.016}px;overflow:hidden;background:#fff">
    <img src="{data_uri(screen)}" style="width:100%;height:100%;object-fit:cover;display:block">
  </div>
</div>"""


def mac_window(screen: pathlib.Path, width: int) -> str:
    bar = width * 0.028
    image_w, image_h = png_size(screen)
    inner_h = width * image_h / image_w
    return f"""
<div style="width:{width}px;border-radius:{width*0.012}px;overflow:hidden;background:#F2F2F7;box-shadow:0 50px 100px rgba(0,0,0,.45),0 0 0 1px rgba(0,0,0,.25)">
  <div style="height:{bar}px;background:#E8E8ED;display:flex;align-items:center;gap:{bar*0.3}px;padding-left:{bar*0.5}px;border-bottom:1px solid #D1D1D6">
    <span style="width:{bar*0.42}px;height:{bar*0.42}px;border-radius:50%;background:#FF5F57"></span>
    <span style="width:{bar*0.42}px;height:{bar*0.42}px;border-radius:50%;background:#FEBC2E"></span>
    <span style="width:{bar*0.42}px;height:{bar*0.42}px;border-radius:50%;background:#28C840"></span>
    <span style="flex:1;text-align:center;font:600 {bar*0.42}px {FONT};color:#3C3C43;margin-right:{bar*2}px">宛名印刷</span>
  </div>
  <img src="{data_uri(screen)}" style="width:{width}px;height:{inner_h}px;object-fit:cover;display:block">
</div>"""


def page(width: int, height: int, body: str, title: str, subtitle: str, title_size: int) -> str:
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
html,body{{margin:0;width:{width}px;height:{height}px;overflow:hidden}}
body{{background:{BG};font-family:{FONT};color:#fff;display:flex;flex-direction:column;align-items:center}}
h1{{margin:0;font-size:{title_size}px;font-weight:800;letter-spacing:.02em;text-align:center}}
p{{margin:{title_size*0.3}px 0 0;font-size:{title_size*0.55}px;font-weight:500;opacity:.9;text-align:center}}
</style></head><body>
<div style="padding:{height*0.05}px {width*0.06}px 0">
<h1>{title}</h1><p>{subtitle}</p></div>
<div style="flex:1;display:flex;align-items:center;justify-content:center;gap:{width*0.04}px;width:100%">{body}</div>
</body></html>"""


def main() -> None:
    src = pathlib.Path(sys.argv[1])
    out = pathlib.Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    pages = {}
    # App Store iPhone 6.9" (1290 x 2796).
    iphone_shots = [
        ("iphone-1", "screen-iphone-list.png", "年賀状の宛名を、まとめて印刷", "グループごとに未印刷だけを一括印刷"),
        ("iphone-2", "screen-iphone-preview.png", "郵便番号枠にぴったり縦書き", "連名・敬称もきれいにそろえて配置"),
        ("iphone-3", "screen-iphone-csv.png", "住所録はCSVで一括取り込み", "Excel の CSV（Shift_JIS）にも対応"),
        ("iphone-4", "screen-iphone-layout.png", "縦書きも横書きも、フォントも", "住所が長くても自動で改行・縮小"),
    ]
    for name, file, title, subtitle in iphone_shots:
        if (src / file).exists():
            pages[name] = (1290, 2796, page(1290, 2796, iphone(src / file, 980), title, subtitle, 76))
    # iPad 13" landscape (2752 x 2064).
    if (src / "screen-ipad-landscape-preview.png").exists():
        pages["ipad-1"] = (2752, 2064, page(2752, 2064, ipad(src / "screen-ipad-landscape-preview.png", 2100),
                                            "iPad の大きな画面で、用紙全体を確認", "横向き・画面分割にも対応", 100))
    if (src / "screen-ipad-landscape-recipients.png").exists():
        pages["ipad-2"] = (2752, 2064, page(2752, 2064, ipad(src / "screen-ipad-landscape-recipients.png", 2100),
                                            "宛先・グループ・プレビューを一画面で", "印刷済みの記録で出し忘れを防止", 100))
        # Mac (Designed for iPad) window on a desktop, 2880 x 1800.
        pages["mac-1"] = (2880, 1800, page(2880, 1800, mac_window(src / "screen-ipad-landscape-recipients.png", 1700),
                                           "Mac でもそのまま使える", "Designed for iPad で動作（Apple シリコン搭載 Mac）", 84))
    # iPhone Duo: two phones side by side (2560 x 1600).
    if (src / "screen-iphone-list.png").exists() and (src / "screen-iphone-preview.png").exists():
        duo = iphone(src / "screen-iphone-list.png", 560, tilt=-4) + iphone(src / "screen-iphone-preview.png", 560, tilt=4)
        pages["iphone-duo"] = (2560, 1600, page(2560, 1600, duo, "宛名印刷 はがき・封筒", "広告なし・買い切り・CSV一括取り込み", 76))
    if (src / "screen-iphone-list-dark.png").exists() and (src / "screen-iphone-preview-dark.png").exists():
        duo = iphone(src / "screen-iphone-list-dark.png", 560, dark=True, tilt=-4) + iphone(src / "screen-iphone-preview-dark.png", 560, dark=True, tilt=4)
        pages["iphone-duo-dark"] = (2560, 1600, page(2560, 1600, duo, "ダークモードにも対応", "宛名面の紙色はそのままで見やすく", 76))
    for name, (w, h, html) in pages.items():
        (out / f"{name}.html").write_text(html, encoding="utf-8")
        (out / f"{name}.size").write_text(f"{w}x{h}")
    print("\n".join(sorted(pages)))


if __name__ == "__main__":
    main()
