#!/usr/bin/env python3
import os
import zlib
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import BLOCKS, MODELS, PAL, Canvas, hexc, mix, ramp, shade  # noqa: E402

PX = 32
SIDES = ("north", "west", "south", "east", "top", "bottom")


def num(v):
    s = "%.6f" % (v / PX)
    s = s.rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def vec(v):
    return "(%s)" % ",".join(num(c) for c in v)


class Face:
    def __init__(self, c, x, y, w, h):
        self.c, self.x, self.y, self.w, self.h = c, x, y, w, h

    def set(self, x, y, col):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.c.set(self.x + x, self.y + y, col)

    def get(self, x, y):
        return self.c.get(self.x + x, self.y + y)

    def blend(self, x, y, col, t):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.c.blend(self.x + x, self.y + y, col, t)

    def rect(self, x0, y0, x1, y1, col):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, col)

    def cells(self):
        return [(x, y) for y in range(self.h) for x in range(self.w)]


class Sheet:
    """Texture atlas of box nets; regions are emitted per face."""

    def __init__(self, name, w, h, seed=0):
        self.name, self.c = name, Canvas(w, h, seed)
        self.r = self.c.r
        self.cx = self.cy = self.row = 0

    def alloc(self, w, h):
        if self.cx + w > self.c.w:
            self.cx, self.cy, self.row = 0, self.cy + self.row, 0
        x0, y0 = self.cx, self.cy
        self.cx += w
        self.row = max(self.row, h)
        assert y0 + h <= self.c.h, (self.name, w, h)
        return x0, y0

    def face(self, w, h):
        return Face(self.c, *self.alloc(w, h), w, h)

    def net(self, w, h, d):
        x0, y0 = self.alloc(2 * (w + d), d + h)
        c = self.c
        return {
            "top": Face(c, x0, y0, w, d), "bottom": Face(c, x0 + w + d, y0, w, d),
            "north": Face(c, x0, y0 + d, w, h), "west": Face(c, x0 + w, y0 + d, d, h),
            "south": Face(c, x0 + w + d, y0 + d, w, h), "east": Face(c, x0 + 2 * w + d, y0 + d, d, h),
        }

    def region(self, f):
        W, H = self.c.w, self.c.h
        return "(%g,%g,%g,%g)" % (round(f.x / W, 6), round(1 - (f.y + f.h) / H, 6),
                                  round((f.x + f.w) / W, 6), round(1 - f.y / H, 6))

    def save(self):
        self.c.save(os.path.join(BLOCKS, self.name + ".png"))


def box(frm, to, tex, net=None, sheet=None, extra=""):
    head = "@box from %s to %s texture \"%s\"%s" % (vec(frm), vec(to), tex, extra)
    if net is None:
        return head
    parts = ["    @part tags (%s) region %s" % (s, sheet.region(net[s])) for s in SIDES if s in net]
    return head + " {\n" + "\n".join(parts) + "\n}"


def bone(name, move, children, rotate=None, scale=None):
    attrs = (" name '%s'" % name if name else "") + (" move %s" % vec(move) if move else "")
    if rotate:
        attrs += " rotate (%s)" % ",".join("%g" % a for a in rotate)
    if scale:
        attrs += " scale (%g,%g,%g)" % (scale, scale, scale)
    body = "\n".join(children)
    return "@bone%s {\n%s\n}" % (attrs, "\n".join("    " + line for line in body.split("\n")))


def write_model(name, items):
    with open(os.path.join(MODELS, name + ".vcm"), "w") as f:
        f.write("\n".join(items) + "\n")


def save_tex(name, c):
    c.save(os.path.join(BLOCKS, name + ".png"))


# ---------- shared surface painters ----------

def bevel(f, tones, light=True):
    """Base fill with a soft top-left light and darker bottom-right edges."""
    for x, y in f.cells():
        t = 2
        if y == 0 or (light and x == 0 and f.w > 2):
            t = 3
        if y == f.h - 1 or (x == f.w - 1 and f.w > 2):
            t = 1
        f.set(x, y, tones[t])


