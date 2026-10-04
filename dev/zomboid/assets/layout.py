#!/usr/bin/env python3
import os

from common import BLOCKS, CLEAR, PAL, Canvas


def fence():
    img = Canvas(32, seed=501)
    wood = PAL["wood_pale"]
    for y0 in (9, 22):
        img.rect(0, y0, 31, y0 + 2, wood[1])
        img.line(0, y0, 31, y0, wood[2])
        img.line(0, y0 + 3, 31, y0 + 3, wood[0])
    for x0 in (1, 9, 17, 25):
        img.paint(img.poly_m([(x0, 4), (x0 + 3, 1), (x0 + 6, 4), (x0 + 6, 32), (x0, 32)]), wood)
        for y in range(6, 31, 7):
            img.set(x0 + 2 + y % 3, y, wood[1])
        for y in (10, 23):
            img.set(x0 + 3, y, PAL["iron"][1])
    img.noise(0.03)
    img.save(os.path.join(BLOCKS, "layout_fence.png"))

    img = Canvas(32, seed=502)
    img.paint(img.rect_m(0, 0, 31, 31) - img.rect_m(4, 4, 27, 27), wood)
    img.fill(img.rect_m(4, 4, 27, 27), CLEAR)
    img.noise(0.03)
    img.save(os.path.join(BLOCKS, "layout_fence_top.png"))


def railing():
    img = Canvas(32, seed=503)
    steel = PAL["steel"]
    for x in (0, 16):
        img.rect(x, 4, x + 1, 31, steel[2])
        img.line(x, 4, x, 31, steel[3])
        img.line(x + 1, 4, x + 1, 31, steel[1])
    img.rect(0, 2, 31, 4, steel[2])
    img.line(0, 2, 31, 2, steel[4])
    img.line(0, 5, 31, 5, steel[0])
    img.line(0, 17, 31, 17, steel[3])
    img.line(0, 18, 31, 18, steel[1])
    for x in (2, 18):
        img.set(x, 6, steel[0])
    img.save(os.path.join(BLOCKS, "layout_railing.png"))

    img = Canvas(32, seed=504)
    img.paint(img.rect_m(0, 0, 31, 31) - img.rect_m(3, 3, 28, 28), steel)
    img.save(os.path.join(BLOCKS, "layout_railing_top.png"))


if __name__ == "__main__":
    fence()
    railing()
