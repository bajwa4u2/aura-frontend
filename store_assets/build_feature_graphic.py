"""Replace the feature graphic's tagline with the canon line.

The mark, the AURA wordmark and the gold rule are the founder-approved design
and are preserved pixel-for-pixel from the existing asset. Only the tagline
band is repainted, because the live Play graphic reads "A space for thoughtful
writing and responsible discourse" — writing is Bajwa Writes' domain under
PRODUCT_IDENTITY_CANON.md, not Aura's.
"""
from PIL import Image, ImageDraw, ImageFont

SRC = "store_assets/play_feature_graphic_1024x500.png"
DST = "store_assets/android/play_feature_graphic_1024x500.png"

TAGLINE = "Public-first civic discourse"

BG = (26, 26, 46)
INK = (168, 178, 196)          # matches the existing tagline grey
BAND = (300, 320, 1024, 385)   # y-range that holds the old tagline

im = Image.open(SRC).convert("RGB")
assert im.size == (1024, 500), im.size

d = ImageDraw.Draw(im)
# Repaint only the tagline band. The rule sits at y=292 and is untouched.
d.rectangle((BAND[0] - 300, BAND[1], BAND[2], BAND[3]), fill=BG)

font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 34)

# Centre the tagline under the wordmark, which is centred on the gold rule.
rule_x0, rule_x1 = None, None
px = im.load()
for x in range(420, 1024):  # skip the gold sun ring on the left
    p = px[x, 292]
    if p[0] > 120 and p[2] < 120:
        rule_x0 = x if rule_x0 is None else rule_x0
        rule_x1 = x
cx = (rule_x0 + rule_x1) // 2

w = d.textlength(TAGLINE, font=font)
d.text((cx - w / 2, 330), TAGLINE, font=font, fill=INK)

im.save(DST, "PNG", optimize=True)

import os
print(f"wrote {DST}")
print(f"size {Image.open(DST).size}  {os.path.getsize(DST)/1024:.0f} KB")
print(f"rule spans x={rule_x0}..{rule_x1}, centre {cx}; tagline width {w:.0f}")