def folds(f, tones, r, count):
    for _ in range(count):
        x, y = r.randrange(f.w), r.randrange(1, max(2, f.h - 1))
        n = r.randint(2, 4)
        dx = r.choice((-1, 1))
        for i in range(n):
            f.set(x + (i * dx) // 2, y + i, tones[1])
        f.set(x - dx, y, tones[3])


def splat(f, r, x, y, size, drip=0, tones=None):
    b = tones or PAL["blood"]
    for _ in range(size * 3):
        px, py = x + r.randint(-size, size), y + r.randint(-size // 2 - 1, size // 2 + 1)
        if abs(px - x) + abs(py - y) <= size + 1:
            f.set(px, py, b[1] if r.random() < 0.55 else b[2])
    f.set(x, y, b[0])
    for _ in range(drip):
        px, py = x + r.randint(-size, size), y
        for i in range(r.randint(2, 6)):
            f.set(px, py + i, b[1] if i % 2 else b[2])
        f.set(px, py + i + 1, b[0])


def tear(f, r, x, y, w, h, skin, gore=False):
    z = skin
    b = PAL["blood"]
    for py in range(y, y + h):
        for px in range(x, x + w):
            edge = px in (x, x + w - 1) or py in (y, y + h - 1)
            if edge and r.random() < 0.45:
                continue
            f.set(px, py, z[1] if py == y else z[2])
            if gore and r.random() < 0.3:
                f.set(px, py, b[1])
    for px in range(x, x + w):
        if r.random() < 0.7:
            f.set(px, y - 1, z[0])
        if r.random() < 0.5:
            f.set(px, y + h, z[0])


def grime(f, r, tones, count, rows=None):
    for _ in range(count):
        y = r.randrange(*(rows or (0, f.h)))
        f.set(r.randrange(f.w), y, tones[1])


# ---------- zombie ----------

ZSKIN = PAL["zskin"]
BRUISE = ramp("6a5a70")
BLOOD = PAL["blood"]
EYE = hexc("d8d0a0")


def skin(f, r, rot=6):
    bevel(f, ZSKIN)
    for _ in range(rot // 3):
        x, y = r.randrange(f.w), r.randrange(f.h)
        f.rect(x, y, x + 1, y + 1, BRUISE[2])
        f.set(x + 1, y + 1, BRUISE[1])
        f.set(x - 1, y, ZSKIN[1])
    if f.w * f.h > 30 and r.random() < 0.5:
        splat(f, r, r.randrange(f.w), r.randrange(f.h), 1)


TORSO = (14, 14, 8)
UPPER = (5, 10, 5)
LOWER = (4, 8, 4)
PELVIS = (14, 3, 8)
LEG = (6, 29, 6)
HEAD = (10, 10, 9)
NECK = (5, 2, 5)
HAND = (4, 3, 5)
NOSE = (2, 2, 1)
EAR = (1, 3, 2)

SHIRTS = {
    "red": ("tee", "a83a34"), "blue": ("hoodie", "3a5a8a"), "green": ("tee", "4a6a3a"),
    "gray": ("hoodie", "6e6e72"), "white": ("button", "d0ccc0"), "police": ("police", "26324e"),
    "plaid": ("plaid", "8a2a26"), "suit": ("suit", "34343c"), "tank": ("tank", "d8d2bc"),
    "sport": ("sport", "d8a828"),
}
PANTS = {
    "jeans": ("pants", "3a5480"), "brown": ("pants", "5e4a34"), "black": ("pants", "2c2c32"),
    "torn": ("torn", "3a5480"), "sport": ("shorts", "2a3a7a"),
}
HEADS = {"bald": None, "dark": "3a2a20", "long": "6a4a2a", "gray": "8a8a86", "blond": "b89a58"}


def shirt_sheet(name, style, col):
    sh = Sheet("z_shirt_" + name, 64, 48, seed=zlib.crc32(name.encode()))
    r = sh.r
    tones = ramp(col)
    torso = sh.net(*TORSO)
    arms = [(sh.net(*UPPER), sh.net(*LOWER)) for _ in range(2)]
    sleeves = {"tee": 6, "sport": 4, "tank": 0, "button": 10, "police": 10, "hoodie": 10, "plaid": 10, "suit": 10}[style]
    cuff = style in ("hoodie", "police", "plaid", "suit", "button")

    for s, f in torso.items():
        bevel(f, tones)
        folds(f, tones, r, 2 if f.w > 8 else 1)
    for upper, lower in arms:
        for s, f in upper.items():
            bevel(f, tones)
            if sleeves < 10:
                for x in range(f.w):
                    for y in range(sleeves, f.h):
                        f.set(x, y, ZSKIN[2] if x else ZSKIN[3])
                    if 0 < sleeves < f.h:
                        f.set(x, sleeves - 1, tones[1])
        for s, f in lower.items():
            if cuff:
                bevel(f, tones)
                for x in range(f.w):
                    f.set(x, f.h - 1, tones[0])
            else:
                skin(f, r, 2)

    front, back = torso["north"], torso["south"]
    if style == "plaid":
        for f in list(torso.values()) + [a[0][k] for a in arms for k in a[0]] + [a[1][k] for a in arms for k in a[1]]:
            for x, y in f.cells():
                if x % 4 == 1 or y % 4 == 1:
                    f.set(x, y, tones[0] if (x % 4 == 1 and y % 4 == 1) else tones[1])
                elif (x + y) % 2 == 0 and f.get(x, y) == tones[2]:
                    f.set(x, y, mix(tones[2], hexc("d8c8a0"), 0.15))
    if style == "tank":
        for s, f in torso.items():
            if s in ("west", "east"):
                f.rect(0, 0, f.w - 1, 3, ZSKIN[2])
                f.rect(2, 0, f.w - 3, 0, tones[2])
        front.rect(4, 0, 9, 2, ZSKIN[2])
        front.rect(5, 3, 8, 3, ZSKIN[1])
        for x, y in front.cells():
            if y > 6 and (x - 7) ** 2 / 30 + (y - 12) ** 2 / 24 < 1 and r.random() < 0.5:
                front.set(x, y, mix(front.get(x, y), hexc("b8a060"), 0.35))
    if style == "sport":
        dark = hexc("1c1c22")
        for f in torso.values():
            for x in range(f.w):
                f.set(x, min(f.h - 1, 5), dark)
                f.set(x, min(f.h - 1, 6), dark)
        for x, y in [(5, 8), (5, 9), (5, 10), (5, 11), (7, 8), (8, 8), (8, 9), (7, 10), (7, 11), (8, 11)]:
            back.set(x, y, hexc("f0ece0"))
        front.rect(5, 0, 8, 0, dark)
    if style in ("tee", "sport"):
        front.rect(5, 0, 8, 1, ZSKIN[2])
        front.rect(6, 2, 7, 2, ZSKIN[1])
        for x in range(4, 10):
            front.set(x, 0 if x in (4, 9) else 2 if x in (5, 8) else 3, tones[1])
    if style == "hoodie":
        front.rect(5, 0, 8, 0, ZSKIN[2])
        front.set(5, 1, hexc("d8d4c8"))
        front.set(8, 1, hexc("d8d4c8"))
        front.set(5, 2, hexc("d8d4c8"))
        front.set(8, 3, hexc("d8d4c8"))
        front.rect(3, 9, 10, 12, tones[1])
        front.rect(4, 9, 9, 9, tones[0])
        back.rect(3, 0, 10, 4, tones[1])
        back.rect(4, 1, 9, 3, tones[2])
    if style in ("button", "police", "suit"):
        for y in range(2, 14, 3):
            front.set(7, y, tones[0] if style != "button" else hexc("8a8a86"))
        front.rect(6, 0, 7, 1, ZSKIN[2])
        front.set(5, 0, tones[3])
        front.set(8, 0, tones[3])
    if style == "police":
        front.rect(2, 3, 4, 5, tones[1])
        front.set(3, 4, hexc("d8b048"))
        front.set(10, 4, hexc("d8b048"))
        front.set(11, 4, hexc("a88830"))
        front.rect(9, 3, 11, 3, tones[0])
        for upper, _ in arms:
            upper["west"].rect(1, 2, 3, 4, hexc("c8a040"))
            upper["east"].rect(1, 2, 3, 4, hexc("c8a040"))
    if style == "suit":
        shirt = PAL["cloth_white"]
        for y in range(0, 9):
            for x in range(6 - y // 3, 8 + y // 3):
                front.set(x, y, shirt[2] if x not in (6 - y // 3, 7 + y // 3) else shirt[1])
        for y in range(1, 10):
            front.set(7, y, hexc("8a2228") if y < 9 else hexc("5a1418"))
            front.set(6, y, hexc("a8323a") if 2 < y < 8 else front.get(6, y))
        front.rect(6, 0, 7, 0, ZSKIN[2])

    holes = {"tank": 1, "sport": 2}.get(style, 3)
    for f in (front, back):
        for _ in range(r.randint(1, holes)):
            w, h = r.randint(2, 4), r.randint(2, 3)
            tear(f, r, r.randint(1, f.w - w - 1), r.randint(4, f.h - h - 1), w, h, ZSKIN, gore=r.random() < 0.5)
    if r.random() < 0.6:
        x = r.randint(2, 8)
        tear(front, r, x, 7, 4, 5, ZSKIN)
        for i in range(3):
            front.rect(x + 1, 8 + i * 1, x + 2, 8 + i * 1, hexc("d8ccb0") if i != 1 else BLOOD[1])
    splat(front, r, 7 + r.randint(-1, 1), 2, 2, drip=4)
    splat(front, r, r.randint(2, 11), r.randint(6, 12), r.randint(1, 2), drip=2)
    splat(back, r, r.randint(2, 11), r.randint(3, 11), 1, drip=1)
    side = torso[r.choice(("west", "east"))]
    splat(side, r, r.randint(1, 6), r.randint(4, 11), 1, drip=2)
    upper, lower = arms[r.randrange(2)]
    splat(upper["north"], r, 2, r.randint(2, 7), 1, drip=2)
    splat(lower["south"], r, 2, r.randint(2, 6), 1, drip=1)
    for f in torso.values():
        grime(f, r, tones, f.w * f.h // 40, (f.h // 2, f.h))
    sh.save()
    return torso, arms, sh


def pants_sheet(name, style, col):
    sh = Sheet("z_pants_" + name, 64, 48, seed=zlib.crc32(name.encode()))
    r = sh.r
    tones = ramp(col)
    pelvis = sh.net(*PELVIS)
    legs = [sh.net(*LEG), sh.net(*LEG)]
    shoe = ramp("4a3a30") if style != "shorts" else ramp("c8c8c4")
    belt = ramp("3a2a20")
    for f in pelvis.values():
        bevel(f, tones)
        if style != "shorts":
            for x in range(f.w):
                f.set(x, 0, belt[1] if x % 5 else belt[2])
    if style != "shorts":
        pelvis["north"].rect(6, 0, 7, 0, hexc("b0a070"))
        pelvis["north"].set(7, 1, tones[1])
        pelvis["north"].set(7, 2, tones[1])
    for i, leg in enumerate(legs):
        bare = (0, 0)
        if style == "shorts":
            bare = (11, 23)
        elif style == "torn" and i == 0:
            bare = (13, 25)
        for s, f in leg.items():
            bevel(f, tones)
            folds(f, tones, r, 2)
            if s in ("west", "east") and style != "shorts":
                for y in range(f.h):
                    f.set(f.w // 2, y, tones[1])
            if bare[1]:
                for y in range(bare[0], min(f.h, bare[1] + (4 if style == "torn" else 0))):
                    for x in range(f.w):
                        f.set(x, y, ZSKIN[3] if x == 0 else ZSKIN[2])
                for x in range(f.w):
                    f.set(x, bare[0] - 1 + (r.random() < 0.5), tones[1])
                    if style == "torn" and r.random() < 0.5:
                        f.set(x, bare[0] + r.randint(1, 6), BLOOD[1])
            if style == "shorts" and f.h > 20:
                for y in range(23, 25):
                    for x in range(f.w):
                        f.set(x, y, hexc("e0dcd0") if y == 23 else hexc("c0bcb0"))
            if f.h > 20:
                top = 25
                barefoot = style == "torn" and i == 0
                for y in range(top, f.h):
                    for x in range(f.w):
                        c = (ZSKIN[1] if barefoot else shoe[2 if y < f.h - 1 else 0])
                        if y == top and not barefoot:
                            c = shoe[3]
                        f.set(x, y, c)
                if s == "north" and not barefoot:
                    f.set(1, top + 1, shoe[4])
                    f.set(2, top + 1, shoe[3])
        bottom = leg["bottom"]
        for x, y in bottom.cells():
            bottom.set(x, y, ZSKIN[0] if style == "torn" and i == 0 else shoe[0])
        top = leg["top"]
        for x, y in top.cells():
            top.set(x, y, tones[1])
    for leg in legs:
        if style == "pants" and r.random() < 0.6:
            f = leg["north"]
            tear(f, r, 1, r.randint(11, 14), 4, 2, ZSKIN, gore=True)
        splat(leg["north"], r, r.randint(1, 4), r.randint(2, 20), 1, drip=2)
        grime(leg["north"], r, tones, 2, (16, 25))
    if style == "torn":
        splat(legs[0]["north"], r, 3, 17, 2, drip=3)
        splat(legs[0]["south"], r, 2, 15, 2, drip=2)
    sh.save()
    return pelvis, legs, sh


def head_sheet(name, hair):
    sh = Sheet("z_head_" + name, 64, 40, seed=zlib.crc32(name.encode()))
    r = sh.r
    head = sh.net(*HEAD)
    neck = sh.net(*NECK)
    hands = [sh.net(*HAND), sh.net(*HAND)]
    nose = sh.net(*NOSE)
    ears = [sh.net(*EAR), sh.net(*EAR)]
    for f in list(head.values()) + list(neck.values()) + list(nose.values()):
        skin(f, r, 3 if f.w * f.h > 20 else 0)
    for ear in ears:
        for f in ear.values():
            bevel(f, ZSKIN)
    for hand in hands:
        for s, f in hand.items():
            skin(f, r, 1)
            if s == "north":
                for x in range(f.w):
                    f.set(x, f.h - 1, hexc("3a3028"))
            if s == "bottom":
                for x in range(0, f.w, 1):
                    f.set(x, 0, ZSKIN[1])
                    f.set(x, f.h - 1, hexc("3a3028") if x % 2 else ZSKIN[0])
        splat(hand["top"], r, 2, 2, 1)

    face = head["north"]
    hr = ramp(hair) if hair else None
    sock = hexc("2a2026")
    for ex in (2, 6):
        face.rect(ex, 4, ex + 1, 4, sock)
        face.set(ex, 3, ZSKIN[0])
        face.set(ex + 1, 3, ZSKIN[1])
        face.set(ex + (1 if ex == 2 else 0), 4, EYE)
        face.set(ex, 5, BRUISE[1])
        face.set(ex + 1, 5, BRUISE[2])
    face.set(3, 4, EYE)
    face.set(6, 4, EYE)
    face.set(2, 4, hexc("8a2020"))
    face.set(7, 4, hexc("8a2020"))
    mouth = hexc("1e1012")
    face.rect(3, 7, 6, 8, mouth)
    for x in (3, 5):
        face.set(x, 7, hexc("d8ccb0"))
    face.set(4, 8, hexc("c8bc98"))
    face.set(6, 8, hexc("d8ccb0"))
    face.rect(2, 6, 7, 6, ZSKIN[1])
    splat(face, r, 4, 9, 1, drip=0)
    face.set(3, 9, BLOOD[2])
    face.set(5, 9, BLOOD[1])
    face.set(6, 9, BLOOD[2])
    if r.random() < 0.7:
        x = r.choice((0, 8))
        face.rect(x, 6, x + 1, 7, BLOOD[1])
        face.set(x, 5, BRUISE[1])
    for f in nose.values():
        bevel(f, ZSKIN)
    nose["north"].set(0, 1, ZSKIN[0])
    nose["north"].set(1, 1, ZSKIN[0])
    nose["bottom"].set(0, 0, BLOOD[1])

    if hair is None:
        for s in ("top", "south", "west", "east"):
            f = head[s]
            for _ in range(3):
                f.set(r.randrange(f.w), r.randrange(min(4, f.h)), BRUISE[1])
        top = head["top"]
        tear(top, r, 3, 3, 4, 3, ramp("8a3a30"), gore=True)
        top.rect(4, 4, 5, 4, hexc("d8ccb0"))
        face.rect(1, 0, 8, 0, ZSKIN[3])
    else:
        long = name == "long"
        top = head["top"]
        for x, y in top.cells():
            top.set(x, y, hr[1] if x % 3 == 2 else hr[3] if y < 2 else hr[2])
        if name == "gray":
            top.rect(3, 2, 6, 5, ZSKIN[3])
            top.set(4, 3, ZSKIN[2])
        for x in range(face.w):
            fringe = 1 + (x % 3 == 0) if name != "gray" else (1 if x in (0, 1, 8, 9) else 0)
            if long:
                fringe = 2 if 2 < x < 7 else (9 if x in (0, 9) else 3)
            for y in range(fringe):
                face.set(x, y, hr[1] if y == fringe - 1 else hr[2])
        back = head["south"]
        depth = 10 if long else 7
        for x in range(back.w):
            d = depth - (x % 2) - (1 if x in (0, back.w - 1) else 0)
            for y in range(d):
                back.set(x, y, hr[1] if x % 3 == 2 else hr[2])
            back.set(x, max(0, d - 1), hr[1])
        for s in ("west", "east"):
            f = head[s]
            for x in range(f.w):
                d = (10 if long else 5) - (1 if x < 2 else 0)
                if not long and x < 3:
                    d = 2 + (x == 2)
                for y in range(d):
                    f.set(x if s == "east" else f.w - 1 - x, y, hr[3] if y == 0 else hr[1] if x % 3 == 2 else hr[2])
        if name != "long" and r.random() < 0.8:
            f = head["top"]
            tear(f, r, r.randint(1, 5), r.randint(1, 4), 3, 2, ramp("8a3a30"), gore=True)
    for s in ("west", "east"):
        splat(head[s], r, r.randint(2, 6), r.randint(6, 8), 1, drip=1)
    sh.save()
    return head, neck, hands, nose, ears, sh


def zombie():
    shirt = pants = head = None
    for name, (style, col) in SHIRTS.items():
        shirt = shirt_sheet(name, style, col)
    for name, (style, col) in PANTS.items():
        pants = pants_sheet(name, style, col)
    for name, hair in HEADS.items():
        head = head_sheet(name, hair)
    torso, arms, ssh = shirt
    pelvis, legs, psh = pants
    hnet, neck, hands, nose, ears, hsh = head

    def arm(i, x):
        upper, lower = arms[i]
        return bone("arm_" + ("left", "right")[i], (x, 16.64, 0), [
            box((-2.5, -10, -2.5), (2.5, 0, 2.5), "$shirt", upper, ssh),
            box((-2, -18, -2), (2, -10, 2), "$shirt", lower, ssh),
            box((-2, -21, -2.5), (2, -18, 2.5), "$head", hands[i], hsh),
        ])

    def leg(i, x):
        return bone("leg_" + ("left", "right")[i], (x, 0, 0), [box((-3, -29, -3), (3, 0, 3), "$pants", legs[i], psh)])

    write_model("zomboid_zombie", [bone("body", None, [
        box((-7, 0, -4), (7, 3, 4), "$pants", pelvis, psh),
        box((-7, 3, -4), (7, 17, 4), "$shirt", torso, ssh),
        bone("head", (0, 17, 0), [
            box((-2.5, 0, -2.5), (2.5, 2, 2.5), "$head", neck, hsh),
            box((-5, 2, -4.5), (5, 12, 4.5), "$head", hnet, hsh),
            box((-1, 6, -5.5), (1, 8, -4.5), "$head", nose, hsh),
            box((-6, 5, -1), (-5, 8, 1), "$head", ears[0], hsh),
            box((5, 5, -1), (6, 8, 1), "$head", ears[1], hsh),
        ]),
        leg(0, -3.5), leg(1, 3.5), arm(0, -9.92), arm(1, 9.92),
    ])])

    gore = Canvas(4, 4, seed=7)
    for x, y in gore.rect_m(0, 0, 3, 3):
        gore.set(x, y, BLOOD[1 + (x + y) % 2])
    save_tex("z_gore", gore)


# ---------- car ----------

CAR_COLORS = {"red": "a83228", "blue": "30589a", "white": "d8d8d0", "green": "3a6a3a", "black": "2e3036",
              "silver": "9aa0a8", "yellow": "d8a828"}
WHEELS = ((16, 8, 0.4), (14, 12, 0.3), (12, 14, 0.2), (8, 16, 0.1))
WHEEL_Z = 32
ARCH = 9.5


def world(f, side, b, i, j):
    x0, y0, z0, x1, y1, z1 = b
    u, v = (i + 0.5) / f.w, (j + 0.5) / f.h
    y = y1 - v * (y1 - y0)
    if side == "west":
        return x0, y, z0 + u * (z1 - z0)
    if side == "east":
        return x1, y, z1 - u * (z1 - z0)
    if side == "south":
        return x0 + u * (x1 - x0), y, z1
    if side == "north":
        return x1 - u * (x1 - x0), y, z0
    if side == "top":
        return x0 + u * (x1 - x0), y1, z0 + v * (z1 - z0)
    return x0 + u * (x1 - x0), y0, z1 - v * (z1 - z0)


class CarBody:
    """Paint boxes of all car variants; layout is shared by every paint sheet."""

    def __init__(self):
        self.boxes = []

    def add(self, group, frm, to, hidden=(), dark=()):
        self.boxes.append((group, frm, to, set(hidden), set(dark)))


def car_layout():
    body = CarBody()
    body.add("body", (-27, -8, 12), (27, 3, 48), hidden=("north",), dark=("bottom",))
    body.add("body", (-27, -14, 41), (27, -8, 48), hidden=("top",), dark=("bottom", "north"))
    body.add("body", (-27, -14, -23), (27, -8, 23), hidden=("top",), dark=("bottom", "north", "south"))
    body.add("body", (-27, -14, -48), (27, -8, -41), hidden=("top",), dark=("bottom", "south"))
    body.add("body", (-30, 3, 8), (-27, 6, 11))
    body.add("body", (27, 3, 8), (30, 6, 11))
    body.add("sedan", (-27, -8, -22), (27, 3, 12), hidden=("top", "north", "south"), dark=("bottom",))
    body.add("sedan", (-27, -8, -48), (27, 3, -22), hidden=("south",), dark=("bottom",))
    body.add("sedan", (-24.5, 15, -21), (24.5, 16.5, 11))
    body.add("sedan", (-24.4, 3, -5), (24.4, 15, -3), hidden=("top", "bottom", "north", "south"))
    body.add("pickup", (-27, -8, -8), (27, 3, 12), hidden=("top", "south"), dark=("bottom",))
    body.add("pickup", (-24.5, 15, -7), (24.5, 16.5, 11))
    body.add("pickup", (-24.6, 3, -7), (-22, 15, -5), hidden=("top", "bottom"))
    body.add("pickup", (22, 3, -7), (24.6, 15, -5), hidden=("top", "bottom"))
    body.add("pickup", (-27, -8, -48), (-25, 4, -8), dark=("bottom",))
    body.add("pickup", (25, -8, -48), (27, 4, -8), dark=("bottom",))
    body.add("pickup", (-25, -8, -48), (25, 4, -46), dark=("bottom",))
    return body


def paint_pixel(tones, mode, r, side, x, y, z, group, doors_tones=None):
    burnt = mode == "burnt"
    if side == "bottom":
        return hexc("1e1e22")
    c = tones[3] if side == "top" else tones[2]
    if doors_tones and side in ("west", "east") and -8 <= y < 3 and -22 < z < 21:
        tones = doors_tones
        c = tones[2]
    if side in ("west", "east"):
        if -3.5 <= y < -2.5:
            c = tones[1]
        elif -2.5 <= y < -1.5:
            c = tones[3]
        for zc in (WHEEL_Z, -WHEEL_Z):
            d = ((z - zc) ** 2 + (y + 14.5) ** 2) ** 0.5
            if d < ARCH:
                c = hexc("16161a")
            elif d < ARCH + 1:
                c = tones[0]
        doors = (21, -5, -22) if group == "sedan" else (21, -7) if group == "pickup" else (21,)
        if group != "pickup" or abs(z) < 40:
            for dz in doors:
                if abs(z - dz) < 0.5 and y > -8:
                    c = tones[0]
        handles = ((16, 19), (-10, -7)) if group == "sedan" else ((15, 18),)
        for a, bz in handles:
            if a <= z < bz and 0 <= y < 1.2:
                c = tones[4] if not burnt else tones[1]
        if group == "pickup" and z < -8 and y > 3:
            c = tones[3]
        if not burnt and abs((z * 0.6 - y) % 31 - 15) < 0.5 and y > -6:
            c = mix(c, tones[4], 0.5)
    if side == "top":
        if z > 12 and (abs(z - 12.8) < 0.5 or abs(abs(x) - 25.5) < 0.5):
            c = tones[2]
        if z > 13 and abs(x) < 0.5:
            c = tones[4]
        if z < -22 and (abs(z + 22.8) < 0.5 or abs(abs(x) - 25.5) < 0.5) and group == "sedan":
            c = tones[2]
    if side == "north" and z < -45:
        if group == "sedan" and (abs(y + 4) < 0.5 and abs(x) < 22 or abs(abs(x) - 22) < 0.5 and y > -4):
            c = tones[0]
        if group == "pickup" and abs(y - 1) < 0.6 and abs(x) < 3:
            c = tones[0]
    if side == "south" and z > 47:
        if y > 2:
            c = tones[3]
        if abs(x) < 1.5 and -1 < y < 1.5:
            c = hexc("c8c8c8") if not burnt else tones[1]
    if y < -10 and side != "top":
        c = mix(c, hexc("5a4a38"), 0.25)
    n = zlib.crc32(b"%d,%d,%d" % (x // 5, y // 4, z // 6)) % 100
    if mode == "wreck":
        if n < 12:
            c = mix(c, hexc("8a4a24"), 0.5 + n / 40)
        elif n > 93:
            c = tones[1]
        elif side != "top" and abs((z + 2 * y) % 23 - 11) < 0.4 and n % 3 == 0:
            c = tones[4]
    if burnt:
        if n < 30:
            c = mix(c, hexc("8a4a24"), 0.45 + n / 100)
        elif n > 88:
            c = tones[0]
        elif y < -9 and n < 50:
            c = mix(c, hexc("6a2a20"), 0.5)
    return c


def paint_sheet(name, tones, mode, layout, doors_tones=None):
    sh = Sheet(name, 192, 120, seed=zlib.crc32(name.encode()))
    nets, todo = [], []
    for k, (group, frm, to, hidden, dark) in enumerate(layout.boxes):
        size = {"top": (to[0] - frm[0], to[2] - frm[2]), "north": (to[0] - frm[0], to[1] - frm[1]),
                "south": (to[0] - frm[0], to[1] - frm[1]), "west": (to[2] - frm[2], to[1] - frm[1]),
                "east": (to[2] - frm[2], to[1] - frm[1])}
        nets.append({s: None for s in SIDES})
        todo += [(k, side) + tuple(max(1, round(v)) for v in size[side]) for side in size
                 if side not in hidden and side not in dark]
    for k, side, w, h in sorted(todo, key=lambda t: (-t[3], -t[2])):
        group, frm, to = layout.boxes[k][:3]
        f = nets[k][side] = sh.face(w, h)
        for i, j in f.cells():
            f.set(i, j, paint_pixel(tones, mode, sh.r, side, *world(f, side, frm + to, i, j), group, doors_tones))
        for i in range(f.w):
            f.set(i, 0, mix(f.get(i, 0), tones[4], 0.35))
            f.set(i, f.h - 1, mix(f.get(i, f.h - 1), tones[0], 0.35))
    plain = sh.face(2, 2)
    bevel(plain, tones)
    dark = sh.face(2, 2)
    dark.rect(0, 0, 1, 1, hexc("1e1e22"))
    for net, (group, frm, to, hidden, darks) in zip(nets, layout.boxes):
        for side in SIDES:
            if net[side] is None:
                net[side] = dark if (side in darks or side == "bottom") else plain
    sh.save()
    return sh, nets, plain


def parts_sheet(name, mode):
    burnt, broken = mode == "burnt", mode == "wreck"
    sh = Sheet(name, 128, 96, seed=zlib.crc32(name.encode()))
    r = sh.r
    F = {}
    glass = ramp("4a6478") if not burnt else ramp("1c1a1a")
    chrome = PAL["steel"] if not burnt else ramp("4a4038")
    rubber = PAL["rubber"]

    def window(f, seats=0, dash=False):
        for i, j in f.cells():
            f.set(i, j, glass[1] if j > f.h * 0.55 else glass[2])
        if burnt:
            for i, j in f.cells():
                if r.random() < 0.15:
                    f.set(i, j, hexc("3a3430"))
            for i in range(f.w):
                f.set(i, f.h - 1 - r.randint(0, 1), hexc("8a8a86") if r.random() < 0.3 else glass[0])
            return
        for k in range(seats):
            cx = int(f.w * (k + 0.5) / max(1, seats))
            f.rect(cx - 2, f.h // 2 - 1, cx + 1, f.h - 1, glass[0])
            f.rect(cx - 1, f.h // 2 - 3, cx, f.h // 2 - 2, glass[0])
        if dash:
            f.rect(0, f.h - 3, f.w - 1, f.h - 1, glass[0])
        for i, j in f.cells():
            if (i + j * 2) % 23 in (0, 1):
                f.set(i, j, mix(f.get(i, j), glass[4], 0.55))
        for i in range(f.w):
            f.set(i, 0, glass[3])
        if broken:
            cx, cy = r.randrange(f.w), r.randrange(f.h)
            for i, j in f.cells():
                d = abs(i - cx) + abs(j - cy) * 2
                if d < 4 or (d < 7 and r.random() < 0.4):
                    f.set(i, j, hexc("141418"))
                elif (i - cx) * (j - cy) == 0 or abs(i - cx) == abs(j - cy) * 2:
                    f.set(i, j, glass[4])

    F["side_sedan"] = sh.face(30, 12)
    window(F["side_sedan"], seats=2)
    F["side_pickup"] = sh.face(16, 13)
    window(F["side_pickup"], seats=1)
    F["wind"] = sh.face(48, 15)
    window(F["wind"], dash=True)
    F["rear"] = sh.face(48, 15)
    window(F["rear"], seats=2)
    F["back_pickup"] = sh.face(48, 13)
    window(F["back_pickup"], seats=2)
    F["glass"] = sh.face(8, 8)
    window(F["glass"])
    F["head"] = sh.face(10, 5)
    f = F["head"]
    bevel(f, chrome)
    if burnt:
        f.rect(1, 1, 8, 3, hexc("141212"))
    else:
        f.rect(1, 1, 8, 3, hexc("f0ecd0"))
        f.rect(2, 1, 4, 2, hexc("fffff4"))
        f.rect(6, 2, 8, 3, hexc("d8d0a0"))
        if broken:
            f.rect(4, 1, 8, 3, hexc("1a1a1e"))
            f.set(5, 2, hexc("c8c4a8"))
    F["tail"] = sh.face(9, 4)
    f = F["tail"]
    f.rect(0, 0, 8, 3, hexc("8a1a14") if not burnt else hexc("1a1414"))
    if not burnt:
        f.rect(1, 1, 5, 2, hexc("d83a28"))
        f.rect(6, 1, 7, 2, hexc("e8a040"))
        f.set(1, 1, hexc("ff8a70"))
    F["grille"] = sh.face(24, 7)
    f = F["grille"]
    for i, j in f.cells():
        f.set(i, j, hexc("1c1c20") if j % 2 else chrome[1])
    f.rect(0, 0, 23, 0, chrome[3])
    F["bumper"] = sh.face(55, 4)
    f = F["bumper"]
    bevel(f, ramp("3a3a40") if not burnt else ramp("2a2420"))
    F["bumper_top"] = sh.face(55, 3)
    bevel(F["bumper_top"], ramp("4a4a52") if not burnt else ramp("2a2420"))
    F["plate"] = sh.face(10, 4)
    f = F["plate"]
    f.rect(0, 0, 9, 3, hexc("e0dccc") if not burnt else hexc("4a4038"))
    f.rect(0, 0, 9, 0, hexc("3a5a9a") if not burnt else hexc("2a2420"))
    for i in (1, 2, 4, 5, 7, 8):
        f.set(i, 2, hexc("2a2a30"))
    F["wheel"] = sh.face(16, 16)
    f = F["wheel"]
    for i, j in f.cells():
        d = ((i - 7.5) ** 2 + (j - 7.5) ** 2) ** 0.5
        if burnt:
            col = ramp("5a4a40")[1 if d > 6 else 2] if d < 7.5 else hexc("2a2622")
        else:
            col = rubber[2] if d > 5.5 else chrome[3] if d > 4.5 else chrome[2] if d > 1.5 else chrome[1]
            if d > 7:
                col = rubber[1]
            if 5.5 < d < 6.5 and i + j < 15:
                col = rubber[3]
        f.set(i, j, col)
    if not burnt:
        for i, j in ((7, 4), (4, 7), (11, 8), (8, 11)):
            f.set(i, j, chrome[0])
    F["tread"] = sh.face(16, 8)
    f = F["tread"]
    for i, j in f.cells():
        f.set(i, j, (rubber[1] if (i + j) % 4 < 2 else rubber[2]) if not burnt else ramp("5a4a40")[1 + (i % 2)])
    F["bed"] = sh.face(25, 20)
    f = F["bed"]
    for i, j in f.cells():
        f.set(i, j, ramp("3a3a40")[1 if i % 4 == 0 else 2 if i % 4 != 1 else 3])
    F["dark"] = sh.face(2, 2)
    F["dark"].rect(0, 0, 1, 1, hexc("16161a"))
    sh.save()
    return sh, F


def car_parts_vcm(psh, F):
    out = []

    def part(frm, to, front_key, front_side, other="dark"):
        net = {s: F[other] for s in SIDES}
        net[front_side] = F[front_key]
        out.append(box(frm, to, "blocks:" + psh.name, net, psh))

    for sx in (-1, 1):
        part((min(sx * 14, sx * 24), -5, 48), (max(sx * 14, sx * 24), 0, 48.8), "head", "south")
        part((min(sx * 16, sx * 25), -5, -48.8), (max(sx * 16, sx * 25), -1, -48), "tail", "north")
    part((-12, -6, 48), (12, 1, 48.5), "grille", "south")
    for z0, z1, s in ((48, 50.5, "south"), (-50.5, -48, "north")):
        net = {k: F["bumper"] for k in SIDES}
        net["top"] = F["bumper_top"]
        out.append(box((-27.5, -13, z0), (27.5, -9, z1), "blocks:" + psh.name, net, psh))
    part((-5, -12.6, 50.5), (5, -9.4, 50.8), "plate", "south")
    part((-5, -7, -48.4), (5, -3, -48), "plate", "north")
    return out


def wheel_boxes(psh, F, drop=0.0, flat=False):
    out = []
    for sx in (-1, 1):
        for zc in (WHEEL_Z, -WHEEL_Z):
            for h, w, off in (WHEELS[:2] if flat else WHEELS):
                yc = -14.5 - drop
                outer = sx * (27 + off)
                x0, x1 = sorted((outer, sx * 20))
                wf = F["wheel"]
                sub = Face(wf.c, wf.x + (16 - w) // 2, wf.y + (16 - h) // 2, w, h)
                net = {s: F["tread"] for s in SIDES}
                net["west" if sx < 0 else "east"] = sub
                hh = h / 2 * (0.6 if flat else 1)
                out.append(box((x0, yc - hh, zc - w / 2), (x1, yc + hh, zc + w / 2), "blocks:" + psh.name, net, psh))
    return out


def cabin_glass(psh, F, group):
    g = "blocks:" + psh.name
    out = []
    tri = psh.region(F["glass"])
    if group == "sedan":
        net = {s: F["glass"] for s in SIDES}
        net["west"] = net["east"] = F["side_sedan"]
        out.append(box((-24, 3, -20), (24, 15, 10), g, net, psh))
        for z0, rot, key in ((18, -35, "wind"), (-28, 35, "rear")):
            net = {s: F["glass"] for s in SIDES}
            net["south" if z0 > 0 else "north"] = F[key]
            extra = " origin %s rotate (%g,0,0)" % (vec((0, 3, z0)), rot)
            out.append(box((-24, 3, z0 - 0.5), (24, 17.5, z0 + 0.5), g, net, psh, extra))
        for zc, ze in ((10, 18), (-20, -28)):
            for x in (-24, 24):
                out.append("@tri a %s b %s c %s texture \"%s\" region %s cull-face off" % (
                    vec((x, 3, zc)), vec((x, 3, ze)), vec((x, 15, zc)), g, tri))
    else:
        net = {s: F["glass"] for s in SIDES}
        net["west"] = net["east"] = F["side_pickup"]
        net["north"] = F["back_pickup"]
        out.append(box((-24, 3, -6), (24, 15, 10), g, net, psh))
        net = {s: F["glass"] for s in SIDES}
        net["south"] = F["wind"]
        out.append(box((-24, 3, 17.5), (24, 17.5, 18.5), g, net, psh, " origin %s rotate (-35,0,0)" % vec((0, 3, 18))))
        for x in (-24, 24):
            out.append("@tri a %s b %s c %s texture \"%s\" region %s cull-face off" % (
                vec((x, 3, 10)), vec((x, 3, 18)), vec((x, 15, 10)), g, tri))
        net = {s: F["bed"] for s in SIDES}
        out.append(box((-25, -8, -46), (25, -6, -8), g, net, psh))
    return out


def pillars(sh, plain, group):
    out = []
    net = {s: plain for s in SIDES}
    tex = "$paint"
    for x0, x1 in ((-24.6, -22.5), (22.5, 24.6)):
        out.append(box((x0, 3, 17.3), (x1, 17.5, 18.7), tex, net, sh, " origin %s rotate (-35,0,0)" % vec((0, 3, 18))))
        if group == "sedan":
            out.append(box((x0, 3, -28.7), (x1, 17.5, -27.3), tex, net, sh, " origin %s rotate (35,0,0)" % vec((0, 3, -28))))
    return out


def car_model(layout, sh, nets, plain, psh, F, tex):
    groups = {"body": [], "sedan": [], "pickup": []}
    for net, (group, frm, to, hidden, dark) in zip(nets, layout.boxes):
        groups[group].append(box(frm, to, tex, net, sh))
    for group in ("sedan", "pickup"):
        groups[group] += cabin_glass(psh, F, group) + pillars(sh, plain, group)
    groups["body"] += car_parts_vcm(psh, F)
    return groups


WRECKS = {"red": ("a83228", None), "blue": ("30589a", None), "white": ("d8d8d0", None),
          "police": ("26282e", "e0e0dc"), "army": ("4e5a34", None), "burnt": ("3a302a", None)}


def car():
    layout = car_layout()
    psh, F = parts_sheet("car_parts", "clean")
    sheets = [paint_sheet("car_" + name, ramp(col), "clean", layout) for name, col in CAR_COLORS.items()]
    sh, nets, plain = sheets[0]
    g = car_model(layout, sh, nets, plain, psh, F, "$paint")
    write_model("zomboid_car", [bone("body", None, g["body"] + wheel_boxes(psh, F) + [
        bone("sedan", None, g["sedan"]), bone("pickup", None, g["pickup"])])])

    for paint, (col, doors) in WRECKS.items():
        mode = "burnt" if paint == "burnt" else "wreck"
        tex = "car_wreck_" + paint
        wsh, wnets, wplain = paint_sheet(tex, ramp(col), mode, layout, ramp(doors) if doors else None)
        wpsh, wF = parts_sheet("car_parts_" + mode, mode)
        g = car_model(layout, wsh, wnets, wplain, wpsh, wF, "blocks:" + tex)
        parts = g["body"] + wheel_boxes(wpsh, wF, drop=-3, flat=True) + g["sedan"]
        if paint == "police":
            parts += [box((-12, 16.5, -6), (-1, 18.5, -2), "blocks:mdl_blue"), box((1, 16.5, -6), (12, 18.5, -2), "blocks:mdl_red"),
                      box((-1, 16.5, -6), (1, 18, -2), "blocks:mdl_iron")]
        parts = [p.replace('"$paint"', '"blocks:%s"' % tex) for p in parts]
        write_model("zomboid_car_wreck_" + paint, [bone(None, (32, 16.3, 48), [bone(None, None, parts, rotate=(1.5, 0, -2.5))])])

# ---------- items in hand / on the ground ----------

def materials():
    def tile(name, tones, fn):
        c = Canvas(32, 32, seed=zlib.crc32(name.encode()))
        for x, y in c.rect_m(0, 0, 31, 31):
            c.set(x, y, tones[fn(x, y, c.r)])
        save_tex("mdl_" + name, c)

    grain = lambda x, y, r: 1 if x % 5 == 0 else 3 if x % 5 == 2 and y % 9 > 2 else 2
    tile("wood", PAL["wood"], grain)
    tile("wood_dark", PAL["wood_dark"], grain)
    tile("steel", PAL["steel"], lambda x, y, r: 3 if x % 6 == 1 else 2)
    tile("blade", ramp("c8ced6"), lambda x, y, r: 4 if x % 8 == 3 else 3 if x % 8 < 3 else 2)
    tile("iron", PAL["iron"], lambda x, y, r: 3 if (x + y) % 11 == 0 else 2)
    tile("gunmetal", ramp("33363e"), lambda x, y, r: 3 if y % 8 == 0 else 2)
    tile("grip", ramp("2a2a2e"), lambda x, y, r: 1 if (x + y) % 4 == 0 else 3 if (x + y) % 4 == 2 else 2)
    tile("red", PAL["plastic_red"], lambda x, y, r: 3 if (x * 3 + y) % 17 == 0 else 2)
    tile("blue", PAL["plastic_blue"], lambda x, y, r: 3 if (x * 3 + y) % 17 == 0 else 2)
    tile("yellow", PAL["cloth_yellow"], lambda x, y, r: 2)
    tile("lens", ramp("f0e8a0"), lambda x, y, r: 4 if x + y < 20 else 3)
    tile("brass", PAL["brass"], lambda x, y, r: 3 if x % 7 == 2 else 2)
    tile("cloth", PAL["cloth_white"], lambda x, y, r: 1 if (x * 7 + y * 3) % 23 == 0 else 2)
    tile("stone", PAL["stone"], lambda x, y, r: 1 if (x // 4 + y // 4) % 3 == 0 and r.random() < 0.3 else 2)
    tile("bark", ramp("5a3e26"), lambda x, y, r: 1 if x % 4 == 0 else 3 if x % 7 == 3 else 2)


ITEM_MODELS = {
    "bat": (-45, 1, [
        ((-2, 0, -2), (2, 1.5, 2), "grip"), ((-1, 1.5, -1), (1, 9, 1), "grip"),
        ((-1.2, 9, -1.2), (1.2, 14, 1.2), "wood"), ((-1.6, 14, -1.6), (1.6, 20, 1.6), "wood"),
        ((-2, 20, -2), (2, 25.5, 2), "wood"), ((-1.6, 25.5, -1.6), (1.6, 26, 1.6), "wood")]),
    "axe": (-45, 1, [
        ((-0.9, 0, -0.9), (0.9, 24, 0.9), "wood"), ((-1.5, 18, -1.2), (2.5, 23, 1.2), "iron"),
        ((2.5, 17, -0.7), (7, 24, 0.7), "steel"), ((7, 16.5, -0.4), (8, 24.5, 0.4), "blade"),
        ((-3, 19, -1), (-1.5, 22, 1), "iron")]),
    "knife": (-45, 1, [
        ((-0.9, 0, -0.7), (0.9, 7, 0.7), "grip"), ((-1.6, 7, -1), (1.6, 8, 1), "steel"),
        ((-1, 8, -0.3), (1.2, 17, 0.3), "blade"), ((-0.4, 17, -0.25), (1, 19, 0.25), "blade")]),
    "crowbar": (-45, 1, [
        ((-0.8, 2, -0.8), (0.8, 22, 0.8), "red"), ((-0.8, 0, -0.6), (2.5, 2, 0.6), "red"),
        ((0.8, 20, -0.8), (3.5, 22, 0.8), "red"), ((2.5, 22, -0.6), (4, 24.5, 0.6), "red"),
        ((3, 24.5, -0.4), (4.5, 25.5, 0.4), "steel"), ((2.5, -0.5, -0.4), (3.5, 1, 0.4), "steel")]),
    "hammer": (-45, 1, [
        ((-0.8, 0, -0.8), (0.8, 17, 0.8), "wood"), ((-1, 0, -1), (1, 5, 1), "grip"),
        ((-2, 15, -1.2), (4, 18, 1.2), "iron"), ((4, 15.3, -1.4), (5, 17.7, 1.4), "steel"),
        ((-5, 16, -0.8), (-2, 17.5, 0.8), "iron"), ((-5.5, 14.5, -0.8), (-4, 16, 0.8), "iron")]),
    "frying_pan": (-45, 1, [
        ((-7, 7, -0.8), (7, 17, 0.8), "iron"), ((-6, 5, -0.8), (6, 19, 0.8), "iron"),
        ((-4, 4, -0.8), (4, 20, 0.8), "iron"), ((-5, 6, 0.8), (5, 18, 1), "gunmetal"),
        ((-0.9, -8, -0.6), (0.9, 4.5, 0.6), "iron"), ((-1.1, -8, -0.8), (1.1, -1, 0.8), "grip")]),
    "spear": (-45, 0.8, [
        ((-0.7, 0, -0.7), (0.7, 26, 0.7), "wood"), ((-1, 22, -1), (1, 25, 1), "grip"),
        ((-1, 25, -0.3), (1.2, 31, 0.3), "blade"), ((-0.4, 31, -0.25), (0.8, 33, 0.25), "blade")]),
    "pistol": (0, 1, [
        ((-4, 3, -1), (6, 6, 1), "gunmetal"), ((-4, 1.5, -0.9), (4, 3, 0.9), "gunmetal"),
        ((6, 3.8, -0.6), (6.5, 5.2, 0.6), "iron"), ((-4, -5, -0.95), (-0.5, 1.5, 0.95), "grip"),
        ((-0.5, 0, -0.5), (2.5, 0.6, 0.5), "gunmetal"), ((2, 0.6, -0.5), (2.5, 1.5, 0.5), "gunmetal"),
        ((0.5, 0.6, -0.3), (1, 1.5, 0.3), "iron"), ((5, 6, -0.3), (5.6, 6.6, 0.3), "iron")]),
    "shotgun": (25, 0.8, [
        ((-14, -2, -1), (-6, 2, 1), "wood"), ((-15, -3, -1.1), (-14, 2.2, 1.1), "grip"),
        ((-6, -1, -0.9), (-3, 1.5, 0.9), "wood"), ((-3, -0.5, -1), (3, 2.5, 1), "gunmetal"),
        ((3, 1, -0.7), (17, 2.4, 0.7), "iron"), ((3, -0.3, -0.6), (14, 1, 0.6), "iron"),
        ((6, -1, -1), (11, 1.2, 1), "wood_dark"), ((-1, -1.5, -0.3), (0, -0.5, 0.3), "iron")]),
    "flashlight": (-45, 1, [
        ((-1.3, 0, -1.3), (1.3, 9, 1.3), "grip"), ((-2, 9, -2), (2, 12, 2), "iron"),
        ((-1.6, 12, -1.6), (1.6, 12.3, 1.6), "lens"), ((1.3, 5, -0.5), (1.7, 6.5, 0.5), "red")]),
    "gas_can": (0, 1, [
        ((-5, 0, -2.5), (5, 11, 2.5), "red"), ((-4, 12, -0.8), (1, 13.5, 0.8), "red"),
        ((-4, 11, -0.8), (-3, 12, 0.8), "red"), ((0, 11, -0.8), (1, 12, 0.8), "red"),
        ((2, 11, -0.8), (4, 13, 0.8), "iron"), ((2.5, 13, -0.6), (3.5, 14, 0.6), "yellow"),
        ((-5.2, 3, -2.7), (5.2, 4, 2.7), "red")]),
}
ITEM_MODELS["spiked_bat"] = (-45, 1, ITEM_MODELS["bat"][2] + [
    b for y in (21, 23, 25) for b in (((-3.5, y, -0.25), (3.5, y + 0.5, 0.25), "steel"),
                                      ((-0.25, y + 1, -3.5), (0.25, y + 1.5, 3.5), "steel"))])
ITEM_USERS = {"gas_can_empty": "gas_can"}


def items():
    materials()
    for name, (angle, scale, parts) in ITEM_MODELS.items():
        lo = [min(p[0][i] for p in parts) for i in range(3)]
        hi = [max(p[1][i] for p in parts) for i in range(3)]
        center = tuple(-(a + b) / 2 for a, b in zip(lo, hi))
        boxes = [box(a, b, "blocks:mdl_" + m) for a, b, m in parts]
        write_model("zomboid_item_" + name, [bone(None, center, boxes, rotate=(0, 0, angle) if angle else None,
                                                  scale=scale if scale != 1 else None)])


# ---------- blocks with custom geometry (faces without a material use the block's own textures) ----------

def B(frm, to, mat=None, extra=""):
    return box(frm, to, "blocks:mdl_" + mat if mat else None, extra=extra) if mat else \
        "@box from %s to %s%s" % (vec(frm), vec(to), extra)


def octo(x0, y0, z0, x1, y1, z1, cut, mat=None):
    """Octagonal prism from three overlapping boxes; tops differ slightly to avoid z-fighting."""
    return [B((x0 + cut, y0, z0), (x1 - cut, y1, z1), mat), B((x0, y0, z0 + cut), (x1, y1 - 0.05, z1 - cut), mat),
            B((x0 + cut / 2, y0, z0 + cut / 2), (x1 - cut / 2, y1 - 0.1, z1 - cut / 2), mat)]


def block_models():
    rot = lambda a: " rotate (0,%g,0)" % a
    m = {}
    m["generator"] = [
        B((4, 3, 6), (28, 20, 26)),
        B((6, 20, 9), (26, 25, 23), "red"), B((20, 25, 13), (23, 26.5, 16), "iron"),
        B((26, 13, 8), (30.5, 15, 10), "iron"), B((29, 13, 8), (30.5, 18, 10), "iron"),
        B((2, 0, 4), (30, 1.5, 6), "iron"), B((2, 0, 26), (30, 1.5, 28), "iron"),
    ] + [B((x, 0, z), (x + 1.5, 26, z + 1.5), "iron") for x in (2, 28.5) for z in (4, 26.5)] + [
        B((2, 25, 4), (30, 26.5, 5.5), "iron"), B((2, 25, 26.5), (30, 26.5, 28), "iron")]
    m["rain_barrel"] = octo(4, 0, 4, 28, 30, 28, 7) + [
        B((4.5, y, 6.5), (27.5, y + 1.2, 25.5), "iron") for y in (5, 23)] + [
        B((6.5, y, 4.5), (25.5, y + 1.2, 27.5), "iron") for y in (5, 23)]
    m["fuel_pump"] = [
        B((2, 0, 5), (30, 3, 27), "stone"), B((4, 3, 8), (28, 52, 24)),
        B((3, 52, 6), (29, 59, 26), "red"), B((5, 59, 9), (27, 60, 23), "iron"),
        B((28, 30, 13), (31, 38, 19), "iron"), B((28.5, 36, 14.5), (30.5, 41, 17.5), "grip"),
        B((29, 9, 15), (30.5, 30, 16.5), "grip"), B((26, 8, 15), (29, 9.5, 16.5), "grip"),
    ]
    m["alarm_clock"] = [
        B((11, 1.5, 13), (21, 11.5, 19)),
        B((10, 11, 14.5), (14, 14, 17.5), "brass"), B((18, 11, 14.5), (22, 14, 17.5), "brass"),
        B((15.5, 11.5, 15.5), (16.5, 14.5, 16.5), "iron"), B((13, 14, 15.7), (19, 14.6, 16.3), "iron"),
        B((11.5, 0, 14.5), (13, 1.5, 17.5), "iron"), B((19, 0, 14.5), (20.5, 1.5, 17.5), "iron"),
    ]
    m["siren"] = [
        B((8, 0, 8), (24, 8, 24)), B((13, 8, 13), (19, 11, 19), "iron"),
        B((10, 11, 10), (22, 16, 22)), B((12, 16, 12), (20, 18, 20), "red"), B((14, 18, 14), (18, 19, 18), "red"),
        B((22, 12, 14), (26, 15, 18), "iron"), B((25, 11.5, 13.5), (26.5, 15.5, 18.5), "iron"),
    ]
    m["campfire"] = [B((10, 0, 10), (22, 1, 22))] + [
        B((4, 0.5, 14.5), (28, 3.5, 17.5), "bark", " origin (0.5,0.0625,0.5)" + rot(a)) for a in (0, 60, 120)] + [
        B((6, 2.5, 15), (26, 5, 17), "bark", " origin (0.5,0.1172,0.5)" + rot(a)) for a in (30, 90, 150)] + [
        B((15 + 11 * c - 1.5, 0, 15 + 11 * s_ - 1.5), (15 + 11 * c + 1.5, 2.5, 15 + 11 * s_ + 1.5), "stone")
        for c, s_ in ((1, 0), (0.7, 0.7), (0, 1), (-0.7, 0.7), (-1, 0), (-0.7, -0.7), (0, -1), (0.7, -0.7))]
    m["bed"] = [
        B((1, 0, 1), (3, 5, 3), "wood_dark"), B((29, 0, 1), (31, 5, 3), "wood_dark"),
        B((1, 4, 1), (31, 8, 31), "wood"), B((2, 8, 2), (30, 15, 29)),
        B((5, 15, 23), (27, 18, 28.5), "cloth"), B((0, 0, 29), (32, 24, 32), "wood_dark"),
        B((0, 22, 28.5), (32, 25, 32), "wood"), B((0, 0, 0), (32, 11, 1.5), "wood_dark"),
    ]
    m["couch"] = [
        B((1, 0, 2), (3, 3, 4), "wood_dark"), B((29, 0, 2), (31, 3, 4), "wood_dark"),
        B((1, 0, 27), (3, 3, 29), "wood_dark"), B((29, 0, 27), (31, 3, 29), "wood_dark"),
        B((4, 3, 1), (28, 10, 24)), B((1, 3, 23), (31, 20, 31)), B((0, 3, 1), (4.5, 14, 31)), B((27.5, 3, 1), (32, 14, 31)),
        B((5, 10, 2), (16, 11.5, 23)), B((16, 10, 2), (27, 11.5, 23)),
    ]
    m["tv"] = [
        B((2, 4, 5), (30, 24, 20)), B((6, 7, 20), (26, 22, 27), "gunmetal"), B((9, 9, 27), (23, 20, 29), "gunmetal"),
        B((4, 0, 8), (28, 4, 24), "wood_dark"),
        B((15, 24, 12), (17, 25, 14), "iron"),
        B((15.6, 24, 12.6), (16.4, 36, 13.4), "steel", " origin (0.5,0.75,0.4062) rotate (0,0,30)"),
        B((15.6, 24, 12.6), (16.4, 36, 13.4), "steel", " origin (0.5,0.75,0.4062) rotate (0,0,-30)"),
    ]
    for name, parts in m.items():
        write_model("zomboid_block_" + name, parts)


if __name__ == "__main__":
    os.makedirs(BLOCKS, exist_ok=True)
    zombie()
    car()
    items()
    block_models()
