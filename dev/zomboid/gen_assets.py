#!/usr/bin/env python3
import math
import os
import random
import struct
import wave
import zlib

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "res", "content", "zomboid")
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


def nature_textures():
    def block(name, seed, fn):
        img = Img(seed=seed)
        fn(img)
        img.save(BLOCKS, name)

    dirt = hexc("6b4a2e")

    def podzol(img):
        img.noise(hexc("5a4128"), 0.12)
        for _ in range(26):
            x, y = img.r.randrange(16), img.r.randrange(16)
            img.line(x, y, x + img.r.choice((-1, 1)), y + 1, img.r.choice((hexc("7a5a30"), hexc("3e5a2a"), hexc("8a6a3a"))))
    block("nature_podzol", 500, podzol)

    def podzol_side(img):
        img.noise(dirt, 0.1)
        img.noise(hexc("5a4128"), 0.12, 0, 0, 15, 2)
        for x in range(16):
            if img.r.random() < 0.5:
                img.set(x, 3, hexc("5a4128"))
    block("nature_podzol_side", 501, podzol_side)

    def mud(img):
        img.noise(hexc("4a3a28"), 0.08)
        for _ in range(5):
            x, y = img.r.randrange(14), img.r.randrange(14)
            img.rect(x, y, x + 2, y + 1, hexc("3a2e22"))
        img.speckle(hexc("5e4c36"), 12)
    block("nature_mud", 502, mud)

    def path(img):
        img.noise(hexc("8a6e4a"), 0.1)
        img.speckle(hexc("a08a6a"), 14)
        img.speckle(hexc("6a5236"), 14)
        for y in (4, 11):
            img.line(0, y, 15, y, hexc("7a603e"))
    block("nature_dirt_path", 503, path)

    def path_side(img):
        img.noise(dirt, 0.1)
        img.noise(hexc("8a6e4a"), 0.1, 0, 0, 15, 1)
    block("nature_dirt_path_side", 504, path_side)

    def mossy(img):
        img.noise(hexc("7c7c78"), 0.1)
        for _ in range(7):
            x, y = img.r.randrange(15), img.r.randrange(15)
            img.rect(x, y, x + img.r.randrange(1, 4), y + 1, hexc("4e6e34"))
        img.line(2, 9, 7, 7, hexc("5c5c58"))
    block("nature_mossy_stone", 505, mossy)

    def bark(base, dark):
        def draw(img):
            img.noise(hexc(base), 0.1)
            for x in range(0, 16, 3):
                img.line(x, 0, x + img.r.choice((-1, 0, 1)), 15, hexc(dark))
        return draw
    block("nature_spruce_bark", 506, bark("5a4030", "3a281c"))

    def rings(img, outer, inner):
        img.noise(hexc(inner), 0.06)
        img.frame(0, 0, 15, 15, hexc(outer))
        img.frame(4, 4, 11, 11, shade(hexc(inner), 0.82))
        img.rect(7, 7, 8, 8, shade(hexc(inner), 0.75))
    block("nature_spruce_top", 507, lambda img: rings(img, "5a4030", "b08a5a"))

    def birch_bark(img):
        img.noise(hexc("e4e0d4"), 0.04)
        for _ in range(9):
            x, y = img.r.randrange(13), img.r.randrange(16)
            img.line(x, y, x + img.r.randrange(1, 4), y, hexc("2a2a26"))
        img.speckle(hexc("b8b4a8"), 10)
    block("nature_birch_bark", 508, birch_bark)
    block("nature_birch_top", 509, lambda img: rings(img, "e4e0d4", "d8c49a"))

    def foliage(base, light, holes, needles=False):
        def draw(img):
            img.noise(hexc(base), 0.14)
            for _ in range(22):
                x, y = img.r.randrange(16), img.r.randrange(16)
                if needles:
                    img.line(x, y, x + 1, y + 1, hexc(light))
                else:
                    img.set(x, y, hexc(light))
            for _ in range(holes):
                img.set(img.r.randrange(16), img.r.randrange(16), (0, 0, 0, 0))
        return draw
    block("nature_spruce_leaves", 510, foliage("24452a", "3a6438", 18, True))
    block("nature_birch_leaves", 511, foliage("6a9a3a", "9ac050", 24))

    def bush(img):
        foliage("3e6a2c", "5a8a3a", 30)(img)
        for _ in range(4):
            x, y = img.r.randrange(1, 15), img.r.randrange(1, 15)
            img.set(x, y, hexc("a02a2a"))
    block("nature_bush", 512, bush)

    def blades(colors, count, tall):
        def draw(img):
            img.p = [(0, 0, 0, 0)] * 256
            for i in range(count):
                x = img.r.randrange(1, 15)
                h = img.r.randrange(tall // 2, tall)
                lean = img.r.choice((-2, -1, 0, 1, 2))
                img.line(x, 15, x + lean, 15 - h, hexc(img.r.choice(colors)))
        return draw
    block("nature_tall_grass", 513, blades(("4a8a30", "5ea03a", "3a7a2a", "8a9a40"), 14, 16))
    block("nature_reeds", 514, lambda img: (blades(("6a8a3a", "8a9a4a", "5a7a30"), 9, 16)(img),
                                            [img.rect(x, 2, x, 5, hexc("5a3a20")) for x in (4, 9, 12)]))

    def fern(img):
        img.p = [(0, 0, 0, 0)] * 256
        for x0, lean in ((4, -3), (8, 0), (11, 3)):
            img.line(x0, 15, x0 + lean, 4, hexc("2e6a2a"))
            for k in range(5, 15, 2):
                t = (15 - k) / 11
                cx = round(x0 + lean * t)
                img.set(cx - 1, k, hexc("4a8a38"))
                img.set(cx + 1, k, hexc("4a8a38"))
    block("nature_fern", 515, fern)

    def flowers(petal):
        def draw(img):
            img.p = [(0, 0, 0, 0)] * 256
            for x, top in ((3, 6), (7, 4), (11, 7), (13, 9)):
                img.line(x, 15, x, top, hexc("3a7a2a"))
                for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                    img.set(x + dx, top + dy, hexc(petal))
                img.set(x, top, hexc("e8c030"))
        return draw
    block("nature_flower_blue", 516, flowers("4a6ad8"))
    block("nature_flower_yellow", 517, flowers("e8d030"))
    block("nature_flower_white", 518, flowers("f0f0e8"))

    def mushroom(img):
        img.p = [(0, 0, 0, 0)] * 256
        for x, s in ((5, 3), (11, 2)):
            img.rect(x, 15 - s * 2, x, 15, hexc("e8dcc0"))
            img.rect(x - s, 15 - s * 2 - 2, x + s, 15 - s * 2, hexc("a03a22"))
            img.set(x - 1, 15 - s * 2 - 1, hexc("f0e8e0"))
    block("nature_mushroom", 519, mushroom)


if __name__ == "__main__":
    for d in (os.path.join(SOUNDS, "zombie"), os.path.join(SOUNDS, "player"), os.path.join(SOUNDS, "world")):
        os.makedirs(d, exist_ok=True)
    icon()
    sounds()
    combat_assets()
    world_sounds()
    nature_textures()
