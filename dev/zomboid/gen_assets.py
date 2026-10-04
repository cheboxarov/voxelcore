#!/usr/bin/env python3
import math
import os
import random
import struct
import wave
import zlib

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "res", "content", "zomboid")
BLOCKS = os.path.join(ROOT, "textures", "blocks")
SOUNDS = os.path.join(ROOT, "sounds")


def save_png(path, pixels, w=16, h=16):
    raw = b"".join(
        b"\x00" + b"".join(struct.pack("BBBB", *pixels[y * w + x]) for x in range(w))
        for y in range(h)
    )

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (c[3],)


class Img:
    def __init__(self, fill=(0, 0, 0, 0), seed=0):
        self.p = [fill] * 256
        self.r = random.Random(seed)

    def set(self, x, y, c):
        if 0 <= x < 16 and 0 <= y < 16:
            self.p[y * 16 + x] = c

    def get(self, x, y):
        return self.p[y * 16 + x]

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def frame(self, x0, y0, x1, y1, c):
        for x in range(x0, x1 + 1):
            self.set(x, y0, c)
            self.set(x, y1, c)
        for y in range(y0, y1 + 1):
            self.set(x0, y, c)
            self.set(x1, y, c)

    def line(self, x0, y0, x1, y1, c):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            self.set(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)

    def noise(self, base, amount=0.12, x0=0, y0=0, x1=15, y1=15):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, shade(base, 1 + self.r.uniform(-amount, amount)))

    def speckle(self, c, count):
        for _ in range(count):
            self.set(self.r.randrange(16), self.r.randrange(16), c)

    def save(self, folder, name):
        save_png(os.path.join(folder, name + ".png"), self.p)


