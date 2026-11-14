#!/usr/bin/env python3
"""NEON CITY 2099 v4 - Phase 0 layout map (450m, density-first).
Draws a top-view plan PNG from the layout data below. The same data is
documented in design/v4_layout.md and will drive the Blender terrain
build in Phase 1. World coords: meters, origin = city centre,
+x east, +z south (map: right = east, down = south)."""
import math
from PIL import Image, ImageDraw, ImageFont

S = 3.6            # px per meter
OFF = 250.0        # world -250..250 -> px 0..1800
MAPW = 1800
PANELW = 580
W, H = MAPW + PANELW, 1800
FONT = "/home/hatch/workspace/godot_neon/assets/jpfont.ttf"

def F(sz):
    return ImageFont.truetype(FONT, sz)

def X(wx):
    return (wx + OFF) * S

def Y(wz):
    return (wz + OFF) * S

def P(pt):
    return (X(pt[0]), Y(pt[1]))

img = Image.new("RGB", (W, H), (8, 10, 16))
d = ImageDraw.Draw(img, "RGBA")

# ---------- district tints ----------
d.polygon([P((-225, -225)), P((-105, -225)), P((-105, 225)), P((-225, 225))],
          fill=(70, 60, 40, 46))          # west industrial
d.polygon([P((115, -70)), P((225, -70)), P((225, 160)), P((115, 160))],
          fill=(40, 70, 90, 46))          # east corporate
d.polygon([P((55, -225)), P((225, -225)), P((225, -65)), P((55, -65))],
          fill=(60, 50, 90, 52))          # NE hills
d.polygon([P((-225, 120)), P((225, 120)), P((225, 225)), P((-225, 225))],
          fill=(90, 50, 60, 40))          # south canal/market

# ---------- built mass: jittered block tiles ----------
import random
random.seed(42)
for gx in range(-225, 225, 30):
    for gz in range(-225, 225, 30):
        jx = random.uniform(-4, 4)
        jz = random.uniform(-4, 4)
        v = random.randint(-7, 9)
        col = (26 + v, 29 + v, 40 + v)
        d.rectangle([X(gx + 2.5 + jx), Y(gz + 2.5 + jz),
                     X(gx + 27.5 + jx), Y(gz + 27.5 + jz)], fill=col)

# ---------- hill terraces (NE) ----------
terr = [((66, -76), (219, -219), (96, 96, 120, 60), "+6m"),
        ((104, -114), (219, -219), (106, 106, 132, 66), "+12m"),
        ((142, -152), (219, -219), (116, 116, 144, 72), "+18m")]
for (a, b, col, _t) in terr:
    xs = sorted([X(a[0]), X(b[0])])
    ys = sorted([Y(a[1]), Y(b[1])])
    d.rectangle([xs[0], ys[0], xs[1], ys[1]], fill=col,
                outline=(150, 150, 190, 160), width=2)

# ---------- canal ----------
canal = [(-225, 176), (-120, 182), (-20, 174), (80, 178), (225, 188)]
cw = 17 * S
d.line([P(p) for p in canal], fill=(14, 52, 84), width=int(cw))
d.line([P(p) for p in canal], fill=(30, 92, 132), width=int(cw * 0.55))
# promenade strips
for off in (-13.5, 13.5):
    pts = [(x, z + off) for (x, z) in canal]
    d.line([P(p) for p in pts], fill=(58, 62, 74), width=int(3.2 * S))

# ---------- plaza ----------
d.rectangle([X(-34), Y(-34), X(34), Y(34)], fill=(34, 37, 50),
            outline=(90, 96, 120), width=2)
d.ellipse([X(-7), Y(-7), X(7), Y(7)], outline=(0, 229, 255), width=3)

