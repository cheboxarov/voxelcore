#!/usr/bin/env python3
import math
import os
import sys
import zlib

sys.path.insert(0, os.path.dirname(__file__))
from blocks import board, nail, panel, put, shingles  # noqa: E402
from common import BLOCKS, CLEAR, MODELS, PAL, Canvas, alpha, hexc, mix, ramp  # noqa: E402


TEX = {}


def tex(name, w=32, h=None):
    def reg(fn):
        TEX["decor_" + name] = (fn, w, h or w)
        return fn
    return reg


STEEL, IRON, DARK = PAL["steel"], PAL["iron"], ramp("2a2c30")
WHITE = ramp("f0f0ea")


def streaks(c, t, n, vertical=True, length=(4, 12)):
    for _ in range(n):
        x, y, k = c.r.randrange(c.w), c.r.randrange(c.h), c.r.randrange(*length)
        tone = t[1] if c.r.random() < 0.6 else t[3]
        for i in range(k):
            c.set(x, (y + i) % c.h, tone) if vertical else c.set((x + i) % c.w, y, tone)


def chips(c, t, n, under=None):
    for _ in range(n):
        x, y = c.r.randrange(c.w), c.r.randrange(c.h)
        c.set(x, y, (under or PAL["rust"])[c.r.choice((1, 2))])
        if c.r.random() < 0.5:
            c.set((x + 1) % c.w, y, t[1])


def letters(c, word, x0, y0, col, glyphs):
    for ch in word:
        for dy, row in enumerate(glyphs[ch]):
            for dx, bit in enumerate(row):
                if bit == "1":
                    c.set(x0 + dx, y0 + dy, col)
        x0 += len(glyphs[ch][0]) + 1


GLYPHS = {"S": ("0111", "1000", "0110", "0001", "1110"), "T": ("111", "010", "010", "010", "010"),
          "O": ("0110", "1001", "1001", "1001", "0110"), "P": ("1110", "1001", "1110", "1000", "1000"),
          "4": ("1001", "1001", "1111", "0001", "0001"), "0": ("0110", "1001", "1001", "1001", "0110")}


@tex("metal")
def metal(c):
    c.rect(0, 0, 31, 31, IRON[2])
    for x in range(32):
        tone = IRON[3] if x % 8 in (1, 2) else IRON[1] if x % 8 == 6 else IRON[2]
        for y in range(32):
            c.set(x, y, tone)
    streaks(c, IRON, 30)
    c.noise(0.03)


@tex("metal_red")
def metal_red(c):
    t = ramp("b8402e")
    for x in range(32):
        tone = t[3] if x % 8 in (1, 2) else t[1] if x % 8 == 6 else t[2]
        for y in range(32):
            c.set(x, y, tone)
    chips(c, t, 14, IRON)
    c.noise(0.03)


@tex("rubber")
def rubber(c):
    t = ramp("2a2a2e")
    for y in range(32):
        for x in range(32):
            c.set(x, y, t[1] if (x + y) % 8 in (0, 1) else t[2] if (x - y) % 8 else t[0])
    c.paint(c.ellipse_m(16, 16, 7, 7), STEEL)
    c.fill(c.ellipse_m(16, 16, 2.5, 2.5), IRON[0])
    c.noise(0.04)


def light(on):
    def draw(c):
        panel(c, 0, 0, 31, 31, IRON)
        lens = ramp("fff4c8") if on else ramp("8c8a80")
        c.paint(c.rect_m(10, 8, 21, 23), lens, grad=not on)
        if on:
            c.fill(c.rect_m(12, 10, 19, 21), lens[4])
            c.fill(c.rect_m(14, 12, 16, 15), (255, 255, 250, 255))
        else:
            c.line(11, 10, 14, 10, lens[4])
        c.frame(9, 7, 22, 24, IRON[0])
    return draw


tex("light_on")(light(True))
tex("light_off")(light(False))


def traffic(lit):
    def draw(c):
        body = ramp("34383a")
        c.rect(0, 0, 31, 31, body[1])
        panel(c, 10, 2, 21, 29, body)
        for i, col in enumerate(("ff3020", "ffb020", "40e060")):
            cy = 7.5 + i * 8.5
            t = ramp(col) if lit == i else ramp(mix(hexc(col), hexc("202020"), 0.72))
            c.fill(c.rect_m(11, int(cy) - 4, 20, int(cy) - 3), body[0])
            c.paint(c.ellipse_m(16, cy, 3.4, 3.4), t, grad=lit != i)
            if lit == i:
                c.fill(c.ellipse_m(16, cy, 2, 2), t[4])
            c.set(14, int(cy) - 2, t[4])
    return draw


tex("traffic_on")(traffic(0))
tex("traffic_off")(traffic(-1))


@tex("sign_stop")
def sign_stop(c):
    red = ramp("c8261e")
    oct_ = [(10, 5), (21, 5), (27, 11), (27, 21), (21, 27), (10, 27), (4, 21), (4, 11)]
    c.fill(c.poly_m(oct_), WHITE[3])
    inner = [(x + (1 if x < 16 else -1), y + (1 if y < 16 else -1)) for x, y in oct_]
    c.paint(c.poly_m(inner), red, grad=False)
    letters(c, "STOP", 8, 14, WHITE[3], GLYPHS)


@tex("sign_speed")
def sign_speed(c):
    c.fill(c.ellipse_m(16, 16, 11, 11), WHITE[3])
    c.paint(c.ellipse_m(16, 16, 10.5, 10.5), ramp("d02a22"), grad=False)
    c.fill(c.ellipse_m(16, 16, 7.5, 7.5), WHITE[3])
    letters(c, "40", 12, 14, DARK[1], GLYPHS)


