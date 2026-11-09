#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成三张同布局风格样板：纸雕绘本 / Q版国风 / 手绘水彩。"""
from pathlib import Path
import json
import math

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance

ROOT = Path(__file__).resolve().parent.parent
CLIENT = ROOT / "client"
DATA = CLIENT / "data"
OUT = ROOT / "art_samples"
OUT.mkdir(exist_ok=True)

W, H = 1400, 1000
MAP = (30, 105, 1030, 655)
PANEL = (1080, 105, 290, 655)

FONT_SERIF = str(CLIENT / "fonts" / "NotoSerifCJKsc-Regular.otf")
FONT_SANS = r"C:\Windows\Fonts\msyh.ttc"
FONT_SANS_BOLD = r"C:\Windows\Fonts\msyhbd.ttc"

PAPER = (250, 242, 224)
INK = (58, 46, 36)
CORAL = (198, 78, 68)
BAMBOO = (76, 140, 102)
MUSTARD = (214, 158, 58)
BLUE = (54, 94, 140)
SKY = (170, 214, 232)
CREAM = (255, 248, 232)
GOLD = (196, 138, 52)


def load_json(path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()


def text(d, xy, s, f, fill, anchor="la", stroke=0, stroke_fill=None):
    d.text(xy, s, font=f, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=stroke_fill)


def shadow_rect(base, box, radius=18, offset=(6, 8), alpha=60):
    ov = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    x0, y0, x1, y1 = box
    d.rounded_rectangle([x0 + offset[0], y0 + offset[1], x1 + offset[0], y1 + offset[1]], radius=radius, fill=(0, 0, 0, alpha))
    base.alpha_composite(ov)


def card(base, box, radius, fill, outline, width=3, shadow=True):
    if shadow:
        shadow_rect(base, box, radius, (5, 7), 55)
    ov = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    d.rounded_rectangle(box, radius=radius, fill=fill + (255,), outline=outline + (255,), width=width)
    base.alpha_composite(ov)


def load_map(style):
    m = Image.open(DATA / "map_base.png").convert("RGB").resize((MAP[2] - MAP[0], MAP[3] - MAP[1]), Image.LANCZOS)
    if style == "paper":
        m = ImageEnhance.Color(m).enhance(1.08)
        m = ImageEnhance.Contrast(m).enhance(1.04)
    elif style == "chibi":
        m = ImageEnhance.Color(m).enhance(1.22)
        m = ImageEnhance.Brightness(m).enhance(1.05)
    elif style == "water":
        m = m.filter(ImageFilter.GaussianBlur(0.7))
        m = ImageEnhance.Color(m).enhance(0.92)
        m = ImageEnhance.Contrast(m).enhance(0.92)
    return m


def background(style):
    base = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(base)
    if style == "paper":
        d.rectangle([0, 0, W, H], fill=(47, 39, 33, 255))
        for y in range(0, H, 14):
            d.line([(0, y), (W, y)], fill=(54, 45, 38, 255), width=1)
    elif style == "chibi":
        d.rectangle([0, 0, W, H], fill=SKY + (255,))
        for i in range(8):
            x = 80 + i * 190
            y = 40 + (i % 3) * 35
            d.ellipse([x, y, x + 110, y + 42], fill=(255, 255, 255, 150))
            d.ellipse([x + 40, y - 16, x + 130, y + 32], fill=(255, 255, 255, 170))
    else:
        d.rectangle([0, 0, W, H], fill=(238, 229, 214, 255))
        for i in range(5):
            d.ellipse([-120 + i * 260, 700 + i * 20, 380 + i * 260, 1080 + i * 20], fill=(214, 228, 222, 70))
    return base


def draw_map(base, style, meta, provinces):
    m = load_map(style)
    shadow_rect(base, [MAP[0] - 8, MAP[1] - 8, MAP[2] + 8, MAP[3] + 8], 18, (8, 10), 85)
    mask = Image.new("L", m.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, m.size[0], m.size[1]], radius=8, fill=255)
    base.paste(m, (MAP[0], MAP[1]), mask)
    d = ImageDraw.Draw(base)
    d.rounded_rectangle([MAP[0] - 6, MAP[1] - 6, MAP[2] + 6, MAP[3] + 6], radius=14, outline=INK + (255,), width=6 if style == "paper" else 4)
    d.rounded_rectangle([MAP[0] - 12, MAP[1] - 12, MAP[2] + 12, MAP[3] + 12], radius=18, outline=GOLD + (255,), width=2)

    # 城池木牌
    for p in provinces:
        code = p["code"]
        if code not in meta["cities"]:
            continue
        nx, ny = meta["cities"][code]
        x = MAP[0] + nx * (MAP[2] - MAP[0])
        y = MAP[1] + ny * (MAP[3] - MAP[1])
        dx = p.get("label_dx", 0) * 1.17
        dy = p.get("label_dy", 0) * 1.17
        tx, ty = x + dx, y + dy
        label = p["name"] + (" ★" if p.get("capital") else "")
        f = font(FONT_SANS_BOLD, 17)
        tw = f.getbbox(label)[2] - f.getbbox(label)[0]
        box = [tx - tw / 2 - 10, ty - 16, tx + tw / 2 + 10, ty + 16]
        if style == "paper":
            card(base, box, 7, CREAM, CORAL if p.get("owner") == "bi" else INK, 3)
        elif style == "chibi":
            card(base, box, 12, (255, 255, 255), CORAL, 3)
        else:
            card(base, box, 8, (255, 250, 240), (150, 130, 100), 1)
        d = ImageDraw.Draw(base)
        text(d, (tx, ty), label, f, INK, "mm")
        # 小印点
        dot = CORAL if p.get("owner") == "bi" else BAMBOO if p.get("owner") == "yan" else MUSTARD if p.get("owner") == "zhi" else BLUE
        d.ellipse([box[0] + 6, ty - 4, box[0] + 14, ty + 4], fill=dot)