# ---------- roads ----------
def road(pts, w_m, col=(50, 54, 68), edge=(96, 102, 122), dash=None):
    wp = [P(p) for p in pts]
    d.line(wp, fill=edge, width=int((w_m + 1.6) * S))
    d.line(wp, fill=col, width=int(w_m * S))
    if dash:
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            n = int(math.hypot(b[0] - a[0], b[1] - a[1]) / 9)
            for k in range(n):
                t0 = k / max(n, 1)
                t1 = t0 + 0.45 / max(n, 1)
                p0 = (a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0)
                p1 = (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)
                d.line([P(p0), P(p1)], fill=dash, width=3)

# ring road (rounded rect r=55, half=160)
ring = []
for cx, cz, a0 in ((105, -105, 180), (105, 105, 270), (-105, 105, 0), (-105, -105, 90)):
    for k in range(9):
        ang = math.radians(a0 + k * 11.25)
        ring.append((cx + 55 * math.cos(ang), cz + 55 * math.sin(ang)))
ring.append(ring[0])
road(ring, 14, dash=(150, 156, 176))

road([(-225, 198), (-120, 110), (-52, 55)], 18, dash=(200, 170, 60))       # Ave A SW
road([(52, -55), (105, -92), (152, -124)], 18, dash=(200, 170, 60))        # Ave A NE
road([(-225, -118), (-120, -62), (-58, -30)], 14, dash=(150, 156, 176))    # Ave B NW
road([(58, 32), (130, 78), (225, 138)], 14, dash=(150, 156, 176))          # Ave B SE
road([(0, 34), (0, 120), (0, 164)], 16, dash=(200, 170, 60))               # N-S main
road([(0, 190), (0, 225)], 16)
road([(-225, -105), (-120, -102), (-58, -102)], 12)                       # H1 west
road([(64, -106), (118, -100)], 12)                                        # H1 east
road([(-225, 60), (-120, 66), (-40, 60)], 10)                              # S2
road([(120, -100), (126, 20), (118, 120), (122, 164)], 11)                 # E street
road([(122, 190), (120, 225)], 11)
road([(-150, -160), (-146, -40), (-152, 80), (-146, 164)], 11)            # W street
road([(-144, 190), (-142, 225)], 11)
road([(105, -92), (155, -88), (138, -128), (188, -138), (172, -182), (196, -205)],
     9, col=(56, 56, 70))                                                  # hill switchbacks
# bridges over canal (short road stubs across the water)
for bx, bz in ((-146, 176), (0, 177), (121, 177)):
    d.line([P((bx, bz - 13)), P((bx, bz + 13))], fill=(50, 54, 68), width=int(11 * S))
    d.line([P((bx, bz - 13)), P((bx, bz + 13))], fill=(120, 126, 148), width=3)
# market street (pedestrian)
road([(-115, 138), (120, 138)], 9, col=(84, 66, 44), edge=(120, 96, 58))
for sx in range(-105, 115, 15):   # stall dots
    d.ellipse([X(sx - 2), Y(134), X(sx + 2), Y(138)], fill=(255, 120, 160))
    d.ellipse([X(sx - 2), Y(140), X(sx + 2), Y(144)], fill=(0, 229, 255))
# alleys (thin pale lines) in 3 superblocks
alley_col = (110, 116, 134)
for a, b in [((-128, 20), (-96, 24)), ((-112, 8), (-110, 44)),
             ((66, 84), (98, 80)), ((84, 66), (86, 104)),
             ((-196, -30), (-168, -26)), ((-182, -46), (-180, -12))]:
    d.line([P(a), P(b)], fill=alley_col, width=4)

# ---------- elevated expressway ----------
deck = [(-225, -58), (-130, -72), (-30, -60), (70, -78), (160, -88), (225, -96)]
d.line([P((x, z + 3)) for (x, z) in deck], fill=(0, 0, 0, 90), width=int(11 * S))
d.line([P(p) for p in deck], fill=(66, 72, 92), width=int(11 * S))
d.line([P(p) for p in deck], fill=(0, 229, 255), width=2)
for i in range(len(deck) - 1):
    a, b = deck[i], deck[i + 1]
    n = int(math.hypot(b[0] - a[0], b[1] - a[1]) / 34)
    for k in range(n + 1):
        t = k / max(n, 1)
        px, pz = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        d.ellipse([X(px - 1.6), Y(pz - 1.6), X(px + 1.6), Y(pz + 1.6)],
                  fill=(150, 156, 176))