def block_textures():
    asphalt = hexc("3a3a3e")
    img = Img(seed=1)
    img.noise(asphalt, 0.18)
    img.speckle(hexc("55555a"), 14)
    img.save(BLOCKS, "asphalt")

    img = Img(seed=2)
    img.noise(asphalt, 0.18)
    img.speckle(hexc("55555a"), 10)
    img.rect(7, 0, 8, 15, hexc("d8b23a"))
    img.save(BLOCKS, "road_line")

    img = Img(seed=3)
    img.noise(hexc("9a9a96"), 0.08)
    img.frame(0, 0, 15, 15, hexc("7c7c78"))
    img.line(0, 7, 15, 7, hexc("858581"))
    img.save(BLOCKS, "sidewalk")

    for name, col in [("white", "d9d4c7"), ("blue", "6f8fae"), ("yellow", "cdb56a"),
                      ("green", "7f9a6e"), ("red", "9c5a4c")]:
        img = Img(seed=zlib.crc32(name.encode()) & 0xFFFF)
        base = hexc(col)
        img.noise(base, 0.05)
        for y in range(0, 16, 4):
            img.line(0, y, 15, y, shade(base, 0.72))
            img.line(0, y + 1, 15, y + 1, shade(base, 1.08))
        img.save(BLOCKS, "siding_" + name)

    img = Img(seed=11)
    img.noise(hexc("5b4038"), 0.1)
    for y in range(0, 16, 4):
        img.line(0, y, 15, y, hexc("3e2a24"))
        off = 0 if (y // 4) % 2 == 0 else 4
        for x in range(off, 16, 8):
            img.line(x, y, x, y + 3, hexc("3e2a24"))
    img.save(BLOCKS, "roof")

    img = Img(seed=12)
    img.noise(hexc("6d5a45"), 0.08)
    img.frame(0, 0, 15, 15, hexc("4a3c2e"))
    img.save(BLOCKS, "trim")

    frame = hexc("e6e2d8")
    glass = hexc("9ec6d8", 120)
    img = Img(glass, seed=13)
    img.frame(0, 0, 15, 15, frame)
    img.line(0, 8, 15, 8, frame)
    img.line(2, 3, 5, 6, hexc("d8f0ff", 170))
    img.line(10, 10, 12, 12, hexc("d8f0ff", 170))
    img.save(BLOCKS, "window")

    img = Img((0, 0, 0, 0), seed=14)
    img.frame(0, 0, 15, 15, frame)
    img.line(0, 8, 15, 8, frame)
    for (x, y) in [(1, 1), (2, 1), (1, 2), (14, 1), (13, 1), (14, 2), (1, 14), (2, 13), (14, 14), (13, 13),
                   (5, 1), (6, 2), (9, 9), (10, 9), (1, 9), (14, 10)]:
        img.set(x, y, hexc("9ec6d8", 160))
    img.save(BLOCKS, "window_broken")

    for level in range(1, 5):
        img = Img((0, 0, 0, 0), seed=20 + level)
        img.frame(0, 0, 15, 15, frame)
        rows = [(1, 3), (5, 7), (9, 11), (13, 15)][:level]
        plank = hexc("a07a4a")
        for i, (a, b) in enumerate(rows):
            for y in range(a, min(b, 15) + 1):
                for x in range(16):
                    tilt = (x // 6 + i) % 2
                    img.set(x, y + tilt if y + tilt <= 15 else y, shade(plank, 1 + img.r.uniform(-0.1, 0.1)))
            img.set(2, a + 1, hexc("303030"))
            img.set(13, a + 1, hexc("303030"))
        img.save(BLOCKS, "barricade_%d" % level)

    for level in range(1, 5):
        img = Img(seed=30 + level)
        img.noise(hexc("7a5532"), 0.08)
        img.frame(0, 0, 15, 15, hexc("54391f"))
        rows = [(1, 3), (5, 7), (9, 11), (13, 15)][:level]
        for i, (a, b) in enumerate(rows):
            for y in range(a, min(b, 15) + 1):
                for x in range(16):
                    img.set(x, y, shade(hexc("b38a55"), 1 + img.r.uniform(-0.1, 0.1)))
            img.set(2, a + 1, hexc("303030"))
            img.set(13, a + 1, hexc("303030"))
        img.save(BLOCKS, "door_barricade_%d" % level)

    white = hexc("e8e8e4")
    img = Img(seed=40)
    img.noise(white, 0.03)
    img.frame(0, 0, 15, 15, hexc("b8b8b4"))
    img.line(0, 5, 15, 5, hexc("a0a09c"))
    img.rect(12, 2, 13, 3, hexc("808080"))
    img.rect(12, 8, 13, 11, hexc("808080"))
    img.save(BLOCKS, "fridge_front")
    img = Img(seed=41)
    img.noise(white, 0.03)
    img.frame(0, 0, 15, 15, hexc("c8c8c4"))
    img.save(BLOCKS, "fridge_side")

    wood = hexc("8a6038")
    img = Img(seed=42)
    img.noise(wood, 0.07)
    img.frame(0, 0, 15, 15, shade(wood, 0.7))
    img.line(7, 1, 7, 14, shade(wood, 0.7))
    img.line(8, 1, 8, 14, shade(wood, 0.8))
    img.rect(5, 7, 5, 8, hexc("d0b060"))
    img.rect(10, 7, 10, 8, hexc("d0b060"))
    img.save(BLOCKS, "wardrobe_front")
    img = Img(seed=43)
    img.noise(wood, 0.07)
    img.frame(0, 0, 15, 15, shade(wood, 0.7))
    for y in range(3, 16, 4):
        img.line(1, y, 14, y, shade(wood, 0.85))
    img.save(BLOCKS, "wood_side")

    cab = hexc("b49a72")
    img = Img(seed=44)
    img.noise(cab, 0.05)
    img.frame(0, 0, 15, 15, shade(cab, 0.7))
    img.rect(1, 1, 14, 3, shade(cab, 0.85))
    img.line(7, 4, 7, 14, shade(cab, 0.7))
    img.rect(5, 8, 5, 9, hexc("505050"))
    img.rect(10, 8, 10, 9, hexc("505050"))
    img.save(BLOCKS, "cabinet_front")
    img = Img(seed=45)
    img.noise(hexc("c9c6bf"), 0.04)
    img.frame(0, 0, 15, 15, hexc("9a968f"))
    img.save(BLOCKS, "counter_top")

    img = Img(seed=46)
    img.noise(hexc("707478"), 0.05)
    img.frame(0, 0, 15, 15, hexc("4c5054"))
    for y in (5, 10):
        img.line(1, y, 14, y, hexc("3a3d40"))
    for y, cols in ((2, ["c84a3a", "e0c040", "4a80c8"]), (7, ["58a050", "c87a3a", "e8e8e8"]), (12, ["a04a8a", "c8c050", "5aa0a0"])):
        for i, c in enumerate(cols):
            img.rect(2 + i * 4, y, 4 + i * 4, y + 2, hexc(c))
    img.save(BLOCKS, "shelf_front")

    img = Img(seed=47)
    img.noise(hexc("a8834e"), 0.1)
    img.frame(0, 0, 15, 15, hexc("6f5230"))
    img.line(0, 0, 15, 15, hexc("6f5230"))
    img.line(15, 0, 0, 15, hexc("6f5230"))
    img.save(BLOCKS, "crate")

    img = Img(seed=48)
    img.noise(hexc("f0f0f0"), 0.03)
    img.frame(0, 0, 15, 15, hexc("b0b0b0"))
    img.rect(6, 3, 9, 12, hexc("d03030"))
    img.rect(3, 6, 12, 9, hexc("d03030"))
    img.save(BLOCKS, "medcab_front")

    img = Img(seed=49)
    img.noise(hexc("d8d8d8"), 0.03)
    img.rect(2, 2, 13, 13, hexc("a8b4bc"))
    img.frame(2, 2, 13, 13, hexc("8090a0"))
    img.rect(7, 1, 8, 4, hexc("909090"))
    img.save(BLOCKS, "sink_top")

    img = Img(seed=50)
    img.noise(hexc("e4e4e0"), 0.03)
    for (cx, cy) in ((4, 4), (11, 4), (4, 11), (11, 11)):
        img.frame(cx - 2, cy - 2, cx + 2, cy + 2, hexc("303030"))
        img.set(cx, cy, hexc("505050"))
    img.save(BLOCKS, "stove_top")
    img = Img(seed=51)
    img.noise(hexc("e4e4e0"), 0.03)
    img.rect(2, 4, 13, 13, hexc("252525"))
    img.frame(2, 4, 13, 13, hexc("909090"))
    img.line(3, 2, 12, 2, hexc("909090"))
    img.save(BLOCKS, "stove_front")

    img = Img(seed=52)
    img.noise(hexc("e8e4dc"), 0.04)
    img.rect(0, 0, 15, 4, hexc("f4f4f4"))
    img.rect(0, 5, 15, 15, hexc("5a74a8"))
    for x in range(0, 16, 3):
        img.line(x, 5, x, 15, hexc("4e6698"))
    img.save(BLOCKS, "bed_top")
    img = Img(seed=53)
    img.noise(hexc("6d4a2a"), 0.07)
    img.rect(0, 0, 15, 6, hexc("5a74a8"))
    img.save(BLOCKS, "bed_side")

    img = Img(seed=54)
    img.noise(hexc("7a3a3a"), 0.08)
    img.frame(0, 0, 15, 15, hexc("5a2626"))
    img.save(BLOCKS, "couch")

    img = Img(seed=55)
    for y in range(16):
        for x in range(16):
            img.set(x, y, hexc("dcdcd4") if ((x // 4) + (y // 4)) % 2 == 0 else hexc("b4b4ac"))
    img.save(BLOCKS, "tiles")

    img = Img(seed=56)
    img.noise(hexc("8a4c3a"), 0.12)
    img.speckle(hexc("6e3a2c"), 30)
    img.save(BLOCKS, "carpet")

    img = Img((0, 0, 0, 0), seed=57)
    for i, (a, b) in enumerate([(2, 13), (13, 2)]):
        img.line(a, 13, b, 9 + i, hexc("6d4a2a"))
        img.line(a, 14, b, 10 + i, hexc("5a3c22"))
    img.rect(5, 11, 10, 15, hexc("3a3a3a"))
    img.save(BLOCKS, "campfire_side")
    img = Img(seed=58)
    img.noise(hexc("4a3a30"), 0.1)
    img.rect(5, 5, 10, 10, hexc("e08a30"))
    img.rect(6, 6, 9, 9, hexc("f4d060"))
    img.save(BLOCKS, "campfire_top")

    img = Img((0, 0, 0, 0), seed=59)
    for y in range(9, 16):
        for x in range(16):
            if img.r.random() < 0.35:
                img.set(x, y, hexc("7a1010", 220))
    img.rect(5, 12, 9, 14, hexc("6a0c0c", 230))
    img.save(BLOCKS, "blood")

    # zombie body parts
    skin = hexc("7f9a6a")
    img = Img(seed=60)
    img.noise(skin, 0.1)
    img.speckle(hexc("5c7048"), 10)
    img.speckle(hexc("6a2020"), 4)
    img.save(BLOCKS, "z_skin")
    img = Img(seed=61)
    img.noise(skin, 0.08)
    img.rect(3, 5, 5, 6, hexc("e8e070"))
    img.rect(10, 5, 12, 6, hexc("e8e070"))
    img.set(4, 6, hexc("801010"))
    img.set(11, 6, hexc("801010"))
    img.rect(4, 10, 11, 12, hexc("301818"))
    for x in range(5, 11, 2):
        img.set(x, 10, hexc("d8d0b0"))
    img.speckle(hexc("6a2020"), 5)
    img.save(BLOCKS, "z_face")
    for name, col in [("red", "8a3030"), ("blue", "34507a"), ("green", "4a6a3a"),
                      ("gray", "707070"), ("white", "c8c4b8"), ("police", "1e2a48")]:
        img = Img(seed=zlib.crc32(name.encode()) & 0xFF)
        img.noise(hexc(col), 0.1)
        for _ in range(6):
            x, y = img.r.randrange(16), img.r.randrange(16)
            img.rect(x, y, x + 1, y + 1, hexc("5a1414"))
        img.speckle(shade(hexc(col), 0.6), 8)
        img.save(BLOCKS, "z_shirt_" + name)
    for name, col in [("jeans", "3a4a66"), ("brown", "5a4632"), ("black", "2a2a2e")]:
        img = Img(seed=zlib.crc32(name.encode()) & 0xFF)
        img.noise(hexc(col), 0.1)
        img.speckle(hexc("4a1010"), 6)
        img.save(BLOCKS, "z_pants_" + name)


def icon():
    w = h = 64
    r = random.Random(7)
    px = []
    for y in range(h):
        for x in range(w):
            c = hexc("101410")
            if 16 <= x < 48 and 8 <= y < 40:
                c = shade(hexc("7f9a6a"), 1 + r.uniform(-0.1, 0.1))
                if 20 <= y < 26 and (22 <= x < 30 or 36 <= x < 44):
                    c = hexc("e8e070")
                if 30 <= y < 36 and 24 <= x < 40:
                    c = hexc("301818")
            elif 12 <= x < 52 and 40 <= y < 64:
                c = shade(hexc("8a3030"), 1 + r.uniform(-0.1, 0.1))
            px.append(c)
    save_png(os.path.join(ROOT, "icon.png"), px, w, h)


def save_wav(path, samples, rate=22050):
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 30000)) for s in samples))


def sounds():
    rate = 22050
    for variant in range(3):
        r = random.Random(100 + variant)
        dur = 1.1 + variant * 0.3
        base = 80 + variant * 18
        out = []
        lp = 0.0
        for i in range(int(rate * dur)):
            t = i / rate
            env = math.sin(math.pi * t / dur) ** 0.7
            f = base * (1 + 0.15 * math.sin(t * 5 + variant)) * (1 - 0.2 * t / dur)
            v = math.sin(2 * math.pi * f * t) * 0.5 + math.sin(2 * math.pi * f * 2.01 * t) * 0.25
            lp += (r.uniform(-1, 1) - lp) * 0.08
            v = (v + lp * 1.6) * (0.6 + 0.4 * math.sin(2 * math.pi * 7 * t))
            out.append(v * env * 0.8)
        save_wav(os.path.join(SOUNDS, "zombie", "groan_%d.wav" % variant), out, rate)

    def hit(path, seed, freq, dur, noise_amt):
        r = random.Random(seed)
        out = []
        for i in range(int(rate * dur)):
            t = i / rate
            env = math.exp(-t * 18)
            out.append((math.sin(2 * math.pi * freq * t * (1 - t)) * (1 - noise_amt) + r.uniform(-1, 1) * noise_amt) * env)
        save_wav(path, out, rate)

    for v in range(2):
        hit(os.path.join(SOUNDS, "player", "hit_%d.wav" % v), 200 + v, 140 + v * 30, 0.25, 0.5)
    hit(os.path.join(SOUNDS, "player", "swing.wav"), 210, 400, 0.18, 0.9)
    hit(os.path.join(SOUNDS, "player", "hurt.wav"), 220, 260, 0.35, 0.3)
    hit(os.path.join(SOUNDS, "world", "glass_break.wav"), 230, 2200, 0.5, 0.85)
    hit(os.path.join(SOUNDS, "world", "hammer.wav"), 240, 900, 0.15, 0.4)
    hit(os.path.join(SOUNDS, "world", "bash.wav"), 250, 90, 0.35, 0.6)
    hit(os.path.join(SOUNDS, "player", "eat.wav"), 260, 300, 0.3, 0.95)


def combat_assets():
    img = Img(seed=70)
    img.noise(hexc("d8d0c0"), 0.06)
    img.frame(0, 0, 15, 15, hexc("8a2020"))
    img.rect(3, 3, 12, 12, hexc("f4f0e4"))
    img.frame(3, 3, 12, 12, hexc("303030"))
    img.line(8, 8, 8, 4, hexc("202020"))
    img.line(8, 8, 11, 8, hexc("202020"))
    img.save(BLOCKS, "alarm_clock_front")
    img = Img(seed=71)
    img.noise(hexc("a02828"), 0.08)
    img.save(BLOCKS, "alarm_clock_side")
    img = Img(seed=72)
    img.noise(hexc("a02828"), 0.08)
    img.rect(2, 6, 5, 9, hexc("d8c040"))
    img.rect(10, 6, 13, 9, hexc("d8c040"))
    img.save(BLOCKS, "alarm_clock_top")
    img = Img(seed=73)
    img.noise(hexc("505458"), 0.08)
    for y in range(2, 14, 3):
        img.line(1, y, 14, y, hexc("383a3e"))
    img.rect(6, 6, 9, 9, hexc("d0b020"))
    img.save(BLOCKS, "siren_side")
    img = Img(seed=74)
    img.noise(hexc("c02020"), 0.1)
    img.rect(5, 5, 10, 10, hexc("ff6040"))
    img.save(BLOCKS, "siren_top")
    img = Img(seed=75)
    img.noise(hexc("d0a020"), 0.08)
    img.rect(0, 5, 15, 7, hexc("1a1a1a"))
    for _ in range(5):
        x, y = img.r.randrange(16), img.r.randrange(16)
        img.rect(x, y, x + 1, y + 1, hexc("5a1414"))
    img.save(BLOCKS, "z_shirt_sport")

    rate = 22050

    def write(name, dur, fn):
        r = random.Random(zlib.crc32(name.encode()))
        save_wav(os.path.join(SOUNDS, name + ".wav"), [fn(i / rate, r) for i in range(int(rate * dur))], rate)

    write("player/gunshot", 0.6, lambda t, r: (r.uniform(-1, 1) * 0.8 + math.sin(2 * math.pi * 90 * t) * 0.4)
          * math.exp(-t * 11))
    write("player/shotgun", 0.9, lambda t, r: (r.uniform(-1, 1) * 0.9 + math.sin(2 * math.pi * 60 * t) * 0.5)
          * math.exp(-t * 6))
    write("player/reload", 0.5, lambda t, r: r.uniform(-1, 1) * 0.7
          * (math.exp(-t * 60) + math.exp(-max(0, t - 0.3) * 60) * (t > 0.3)))
    write("player/dry_fire", 0.12, lambda t, r: r.uniform(-1, 1) * 0.5 * math.exp(-t * 80))
    write("world/alarm", 0.9, lambda t, r: math.sin(2 * math.pi * 1800 * t) * 0.6
          * (1 if (t * 16) % 2 < 1 else 0) * (1 if t < 0.8 else 0))
    write("world/siren", 1.0, lambda t, r: math.sin(2 * math.pi * (600 * t + 250 / math.pi * math.sin(math.pi * t)))
          * 0.8 * min(1, t * 20, (1 - t) * 20))
def world_textures():
    def block(name, seed, fn):
        img = Img(seed=seed)
        fn(img)
        img.save(BLOCKS, name)

    def lamp(on):
        def draw(img):
            img.noise(hexc("f8f0c0") if on else hexc("8a8678"), 0.04)
            img.frame(0, 0, 15, 15, hexc("d8d0a0") if on else hexc("6a6658"))
            img.rect(4, 4, 11, 11, hexc("fffbe0") if on else hexc("a09c8c"))
        return draw
    block("lamp_on", 300, lamp(True))
    block("lamp_off", 301, lamp(False))

    def metal(img, base="5a6a4a"):
        img.noise(hexc(base), 0.06)
        img.frame(0, 0, 15, 15, shade(hexc(base), 0.6))

    block("generator_side", 302, lambda img: (metal(img), img.rect(3, 4, 12, 11, hexc("303030")),
                                              [img.line(4, y, 11, y, hexc("505050")) for y in (5, 7, 9)]))
    block("generator_top", 303, lambda img: (metal(img), img.rect(5, 5, 10, 10, hexc("c0a030")),
                                             img.rect(7, 7, 8, 8, hexc("202020"))))

    def gen_front(on):
        def draw(img):
            metal(img)
            img.rect(3, 3, 8, 8, hexc("202020"))
            img.rect(10, 3, 12, 5, hexc("40e040") if on else hexc("304030"))
            img.rect(3, 11, 12, 12, hexc("303030"))
        return draw
    block("generator_front", 304, gen_front(False))
    block("generator_front_on", 305, gen_front(True))

    def pump_front(img):
        metal(img, "c03a30")
        img.rect(3, 2, 12, 6, hexc("e8e8d8"))
        img.rect(4, 3, 11, 5, hexc("203020"))
        img.rect(10, 8, 12, 13, hexc("202020"))
        img.line(11, 13, 11, 15, hexc("202020"))
    block("fuel_pump_front", 306, pump_front)
    block("fuel_pump_side", 307, lambda img: (metal(img, "c03a30"), img.rect(2, 2, 13, 4, hexc("e8e8d8"))))

    def tv_front(img):
        img.noise(hexc("2a2a2a"), 0.05)
        img.rect(1, 2, 12, 12, hexc("101418"))
        img.line(3, 4, 6, 4, hexc("303a44"))
        img.rect(13, 4, 14, 5, hexc("707070"))
        img.rect(13, 8, 14, 9, hexc("707070"))
    block("tv_front", 308, tv_front)
    block("tv_side", 309, lambda img: img.noise(hexc("2a2a2a"), 0.05))

    def barrel_side(img):
        img.noise(hexc("3a6a9a"), 0.06)
        for y in (2, 13):
            img.line(0, y, 15, y, hexc("23445f"))
    block("rain_barrel_side", 310, barrel_side)
    block("rain_barrel_top", 311, lambda img: (img.noise(hexc("3a6a9a"), 0.06),
                                               img.rect(2, 2, 13, 13, hexc("2a5aa0")),
                                               img.line(4, 5, 8, 5, hexc("6aa0e0"))))

    def soil(img):
        img.noise(hexc("5a3e26"), 0.12)
        for y in (3, 7, 11, 15):
            img.line(0, y, 15, y, hexc("3e2a18"))
    block("garden_bed", 312, soil)

    def crop(stage, leaf, fruit):
        def draw(img):
            img.p = [(0, 0, 0, 0)] * 256
            h = (4, 8, 12, 13)[stage]
            for x in (3, 7, 11):
                img.line(x, 15, x - 1, 15 - h, hexc(leaf))
                img.line(x + 1, 15, x + 2, 16 - h, shade(hexc(leaf), 0.8))
            if stage == 3:
                for x in (3, 7, 11):
                    img.rect(x - 1, 13, x + 1, 15, hexc(fruit))
        return draw
    for kind, leaf, fruit in (("carrot", "4aa040", "e07a20"), ("potato", "3a8a3a", "b89a60")):
        for stage in range(4):
            block("crop_%s_%d" % (kind, stage), 320 + stage, crop(stage, leaf, fruit))

    def dead(img):
        img.p = [(0, 0, 0, 0)] * 256
        for x in (3, 7, 11):
            img.line(x, 15, x + 2, 9, hexc("7a6a3a"))
    block("crop_dead", 330, dead)

    def fire(seed):
        def draw(img):
            img.p = [(0, 0, 0, 0)] * 256
            for x in range(16):
                h = 6 + img.r.randrange(9)
                for y in range(16 - h, 16):
                    k = (y - (16 - h)) / h
                    img.set(x, y, hexc("f8e060") if k > 0.6 else hexc("f08020") if k > 0.25 else hexc("c03010", 220))
        return draw
    block("fire", 331, fire(331))

    def planks_wall(img):
        img.noise(hexc("9a7444"), 0.08)
        for y in (0, 5, 10, 15):
            img.line(0, y, 15, y, hexc("5e4628"))
        for x, y in ((2, 2), (13, 2), (2, 7), (13, 7), (2, 12), (13, 12)):
            img.set(x, y, hexc("c0c4c8"))
    block("plank_wall", 332, planks_wall)

    def gate(img):
        planks_wall(img)
        img.line(1, 1, 14, 14, hexc("5e4628"))
        img.line(1, 2, 13, 14, hexc("6e5232"))
    block("wooden_gate", 333, gate)

    def palisade(img):
        img.p = [(0, 0, 0, 0)] * 256
        for x0 in (0, 4, 8, 12):
            img.rect(x0, 1, x0 + 3, 15, shade(hexc("6a4c2c"), 0.9 + 0.05 * x0 / 4))
            img.line(x0, 1, x0, 15, hexc("4a3420"))
            img.rect(x0 + 1, 0, x0 + 2, 0, hexc("8a6a44"))
    block("palisade", 334, palisade)
    block("palisade_top", 335, lambda img: (img.noise(hexc("8a6a44"), 0.1), img.frame(0, 0, 15, 15, hexc("5a4028"))))

    def ladder(img):
        img.p = [(0, 0, 0, 0)] * 256
        img.rect(2, 0, 3, 15, hexc("8a6a3a"))
        img.rect(12, 0, 13, 15, hexc("8a6a3a"))
        for y in (2, 6, 10, 14):
            img.rect(4, y, 11, y, hexc("a07c48"))
    block("ladder", 336, ladder)

    def floor(img):
        img.noise(hexc("a88050"), 0.07)
        for x in (0, 4, 8, 12):
            img.line(x, 0, x, 15, hexc("6e5232"))
    block("wood_floor", 337, floor)

    for name, col in (("red", "a83228"), ("blue", "30589a"), ("white", "d8d8d0"), ("green", "3a6a3a")):
        block("car_" + name, 340 + len(name), lambda img, c=col: (img.noise(hexc(c), 0.04),
                                                                   img.line(0, 15, 15, 15, shade(hexc(c), 0.7))))
    block("car_glass", 350, lambda img: (img.noise(hexc("4a6a80"), 0.05), img.line(2, 3, 6, 7, hexc("9ac0d8"))))
    block("car_wheel", 351, lambda img: (img.noise(hexc("1a1a1a"), 0.1), img.rect(5, 5, 10, 10, hexc("8a8a8a"))))
    block("car_light", 352, lambda img: img.noise(hexc("f0f0c0"), 0.03))


def world_sounds():
    rate = 22050

    def engine(path, seed, freq, dur, rough):
        r = random.Random(seed)
        out = []
        lp = 0.0
        for i in range(int(rate * dur)):
            t = i / rate
            lp += (r.uniform(-1, 1) - lp) * 0.1
            v = math.sin(2 * math.pi * freq * t) * 0.4 + math.sin(2 * math.pi * freq * 2 * t) * 0.2
            v = (v + lp * rough) * (0.75 + 0.25 * math.sin(2 * math.pi * freq / 4 * t))
            fade = min(1.0, t / 0.05, (dur - t) / 0.05)
            out.append(v * 0.7 * fade)
        save_wav(path, out, rate)

    engine(os.path.join(SOUNDS, "world", "generator.wav"), 400, 55, 1.0, 1.2)
    engine(os.path.join(SOUNDS, "world", "engine.wav"), 401, 38, 1.0, 0.8)

    r = random.Random(402)
    out = []
    lp = 0.0
    for i in range(int(rate * 1.2)):
        lp += (r.uniform(-1, 1) - lp) * 0.3
        crack = r.uniform(-1, 1) if r.random() < 0.004 else 0
        out.append((lp * 0.5 + crack) * 0.6)
    save_wav(os.path.join(SOUNDS, "world", "fire.wav"), out, rate)

    r = random.Random(403)
    out = [r.uniform(-1, 1) * 0.35 * (0.7 + 0.3 * math.sin(i / rate * 9)) for i in range(int(rate * 1.0))]
    save_wav(os.path.join(SOUNDS, "world", "static.wav"), out, rate)


if __name__ == "__main__":
    for d in (BLOCKS, os.path.join(SOUNDS, "zombie"), os.path.join(SOUNDS, "player"), os.path.join(SOUNDS, "world")):
        os.makedirs(d, exist_ok=True)
    block_textures()
    icon()
    sounds()
    combat_assets()
    world_textures()
    world_sounds()
