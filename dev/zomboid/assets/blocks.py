#!/usr/bin/env python3
import math
import os
import sys
import zlib

sys.path.insert(0, os.path.dirname(__file__))
from common import *  # noqa: E402,F403

TEX = {}


def tex(name, w=32, h=None):
    def reg(fn):
        TEX[name] = (fn, w, h or w)
        return fn
    return reg


def put(c, x, y, col):
    c.set(x % c.w, y % c.h, col)


def panel(c, x0, y0, x1, y1, t, sunk=False):
    lit, dark = (t[1], t[3]) if sunk else (t[3], t[1])
    c.rect(x0, y0, x1, y1, t[2])
    c.line(x0, y0, x1, y0, lit)
    c.line(x0, y0, x0, y1, lit)
    c.line(x0, y1, x1, y1, dark)
    c.line(x1, y0, x1, y1, dark)


def board(c, x0, y0, x1, y1, t, vertical=False, knots=True):
    a0, a1, b0, b1 = (y0, y1, x0, x1) if vertical else (x0, x1, y0, y1)

    def at(a, b, col):
        put(c, b, a, col) if vertical else put(c, a, b, col)
    for a in range(a0, a1 + 1):
        for b in range(b0, b1 + 1):
            at(a, b, t[2])
    for b in range(b0 + 1, b1):
        a = a0 + c.r.randrange(max(1, a1 - a0))
        n = c.r.randrange(3, 9)
        tone = t[1] if c.r.random() < 0.6 else t[3]
        for i in range(n):
            if a + i <= a1:
                at(a + i, b, tone)
    for a in range(a0, a1 + 1):
        at(a, b0, t[3])
        at(a, b1, t[1])
    for b in range(b0, b1 + 1):
        at(a0, b, t[1] if b > b0 else t[3])
        at(a1, b, t[1])
    if knots and a1 - a0 > 10 and b1 - b0 > 3 and c.r.random() < 0.5:
        a, b = c.r.randrange(a0 + 3, a1 - 3), (b0 + b1) // 2
        at(a, b, t[0])
        at(a + 1, b, t[1])
        at(a - 1, b, t[1])


def nail(c, x, y, t=PAL["iron"]):
    put(c, x, y, t[3])
    put(c, x + 1, y, t[1])
    put(c, x, y + 1, t[1])
    put(c, x + 1, y + 1, t[0])


ASPHALT = PAL["asphalt"]
CONCRETE = ramp("9c9a94")
TRIM = ramp("6d5a45")
FRAME = ramp("dedad0")
GLASS = ramp("9ec6d8")
ENAMEL = ramp("e4e2da")
CHROME = ramp("a8b0b8")
CABINET = ramp("b49a72")
LAMINATE = ramp("c9c6bf")
DARK = ramp("2c2c30")
SOIL = PAL["soil"]


def asphalt(c):
    t = ASPHALT
    for y in range(c.h):
        for x in range(c.w):
            c.set(x, y, t[2])
    for _ in range(90):
        x, y = c.r.randrange(c.w), c.r.randrange(c.h)
        c.set(x, y, t[3] if c.r.random() < 0.6 else t[4])
    for _ in range(70):
        x, y = c.r.randrange(c.w), c.r.randrange(c.h)
        c.set(x, y, t[1])
        if c.r.random() < 0.3:
            put(c, x + 1, y, t[1])
    for _ in range(6):
        x, y = c.r.randrange(c.w), c.r.randrange(c.h)
        put(c, x, y, t[0])
        put(c, x + 1, y + 1, t[1])


@tex("asphalt")
def tex_asphalt(c):
    asphalt(c)
    c.noise(0.03)


@tex("road_line")
def tex_road_line(c):
    c.r.seed(zlib.crc32(b"asphalt"))
    asphalt(c)
    c.noise(0.03)
    paint = ramp("d8b23a")
    for y in range(c.h):
        for x in range(14, 18):
            if c.r.random() < 0.12:
                continue
            c.set(x, y, paint[3] if x == 14 else paint[1] if x == 17 else paint[2])
    for _ in range(5):
        c.set(c.r.randrange(14, 18), c.r.randrange(c.h), ASPHALT[3])


@tex("sidewalk")
def tex_sidewalk(c):
    t = CONCRETE
    c.rect(0, 0, 31, 31, t[2])
    for _ in range(110):
        c.set(c.r.randrange(32), c.r.randrange(32), t[3] if c.r.random() < 0.5 else t[1])
    for i in range(32):
        c.set(i, 0, t[0])
        c.set(0, i, t[0])
        c.set(i, 1, t[3])
        c.set(1, i, t[3])
        c.set(i, 31, t[1])
        c.set(31, i, t[1])
    for i in range(2, 31):
        c.set(i, 16, t[1])
        c.set(i, 17, t[3])
    for x, y in ((6, 9), (7, 9), (8, 10), (9, 10), (10, 11), (22, 24), (23, 25), (24, 25)):
        c.set(x, y, t[1])
    c.noise(0.03)


SIDING = {"white": "d9d4c7", "blue": "6f8fae", "yellow": "cdb56a", "green": "7f9a6e", "red": "9c5a4c"}


def siding(col):
    def draw(c):
        t = ramp(col)
        for y in range(32):
            row = y % 8
            tone = t[0] if row == 0 else t[1] if row == 1 else t[3] if row == 7 else t[2]
            for x in range(32):
                c.set(x, y, tone)
        for b in range(4):
            for _ in range(5):
                x, y, n = c.r.randrange(32), b * 8 + c.r.randrange(2, 7), c.r.randrange(4, 12)
                for i in range(n):
                    put(c, x + i, y, mix(t[2], t[1], 0.35))
        for _ in range(4):
            x, y = c.r.randrange(32), c.r.randrange(32)
            if y % 8 > 1:
                c.set(x, y, mix(t[2], t[4], 0.6))
        c.noise(0.025)
    return draw


for _name, _col in SIDING.items():
    tex("siding_" + _name)(siding(_col))


