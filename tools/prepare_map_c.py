from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(r"D:\DeskBox\游戏")
SRC = ROOT / "art_src" / "gpt" / "keyart_c.png"
OUT = ROOT / "client" / "assets" / "art" / "map_c.png"
PREVIEW = ROOT / "tools" / "watch" / "map_c_markers.jpg"

# Crop inside the torn-paper map area, excluding the right-hand order panel
# and the wooden desk strip at the bottom.
BOX = (125, 65, 1760, 1365)
im = Image.open(SRC).convert("RGB")
crop = im.crop(BOX)
OUT.parent.mkdir(parents=True, exist_ok=True)
crop.save(OUT, optimize=True)

# Anchor points in original keyart_c.png pixel coordinates, converted to crop space.
ANCHORS = {
    "A_START 云麓关": (518, 409),
    "N3 听雨台": (1509, 336),
    "N2 落霞原": (976, 715),
    "N1 松风渡": (410, 1061),
    "B_START 雁回关": (1409, 1114),
}

preview = crop.copy()
d = ImageDraw.Draw(preview)
w, h = preview.size
for label, (ax, ay) in ANCHORS.items():
    nx, ny = (ax - BOX[0]) / w, (ay - BOX[1]) / h
    x, y = int(nx * w), int(ny * h)
    r = 46
    d.ellipse((x - r, y - r, x + r, y + r), outline=(200, 40, 30), width=5)
    d.line((x - 10, y, x + 10, y), fill=(200, 40, 30), width=3)
    d.line((x, y - 10, x, y + 10), fill=(200, 40, 30), width=3)
    d.text((x + 52, y - 12), f"{label}  ({nx:.3f}, {ny:.3f})", fill=(20, 20, 20))

preview.thumbnail((1400, 1400), Image.LANCZOS)
PREVIEW.parent.mkdir(parents=True, exist_ok=True)
preview.save(PREVIEW, quality=90)
print("crop:", crop.size, "->", OUT)
print("preview:", PREVIEW)
for label, (ax, ay) in ANCHORS.items():
    print(label, round((ax - BOX[0]) / w, 3), round((ay - BOX[1]) / h, 3))
