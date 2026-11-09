#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 UI 9-patch 纹理：顶栏、纸面板、鎏金按钮。"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "client" / "data"

GOLD = (207, 131, 37)
GOLD_DARK = (143, 92, 24)
PAPER = (255, 250, 240)
INK = (30, 58, 95)
RED = (168, 52, 45)
RED_LIGHT = (207, 72, 62)


def grain(img, amount=2.0, seed=7):
    arr = np.asarray(img).astype(np.float32)
    rng = np.random.default_rng(seed)
    noise = rng.normal(0, amount, (arr.shape[0], arr.shape[1], 1))
    arr[:, :, :3] = np.clip(arr[:, :, :3] + noise, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGB")


def panel():
    size = 128
    img = Image.new("RGB", (size, size), PAPER)
    d = ImageDraw.Draw(img)
    # 双层金边
    d.rectangle([2, 2, size - 3, size - 3], outline=GOLD, width=3)
    d.rectangle([9, 9, size - 10, size - 10], outline=(185, 169, 142), width=1)
    # 四角小回纹
    for x, y, sx, sy in [(4, 4, 1, 1), (size - 5, 4, -1, 1), (4, size - 5, 1, -1), (size - 5, size - 5, -1, -1)]:
        d.line([(x, y), (x + 14 * sx, y)], fill=GOLD, width=2)
        d.line([(x, y), (x, y + 14 * sy)], fill=GOLD, width=2)
        d.line([(x + 4 * sx, y + 4 * sy), (x + 9 * sx, y + 4 * sy)], fill=GOLD_DARK, width=1)
    img = grain(img, 1.8, 11)
    img.save(DATA / "ui_panel.png", optimize=True)


def button():
    w, h = 96, 48
    img = Image.new("RGB", (w, h), RED)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 1, w - 2, h - 2], radius=8, fill=RED, outline=GOLD, width=2)
    d.rounded_rectangle([5, 4, w - 6, 18], radius=6, fill=RED_LIGHT)
    d.line([(8, h - 8), (w - 9, h - 8)], fill=(120, 32, 28), width=1)
    img = grain(img, 1.5, 13)
    img.save(DATA / "ui_button.png", optimize=True)


def topbar():
    w, h = 256, 80
    arr = np.zeros((h, w, 3), dtype=np.float32)
    top = np.array(INK, dtype=np.float32)
    bottom = np.array((16, 30, 52), dtype=np.float32)
    for y in range(h):
        t = y / (h - 1)
        arr[y, :, :] = top * (1 - t) + bottom * t
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    d.line([(0, h - 3), (w, h - 3)], fill=GOLD, width=3)
    d.line([(0, h - 7), (w, h - 7)], fill=GOLD_DARK, width=1)
    img = grain(img, 1.2, 17)
    img.save(DATA / "ui_topbar.png", optimize=True)


if __name__ == "__main__":
    DATA.mkdir(parents=True, exist_ok=True)
    panel()
    button()
    topbar()
    print("generated ui_panel.png ui_button.png ui_topbar.png")
