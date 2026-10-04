#!/usr/bin/env python3
import colorsys
import json
import os
import sys
import zlib

sys.path.insert(0, os.path.dirname(__file__))
from common import CLEAR, ITEMS, PAL, ROOT, Canvas, alpha, mix, ramp  # noqa: E402

S = 24
ART = {}
PERISHABLE = ("apple", "bread", "carrot", "potato", "raw_meat", "cooked_meat", "soup", "stew")


def art(fn):
    ART[fn.__name__] = fn
    return fn


def cyl(c, mask, tones):
    xs = [p[0] for p in mask]
    x0, w = min(xs), max(xs) - min(xs) + 1
    for x, y in mask:
        u = (x - x0 + 0.5) / w
        c.set(x, y, tones[4 if 0.18 < u < 0.32 else 3 if u <= 0.18 else 2 if u < 0.62 else 1 if u < 0.88 else 0])


def rod(c, x0, y0, x1, y1, tones, w=2):
    c.paint(c.line_m(x0, y0, x1, y1, w), tones, grad=False)


WOOD, WOOD_D, WOOD_P = PAL["wood"], PAL["wood_dark"], PAL["wood_pale"]
STEEL, IRON, RUBBER = PAL["steel"], PAL["iron"], PAL["rubber"]
WHITE = ramp("e8e6de")
GOLD = ramp("d8b040")


@art
def bat(c):
    rod(c, 4, 19, 10, 13, WOOD_P)
    c.paint(c.line_m(9, 12, 18, 3, 3) | c.line_m(9, 14, 19, 4, 2) | c.line_m(11, 13, 13, 11, 2) | {(20, 3), (19, 2)}, WOOD_P)
    c.paint(c.line_m(4, 19, 7, 16, 2), RUBBER, grad=False)
    for x, y in ((5, 18), (7, 16)):
        c.set(x, y, RUBBER[3])
    c.paint(c.rect_m(2, 20, 4, 22), RUBBER)
    c.line(11, 10, 17, 4, WOOD_P[4])


@art
def spiked_bat(c):
    bat(c)
    for x, y, dx, dy in ((10, 10, -1, -1), (13, 7, -1, -1), (16, 4, -1, -1), (13, 14, 1, 1), (16, 11, 1, 1), (19, 8, 1, 1)):
        c.fill({(x + dx, y + dy), (x + 2 * dx, y + 2 * dy)}, STEEL[4])
        c.set(x + 3 * dx, y + 3 * dy, STEEL[2])
        c.set(x, y, IRON[0])


@art
def axe(c):
    rod(c, 4, 20, 15, 6, WOOD)
    c.paint(c.poly_m([(11, 3), (16, 2), (21, 4), (21, 13), (18, 11), (16, 8), (12, 7)]), STEEL)
    c.paint(c.rect_m(12, 3, 15, 7), PAL["plastic_red"])
    c.line(20, 4, 20, 12, STEEL[4])
    c.line(21, 5, 21, 12, ramp("e8eef2")[4])
    c.paint(c.rect_m(3, 19, 5, 21), WOOD_D)


@art
def knife(c):
    c.paint(c.poly_m([(9, 15), (19, 4), (21, 3), (20, 6), (11, 16)]), STEEL)
    c.line(11, 14, 19, 5, ramp("e8eef2")[4])
    c.paint(c.line_m(8, 14, 11, 17, 1), IRON)
    c.paint(c.line_m(3, 19, 8, 14, 3), PAL["wood_dark"], grad=False)
    for x, y in ((5, 18), (7, 16)):
        c.set(x, y, STEEL[4])


@art
def crowbar(c):
    red = ramp("b0262a")
    rod(c, 6, 19, 17, 6, red)
    c.paint(c.line_m(17, 5, 19, 4, 2) | c.line_m(19, 4, 21, 6, 2) | {(21, 8), (22, 8)}, red)
    c.paint(c.line_m(3, 18, 5, 20, 2) | {(3, 16), (3, 17)}, red)
    c.paint(c.line_m(7, 18, 9, 16, 2), IRON, grad=False)
    c.line(8, 15, 16, 7, red[4])


@art
def frying_pan(c):
    c.paint(c.ellipse_m(9, 13, 8, 7), IRON)
    c.paint(c.ellipse_m(9, 13, 6, 5), RUBBER)
    c.line(5, 11, 7, 9, RUBBER[4])
    rod(c, 16, 10, 21, 5, RUBBER)
    c.paint(c.rect_m(15, 10, 16, 11), IRON)
    c.set(20, 6, RUBBER[1])


@art
def hammer(c):
    rod(c, 3, 21, 13, 11, WOOD)
    c.paint(c.line_m(3, 20, 5, 18, 2) | {(2, 22), (3, 22)}, RUBBER, grad=False)
    head = c.line_m(9, 4, 17, 12, 3) | c.line_m(8, 4, 11, 1, 3)
    head -= c.line_m(17, 13, 21, 17, 1)
    c.paint(head | c.line_m(17, 11, 21, 14, 1) | c.line_m(16, 13, 19, 17, 1), STEEL)
    c.paint(c.line_m(7, 2, 10, 5, 4), IRON)
    c.line(10, 4, 16, 10, STEEL[4])


@art
def spear(c):
    rod(c, 2, 21, 15, 8, WOOD)
    c.paint(c.poly_m([(14, 9), (20, 2), (22, 1), (21, 4), (15, 10)]) | c.line_m(14, 8, 20, 2, 2), STEEL)
    c.line(16, 7, 20, 3, ramp("e8eef2")[4])
    c.paint(c.line_m(12, 11, 15, 8, 3), PAL["cloth_white"], grad=False)
    for x, y in ((13, 11), (15, 9)):
        c.set(x, y, PAL["cloth_white"][1])


