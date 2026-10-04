#!/usr/bin/env python3
import os
import sys
import zlib

sys.path.insert(0, os.path.dirname(__file__))
from common import BLOCKS, CLEAR, PAL, Canvas, mix, ramp  # noqa: E402
from blocks import board, nail, put  # noqa: E402

TEX = {}


def tex(name, w=32, h=None):
    def reg(fn):
        TEX[name] = (fn, w, h or w)
        return fn
    return reg


SOIL = PAL["soil"]
DIRT = ramp("6b4a2e")
NEEDLES = ramp("2c4a2c")
LEAF = ramp("6e9a3a")
STONE = PAL["stone"]
MOSS = ramp("4e6e34")
STRAW = ramp("c8a850")


def speckle(c, n, tones, x0=0, y0=0, x1=31, y1=31):
    for _ in range(n):
        put(c, c.r.randint(x0, x1), c.r.randint(y0, y1), c.r.choice(tones))


def ground(c, t, y0=0, y1=31):
    c.rect(0, y0, 31, y1, t[2])
    speckle(c, 60, (t[1], t[3]), 0, y0, 31, y1)
    speckle(c, 14, (t[0], t[4]), 0, y0, 31, y1)


@tex("nature_podzol")
def podzol(c):
    ground(c, ramp("5a4128"))
    for _ in range(40):
        x, y = c.r.randrange(32), c.r.randrange(32)
        t = c.r.choice((ramp("8a6a3a"), NEEDLES, ramp("a07a40")))
        dx = c.r.choice((-1, 1))
        put(c, x, y, t[3])
        put(c, x + dx, y + 1, t[2])
        put(c, x + 2 * dx, y + 2, t[1])
    c.noise(0.03)


@tex("nature_podzol_side")
def podzol_side(c):
    ground(c, DIRT)
    ground(c, ramp("5a4128"), 0, 4)
    for x in range(32):
        if c.r.random() < 0.5:
            c.set(x, 5, ramp("5a4128")[1])
    c.noise(0.03)


@tex("nature_mud")
def mud(c):
    t = ramp("4a3a28")
    ground(c, t)
    for _ in range(6):
        cx, cy = c.r.randrange(4, 28), c.r.randrange(4, 28)
        c.fill(c.ellipse_m(cx, cy, c.r.uniform(2, 4), c.r.uniform(1.2, 2.2)), t[1])
        c.set(cx - 1, cy - 1, mix(t[3], PAL["water"][3], 0.4))
    c.noise(0.03)


