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


def building_textures():
    def block(name, seed, fn):
        img = Img(seed=seed)
        fn(img)
        img.save(BLOCKS, name)

    def plaster(img):
        img.noise(hexc("d8d2c0"), 0.04)
        img.speckle(hexc("c4bca8"), 10)
    block("bld_plaster", 500, plaster)

    def concrete(img):
        img.noise(hexc("8c8c88"), 0.07)
        img.speckle(hexc("6e6e6a"), 14)
        img.line(0, 15, 15, 15, hexc("707070"))
        img.line(15, 0, 15, 15, hexc("707070"))
    block("bld_concrete", 501, concrete)

    def corrugated(img):
        for x in range(16):
            c = hexc("6a7a86") if x % 4 < 2 else hexc("52606a")
            for y in range(16):
                img.set(x, y, shade(c, 1 + img.r.uniform(-0.04, 0.04)))
        img.speckle(hexc("7a5a40"), 5)
    block("bld_corrugated", 502, corrugated)

    def linoleum(img):
        img.noise(hexc("a8c0a0"), 0.04)
        img.speckle(hexc("8aa086"), 12)
        img.frame(0, 0, 15, 15, hexc("94ac8c"))
    block("bld_linoleum", 503, linoleum)

    def sandbag(img):
        img.noise(hexc("a89268"), 0.06)
        for y in (4, 9, 14):
            img.line(0, y, 15, y, hexc("7a6644"))
        for y0, off in ((0, 0), (5, 4), (10, 0)):
            for x in range(off, 16, 8):
                img.line(x, y0, x, y0 + 3, hexc("7a6644"))
    block("bld_sandbag", 504, sandbag)
    block("bld_sandbag_top", 505, lambda img: (img.noise(hexc("b09a70"), 0.06), img.speckle(hexc("8a7650"), 12)))

    def fence(img):
        for i in range(-16, 16, 4):
            img.line(i, 0, i + 15, 15, hexc("9aa0a4"))
            img.line(i + 15, 0, i, 15, hexc("9aa0a4"))
        img.frame(0, 0, 15, 15, hexc("707478"))
    block("bld_fence", 506, fence)

    def gravestone(img):
        img.noise(hexc("8a8a8e"), 0.08)
        img.speckle(hexc("5a6a4a"), 8)
        img.rect(7, 3, 8, 10, hexc("5a5a5e"))
        img.rect(5, 5, 10, 6, hexc("5a5a5e"))
    block("bld_gravestone", 507, gravestone)

    def pew(img):
        img.noise(hexc("6a4428"), 0.06)
        for y in (3, 8, 13):
            img.line(0, y, 15, y, hexc("4a2e18"))
    block("bld_pew", 508, pew)
    block("bld_pew_top", 509, lambda img: (img.noise(hexc("7a5030"), 0.05), img.line(0, 7, 15, 7, hexc("4a2e18"))))

    block("bld_table_top", 510, lambda img: (img.noise(hexc("a07848"), 0.05), img.frame(0, 0, 15, 15, hexc("6e5030"))))

    def table_side(img):
        img.rect(0, 0, 15, 2, hexc("8a6438"))
        img.rect(0, 3, 1, 15, hexc("6e5030"))
        img.rect(14, 3, 15, 15, hexc("6e5030"))
    block("bld_table_side", 511, table_side)

    def chalkboard(img):
        img.noise(hexc("2e4a36"), 0.05)
        img.frame(0, 0, 15, 15, hexc("8a6438"))
        img.line(3, 5, 9, 5, hexc("d8d8d0"))
        img.line(3, 8, 12, 8, hexc("d8d8d0"))
        img.line(3, 11, 7, 11, hexc("d8d8d0"))
    block("bld_chalkboard", 512, chalkboard)

    def locker_front(img):
        img.noise(hexc("5a6e8a"), 0.04)
        img.frame(0, 0, 15, 15, hexc("3e4c60"))
        for y in (2, 4, 6):
            img.line(4, y, 11, y, hexc("2a3444"))
        img.rect(12, 8, 13, 10, hexc("c8c8c8"))
    block("bld_locker_front", 513, locker_front)
    block("bld_locker_side", 514, lambda img: (img.noise(hexc("566a84"), 0.04), img.frame(0, 0, 15, 15, hexc("3e4c60"))))

    def ammo(img, top=False):
        img.noise(hexc("4e5a32"), 0.06)
        img.frame(0, 0, 15, 15, hexc("343c20"))
        if not top:
            img.rect(3, 6, 12, 9, hexc("d0c890"))
            img.line(4, 7, 11, 7, hexc("343c20"))
    block("bld_ammo_front", 515, ammo)
    block("bld_ammo_side", 516, lambda img: (img.noise(hexc("4e5a32"), 0.06), img.frame(0, 0, 15, 15, hexc("343c20"))))
    block("bld_ammo_top", 517, lambda img: ammo(img, True))

    def stained(img):
        colors = ["b02828", "2848b0", "d0a020", "288a40", "8a30a0"]
        for y in range(16):
            for x in range(16):
                c = hexc(colors[((x // 4) + (y // 4) * 2) % len(colors)], 170)
                img.set(x, y, c)
        for i in range(0, 16, 4):
            img.line(i, 0, i, 15, hexc("202020"))
            img.line(0, i, 15, i, hexc("202020"))
        img.frame(0, 0, 15, 15, hexc("303030"))
    block("bld_stained_glass", 518, stained)

    def machine(img, part):
        img.noise(hexc("5a7a6a"), 0.05)
        img.frame(0, 0, 15, 15, hexc("3a4e44"))
        if part == "front":
            img.rect(3, 3, 12, 8, hexc("2a2a2a"))
            img.rect(5, 4, 10, 6, hexc("8a9a90"))
            img.rect(11, 11, 13, 13, hexc("c03020"))
        elif part == "top":
            img.rect(5, 5, 10, 10, hexc("8a8a8a"))
    for part, seed in (("front", 519), ("side", 520), ("top", 521)):
        block("bld_machine_" + part, seed, lambda img, part=part: machine(img, part))


if __name__ == "__main__":
    for d in (os.path.join(SOUNDS, "zombie"), os.path.join(SOUNDS, "player"), os.path.join(SOUNDS, "world")):
        os.makedirs(d, exist_ok=True)
    icon()
    sounds()
    combat_assets()
    world_sounds()
    building_textures()
