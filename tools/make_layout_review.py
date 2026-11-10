from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r"D:\DeskBox\游戏")
OUT = ROOT / "tools" / "watch"
OUT.mkdir(parents=True, exist_ok=True)
FONT = "C:/Windows/Fonts/msyh.ttc"


def font(size):
    return ImageFont.truetype(FONT, size)


def label(draw, xy, text, fill=(255, 245, 220), bg=(32, 24, 18, 210), border=(207, 131, 37)):
    f = font(22)
    box = draw.textbbox((0, 0), text, font=f)
    w, h = box[2] - box[0] + 24, box[3] - box[1] + 14
    x, y = xy
    draw.rounded_rectangle((x, y, x + w, y + h), radius=8, fill=bg, outline=border, width=2)
    draw.text((x + 12, y + 6), text, font=f, fill=fill)


def annotate_map():
    src = ROOT / "client" / "tests" / "screenshot_tablet_s01_map.png"
    im = Image.open(src).convert("RGBA")
    overlay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    # top hud
    d.rectangle((0, 0, 1400, 72), fill=(30, 22, 16, 90), outline=(207, 131, 37, 220), width=2)
    label(d, (18, 16), "① 顶部 HUD：身份 / 资源 / 21:00 倒计时 / 设置")
    # left rail
    d.rectangle((10, 80, 150, 340), fill=(30, 22, 16, 80), outline=(207, 131, 37, 200), width=2)
    label(d, (18, 88), "② 左侧栏")
    # right rail
    d.rectangle((1248, 80, 1394, 340), fill=(30, 22, 16, 80), outline=(207, 131, 37, 200), width=2)
    label(d, (1120, 88), "③ 右侧栏")
    # map
    d.rectangle((158, 76, 1242, 936), fill=(0, 0, 0, 0), outline=(255, 245, 220, 230), width=2)
    label(d, (178, 690), "⑤ 常驻沙盘：5 节点 / 缩放 / LOD")
    # bottom dock
    d.rectangle((340, 936, 1060, 996), fill=(30, 22, 16, 85), outline=(207, 131, 37, 220), width=2)
    label(d, (352, 945), "④ 底部导航：地图 / 主城 / 军队 / 战报 / 回放")
    out = Image.alpha_composite(im, overlay).convert("RGB")
    out.save(OUT / "layout_map_annotated.jpg", quality=90)


def annotate_login():
    src = ROOT / "client" / "tests" / "screenshot_login_keyart.png"
    im = Image.open(src).convert("RGBA")
    overlay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    d.rectangle((0, 0, 1400, 1000), fill=(0, 0, 0, 0), outline=(207, 131, 37, 200), width=3)
    label(d, (20, 18), "① 全屏 C 主视觉：宣纸 / 水彩 / 木桌 / 文房")
    d.rectangle((448, 196, 952, 802), fill=(0, 0, 0, 0), outline=(255, 245, 220, 240), width=3)
    label(d, (470, 208), "② 奶油纸卡：登录全部内容")
    d.rectangle((480, 402, 930, 470), fill=(0, 0, 0, 0), outline=(255, 245, 220, 220), width=2)
    label(d, (492, 408), "③ 姓名 + 密码")
    d.rectangle((480, 520, 930, 570), fill=(0, 0, 0, 0), outline=(184, 59, 50, 240), width=3)
    label(d, (492, 526), "④ 唯一主按钮：踏入山河")
    d.rectangle((1268, 18, 1382, 56), fill=(0, 0, 0, 0), outline=(255, 245, 220, 180), width=2)
    label(d, (1140, 20), "⑤ 网络设置：弱化")
    out = Image.alpha_composite(im, overlay).convert("RGB")
    out.save(OUT / "layout_login_annotated.jpg", quality=90)


def flow():
    W, H = 1600, 920
    im = Image.new("RGB", (W, H), (24, 20, 17))
    d = ImageDraw.Draw(im)
    title = "页面流：地图常驻 + 分层入口（不是一页塞满）"
    d.text((50, 28), title, font=font(34), fill=(246, 239, 226))

    def box(x, y, w, h, text, sub="", color=(207, 131, 37)):
        d.rounded_rectangle((x, y, x + w, y + h), radius=14, fill=(38, 30, 24), outline=color, width=3)
        d.text((x + 20, y + 16), text, font=font(28), fill=(255, 245, 220))
        if sub:
            d.text((x + 20, y + 56), sub, font=font(18), fill=(190, 175, 150))

    def arrow(x1, y1, x2, y2, color=(207, 131, 37)):
        d.line((x1, y1, x2, y2), fill=color, width=4)
        # simple arrow head
        import math
        ang = math.atan2(y2 - y1, x2 - x1)
        for s in (-0.5, 0.5):
            d.line((x2, y2, x2 - 18 * math.cos(ang + s), y2 - 18 * math.sin(ang + s)), fill=color, width=4)

    box(50, 100, 300, 120, "登录页", "姓名 + 密码 / 单主按钮")
    box(420, 100, 560, 310, "主地图（常驻）", "顶部 HUD / 左右侧栏 / 底部导航 / 沙盘")
    box(1050, 100, 340, 120, "城池抽屉", "点城 → 底部滑出 ≤40%")
    box(1050, 260, 340, 120, "军令确认", "出发 → 目标 / 风险 / 确认")
    box(1050, 420, 340, 120, "战争日报", "独立全屏页 / 可追溯")
    box(1050, 580, 340, 120, "战局回放", "逐回合 / 不重算")

    box(50, 420, 300, 100, "阵营页", "领地 / 战功 / 目标")
    box(50, 560, 300, 100, "赛季页", "4 周进度 / 奖励")
    box(50, 700, 300, 100, "图鉴 / 商店", "文脉 / 外观 / 便利")

    arrow(350, 160, 420, 160)
    arrow(980, 160, 1050, 160)
    arrow(1220, 220, 1220, 260)
    arrow(1220, 380, 1220, 420)
    arrow(1220, 540, 1220, 580)
    arrow(200, 200, 200, 420)
    arrow(200, 520, 200, 560)
    arrow(200, 660, 200, 700)

    d.text((50, 850), "原则：主地图不消失；点城只开抽屉；战报/回放/阵营/赛季用独立页或全屏浮层；教师入口不进 App。",
           font=font(18), fill=(190, 175, 150))
    im.save(OUT / "layout_flow.jpg", quality=90)


annotate_map()
annotate_login()
flow()
print("layout images ready")