@art
def canned_beans(c):
    cyl(c, c.rect_m(6, 5, 17, 20), STEEL)
    cyl(c, c.rect_m(6, 8, 17, 17), ramp("c04a2a"))
    c.paint(c.ellipse_m(12, 5, 6, 2), ramp("dce2e8"))
    c.fill(c.ellipse_m(12, 5, 4, 1), STEEL[1])
    c.line(6, 20, 17, 20, STEEL[0])
    c.line(6, 7, 17, 7, STEEL[1])
    c.line(6, 18, 17, 18, STEEL[1])
    for x, y in ((9, 12), (12, 13), (14, 11), (11, 11)):
        c.fill({(x, y), (x + 1, y)}, ramp("8a4a24")[3])
        c.set(x, y + 1, ramp("8a4a24")[1])
    c.line(8, 15, 15, 15, ramp("f0d060")[3])


@art
def bread(c):
    crust = ramp("c88a40")
    c.paint(c.ellipse_m(12, 13, 10, 6) | c.rect_m(3, 13, 20, 18), crust)
    c.line(3, 19, 20, 19, crust[0])
    for x in (6, 10, 14, 18):
        c.fill(c.line_m(x - 1, 9 + (x == 6 or x == 18), x + 1, 12, 1), crust[1])
        c.fill(c.line_m(x, 9 + (x == 6 or x == 18), x + 2, 12, 1), ramp("f0d8a0")[3])
    c.line(5, 9, 9, 8, crust[4])


@art
def apple(c):
    red = ramp("c02828")
    c.paint(c.ellipse_m(9, 14, 6, 7) | c.ellipse_m(15, 14, 6, 7), red)
    c.fill({(11, 7), (12, 8), (13, 7)}, red[1])
    c.line(12, 3, 12, 7, PAL["wood_dark"][2])
    c.paint(c.ellipse_m(16, 5, 3, 1.6), PAL["grass"])
    c.fill({(6, 11), (7, 10), (6, 12), (8, 10)}, ramp("f07070")[4])


@art
def chips(c):
    bag = ramp("e8c030")
    c.paint(c.poly_m([(5, 3), (19, 3), (18, 12), (20, 21), (4, 21), (6, 12)]), bag)
    for x in range(5, 20, 2):
        c.set(x, 3, bag[1])
        c.set(x, 21, bag[1])
    c.paint(c.ellipse_m(12, 13, 4.5, 3.5), ramp("c03020"))
    c.fill(c.ellipse_m(12, 13, 2.5, 1.8), ramp("f8e0a0")[3])
    c.line(6, 6, 18, 6, ramp("c03020")[2])
    c.line(7, 8, 9, 17, bag[4])


@art
def chocolate(c):
    choc = ramp("6a3a1e")
    c.paint(c.rect_m(4, 3, 19, 12), choc, grad=False)
    for x in (8, 12, 16):
        c.line(x, 3, x, 12, choc[1])
    c.line(4, 7, 19, 7, choc[1])
    for x in (5, 9, 13, 17):
        c.set(x, 4, choc[3])
        c.set(x, 8, choc[3])
    c.paint(c.rect_m(4, 13, 19, 14), ramp("c8ccd2"), grad=False)
    c.paint(c.rect_m(3, 14, 20, 21), ramp("3a5aa0"))
    c.line(5, 17, 18, 17, ramp("e8c040")[3])
    c.line(5, 18, 12, 18, ramp("e8c040")[1])


@art
def rotten_food(c):
    c.paint(c.ellipse_m(12, 18, 11, 4), ramp("c8c4b4"))
    goo = ramp("6a7a34")
    c.paint(c.ellipse_m(12, 14, 9, 5) | c.ellipse_m(9, 11, 5, 4) | c.ellipse_m(15, 12, 4, 3), goo)
    for x, y in ((7, 10), (13, 12), (16, 15), (9, 15), (17, 11)):
        c.fill({(x, y), (x + 1, y), (x, y - 1)}, ramp("d0d8a8")[3])
    for x, y in ((11, 12), (14, 16), (6, 14), (12, 9)):
        c.fill({(x, y), (x + 1, y)}, ramp("3a2a10")[2])
    for x, y in ((19, 4), (5, 5), (14, 2)):
        c.set(x, y, ramp("202024")[2])
        c.set(x - 1, y - 1, alpha(ramp("c8d8e8")[4], 210))
        c.set(x + 1, y - 1, alpha(ramp("c8d8e8")[4], 210))
    for x in (9, 15):
        c.fill({(x, 7), (x + 1, 6), (x, 5), (x + 1, 4)}, alpha(ramp("9aaa50")[3], 160))


def _bottle(c, liquid, label):
    glass = ramp("b8d8e8", 150)
    body = c.rect_m(7, 8, 16, 21) | c.ellipse_m(11.5, 8.5, 5, 3)
    cyl(c, body, glass)
    cyl(c, c.rect_m(10, 3, 13, 6), glass)
    if liquid:
        cyl(c, {p for p in body if p[1] >= 10}, liquid)
    if label:
        cyl(c, c.rect_m(7, 13, 16, 16), label)
    cyl(c, c.rect_m(10, 1, 13, 3), ramp("3060c0"))
    c.line(9, 9, 9, 20, alpha(ramp("ffffff")[4], 220))
    c.line(7, 21, 16, 21, alpha(glass[0], 200))


@art
def water_bottle(c):
    _bottle(c, ramp("4a96e0", 210), ramp("e8f0f8"))
    c.line(10, 14, 13, 14, ramp("3a7ac0")[2])


@art
def dirty_water_bottle(c):
    _bottle(c, ramp("7a7a3a", 225), ramp("c8c0a0"))
    for x, y in ((11, 19), (13, 18), (10, 20), (14, 20), (12, 11)):
        c.set(x, y, ramp("4a3a1a")[2])


