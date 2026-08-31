"""Compose the Play feature graphic: the canonical mark, the wordmark, the line.

WHY THIS IS NOT IN generate_store_assets.dart
---------------------------------------------
The Dart generator owns every icon, and it draws the mark geometrically -- ring,
ticks, ground -- which needs no font. The feature graphic is the one asset that
must set TYPE, and the `image` package has no TrueType rasteriser. Rather than
approximate the wordmark with a bitmap font, the poster is composed here, where
the real face the master specifies (Times New Roman) can actually be used.

The identity still comes from one place: the mark is read from the generated
`assets/store/android/adaptive_foreground.png`, which the Dart generator wrote
from `assets/brand/AURA_logo_master.svg`. This file composes; it never redraws
the mark. That is the whole lesson of the Orchestrate drift -- a generator that
invents identity is the bug.

The poster this replaces carried the legacy crescent AND the wordmark. Dropping
to a bare ring would have fixed the identity and lost the product name, so the
lockup is rebuilt rather than removed.
"""
from __future__ import annotations

import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
MARK = ROOT / 'assets/store/android/adaptive_foreground.png'
OUT = ROOT / 'assets/store/android/feature_graphic_1024x500.png'

WIDTH, HEIGHT = 1024, 500
NAVY = (26, 26, 46)
INK_LIGHT = (216, 216, 216)
MUTED = (150, 150, 168)

WORDMARK = 'Aura'
TAGLINE = 'A space for thoughtful writing and responsible discourse'

SERIF = 'C:/Windows/Fonts/times.ttf'


def mark_image(target_height: int) -> Image.Image:
    """The canonical mark, cropped to its own ink and scaled."""
    src = Image.open(MARK).convert('RGBA')
    bbox = src.split()[-1].getbbox()
    if bbox is None:
        raise SystemExit(f'{MARK} carries no mark')
    mark = src.crop(bbox)
    scale = target_height / mark.height
    return mark.resize(
        (round(mark.width * scale), target_height), Image.LANCZOS)


def main() -> None:
    canvas = Image.new('RGB', (WIDTH, HEIGHT), NAVY)
    draw = ImageDraw.Draw(canvas)

    mark = mark_image(178)
    title_font = ImageFont.truetype(SERIF, 94)
    tag_font = ImageFont.truetype(SERIF, 26)

    # Measure everything before placing anything, so the lockup is centred as
    # one object rather than positioned by eye.
    t_box = draw.textbbox((0, 0), WORDMARK, font=title_font)
    g_box = draw.textbbox((0, 0), TAGLINE, font=tag_font)
    t_w, t_h = t_box[2] - t_box[0], t_box[3] - t_box[1]
    g_w, g_h = g_box[2] - g_box[0], g_box[3] - g_box[1]

    gap = 46          # between mark and text
    lead = 20         # between wordmark and tagline
    text_w = max(t_w, g_w)
    text_h = t_h + lead + g_h

    lockup_w = mark.width + gap + text_w
    left = (WIDTH - lockup_w) // 2

    canvas.paste(mark, (left, (HEIGHT - mark.height) // 2), mark)

    text_left = left + mark.width + gap
    text_top = (HEIGHT - text_h) // 2
    draw.text((text_left - t_box[0], text_top - t_box[1]),
              WORDMARK, font=title_font, fill=INK_LIGHT)
    draw.text((text_left - g_box[0], text_top + t_h + lead - g_box[1]),
              TAGLINE, font=tag_font, fill=MUTED)

    canvas.save(OUT)
    print(f'wrote {OUT.relative_to(ROOT)}  {canvas.size}')


if __name__ == '__main__':
    main()
