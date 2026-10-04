#!/usr/bin/env python3
import os
import sys
import zlib

sys.path.insert(0, os.path.dirname(__file__))
from common import BLOCKS, CLEAR, PAL, Canvas, mix, ramp  # noqa: E402
from blocks import CHROME, CONCRETE, DARK, board, nail, panel, put  # noqa: E402

TEX = {}


def tex(name):
    def reg(fn):
        TEX[name] = fn
        return fn
    return reg


def bevel(c, t):
    c.line(0, 0, 31, 0, t[3])
    c.line(0, 0, 0, 31, t[3])
    c.line(0, 31, 31, 31, t[1])
    c.line(31, 0, 31, 31, t[1])


def speckle(c, t, n):
    for _ in range(n):
        c.set(c.r.randrange(32), c.r.randrange(32), t[3] if c.r.random() < 0.5 else t[1])


@tex("bld_plaster")
def plaster(c):
    t = ramp("d6cfbc")
    c.rect(0, 0, 31, 31, t[2])
    speckle(c, t, 70)
    for x, y, n in ((5, 9, 6), (19, 22, 4)):
        for i in range(n):
            put(c, x + i, y + i // 2, t[1])
    bevel(c, t)
    c.noise(0.02)


@tex("bld_concrete")
def concrete(c):
    t = CONCRETE
    c.rect(0, 0, 31, 31, t[2])
    speckle(c, t, 120)
    for x, y in ((8, 8), (24, 8), (8, 24), (24, 24)):
        c.set(x, y, t[0])
        c.set(x + 1, y + 1, t[3])
    c.line(0, 15, 31, 15, t[1])
    c.line(0, 16, 31, 16, t[3])
    bevel(c, t)
    c.noise(0.03)


@tex("bld_corrugated")
def corrugated(c):
    t = ramp("6f7f8a")
    for x in range(32):
        tone = (t[3], t[2], t[2], t[1])[x % 4]
        for y in range(32):
            c.set(x, y, tone)
    rust = PAL["rust"]
    for _ in range(4):
        x, y = c.r.randrange(32), c.r.randrange(24)
        for i in range(c.r.randrange(3, 8)):
            c.blend(x, y + i, rust[2], 0.6)
    for x in range(1, 32, 8):
        nail(c, x, 2)
        nail(c, x, 28)
    c.noise(0.02)


@tex("bld_linoleum")
def linoleum(c):
    t = ramp("a9bfa2")
    c.rect(0, 0, 31, 31, t[2])
    for _ in range(60):
        c.set(c.r.randrange(32), c.r.randrange(32), t[1] if c.r.random() < 0.6 else t[4])
    for i in range(32):
        c.set(i, 15, t[1])
        c.set(15, i, t[1])
    bevel(c, t)
    c.noise(0.02)


SAND = ramp("b09a6c")


@tex("bld_sandbag")
def sandbag(c):
    c.rect(0, 0, 31, 31, SAND[0])
    for row, off in ((0, 0), (1, 8), (2, 0), (3, 8)):
        y0 = row * 8
        for x0 in range(-16 + off, 32, 16):
            c.paint(c.ellipse_m(x0 + 8, y0 + 4, 7.6, 3.8), SAND)
            c.line(x0 + 3, y0 + 2, x0 + 10, y0 + 2, SAND[4])
    c.noise(0.03)


@tex("bld_sandbag_top")
def sandbag_top(c):
    c.rect(0, 0, 31, 31, SAND[1])
    for x0, y0 in ((8, 8), (24, 8), (8, 24), (24, 24)):
        c.paint(c.ellipse_m(x0, y0, 7.5, 7.5), SAND)
        c.set(x0, y0, SAND[1])
    c.noise(0.03)


@tex("bld_fence")
def fence(c):
    t = PAL["steel"]
    for i in range(-32, 32, 6):
        c.line(i, 0, i + 31, 31, t[2])
        c.line(i + 31, 0, i, 31, t[1])
    c.rect(0, 0, 31, 1, t[3])
    c.rect(0, 30, 31, 31, t[1])
    c.rect(0, 0, 1, 31, t[2])
    c.rect(30, 0, 31, 31, t[1])


@tex("bld_gravestone")
def gravestone(c):
    t = ramp("8c8c90")
    c.rect(0, 0, 31, 31, t[2])
    speckle(c, t, 90)
    moss = PAL["grass"]
    for _ in range(14):
        c.blend(c.r.randrange(32), 24 + c.r.randrange(8), moss[1], 0.7)
    c.rect(14, 5, 17, 20, t[0])
    c.rect(9, 9, 22, 12, t[0])
    c.line(15, 5, 15, 20, t[1])
    for y in (24, 27):
        c.line(7, y, 24, y, t[1])
    bevel(c, t)
    c.noise(0.03)


PEW = ramp("6e4a2c")


@tex("bld_pew")
def pew(c):
    for y0, y1 in ((0, 9), (10, 20), (21, 31)):
        board(c, 0, y0, 31, y1, PEW, knots=False)
    c.noise(0.03)


@tex("bld_pew_top")
def pew_top(c):
    for x0 in (0, 8, 16, 24):
        board(c, x0, 0, x0 + 7, 31, PEW, vertical=True)
    c.noise(0.03)


TABLE = PAL["wood"]


@tex("bld_table_top")
def table_top(c):
    for y0 in (0, 8, 16, 24):
        board(c, 0, y0, 31, y0 + 7, TABLE)
    c.frame(0, 0, 31, 31, TABLE[0])
    c.noise(0.03)


@tex("bld_table_side")
def table_side(c):
    c.fill(c.rect_m(0, 0, 31, 31), CLEAR)
    board(c, 0, 0, 31, 4, TABLE, knots=False)
    c.paint(c.rect_m(1, 5, 4, 31), PAL["wood_dark"])
    c.paint(c.rect_m(27, 5, 30, 31), PAL["wood_dark"])


@tex("bld_chalkboard")
def chalkboard(c):
    frame, board_t = PAL["wood"], ramp("2f4a37")
    c.rect(0, 0, 31, 31, frame[2])
    panel(c, 2, 2, 29, 29, board_t, sunk=True)
    chalk = ramp("dcdcd2")
    for y, x1 in ((7, 20), (11, 25), (15, 14), (19, 22)):
        for x in range(5, x1):
            if c.r.random() < 0.85:
                c.set(x, y, chalk[2] if c.r.random() < 0.7 else chalk[1])
    c.line(18, 23, 26, 23, chalk[3])
    bevel(c, frame)


LOCKER = ramp("5b6f8a")


@tex("bld_locker_front")
def locker_front(c):
    panel(c, 0, 0, 31, 31, LOCKER)
    for y in (4, 7, 10):
        c.line(9, y, 22, y, LOCKER[0])
        c.line(9, y + 1, 22, y + 1, LOCKER[3])
    c.rect(25, 14, 26, 20, CHROME[2])
    c.line(25, 14, 25, 20, CHROME[4])
    c.rect(24, 22, 27, 24, DARK[1])
    c.noise(0.02)


@tex("bld_locker_side")
def locker_side(c):
    panel(c, 0, 0, 31, 31, LOCKER)
    c.noise(0.02)


ARMY = ramp("4f5a34")


def ammo(c, front):
    for y0, y1 in ((0, 10), (11, 20), (21, 31)):
        board(c, 0, y0, 31, y1, ARMY, knots=False)
    c.frame(0, 0, 31, 31, ARMY[0])
    if front:
        label = PAL["paper"]
        c.paint(c.rect_m(7, 12, 24, 19), label)
        for x in range(9, 23, 2):
            c.set(x, 15, DARK[1])
        c.rect(3, 4, 5, 7, PAL["iron"][2])
        c.rect(26, 4, 28, 7, PAL["iron"][2])
    c.noise(0.02)


tex("bld_ammo_front")(lambda c: ammo(c, True))
tex("bld_ammo_side")(lambda c: ammo(c, False))


@tex("bld_ammo_top")
def ammo_top(c):
    for x0 in (0, 11, 21):
        board(c, x0, 0, min(31, x0 + 10), 31, ARMY, vertical=True, knots=False)
    c.frame(0, 0, 31, 31, ARMY[0])
    c.noise(0.02)


@tex("bld_stained_glass")
def stained_glass(c):
    lead = DARK[0]
    colors = [ramp(x, 190) for x in ("b02828", "2848b0", "d0a020", "288a40", "8a30a0")]
    for y in range(32):
        for x in range(32):
            g = colors[((x // 8) + (y // 8) * 2 + (x + y) // 16) % len(colors)]
            c.set(x, y, g[3] if (x + y) % 8 < 2 else g[2])
    for i in range(0, 32, 8):
        c.line(i, 0, i, 31, lead)
        c.line(0, i, 31, i, lead)
    c.line(0, 0, 31, 31, lead)
    c.frame(0, 0, 31, 31, DARK[1])


MACHINE = ramp("5c7a6a")


@tex("bld_machine_front")
def machine_front(c):
    panel(c, 0, 0, 31, 31, MACHINE)
    panel(c, 5, 5, 26, 15, DARK, sunk=True)
    c.paint(c.rect_m(9, 7, 22, 12), ramp("8aa094"))
    c.paint(c.ellipse_m(23, 23, 3.5, 3.5), PAL["plastic_red"])
    c.paint(c.ellipse_m(13, 23, 2.5, 2.5), PAL["cloth_yellow"])
    for y in (28, 29):
        c.line(4, y, 27, y, mix(MACHINE[1], DARK[0], 0.5))
    c.noise(0.02)


@tex("bld_machine_side")
def machine_side(c):
    panel(c, 0, 0, 31, 31, MACHINE)
    for y in range(6, 26, 4):
        c.line(8, y, 23, y, MACHINE[0])
        c.line(8, y + 1, 23, y + 1, MACHINE[3])
    c.noise(0.02)


@tex("bld_machine_top")
def machine_top(c):
    panel(c, 0, 0, 31, 31, MACHINE)
    c.paint(c.ellipse_m(16, 16, 8, 8), PAL["steel"])
    c.fill(c.ellipse_m(16, 16, 3, 3), DARK[1])
    c.noise(0.02)


def main():
    os.makedirs(BLOCKS, exist_ok=True)
    for name, fn in TEX.items():
        c = Canvas(32, seed=zlib.crc32(name.encode()))
        fn(c)
        c.save(os.path.join(BLOCKS, name + ".png"))


if __name__ == "__main__":
    main()