@art
def empty_bottle(c):
    _bottle(c, None, None)
    c.line(14, 12, 14, 18, alpha(ramp("ffffff")[3], 160))


@art
def soda(c):
    red = ramp("c82020")
    cyl(c, c.rect_m(7, 5, 16, 20), red)
    c.paint(c.ellipse_m(11.5, 5, 5, 1.6), ramp("d8dce0"))
    c.fill({(11, 4), (12, 4), (13, 4)}, STEEL[1])
    cyl(c, c.rect_m(7, 19, 16, 21), STEEL)
    for x in range(7, 17):
        y = 12 + round(2 * ((x - 7) / 9 - 0.5) ** 2 * 4 - 1)
        c.set(x, y, ramp("f8f8f8")[3])
        c.set(x, y + 1, ramp("f8f8f8")[2])


def _rag(c, cloth):
    m = c.poly_m([(3, 6), (8, 4), (13, 5), (19, 3), (21, 9), (20, 15), (21, 20), (14, 19), (9, 21), (3, 19), (4, 13)])
    c.paint(m, cloth)
    for x0, y0, x1, y1 in ((6, 7, 9, 18), (12, 6, 14, 18), (16, 5, 18, 17)):
        c.fill(c.line_m(x0, y0, x1, y1) & m, cloth[1])
        c.fill(c.line_m(x0 + 1, y0, x1 + 1, y1) & m, cloth[3])
    for x in range(4, 21, 2):
        c.set(x, 20 + (x % 4 == 0), cloth[1])


@art
def rag(c):
    _rag(c, ramp("c8bfa8"))


@art
def dirty_rag(c):
    _rag(c, ramp("8e7e5e"))
    for x, y in ((8, 8), (14, 13), (10, 15), (16, 8), (7, 14)):
        c.fill({(x, y), (x + 1, y), (x, y + 1)}, ramp("5a3a20")[2])
    c.fill({(12, 10), (13, 10), (12, 11)}, PAL["blood"][2])


def _bandage(c, cloth, stain):
    c.paint(c.rect_m(3, 14, 20, 18), cloth)
    for x in range(5, 20, 3):
        c.set(x, 16, cloth[1])
    c.paint(c.ellipse_m(9, 10, 6, 6.5), cloth)
    for r in (4, 2):
        c.fill(c.ellipse_m(9, 10, r + 0.6, r + 0.6) - c.ellipse_m(9, 10, r - 0.4, r - 0.4), cloth[1])
    c.fill(c.ellipse_m(9, 10, 0.9, 0.9), cloth[0])
    if stain:
        for x, y in ((15, 15), (16, 16), (17, 15), (11, 7), (6, 12), (12, 12)):
            c.fill({(x, y), (x + 1, y)}, stain)


@art
def bandage(c):
    _bandage(c, WHITE, None)


@art
def dirty_bandage(c):
    _bandage(c, ramp("c8b890"), PAL["blood"][2])


@art
def disinfectant(c):
    cyl(c, c.rect_m(7, 8, 16, 21) | c.ellipse_m(11.5, 8, 5, 2.5), ramp("6a3a1e", 230))
    cyl(c, c.rect_m(9, 2, 14, 5), WHITE)
    c.paint(c.rect_m(10, 5, 13, 6), WHITE)
    c.paint(c.rect_m(7, 12, 16, 18), WHITE)
    red = ramp("d03030")
    c.fill(c.rect_m(11, 13, 12, 17) | c.rect_m(9, 14, 14, 16), red[2])


def _pill_bottle(c, body, cap, pill):
    cyl(c, c.rect_m(5, 7, 14, 21), body)
    cyl(c, c.rect_m(4, 3, 15, 6), cap)
    c.paint(c.rect_m(5, 11, 14, 17), WHITE)
    c.line(7, 13, 12, 13, body[1])
    c.line(7, 15, 10, 15, ramp("909090")[2])
    for x, y in ((17, 18), (19, 20)):
        c.paint(c.ellipse_m(x, y, 2, 1.6), pill)


@art
def painkillers(c):
    _pill_bottle(c, ramp("e89030", 235), WHITE, WHITE)


@art
def antibiotics(c):
    foil = ramp("c0c6cc")
    c.paint(c.rect_m(3, 4, 20, 19), foil)
    for i in range(3):
        for j in range(2):
            x, y = 6 + i * 5, 7 + j * 7
            c.paint(c.rect_m(x, y, x + 2, y + 1), ramp("c83030"))
            c.paint(c.rect_m(x, y + 2, x + 2, y + 3), WHITE)
    c.line(3, 11, 20, 11, foil[1])


@art
def plank(c):
    m = c.line_m(2, 17, 17, 2, 4)
    c.paint(m, WOOD_P)
    c.fill(c.line_m(4, 18, 19, 3, 1), WOOD_P[1])
    c.fill(c.line_m(5, 16, 14, 7, 1), WOOD_P[3])
    c.fill(c.line_m(8, 16, 15, 9, 1), WOOD_P[1])
    c.set(10, 11, WOOD_D[1])
    c.fill(c.rect_m(2, 17, 3, 20), WOOD_P[1])
    c.fill({(18, 2), (20, 3), (19, 5)}, WOOD_P[0])


@art
def nails(c):
    for x0, y0, x1, y1 in ((4, 5, 9, 19), (10, 3, 13, 18), (15, 6, 18, 20)):
        c.paint(c.line_m(x0, y0 + 1, x1, y1, 1), STEEL, grad=False)
        c.paint(c.line_m(x0 - 2, y0, x0 + 2, y0, 1), STEEL, grad=False)
        c.set(x1, y1, STEEL[1])
        c.set(x0 - 2, y0, STEEL[4])