@tex("sign_crossing")
def sign_crossing(c):
    blue = ramp("2a5ab0")
    panel(c, 3, 5, 28, 26, blue)
    c.frame(4, 6, 27, 25, WHITE[3])
    c.poly([(16, 8), (26, 24), (6, 24)], WHITE[3])
    ink = DARK[1]
    c.rect(15, 12, 16, 13, ink)
    c.line(15, 14, 14, 18, ink)
    c.line(14, 18, 12, 22, ink)
    c.line(14, 18, 17, 22, ink)
    c.line(15, 15, 18, 17, ink)
    c.line(15, 15, 12, 17, ink)
    for x in range(9, 24, 3):
        c.set(x, 23, ink)


@tex("sign_back")
def sign_back(c):
    metal(c)
    c.frame(3, 4, 28, 27, IRON[1])
    for x, y in ((16, 9), (16, 22)):
        nail(c, x, y, STEEL)


@tex("hydrant")
def hydrant(c):
    t = ramp("c8301e")
    for x in range(32):
        tone = t[3] if 11 <= x <= 13 else t[4] if x == 12 else t[1] if x >= 19 else t[2]
        for y in range(32):
            c.set(x, y, tone)
    for y in (6, 25):
        for x in range(32):
            c.set(x, y, mix(c.get(x, y), t[0], 0.5))
    chips(c, t, 8)
    for x, y in ((8, 15), (23, 15)):
        nail(c, x, y, PAL["brass"])


@tex("bench")
def bench(c):
    t = ramp("8a5a30")
    for y0 in range(1, 32, 6):
        board(c, -3, y0, 34, y0 + 4, t, knots=False)
        c.line(0, y0 - 1, 31, y0 - 1, ramp("4e3018")[1])
    c.noise(0.03)


@tex("trash")
def trash(c):
    t = ramp("3a5a3a")
    for x in range(32):
        tone = (t[3], t[2], t[2], t[1])[x % 4]
        for y in range(32):
            c.set(x, y, tone)
    for y in (3, 28):
        c.line(0, y, 31, y, t[0])
        c.line(0, y + 1, 31, y + 1, t[3])
    chips(c, t, 10)


@tex("trash_top")
def trash_top(c):
    t = ramp("2e4a2e")
    panel(c, 0, 0, 31, 31, t)
    c.paint(c.ellipse_m(16, 16, 9, 9), t)
    c.fill(c.ellipse_m(16, 16, 6, 6), DARK[0])
    c.line(12, 13, 15, 12, DARK[2])


@tex("mailbox")
def mailbox(c):
    t = ramp("2a4a9a")
    for y in range(32):
        tone = t[3] if y < 12 else t[4] if y == 12 else t[1] if y > 26 else t[2]
        for x in range(32):
            c.set(x, y, tone)
    c.line(0, 18, 31, 18, WHITE[2])
    chips(c, t, 6)


@tex("mailbox_front")
def mailbox_front(c):
    mailbox(c)
    t = ramp("2a4a9a")
    panel(c, 11, 11, 20, 20, t)
    c.rect(14, 15, 17, 16, STEEL[3])
    c.set(17, 16, STEEL[0])
    c.rect(20, 9, 21, 15, ramp("d02a22")[2])
    c.set(20, 9, ramp("d02a22")[4])


@tex("dumpster")
def dumpster(c):
    t = ramp("2e5a46")
    for x in range(32):
        tone = t[3] if x % 8 == 1 else t[1] if x % 8 == 6 else t[2]
        for y in range(32):
            c.set(x, y, tone)
    c.rect(0, 0, 31, 3, t[1])
    c.line(0, 3, 31, 3, t[0])
    chips(c, t, 30)
    for _ in range(4):
        x = c.r.randrange(32)
        for y in range(4, 4 + c.r.randrange(4, 14)):
            c.set(x, y, PAL["rust"][1])
    c.paint(c.rect_m(12, 10, 19, 14), ramp("e8e8e0"), grad=False)


@tex("glass")
def glass(c):
    c.rect(0, 0, 31, 31, alpha(PAL["glass"][2], 90))
    c.frame(0, 0, 31, 31, IRON[1])
    c.frame(1, 1, 30, 30, IRON[3])
    for d in (0, 5):
        c.line(5 + d, 26, 18 + d, 13, alpha(PAL["glass"][4], 140))
    c.line(20, 8, 24, 4, alpha(PAL["glass"][4], 140))


@tex("bus_sign")
def bus_sign(c):
    blue = ramp("1e4a8a")
    c.rect(0, 0, 31, 31, blue[2])
    panel(c, 0, 10, 31, 21, blue)
    c.paint(c.rect_m(9, 12, 22, 18), WHITE)
    c.fill(c.rect_m(10, 13, 21, 15), blue[2])
    c.line(15, 13, 15, 15, WHITE[3])
    c.rect(10, 19, 11, 20, DARK[1])
    c.rect(20, 19, 21, 20, DARK[1])


@tex("fence")
def fence(c):
    t = ramp("e8e4d8")
    for x0 in range(0, 32, 8):
        board(c, x0, 0, x0 + 7, 31, t, vertical=True, knots=False)
    for x in range(32):
        for y in range(27, 32):
            c.set(x, y, mix(c.get(x, y), ramp("8a7a5a")[2], 0.15 * (y - 26)))


