"""NEON PEARL casino - printed textures (PIL only).
Generates JPGs into ../assets/textures/.
Run: python3 paint_casino.py
Font: DejaVuSans-Bold (has suit glyphs).
"""
import os, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BASE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(BASE, "..", "assets", "textures")
os.makedirs(TEX, exist_ok=True)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

WHEEL_ORDER = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8,
               23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12,
               35, 3, 26]
RED = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}


def f(size):
    return ImageFont.truetype(FONT, size)


def num_color(n):
    if n == 0:
        return (0, 130, 55)
    return (178, 24, 32) if n in RED else (18, 18, 22)


def centered(d, cx, cy, text, font, fill):
    b = d.textbbox((0, 0), text, font=font)
    w, h = b[2] - b[0], b[3] - b[1]
    d.text((cx - w / 2 - b[0], cy - h / 2 - b[1]), text, font=font, fill=fill)


# ---------------------------------------------------------------- roulette layout
def roulette_layout():
    W, H = 2048, 1024
    img = Image.new("RGB", (W, H), (8, 92, 52))
    d = ImageDraw.Draw(img)
    # subtle felt noise bands
    for i in range(0, H, 4):
        shade = 4 if (i // 4) % 2 else 0
        d.line([(0, i), (W, i)], fill=(8, 92 + shade, 52))
    WHITE = (240, 240, 235)
    x0, x1 = 573, 2030           # layout area (right of the wheel recess)
    gx0, gx1 = 650, 1890         # number grid
    gy0, gy1 = 80, 625           # grid vertical extent (image top = dealer/far side)
    rows = 3
    rh = (gy1 - gy0) / rows
    cw = (gx1 - gx0) / 12
    # zero cell (spans 3 rows)
    d.rectangle([x0, gy0, gx0, gy1], fill=(0, 140, 60), outline=WHITE, width=5)
    centered(d, (x0 + gx0) / 2, (gy0 + gy1) / 2, "0", f(62), WHITE)
    # number cells: image top row = 1,4,..34 ; mid = 2,5,..35 ; bottom = 3,6,..36
    for c in range(12):
        for r in range(3):       # r: 0 top,1 mid,2 bottom
            n = 3 * c + (r + 1)
            xa, ya = gx0 + c * cw, gy0 + r * rh
            d.rectangle([xa, ya, xa + cw, ya + rh], fill=num_color(n),
                        outline=WHITE, width=5)
            centered(d, xa + cw / 2, ya + rh / 2, str(n), f(56), WHITE)
    # column bets
    for r in range(3):
        ya = gy0 + r * rh
        d.rectangle([gx1, ya, x1, ya + rh], outline=WHITE, width=5)
        centered(d, (gx1 + x1) / 2, ya + rh / 2, "2:1", f(64), WHITE)
    # dozens
    dy0, dy1 = 660, 775
    dw = (gx1 - x0) / 3
    for i, label in enumerate(["1st 12", "2nd 12", "3rd 12"]):
        xa = x0 + i * dw
        d.rectangle([xa, dy0, xa + dw, dy1], outline=WHITE, width=5)
        centered(d, xa + dw / 2, (dy0 + dy1) / 2, label, f(72), WHITE)
    # even-money row
    ey0, ey1 = 810, 935
    ew = (gx1 - x0) / 6
    labels = ["1-18", "EVEN", None, None, "ODD", "19-36"]
    for i, label in enumerate(labels):
        xa = x0 + i * ew
        d.rectangle([xa, ey0, xa + ew, ey1], outline=WHITE, width=5)
        cx, cy = xa + ew / 2, (ey0 + ey1) / 2
        if label:
            centered(d, cx, cy, label, f(64), WHITE)
        else:
            col = (200, 30, 40) if i == 2 else (15, 15, 18)
            s = 34
            d.polygon([(cx, cy - s), (cx + s, cy), (cx, cy + s), (cx - s, cy)],
                      fill=col, outline=WHITE, width=3)
    d.rectangle([x0 - 6, gy0 - 6, x1 + 6, ey1 + 6], outline=WHITE, width=4)
    img.save(os.path.join(TEX, "roulette_layout.jpg"), quality=90)
    print("roulette_layout.jpg")


# ---------------------------------------------------------------- arc text helper
def arc_text(img, text, center, radius, a0, a1, font, fill):
    """Text along an arc; char tops point radially outward from center.
    Angles in degrees, screen coords (x right, y down), position =
    center + r*(cos a, sin a)."""
    n = len(text)
    for i, ch in enumerate(text):
        t = i / max(1, n - 1)
        a = math.radians(a0 + (a1 - a0) * t)
        x = center[0] + radius * math.cos(a)
        y = center[1] + radius * math.sin(a)
        # PIL rotate(theta CCW) maps up-vector (0,-1) -> (-sin, -cos);
        # want up = (cos a, sin a): theta = atan2(-cos a, -sin a)
        theta = math.degrees(math.atan2(-math.cos(a), -math.sin(a)))
        tile = Image.new("RGBA", (90, 90), (0, 0, 0, 0))
        td = ImageDraw.Draw(tile)
        b = td.textbbox((0, 0), ch, font=font)
        td.text((45 - (b[2] - b[0]) / 2 - b[0], 45 - (b[3] - b[1]) / 2 - b[1]),
                ch, font=font, fill=fill + (255,))
        tile = tile.rotate(theta, resample=Image.BICUBIC, expand=False)
        img.paste(tile, (int(x - 45), int(y - 45)), tile)


# ---------------------------------------------------------------- blackjack felt
def bj_felt():
    # Table top is 2.4 x 1.3 m but texture is square: the design band is the
    # middle 1.3/2.4 of the image height so shapes stay undistorted when the
    # UV maps the full bounding box. Scale = 1024/2.4 = 426.7 px per metre.
    S = 1024
    img = Image.new("RGB", (S, S), (7, 74, 58))
    d = ImageDraw.Draw(img)
    for i in range(0, S, 4):
        shade = 4 if (i // 4) % 2 else 0
        d.line([(0, i), (S, i)], fill=(7, 74 + shade, 58))
    WHITE = (238, 238, 230)
    GOLD = (232, 190, 90)
    # table centre maps to (512,512); dealer edge y=235, player edge y=789
    arc_text(img, "BLACKJACK PAYS 3 TO 2", (512, 960), 576, 243, 297,
             f(56), GOLD)
    d = ImageDraw.Draw(img)
    centered(d, 512, 482, "Dealer must stand on all 17s", f(33), WHITE)
    d.arc([512 - 405, 960 - 405, 512 + 405, 960 + 405], start=248, end=292,
          fill=WHITE, width=4)
    arc_text(img, "INSURANCE", (512, 960), 368, 256, 284, f(34), WHITE)
    d = ImageDraw.Draw(img)
    # 7 betting circles along the player-side arc (r = 0.85 m about table centre)
    for k in range(7):
        a = math.radians(28 + k * 20.6)
        cx = 512 + 363 * math.cos(a)
        cy = 512 + 363 * math.sin(a)
        d.ellipse([cx - 49, cy - 49, cx + 49, cy + 49], outline=WHITE, width=5)
    centered(d, 512, 292, "NEON PEARL", f(42), GOLD)
    img.save(os.path.join(TEX, "bj_felt.jpg"), quality=90)
    print("bj_felt.jpg")


# ---------------------------------------------------------------- poker felt
def poker_felt():
    W, H = 1024, 512
    img = Image.new("RGB", (W, H), (24, 16, 46))
    d = ImageDraw.Draw(img)
    for i in range(0, H, 4):
        shade = 3 if (i // 4) % 2 else 0
        d.line([(0, i), (W, i)], fill=(24 + shade, 16, 46 + shade))
    d.ellipse([46, 36, W - 46, H - 36], outline=(230, 225, 215), width=5)
    d.ellipse([70, 56, W - 70, H - 56], outline=(190, 150, 70), width=2)
    centered(d, W / 2, H / 2 - 26, "NEON PEARL", f(92), (232, 190, 90))
    centered(d, W / 2, H / 2 + 52, "TEXAS HOLD'EM", f(40), (220, 220, 225))
    img.save(os.path.join(TEX, "poker_felt.jpg"), quality=90)
    print("poker_felt.jpg")


# ---------------------------------------------------------------- carpet (tiling)
def casino_carpet():
    S = 1024
    img = Image.new("RGB", (S, S), (34, 13, 48))
    d = ImageDraw.Draw(img)
    GOLD = (196, 152, 62)
    MAG = (198, 40, 138)
    TEAL = (24, 110, 118)

    def wrapped(fn):
        for ox in (-S, 0, S):
            for oy in (-S, 0, S):
                fn(ox, oy)

    # diamond lattice
    step = 256
    for gx in range(0, S, step):
        for gy in range(0, S, step):
            cx, cy = gx + step // 2, gy + step // 2
            for r, col, wdt in [(86, GOLD, 5), (58, MAG, 4), (30, GOLD, 3)]:
                def dia(ox, oy, cx=cx, cy=cy, r=r, col=col, wdt=wdt):
                    d.polygon([(cx + ox, cy - r + oy), (cx + r + ox, cy + oy),
                               (cx + ox, cy + r + oy), (cx - r + ox, cy + oy)],
                              outline=col, width=wdt)
                wrapped(dia)
            def dot(ox, oy, cx=cx, cy=cy):
                d.ellipse([cx - 9 + ox, cy - 9 + oy, cx + 9 + ox, cy + 9 + oy],
                          fill=TEAL)
            wrapped(dot)
    # corner swirls (arcs) at lattice nodes
    for gx in range(0, S + 1, step):
        for gy in range(0, S + 1, step):
            for k in range(3):
                r = 26 + k * 16
                def arc(ox, oy, gx=gx, gy=gy, r=r, k=k):
                    d.arc([gx - r + ox, gy - r + oy, gx + r + ox, gy + r + oy],
                          start=k * 40, end=k * 40 + 200,
                          fill=MAG if k % 2 else GOLD, width=4)
                wrapped(arc)
    # small confetti ticks
    import random
    random.seed(7)
    for _ in range(160):
        x, y = random.randrange(S), random.randrange(S)
        col = GOLD if random.random() < 0.5 else MAG
        def tick(ox, oy, x=x, y=y, col=col):
            d.line([(x - 6 + ox, y + oy), (x + 6 + ox, y + oy)], fill=col, width=3)
        wrapped(tick)
    img.save(os.path.join(TEX, "casino_carpet.jpg"), quality=90)
    print("casino_carpet.jpg")


# ---------------------------------------------------------------- card atlas
def card_atlas():
    S = 1024
    img = Image.new("RGB", (S, S), (225, 225, 228))
    d = ImageDraw.Draw(img)
    cols, rows = 13, 5
    cw, chh = S / cols, S / rows
    suits = ["\u2660", "\u2665", "\u2666", "\u2663"]  # spade heart diamond club
    ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
    for r in range(4):
        red = r in (1, 2)
        col = (196, 24, 36) if red else (16, 16, 22)
        for c in range(cols):
            x0, y0 = c * cw, r * chh
            d.rectangle([x0 + 2, y0 + 2, x0 + cw - 2, y0 + chh - 2],
                        fill=(250, 250, 248), outline=(120, 120, 130), width=2)
            # corner rank + suit
            d.text((x0 + 7, y0 + 2), ranks[c], font=f(30), fill=col)
            d.text((x0 + 9, y0 + 36), suits[r], font=f(26), fill=col)
            # big center suit
            centered(d, x0 + cw / 2, y0 + chh / 2 + 8, suits[r], f(74), col)
    # row 4: card back, joker, blanks
    y0 = 4 * chh
    d.rectangle([2, y0 + 2, cw - 2, y0 + chh - 2], fill=(24, 40, 140),
                outline=(120, 120, 130), width=2)
    for i in range(6):
        for j in range(10):
            cx, cy = 8 + i * 12, y0 + 12 + j * 19
            d.polygon([(cx, cy - 6), (cx + 6, cy), (cx, cy + 6), (cx - 6, cy)],
                      outline=(210, 60, 80), width=1)
    d.rectangle([cw + 2, y0 + 2, 2 * cw - 2, y0 + chh - 2], fill=(250, 250, 248),
                outline=(120, 120, 130), width=2)
    centered(d, cw * 1.5, y0 + 60, "JOKER", f(15), (196, 24, 36))
    centered(d, cw * 1.5, y0 + chh / 2 + 26, "\u2605", f(64), (196, 24, 36))
    for c in range(2, cols):
        x0 = c * cw
        d.rectangle([x0 + 2, y0 + 2, x0 + cw - 2, y0 + chh - 2],
                    fill=(235, 235, 238), outline=(150, 150, 158), width=2)
    img.save(os.path.join(TEX, "card_atlas.jpg"), quality=92)
    print("card_atlas.jpg")


# ---------------------------------------------------------------- wheel ring
def wheel_ring():
    W, H = 1024, 256
    img = Image.new("RGB", (W, H), (30, 20, 12))
    d = ImageDraw.Draw(img)
    seg = W / 37
    for i, n in enumerate(WHEEL_ORDER):
        cx = i * seg
        d.rectangle([cx, 0, cx + seg, H], fill=num_color(n))
        d.line([(cx, 0), (cx, H)], fill=(210, 180, 120), width=2)
        # number rotated so it reads radially (top of digits toward v=0 edge)
        tile = Image.new("RGBA", (140, 30), (0, 0, 0, 0))
        td = ImageDraw.Draw(tile)
        centered(td, 70, 15, str(n), f(25), (245, 245, 240))
        tile = tile.rotate(-90, resample=Image.BICUBIC, expand=True)
        tx = int(cx + seg / 2 - tile.width / 2)
        img.paste(tile, (tx, H // 2 - tile.height // 2), tile)
        if i == 0:  # wrap copy for the u=0 seam
            img.paste(tile, (tx + W, H // 2 - tile.height // 2), tile)
    img.save(os.path.join(TEX, "wheel_ring.jpg"), quality=90)
    print("wheel_ring.jpg")


# ---------------------------------------------------------------- slot screen
def slot_screen():
    S = 512
    img = Image.new("RGB", (S, S), (8, 6, 22))
    glow = Image.new("RGB", (S, S), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    centered(gd, S / 2, 92, "NEON SLOTS", f(64), (255, 60, 170))
    centered(gd, S / 2, 300, "7 7 7", f(190), (255, 190, 40))
    centered(gd, S / 2, 448, "JACKPOT", f(44), (60, 220, 255))
    glow = glow.filter(ImageFilter.GaussianBlur(9))
    img = Image.blend(img, Image.new("RGB", (S, S), (8, 6, 22)), 0.0)
    from PIL import ImageChops
    img = ImageChops.add(img, glow)
    img = ImageChops.add(img, glow.point(lambda v: v // 2))
    d = ImageDraw.Draw(img)
    centered(d, S / 2, 92, "NEON SLOTS", f(64), (255, 170, 220))
    centered(d, S / 2, 300, "7 7 7", f(190), (255, 226, 130))
    centered(d, S / 2, 448, "JACKPOT", f(44), (170, 240, 255))
    d.rectangle([10, 10, S - 10, S - 10], outline=(255, 60, 170), width=4)
    img.save(os.path.join(TEX, "slot_screen.jpg"), quality=90)
    print("slot_screen.jpg")


if __name__ == "__main__":
    roulette_layout()
    bj_felt()
    poker_felt()
    casino_carpet()
    card_atlas()
    wheel_ring()
    slot_screen()