def draw_topbar(base, style):
    d = ImageDraw.Draw(base)
    if style == "paper":
        d.rectangle([0, 0, W, 84], fill=(52, 43, 36, 255))
        d.rectangle([0, 80, W, 84], fill=GOLD)
        f_title = font(FONT_SERIF, 34)
        text(d, (92, 16), "青竹文房·灵宠山河", f_title, CREAM)
        text(d, (94, 54), "S1 九州争霸 · 第 1 周 · 语文文脉地图", font(FONT_SANS, 15), (220, 205, 180))
        d.rectangle([28, 18, 72, 62], fill=CORAL)
        text(d, (50, 40), "青", font(FONT_SERIF, 26), CREAM, "mm")
    elif style == "chibi":
        d.rectangle([0, 0, W, 84], fill=(255, 248, 232, 255))
        d.rectangle([0, 80, W, 84], fill=(240, 170, 90))
        for i in range(7):
            d.ellipse([200 + i * 160, 12, 280 + i * 160, 40], fill=(220, 240, 250, 255))
        f_title = font(FONT_SANS_BOLD, 34)
        text(d, (92, 14), "青竹文房·灵宠山河", f_title, (60, 90, 130))
        text(d, (94, 54), "S1 九州争霸 · 第 1 周 · 语文文脉地图", font(FONT_SANS, 15), (110, 120, 130))
        d.rounded_rectangle([26, 16, 74, 64], radius=14, fill=CORAL)
        text(d, (50, 40), "青", font(FONT_SANS_BOLD, 26), CREAM, "mm")
    else:
        d.rectangle([0, 0, W, 84], fill=(246, 238, 224, 255))
        d.line([(0, 82), (W, 82)], fill=(160, 135, 100), width=2)
        f_title = font(FONT_SERIF, 34)
        text(d, (92, 16), "青竹文房·灵宠山河", f_title, (85, 68, 52))
        text(d, (94, 54), "S1 九州争霸 · 第 1 周 · 语文文脉地图", font(FONT_SANS, 15), (130, 112, 92))
        d.ellipse([28, 18, 72, 62], fill=(190, 110, 95))
        text(d, (50, 40), "青", font(FONT_SERIF, 26), CREAM, "mm")

    text(d, (900, 26), "笔阵营｜粮 500　木 500　铁 500｜军令 3/3", font(FONT_SANS, 15), INK if style != "paper" else CREAM)


def draw_panel(base, style):
    d = ImageDraw.Draw(base)
    if style == "paper":
        card(base, [PANEL[0], PANEL[1], PANEL[0] + PANEL[2], PANEL[1] + PANEL[3]], 14, CREAM, (120, 92, 64), 4)
    elif style == "chibi":
        card(base, [PANEL[0], PANEL[1], PANEL[0] + PANEL[2], PANEL[1] + PANEL[3]], 22, (255, 255, 255), (240, 170, 90), 4)
    else:
        card(base, [PANEL[0], PANEL[1], PANEL[0] + PANEL[2], PANEL[1] + PANEL[3]], 12, (255, 250, 240), (170, 145, 110), 1)
    d = ImageDraw.Draw(base)
    x = PANEL[0] + 20
    y = PANEL[1] + 18
    text(d, (x, y), "省份信息", font(FONT_SANS_BOLD if style == "chibi" else FONT_SERIF, 22), (70, 55, 42))
    text(d, (x, y + 38), "长安 · 笔", font(FONT_SANS_BOLD if style == "chibi" else FONT_SERIF, 28), CORAL)
    body = ["地形：平原", "资源：粮", "胜利点：3", "首都：是", "城墙：Lv.2", "守军：0", "相邻：洛阳、汉中、太原"]
    for i, line in enumerate(body):
        text(d, (x, y + 86 + i * 27), line, font(FONT_SANS, 15), (70, 60, 50))
    d.line([(x, y + 292), (PANEL[0] + PANEL[2] - 20, y + 292)], fill=(170, 145, 110), width=1)
    text(d, (x, y + 308), "今日军令（3 道）", font(FONT_SANS_BOLD if style == "chibi" else FONT_SERIF, 19), (70, 55, 42))
    orders = ["征兵", "进军", "驻守"]
    for i, o in enumerate(orders):
        yy = y + 350 + i * 56
        d.rounded_rectangle([x, yy, x + 108, yy + 38], radius=8, fill=(255, 248, 232), outline=(180, 150, 110), width=2)
        text(d, (x + 54, yy + 19), o, font(FONT_SANS, 16), INK, "mm")
        text(d, (x + 120, yy + 19), "目标：长安", font(FONT_SANS, 14), (100, 88, 72), "lm")
    by = y + 530
    if style == "paper":
        card(base, [x, by, PANEL[0] + PANEL[2] - 20, by + 48], 8, CORAL, (110, 42, 36), 3, False)
    elif style == "chibi":
        card(base, [x, by, PANEL[0] + PANEL[2] - 20, by + 48], 16, (244, 120, 100), (200, 80, 70), 3, False)
    else:
        card(base, [x, by, PANEL[0] + PANEL[2] - 20, by + 48], 8, (200, 120, 105), (150, 90, 80), 1, False)
    d = ImageDraw.Draw(base)
    text(d, ((x + PANEL[0] + PANEL[2] - 20) / 2, by + 24), "提交军令", font(FONT_SANS_BOLD, 20), CREAM, "mm")
    text(d, (x, by + 64), "点击地图上的城池查看文脉小知识。", font(FONT_SANS, 13), (120, 105, 88))