def leaves(c, t, n, r=(2.2, 3.4)):
    for _ in range(n):
        x, y, rr = c.r.uniform(0, 32), c.r.uniform(0, 32), c.r.uniform(*r)
        m = {(px % 32, py % 32) for px, py in c.ellipse_m(x, y, rr, rr * 0.8)}
        c.paint(m, t, grad=False)


@tex("hedge")
def hedge(c):
    t = ramp("3a6a2e")
    c.rect(0, 0, 31, 31, t[0])
    leaves(c, t, 90)
    for _ in range(30):
        c.set(c.r.randrange(32), c.r.randrange(32), t[4])


@tex("soil")
def soil(c):
    t = ramp("4a3020")
    c.rect(0, 0, 31, 31, t[2])
    for _ in range(40):
        x, y = c.r.randrange(32), c.r.randrange(32)
        c.set(x, y, t[3])
        put(c, x + 1, y, t[3])
        put(c, x, y + 1, t[1])
        put(c, x + 1, y + 1, t[0])
    for _ in range(60):
        c.set(c.r.randrange(32), c.r.randrange(32), t[1])
    for _ in range(6):
        x, y = c.r.randrange(32), c.r.randrange(32)
        c.set(x, y, PAL["grass"][3])
    c.noise(0.04)


@tex("gravel")
def gravel(c):
    t = ramp("a49a86")
    c.rect(0, 0, 31, 31, t[1])
    for _ in range(110):
        x, y = c.r.randrange(32), c.r.randrange(32)
        s = ramp(mix(t[2], hexc(c.r.choice(("8a8478", "b0a690", "7a7262", "c8bea8"))), 0.6))
        put(c, x, y, s[3])
        put(c, x + 1, y, s[2])
        put(c, x, y + 1, s[2])
        put(c, x + 1, y + 1, s[0])
    c.noise(0.03)


@tex("concrete")
def concrete(c):
    t = ramp("8e8c88")
    c.rect(0, 0, 31, 31, t[2])
    for _ in range(90):
        c.set(c.r.randrange(32), c.r.randrange(32), t[1] if c.r.random() < 0.6 else t[3])
    for _ in range(8):
        c.set(c.r.randrange(32), c.r.randrange(32), t[0])
    c.line(0, 15, 31, 15, mix(t[2], t[1], 0.6))
    c.line(0, 31, 31, 31, t[1])
    c.line(31, 0, 31, 31, t[1])
    c.noise(0.03)


@tex("slide")
def slide(c):
    t = ramp("e0b020")
    for x in range(32):
        tone = t[3] if 6 <= x <= 9 else t[4] if x == 7 else t[1] if x >= 26 else t[2]
        for y in range(32):
            c.set(x, y, tone)
    streaks(c, t, 6, length=(6, 16))
    c.noise(0.02)


def car_paint(col, stripe=None):
    def draw(c):
        t = ramp(col)
        for y in range(32):
            tone = t[3] if y < 4 else t[1] if y > 27 else t[2]
            for x in range(32):
                c.set(x, y, tone)
        if stripe:
            c.paint(c.rect_m(0, 13, 31, 18), ramp(stripe), grad=False)
        c.line(3, 22, 14, 24, t[0])
        c.line(4, 23, 13, 25, t[3])
        chips(c, t, 14)
        c.noise(0.03)
    return draw


for _n, _col, _stripe in (("red", "9a2a22", None), ("blue", "2a4a8a", None), ("white", "c8c8c0", None),
                          ("police", "e0e0dc", "1a3a9a"), ("army", "4e5a32", None)):
    tex("paint_" + _n)(car_paint(_col, _stripe))


@tex("burnt")
def burnt(c):
    t = ramp("2a2624")
    c.rect(0, 0, 31, 31, t[1])
    for _ in range(60):
        x, y = c.r.randrange(32), c.r.randrange(32)
        c.set(x, y, PAL["rust"][c.r.choice((1, 2, 3))])
    for _ in range(50):
        c.set(c.r.randrange(32), c.r.randrange(32), t[c.r.choice((0, 2, 3))])
    for y in range(0, 32, 8):
        c.line(0, y, 31, y, t[0])
    c.noise(0.05)


@tex("broken_glass")
def broken_glass(c):
    g = ramp("3a4a56")
    c.rect(0, 0, 31, 31, g[2])
    c.line(0, 31, 31, 0, g[3])
    for a, b in (((16, 15), (4, 2)), ((16, 15), (29, 9)), ((16, 15), (11, 31)), ((16, 15), (31, 24)), ((16, 15), (0, 18))):
        c.line(a[0], a[1], b[0], b[1], ramp("b0c8d8")[3])
    c.paint(c.ellipse_m(17, 16, 3, 3), DARK)
    c.line(4, 8, 8, 4, g[4])


def bus_base(c):
    t = ramp("e0a81e")
    for y in range(32):
        tone = t[3] if y < 2 else t[1] if y > 29 else t[2]
        for x in range(32):
            c.set(x, y, tone)
    return t


@tex("bus_side")
def bus_side(c):
    t = bus_base(c)
    for x0 in (2, 18):
        panel(c, x0, 5, x0 + 12, 15, ramp("2a3a46"), sunk=True)
        c.line(x0 + 2, 13, x0 + 6, 7, ramp("2a3a46")[4])
    c.rect(0, 20, 31, 21, DARK[1])
    c.rect(0, 25, 31, 25, DARK[1])
    chips(c, t, 10)


