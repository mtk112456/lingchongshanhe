from pathlib import Path
from PIL import Image

ROOT = Path(r"D:\DeskBox\游戏")
ART = ROOT / "client" / "assets" / "art"
CODES = ["yunlu", "songfeng", "luoxia", "tingyu", "yanhui"]
PAD = 8

for code in CODES:
    src = ART / f"city_{code}.png"
    im = Image.open(src).convert("RGBA")
    bbox = im.getbbox()
    if not bbox:
        print("empty", src)
        continue
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - PAD)
    y0 = max(0, y0 - PAD)
    x1 = min(im.width, x1 + PAD)
    y1 = min(im.height, y1 + PAD)
    out = im.crop((x0, y0, x1, y1))
    dst = ART / f"city_{code}_trim.png"
    out.save(dst, optimize=True)
    print(f"{dst.name}: {out.width}x{out.height} from {src.name} bbox={bbox}")
