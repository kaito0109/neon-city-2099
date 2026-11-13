#!/usr/bin/env python3
"""Paint the v3 kit atlas (1024x1024) used by the Blender building kits.

Layout in UV space (u right, v up; PIL y is flipped):
  ent_wall    (0.000, 0.500, 0.500, 1.000)  entropism concrete + dark windows
  kit_wall    (0.500, 0.5625, 1.000, 1.000) kitsch plastic panels + round windows
  mil_glass   (0.000, 0.250, 0.4375, 0.500) neo-militarism dark glass
  store_glass (0.4375, 0.3125, 1.000, 0.5625) ground-floor storefront glass
  panes       (0.500, 0.125, 1.000, 0.3125) 8x3 grid of lit/unlit window panes
  sign_yellow (0.000, 0.000, 0.250, 0.125)
  sign_cyan   (0.250, 0.000, 0.500, 0.125)
  sign_pink   (0.500, 0.000, 0.750, 0.125)
  hazard      (0.750, 0.000, 0.875, 0.125)  yellow/black diagonal stripes
  shutter     (0.875, 0.000, 1.000, 0.125)  corrugated shutter slats
  awning      (0.000, 0.125, 0.125, 0.250)  teal/white stripes
  poster      (0.125, 0.125, 0.250, 0.250)  layered poster art
  grille      (0.250, 0.125, 0.375, 0.250)  AC vent grille
  metal_plate (0.375, 0.125, 0.500, 0.250)  dark riveted metal
"""
import random
from PIL import Image, ImageDraw

S = 1024
img = Image.new("RGB", (S, S), (24, 24, 30))
dr = ImageDraw.Draw(img, "RGBA")
rng = random.Random(2077)


def px(rect):
    u0, v0, u1, v1 = rect
    return (int(u0 * S), int((1.0 - v1) * S), int(u1 * S), int((1.0 - v0) * S))


def fill(rect, col):
    dr.rectangle(px(rect), fill=col)


def noise(rect, base, amp, n=2600):
    x0, y0, x1, y1 = px(rect)
    for _ in range(n):
        x = rng.uniform(x0, x1)
        y = rng.uniform(y0, y1)
        d = rng.randint(-amp, amp)
        c = tuple(max(0, min(255, base[i] + d)) for i in range(3))
        dr.point((x, y), fill=c)


# ---------------------------------------------------------------- ent wall
ENT = (0.0, 0.5, 0.5, 1.0)
fill(ENT, (96, 95, 100))
noise(ENT, (96, 95, 100), 16)
x0, y0, x1, y1 = px(ENT)
# panel seams: verticals every 1/3, horizontal floor lines every 1/8
for i in range(1, 3):
    xx = x0 + (x1 - x0) * i // 3
    dr.line((xx, y0, xx, y1), fill=(70, 69, 74), width=3)
for j in range(9):
    yy = y0 + (y1 - y0) * j // 8
    dr.line((x0, yy, x1, yy), fill=(74, 73, 78), width=2)
# rain streaks under the top edge and random grime
for _ in range(46):
    sx = rng.uniform(x0 + 8, x1 - 8)
    sy = rng.uniform(y0, y1 - 90)
    ln = rng.uniform(28, 110)
    dr.line((sx, sy, sx + rng.uniform(-2, 2), sy + ln), fill=(58, 57, 62, 130), width=rng.randint(2, 5))
# punched windows: 6 cols x 8 rows, mostly dark, a few dim (glow panes overlay the lit ones)
cw = (x1 - x0) / 6.0
ch = (y1 - y0) / 8.0
for cx in range(6):
    for cy in range(8):
        wx0 = x0 + cx * cw + cw * 0.24
        wx1 = x0 + (cx + 1) * cw - cw * 0.24
        wy0 = y0 + cy * ch + ch * 0.22
        wy1 = y0 + (cy + 1) * ch - ch * 0.22
        r = rng.random()
        if r < 0.10:
            col = (52, 48, 40)
        elif r < 0.16:
            col = (38, 46, 54)
        else:
            col = (22, 23, 28)
        dr.rectangle((wx0, wy0, wx1, wy1), fill=col, outline=(60, 59, 64), width=2)
        dr.line((wx0, (wy0 + wy1) / 2, wx1, (wy0 + wy1) / 2), fill=(48, 47, 52), width=2)

# ---------------------------------------------------------------- kit wall
KIT = (0.5, 0.5625, 1.0, 1.0)
fill(KIT, (196, 190, 178))
noise(KIT, (196, 190, 178), 10, 1500)
x0, y0, x1, y1 = px(KIT)
# big plastic colour panels (kitsch blocks of yellow / turquoise / pink)
panels = [(252, 238, 10), (20, 200, 205), (245, 90, 160), (252, 238, 10), (20, 200, 205)]
pw = (x1 - x0) / 5.0
for i, col in enumerate(panels):
    dr.rectangle((x0 + i * pw + 5, y0 + 14, x0 + (i + 1) * pw - 5, y0 + 74), fill=col)
    dr.rectangle((x0 + i * pw + 5, y1 - 66, x0 + (i + 1) * pw - 5, y1 - 12), fill=col)