@tex("bus_roof")
def bus_roof(c):
    t = ramp("d8d4c8")
    for x in range(32):
        tone = t[3] if x % 16 == 1 else t[1] if x % 16 == 14 else t[2]
        for y in range(32):
            c.set(x, y, tone)
    chips(c, t, 12)
    c.paint(c.rect_m(10, 10, 21, 21), ramp("8a8478"))


@tex("bus_under")
def bus_under(c):
    t = ramp("2e2e2e")
    c.rect(0, 0, 31, 31, t[2])
    c.paint(c.rect_m(0, 12, 31, 19), IRON, grad=False)
    for x in range(0, 32, 8):
        c.paint(c.rect_m(x, 4, x + 1, 27), t, grad=False)
    chips(c, t, 30)


@tex("bus_front")
def bus_front(c):
    t = bus_base(c)
    panel(c, 2, 3, 29, 15, ramp("2a3a46"), sunk=True)
    c.line(5, 13, 11, 6, ramp("b0c8d8")[3])
    c.line(15, 3, 15, 15, DARK[1])
    for x0 in (2, 25):
        c.paint(c.rect_m(x0, 20, x0 + 4, 23), ramp("f0f0c0"))
    c.rect(9, 20, 22, 23, DARK[2])
    for x in range(10, 22, 2):
        c.line(x, 21, x, 22, DARK[0])
    c.rect(0, 27, 31, 29, STEEL[1])


@tex("heli")
def heli(c):
    t = ramp("4a5432")
    c.rect(0, 0, 31, 31, t[2])
    for y in (0, 16):
        c.line(0, y, 31, y, t[0])
        c.line(0, y + 1, 31, y + 1, t[3])
    c.line(15, 0, 15, 31, t[0])
    for x in range(3, 32, 6):
        for y in (3, 19):
            c.set(x, y, t[3])
    star = [(16, 5), (18, 10), (23, 10), (19, 13), (21, 18), (16, 15), (11, 18), (13, 13), (9, 10), (14, 10)]
    c.paint(c.poly_m(star), ramp("e8e8e0"), grad=False)
    chips(c, t, 16)


@tex("barrier")
def barrier(c):
    o, w = ramp("e86a1a"), WHITE
    for y in range(32):
        for x in range(32):
            k = (x + y) % 16
            c.set(x, y, (o if k < 8 else w)[3 if k in (0, 8) else 1 if k in (7, 15) else 2])


@tex("tape")
def tape(c):
    y_, k_ = ramp("f0d020"), DARK
    for x in range(32):
        for y in range(14, 18):
            c.set(x, y, y_[3 if y == 14 else 2] if (x + y) % 8 < 4 else k_[2])


