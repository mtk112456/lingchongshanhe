from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(r"D:\DeskBox\游戏")
ART = ROOT / "art_src" / "gpt" / "ai_pipeline_v1"

v2 = ART / "MAP12_LAYOUT_CONCEPT_V2.png"
im = Image.open(v2)
print("V2", im.size, im.mode, "MB", round(v2.stat().st_size / 1024 / 1024, 2))

for name in ["city_changan.png", "city_liangzhou.png"]:
    p = ART / name
    im = Image.open(p).convert("RGBA")
    bbox = im.getbbox()
    corners = [im.getpixel((0, 0))[3], im.getpixel((im.width - 1, 0))[3], im.getpixel((0, im.height - 1))[3], im.getpixel((im.width - 1, im.height - 1))[3]]
    print(name, im.size, im.mode, "bbox", bbox, "content", (bbox[2] - bbox[0], bbox[3] - bbox[1]) if bbox else None, "corners", corners)

# 64px preview on paper and dark backgrounds
cell = 160
pad = 12
canvas = Image.new("RGB", (cell * 4 + pad * 5, cell + 40), (32, 28, 24))
d = ImageDraw.Draw(canvas)
for i, name in enumerate(["city_changan.png", "city_liangzhou.png"]):
    im = Image.open(ART / name).convert("RGBA")
    for j, bg in enumerate([(246, 239, 226, 255), (47, 39, 33, 255)]):
        tile = Image.new("RGBA", (cell, cell), bg)
        small = im.copy()
        small.thumbnail((64, 64), Image.LANCZOS)
        tile.alpha_composite(small, ((cell - small.width) // 2, (cell - small.height) // 2))
        canvas.paste(tile.convert("RGB"), (pad + (i * 2 + j) * (cell + pad), 30))
        d.text((pad + (i * 2 + j) * (cell + pad), 8), f"{name} x64", fill=(240, 235, 220))
out = ART / "preview_64_changan_liangzhou.png"
canvas.save(out)
print("preview", out)
