"""Acceptance probe: screenshot content metrics, asset validation, contact sheet.

Usage:
  python tools/watch_probe.py --images a.png b.png --contact out.jpg --out probe.json
  python tools/watch_probe.py --assets --out assets.json
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageStat

ROOT = Path(__file__).resolve().parent.parent

ASSET_SPECS = {
    "city_yunlu.png": (512, 512, "RGBA"),
    "city_songfeng.png": (512, 512, "RGBA"),
    "city_luoxia.png": (512, 512, "RGBA"),
    "city_tingyu.png": (512, 512, "RGBA"),
    "city_yanhui.png": (512, 512, "RGBA"),
    "mascot_bamboo_normal.png": (1024, 1024, "RGBA"),
    "mascot_bamboo_happy.png": (1024, 1024, "RGBA"),
    "mascot_bamboo_nervous.png": (1024, 1024, "RGBA"),
    "mascot_inkdrop_normal.png": (1024, 1024, "RGBA"),
    "mascot_inkdrop_proud.png": (1024, 1024, "RGBA"),
    "mascot_inkdrop_sad.png": (1024, 1024, "RGBA"),
    "ui_kit_c.png": (1586, 992, "RGB"),
}


def image_metrics(path: Path) -> dict:
    with Image.open(path) as src:
        im = src.convert("RGB")
        width, height = im.size
        small = im.copy()
        small.thumbnail((400, 400), Image.LANCZOS)
        gray = small.convert("L")
        std = float(ImageStat.Stat(gray).stddev[0])
        quant = small.quantize(colors=64, method=Image.MEDIANCUT).convert("RGB")
        colors = quant.getcolors(maxcolors=1_000_000) or []
        unique = len(colors)
        total = max(1, quant.width * quant.height)
        dominant = max((count for count, _ in colors), default=total) / total
    return {
        "path": str(path),
        "name": path.name,
        "width": width,
        "height": height,
        "bytes": path.stat().st_size,
        "std": round(std, 2),
        "unique": unique,
        "dominant": round(dominant, 3),
        # 纯黑/纯色空面板才会 std < 5；有文字的空态通常 std >= 8
        "blank_like": std < 5.0 and unique < 12,
    }


def check_assets() -> dict:
    art = ROOT / "client" / "assets" / "art"
    source = ROOT / "art_src" / "gpt"
    checks = {}
    for name, (want_w, want_h, want_mode) in ASSET_SPECS.items():
        path = art / name
        info = {"exists": path.is_file()}
        if path.is_file():
            with Image.open(path) as im:
                info.update(
                    width=im.width,
                    height=im.height,
                    mode=im.mode,
                    ok=im.width == want_w and im.height == want_h and im.mode == want_mode,
                )
                if im.mode == "RGBA":
                    rgba = im.convert("RGBA")
                    info["corners"] = [
                        rgba.getpixel((0, 0))[3],
                        rgba.getpixel((rgba.width - 1, 0))[3],
                        rgba.getpixel((0, rgba.height - 1))[3],
                        rgba.getpixel((rgba.width - 1, rgba.height - 1))[3],
                    ]
                    info["transparent_corners"] = all(a == 0 for a in info["corners"])
        checks[name] = info

    map_path = art / "map_c.png"
    map_info = {"exists": map_path.is_file()}
    if map_path.is_file():
        with Image.open(map_path) as im:
            map_info.update(width=im.width, height=im.height, mode=im.mode,
                            ok=im.width == 1635 and im.height == 1300)
    checks["map_c.png"] = map_info

    keyart = source / "keyart_c.png"
    keyart_info = {"exists": keyart.is_file()}
    if keyart.is_file():
        with Image.open(keyart) as im:
            keyart_info.update(width=im.width, height=im.height, mode=im.mode)
    checks["keyart_c.png"] = keyart_info
    return checks


def contact_sheet(paths: list[Path], out: Path) -> None:
    thumbs = []
    for path in paths:
        if not path.is_file():
            continue
        with Image.open(path) as src:
            im = src.convert("RGB")
            width = 520
            height = max(1, int(im.height * width / im.width))
            thumbs.append((path.name, im.resize((width, height), Image.LANCZOS)))
    if not thumbs:
        return
    cols = 3
    gap = 14
    label_h = 26
    cell_w = 520
    cell_h = max(im.height for _, im in thumbs) + label_h
    rows = (len(thumbs) + cols - 1) // cols
    canvas = Image.new("RGB", (cols * cell_w + (cols + 1) * gap, rows * cell_h + (rows + 1) * gap), (28, 28, 28))
    draw = ImageDraw.Draw(canvas)
    for i, (name, im) in enumerate(thumbs):
        col, row = i % cols, i // cols
        x = gap + col * (cell_w + gap)
        y = gap + row * (cell_h + gap)
        draw.text((x, y), name, fill=(240, 235, 220))
        canvas.paste(im, (x, y + label_h))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out, quality=88)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--images", nargs="*", default=[])
    parser.add_argument("--assets", action="store_true")
    parser.add_argument("--contact", default="")
    parser.add_argument("--out", default="")
    args = parser.parse_args()

    payload: dict = {}
    if args.images:
        payload["images"] = [image_metrics(Path(p)) for p in args.images if Path(p).is_file()]
    if args.assets:
        payload["assets"] = check_assets()
    if args.out:
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    if args.contact and args.images:
        contact_sheet([Path(p) for p in args.images], Path(args.contact))
    print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