# ---------- hero buildings ----------
# megabuilding (north of plaza, spawn-facing landmark)
d.rectangle([X(-52), Y(-128), X(52), Y(-72)], fill=(30, 30, 40),
            outline=(252, 238, 10), width=4)
# arch building across Ave A (SW)
d.rectangle([X(-112), Y(64), X(-66), Y(102)], fill=(30, 38, 46),
            outline=(0, 229, 255), width=4)
d.line([P((-120, 110)), P((-52, 55))], fill=(200, 170, 60), width=3)  # dashes under arch
# cylinder tower (E of plaza)
d.ellipse([X(81), Y(41), X(109), Y(69)], fill=(36, 30, 42),
          outline=(255, 46, 136), width=4)
# hilltop lookout
d.ellipse([X(188), Y(-213), X(204), Y(-197)], outline=(0, 229, 255), width=3)

# ---------- POI markers ----------
def marker(wx, wz, num, col=(252, 238, 10)):
    cx, cy = X(wx), Y(wz)
    r = 17
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(10, 12, 18),
              outline=col, width=3)
    d.text((cx, cy), str(num), font=F(24), fill=col, anchor="mm")

marker(0, -100, 1)       # megabuilding
marker(-89, 83, 2)       # arch
marker(95, 55, 3)        # cylinder
marker(196, -205, 4)     # hilltop
marker(0, 138, 5)        # market street
marker(-60, 168, 6)      # canal promenade
# JOB kiosks (small yellow squares)
for kx, kz in ((24, -24), (-60, 130), (-8, 156), (150, -116), (-172, 42)):
    d.rectangle([X(kx - 2.2), Y(kz - 2.2), X(kx + 2.2), Y(kz + 2.2)],
                fill=(252, 238, 10))
# clinic (white cross E of plaza)
cx, cy = X(46), Y(16)
d.rectangle([cx - 5, cy - 15, cx + 5, cy + 15], fill=(240, 244, 250))
d.rectangle([cx - 15, cy - 5, cx + 15, cy + 5], fill=(240, 244, 250))
# spawn star (south of plaza)
sx, sy = X(0), Y(48)
d.polygon([(sx, sy - 16), (sx + 5, sy - 5), (sx + 16, sy), (sx + 5, sy + 5),
           (sx, sy + 16), (sx - 5, sy + 5), (sx - 16, sy), (sx - 5, sy - 5)],
          fill=(252, 238, 10))

# ---------- labels ----------
def label(wx, wz, text, sz=30, col=(225, 230, 245), anchor="mm", alpha=235):
    d.text((X(wx), Y(wz)), text, font=F(sz), fill=col + (alpha,), anchor=anchor)

label(0, 0, "中央広場", 26, (160, 200, 220))
label(0, -142, "メガビル", 28, (252, 238, 10))
label(-128, 96, "アーチビル", 26, (0, 229, 255))
label(132, 50, "円筒タワー", 24, (255, 120, 180))
label(150, -168, "霧坂ヒルズ", 40, (200, 195, 235))
label(84, -150, "+6m", 22, (190, 190, 215))
label(150, -126, "+12m", 22, (190, 190, 215))
label(186, -164, "+18m", 22, (190, 190, 215))
label(172, 26, "コーポ東", 36, (170, 215, 235))
label(-176, -136, "錆浜工業区", 36, (230, 210, 160))
label(-168, 208, "運河", 30, (120, 190, 235))
label(52, 128, "市場通り", 26, (255, 190, 120))
label(-152, -98, "環太平洋大通り", 24, (200, 205, 220))
label(-168, 128, "霧渚大通り", 24, (230, 210, 140))
label(0, -176, "中央環状路", 24, (200, 205, 220))
label(-102, -44, "高架スカイウェイ（標高10m）", 24, (150, 230, 245))
label(0, 66, "スポーン", 22, (252, 238, 10))
label(66, 16, "クリニック", 22, (240, 244, 250))
label(196, -186, "ヒルトップ広場", 22, (160, 230, 245))

