#!/usr/bin/env python3
import os

from common import BLOCKS, PAL, Canvas


def fence():
    img = Canvas(seed=501)
    wood = PAL["wood_pale"]
    for x0 in (1, 6, 11):
        img.rect(x0, 2, x0 + 3, 15, wood[2])
        img.line(x0, 2, x0, 15, wood[1])
        img.rect(x0 + 1, 1, x0 + 2, 1, wood[3])
    img.rect(0, 5, 15, 6, wood[1])
    img.rect(0, 11, 15, 12, wood[1])
    img.noise(0.05)
    img.save(os.path.join(BLOCKS, "layout_fence.png"))

    img = Canvas(seed=502)
    img.rect(0, 0, 15, 15, wood[2])
    img.frame(0, 0, 15, 15, wood[1])
    img.save(os.path.join(BLOCKS, "layout_fence_top.png"))


def railing():
    img = Canvas(seed=503)
    steel = PAL["steel"]
    for x in (0, 7, 15):
        img.rect(x, 3, x, 15, steel[1])
    img.rect(0, 2, 15, 3, steel[3])
    img.line(0, 9, 15, 9, steel[2])
    img.save(os.path.join(BLOCKS, "layout_railing.png"))

    img = Canvas(seed=504)
    img.rect(0, 0, 15, 15, steel[2])
    img.frame(0, 0, 15, 15, steel[1])
    img.save(os.path.join(BLOCKS, "layout_railing_top.png"))


if __name__ == "__main__":
    fence()
    railing()
