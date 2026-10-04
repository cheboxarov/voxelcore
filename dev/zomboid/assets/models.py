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

    def net(self, w, h, d):
        nw, nh = 2 * (w + d), d + h
        if self.cx + nw > self.c.w:
            self.cx, self.cy, self.row = 0, self.cy + self.row, 0
        x0, y0 = self.cx, self.cy
        self.cx += nw
        self.row = max(self.row, nh)
        assert y0 + nh <= self.c.h, (self.name, w, h, d)
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
    parts = ["    @part tags (%s) region %s" % (s, sheet.region(net[s])) for s in SIDES]
    return head + " {\n" + "\n".join(parts) + "\n}"


def bone(name, move, children, rotate=None):
    attrs = (" name '%s'" % name if name else "") + (" move %s" % vec(move) if move else "")
    if rotate:
        attrs += " rotate (%s)" % ",".join("%g" % a for a in rotate)
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


if __name__ == "__main__":
    os.makedirs(BLOCKS, exist_ok=True)
    zombie()
