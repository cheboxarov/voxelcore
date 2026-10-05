#!/usr/bin/env python3
import math
import os
import sys
import zlib

sys.path.insert(0, os.path.dirname(__file__))
from common import BLOCKS, MODELS, Canvas, hexc, shade  # noqa: E402


class Img(Canvas):
    def __init__(self, fill=(0, 0, 0, 0), seed=0):
        super().__init__(16, seed=seed, fill=fill)

    def noise(self, base, amount=0.12):
        for y in range(16):
            for x in range(16):
                self.set(x, y, shade(base, 1 + self.r.uniform(-amount, amount)))

    def speckle(self, c, count):
        for _ in range(count):
            self.set(self.r.randrange(16), self.r.randrange(16), c)

    def save(self, folder, name):
        super().save(os.path.join(folder, name + ".png"))




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
    def block(name, seed, fn, fill=None):
        img = Img(fill or (0, 0, 0, 0), seed=seed)
        fn(img)
        img.save(BLOCKS, "decor_" + name)

    clear = (0, 0, 0, 0)
    block("metal", 500, lambda img: (img.noise(hexc("6c7074"), 0.06), img.line(0, 0, 0, 15, hexc("8a8e92"))))
    block("metal_red", 501, lambda img: img.noise(hexc("b8402e"), 0.06))
    block("rubber", 502, lambda img: (img.noise(hexc("1c1c1e"), 0.12), img.frame(4, 4, 11, 11, hexc("4a4a4e"))))

    def light(on):
        def draw(img):
            img.noise(hexc("fff4c8") if on else hexc("7c7a70"), 0.03)
            img.frame(0, 0, 15, 15, hexc("50545a"))
        return draw
    block("light_on", 503, light(True))
    block("light_off", 504, light(False))

    def traffic(lit):
        def draw(img):
            img.noise(hexc("202224"), 0.05)
            for i, (on, off) in enumerate((("ff3020", "4a1410"), ("ffc020", "4a3a10"), ("40e060", "103a1a"))):
                y = 1 + i * 5
                img.rect(5, y, 10, y + 3, hexc(on if lit == i else off))
        return draw
    block("traffic_on", 505, traffic(0))
    block("traffic_off", 506, traffic(-1))

    font = {"S": ("111", "100", "111", "001", "111"), "T": ("111", "010", "010", "010", "010"),
            "O": ("111", "101", "101", "101", "111"), "P": ("111", "101", "111", "100", "100"),
            "4": ("101", "101", "111", "001", "001"), "0": ("111", "101", "101", "101", "111")}

    def text(img, word, x0, y0, c):
        for i, ch in enumerate(word):
            for dy, row in enumerate(font[ch]):
                for dx, bit in enumerate(row):
                    if bit == "1":
                        img.set(x0 + i * 4 + dx, y0 + dy, c)

    def sign_stop(img):
        img.p = [clear] * 256
        red = hexc("c8261e")
        for y in range(16):
            cut = max(0, 4 - y, y - 11)
            img.rect(cut, y, 15 - cut, y, red)
        text(img, "STOP", 0, 5, hexc("f0f0f0"))
    block("sign_stop", 507, sign_stop)

    def sign_speed(img):
        img.p = [clear] * 256
        for y in range(16):
            for x in range(16):
                d = math.hypot(x - 7.5, y - 7.5)
                if d < 8:
                    img.set(x, y, hexc("d02a22") if d > 5.6 else hexc("f4f4f0"))
        text(img, "40", 4, 5, hexc("202020"))
    block("sign_speed", 508, sign_speed)

    def sign_crossing(img):
        img.noise(hexc("2a5ab0"), 0.03)
        img.frame(0, 0, 15, 15, hexc("f0f0f0"))
        img.line(1, 14, 14, 1, hexc("f0f0f0"))
        img.rect(7, 3, 8, 4, hexc("202020"))
        img.line(7, 5, 6, 10, hexc("202020"))
        img.line(6, 10, 4, 13, hexc("202020"))
        img.line(6, 10, 9, 13, hexc("202020"))
        img.line(7, 6, 10, 8, hexc("202020"))
    block("sign_crossing", 509, sign_crossing)
    block("sign_back", 510, lambda img: (img.noise(hexc("8a8e92"), 0.04), img.frame(0, 0, 15, 15, hexc("6a6e72"))))

    block("hydrant", 511, lambda img: (img.noise(hexc("c8301e"), 0.08), img.line(0, 3, 15, 3, hexc("e8c040"))))

    def bench(img):
        img.noise(hexc("8a5a30"), 0.08)
        for y in (0, 5, 10, 15):
            img.line(0, y, 15, y, hexc("4e3018"))
    block("bench", 512, bench)

    def trash(img):
        img.noise(hexc("3a5a3a"), 0.06)
        for x in range(1, 16, 3):
            img.line(x, 0, x, 15, hexc("2a422a"))
    block("trash", 513, trash)
    block("trash_top", 514, lambda img: (img.noise(hexc("2e4a2e"), 0.06), img.rect(6, 6, 9, 9, hexc("1a1a1a"))))

    def mailbox(img):
        img.noise(hexc("2a4a9a"), 0.05)
        img.rect(2, 2, 13, 4, hexc("e8e8e8"))
    block("mailbox", 515, mailbox)
    block("mailbox_front", 516, lambda img: (img.noise(hexc("2a4a9a"), 0.05), img.rect(3, 6, 12, 8, hexc("101010")),
                                             img.rect(12, 2, 13, 6, hexc("d02a22"))))

    def dumpster(img):
        img.noise(hexc("2e5a46"), 0.08)
        img.speckle(hexc("7a4a2a"), 20)
        img.line(0, 3, 15, 3, hexc("1e3e30"))
    block("dumpster", 517, dumpster)

    def glass(img):
        img.p = [hexc("a0c4d8", 90)] * 256
        img.frame(0, 0, 15, 15, hexc("50545a"))
        img.line(3, 12, 8, 7, hexc("e0f0ff", 140))
    block("glass", 518, glass)

    def bus_sign(img):
        img.noise(hexc("1e4a8a"), 0.03)
        img.rect(2, 4, 13, 11, hexc("f0f0f0"))
        img.rect(4, 6, 11, 9, hexc("1e4a8a"))
        img.rect(4, 10, 5, 11, hexc("202020"))
        img.rect(10, 10, 11, 11, hexc("202020"))
    block("bus_sign", 519, bus_sign)

    def fence(img):
        img.noise(hexc("e8e4d8"), 0.04)
        img.line(0, 15, 15, 15, hexc("b0aca0"))
    block("fence", 520, fence)

    def hedge(img):
        img.noise(hexc("2e5e26"), 0.18)
        img.speckle(hexc("1e3e18"), 40)
        img.speckle(hexc("4a7a36"), 20)
    block("hedge", 521, hedge)

    def soil(img):
        img.noise(hexc("4a3020"), 0.15)
        img.speckle(hexc("6a4a2a"), 30)
    block("soil", 522, soil)
    block("gravel", 523, lambda img: (img.noise(hexc("a49a86"), 0.12), img.speckle(hexc("7a7262"), 40),
                                      img.speckle(hexc("c8bea8"), 20)))
    block("slide", 524, lambda img: (img.noise(hexc("e0b020"), 0.04), img.line(0, 0, 15, 0, hexc("c08a10"))))

    def paint(name, col, seed, stripe=None):
        def draw(img):
            img.noise(hexc(col), 0.05)
            img.speckle(shade(hexc(col), 0.6), 10)
            img.speckle(hexc("6a3a20"), 6)
            if stripe:
                img.rect(0, 6, 15, 9, hexc(stripe))
            img.line(2, 11, 9, 12, shade(hexc(col), 0.5))
        block("paint_" + name, seed, draw)
    paint("red", "9a2a22", 525)
    paint("blue", "2a4a8a", 526)
    paint("white", "c8c8c0", 527)
    paint("police", "e0e0dc", 528, "1a3a9a")
    paint("army", "4e5a32", 529)

    def burnt(img):
        img.noise(hexc("262220"), 0.2)
        img.speckle(hexc("6a3a1e"), 30)
        img.speckle(hexc("4a4642"), 20)
    block("burnt", 530, burnt)

    def broken_glass(img):
        img.p = [hexc("3a4a56")] * 256
        img.noise(hexc("3a4a56"), 0.08)
        img.line(2, 1, 8, 8, hexc("b0c8d8"))
        img.line(8, 8, 14, 5, hexc("b0c8d8"))
        img.line(8, 8, 6, 15, hexc("b0c8d8"))
        img.rect(9, 10, 13, 13, hexc("101418"))
    block("broken_glass", 531, broken_glass)

    def bus_side(img):
        img.noise(hexc("e0a81e"), 0.04)
        for x in range(0, 16, 4):
            img.rect(x + 1, 3, x + 3, 7, hexc("2a3a46"))
        img.line(0, 10, 15, 10, hexc("202020"))
        img.speckle(hexc("6a3a1e"), 6)
    block("bus_side", 532, bus_side)
    block("bus_roof", 533, lambda img: (img.noise(hexc("d8d4c8"), 0.05), img.speckle(hexc("8a8478"), 10)))

    def bus_under(img):
        img.noise(hexc("2a2a2a"), 0.12)
        img.rect(0, 6, 15, 9, hexc("3a3a3a"))
        img.speckle(hexc("6a3a1e"), 16)
    block("bus_under", 534, bus_under)

    def bus_front(img):
        img.noise(hexc("e0a81e"), 0.04)
        img.rect(1, 2, 14, 8, hexc("2a3a46"))
        img.line(3, 3, 7, 7, hexc("b0c8d8"))
        img.rect(1, 11, 3, 12, hexc("f0f0c0"))
        img.rect(12, 11, 14, 12, hexc("f0f0c0"))
    block("bus_front", 535, bus_front)

    block("heli", 536, lambda img: (img.noise(hexc("4a5432"), 0.07), img.speckle(hexc("2a2a22"), 14),
                                    img.rect(5, 6, 10, 9, hexc("e8e8e0"))))

    def barrier(img):
        for y in range(16):
            for x in range(16):
                img.set(x, y, hexc("e86a1a") if ((x + y) // 4) % 2 == 0 else hexc("f0f0f0"))
    block("barrier", 537, barrier)

    def tape(img):
        img.p = [clear] * 256
        for x in range(16):
            img.rect(x, 6, x, 9, hexc("f0d020") if (x // 3) % 2 == 0 else hexc("202020"))
    block("tape", 538, tape)

    def sandbag(img):
        img.noise(hexc("a08a5e"), 0.1)
        img.frame(0, 0, 15, 15, hexc("6e5c3a"))
        img.line(0, 7, 15, 7, hexc("7e6a46"))
    block("sandbag", 539, sandbag)

    def army_crate(img):
        img.noise(hexc("4e5a32"), 0.06)
        img.frame(0, 0, 15, 15, hexc("2e361e"))
        img.rect(4, 6, 11, 9, hexc("d8d0a0"))
        img.rect(6, 7, 9, 8, hexc("4e5a32"))
    block("army_crate", 540, army_crate)

    def tent(img):
        img.noise(hexc("4a6a3a"), 0.06)
        img.line(0, 0, 15, 0, hexc("2e4a24"))
        img.line(7, 0, 7, 15, hexc("3a5a2e"))
    block("tent", 541, tent)

    def blood(img):
        img.p = [clear] * 256
        cx, cy = img.r.uniform(5, 10), img.r.uniform(5, 10)
        for y in range(16):
            for x in range(16):
                d = math.hypot(x - cx, y - cy) + img.r.uniform(-1.5, 1.5)
                if d < 4.5:
                    img.set(x, y, hexc("6a0a0a", 235))
                elif d < 7 and img.r.random() < 0.35:
                    img.set(x, y, hexc("7a1010", 220))
        img.line(int(cx), int(cy), 15, 3, hexc("5a0808", 210))
    block("blood", 542, blood)

    def litter(img):
        img.p = [clear] * 256
        img.rect(2, 3, 6, 6, hexc("e8e4d8"))
        img.line(3, 4, 5, 4, hexc("8a8a8a"))
        img.rect(10, 9, 12, 13, hexc("c83a2a"))
        img.rect(10, 9, 12, 9, hexc("b0b0b0"))
        img.rect(4, 11, 7, 12, hexc("6a8a4a"))
        img.set(13, 3, hexc("d8c060"))
        img.set(8, 7, hexc("a0a0a0"))
    block("litter", 543, litter)

    def note(img):
        img.p = [clear] * 256
        img.rect(3, 2, 12, 13, hexc("f0ead0"))
        for y in range(4, 12, 2):
            img.line(4, y, 11, y, hexc("5a5a7a"))
    block("note", 544, note)

    def firepit(img):
        img.noise(hexc("3a3430"), 0.15)
        img.frame(1, 1, 14, 14, hexc("8a8680"))
        img.speckle(hexc("1a1a1a"), 20)
        img.rect(6, 6, 9, 9, hexc("4a3a2a"))
    block("firepit", 545, firepit)

    def roof(name, col):
        def draw(img):
            img.noise(hexc(col), 0.1)
            dark = shade(hexc(col), 0.65)
            for y in range(0, 16, 4):
                img.line(0, y, 15, y, dark)
                off = 0 if (y // 4) % 2 == 0 else 4
                for x in range(off, 16, 8):
                    img.line(x, y, x, y + 3, dark)
        block("roof_" + name, zlib.crc32(name.encode()) & 0xFFFF, draw)
    roof("grey", "5a5e64")
    roof("green", "3e5a44")

    def workbench(img):
        img.noise(hexc("9a7444"), 0.08)
        img.rect(2, 3, 6, 4, hexc("8a8a8a"))
        img.rect(9, 9, 13, 10, hexc("c03030"))
        img.line(3, 11, 7, 7, hexc("5a5a5a"))
    block("workbench_top", 546, workbench)
    block("workbench_side", 547, lambda img: (img.noise(hexc("7a5a34"), 0.08), img.frame(0, 0, 15, 15, hexc("4e3820")),
                                              img.rect(3, 5, 12, 8, hexc("5e4428"))))
    block("ceramic", 548, lambda img: (img.noise(hexc("e8eae8"), 0.03), img.frame(0, 0, 15, 15, hexc("c8cac8"))))

    def desk(img):
        img.noise(hexc("6a4a2e"), 0.07)
        img.rect(2, 3, 13, 6, hexc("4e3420"))
        img.rect(2, 9, 13, 12, hexc("4e3420"))
        img.rect(7, 4, 8, 4, hexc("c0a040"))
        img.rect(7, 10, 8, 10, hexc("c0a040"))
    block("desk", 549, desk)

    def bookshelf(img):
        img.noise(hexc("6a4a2e"), 0.06)
        for y0 in (1, 5, 9, 13):
            x = 1
            while x < 15:
                w = 1 + img.r.randrange(2)
                col = img.r.choice(("8a2a22", "2a4a7a", "3a6a3a", "c8a040", "5a3a6a", "d8d0c0"))
                img.rect(x, y0, min(14, x + w - 1), y0 + 2, hexc(col))
                x += w
            img.line(0, y0 + 3, 15, y0 + 3, hexc("4a3020"))
    block("bookshelf", 550, bookshelf)

    def toys(img):
        img.noise(hexc("d06a8a"), 0.05)
        img.frame(0, 0, 15, 15, hexc("8a3a5a"))
        img.rect(3, 4, 6, 7, hexc("f0d040"))
        img.rect(9, 8, 12, 11, hexc("40a0e0"))
    block("toybox", 551, toys)

    def concrete(img):
        img.noise(hexc("8e8c88"), 0.07)
        img.speckle(hexc("74726e"), 18)
    block("concrete", 552, concrete)


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
        B((0.58, 0, 0.12), (0.98, 0.74, 0.88), "blocks:wood_side", {"north": "blocks:decor_desk"}),
        B((0.04, 0, 0.14), (0.12, 0.74, 0.22), "blocks:wood_side"),
        B((0.04, 0, 0.78), (0.12, 0.74, 0.86), "blocks:wood_side"),
        B((0.2, 0.82, 0.55), (0.45, 0.85, 0.8), "blocks:decor_note"),
    ])


if __name__ == "__main__":
    os.makedirs(MODELS, exist_ok=True)
    detail_textures()
    detail_models()