def shingles(c, col):
    base = ramp(col)
    tabs = {(r, k): ramp(mix(base[2], base[c.r.choice((1, 3, 3))], c.r.uniform(0.1, 0.6)))
            for r in range(c.h // 8) for k in range(2)}
    for y in range(c.h):
        row, ry = y // 8, y % 8
        off = 8 if row % 2 else 0
        for x in range(c.w):
            t = tabs[(row, ((x + off) % 32) // 16)]
            tone = t[0] if ry == 7 else t[1] if ry in (0, 6) else t[3] if ry == 5 else t[2]
            if (x + off) % 16 == 0 and 2 <= ry <= 6:
                tone = t[1]
            c.set(x, y, tone)
    for _ in range(c.w * c.h // 5):
        x, y = c.r.randrange(c.w), c.r.randrange(c.h)
        if y % 8 < 6:
            c.set(x, y, mix(c.get(x, y), base[4] if c.r.random() < 0.35 else base[0], 0.35))
    c.noise(0.03)


tex("roof")(lambda c: shingles(c, "5b4038"))
tex("roof_side", 32, 16)(lambda c: shingles(c, "5b4038"))


@tex("trim")
def tex_trim(c):
    for (x0, x1), j in zip(((0, 9), (10, 21), (22, 31)), (5, 20, 12)):
        board(c, x0, j, x1, j + 31, TRIM, vertical=True, knots=False)
    c.noise(0.03)


def window_frame(c):
    t = FRAME
    c.frame(0, 0, 31, 31, t[1])
    c.frame(1, 1, 30, 30, t[3])
    c.frame(2, 2, 29, 29, t[2])
    c.line(3, 3, 28, 3, t[0])
    c.line(3, 3, 3, 28, t[0])
    c.rect(2, 15, 29, 16, t[2])
    c.line(3, 15, 28, 15, t[3])
    c.line(3, 17, 28, 17, t[0])
    c.rect(15, 3, 16, 28, t[2])
    c.line(15, 3, 15, 28, t[3])
    c.line(17, 3, 17, 14, t[0])
    c.line(17, 18, 17, 28, t[0])


@tex("window")
def tex_window(c):
    c.rect(0, 0, 31, 31, alpha(GLASS[2], 120))
    for x0, y0 in ((4, 4), (18, 4), (4, 18), (18, 18)):
        c.line(x0 + 1, y0 + 4, x0 + 4, y0 + 1, alpha(GLASS[4], 170))
        c.line(x0 + 1, y0 + 7, x0 + 7, y0 + 1, alpha(GLASS[4], 170))
        c.line(x0 + 7, y0 + 9, x0 + 9, y0 + 7, alpha(GLASS[3], 150))
    window_frame(c)


@tex("window_broken")
def tex_window_broken(c):
    shard = alpha(GLASS[3], 160)
    edge = alpha(GLASS[4], 180)
    for pts in (((4, 4), (11, 4), (4, 9)), ((14, 4), (14, 12), (10, 4)), ((18, 4), (23, 4), (18, 7)),
                ((28, 4), (28, 13), (24, 4)), ((4, 18), (8, 18), (4, 26)), ((4, 28), (11, 28), (4, 23)),
                ((28, 28), (21, 28), (28, 20)), ((18, 28), (18, 24), (22, 28)), ((14, 18), (14, 22), (11, 18))):
        c.poly(pts, shard)
        c.line(pts[1][0], pts[1][1], pts[2][0], pts[2][1], edge)
    window_frame(c)


BAR_ROWS = ((2, 8, 1), (10, 16, -1), (18, 24, 1), (26, 31, -1))


def plank_across(c, y0, y1, tilt, t):
    for x in range(32):
        dy = round(tilt * (x - 16) / 16)
        for y in range(y0, y1 + 1):
            yy = y + dy
            if 0 <= yy < 32:
                tone = t[3] if y == y0 else t[1] if y == y1 else t[2]
                c.set(x, yy, tone)
    for _ in range(7):
        x, y, n = c.r.randrange(32), c.r.randrange(y0 + 1, y1), c.r.randrange(4, 12)
        tone = t[1] if c.r.random() < 0.7 else t[3]
        for i in range(n):
            if x + i < 32:
                c.set(x + i, y + round(tilt * (x + i - 16) / 16), tone)
    for x in (3, 28):
        dy = round(tilt * (x - 16) / 16)
        nail(c, x, (y0 + y1) // 2 + dy - 1)


def barricade(level):
    def draw(c):
        window_frame(c)
        for i, (a, b, tilt) in enumerate(BAR_ROWS[:level]):
            plank_across(c, a, b, tilt, ramp(("a07a4a", "947044", "aa8250", "9a7448")[i]))
    return draw


for _lv in range(1, 5):
    tex("barricade_%d" % _lv)(barricade(_lv))


def door(c, t):
    c.rect(0, 0, 31, 63, t[2])
    c.frame(0, 0, 31, 63, t[0])
    c.line(1, 1, 30, 1, t[3])
    c.line(1, 1, 1, 62, t[3])
    for x0, y0, x1, y1 in ((5, 5, 14, 26), (17, 5, 26, 26), (5, 32, 14, 58), (17, 32, 26, 58)):
        panel(c, x0, y0, x1, y1, t, sunk=True)
        c.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, t[2])
        c.line(x0 + 2, y0 + 2, x1 - 2, y0 + 2, t[3])
        c.line(x0 + 2, y0 + 2, x0 + 2, y1 - 2, t[3])
    c.rect(26, 30, 28, 32, PAL["brass"][3])
    c.set(28, 32, PAL["brass"][1])
    c.set(26, 30, PAL["brass"][4])


DOOR_ROWS = ((8, 15, 1), (22, 29, -1), (38, 45, 1), (50, 57, -1))


def door_barricade(level):
    def draw(c):
        door(c, ramp("7a5532"))
        for i, (a, b, tilt) in enumerate(DOOR_ROWS[:level]):
            for x in range(32):
                dy = round(tilt * (x - 16) / 16)
                for y in range(a, b + 1):
                    t = ramp(("b38a55", "a8804c", "bc9460", "ae8650")[i])
                    c.set(x, y + dy, t[3] if y == a else t[1] if y == b else t[2])
            for _ in range(7):
                x, y, n = c.r.randrange(32), c.r.randrange(a + 1, b), c.r.randrange(4, 12)
                for k in range(min(n, 32 - x)):
                    c.set(x + k, y + round(tilt * (x + k - 16) / 16), t[1])
            for x in (3, 28):
                nail(c, x, (a + b) // 2 + round(tilt * (x - 16) / 16) - 1)
    return draw


for _lv in range(1, 5):
    tex("door_barricade_%d" % _lv, 32, 64)(door_barricade(_lv))


@tex("fridge_front", 32, 64)
def tex_fridge_front(c):
    t = ENAMEL
    panel(c, 0, 0, 31, 20, t)
    panel(c, 0, 21, 31, 63, t)
    c.line(0, 20, 31, 20, t[0])
    c.line(0, 21, 31, 21, t[1])
    for y0, y1 in ((5, 16), (26, 46)):
        c.rect(26, y0, 27, y1, CHROME[2])
        c.line(26, y0, 26, y1, CHROME[4])
        c.line(28, y0, 28, y1, CHROME[0])
    c.rect(5, 29, 12, 38, PAL["paper"][3])
    c.line(5, 38, 12, 38, PAL["paper"][1])
    for y, n in ((31, 6), (33, 5), (35, 6)):
        c.line(6, y, 5 + n, y, PAL["plastic_blue"][2])
    c.rect(8, 27, 9, 28, PAL["plastic_red"][2])
    c.rect(15, 10, 17, 12, PAL["plastic_red"][2])
    c.rect(1, 60, 30, 62, DARK[1])
    for x in range(3, 29, 3):
        c.set(x, 61, DARK[0])


@tex("fridge_side")
@tex("fridge_side_tall", 32, 64)
def tex_fridge_side(c):
    t = ENAMEL
    panel(c, 0, 0, 31, c.h - 1, t)
    for y in range(2, c.h - 2):
        c.set(2, y, t[3])
        c.set(29, y, mix(t[2], t[1], 0.5))
    c.noise(0.015)



@tex("wardrobe_front", 32, 64)
def tex_wardrobe_front(c):
    t = ramp("8a6038")
    c.rect(0, 0, 31, 63, t[1])
    for x0, x1 in ((1, 15), (16, 30)):
        board(c, x0, 1, x1, 50, t, vertical=True, knots=False)
        for y0, y1 in ((4, 21), (25, 47)):
            panel(c, x0 + 3, y0, x1 - 3, y1, t, sunk=True)
            c.rect(x0 + 4, y0 + 1, x1 - 4, y1 - 1, t[2])
    c.line(15, 1, 15, 50, t[0])
    c.line(16, 1, 16, 50, t[3])
    board(c, 1, 53, 30, 61, t, knots=False)
    for x in (13, 18):
        c.rect(x, 22, x, 26, PAL["brass"][3])
        c.set(x, 26, PAL["brass"][1])
    c.rect(14, 57, 17, 57, PAL["brass"][2])
    c.line(0, 51, 31, 51, t[0])
    c.line(0, 52, 31, 52, t[1])
    c.frame(0, 0, 31, 63, t[0])


@tex("wood_side")
@tex("wood_side_tall", 32, 64)
def tex_wood_side(c):
    t = ramp("8a6038")
    for x0, x1 in ((0, 7), (8, 15), (16, 23), (24, 31)):
        board(c, x0, 0, x1, c.h - 1, t, vertical=True)
    c.frame(0, 0, 31, c.h - 1, t[0])
    c.line(1, 1, 30, 1, t[3])
    c.noise(0.025)


@tex("cabinet_front")
def tex_cabinet_front(c):
    t = CABINET
    c.rect(0, 0, 31, 31, t[1])
    panel(c, 1, 1, 30, 7, t)
    c.rect(12, 4, 19, 4, CHROME[1])
    c.rect(12, 3, 19, 3, CHROME[3])
    for x0, x1 in ((1, 15), (16, 30)):
        panel(c, x0, 9, x1, 27, t)
        panel(c, x0 + 3, 12, x1 - 3, 24, t, sunk=True)
    for x in (13, 18):
        c.rect(x, 15, x, 19, CHROME[3])
        c.set(x, 19, CHROME[0])
    c.rect(0, 28, 31, 31, DARK[1])
    c.line(0, 28, 31, 28, DARK[0])
    c.noise(0.02)


@tex("counter_top")
def tex_counter_top(c):
    t = LAMINATE
    c.rect(0, 0, 31, 31, t[2])
    for _ in range(120):
        c.set(c.r.randrange(32), c.r.randrange(32), t[1] if c.r.random() < 0.5 else t[3])
    c.frame(0, 0, 31, 31, t[1])
    c.line(1, 1, 30, 1, t[4])
    c.line(1, 1, 1, 30, t[4])
    c.noise(0.015)


SHELF_GOODS = (("c84a3a", "e0c040", "4a80c8", "58a050"), ("c87a3a", "e8e8e8", "a04a8a", "c8c050"),
               ("5aa0a0", "d86a30", "3a6ab0", "b8bcc4"))


@tex("shelf_front", 32, 64)
def tex_shelf_front(c):
    t = PAL["iron"]
    c.rect(0, 0, 31, 63, DARK[0])
    for i in range(6):
        cols = SHELF_GOODS[i % 3][::1 if i < 3 else -1]
        top = i * 10 + 1
        x = 2
        for j, col in enumerate(cols):
            g = ramp(col)
            kind = (i + j) % 3
            w = 6 if kind != 2 else 4
            h = (7, 5, 8)[kind]
            y0 = top + 8 - h
            if kind == 0:
                c.paint(c.rect_m(x, y0, x + w - 1, top + 7), g)
                c.line(x, y0 + 2, x + w - 1, y0 + 2, PAL["paper"][3])
            elif kind == 1:
                c.paint(c.rect_m(x, y0, x + w - 1, top + 7), g)
                c.line(x, y0, x + w - 1, y0, CHROME[3])
                c.line(x, top + 7, x + w - 1, top + 7, CHROME[1])
            else:
                c.paint(c.rect_m(x, y0 + 2, x + w - 1, top + 7), g)
                c.rect(x + 1, y0, x + w - 2, y0 + 1, g[1])
            x += w + 1
        c.rect(0, top + 8, 31, top + 9, t[2])
        c.line(0, top + 8, 31, top + 8, t[3])
        c.line(0, top + 9, 31, top + 9, t[0])
    c.rect(0, 0, 1, 63, t[2])
    c.rect(30, 0, 31, 63, t[1])
    c.line(0, 0, 0, 63, t[3])
    c.line(31, 0, 31, 63, t[0])


@tex("crate")
def tex_crate(c):
    t = ramp("a8834e")
    for y0, y1 in ((0, 7), (8, 15), (16, 23), (24, 31)):
        board(c, 0, y0, 31, y1, t, knots=False)
    for x0 in (0, 27):
        board(c, x0, 0, x0 + 4, 31, ramp("8c6a3c"), vertical=True, knots=False)
    for y0 in (0, 27):
        board(c, 0, y0, 31, y0 + 4, ramp("8c6a3c"), knots=False)
    brace = ramp("8c6a3c")
    for i in range(5, 27):
        for w in range(-2, 3):
            c.set(i + w, 31 - i, brace[3] if w == -2 else brace[1] if w == 2 else brace[2])
    for x, y in ((1, 1), (29, 1), (1, 29), (29, 29)):
        nail(c, x, y)
    c.frame(0, 0, 31, 31, t[0])
    c.noise(0.03)


@tex("medcab_front")
def tex_medcab_front(c):
    t = ENAMEL
    panel(c, 0, 0, 31, 31, t)
    panel(c, 3, 3, 28, 28, ramp("c8d8dc"), sunk=True)
    red = PAL["plastic_red"]
    c.paint(c.rect_m(13, 7, 18, 24) | c.rect_m(7, 13, 24, 18), red)
    c.line(5, 26, 9, 22, ramp("c8d8dc")[4])
    c.rect(25, 13, 26, 18, CHROME[2])
    c.line(25, 13, 25, 18, CHROME[4])


@tex("sink_top")
def tex_sink_top(c):
    tex_counter_top(c)
    s = CHROME
    c.rect(5, 8, 26, 27, s[1])
    c.rect(6, 9, 25, 26, s[2])
    c.line(6, 9, 25, 9, s[0])
    c.line(6, 9, 6, 26, s[0])
    c.line(25, 10, 25, 26, s[3])
    c.line(7, 26, 25, 26, s[3])
    c.rect(15, 17, 16, 18, DARK[0])
    c.frame(14, 16, 17, 19, s[1])
    c.rect(14, 2, 17, 5, s[2])
    c.line(14, 2, 17, 2, s[4])
    c.rect(15, 6, 16, 11, s[3])
    c.set(16, 11, s[1])
    for x in (9, 22):
        c.rect(x, 3, x + 1, 4, s[3])
        c.set(x + 1, 4, s[0])


@tex("stove_top")
def tex_stove_top(c):
    t = ENAMEL
    panel(c, 0, 0, 31, 31, t)
    for cx, cy, r in ((9, 9, 6), (23, 9, 5), (9, 23, 5), (23, 23, 6)):
        c.paint(c.ellipse_m(cx, cy, r + 0.5, r + 0.5), DARK)
        for k in range(1, r, 2):
            for x, y in c.ellipse_m(cx, cy, k + 0.5, k + 0.5) - c.ellipse_m(cx, cy, k - 0.5, k - 0.5):
                c.set(x, y, DARK[3])
        c.set(cx, cy, DARK[1])


@tex("stove_front")
def tex_stove_front(c):
    t = ENAMEL
    panel(c, 0, 0, 31, 31, t)
    c.rect(0, 0, 31, 5, DARK[2])
    c.line(0, 5, 31, 5, DARK[0])
    for x in (4, 10, 21, 27):
        c.rect(x - 1, 1, x + 1, 3, CHROME[3])
        c.set(x, 2, CHROME[0])
    c.rect(14, 2, 17, 3, ramp("40c060")[2])
    c.rect(4, 8, 27, 9, CHROME[2])
    c.line(4, 8, 27, 8, CHROME[4])
    c.line(4, 10, 27, 10, t[1])
    panel(c, 4, 12, 27, 26, DARK, sunk=True)
    c.line(7, 15, 11, 15, DARK[4])
    c.line(7, 16, 9, 16, DARK[3])
    c.rect(0, 28, 31, 31, DARK[1])
    c.line(0, 28, 31, 28, DARK[0])


@tex("tiles")
def tex_tiles(c):
    a, b = ramp("dcdcd4"), ramp("b4b4ac")
    for y in range(32):
        for x in range(32):
            t = a if ((x // 8) + (y // 8)) % 2 == 0 else b
            rx, ry = x % 8, y % 8
            tone = t[2]
            if rx == 0 or ry == 0:
                tone = ramp("8c8a84")[2]
            elif rx == 1 or ry == 1:
                tone = t[3]
            elif rx == 7 or ry == 7:
                tone = t[1]
            c.set(x, y, tone)
    for x, y in ((3, 3), (4, 3), (3, 4), (19, 19), (20, 19), (19, 20), (11, 27), (12, 27), (27, 11), (27, 12)):
        c.set(x, y, a[4] if ((x // 8) + (y // 8)) % 2 == 0 else b[4])
    c.noise(0.015)


@tex("carpet")
def tex_carpet(c):
    t = ramp("8a4c3a")
    for y in range(32):
        for x in range(32):
            d = (abs((x % 16) - 8) + abs((y % 16) - 8))
            tone = t[2]
            if d == 8:
                tone = t[1]
            elif d == 4:
                tone = t[3]
            elif d == 0:
                tone = ramp("c8a050")[2]
            if (x + y) % 2 == 0 and tone == t[2]:
                tone = mix(t[2], t[1], 0.25)
            c.set(x, y, tone)
    c.noise(0.04)


@tex("lamp_on", 16)
def tex_lamp_on(c):
    t = ramp("fff4c0")
    panel(c, 0, 0, 15, 15, ramp("e8dca8"))
    c.paint(c.ellipse_m(8, 8, 7, 7), t)
    c.fill(c.ellipse_m(8, 8, 4.5, 4.5), t[4])
    c.fill(c.ellipse_m(7, 7, 2, 2), (255, 255, 246, 255))


@tex("lamp_off", 16)
def tex_lamp_off(c):
    t = ramp("a8a494")
    panel(c, 0, 0, 15, 15, ramp("9a9686"))
    c.paint(c.ellipse_m(8, 8, 7, 7), t)
    c.fill(c.ellipse_m(8, 8, 4.5, 4.5), t[2])
    c.fill(c.ellipse_m(6, 6, 1.5, 1.5), t[4])


def lamp_side(t, glow):
    def draw(c):
        for y in range(10):
            for x in range(16):
                c.set(x, y, t[3] if y < 2 else t[2] if y < 7 else t[1])
        c.line(0, 0, 15, 0, t[4])
        c.line(0, 9, 15, 9, glow)
        c.set(0, 5, t[1])
        c.set(15, 5, t[1])
    return draw


tex("lamp_on_side", 16, 10)(lamp_side(ramp("e8dca8"), (255, 248, 210, 255)))
tex("lamp_off_side", 16, 10)(lamp_side(ramp("9a9686"), ramp("9a9686")[0]))


@tex("lamp_top", 16)
def tex_lamp_top(c):
    t = ramp("8a8678")
    panel(c, 0, 0, 15, 15, t)
    c.paint(c.ellipse_m(8, 8, 3, 3), CHROME)


@tex("tv_front", 29, 24)
def tex_tv_front(c):
    body = ramp("5a4632")
    for y in range(24):
        for x in range(29):
            c.set(x, y, body[2] if (y + x // 7) % 5 else body[1])
    c.frame(0, 0, 28, 23, body[0])
    c.line(1, 1, 27, 1, body[3])
    c.line(1, 1, 1, 22, body[3])
    scr = c.rect_m(3, 3, 20, 19) - {(3, 3), (20, 3), (3, 19), (20, 19)}
    c.fill(scr, ramp("1a2026")[2])
    c.fill(c.rect_m(4, 4, 19, 18) - {(4, 4), (19, 4), (4, 18), (19, 18)}, ramp("2a3540")[2])
    for x, y in c.line_m(6, 9, 10, 5) | c.line_m(6, 12, 13, 5):
        c.set(x, y, ramp("2a3540")[4] if (x + y) % 2 else ramp("2a3540")[3])
    c.rect(2, 2, 21, 2, body[0])
    for y in (5, 10):
        c.paint(c.ellipse_m(24.5, y + 1.5, 2, 2), CHROME)
    for y in range(15, 21, 2):
        c.line(23, y, 26, y, body[0])


@tex("tv_side", 24)
def tex_tv_side(c):
    body = ramp("5a4632")
    for y in range(24):
        for x in range(24):
            c.set(x, y, body[2] if (y + x // 6) % 5 else body[1])
    for y in range(5, 19, 3):
        c.line(5, y, 18, y, body[0])
        c.line(5, y + 1, 18, y + 1, body[3])
    c.frame(0, 0, 23, 23, body[0])


@tex("garden_bed")
def tex_garden_bed(c):
    t = SOIL
    for y in range(32):
        ry = y % 8
        for x in range(32):
            wy = (ry + (1 if (x // 5 + y // 8) % 3 == 0 else 0)) % 8
            c.set(x, y, t[3] if wy in (1, 2) else t[2] if wy in (0, 3, 4) else t[1] if wy in (5, 6) else t[0])
    for _ in range(70):
        x, y = c.r.randrange(32), c.r.randrange(32)
        c.set(x, y, mix(t[2], t[4], 0.5) if c.r.random() < 0.3 else t[1])
    for _ in range(8):
        x, y = c.r.randrange(32), c.r.randrange(32)
        c.set(x, y, ramp("8a8a86")[3])
        put(c, x + 1, y, ramp("8a8a86")[1])
    c.noise(0.04)


def stem(c, x, base, h, lean, tones):
    pts = []
    for k in range(h + 1):
        f = k / max(1, h)
        px, py = round(x + lean * f * f), base - k
        c.set(px, py, tones[1] if f < 0.35 else tones[2])
        pts.append((px, py, f))
    return pts


def crop(kind, stage):
    def draw(c):
        leaf = ramp("4aa040") if kind == "carrot" else ramp("3a8a3a")
        h = (7, 13, 19, 24)[stage]
        n = (2, 3, 4, 5)[stage]
        for x in (6, 16, 26):
            for i in range(n):
                lean = (i - (n - 1) / 2) * (2.5 if kind == "carrot" else 3.2) + c.r.uniform(-0.8, 0.8)
                sh = h - c.r.randrange(0, max(1, h // 4))
                pts = stem(c, x, 30, sh, lean, leaf)
                for px, py, f in pts:
                    if kind == "carrot" and f > 0.35 and py % 2 == 0:
                        side = 1 if (py // 2) % 2 else -1
                        c.set(px + side, py, leaf[3])
                        c.set(px + side * 2, py - 1, leaf[3] if f > 0.7 else leaf[2])
                    if kind == "potato" and f > 0.45 and py % 4 == 0:
                        side = 1 if (py // 4) % 2 else -1
                        c.paint(c.ellipse_m(px + side * 2 + 0.5, py + 0.5, 2.2, 1.5), leaf, grad=False)
                if kind == "potato":
                    tx, ty, _ = pts[-1]
                    c.paint(c.ellipse_m(tx + 0.5, ty + 1, 2.4, 1.8), leaf, grad=False)
                    if stage == 3 and i % 2 == 0:
                        c.set(tx, ty - 1, ramp("ece6f2")[3])
                        c.set(tx + 1, ty - 1, ramp("ece6f2")[2])
                        c.set(tx, ty - 2, ramp("ece6f2")[4])
                        c.set(tx + 1, ty - 2, ramp("e8c030")[2])
            if stage == 3 and kind == "carrot":
                c.paint(c.rect_m(x - 2, 29, x + 1, 31), ramp("e07a20"))
            if stage == 3 and kind == "potato":
                c.paint(c.ellipse_m(x - 2.5, 30.5, 2.2, 1.6), ramp("b89a60"))
    return draw


for _kind in ("carrot", "potato"):
    for _st in range(4):
        tex("crop_%s_%d" % (_kind, _st))(crop(_kind, _st))


@tex("crop_dead")
def tex_crop_dead(c):
    t = ramp("7a6a3a")
    for x in (6, 16, 26):
        for i in range(4):
            dx = c.r.choice((-1, 1)) * c.r.uniform(2, 6)
            top = 30 - c.r.randrange(6, 14)
            for y in range(top, 31):
                f = (30 - y) / max(1, 30 - top)
                c.set(round(x + dx * f * f), y, t[1] if f < 0.4 else t[2] if f < 0.8 else t[3])


@tex("fire")
def tex_fire(c):
    layers = ((alpha(ramp("c03010")[2], 220), 1.0, 1.0), (ramp("f08020")[2], 0.68, 0.78),
              (ramp("f8e060")[2], 0.4, 0.55), (ramp("f8e060")[4], 0.18, 0.3))
    tongues = [(4, 14, 3.5), (10, 22, 4.5), (16, 28, 5.5), (22, 20, 4.5), (28, 15, 3.5), (13, 17, 3), (20, 25, 3.5)]
    for col, kw, kh in layers:
        for i, (cx, h, w) in enumerate(tongues):
            hh = h * kh
            for k in range(int(hh) + 1):
                f = k / hh
                hw = w * kw * (1 - f) ** 0.6 + 0.3
                xc = cx + 2.2 * f * f * (1 if i % 2 else -1)
                y = 31 - k
                for x in range(int(xc - hw), int(xc + hw) + 1):
                    if abs(x + 0.5 - xc) <= hw:
                        c.set(x, y, col)


@tex("plank_wall")
def tex_plank_wall(c):
    tones = (ramp("9a7444"), ramp("8e6a3e"), ramp("a47c4a"), ramp("94703f"))
    joints = (11, 25, 4, 19)
    for row in range(4):
        y0, y1, j = row * 8, row * 8 + 7, joints[row]
        board(c, j, y0, j + 31, y1, tones[row])
        for x in (j + 2, j + 28):
            nail(c, x, y0 + 3)
    c.noise(0.03)


@tex("wooden_gate", 32, 64)
def tex_wooden_gate(c):
    t = ramp("9a7444")
    for i, x0 in enumerate((0, 8, 16, 24)):
        board(c, x0, 0, x0 + 7, 63, ramp(("9a7444", "8e6a3e", "a47c4a", "94703f")[i]), vertical=True)
    brace = ramp("7a5a34")
    for y0 in (6, 52):
        board(c, 0, y0, 31, y0 + 5, brace, knots=False)
    for i in range(12, 52):
        x = round((i - 12) * 27 / 40) + 2
        for w in range(-2, 3):
            c.set(x + w, 63 - i, brace[3] if w == -2 else brace[1] if w == 2 else brace[2])
    for y0 in (6, 52):
        c.paint(c.rect_m(0, y0 + 1, 6, y0 + 4), PAL["iron"])
        nail(c, 4, y0 + 2)
    c.frame(0, 0, 31, 63, t[0])


@tex("palisade")
def tex_palisade(c):
    for i, x0 in enumerate((0, 8, 16, 24)):
        t = ramp(("6a4c2c", "735230", "664a2a", "70502e")[i])
        tip = i % 2
        for y in range(tip, 32):
            for x in range(x0, x0 + 8):
                d = x - x0
                if y - tip < 2 and abs(d - 3.5) > (y - tip) + 1.5:
                    continue
                tone = t[3] if d <= 1 else t[1] if d >= 6 else t[2]
                c.set(x, y, tone)
        for _ in range(6):
            x, y = c.r.randrange(x0 + 2, x0 + 6), c.r.randrange(tip + 4, 32)
            for k in range(c.r.randrange(2, 6)):
                c.set(x, y + k, t[1])
        c.line(x0 + 2, tip + 1, x0 + 3, tip, ramp("c8a878")[3])
        c.set(x0 + 4, tip, ramp("c8a878")[2])
        c.line(x0, 21, x0 + 7, 22, ramp("8a7a5a")[1])


@tex("palisade_top")
def tex_palisade_top(c):
    c.rect(0, 0, 31, 31, ramp("3a2a1a")[1])
    for gy in range(4):
        for gx in range(4):
            cx, cy = gx * 8 + 4, gy * 8 + 4
            c.paint(c.ellipse_m(cx, cy, 3.8, 3.8), ramp("8a6a44"))
            c.set(cx - 1, cy - 1, ramp("c8a878")[3])
            c.set(cx, cy, ramp("c8a878")[4])


@tex("ladder")
def tex_ladder(c):
    t = ramp("8a6a3a")
    for x0 in (3, 25):
        board(c, x0, 0, x0 + 3, 31, t, vertical=True, knots=False)
    for y in (3, 11, 19, 27):
        board(c, 7, y, 24, y + 2, ramp("a07c48"), knots=False)
        nail(c, 4, y)
        nail(c, 26, y)


FLOOR_TONES = (ramp("a88050"), ramp("9c7646"), ramp("b08858"), ramp("a27a4a"))


@tex("wood_floor")
def tex_wood_floor(c):
    joints = (5, 21, 13, 28)
    for col in range(4):
        x0, j = col * 8, joints[col]
        board(c, x0, j, x0 + 7, j + 31, FLOOR_TONES[col], vertical=True)
    c.noise(0.03)


@tex("wood_floor_side", 32, 16)
def tex_wood_floor_side(c):
    for col in range(4):
        board(c, col * 8, 0, col * 8 + 7, 15, FLOOR_TONES[col], vertical=True, knots=False)
    c.noise(0.03)


@tex("bed_top")
def tex_bed_top(c):
    sheet, blanket = ramp("ecebe4"), ramp("5a74a8")
    c.rect(0, 0, 31, 31, sheet[2])
    c.paint(c.rect_m(3, 1, 28, 8) - {(3, 1), (28, 1), (3, 8), (28, 8)}, sheet)
    c.line(5, 4, 26, 4, sheet[3])
    c.paint(c.rect_m(0, 10, 31, 31), blanket, grad=False)
    c.rect(0, 10, 31, 13, sheet[3])
    c.line(0, 13, 31, 13, sheet[1])
    c.line(0, 14, 31, 14, blanket[0])
    for y in range(16, 32):
        for x in range(32):
            if (x + y) % 8 == 0 or (x - y) % 8 == 0:
                c.set(x, y, blanket[1])
    c.line(1, 15, 1, 31, blanket[3])
    c.line(30, 15, 30, 31, blanket[1])
    c.noise(0.02)


@tex("bed_side", 32, 18)
def tex_bed_side(c):
    blanket, wood = ramp("5a74a8"), ramp("6d4a2a")
    for x0, x1 in ((0, 15), (16, 31)):
        board(c, x0, 9, x1, 17, wood, knots=False)
    c.rect(0, 0, 31, 8, blanket[2])
    c.line(0, 0, 31, 0, blanket[3])
    for x in range(32):
        c.set(x, 8 + (1 if x % 6 in (2, 3) else 0), blanket[1])
        if x % 6 == 2:
            c.set(x, 9, blanket[0])
    for x in range(0, 32, 4):
        c.set(x, 4, blanket[1])
        c.set(x + 2, 4, blanket[3])
    c.rect(0, 16, 2, 17, wood[0])
    c.rect(29, 16, 31, 17, wood[0])


@tex("couch")
def tex_couch(c):
    t = ramp("7a3a3a")
    c.rect(0, 0, 31, 31, t[2])
    for x0, x1 in ((0, 15), (16, 31)):
        m = c.rect_m(x0 + 1, 1, x1 - 1, 30)
        c.paint(m, t)
        c.frame(x0, 0, x1, 31, t[0])
        for bx, by in ((x0 + 5, 9), (x1 - 5, 9), (x0 + 5, 22), (x1 - 5, 22), ((x0 + x1) // 2, 15)):
            c.set(bx, by, t[0])
            c.set(bx - 1, by - 1, t[3])
            c.set(bx + 1, by + 1, t[1])
    for y in range(2, 30, 3):
        for x in range(2, 30, 3):
            if c.get(x, y) == t[2]:
                c.set(x, y, mix(t[2], t[1], 0.4))
    c.noise(0.02)


@tex("alarm_clock_front", 13)
def tex_alarm_clock_front(c):
    body = PAL["plastic_red"]
    panel(c, 0, 0, 12, 12, body)
    c.paint(c.ellipse_m(6.5, 6.5, 5, 5), ramp("f4f0e4"), grad=False)
    for x, y in ((6, 2), (10, 6), (6, 10), (2, 6)):
        c.set(x, y, DARK[1])
    c.line(6, 6, 6, 3, DARK[0])
    c.line(6, 6, 9, 6, DARK[0])
    c.set(7, 5, body[2])
    c.set(4, 4, ramp("f4f0e4")[4])


@tex("alarm_clock_side", 13)
def tex_alarm_clock_side(c):
    body = PAL["plastic_red"]
    panel(c, 0, 0, 12, 12, body)
    c.rect(5, 5, 7, 7, CHROME[2])
    c.set(5, 5, CHROME[4])
    c.set(7, 7, CHROME[0])


@tex("alarm_clock_top", 13)
def tex_alarm_clock_top(c):
    body, bell = PAL["plastic_red"], PAL["brass"]
    panel(c, 0, 0, 12, 12, body)
    for cx in (3, 9.5):
        c.paint(c.ellipse_m(cx + 0.5, 6.5, 2.6, 2.6), bell)
    c.rect(5, 6, 7, 6, CHROME[1])
    c.set(6, 5, CHROME[4])


@tex("siren_side", 19, 18)
def tex_siren_side(c):
    t = PAL["iron"]
    panel(c, 0, 0, 18, 17, t)
    for y in range(3, 15, 2):
        c.line(2, y, 16, y, t[0])
        c.line(2, y + 1, 16, y + 1, t[3])
    c.paint(c.rect_m(7, 6, 11, 11), ramp("d0b020"))
    c.line(0, 17, 18, 17, t[0])


@tex("siren_top", 19)
def tex_siren_top(c):
    t, red = PAL["iron"], ramp("c02020")
    panel(c, 0, 0, 18, 18, t)
    c.paint(c.ellipse_m(9.5, 9.5, 7, 7), red)
    c.fill(c.ellipse_m(9.5, 9.5, 4, 4), ramp("ff6040")[3])
    c.fill(c.ellipse_m(8, 8, 1.6, 1.6), ramp("ff6040")[4])


@tex("campfire_side", 26, 11)
def tex_campfire_side(c):
    stone, log = PAL["stone"], ramp("6d4a2a")
    for x0, x1, y0 in ((2, 23, 3), (0, 13, 1), (12, 25, 2)):
        for x in range(x0, x1 + 1):
            for y in range(y0, y0 + 3):
                c.set(x, y, log[3] if y == y0 else log[1] if y == y0 + 2 else log[2])
        c.paint(c.ellipse_m(x1 + 0.5, y0 + 1.5, 1.4, 1.5), ramp("c8a878"))
    for i, x0 in enumerate(range(0, 26, 5)):
        c.paint(c.ellipse_m(x0 + 2.5, 8.5 - (i % 2), 2.7, 2.6), stone)
    for x in range(26):
        if c.get(x, 10)[3] == 0:
            c.set(x, 10, stone[0])


@tex("campfire_top", 26)
def tex_campfire_top(c):
    ash, stone, log = ramp("4a4038"), PAL["stone"], ramp("6d4a2a")
    c.fill(c.ellipse_m(13, 13, 12.5, 12.5), ash[1])
    for i in range(12):
        a = i / 12 * 2 * math.pi
        c.paint(c.ellipse_m(13 + 10.5 * math.cos(a), 13 + 10.5 * math.sin(a), 2.6, 2.6), stone)
    c.fill(c.ellipse_m(13, 13, 8, 8), ash[2])
    for (x0, y0, x1, y1) in ((6, 6, 20, 20), (20, 6, 6, 20), (13, 5, 13, 21)):
        c.paint(c.line_m(x0, y0, x1, y1, 2), log, grad=False)
    c.paint(c.ellipse_m(13, 13, 4.5, 4.5), ramp("f08020"), grad=False)
    c.fill(c.ellipse_m(13, 13, 2.5, 2.5), ramp("f8e060")[3])
    for x, y in ((9, 15), (17, 10), (16, 17), (10, 9)):
        c.set(x, y, ramp("f08020")[4])
    for _ in range(20):
        x, y = c.r.randrange(26), c.r.randrange(26)
        if c.get(x, y) == ash[2]:
            c.set(x, y, ash[3])


GEN = ramp("5a6a4a")


def gen_body(c):
    panel(c, 0, 0, c.w - 1, c.h - 1, GEN)
    c.frame(0, 0, c.w - 1, c.h - 1, GEN[0])
    for x, y in ((2, 2), (c.w - 4, 2), (2, c.h - 4), (c.w - 4, c.h - 4)):
        nail(c, x, y, CHROME)


@tex("generator_side", 26)
def tex_generator_side(c):
    gen_body(c)
    panel(c, 5, 6, 20, 19, DARK, sunk=True)
    for y in range(8, 18, 2):
        c.line(6, y, 19, y, DARK[0])
        c.line(6, y + 1, 19, y + 1, DARK[3])


@tex("generator_top", 29, 26)
def tex_generator_top(c):
    gen_body(c)
    c.paint(c.ellipse_m(9, 13, 5, 5), ramp("c0a030"))
    c.paint(c.ellipse_m(9, 13, 2, 2), DARK)
    c.paint(c.rect_m(17, 8, 24, 18), CHROME)
    c.line(18, 10, 23, 10, CHROME[0])
    c.line(18, 13, 23, 13, CHROME[0])
    c.line(18, 16, 23, 16, CHROME[0])


def gen_front(on):
    def draw(c):
        gen_body(c)
        panel(c, 4, 4, 13, 13, DARK, sunk=True)
        c.line(6, 11, 11, 6, DARK[4])
        c.paint(c.ellipse_m(9, 9, 2.5, 2.5), CHROME)
        led = ramp("40e040") if on else ramp("304030")
        c.paint(c.rect_m(17, 5, 20, 8), led, grad=False)
        if on:
            c.set(18, 6, led[4])
        c.rect(22, 5, 24, 8, PAL["plastic_red"][2])
        c.set(22, 5, PAL["plastic_red"][4])
        c.paint(c.rect_m(17, 11, 24, 13), DARK)
        c.paint(c.rect_m(4, 18, 24, 21), DARK)
        for x in range(6, 24, 3):
            c.line(x, 19, x, 20, DARK[3])
    return draw


tex("generator_front", 29, 26)(gen_front(False))
tex("generator_front_on", 29, 26)(gen_front(True))


@tex("fuel_pump_front")
def tex_fuel_pump_front(c):
    t = ramp("c03a30")
    panel(c, 0, 0, 31, 31, t)
    panel(c, 4, 3, 27, 13, ramp("e8e8d8"))
    panel(c, 6, 5, 25, 11, ramp("203020"), sunk=True)
    for i, x in enumerate((8, 12, 16, 20)):
        c.rect(x, 7, x + 2, 9, ramp("60e060")[2 + i % 2])
    c.paint(c.rect_m(4, 16, 14, 21), ramp("e8e8d8"))
    c.line(6, 18, 12, 18, DARK[2])
    c.line(6, 20, 10, 20, DARK[2])
    c.paint(c.rect_m(19, 16, 25, 25), DARK)
    c.paint(c.rect_m(21, 15, 23, 17), CHROME)
    c.line(22, 26, 22, 31, DARK[1])
    c.line(23, 26, 23, 31, DARK[0])
    c.rect(0, 29, 31, 31, t[0])


@tex("fuel_pump_side")
def tex_fuel_pump_side(c):
    t = ramp("c03a30")
    panel(c, 0, 0, 31, 31, t)
    panel(c, 3, 3, 28, 7, ramp("e8e8d8"))
    c.line(5, 5, 26, 5, t[1])
    c.paint(c.rect_m(3, 11, 28, 13), ramp("e8e8d8"), grad=False)
    c.rect(0, 29, 31, 31, t[0])


@tex("rain_barrel_side", 26, 30)
def tex_rain_barrel_side(c):
    t = ramp("3a6a9a")
    for x in range(26):
        tone = t[3] if 3 <= x <= 6 else t[4] if x == 4 else t[1] if x >= 21 else t[0] if x in (0, 25) else t[2]
        for y in range(30):
            c.set(x, y, tone)
    for y in (3, 4, 25, 26):
        for x in range(26):
            c.set(x, y, mix(c.get(x, y), t[0], 0.5 if y in (4, 26) else 0.25))
    c.line(0, 0, 25, 0, t[4])
    c.paint(c.rect_m(17, 21, 19, 23), CHROME)


@tex("rain_barrel_top", 26)
def tex_rain_barrel_top(c):
    t, w = ramp("3a6a9a"), PAL["water"]
    c.rect(0, 0, 25, 25, t[1])
    c.paint(c.ellipse_m(13, 13, 12.8, 12.8), t, grad=False)
    c.fill(c.ellipse_m(13, 13, 11, 11), t[0])
    c.fill(c.ellipse_m(13, 13.5, 10, 10), w[2])
    c.line(6, 9, 11, 7, w[4])
    c.line(14, 16, 19, 14, w[3])
    c.set(9, 18, w[3])


def main():
    os.makedirs(BLOCKS, exist_ok=True)
    for name, (fn, w, h) in TEX.items():
        c = Canvas(w, h, seed=zlib.crc32(name.encode()))
        fn(c)
        c.save(os.path.join(BLOCKS, name + ".png"))


if __name__ == "__main__":
    main()