# ---------- frame, north arrow, scale ----------
d.rectangle([2, 2, MAPW - 3, H - 3], outline=(90, 96, 120), width=3)
ax, ay = MAPW - 70, 66
d.polygon([(ax, ay - 34), (ax + 13, ay + 16), (ax, ay + 4), (ax - 13, ay + 16)],
          fill=(225, 230, 245))
d.text((ax, ay + 44), "N", font=F(28), fill=(225, 230, 245), anchor="mm")
bx, by = 60, H - 64
d.rectangle([bx, by, bx + 100 * S, by + 10], outline=(225, 230, 245), width=2)
d.rectangle([bx, by, bx + 50 * S, by + 10], fill=(225, 230, 245))
d.text((bx + 50 * S, by - 16), "100m", font=F(24), fill=(225, 230, 245), anchor="mm")

# ---------- legend panel ----------
px0 = MAPW + 28
d.rectangle([MAPW + 8, 8, W - 8, H - 8], outline=(90, 96, 120), width=2)
ty = 44
def prow(text, sz=27, col=(225, 230, 245), dy=44, bold=False):
    global ty
    d.text((px0, ty), text, font=F(sz), fill=col)
    ty += dy

prow("NEON CITY 2099 v4", 40, (0, 229, 255), 52)
prow("地図案（Phase 0）", 40, (252, 238, 10), 74)
prow("市街：450 × 450 m（密度重視）", 27, (225, 230, 245), 40)
prow("現行660m比で面積46%に凝縮", 27, (225, 230, 245), 40)
prow("＝街路の密度は約2.2倍", 27, (225, 230, 245), 78)

prow("■ 目玉の建物", 29, (0, 229, 255), 46)
prow("1 メガビル（段々＋中庭）", 26, dy=38)
prow("2 アーチビル（大通りを跨ぐ）", 26, dy=38)
prow("3 円筒タワー（リングバルコニー）", 26, dy=38)
prow("4 ヒルトップ広場（展望）", 26, dy=64)

prow("■ 歩く場所", 29, (0, 229, 255), 46)
prow("5 市場通り（歩行者専用・屋台）", 26, dy=38)
prow("6 運河プロムナード（水位-2m）", 26, dy=38)
prow("・路地3か所（幅3.5m）", 26, dy=38)
prow("・中央広場 68×68m", 26, dy=64)

prow("■ 数字", 29, (0, 229, 255), 46)
prow("建物 約150棟（現行と同数を凝縮）", 26, dy=38)
prow("道路幅 3.5m（路地）〜18m（大通り）", 26, dy=38)
prow("高低差 -2m（運河）〜 +18m（丘）", 26, dy=38)
prow("黄色い小四角 = JOBキオスク×5", 26, dy=64)

prow("■ 確認してほしい点", 29, (252, 238, 10), 46)
prow("① 地区の配置（丘=北東／運河=南）", 26, dy=38)
prow("② 市場通りと広場の位置", 26, dy=38)
prow("③ 目玉建物3つの置き場所", 26, dy=38)
prow("④ この密度感で進めてよいか", 26, dy=64)
prow("OKなら次はPhase 1：", 27, (0, 229, 255), 40)
prow("この地図どおりBlenderで", 26, dy=38)
prow("地形を一体成形する", 26, dy=38)

img.save("/home/hatch/workspace/godot_neon/design/v4_map.png")
print("saved", img.size)