@art
def flashlight(c):
    body = ramp("3a3a40")
    c.paint(c.line_m(3, 18, 12, 9, 4), body)
    c.paint(c.line_m(12, 7, 15, 4, 6), body)
    c.fill(c.line_m(16, 5, 19, 8, 1) | c.line_m(17, 4, 20, 7, 1), ramp("f8e070")[4])
    c.fill(c.line_m(16, 4, 19, 7, 1), ramp("f8e070")[3])
    c.paint(c.rect_m(8, 13, 9, 14), ramp("c03030"))
    c.line(5, 17, 11, 11, body[4])
    for x, y in ((21, 2), (22, 5), (19, 1)):
        c.set(x, y, alpha(ramp("fff0a0")[4], 160))


@art
def matches(c):
    box = ramp("d8b040")
    c.paint(c.rect_m(3, 9, 20, 19), box)
    c.paint(c.rect_m(5, 11, 18, 17), ramp("c03020"))
    c.fill(c.rect_m(3, 18, 20, 19), ramp("5a3a2a")[2])
    c.paint(c.line_m(11, 3, 11, 13, 1), WOOD_P, grad=False)
    c.paint(c.ellipse_m(11.5, 3, 1.6, 2), ramp("d02020"))
    c.paint(c.line_m(15, 4, 15, 13, 1), WOOD_P, grad=False)
    c.paint(c.ellipse_m(15.5, 4, 1.6, 2), ramp("d02020"))


BOOK_COLORS = {"melee": "8a2a2a", "carpentry": "7a5a34", "cooking": "c86a28", "first_aid": "d8d8d0", "sneaking": "3e5a3a"}


def _emblem(c, skill, x, y):
    ink = ramp("f0e6c8")
    if skill == "melee":
        c.fill(c.line_m(x, y + 6, x + 6, y, 1) | {(x + 5, y), (x + 6, y + 1)}, ink[3])
        c.fill(c.line_m(x, y, x + 6, y + 6, 1) | {(x, y + 1), (x + 1, y)}, ink[2])
    elif skill == "carpentry":
        c.fill(c.rect_m(x, y, x + 6, y + 1), ink[3])
        c.fill(c.rect_m(x + 3, y + 2, x + 4, y + 6), ink[2])
    elif skill == "cooking":
        c.fill(c.rect_m(x + 1, y + 3, x + 5, y + 6) | c.rect_m(x, y + 2, x + 6, y + 2) | {(x - 1, y + 3), (x + 7, y + 3)}, ink[3])
        c.fill({(x + 2, y), (x + 4, y + 1), (x + 4, y - 1)}, ink[2])
    elif skill == "first_aid":
        c.fill(c.rect_m(x + 2, y, x + 4, y + 6) | c.rect_m(x, y + 2, x + 6, y + 4), ramp("c02020")[2])
    else:
        c.fill(c.ellipse_m(x + 3.5, y + 3.5, 3.6, 2.3), ink[3])
        c.fill(c.ellipse_m(x + 3.5, y + 3.5, 1.4, 1.4), ramp("1a2a1a")[2])


def book(skill, volume):
    def draw(c):
        cover = ramp(BOOK_COLORS[skill])
        c.paint(c.rect_m(6, 2, 19, 20), cover)
        c.fill(c.rect_m(5, 3, 18, 21), cover[2])
        c.paint(c.rect_m(5, 2, 18, 20), cover)
        c.paint(c.rect_m(4, 2, 6, 21), ramp(BOOK_COLORS[skill])[:1] + cover[:4], grad=False)
        c.fill(c.rect_m(7, 21, 19, 21), PAL["paper"][3])
        c.fill(c.rect_m(19, 3, 19, 20), PAL["paper"][2])
        c.frame(8, 4, 17, 13, GOLD[1])
        _emblem(c, skill, 9, 5)
        for i in range(volume):
            c.fill(c.rect_m(10 + i * 3, 16, 11 + i * 3, 18), GOLD[3])
    return draw


for _skill in BOOK_COLORS:
    for _volume in (1, 2):
        ART["book_%s_%d" % (_skill, _volume)] = book(_skill, _volume)


@art
def novel(c):
    cover = ramp("5a2a6a")
    c.paint(c.rect_m(5, 2, 18, 21), cover)
    c.paint(c.rect_m(3, 2, 5, 21), cover, grad=False)
    c.fill(c.rect_m(19, 3, 20, 20), PAL["paper"][2])
    for y in range(4, 20, 2):
        c.set(20, y, PAL["paper"][1])
    c.fill(c.rect_m(8, 5, 16, 6), GOLD[3])
    c.fill(c.rect_m(9, 8, 15, 8), GOLD[1])
    c.paint(c.ellipse_m(12, 14, 3, 3), ramp("e8d0a0"))


@art
def magazine(c):
    c.paint(c.poly_m([(4, 3), (19, 2), (20, 21), (5, 22)]), WHITE)
    c.fill(c.rect_m(6, 4, 18, 7), ramp("d03030")[2])
    c.fill(c.rect_m(7, 5, 17, 6), ramp("f8f0f0")[4])
    c.paint(c.rect_m(6, 9, 18, 17), ramp("4a80c0"))
    c.paint(c.ellipse_m(12, 15, 3, 3), PAL["skin"])
    c.paint(c.ellipse_m(12, 11.5, 2.5, 2), ramp("3a2a20"))
    c.line(6, 19, 14, 19, ramp("808080")[2])
    c.line(6, 20, 11, 20, ramp("808080")[3])