@tex("sandbag")
def sandbag(c):
    t = ramp("a08a5e")
    for y in range(32):
        for x in range(32):
            c.set(x, y, t[3] if (x + y) % 3 == 0 else t[1] if (x - y) % 4 == 0 else t[2])
    bag = c.rect_m(8, 11, 23, 20) - {(8, 11), (23, 11), (8, 20), (23, 20)}
    edge = {(x, y) for x, y in bag if not all((x + dx, y + dy) in bag for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
    for x, y in edge:
        c.set(x, y, t[0] if y > 15 or x > 20 else t[4])
    c.line(10, 15, 21, 15, t[1])
    c.noise(0.03)


@tex("army_crate", 28, 22)
def army_crate(c):
    t = ramp("4e5a32")
    for y0 in (0, 7, 14):
        board(c, 0, y0, 27, y0 + 6, t, knots=False)
    c.frame(0, 0, 27, 21, t[0])
    for x0 in (0, 24):
        c.paint(c.rect_m(x0, 0, x0 + 3, 21), ramp("3e4826"), grad=False)
    c.paint(c.rect_m(9, 8, 18, 13), ramp("d8d0a0"), grad=False)
    c.fill(c.rect_m(11, 10, 16, 11), t[1])
    for x, y in ((1, 1), (25, 1), (1, 19), (25, 19)):
        nail(c, x, y)


@tex("tent")
def tent(c):
    t = ramp("4a6a3a")
    for y in range(32):
        tone = t[3] if y % 16 == 1 else t[1] if y % 16 == 14 else t[2]
        for x in range(32):
            c.set(x, y, tone)
    c.line(0, 0, 31, 0, t[0])
    c.line(15, 0, 15, 31, t[1])
    c.line(16, 0, 16, 31, t[3])
    streaks(c, t, 10, vertical=False)
    c.noise(0.02)


@tex("blood")
def blood(c):
    dark, wet = alpha(ramp("6a0a0a")[2], 235), alpha(ramp("7a1010")[3], 220)
    cx, cy = c.r.uniform(12, 20), c.r.uniform(12, 20)
    for y in range(32):
        for x in range(32):
            d = math.hypot(x - cx, y - cy) + c.r.uniform(-2.5, 2.5)
            if d < 7:
                c.set(x, y, dark)
            elif d < 12 and c.r.random() < 0.25:
                c.set(x, y, wet)
    for _ in range(3):
        a = c.r.uniform(0, 2 * math.pi)
        for k in range(8, 16):
            c.set(int(cx + math.cos(a) * k), int(cy + math.sin(a) * k), alpha(ramp("5a0808")[2], 210))
    c.set(int(cx) - 2, int(cy) - 2, alpha(ramp("7a1010")[4], 235))


@tex("litter")
def litter(c):
    paper = ramp("e8e4d8")
    c.paint(c.poly_m([(3, 5), (12, 3), (13, 11), (4, 12)]), paper, grad=False)
    c.line(5, 6, 11, 5, IRON[2])
    c.line(5, 8, 10, 7, IRON[2])
    can = ramp("c83a2a")
    c.paint(c.rect_m(20, 18, 26, 22), can, grad=False)
    c.rect(26, 18, 27, 22, STEEL[2])
    c.paint(c.poly_m([(6, 22), (13, 20), (14, 25), (8, 27)]), ramp("6a8a4a"), grad=False)
    c.rect(24, 5, 25, 6, PAL["brass"][2])
    c.rect(16, 13, 19, 13, ramp("e8e0c8")[3])
    c.set(20, 13, ramp("c87a3a")[2])
    c.set(28, 28, STEEL[3])


@tex("note", 18, 16)
def note(c):
    paper = ramp("f0ead0")
    c.rect(0, 0, 17, 15, paper[2])
    c.line(0, 0, 17, 0, paper[3])
    c.line(17, 0, 17, 15, paper[1])
    c.line(0, 15, 17, 15, paper[1])
    c.line(9, 0, 9, 15, mix(paper[2], paper[1], 0.5))
    for y in range(3, 14, 2):
        x1 = 15 - c.r.randrange(0, 5)
        for x in range(2, x1):
            if c.r.random() < 0.8:
                c.set(x, y, ramp("3a3a6a")[2])
    c.set(15, 2, ramp("c03020")[2])


@tex("firepit", 29)
def firepit(c):
    ash, stone, log = ramp("4a4038"), PAL["stone"], ramp("3a2a1e")
    c.rect(0, 0, 28, 28, ash[1])
    for i in range(14):
        a = i / 14 * 2 * math.pi
        c.paint(c.ellipse_m(14.5 + 11.5 * math.cos(a), 14.5 + 11.5 * math.sin(a), 2.6, 2.4), stone)
    c.fill(c.ellipse_m(14.5, 14.5, 8.5, 8.5), ash[2])
    for a, b in (((8, 9), (21, 19)), ((20, 8), (9, 21))):
        c.paint(c.line_m(a[0], a[1], b[0], b[1], 2), log, grad=False)
    for _ in range(25):
        x, y = c.r.randrange(29), c.r.randrange(29)
        if c.get(x, y) == ash[2]:
            c.set(x, y, ash[3] if c.r.random() < 0.7 else ramp("f08020")[1])


def roof_green(c):
    t = ramp("3e5a44")
    for x in range(32):
        tone = t[4] if x % 8 == 0 else t[3] if x % 8 == 1 else t[0] if x % 8 == 2 else t[1] if x % 8 == 7 else t[2]
        for y in range(c.h):
            c.set(x, y, tone)
    chips(c, t, c.h // 2)
    c.noise(0.02)


tex("roof_green")(roof_green)
tex("roof_green_side", 32, 16)(roof_green)
tex("roof_grey")(lambda c: shingles(c, "5a5e64"))
tex("roof_grey_side", 32, 16)(lambda c: shingles(c, "5a5e64"))


@tex("workbench_top")
def workbench_top(c):
    t = ramp("9a7444")
    for y0 in (0, 8, 16, 24):
        board(c, 0, y0, 31, y0 + 7, t, knots=False)
    c.paint(c.rect_m(2, 3, 9, 6), IRON)
    c.paint(c.rect_m(5, 7, 6, 10), IRON, grad=False)
    c.paint(c.line_m(14, 24, 24, 14, 2), STEEL, grad=False)
    c.paint(c.rect_m(24, 11, 27, 15), ramp("c03030"))
    c.paint(c.line_m(18, 6, 26, 6, 1) | c.line_m(18, 7, 21, 7, 1), ramp("6a4428"), grad=False)
    c.rect(22, 5, 27, 8, STEEL[2])
    for x, y in ((4, 20), (6, 22), (9, 19)):
        c.set(x, y, STEEL[3])


@tex("workbench_side", 32, 29)
def workbench_side(c):
    t = ramp("7a5a34")
    c.rect(0, 0, 31, 28, CLEAR)
    board(c, 0, 0, 31, 4, t, knots=False)
    for x0 in (0, 27):
        board(c, x0, 5, x0 + 4, 28, t, vertical=True, knots=False)
    board(c, 5, 19, 26, 22, t, knots=False)
    panel(c, 7, 7, 24, 13, t)
    c.rect(14, 10, 17, 10, STEEL[3])


@tex("ceramic")
def ceramic(c):
    t = ramp("e8eae8")
    c.rect(0, 0, 31, 31, t[2])
    for y in range(32):
        for x in range(32):
            if 4 <= x + y // 3 <= 7:
                c.set(x, y, t[3])
    c.line(0, 31, 31, 31, t[1])
    c.line(31, 0, 31, 31, t[1])


@tex("desk")
def desk(c):
    t = ramp("6a4a2e")
    for y0 in (0, 8, 16, 24):
        board(c, 0, y0, 31, y0 + 7, t, knots=False)
    c.noise(0.02)


@tex("desk_front")
def desk_front(c):
    t = ramp("6a4a2e")
    c.rect(0, 0, 31, 31, t[1])
    for y0 in (4, 12, 20):
        panel(c, 10, y0, 21, y0 + 6, t)
        c.rect(15, y0 + 3, 16, y0 + 3, PAL["brass"][3])


@tex("toybox", 24, 20)
def toybox(c):
    t = ramp("d06a8a")
    panel(c, 0, 0, 23, 19, t)
    c.frame(0, 0, 23, 19, t[0])
    c.line(0, 5, 23, 5, t[0])
    for x0, y0, col in ((3, 9, "f0d040"), (10, 11, "40a0e0"), (17, 9, "60c060")):
        c.paint(c.rect_m(x0, y0, x0 + 4, y0 + 4), ramp(col))
    c.paint(c.ellipse_m(12, 2.5, 2.5, 1.5), ramp("f0d040"), grad=False)


@tex("bookshelf", 32, 64)
def bookshelf(c):
    w = ramp("4e3420")
    c.rect(0, 0, 31, 63, w[1])
    c.frame(0, 0, 31, 63, w[0])
    c.line(1, 1, 30, 1, w[3])
    c.line(1, 1, 1, 62, w[3])
    for y0 in (3, 18, 33, 48):
        c.rect(2, y0, 29, y0 + 11, DARK[0])
        x = 3
        while x < 28:
            bw, bh = 2 + c.r.randrange(3), 8 + c.r.randrange(4)
            b = ramp(c.r.choice(("8a2a22", "2a4a7a", "3a6a3a", "c8a040", "5a3a6a", "d8d0c0")))
            x1 = min(28, x + bw - 1)
            m = c.rect_m(x, y0 + 12 - bh, x1, y0 + 11)
            c.paint(m, b, grad=False)
            c.line(x, y0 + 12 - bh + 2, x1, y0 + 12 - bh + 2, b[4])
            x += bw + (1 if c.r.random() < 0.2 else 0)
        c.rect(1, y0 + 12, 30, y0 + 14, w[2])
        c.line(1, y0 + 12, 30, y0 + 12, w[3])
        c.line(1, y0 + 14, 30, y0 + 14, w[0])


def _vcm_box(a, b, tex=None, faces=None, rotate=None, origin=None):
    s = "@box from (%g,%g,%g) to (%g,%g,%g)" % (*a, *b)
    if tex:
        s += ' texture "%s"' % tex
    if origin:
        s += " origin (%g,%g,%g)" % origin
    if rotate:
        s += " rotate (%g,%g,%g)" % rotate
    parts = []
    big = any(abs(b[i] - a[i]) > 1.001 for i in range(3))
    for tags, t in (faces or {}).items():
        parts.append('@part tags (%s) texture "%s"%s' % (tags, t, " region (0,0,1,1)" if big else ""))
    if big and not faces:
        parts.append("@part tags (top,bottom,north,south,east,west) region (0,0,1,1)")
    if parts:
        s += " {\n    " + "\n    ".join(parts) + "\n}"
    return s


def _vcm(name, boxes):
    with open(os.path.join(MODELS, name + ".vcm"), "w") as f:
        f.write("\n".join(boxes) + "\n")


def detail_textures():
    for name, (fn, w, h) in TEX.items():
        c = Canvas(w, h, seed=zlib.crc32(name.encode()))
        fn(c)
        c.save(os.path.join(BLOCKS, name + ".png"))


def detail_models():
    B = _vcm_box
    _vcm("zomboid_decor_streetlight", [
        B((0.42, 0, 0.42), (0.58, 0.55, 0.58), "blocks:decor_metal"),
        B((0.45, 0.45, -0.2), (0.55, 0.55, 0.5), "blocks:decor_metal"),
        B((0.3, 0.32, -0.45), (0.7, 0.45, 0.05), "blocks:decor_metal", {"bottom": "$0"}),
    ])
    _vcm("zomboid_decor_traffic_light", [
        B((0.45, 0, 0.45), (0.55, 0.2, 0.55), "blocks:decor_metal"),
        B((0.34, 0.15, 0.38), (0.66, 0.95, 0.62), "blocks:decor_traffic_off", {"north,south": "$0"}),
    ])
    _vcm("zomboid_decor_sign", [
        B((0.46, 0, 0.47), (0.54, 0.5, 0.55), "blocks:decor_metal"),
        B((0.1, 0.25, 0.42), (0.9, 0.95, 0.47), "blocks:decor_sign_back", {"north": "$0"}),
    ])
    _vcm("zomboid_decor_hydrant", [
        B((0.32, 0, 0.32), (0.68, 0.6, 0.68), "blocks:decor_hydrant"),
        B((0.36, 0.6, 0.36), (0.64, 0.74, 0.64), "blocks:decor_hydrant"),
        B((0.2, 0.32, 0.43), (0.8, 0.46, 0.57), "blocks:decor_hydrant"),
    ])
    _vcm("zomboid_decor_bench", [
        B((0, 0.4, 0.15), (1, 0.48, 0.62), "blocks:decor_bench"),
        B((0, 0.55, 0.6), (1, 0.95, 0.68), "blocks:decor_bench"),
        B((0.06, 0, 0.2), (0.14, 0.9, 0.66), "blocks:decor_metal"),
        B((0.86, 0, 0.2), (0.94, 0.9, 0.66), "blocks:decor_metal"),
    ])
    _vcm("zomboid_decor_trash_can", [
        B((0.22, 0, 0.22), (0.78, 0.85, 0.78), "blocks:decor_trash"),
        B((0.18, 0.85, 0.18), (0.82, 0.92, 0.82), "blocks:decor_trash_top"),
    ])
    _vcm("zomboid_decor_mailbox", [
        B((0.45, 0, 0.45), (0.55, 0.72, 0.55), "blocks:decor_bench"),
        B((0.32, 0.72, 0.22), (0.68, 1.0, 0.82), "blocks:decor_mailbox", {"north": "blocks:decor_mailbox_front"}),
    ])
    _vcm("zomboid_decor_dumpster", [
        B((0.05, 0.12, 0.05), (1.95, 1.25, 0.95), "blocks:decor_dumpster"),
        B((0, 1.25, 0), (2, 1.36, 1), "blocks:decor_dumpster", rotate=(-4, 0, 0)),
        B((0.15, 0, 0.15), (0.35, 0.14, 0.35), "blocks:decor_rubber"),
        B((1.65, 0, 0.65), (1.85, 0.14, 0.85), "blocks:decor_rubber"),
        B((0.15, 0, 0.65), (0.35, 0.14, 0.85), "blocks:decor_rubber"),
        B((1.65, 0, 0.15), (1.85, 0.14, 0.35), "blocks:decor_rubber"),
    ])
    _vcm("zomboid_decor_bus_stop", [
        B((0, 0, 0.86), (3, 2.3, 0.94), "blocks:decor_glass"),
        B((0, 0, 0.1), (0.08, 2.3, 0.86), "blocks:decor_glass"),
        B((2.92, 0, 0.1), (3, 2.3, 0.86), "blocks:decor_glass"),
        B((-0.05, 2.3, 0), (3.05, 2.42, 1), "blocks:decor_metal"),
        B((0.3, 0.42, 0.5), (2.7, 0.5, 0.84), "blocks:decor_bench"),
        B((1.0, 2.42, 0.02), (2.0, 2.8, 0.08), "blocks:decor_bus_sign"),
    ])
    pickets = [B((x, 0, 0.45), (x + 0.12, 1.0, 0.55), "blocks:decor_fence") for x in (0.04, 0.29, 0.54, 0.79)]
    _vcm("zomboid_decor_fence", pickets + [
        B((0, 0.25, 0.4), (1, 0.35, 0.45), "blocks:decor_fence"),
        B((0, 0.7, 0.4), (1, 0.8, 0.45), "blocks:decor_fence"),
    ])
    _vcm("zomboid_decor_swing", [
        B((0.05, 0, 0.08), (0.17, 2.45, 0.2), "blocks:decor_metal_red"),
        B((0.05, 0, 0.8), (0.17, 2.45, 0.92), "blocks:decor_metal_red"),
        B((2.83, 0, 0.08), (2.95, 2.45, 0.2), "blocks:decor_metal_red"),
        B((2.83, 0, 0.8), (2.95, 2.45, 0.92), "blocks:decor_metal_red"),
        B((0.02, 2.33, 0.08), (0.2, 2.47, 0.92), "blocks:decor_metal_red"),
        B((2.8, 2.33, 0.08), (2.98, 2.47, 0.92), "blocks:decor_metal_red"),
        B((0, 2.35, 0.44), (3, 2.47, 0.56), "blocks:decor_metal_red"),
    ] + [B((x, 0.98, 0.49), (x + 0.03, 2.35, 0.52), "blocks:decor_metal") for x in (0.62, 1.05, 1.95, 2.38)]
      + [B((x, 0.92, 0.36), (x + 0.5, 0.99, 0.64), "blocks:decor_rubber") for x in (0.6, 1.92)])
    ramp_len = math.hypot(2.2, 1.7)
    _vcm("zomboid_decor_slide", [
        B((0.1, 1.7, 2.2), (0.9, 1.8, 2.95), "blocks:decor_metal"),
        B((0.12, 0, 2.85), (0.2, 2.4, 2.95), "blocks:decor_metal"),
        B((0.8, 0, 2.85), (0.88, 2.4, 2.95), "blocks:decor_metal"),
        B((0.12, 0, 2.2), (0.2, 1.7, 2.3), "blocks:decor_metal"),
        B((0.8, 0, 2.2), (0.88, 1.7, 2.3), "blocks:decor_metal"),
    ] + [B((0.2, y, 2.87), (0.8, y + 0.06, 2.93), "blocks:decor_metal") for y in (0.4, 0.85, 1.3)] + [
        B((0.18, 0, 0), (0.82, 0.06, ramp_len), "blocks:decor_slide", origin=(0.5, 0, 0), rotate=(-37.7, 0, 0)),
        B((0.14, 0, 0), (0.2, 0.2, ramp_len), "blocks:decor_slide", origin=(0.5, 0, 0), rotate=(-37.7, 0, 0)),
        B((0.8, 0, 0), (0.86, 0.2, ramp_len), "blocks:decor_slide", origin=(0.5, 0, 0), rotate=(-37.7, 0, 0)),
    ])
    bus = []
    for k in range(9):
        bus.append(B((0.1, 0.05, k), (2.9, 2.5, k + 1), None,
                     {"top": "blocks:decor_bus_side", "bottom": "blocks:decor_bus_under",
                      "east": "blocks:decor_bus_roof", "west": "blocks:decor_bus_under",
                      "north": "blocks:decor_bus_front", "south": "blocks:decor_bus_front"}))
    bus += [B((0, 0.3, z), (0.12, 1.0, z + 0.7), "blocks:decor_rubber") for z in (1.2, 6.8)]
    bus += [B((0, 1.5, z), (0.12, 2.2, z + 0.7), "blocks:decor_rubber") for z in (1.2, 6.8)]
    _vcm("zomboid_decor_bus_wreck", bus)
    _vcm("zomboid_decor_heli_wreck", [
        B((1.0, 0.0, 1.2), (3.6, 2.0, 4.4), "blocks:decor_heli", rotate=(0, 0, -14)),
        B((1.3, 0.2, 0.3), (3.3, 1.8, 1.25), "blocks:decor_broken_glass", {"top": "blocks:decor_heli"}, rotate=(0, 0, -14)),
        B((2.0, 1.0, 4.3), (2.6, 1.5, 6.9), "blocks:decor_heli", rotate=(4, 6, -10)),
        B((2.2, 1.4, 6.3), (2.4, 2.4, 6.9), "blocks:decor_heli", rotate=(0, 6, -10)),
        B((0.6, 0.0, 1.0), (0.8, 0.12, 4.6), "blocks:decor_metal", rotate=(0, 0, -8)),
        B((3.5, 0.0, 1.0), (3.7, 0.12, 4.6), "blocks:decor_metal", rotate=(0, 0, 10)),
        B((0.2, 0.02, 5.2), (4.8, 0.1, 5.45), "blocks:decor_burnt", rotate=(0, 28, 0)),
        B((0.4, 0.02, 0.2), (3.0, 0.1, 0.45), "blocks:decor_burnt", rotate=(0, -12, 0)),
        B((2.25, 2.0, 2.6), (2.55, 2.4, 2.9), "blocks:decor_metal", rotate=(0, 0, -14)),
    ])
    _vcm("zomboid_decor_police_barrier", [
        B((0, 0.72, 0.42), (1, 0.92, 0.5), "blocks:decor_barrier"),
        B((0, 0.32, 0.42), (1, 0.44, 0.5), "blocks:decor_barrier"),
    ] + [B((x, 0, 0.3), (x + 0.07, 0.92, 0.37), "blocks:decor_metal", rotate=(-12, 0, 0)) for x in (0.06, 0.87)]
      + [B((x, 0, 0.55), (x + 0.07, 0.92, 0.62), "blocks:decor_metal", rotate=(12, 0, 0)) for x in (0.06, 0.87)])
    _vcm("zomboid_decor_tape", [B((0, 0.88, 0.49), (1, 0.98, 0.51), "blocks:decor_tape")])
    bags = []
    for row, (y, off) in enumerate(((0, 0.0), (0.3, 0.25), (0.6, 0.0))):
        x = -off
        while x < 1:
            a, b = max(0.0, x), min(1.0, x + 0.5)
            bags.append(B((a + 0.01, y, 0.08 + row * 0.04), (b - 0.01, y + 0.3, 0.92 - row * 0.04), "blocks:decor_sandbag"))
            x += 0.5
    _vcm("zomboid_decor_sandbags", bags)
    side = math.hypot(1.5, 1.7)
    ang = math.degrees(math.atan2(1.7, 1.5))
    _vcm("zomboid_decor_tent", [
        B((0, 0, 0), (side, 0.05, 3), "blocks:decor_tent", origin=(0, 0, 0), rotate=(0, 0, ang)),
        B((3 - side, 0, 0), (3, 0.05, 3), "blocks:decor_tent", origin=(3, 0, 0), rotate=(0, 0, -ang)),
        '@tri a (0,0,2.95) b (3,0,2.95) c (1.5,1.7,2.95) texture "blocks:decor_tent" cull-face off',
        '@tri a (0,0,0.05) b (0.9,0,0.05) c (1.2,1.36,0.05) texture "blocks:decor_tent" cull-face off',
        B((1.45, 0, 1.4), (1.55, 1.72, 1.5), "blocks:decor_metal"),
    ])
    _vcm("zomboid_decor_stairs", [
        B((0, 0, 0), (1, 0.5, 1), "blocks:wood_floor"),
        B((0, 0.5, 0.5), (1, 1, 1), "blocks:wood_floor"),
    ])
    _vcm("zomboid_decor_bathtub", [
        B((0, 0, 0), (1, 0.15, 2), "blocks:decor_ceramic"),
        B((0, 0.15, 0), (0.12, 0.6, 2), "blocks:decor_ceramic"),
        B((0.88, 0.15, 0), (1, 0.6, 2), "blocks:decor_ceramic"),
        B((0.12, 0.15, 0), (0.88, 0.6, 0.12), "blocks:decor_ceramic"),
        B((0.12, 0.15, 1.88), (0.88, 0.6, 2), "blocks:decor_ceramic"),
        B((0.45, 0.6, 1.8), (0.55, 0.8, 1.95), "blocks:decor_metal"),
    ])
    _vcm("zomboid_decor_toilet", [
        B((0.32, 0, 0.25), (0.68, 0.4, 0.72), "blocks:decor_ceramic"),
        B((0.26, 0.4, 0.15), (0.74, 0.46, 0.72), "blocks:decor_ceramic"),
        B((0.24, 0.4, 0.7), (0.76, 0.95, 0.9), "blocks:decor_ceramic"),
    ])
    _vcm("zomboid_decor_desk", [
        B((0, 0.74, 0.1), (1, 0.82, 0.9), "blocks:decor_desk"),
        B((0.58, 0, 0.12), (0.98, 0.74, 0.88), "blocks:wood_side", {"north": "blocks:decor_desk_front"}),
        B((0.04, 0, 0.14), (0.12, 0.74, 0.22), "blocks:wood_side"),
        B((0.04, 0, 0.78), (0.12, 0.74, 0.86), "blocks:wood_side"),
        B((0.2, 0.82, 0.55), (0.45, 0.85, 0.8), "blocks:decor_note"),
    ])


if __name__ == "__main__":
    os.makedirs(MODELS, exist_ok=True)
    detail_textures()
    detail_models()
