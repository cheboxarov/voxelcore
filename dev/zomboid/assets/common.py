import colorsys
import os
import random
import struct
import zlib

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "res", "content", "zomboid"))
BLOCKS = os.path.join(ROOT, "textures", "blocks")
ITEMS = os.path.join(ROOT, "textures", "items")
MODELS = os.path.join(ROOT, "models")
CLEAR = (0, 0, 0, 0)


def save_png(path, pixels, w, h):
    raw = b"".join(b"\x00" + b"".join(struct.pack("BBBB", *pixels[y * w + x]) for x in range(w)) for y in range(h))

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


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (a[3] if len(b) < 4 else int(round(a[3] + (b[3] - a[3]) * t)),)


def alpha(c, a):
    return c[:3] + (a,)


def _hue_toward(h, target, t):
    d = (target - h + 0.5) % 1.0 - 0.5
    return (h + d * t) % 1.0


def ramp(base, a=None):
    c = hexc(base) if isinstance(base, str) else base
    h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in c[:3]))
    out = []
    tones = ((l * 0.42, 0.66, 0.12, 1.1), (l * 0.7, 0.66, 0.06, 1.05), (l, h, 0, 1.0),
             (l + (1 - l) * 0.2, 0.13, 0.05, 0.95), (l + (1 - l) * 0.42, 0.13, 0.1, 0.85))
    for nl, target, hue_t, sat in tones:
        nh = _hue_toward(h, target, hue_t)
        r, g, b = colorsys.hls_to_rgb(nh, max(0, min(1, nl)), max(0, min(1, s * sat)))
        out.append((int(r * 255), int(g * 255), int(b * 255), c[3] if a is None else a))
    return out


PAL = {name: ramp(col) for name, col in {
    "wood": "a87a4a", "wood_dark": "6e4a2c", "wood_pale": "c8a878", "steel": "9aa2ac", "iron": "5c6168",
    "rust": "8a4a2a", "brass": "c8a040", "paper": "e8e0c8", "cardboard": "b08c5c", "leather": "6a4428",
    "rubber": "34343a", "plastic_red": "c03a30", "plastic_blue": "3a6ab0", "plastic_white": "dcdcd4",
    "cloth_red": "a83a34", "cloth_blue": "3a5a8a", "cloth_green": "4a6a3a", "cloth_white": "d8d4c8",
    "cloth_yellow": "d8b030", "denim": "3a5480", "skin": "d8a878", "zskin": "7f9a6a", "blood": "8a1a18",
    "glass": "a8d0e0", "water": "4a90d0", "fire": "f08a28", "grass": "5a8a3a", "soil": "5a3e26",
    "stone": "8a8a86", "asphalt": "3e3e44",
}.items()}


class Canvas:
    def __init__(self, w=16, h=None, seed=0, fill=CLEAR):
        self.w, self.h = w, h or w
        self.p = [fill] * (self.w * self.h)
        self.r = random.Random(seed)

    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def set(self, x, y, c):
        if self.inside(x, y):
            self.p[y * self.w + x] = c

    def get(self, x, y):
        return self.p[y * self.w + x] if self.inside(x, y) else CLEAR

    def blend(self, x, y, c, t):
        if self.inside(x, y):
            self.set(x, y, mix(self.get(x, y), c, t))

    def rect_m(self, x0, y0, x1, y1):
        return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}

    def ellipse_m(self, cx, cy, rx, ry):
        return {(x, y) for y in range(int(cy - ry) - 1, int(cy + ry) + 2) for x in range(int(cx - rx) - 1, int(cx + rx) + 2)
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1}

    def line_m(self, x0, y0, x1, y1, w=1):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        pts = {(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n)) for i in range(n + 1)}
        return {(x + dx, y + dy) for x, y in pts for dx in range(w) for dy in range(w)}

    def poly_m(self, pts):
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        out = set()
        for y in range(int(min(ys)), int(max(ys)) + 1):
            for x in range(int(min(xs)), int(max(xs)) + 1):
                px, py, inside = x + 0.5, y + 0.5, False
                for i in range(len(pts)):
                    (ax, ay), (bx, by) = pts[i], pts[i - 1]
                    if (ay > py) != (by > py) and px < ax + (bx - ax) * (py - ay) / (by - ay):
                        inside = not inside
                if inside:
                    out.add((x, y))
        return out

    def fill(self, mask, c):
        for x, y in mask:
            self.set(x, y, c)

    def paint(self, mask, tones, grad=True):
        if not mask:
            return
        xs, ys = [p[0] for p in mask], [p[1] for p in mask]
        x0, y0, sw, sh = min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
        for x, y in mask:
            score = ((x, y - 1) not in mask) + ((x - 1, y) not in mask) - ((x, y + 1) not in mask) - ((x + 1, y) not in mask)
            t = 2 + max(-1, min(2, score))
            if t == 2 and grad and sw > 3 and sh > 3:
                g = ((x - x0) / sw + (y - y0) / sh) / 2
                t = 3 if g < 0.22 else 1 if g > 0.78 else 2
            self.set(x, y, tones[t])

    def rect(self, x0, y0, x1, y1, c):
        self.fill(self.rect_m(x0, y0, x1, y1), c)

    def frame(self, x0, y0, x1, y1, c):
        self.fill(self.rect_m(x0, y0, x1, y1) - self.rect_m(x0 + 1, y0 + 1, x1 - 1, y1 - 1), c)

    def line(self, x0, y0, x1, y1, c, w=1):
        self.fill(self.line_m(x0, y0, x1, y1, w), c)

    def ellipse(self, cx, cy, rx, ry, c):
        self.fill(self.ellipse_m(cx, cy, rx, ry), c)

    def poly(self, pts, c):
        self.fill(self.poly_m(pts), c)

    def outline(self, ink=(28, 20, 34), k=0.62):
        src = list(self.p)
        for y in range(self.h):
            for x in range(self.w):
                if src[y * self.w + x][3]:
                    continue
                near = [src[ny * self.w + nx] for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
                        if self.inside(nx, ny) and src[ny * self.w + nx][3] > 40]
                if near:
                    c = max(near, key=lambda v: v[3])
                    self.set(x, y, alpha(mix(shade(c, 0.45), ink, k), 255))

    def noise(self, amount=0.04, mask=None):
        for x, y in (mask if mask is not None else self.rect_m(0, 0, self.w - 1, self.h - 1)):
            c = self.get(x, y)
            if c[3]:
                self.set(x, y, shade(c, 1 + self.r.uniform(-amount, amount)))

    def save(self, path):
        save_png(path, self.p, self.w, self.h)