@art
def cigarettes(c):
    for x in (8, 11, 14):
        c.paint(c.rect_m(x, 2, x + 1, 6), ramp("e8e0d0"), grad=False)
        c.fill(c.rect_m(x, 2, x + 1, 3), ramp("d89050")[2])
    c.paint(c.rect_m(5, 6, 18, 21), WHITE)
    c.paint(c.poly_m([(5, 6), (19, 6), (19, 11), (12, 15), (5, 11)]), ramp("c02020"))
    c.fill(c.rect_m(5, 6, 18, 6), ramp("c02020")[1])
    c.line(8, 18, 15, 18, ramp("202020")[2])


@art
def knit_hat(c):
    wool = ramp("b03030")
    c.paint(c.ellipse_m(12, 13, 8, 9) & c.rect_m(0, 0, 23, 16), wool)
    for x in (7, 10, 13, 16):
        c.fill(c.line_m(x, 7 + abs(x - 11.5) // 2, x, 15, 1), wool[1])
    c.paint(c.rect_m(3, 16, 20, 20), WHITE)
    for x in range(4, 20, 2):
        c.line(x, 17, x, 19, WHITE[1])
    c.paint(c.ellipse_m(12, 3.5, 2.6, 2.6), WHITE)


def _top(c, cloth, long_sleeves, hood=False, length=20):
    body = c.rect_m(7, 4, 16, length) | c.poly_m([(3, 5), (8, 3), (16, 3), (21, 5), (21, 6), (3, 6)])
    if long_sleeves:
        body |= c.poly_m([(3, 5), (7, 5), (7, 17), (2, 17)]) | c.poly_m([(17, 5), (21, 5), (22, 17), (17, 17)])
    else:
        body |= c.poly_m([(2, 5), (8, 4), (8, 10), (1, 10)]) | c.poly_m([(16, 4), (22, 5), (23, 10), (16, 10)])
    c.paint(body, cloth)
    if long_sleeves:
        c.fill(c.line_m(7, 9, 7, 17), cloth[1])
        c.fill(c.line_m(17, 9, 17, 17), cloth[1])
    c.fill(c.ellipse_m(12, 3, 3, 1.8) & body, cloth[0])
    if hood:
        c.paint(c.ellipse_m(12, 3.5, 4.5, 3.5) - c.ellipse_m(12, 4.5, 2.6, 2.5), cloth)


@art
def tshirt(c):
    cloth = ramp("e0e0dc")
    _top(c, cloth, False, length=19)
    c.fill(c.rect_m(9, 9, 14, 13), ramp("3a6aa0")[2])
    c.fill(c.rect_m(10, 10, 13, 12), ramp("3a6aa0")[3])
    c.line(8, 19, 15, 19, cloth[1])


@art
def sweater(c):
    cloth = ramp("3a6a9a")
    _top(c, cloth, True)
    for y in (9, 12):
        for x in range(8, 16):
            c.set(x, y, cloth[3] if (x + y) % 2 else cloth[4])
    for x0, x1 in ((2, 6), (18, 22), (7, 16)):
        y = 20 if x0 == 7 else 17
        for x in range(x0, x1 + 1):
            c.set(x, y, cloth[1] if x % 2 else cloth[0])


@art
def leather_jacket(c):
    cloth = ramp("3e2a20")
    _top(c, cloth, True)
    c.fill(c.line_m(12, 4, 12, 20), ramp("a8a8a8")[2])
    c.paint(c.poly_m([(8, 3), (12, 4), (10, 9), (7, 5)]) | c.poly_m([(16, 3), (12, 4), (14, 9), (17, 5)]), ramp("4e3628"))
    c.fill({(9, 14), (14, 14)}, cloth[4])
    c.line(5, 8, 5, 15, cloth[4])
    c.line(8, 8, 8, 18, cloth[3])


@art
def raincoat(c):
    cloth = ramp("e8c020")
    _top(c, cloth, True, hood=True, length=22)
    c.fill(c.line_m(12, 6, 12, 22), cloth[1])
    for y in (9, 13, 17):
        c.set(13, y, ramp("3a3020")[2])
    c.line(8, 15, 10, 15, cloth[1])
    c.line(14, 15, 16, 15, cloth[1])


@art
def jeans(c):
    den = PAL["denim"]
    c.paint(c.rect_m(6, 2, 17, 7) | c.poly_m([(6, 7), (12, 7), (11, 22), (5, 22)]) | c.poly_m([(12, 7), (18, 7), (19, 22), (13, 22)]), den)
    c.fill(c.rect_m(6, 2, 17, 3), den[1])
    c.fill(c.line_m(12, 4, 12, 9), den[0])
    for x in (8, 15):
        c.set(x, 2, ramp("c8a050")[3])
    c.fill(c.line_m(7, 5, 9, 7) | c.line_m(16, 5, 14, 7), den[3])
    c.fill(c.rect_m(5, 21, 11, 21) | c.rect_m(13, 21, 19, 21), den[3])
    c.fill(c.line_m(8, 10, 8, 19), den[1])


@art
def boots(c):
    lea = PAL["leather"]
    for dx, k in ((0, 1.0), (9, 0.85)):
        tones = [mix(t, (0, 0, 0, 255), 1 - k) for t in lea]
        c.paint(c.rect_m(3 + dx, 5, 7 + dx, 17) | c.poly_m([(3 + dx, 14), (10 + dx, 14), (13 + dx, 16), (13 + dx, 19), (3 + dx, 19)]), tones)
        c.fill(c.rect_m(3 + dx, 19, 13 + dx, 20), RUBBER[1])
        for y in (8, 11, 14):
            c.fill({(6 + dx, y), (7 + dx, y)}, ramp("d8c8a0")[3])
        c.fill(c.rect_m(3 + dx, 5, 7 + dx, 6), tones[3])


def _bag(c, cloth, hiking):
    top = 7 if hiking else 4
    c.paint(c.ellipse_m(12, top + 8, 8, 8) & c.rect_m(0, top, 23, 22) | c.rect_m(4, top + 7, 19, 21), cloth)
    c.fill(c.rect_m(3, top + 3, 3, 20) | c.rect_m(20, top + 3, 20, 20), cloth[0])
    c.paint(c.rect_m(7, 13, 16, 20), cloth[1:4] + [cloth[3], cloth[4]])
    c.fill(c.rect_m(7, 13, 16, 13), cloth[0])
    c.fill({(11, 14), (12, 14), (12, 15)}, ramp("d0d0d0")[3])
    if hiking:
        roll = ramp("b89a6a")
        cyl(c, c.rect_m(4, 2, 19, 6), [roll[0], roll[1], roll[2], roll[3], roll[4]])
        c.paint(c.ellipse_m(19, 4.5, 1.6, 2.6), roll)
        c.fill({(19, 4), (19, 5)}, roll[0])
        c.fill(c.rect_m(7, 2, 7, 7) | c.rect_m(16, 2, 16, 7), PAL["leather"][1])
        c.fill(c.rect_m(5, 10, 18, 11), PAL["leather"][2])
        c.fill({(11, 10), (12, 11)}, STEEL[3])
        c.paint(c.rect_m(1, 14, 3, 20), cloth)
        c.paint(c.rect_m(20, 14, 22, 20), cloth)
    else:
        c.fill(c.line_m(9, 1, 9, 4) | c.line_m(14, 1, 14, 4) | c.line_m(9, 1, 14, 1), cloth[0])
        c.fill(c.line_m(6, 8, 17, 8), cloth[1])


@art
def school_bag(c):
    _bag(c, ramp("c03a3a"), False)


@art
def hiking_bag(c):
    _bag(c, ramp("4a6a3a"), True)


@art
def stick(c):
    bark = ramp("7a5a30")
    c.paint(c.line_m(3, 20, 18, 4, 2), bark, grad=False)
    c.paint(c.line_m(11, 12, 14, 14, 1) | {(15, 15)}, bark, grad=False)
    c.paint(c.ellipse_m(17, 16.5, 2.2, 1.4), PAL["grass"])
    c.set(4, 20, ramp("d8b880")[3])
    c.set(3, 20, ramp("d8b880")[2])


@art
def splint(c):
    for dx in (0, 4):
        c.paint(c.rect_m(7 + dx, 2, 8 + dx, 21), WOOD_P, grad=False)
    for y in (5, 15):
        c.paint(c.rect_m(5, y, 14, y + 3), WHITE)
        c.line(5, y + 2, 14, y + 1, WHITE[1])


@art
def cooking_pot(c):
    c.paint(c.rect_m(4, 9, 19, 20) | c.ellipse_m(12, 20, 8, 1.5), STEEL)
    cyl(c, c.rect_m(4, 9, 19, 19), STEEL)
    c.paint(c.ellipse_m(12, 8, 9, 2.4), ramp("b8c0c8"))
    c.paint(c.rect_m(10, 4, 13, 6), RUBBER)
    for x in (1, 21):
        c.paint(c.rect_m(x, 11, x + 1, 13), RUBBER)
    c.line(4, 12, 19, 12, STEEL[1])


@art
def raw_meat(c):
    meat = ramp("c83a44")
    c.paint(c.ellipse_m(11, 12, 8.5, 7) | c.ellipse_m(15, 14, 6, 5), meat)
    fat = ramp("f0e0d0")
    c.fill(c.ellipse_m(11, 12, 8.5, 7) - c.ellipse_m(11.5, 12.5, 7.5, 6), fat[3])
    for x0, y0, x1, y1 in ((7, 10, 12, 9), (9, 14, 15, 13), (13, 16, 17, 17)):
        c.fill(c.line_m(x0, y0, x1, y1), fat[2])
    c.paint(c.ellipse_m(17, 9, 2.2, 2.2), fat)
    c.fill(c.ellipse_m(17, 9, 1, 1), meat[1])


@art
def cooked_meat(c):
    meat = ramp("8a4a22")
    c.paint(c.ellipse_m(11, 12, 8.5, 7) | c.ellipse_m(15, 14, 6, 5), meat)
    c.fill(c.ellipse_m(11, 12, 8.5, 7) - c.ellipse_m(11.5, 12.5, 7.5, 6), ramp("c08a50")[3])
    for i in range(4):
        c.fill(c.line_m(6 + i * 4, 17, 10 + i * 4, 7), meat[0])
    c.paint(c.ellipse_m(17, 9, 2.2, 2.2), ramp("e8d8b8"))


def _bowl(c, bowl, food, bits):
    c.paint(c.ellipse_m(12, 11, 10, 3), food)
    for x, y, col in bits:
        c.fill({(x, y), (x + 1, y)}, ramp(col)[3])
        c.set(x, y + 1, ramp(col)[1])
    c.paint(c.ellipse_m(12, 13, 10, 7) & c.rect_m(0, 12, 23, 23), bowl)
    c.fill(c.line_m(2, 12, 21, 12), bowl[3])
    c.paint(c.rect_m(9, 19, 14, 20), bowl)
    steam = alpha(ramp("ffffff")[4], 150)
    for x in (8, 15):
        c.fill({(x, 7), (x + 1, 6), (x, 5), (x + 1, 4), (x, 3)}, steam)


@art
def soup(c):
    _bowl(c, WHITE, ramp("e0a838"), ((6, 10, "e07020"), (11, 9, "4a9a30"), (15, 10, "e07020")))


@art
def stew(c):
    _bowl(c, ramp("8a5a3a"), ramp("6a3418"), ((6, 10, "a05a3a"), (10, 9, "d8c080"), (14, 10, "e07020"), (16, 9, "a05a3a")))


@art
def pistol(c):
    slide, frame = ramp("4a4c52"), ramp("2a2a2e")
    c.paint(c.rect_m(3, 6, 20, 10), slide)
    for x in range(13, 19, 2):
        c.line(x, 7, x, 9, slide[1])
    c.fill(c.rect_m(20, 7, 21, 8), frame[0])
    c.paint(c.rect_m(5, 11, 17, 12), frame)
    c.paint(c.poly_m([(4, 11), (10, 11), (9, 21), (2, 21)]), frame)
    c.fill(c.line_m(3, 19, 8, 13), frame[3])
    c.fill(c.line_m(10, 13, 13, 13) | c.line_m(13, 13, 14, 15) | c.line_m(10, 16, 14, 16), frame[1])
    c.set(11, 14, frame[3])
    c.line(4, 6, 19, 6, slide[4])
    c.set(19, 5, slide[3])


@art
def shotgun(c):
    metal = ramp("3a3c42")
    c.paint(c.rect_m(9, 7, 23, 9), metal, grad=False)
    c.paint(c.rect_m(9, 10, 21, 11), metal, grad=False)
    c.paint(c.rect_m(13, 10, 19, 13), WOOD)
    for x in (14, 16, 18):
        c.set(x, 12, WOOD[1])
    c.paint(c.rect_m(5, 6, 11, 12), metal)
    c.fill(c.line_m(7, 13, 10, 13) | c.line_m(10, 12, 10, 14) | {(7, 14)}, metal[1])
    c.paint(c.poly_m([(0, 11), (6, 7), (6, 13), (2, 18), (0, 18)]), WOOD)
    c.line(9, 7, 22, 7, metal[4])
    c.set(22, 6, metal[2])


def _rounds(c, xs, casing, tip, tip_h, base):
    for x in xs:
        cyl(c, c.rect_m(x, 8, x + 3, 20), casing)
        if tip:
            cyl(c, c.rect_m(x, 8 - tip_h, x + 3, 7), tip)
            c.set(x, 8 - tip_h, CLEAR)
            c.set(x + 3, 8 - tip_h, CLEAR)
        cyl(c, c.rect_m(x, 19, x + 3, 21), base)


@art
def ammo_9mm(c):
    _rounds(c, (3, 10, 17), ramp("c8a040"), ramp("b06a3a"), 4, ramp("a08030"))


@art
def shotgun_shells(c):
    _rounds(c, (2, 9, 16), ramp("b02a20"), None, 0, ramp("c8a040"))
    for x in (2, 9, 16):
        cyl(c, c.rect_m(x, 15, x + 4, 21), ramp("c8a040"))
        cyl(c, c.rect_m(x, 4, x + 4, 14), ramp("b02a20"))
        c.fill(c.rect_m(x + 1, 4, x + 3, 4), ramp("b02a20")[0])


def _jerrycan(c, red, fuel):
    c.paint(c.poly_m([(4, 6), (15, 6), (19, 9), (19, 22), (4, 22)]), red)
    c.fill(c.line_m(6, 9, 16, 19) | c.line_m(16, 9, 6, 19), red[1])
    c.fill(c.line_m(6, 10, 16, 20) | c.line_m(16, 10, 6, 20), red[3])
    c.paint(c.rect_m(5, 2, 12, 5) - c.rect_m(7, 3, 10, 5), red)
    c.paint(c.line_m(15, 6, 19, 2, 2), ramp("e0c030") if fuel else ramp("808080"))
    c.fill(c.rect_m(17, 12, 18, 20), ramp("302010")[1])
    if fuel:
        c.fill(c.rect_m(17, 13, 18, 20), ramp("e0a030")[3])
        c.set(21, 4, ramp("e0a030")[3])


@art
def gas_can(c):
    _jerrycan(c, ramp("c82820"), True)


@art
def gas_can_empty(c):
    _jerrycan(c, ramp("8a4a40"), False)
    for x, y in ((8, 16), (12, 8), (14, 18)):
        c.set(x, y, ramp("5a3a30")[1])


@art
def car_key(c):
    c.paint(c.ellipse_m(7.5, 7.5, 5.5, 5) | c.rect_m(10, 8, 13, 12), RUBBER)
    c.fill(c.ellipse_m(5.5, 5.5, 1.3, 1.3), CLEAR)
    c.fill({(8, 9), (9, 9), (8, 10)}, ramp("c03030")[3])
    blade = c.line_m(13, 11, 21, 19, 3)
    teeth = {(15, 16), (16, 17), (18, 19), (19, 20), (17, 19)}
    c.paint(blade | teeth, STEEL)
    c.fill(c.line_m(14, 12, 20, 18), STEEL[4])
    c.paint(c.ellipse_m(3.5, 3.5, 3, 3) - c.ellipse_m(3.5, 3.5, 1.8, 1.8) - c.ellipse_m(7.5, 7.5, 5.5, 5), ramp("c8a040"), grad=False)


@art
def map(c):
    paper = ramp("e8dcb0")
    panels = ((3, 4, 8, 19, 0), (8, 3, 14, 18, 1), (14, 4, 20, 19, 0))
    for x0, y0, x1, y1, dark in panels:
        tones = paper if not dark else [mix(t, (0, 0, 0, 255), 0.12) for t in paper]
        c.paint(c.poly_m([(x0, y0), (x1, y0 + (1 if dark else 0) - (0 if x0 != 8 else 0)), (x1, y1), (x0, y1)]), tones)
    c.fill(c.line_m(4, 14, 19, 8), ramp("4a80c0")[2])
    c.fill(c.line_m(5, 7, 10, 10) | c.line_m(10, 10, 17, 14), ramp("909090")[2])
    c.fill(c.ellipse_m(6, 16, 2, 1.5), PAL["grass"][2])
    c.fill(c.line_m(15, 14, 18, 17) | c.line_m(18, 14, 15, 17), ramp("c02020")[2])


@art
def radio(c):
    case = ramp("4a4a44")
    c.paint(c.rect_m(3, 8, 20, 21), case)
    c.paint(c.line_m(16, 7, 21, 1, 1), STEEL, grad=False)
    c.paint(c.rect_m(5, 10, 11, 19), ramp("2a2a2a"))
    for y in range(11, 19, 2):
        c.line(6, y, 10, y, ramp("5a5a5a")[2])
    c.paint(c.rect_m(13, 10, 18, 13), ramp("e0c060"))
    c.line(15, 10, 15, 13, ramp("c03020")[2])
    c.paint(c.ellipse_m(15.5, 17, 2, 2), STEEL)
    c.fill(c.line_m(6, 8, 9, 6) | c.line_m(9, 6, 14, 6) | c.line_m(14, 6, 17, 8), case[1])


@art
def shovel(c):
    rod(c, 3, 21, 14, 10, WOOD)
    c.paint(c.rect_m(1, 18, 5, 19) | c.rect_m(1, 20, 2, 22) | c.rect_m(4, 20, 5, 22), RUBBER)
    c.paint(c.poly_m([(13, 9), (17, 3), (20, 1), (23, 3), (22, 7), (18, 12)]), STEEL)
    c.line(17, 4, 21, 2, STEEL[4])
    c.fill(c.line_m(14, 10, 16, 8), IRON[1])


def _seeds(c, veg):
    c.paint(c.rect_m(5, 2, 18, 21), PAL["paper"])
    c.fill(c.rect_m(5, 2, 18, 3), PAL["paper"][1])
    c.paint(c.rect_m(7, 5, 16, 15), ramp("8ab060"))
    if veg == "carrot":
        c.paint(c.poly_m([(9, 7), (13, 7), (11, 15)]), ramp("e07a20"))
        c.fill(c.line_m(10, 5, 11, 7) | c.line_m(12, 5, 11, 7), PAL["grass"][3])
    else:
        c.paint(c.ellipse_m(11.5, 11, 3.5, 3), ramp("b89a60"))
        c.fill({(10, 10), (13, 12)}, ramp("6a5030")[2])
    c.line(7, 18, 16, 18, ramp("707070")[2])
    for x, y in ((19, 19), (21, 21), (20, 22)):
        c.set(x, y, ramp("d8c890")[2])


@art
def seeds_carrot(c):
    _seeds(c, "carrot")


@art
def seeds_potato(c):
    _seeds(c, "potato")


@art
def potato(c):
    skin = ramp("b08a50")
    c.paint(c.ellipse_m(10, 12, 7, 6) | c.ellipse_m(14, 13, 7, 5.5), skin)
    for x, y in ((8, 10), (13, 14), (17, 11), (10, 15)):
        c.set(x, y, skin[0])
        c.set(x + 1, y, skin[1])
    c.fill({(7, 9), (8, 8)}, skin[4])


@art
def carrot(c):
    orange = ramp("e07020")
    c.paint(c.poly_m([(12, 7), (18, 7), (19, 11), (6, 21), (4, 21)]) | c.line_m(13, 8, 18, 8, 2), orange)
    for x, y in ((10, 13), (13, 11), (8, 17)):
        c.fill(c.line_m(x, y, x + 2, y + 1), orange[1])
    leaf = PAL["grass"]
    c.paint(c.line_m(16, 6, 18, 1) | c.line_m(17, 6, 21, 2) | c.line_m(18, 7, 22, 6), leaf, grad=False)


def _stale(c):
    tint = (128, 116, 64, 255)
    for i, p in enumerate(c.p):
        if p[3] > 200:
            h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in p[:3]))
            r, g, b = colorsys.hls_to_rgb(h, l * 0.9, s * 0.55)
            c.p[i] = mix((int(r * 255), int(g * 255), int(b * 255), p[3]), tint, 0.32)
    mold = ramp("b8c890")
    spots = [(x, y) for y in range(S) for x in range(S) if c.get(x, y)[3] > 200 and (x * 7 + y * 13) % 29 == 0]
    for x, y in spots[:7]:
        c.fill({(x, y), (x + 1, y), (x, y + 1)} & {p for p in c.rect_m(0, 0, S - 1, S - 1) if c.get(*p)[3] > 200}, mold[3])
        c.set(x + 1, y + 1, ramp("4a5020")[2]) if c.get(x + 1, y + 1)[3] > 200 else None


def stale_of(fn):
    def draw(c):
        fn(c)
        _stale(c)
    return draw


for _food in PERISHABLE:
    ART[_food + "_stale"] = stale_of(ART[_food])


if __name__ == "__main__":
    os.makedirs(ITEMS, exist_ok=True)
    for name, fn in ART.items():
        c = Canvas(S, seed=zlib.crc32(name.encode()) & 0xFFFF)
        fn(c)
        c.outline()
        c.save(os.path.join(ITEMS, name + ".png"))
    for food in PERISHABLE:
        with open(os.path.join(ROOT, "items", food + ".json"), encoding="utf-8") as f:
            props = json.load(f)
        props.pop("zomboid:stale")
        props.update({"icon": "items:%s_stale" % food, "description": "Несвежее. Может вызвать отравление",
                      "model-name": "zomboid:%s_stale.model" % food, "zomboid:fresh": "zomboid:" + food})
        with open(os.path.join(ROOT, "items", food + "_stale.json"), "w", encoding="utf-8") as f:
            json.dump(props, f, ensure_ascii=False, indent=4)
            f.write("\n")