# floor seams
for j in range(1, 6):
    yy = y0 + (y1 - y0) * j // 6
    dr.line((x0, yy, x1, yy), fill=(150, 144, 132), width=3)
# round windows: 5 cols x 6 rows of dark circles (glow discs overlay lit ones)
cw = (x1 - x0) / 5.0
ch = (y1 - y0) / 6.0
for cx in range(5):
    for cy in range(6):
        ccx = x0 + (cx + 0.5) * cw
        ccy = y0 + (cy + 0.5) * ch
        r = min(cw, ch) * 0.30
        dr.ellipse((ccx - r, ccy - r, ccx + r, ccy + r), fill=(26, 28, 34), outline=(120, 114, 102), width=3)

# ---------------------------------------------------------------- mil glass
MIL = (0.0, 0.25, 0.4375, 0.5)
x0, y0, x1, y1 = px(MIL)
for yy in range(y0, y1):
    t = (yy - y0) / max(1, (y1 - y0))
    col = (int(16 + 14 * t), int(22 + 16 * t), int(32 + 20 * t))
    dr.line((x0, yy, x1, yy), fill=col)
cw = (x1 - x0) / 8.0
ch = (y1 - y0) / 6.0
for i in range(9):
    xx = x0 + i * cw
    dr.line((xx, y0, xx, y1), fill=(52, 62, 78), width=2)
for j in range(7):
    yy = y0 + j * ch
    dr.line((x0, yy, x1, yy), fill=(52, 62, 78), width=2)
noise(MIL, (24, 32, 46), 7, 900)

# ---------------------------------------------------------------- storefront glass
STO = (0.4375, 0.3125, 1.0, 0.5625)
x0, y0, x1, y1 = px(STO)
for yy in range(y0, y1):
    t = (yy - y0) / max(1, (y1 - y0))
    # warm interior glow near the bottom (street level), dark glass above
    col = (int(30 + 66 * t), int(24 + 44 * t), int(26 + 22 * t))
    dr.line((x0, yy, x1, yy), fill=col)
# interior silhouettes: shelves / counter blocks
for i in range(7):
    sx = x0 + rng.uniform(0, (x1 - x0) - 60)
    sw = rng.uniform(26, 58)
    sh = rng.uniform(30, 80)
    dr.rectangle((sx, y1 - sh, sx + sw, y1), fill=(18, 14, 12, 170))
# mullions
seg = (x1 - x0) / 6.0
for i in range(7):
    xx = x0 + i * seg
    dr.rectangle((xx - 3, y0, xx + 3, y1), fill=(12, 12, 14))
dr.rectangle((x0, y0, x1, y0 + 8), fill=(12, 12, 14))
dr.rectangle((x0, y1 - 8, x1, y1), fill=(12, 12, 14))

# ---------------------------------------------------------------- glow panes
PAN = (0.5, 0.125, 1.0, 0.3125)
x0, y0, x1, y1 = px(PAN)
cw = (x1 - x0) / 8.0
ch = (y1 - y0) / 3.0
pane_rows = [
    [(255, 196, 110), (255, 176, 92), (250, 205, 140), (238, 168, 84),
     (255, 214, 150), (246, 188, 102), (255, 200, 120), (240, 178, 96)],
    [(168, 216, 255), (150, 200, 246), (190, 228, 255), (140, 188, 238),
     (176, 220, 250), (158, 206, 244), (182, 224, 252), (148, 196, 240)],
    [(96, 88, 74), (60, 66, 76), (30, 32, 38), (24, 25, 30),
     (235, 242, 248), (208, 220, 230), (52, 56, 64), (28, 29, 34)],
]
for r in range(3):
    for c in range(8):
        cx0 = x0 + c * cw + 3
        cx1 = x0 + (c + 1) * cw - 3
        cy0 = y0 + r * ch + 3
        cy1 = y0 + (r + 1) * ch - 3
        dr.rectangle((cx0, cy0, cx1, cy1), fill=pane_rows[r][c])
        if r < 2 and rng.random() < 0.4:  # half-open blind line
            dr.line((cx0, (cy0 + cy1) / 2, cx1, (cy0 + cy1) / 2), fill=(90, 80, 70), width=2)