@tex("nature_dirt_path")
def dirt_path(c):
    t = ramp("8a6e4a")
    ground(c, t)
    for y in (8, 22):
        for x in range(32):
            c.set(x, y + (x // 7) % 2, t[1])
            put(c, x, y + 1 + (x // 7) % 2, t[0] if c.r.random() < 0.2 else t[1])
    speckle(c, 10, (STONE[3], STONE[1]))
    c.noise(0.03)


@tex("nature_dirt_path_side")
def dirt_path_side(c):
    ground(c, DIRT)
    ground(c, ramp("8a6e4a"), 0, 3)
    c.noise(0.03)


@tex("nature_mossy_stone")
def mossy_stone(c):
    t = STONE
    for i, (x0, y0, x1, y1) in enumerate(((0, 0, 14, 11), (15, 0, 31, 13), (0, 12, 19, 31), (20, 14, 31, 31))):
        c.paint(c.rect_m(x0, y0, x1, y1), t)
    speckle(c, 40, (t[1], t[3]))
    for _ in range(9):
        x, y = c.r.randrange(30), c.r.randrange(30)
        c.paint(c.ellipse_m(x, y, c.r.uniform(1.5, 3.5), c.r.uniform(1, 2)), MOSS, grad=False)
    c.noise(0.03)


def bark(c, t, dark):
    c.rect(0, 0, 31, 31, t[2])
    for x in range(0, 32, 4):
        off = c.r.choice((-1, 0, 1))
        for y in range(32):
            c.set((x + off + (y // 9) % 2) % 32, y, dark)
            if c.r.random() < 0.3:
                put(c, x + off + 1, y, t[1])
    speckle(c, 30, (t[3], t[1]))


@tex("nature_spruce_bark")
def spruce_bark(c):
    t = ramp("5a4030")
    bark(c, t, t[0])
    c.noise(0.03)


def rings(c, outer, inner):
    c.rect(0, 0, 31, 31, inner[2])
    for r, tone in ((13, inner[1]), (9, inner[3]), (5, inner[1]), (2, inner[0])):
        c.fill(c.ellipse_m(16, 16, r, r) - c.ellipse_m(16, 16, r - 1, r - 1), tone)
    c.fill(c.rect_m(0, 0, 31, 31) - c.ellipse_m(16, 16, 15.5, 15.5), outer[2])
    c.frame(0, 0, 31, 31, outer[1])
    c.noise(0.03)


@tex("nature_spruce_top")
def spruce_top(c):
    rings(c, ramp("5a4030"), ramp("b08a5a"))


@tex("nature_birch_bark")
def birch_bark(c):
    t = ramp("e4e0d4")
    c.rect(0, 0, 31, 31, t[2])
    speckle(c, 50, (t[1], t[3]))
    for _ in range(12):
        x, y = c.r.randrange(30), c.r.randrange(32)
        n = c.r.randrange(2, 7)
        c.line(x, y, x + n, y, ramp("2a2a26")[2])
        put(c, x + n // 2, y + 1, ramp("2a2a26")[1])
    c.noise(0.02)


@tex("nature_birch_top")
def birch_top(c):
    rings(c, ramp("e4e0d4"), ramp("d8c49a"))


def foliage(c, t, holes, needles=False, berries=None):
    c.rect(0, 0, 31, 31, t[2])
    for _ in range(70):
        x, y = c.r.randrange(32), c.r.randrange(32)
        if needles:
            c.line(x, y, x + 2, y + 2, t[3] if c.r.random() < 0.5 else t[1])
        else:
            c.paint(c.ellipse_m(x, y, 1.6, 1.2), t, grad=False)
    speckle(c, 30, (t[0], t[4]))
    for _ in range(holes):
        x, y = c.r.randrange(32), c.r.randrange(32)
        c.set(x, y, CLEAR)
        put(c, x + 1, y, CLEAR)
    for _ in range(berries or 0):
        x, y = c.r.randrange(1, 31), c.r.randrange(1, 31)
        c.set(x, y, ramp("b02a2a")[3])
        put(c, x + 1, y + 1, ramp("b02a2a")[1])


@tex("nature_spruce_leaves")
def spruce_leaves(c):
    foliage(c, NEEDLES, 40, needles=True)


@tex("nature_birch_leaves")
def birch_leaves(c):
    foliage(c, LEAF, 50)


@tex("nature_bush")
def bush(c):
    foliage(c, ramp("3e6a2c"), 60, berries=7)


def blades(c, tones, count, tall):
    for _ in range(count):
        x = c.r.randrange(2, 30)
        h = c.r.randrange(tall // 2, tall)
        lean = c.r.uniform(-5, 5)
        t = c.r.choice(tones)
        for k in range(h):
            f = k / h
            c.set(round(x + lean * f * f), 31 - k, t[1] if f < 0.3 else t[2] if f < 0.8 else t[3])


@tex("nature_tall_grass")
def tall_grass(c):
    blades(c, (ramp("4a8a30"), ramp("5ea03a"), ramp("8a9a40")), 26, 31)


@tex("nature_reeds")
def reeds(c):
    blades(c, (ramp("6a8a3a"), ramp("8a9a4a")), 16, 31)
    for x in (8, 18, 25):
        c.paint(c.rect_m(x, 3, x + 1, 10), ramp("5a3a20"), grad=False)
        c.line(x, 0, x, 2, ramp("6a8a3a")[2])


@tex("nature_fern")
def fern(c):
    t = ramp("3e7a30")
    for x0, lean in ((8, -6), (16, 0), (23, 6)):
        for k in range(24):
            f = k / 24
            cx, cy = round(x0 + lean * f), 31 - k
            c.set(cx, cy, t[1])
            if k > 4 and k % 2 == 0:
                w = max(1, round(5 * (1 - f)))
                c.line(cx - w, cy - 1, cx - 1, cy, t[3])
                c.line(cx + 1, cy, cx + w, cy - 1, t[2])


def flowers(petal):
    def draw(c):
        stem = ramp("3a7a2a")
        p = ramp(petal)
        for x, top in ((6, 12), (14, 8), (22, 14), (27, 18)):
            c.line(x, 31, x, top, stem[2])
            c.line(x, 24, x - 2, 22, stem[3])
            c.paint(c.ellipse_m(x + 0.5, top + 0.5, 2.6, 2.6), p, grad=False)
            c.set(x, top, ramp("e8c030")[3])
    return draw


tex("nature_flower_blue")(flowers("4a6ad8"))
tex("nature_flower_yellow")(flowers("e8d030"))
tex("nature_flower_white")(flowers("f0f0e8"))


@tex("nature_mushroom")
def mushroom(c):
    stem, cap = ramp("e8dcc0"), ramp("a83a22")
    for x, s in ((10, 4), (22, 3)):
        c.paint(c.rect_m(x - 1, 31 - s * 3, x + 1, 31), stem)
        c.paint(c.ellipse_m(x + 0.5, 31 - s * 3, s + 2, s * 0.9), cap)
        speckle(c, 3, (ramp("f0e8e0")[4],), x - s, 31 - s * 4, x + s, 31 - s * 3)


@tex("nature_barn_wood")
def barn_wood(c):
    for i, x0 in enumerate((0, 8, 16, 24)):
        board(c, x0, 0, x0 + 7, 31, ramp(("8e2e24", "862a22", "962f25", "8a2c23")[i]), vertical=True)
    for y in (3, 28):
        for x in (3, 11, 19, 27):
            nail(c, x, y)
    c.noise(0.03)


@tex("nature_hay_side")
def hay_side(c):
    t = STRAW
    c.rect(0, 0, 31, 31, t[2])
    for _ in range(80):
        x, y = c.r.randrange(31), c.r.randrange(32)
        c.line(x, y, x + c.r.randrange(2, 5), y, c.r.choice((t[1], t[3], t[4])))
    for x in (8, 23):
        c.paint(c.rect_m(x, 0, x + 1, 31), ramp("6a5020"), grad=False)


@tex("nature_hay_top")
def hay_top(c):
    t = STRAW
    c.rect(0, 0, 31, 31, t[2])
    for _ in range(90):
        x, y = c.r.randrange(32), c.r.randrange(32)
        c.line(x, y, x + c.r.choice((-2, 2)), y + c.r.choice((-1, 1)), c.r.choice((t[1], t[3], t[4])))


def canvas(base):
    def draw(c):
        t = ramp(base)
        c.rect(0, 0, 31, 31, t[2])
        for y in range(0, 32, 8):
            c.line(0, y, 31, y, t[1])
            c.line(0, y + 1, 31, y + 1, t[3])
        for x in (5, 26):
            for y in range(2, 32, 8):
                put(c, x, y + 3, t[0])
        c.noise(0.02)
    return draw


tex("nature_tent_green")(canvas("4a6a3a"))
tex("nature_tent_orange")(canvas("c8642a"))


@tex("nature_trailer_siding")
def trailer_siding(c):
    t = PAL["plastic_white"]
    c.rect(0, 0, 31, 31, t[2])
    for y in range(2, 32, 5):
        c.line(0, y, 31, y, t[1])
        c.line(0, y + 1, 31, y + 1, t[3])
    c.paint(c.rect_m(0, 19, 31, 21), PAL["plastic_blue"], grad=False)
    speckle(c, 6, (PAL["rust"][2],), 0, 24, 31, 31)


def corrugated(c, t):
    for x in range(32):
        k = x % 4
        tone = t[3] if k == 0 else t[2] if k == 1 else t[1] if k == 2 else t[2]
        c.line(x, 0, x, 31, tone)
    speckle(c, 10, (PAL["rust"][2], PAL["rust"][1]))


@tex("nature_metal_roof")
def metal_roof(c):
    corrugated(c, PAL["steel"])


@tex("nature_silo")
def silo(c):
    t = ramp("b0b4b0")
    corrugated(c, t)
    for y in (0, 15, 16):
        c.line(0, y, 31, y, t[0] if y else t[1])
    for x in range(2, 32, 8):
        nail(c, x, 13)


@tex("nature_fence")
def fence(c):
    t = PAL["wood"]
    for x0 in (0, 28):
        board(c, x0, 0, x0 + 3, 31, t, vertical=True, knots=False)
    for y0 in (6, 20):
        board(c, 0, y0, 31, y0 + 4, ramp("9a7444"), knots=False)
        nail(c, 1, y0 + 1)
        nail(c, 29, y0 + 1)


@tex("nature_fence_end")
def fence_end(c):
    board(c, 0, 0, 31, 31, PAL["wood"], vertical=True, knots=False)


def main():
    os.makedirs(BLOCKS, exist_ok=True)
    for name, (fn, w, h) in TEX.items():
        c = Canvas(w, h, seed=zlib.crc32(name.encode()))
        fn(c)
        c.save(os.path.join(BLOCKS, name + ".png"))


if __name__ == "__main__":
    main()