def draw_mascots(base, style):
    d = ImageDraw.Draw(base)
    # 小青竹
    bx, by = 890, 720
    body = BAMBOO if style != "chibi" else (96, 180, 120)
    d.rounded_rectangle([bx, by, bx + 62, by + 92], radius=24, fill=body, outline=INK, width=4)
    d.ellipse([bx + 14, by + 34, bx + 26, by + 46], fill=INK)
    d.ellipse([bx + 38, by + 34, bx + 50, by + 46], fill=INK)
    d.arc([bx + 20, by + 48, bx + 44, by + 68], 10, 170, fill=INK, width=2)
    d.polygon([(bx + 20, by), (bx + 32, by - 22), (bx + 44, by)], fill=(96, 180, 120))
    text(d, (bx + 31, by + 108), "小青竹", font(FONT_SANS_BOLD, 13), INK, "mm")
    # 墨点精
    ix, iy = 980, 728
    d.ellipse([ix, iy, ix + 54, iy + 68], fill=(60, 72, 96), outline=INK, width=4)
    d.polygon([(ix + 27, iy - 22), (ix + 6, iy + 18), (ix + 48, iy + 18)], fill=(60, 72, 96), outline=INK)
    d.ellipse([ix + 14, iy + 28, ix + 24, iy + 38], fill=CREAM)
    d.ellipse([ix + 31, iy + 28, ix + 41, iy + 38], fill=CREAM)
    d.arc([ix + 18, iy + 40, ix + 38, iy + 56], 10, 170, fill=CREAM, width=2)
    text(d, (ix + 27, iy + 80), "墨点精", font(FONT_SANS_BOLD, 13), INK, "mm")
    # 对话气泡
    if style == "chibi":
        card(base, [810, 690, 1000, 736], 18, (255, 255, 255), (240, 170, 90), 3, True)
        d = ImageDraw.Draw(base)
        text(d, (905, 713), "今天打哪？", font(FONT_SANS_BOLD, 15), INK, "mm")


def draw_legend(base, style):
    d = ImageDraw.Draw(base)
    items = [("笔", CORAL), ("墨", BLUE), ("纸", MUSTARD), ("砚", BAMBOO)]
    x = 32
    y = 790
    for name, col in items:
        d.ellipse([x, y, x + 18, y + 18], fill=col, outline=INK, width=2)
        text(d, (x + 26, y - 1), name, font(FONT_SANS, 15), CREAM if style == "paper" else INK)
        x += 62
    text(d, (32, 826), "语文文脉：诗 · 词 · 文 · 字 · 典", font(FONT_SANS, 14), (220, 205, 180) if style == "paper" else (110, 95, 78))


def render(style, name):
    base = background(style)
    meta = load_json(DATA / "map_meta.json")
    provinces = load_json(DATA / "provinces.json")["provinces"]
    draw_map(base, style, meta, provinces)
    draw_topbar(base, style)
    draw_panel(base, style)
    draw_mascots(base, style)
    draw_legend(base, style)
    # 纸纹/暗角
    # 简单暗角
    ov = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for i in range(60):
        a = int(40 * (1 - i / 60))
        d.rectangle([i, i, W - i, H - i], outline=(0, 0, 0, a), width=1)
    base.alpha_composite(ov)
    base.convert("RGB").save(OUT / name, quality=94)
    print("saved", OUT / name)


if __name__ == "__main__":
    render("paper", "sample_A_papercut.png")
    render("chibi", "sample_B_chibi.png")
    render("water", "sample_C_watercolor.png")
