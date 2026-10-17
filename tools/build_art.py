#!/usr/bin/env python3
"""Turn the angelfish line drawings into what the QML character needs.

Input (art/src): black ink drawings with white fills on a flat green background.
  sideview_plain.png   the fish
  halowing.png         halo and sparkles (its wings are not used), on the same canvas as the fish
  onewing.png          a single wing, on the same canvas; drawn twice, behind and in front of the fish

Output (common/):
  images/*.png         ink layers: black, with alpha where the ink is; and ready-coloured pieces
  AngelfishArt.js      fill regions as polygons (flat x,y lists), with a role each, plus pivots and sizes

Every enclosed white area of the fish becomes a fill region that the QML colours on its own.
The ink goes on top, so region edges only need to end up somewhere under an outline.

Needs: pillow, numpy, scipy, contourpy.   Run: make art
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from scipy.spatial import ConvexHull
import contourpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'art', 'src')
OUT = os.path.join(ROOT, 'common')
DEBUG = os.path.join(ROOT, 'build', 'art-debug')
SCALE = 0.5          # output size relative to the source drawings
MARGIN = 24          # source pixels kept around the character
MIN_REGION = 60      # smaller white specks are left to the base fill

# Regions that can't be told apart by rule are picked by the nearest centroid (source pixels).
SEEDS = {
    'dorsal':   [(1531, 466)],
    'tail':     [(1790, 871)],
    'anal':     [(1544, 1197)],
    'ventral':  [(1245, 1164), (1200, 1176)],
    'pectoral': [(1487, 1000)],
    'sleeve':   [(1392, 910), (1409, 928)],
}
WING_ROOT = (1610, 676)  # source pixels: the base of the wings, where they flap from
TAIL_CUT_PAD = 6     # source pixels of tail kept left of the cuff edge, hidden behind the body


def load(name):
    """Background may be flat green or real transparency; either becomes 'green' here."""
    src = Image.open(os.path.join(SRC, name)).convert('RGBA')
    im = np.asarray(src).astype(np.int32)
    clear = im[..., 3] < 128
    im[clear, :3] = (0, 254, 33)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    green = (g > 150) & (g - np.maximum(r, b) > 60)
    # the background is connected green; green-tinted edge pixels count as ink
    ink_alpha = np.clip(255 - g, 0, 255).astype(np.uint8)   # green channel: 0 in ink, ~255 in white AND background
    white = (~green) & ((r + g + b) > 3 * 150) & (np.abs(g - (r + b) // 2) < 40)
    return green, white, ink_alpha


def simplify(pts, eps):
    """Douglas-Peucker on a closed ring."""
    pts = np.asarray(pts, dtype=float)
    if len(pts) < 8:
        return pts
    keep = np.zeros(len(pts), bool)
    far = int(np.argmax(((pts - pts[0]) ** 2).sum(1)))
    keep[0] = keep[far] = True
    stack = [(0, far), (far, len(pts) - 1)]
    while stack:
        a, b = stack.pop()
        if b <= a + 1:
            continue
        seg = pts[b] - pts[a]
        n = np.hypot(*seg)
        rel = pts[a + 1:b] - pts[a]
        d = np.abs(rel[:, 0] * seg[1] - rel[:, 1] * seg[0]) / n if n > 0 else np.hypot(rel[:, 0], rel[:, 1])
        i = int(np.argmax(d))
        if d[i] > eps:
            m = a + 1 + i
            keep[m] = True
            stack += [(a, m), (m, b)]
    keep[-1] = True
    return pts[keep]


def outline(mask, grow=0, eps=1.2):
    """Outer boundary of a mask as a simplified polygon (source pixels)."""
    if grow > 0:
        mask = ndi.binary_dilation(mask, iterations=grow)
    elif grow < 0:
        mask = ndi.binary_erosion(mask, iterations=-grow)
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return None
    x0, y0, x1, y1 = xs.min() - 2, ys.min() - 2, xs.max() + 3, ys.max() + 3
    x0, y0 = max(x0, 0), max(y0, 0)
    sub = np.pad(mask[y0:y1, x0:x1].astype(float), 1)
    lines = contourpy.contour_generator(z=sub).lines(0.5)
    best = max(lines, key=len)
    return simplify(best, eps) + (x0 - 1, y0 - 1)


def flat(poly, ox, oy):
    p = (np.asarray(poly) - (ox, oy)) * SCALE
    return [round(float(v), 1) for v in p.reshape(-1)]


def svg(poly, ox, oy):
    p = (np.asarray(poly) - (ox, oy)) * SCALE
    return 'M' + ' L'.join('%.1f %.1f' % (x, y) for x, y in p) + ' Z'


def save_ink(alpha, box, name):
    x0, y0, x1, y1 = box
    a = Image.fromarray(alpha[y0:y1, x0:x1])
    a = a.resize((round((x1 - x0) * SCALE), round((y1 - y0) * SCALE)), Image.LANCZOS)
    out = Image.new('RGBA', a.size, (0, 0, 0, 0))
    out.putalpha(a)
    out.save(os.path.join(OUT, 'images', name), optimize=True)


def save_coloured(alpha, fill_mask, rgb, box, name):
    """A finished piece: one flat fill colour under its ink."""
    x0, y0, x1, y1 = box
    size = (round((x1 - x0) * SCALE), round((y1 - y0) * SCALE))
    ink = np.asarray(Image.fromarray(alpha[y0:y1, x0:x1]).resize(size, Image.LANCZOS)).astype(float) / 255
    fill = np.asarray(Image.fromarray((fill_mask[y0:y1, x0:x1] * 255).astype(np.uint8)).resize(size, Image.LANCZOS)).astype(float) / 255
    a = np.maximum(ink, fill)
    out = np.zeros(size[::-1] + (4,), np.uint8)
    for c in range(3):
        out[..., c] = np.where(a > 0, rgb[c] * (1 - ink), 0)
    out[..., 3] = a * 255
    Image.fromarray(out).save(os.path.join(OUT, 'images', name), optimize=True)


def main():
    os.makedirs(os.path.join(OUT, 'images'), exist_ok=True)
    os.makedirs(DEBUG, exist_ok=True)

    green, white, ink = load('sideview_plain.png')
    hgreen, hwhite, hink = load('halowing.png')
    H, W = green.shape

    # ---- canvas: one box around fish + halo + wings, shared by every piece ----
    ys, xs = np.nonzero(~green | ~hgreen | ~load('onewing.png')[0])
    bx0, by0 = max(xs.min() - MARGIN, 0), max(ys.min() - MARGIN, 0)
    bx1, by1 = min(xs.max() + MARGIN, W), min(ys.max() + MARGIN, H)
    box = (bx0, by0, bx1, by1)

    # ---- fish regions ----
    lab, n = ndi.label(white)
    idx = np.arange(1, n + 1)
    area = ndi.sum(white, lab, idx)
    com = np.array(ndi.center_of_mass(white, lab, idx))[:, ::-1]      # x, y
    big = [i for i in idx if area[i - 1] >= MIN_REGION]
    role = {}

    head = int(idx[np.argmax(area)])
    role[head] = 'body'
    hs = ndi.find_objects((lab == head).astype(int))[0]
    for name, seeds in SEEDS.items():
        for sx, sy in seeds:
            i = min(big, key=lambda k: (com[k - 1][0] - sx) ** 2 + (com[k - 1][1] - sy) ** 2)
            role[i] = name
    objs = ndi.find_objects(lab)
    eye = []
    for i in big:
        if i in role:
            continue
        s = objs[i - 1]
        inside = s[0].start > hs[0].start and s[0].stop < hs[0].stop and s[1].start > hs[1].start and s[1].stop < hs[1].stop
        if inside and area[i - 1] > 3000:
            role[i] = 'eye'
            eye.append(i)

    # sweater bands: what's left, ordered by how far they sit from the head
    dist_from_head = ndi.distance_transform_edt(lab != head)
    cand = [i for i in big if i not in role]
    depth = {i: float(np.median(dist_from_head[lab == i])) for i in cand}
    ribs = [i for i in cand if area[i - 1] < 1200]
    bands = sorted((i for i in cand if area[i - 1] >= 1200), key=lambda i: depth[i])
    for i in ribs:
        role[i] = 'rib'
    ring, rings, last = -1, {}, -1e9
    for i in bands:
        if depth[i] - last > BAND_GAP:
            ring += 1
        rings[i] = ring
        last = depth[i]
        role[i] = 'band'
    nrings = ring + 1

    # ---- the tail is its own piece, hinged at the cuff ----
    tail = next(i for i in role if role[i] == 'tail')
    ts = objs[tail - 1]
    cut = ts[1].start - TAIL_CUT_PAD
    tail_zone = np.zeros_like(green)
    tail_zone[max(ts[0].start - 30, 0):ts[0].stop + 30, cut:] = True
    comp, _ = ndi.label(~green & tail_zone)
    tail_piece = comp == comp[int(com[tail - 1][1]), int(com[tail - 1][0])]
    tys, txs = np.nonzero(tail_piece & (np.arange(W)[None, :] < ts[1].start + 4))
    tail_pivot = (float(ts[1].start), float(tys.mean()))
    body_ink = np.where(tail_piece & (np.arange(W)[None, :] >= ts[1].start), 0, ink).astype(np.uint8)
    body_ink[green] = 0
    tail_ink = np.where(tail_piece, ink, 0).astype(np.uint8)

    # ---- the eye is drawn by the QML, so clear its inside from the ink ----
    eye_mask = np.isin(lab, eye)
    eys, exs = np.nonzero(eye_mask)
    pts = np.stack([exs, eys], 1)
    hull = pts[ConvexHull(pts).vertices]
    him = Image.new('L', (W, H), 0)
    ImageDraw.Draw(him).polygon([tuple(map(float, p)) for p in hull], fill=255)
    eye_in = np.asarray(him) > 0
    body_ink[eye_in] = 0
    eye_box = [exs.min(), eys.min(), exs.max() + 1, eys.max() + 1]

    save_ink(body_ink, box, 'fish-ink.png')
    save_ink(tail_ink, box, 'tail-ink.png')

    # ---- regions as polygons ----
    # the base fill sits under everything, so it stops inside the outline: soft edge pixels
    # around the drawing are not part of it
    solid = ndi.binary_fill_holes((ink > 128) & ~green | white)
    silhouette = solid & ~tail_piece
    regions = [{'role': 'base', 'p': flat(outline(silhouette, grow=-3), bx0, by0)}]
    tail_regions = [{'role': 'base', 'p': flat(outline(ndi.binary_fill_holes(tail_piece & solid), grow=-3), bx0, by0)}]
    for i in sorted(role, key=lambda k: (role[k] != 'body', k)):
        if role[i] == 'eye':
            continue
        entry = {'role': role[i], 'p': flat(outline(lab == i, grow=3), bx0, by0)}
        if role[i] == 'band':
            entry['ring'] = rings[i]
        (tail_regions if role[i] == 'tail' else regions).append(entry)

    # ---- halo, wings, sparkles: finished pieces ----
    comp, nc = ndi.label(~hgreen)
    sizes = ndi.sum(~hgreen, comp, np.arange(1, nc + 1))
    order = np.argsort(-sizes) + 1
    wing, halo = comp == order[0], comp == order[1]
    sparkle = (~hgreen) & ~wing & ~halo
    hink_clean = np.where(hgreen, 0, hink).astype(np.uint8)
    wgreen, wwhite, wink = load('onewing.png')
    comp, nc = ndi.label(~wgreen)
    sizes = ndi.sum(~wgreen, comp, np.arange(1, nc + 1))
    one_wing = comp == (np.argmax(sizes) + 1)          # drops stray specks
    wink_clean = np.where(one_wing, wink, 0).astype(np.uint8)
    pieces = {}
    # The same wing twice: a shaded one behind the fish and a white one in front.
    for name, ink_src, mask, fill, rgb in (
            ('wing-back', wink_clean, one_wing, one_wing & wwhite, (214, 220, 230)),
            ('wing-front', wink_clean, one_wing, one_wing & wwhite, (255, 255, 255)),
            ('halo', hink_clean, halo, halo & hwhite, (255, 226, 110)),
            ('sparkles', hink_clean, sparkle, sparkle & hwhite, (255, 240, 170))):
        ys, xs = np.nonzero(mask)
        pb = (max(xs.min() - 6, 0), max(ys.min() - 6, 0), min(xs.max() + 7, W), min(ys.max() + 7, H))
        save_coloured(np.where(mask, ink_src, 0).astype(np.uint8), fill, rgb, pb, name + '.png')
        pieces[name.replace('-', '_')] = {'x': (pb[0] - bx0) * SCALE, 'y': (pb[1] - by0) * SCALE,
                        'w': round((pb[2] - pb[0]) * SCALE), 'h': round((pb[3] - pb[1]) * SCALE)}
    # The wings sit behind the fish (the dorsal fin overlaps them in the drawing) and flap from
    # their base, where the feathers meet. Set by hand: move it if the wing drawing changes.
    wing_root = WING_ROOT

    def pt(p):
        return {'x': round((p[0] - bx0) * SCALE, 1), 'y': round((p[1] - by0) * SCALE, 1)}

    # ---- the mouth: the tip of the nose, where food goes in and bubbles come out ----
    mys, mxs = np.nonzero(body_ink > 128)
    tip = mxs.min()
    mouth = (float(tip), float(mys[mxs <= tip + 3].mean()))

    art = {
        'width': round((bx1 - bx0) * SCALE), 'height': round((by1 - by0) * SCALE),
        'bandRings': nrings,
        'regions': regions,
        'tailRegions': tail_regions,
        'tailPivot': pt(tail_pivot),
        'eye': {'x': (eye_box[0] - bx0) * SCALE, 'y': (eye_box[1] - by0) * SCALE,
                'w': (eye_box[2] - eye_box[0]) * SCALE, 'h': (eye_box[3] - eye_box[1]) * SCALE,
                'd': svg(outline(eye_in, grow=2), bx0, by0)},
        'pieces': pieces,
        'wingRoot': pt(wing_root),
        'mouth': pt(mouth),
    }
    with open(os.path.join(OUT, 'AngelfishArt.js'), 'w') as f:
        f.write('// Generated by tools/build_art.py. Do not edit; run `make art`.\n.pragma library\n\nvar art = ')
        json.dump(art, f, separators=(',', ':'))
        f.write(';\n')

    # ---- debug picture: roles and band rings ----
    colours = {'body': (190, 235, 170), 'rib': (200, 200, 200), 'dorsal': (200, 120, 200), 'tail': (245, 195, 70),
               'anal': (70, 125, 110), 'ventral': (240, 110, 160), 'pectoral': (120, 180, 100), 'sleeve': (170, 70, 150),
               'eye': (255, 255, 255)}
    dbg = np.full((H, W, 3), 40, np.uint8)
    dbg[~green] = (255, 255, 255)
    for i, r in role.items():
        if r == 'band':
            t = rings[i] / max(nrings - 1, 1)
            dbg[lab == i] = (int(255 * t), 80, int(255 * (1 - t)))
        else:
            dbg[lab == i] = colours[r]
    dbg[ink > 128] = (0, 0, 0)
    dbg[tail_piece & (ink <= 128) & ~white] = (255, 0, 255)
    img = Image.fromarray(dbg).crop(box)
    d = ImageDraw.Draw(img)
    for i, r in role.items():
        if r == 'band':
            d.text((com[i - 1][0] - bx0 - 6, com[i - 1][1] - by0 - 6), str(rings[i]), fill=(255, 255, 255))
    d.ellipse([tail_pivot[0] - bx0 - 6, tail_pivot[1] - by0 - 6, tail_pivot[0] - bx0 + 6, tail_pivot[1] - by0 + 6], fill=(0, 255, 255))
    wr = (wing_root[0] - bx0, wing_root[1] - by0)
    d.ellipse([wr[0] - 7, wr[1] - 7, wr[0] + 7, wr[1] + 7], outline=(255, 0, 0), width=3)
    img.save(os.path.join(DEBUG, 'roles.png'))
    wimg = Image.fromarray(np.where(one_wing[..., None], (255, 255, 255), (40, 40, 40)).astype(np.uint8)).crop(box)
    wimg.paste((0, 0, 0), mask=Image.fromarray(((wink > 128) & one_wing).astype(np.uint8) * 255).crop(box))
    ImageDraw.Draw(wimg).ellipse([wr[0] - 7, wr[1] - 7, wr[0] + 7, wr[1] + 7], outline=(255, 0, 0), width=3)
    wimg.save(os.path.join(DEBUG, 'wing-root.png'))
    print('canvas %dx%d  regions %d  tail regions %d  band rings %d  ribs %d' % (
        art['width'], art['height'], len(regions), len(tail_regions), nrings, len(ribs)))
    print('band depths:', ' '.join('%d:%.0f' % (rings[i], depth[i]) for i in bands))
    print('AngelfishArt.js %.0f kB' % (os.path.getsize(os.path.join(OUT, 'AngelfishArt.js')) / 1024))


BAND_GAP = 12        # source pixels: bands whose distance from the head differs by less are one ring

if __name__ == '__main__':
    main()