# ---------------------------------------------------------------- signs
def sign(rect, bg, fg, style):
    x0, y0, x1, y1 = px(rect)
    dr.rectangle((x0, y0, x1, y1), fill=bg)
    if style == 0:  # bold bars = fake glyphs
        bx = x0 + 18
        while bx < x1 - 44:
            w = rng.uniform(16, 34)
            dr.rectangle((bx, y0 + 26, bx + w, y1 - 26), fill=fg)
            bx += w + 14
    elif style == 1:  # circle + bars
        r = (y1 - y0) * 0.32
        dr.ellipse((x0 + 22, y0 + (y1 - y0) / 2 - r, x0 + 22 + 2 * r, y0 + (y1 - y0) / 2 + r), outline=fg, width=9)
        dr.rectangle((x0 + 130, y0 + 34, x1 - 24, y0 + 56), fill=fg)
        dr.rectangle((x0 + 130, y0 + 70, x1 - 60, y0 + 92), fill=fg)
    else:  # stacked bars
        dr.rectangle((x0 + 20, y0 + 22, x1 - 90, y0 + 46), fill=fg)
        dr.rectangle((x0 + 20, y0 + 58, x1 - 40, y0 + 82), fill=fg)
        dr.rectangle((x0 + 20, y0 + 94, x1 - 130, y0 + 112), fill=fg)


sign((0.0, 0.0, 0.25, 0.125), (252, 238, 10), (16, 16, 16), 0)      # CYBERPUNK YELLOW
sign((0.25, 0.0, 0.5, 0.125), (8, 40, 52), (64, 224, 255), 1)       # cyan on deep teal
sign((0.5, 0.0, 0.75, 0.125), (255, 64, 150), (255, 244, 250), 2)   # hot pink

# hazard stripes
HZ = (0.75, 0.0, 0.875, 0.125)
x0, y0, x1, y1 = px(HZ)
dr.rectangle((x0, y0, x1, y1), fill=(252, 238, 10))
for i in range(-2, 8):
    sx = x0 + i * 32
    dr.polygon([(sx, y1), (sx + 18, y1), (sx + 18 + (y1 - y0), y0), (sx + (y1 - y0), y0)], fill=(14, 14, 14))

# shutter slats
SH = (0.875, 0.0, 1.0, 0.125)
x0, y0, x1, y1 = px(SH)
dr.rectangle((x0, y0, x1, y1), fill=(104, 106, 112))
for yy in range(y0, y1, 10):
    dr.line((x0, yy, x1, yy), fill=(66, 67, 72), width=3)
    dr.line((x0, yy + 4, x1, yy + 4), fill=(140, 142, 148), width=1)
noise(SH, (104, 106, 112), 12, 300)

# awning stripes (teal / off-white)
AW = (0.0, 0.125, 0.125, 0.25)
x0, y0, x1, y1 = px(AW)
for i in range(8):
    col = (16, 150, 152) if i % 2 == 0 else (226, 222, 208)
    dr.rectangle((x0 + i * (x1 - x0) // 8, y0, x0 + (i + 1) * (x1 - x0) // 8, y1), fill=col)

# poster: layered gig-poster art
PO = (0.125, 0.125, 0.25, 0.25)
x0, y0, x1, y1 = px(PO)
dr.rectangle((x0, y0, x1, y1), fill=(214, 208, 196))
dr.rectangle((x0 + 8, y0 + 8, x1 - 20, y1 - 30), fill=(200, 44, 66))
dr.ellipse((x0 + 30, y0 + 22, x1 - 42, y0 + 82), fill=(252, 238, 10))
dr.rectangle((x0 + 14, y1 - 44, x1 - 14, y1 - 32), fill=(20, 20, 24))
dr.rectangle((x0 + 14, y1 - 26, x1 - 40, y1 - 16), fill=(20, 20, 24))
dr.polygon([(x1 - 26, y0), (x1, y0), (x1, y0 + 26)], fill=(168, 162, 150))  # torn corner

# AC grille
GR = (0.25, 0.125, 0.375, 0.25)
x0, y0, x1, y1 = px(GR)
dr.rectangle((x0, y0, x1, y1), fill=(72, 74, 80))
for yy in range(y0 + 8, y1 - 6, 9):
    dr.line((x0 + 8, yy, x1 - 8, yy), fill=(30, 31, 36), width=4)
dr.rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 3), outline=(110, 112, 118), width=3)

# riveted metal plate
ME = (0.375, 0.125, 0.5, 0.25)
x0, y0, x1, y1 = px(ME)
dr.rectangle((x0, y0, x1, y1), fill=(52, 53, 60))
noise(ME, (52, 53, 60), 8, 500)
for cx, cy in [(10, 10), (x1 - x0 - 10, 10), (10, y1 - y0 - 10), (x1 - x0 - 10, y1 - y0 - 10)]:
    dr.ellipse((x0 + cx - 4, y0 + cy - 4, x0 + cx + 4, y0 + cy + 4), fill=(96, 98, 106))

img.save("/home/hatch/workspace/godot_neon/assets/textures/kit_atlas.jpg", quality=90)
img.save("/tmp/kit_atlas_preview.png")
print("atlas saved")
