#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
《青竹文房·灵宠山河》地图生成器
输入：client/data/china_provinces.json + client/data/provinces.json
输出：
  client/data/map_base.png   精致底图（省界/势力淡染/河流/山脉/省名/纸纹/暗角）
  client/data/map_id.png     省份 ID 图（每省唯一红色值，用于点击/上色）
  client/data/map_meta.json  城池与省会的归一化坐标
"""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
CLIENT = ROOT / "client"
DATA = CLIENT / "data"

W, H = 1760, 1120
S = 2  # 超采样倍数
MARGIN = 0.025

PAPER = (243, 234, 216)
PAPER_DARK = (233, 223, 204)
WATER = (219, 231, 234)
INK = (95, 81, 67)
BORDER_DARK = (143, 128, 107)
BORDER_LIGHT = (185, 169, 142)
GOLD = (207, 131, 37)
FACTION = {
    "bi": (184, 59, 50),
    "mo": (30, 58, 95),
    "zhi": (207, 131, 37),
    "yan": (39, 111, 87),
}
OWNER = {
    "陕西省": "bi",
    "四川省": "yan",
    "江苏省": "zhi",
    "浙江省": "zhi",
    "山西省": "mo",
    "河北省": "mo",
    "湖北省": "yan",
}
ACTIVE = {
    "陕西省", "河南省", "四川省", "湖北省", "湖南省",
    "江苏省", "浙江省", "山西省", "河北省", "安徽省",
}
SHORT = [
    ("维吾尔自治区", ""), ("壮族自治区", ""), ("回族自治区", ""),
    ("自治区", ""), ("特别行政区", ""), ("省", ""), ("市", ""),
]


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def blend(a, b, t):
    return tuple(int(round(a[i] * (1 - t) + b[i] * t)) for i in range(3))


def short_name(name: str) -> str:
    for suffix, repl in SHORT:
        name = name.replace(suffix, repl)
    return name


def project_raw(lon: float, lat: float):
    x = math.radians(lon)
    y = math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))
    return x, -y


def iter_coords(coords):
    if isinstance(coords, (list, tuple)) and len(coords) >= 2 and isinstance(coords[0], (int, float)) and isinstance(coords[1], (int, float)):
        yield float(coords[0]), float(coords[1])
    elif isinstance(coords, (list, tuple)):
        for item in coords:
            yield from iter_coords(item)


def main():
    geo = load_json(DATA / "china_provinces.json")
    province_data = load_json(DATA / "provinces.json")

    # 投影边界
    xs, ys = [], []
    for feature in geo.get("features", []):
        for lon, lat in iter_coords(feature.get("geometry", {}).get("coordinates", [])):
            x, y = project_raw(lon, lat)
            xs.append(x)
            ys.append(y)
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)

    def project(lon: float, lat: float, scale: float = 1.0):
        x, y = project_raw(lon, lat)
        nx = (x - min_x) / max(1e-9, max_x - min_x)
        ny = (y - min_y) / max(1e-9, max_y - min_y)
        nx = MARGIN + nx * (1 - 2 * MARGIN)
        ny = MARGIN + ny * (1 - 2 * MARGIN)
        return nx * W * scale, ny * H * scale

    def poly_points(ring, scale: float):
        return [project(lon, lat, scale) for lon, lat in ring]

    # 底图（超采样）
    base = Image.new("RGB", (W * S, H * S), PAPER)
    draw = ImageDraw.Draw(base)

    # 省名标签字体
    font_path = CLIENT / "fonts" / "NotoSerifCJKsc-Regular.otf"
    font = ImageFont.truetype(str(font_path), int(19 * S))
    font_city = ImageFont.truetype(str(font_path), int(16 * S))

    province_index = {}
    next_id = 1

    # 先填省面
    for feature in geo.get("features", []):
        props = feature.get("properties", {})
        name = (props.get("name") or "").strip()
        if not name:
            continue
        province_index[name] = next_id
        next_id += 1

        owner = OWNER.get(name)
        if owner:
            fill = blend(PAPER, FACTION[owner], 0.20)
        else:
            fill = PAPER_DARK
        if name not in ACTIVE:
            fill = blend(fill, (246, 239, 226), 0.55)

        geom = feature.get("geometry", {})
        gtype = geom.get("type")
        coords = geom.get("coordinates", [])
        polys = [coords] if gtype == "Polygon" else coords

        for rings in polys:
            if not rings:
                continue
            outer = poly_points(rings[0], S)
            if len(outer) >= 3:
                draw.polygon(outer, fill=fill)
            for hole in rings[1:]:
                hp = poly_points(hole, S)
                if len(hp) >= 3:
                    draw.polygon(hp, fill=WATER)

    # 活跃省份的淡金外发光（先画在底图上，再压边）
    for feature in geo.get("features", []):
        name = (feature.get("properties", {}).get("name") or "").strip()
        if name not in ACTIVE:
            continue
        geom = feature.get("geometry", {})
        gtype = geom.get("type")
        coords = geom.get("coordinates", [])
        polys = [coords] if gtype == "Polygon" else coords
        for rings in polys:
            if not rings:
                continue
            pts = poly_points(rings[0], S)
            if len(pts) >= 3:
                draw.line(pts + [pts[0]], fill=blend(PAPER, GOLD, 0.35), width=int(7 * S), joint="curve")

    # 省界
    for feature in geo.get("features", []):
        props = feature.get("properties", {})
        name = (props.get("name") or "").strip()
        if not name:
            continue
        owner = OWNER.get(name)
        border = blend(BORDER_LIGHT, FACTION[owner], 0.55) if owner else BORDER_LIGHT
        if name not in ACTIVE:
            border = blend(BORDER_LIGHT, PAPER, 0.35)

        geom = feature.get("geometry", {})
        gtype = geom.get("type")
        coords = geom.get("coordinates", [])
        polys = [coords] if gtype == "Polygon" else coords
        for rings in polys:
            if not rings:
                continue
            pts = poly_points(rings[0], S)
            if len(pts) >= 3:
                draw.line(pts + [pts[0]], fill=BORDER_DARK, width=int(2.4 * S), joint="curve")
                draw.line(pts + [pts[0]], fill=border, width=int(1.1 * S), joint="curve")
            for hole in rings[1:]:
                hp = poly_points(hole, S)
                if len(hp) >= 3:
                    draw.line(hp + [hp[0]], fill=blend(BORDER_DARK, PAPER, 0.45), width=int(1.0 * S), joint="curve")

    # 河流
    def draw_river(points):
        pts = [project(lon, lat, S) for lon, lat in points]
        draw.line(pts, fill=(111, 147, 168), width=int(3.2 * S), joint="curve")
        draw.line(pts, fill=(207, 225, 234), width=int(1.2 * S), joint="curve")

    draw_river([
        (96.0, 35.0), (99.0, 35.8), (102.0, 36.0), (105.0, 36.4),
        (107.5, 37.2), (110.0, 37.8), (111.5, 37.0), (112.0, 35.2),
        (114.0, 34.8), (116.0, 35.8), (118.0, 37.0), (119.2, 37.6),
    ])
    draw_river([
        (91.0, 33.0), (94.0, 32.0), (97.0, 30.5), (100.0, 29.2),
        (103.0, 29.0), (106.0, 29.8), (109.0, 30.0), (112.0, 30.0),
        (114.5, 29.8), (117.0, 30.8), (119.0, 31.8), (121.2, 31.4),
    ])

    # 山脉
    def mountains(center_lonlat, count, scale=1.0):
        for i in range(count):
            lon = center_lonlat[0] + math.sin(i * 2.7) * 0.55
            lat = center_lonlat[1] + math.cos(i * 1.9) * 0.35
            x, y = project(lon, lat, S)
            w = (12 + (i % 3) * 4) * scale * S
            h = (18 + (i % 2) * 8) * scale * S
            tri = [(x - w, y + h * 0.5), (x, y - h), (x + w, y + h * 0.5)]
            shadow = [(px + 2 * S, py + 3 * S) for px, py in tri]
            draw.polygon(shadow, fill=blend(PAPER, INK, 0.12))
            draw.polygon(tri, fill=blend(PAPER, INK, 0.45))
            snow = [(x - w * 0.35, y - h * 0.15), (x, y - h), (x + w * 0.35, y - h * 0.15)]
            draw.polygon(snow, fill=(255, 250, 240))

    mountains((99.0, 38.2), 6, 1.0)
    mountains((103.5, 34.0), 7, 0.9)
    mountains((113.2, 38.2), 5, 0.8)
    mountains((110.0, 30.5), 5, 0.8)
    mountains((86.0, 42.0), 7, 1.1)
    mountains((90.0, 33.0), 6, 1.0)

    # 关隘
    def draw_pass(code):
        city = next((p for p in province_data["provinces"] if p["code"] == code), None)
        if not city:
            return
        x, y = project(city["lon"], city["lat"], S)
        w, h = 9 * S, 13 * S
        draw.rectangle([x - w, y - h - 24 * S, x + w, y - 24 * S], fill=blend(PAPER, INK, 0.25))
        draw.rectangle([x - w * 0.55, y - h - 24 * S, x + w * 0.55, y - 24 * S], fill=PAPER)
        draw.line([x, y - 12 * S, x, y + 4 * S], fill=blend(PAPER, INK, 0.45), width=int(1.0 * S))

    draw_pass("hanzhong")
    draw_pass("xiangyang")

    # 省名（轻）
    for feature in geo.get("features", []):
        props = feature.get("properties", {})
        name = (props.get("name") or "").strip()
        if not name:
            continue
        center = props.get("centroid") or props.get("center")
        if not center:
            continue
        x, y = project(center[0], center[1], S)
        label = short_name(name)
        color = (95, 81, 67, 190) if name in ACTIVE else (122, 106, 85, 120)
        draw.text((x, y), label, font=font, fill=color, anchor="mm", stroke_width=0)

    # 城池名（底图不画，Godot 用木牌；这里只画一个很小的点，供定位参考）
    for city in province_data["provinces"]:
        x, y = project(city["lon"], city["lat"], S)
        draw.ellipse([x - 3 * S, y - 3 * S, x + 3 * S, y + 3 * S], fill=blend(PAPER, INK, 0.55))

    # 纸纹 + 暗角
    arr = np.asarray(base).astype(np.float32)
    rng = np.random.default_rng(42)
    noise = rng.normal(0, 4.0, (arr.shape[0], arr.shape[1], 1))
    arr[:, :, :3] = np.clip(arr[:, :, :3] + noise, 0, 255)
    yy, xx = np.mgrid[0:arr.shape[0], 0:arr.shape[1]]
    nx = (xx - arr.shape[1] / 2) / (arr.shape[1] / 2)
    ny = (yy - arr.shape[0] / 2) / (arr.shape[0] / 2)
    dist = np.sqrt(nx * nx + ny * ny)
    vig = np.clip(1.0 - 0.16 * dist * dist, 0.82, 1.0)[:, :, None]
    arr[:, :, :3] = np.clip(arr[:, :, :3] * vig, 0, 255)
    base = Image.fromarray(arr.astype(np.uint8), "RGB")
    base = base.resize((W, H), Image.LANCZOS)
    base.save(DATA / "map_base.png", optimize=True)

    # 省份 ID 图（不超采样，保持硬边）
    id_img = Image.new("RGB", (W, H), (0, 0, 0))
    id_draw = ImageDraw.Draw(id_img)
    for feature in geo.get("features", []):
        name = (feature.get("properties", {}).get("name") or "").strip()
        if not name:
            continue
        idx = province_index.get(name, 0)
        color = (idx, 0, 0)
        geom = feature.get("geometry", {})
        gtype = geom.get("type")
        coords = geom.get("coordinates", [])
        polys = [coords] if gtype == "Polygon" else coords
        for rings in polys:
            if not rings:
                continue
            pts = [project(lon, lat, 1.0) for lon, lat in rings[0]]
            if len(pts) >= 3:
                id_draw.polygon(pts, fill=color)
            for hole in rings[1:]:
                hp = [project(lon, lat, 1.0) for lon, lat in hole]
                if len(hp) >= 3:
                    id_draw.polygon(hp, fill=(0, 0, 0))
    id_img.save(DATA / "map_id.png", optimize=True)

    # 归一化坐标
    meta = {"width": W, "height": H, "cities": {}, "provinces": {}}
    for city in province_data["provinces"]:
        x, y = project(city["lon"], city["lat"], 1.0)
        meta["cities"][city["code"]] = [round(x / W, 6), round(y / H, 6)]
    for feature in geo.get("features", []):
        props = feature.get("properties", {})
        name = (props.get("name") or "").strip()
        if not name:
            continue
        center = props.get("centroid") or props.get("center")
        if not center:
            continue
        x, y = project(center[0], center[1], 1.0)
        meta["provinces"][name] = [round(x / W, 6), round(y / H, 6)]
    with (DATA / "map_meta.json").open("w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)

    print("generated:", DATA / "map_base.png", DATA / "map_id.png", DATA / "map_meta.json")


if __name__ == "__main__":
    main()
