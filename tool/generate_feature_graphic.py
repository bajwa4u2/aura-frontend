"""Compose the Play feature graphic: the canonical mark, the wordmark, the line.

WHY THIS IS NOT IN generate_store_assets.dart
---------------------------------------------
The Dart generator owns every icon and draws the mark from the master's own
geometry, which needs no font. The feature graphic is the one asset that must
set TYPE, and the `image` package has no TrueType rasteriser. So the poster is
composed here, and here ONLY -- the Dart generator no longer writes it, because
two generators writing one file is the same ambiguity that let Orchestrate's
mark drift.

NOTHING HERE INVENTS IDENTITY
-----------------------------
  * the mark comes from assets/store/android/adaptive_foreground.png, which the
    Dart generator wrote from the master;
  * the wordmark comes from the master's own OUTLINES -- it used to be set in
    Times New Roman from the system font directory, which silently renders in a
    fallback face on any machine without it, and is not reproducible off
    Windows at all.

Only the tagline still needs an installed face. That is marketing copy rather
than identity, so a fallback chain is acceptable -- but it fails loudly rather
than silently substituting something else.
"""
from __future__ import annotations

import pathlib
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
MASTER = ROOT / 'assets/brand/AURA_logo_master.svg'
MARK = ROOT / 'assets/store/android/adaptive_foreground.png'
OUT = ROOT / 'assets/store/android/feature_graphic_1024x500.png'

WIDTH, HEIGHT = 1024, 500
TAGLINE = 'A space for thoughtful writing and responsible discourse'

SERIF_CANDIDATES = [
    'C:/Windows/Fonts/times.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf',
    '/System/Library/Fonts/Supplemental/Times New Roman.ttf',
]

MARK_HEIGHT = 178
WORDMARK_HEIGHT = 96
GAP = 46
LEAD = 20
TAG_SIZE = 26


def hex_rgb(value: str) -> tuple[int, int, int]:
    h = value.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def read_master() -> tuple[str, dict]:
    svg = MASTER.read_text(encoding='utf-8')
    group = re.search(r'<g id="wordmark"[^>]*>(.*?)</g>', svg, re.S)
    if not group:
        raise SystemExit('master has no <g id="wordmark"> -- has it been outlined?')
    tokens = {
        'navy': hex_rgb(re.search(r'data-surface-dark="([^"]+)"', svg).group(1)),
        'wordmark': hex_rgb(
            re.search(r'<g id="wordmark"[^>]*fill="([^"]+)"', svg).group(1)),
    }
    return group.group(1), tokens


def wordmark_polygons(body: str) -> list[list[tuple[float, float]]]:
    """The outlined glyphs, as polygons in master coordinates."""
    polys = []
    for d in re.findall(r'<path d="([^"]+)"', body):
        pts = [tuple(float(v) for v in m.split())
               for m in re.findall(r'[ML]([-\d.]+ [-\d.]+)', d)]
        if len(pts) >= 3:
            polys.append(pts)
    if not polys:
        raise SystemExit('wordmark group contains no paths')
    return polys


def render_wordmark(polys, height: int, colour) -> Image.Image:
    """Fill the outlines, honouring counters, at 4x then downsample."""
    ss = 4
    xs = [x for p in polys for x, _ in p]
    ys = [y for p in polys for _, y in p]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    scale = (height * ss) / (y1 - y0)
    w = round((x1 - x0) * scale)
    h = round((y1 - y0) * scale)

    mask = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(mask)
    # Largest first, then alternate: an odd containment depth is a counter.
    def area(p):
        return abs(sum(p[i][0] * p[(i + 1) % len(p)][1]
                       - p[(i + 1) % len(p)][0] * p[i][1]
                       for i in range(len(p)))) / 2

    def contains(outer, pt):
        inside = False
        n = len(outer)
        for i in range(n):
            ax, ay = outer[i]
            bx, by = outer[(i + 1) % n]
            if (ay > pt[1]) != (by > pt[1]) and \
                    pt[0] < (bx - ax) * (pt[1] - ay) / (by - ay) + ax:
                inside = not inside
        return inside

    ordered = sorted(polys, key=area, reverse=True)
    for poly in ordered:
        depth = sum(1 for other in ordered
                    if other is not poly and area(other) > area(poly)
                    and contains(other, poly[0]))
        d.polygon([((x - x0) * scale, (y - y0) * scale) for x, y in poly],
                  fill=255 if depth % 2 == 0 else 0)

    mask = mask.resize((w // ss, h // ss), Image.LANCZOS)
    glyphs = Image.new('RGBA', mask.size, colour + (0,))
    glyphs.putalpha(mask)
    return glyphs


def mark_image(target_height: int) -> Image.Image:
    src = Image.open(MARK).convert('RGBA')
    box = src.split()[-1].getbbox()
    if box is None:
        raise SystemExit(f'{MARK} carries no mark')
    mark = src.crop(box)
    scale = target_height / mark.height
    return mark.resize((round(mark.width * scale), target_height), Image.LANCZOS)


def serif(size: int) -> ImageFont.FreeTypeFont:
    for path in SERIF_CANDIDATES:
        if pathlib.Path(path).exists():
            return ImageFont.truetype(path, size)
    raise SystemExit(
        'no serif face found for the tagline; add one to SERIF_CANDIDATES '
        'rather than letting the poster fall back to a different face')


def main() -> None:
    body, tokens = read_master()
    polys = wordmark_polygons(body)

    canvas = Image.new('RGB', (WIDTH, HEIGHT), tokens['navy'])
    draw = ImageDraw.Draw(canvas)

    mark = mark_image(MARK_HEIGHT)
    word = render_wordmark(polys, WORDMARK_HEIGHT, tokens['wordmark'])
    tag_font = serif(TAG_SIZE)

    g_box = draw.textbbox((0, 0), TAGLINE, font=tag_font)
    g_w, g_h = g_box[2] - g_box[0], g_box[3] - g_box[1]

    text_w = max(word.width, g_w)
    text_h = word.height + LEAD + g_h
    lockup_w = mark.width + GAP + text_w
    left = (WIDTH - lockup_w) // 2

    canvas.paste(mark, (left, (HEIGHT - mark.height) // 2), mark)

    text_left = left + mark.width + GAP
    text_top = (HEIGHT - text_h) // 2
    canvas.paste(word, (text_left, text_top), word)
    draw.text((text_left - g_box[0], text_top + word.height + LEAD - g_box[1]),
              TAGLINE, font=tag_font, fill=(150, 150, 168))

    canvas.save(OUT)
    print(f'wrote {OUT.relative_to(ROOT)}  {canvas.size}')


if __name__ == '__main__':
    main()
