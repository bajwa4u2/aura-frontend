"""Fit real device captures into Google Play's accepted aspect ratios.

The Pixel 9a is 1080x2424, which is 9:20.2. Play accepts only 16:9 or 9:16, so
a raw device screenshot is rejected. Nothing is cropped and nothing is
stretched: each capture is scaled to fit and centred on a canvas painted with
the app's own background colour, sampled from the capture itself.

Phone   -> 1080x1920 (9:16)
Tablet  -> 1920x1080 (16:9), from landscape captures, which show the side-rail
           layout rather than a stretched phone UI.
"""
import os
from PIL import Image

RAW = "store_assets/android/screenshots/raw"
OUT = "store_assets/android/screenshots"

PHONE = (1080, 1920)
TABLET = (1920, 1080)

PHONE_SET = [
    ("01_home.png", "1_home"),
    ("04_discover_institutions.png", "2_institutions"),
    ("10_search.png", "3_verified_institution"),
    ("05_conversation.png", "4_messages"),
    ("02_discover.png", "5_discover"),
]

TABLET_SET = [
    ("L2_home.png", "1_institutions"),
    ("L1_institution.png", "2_institution"),
    ("L3_alt.png", "3_surface"),
]


RING = 4  # px. `adb shell input text` leaves a 3px keyboard-focus ring on the
          # screen edge. It is a capture artifact, not part of the product, so
          # it is trimmed from every capture uniformly.


def bg_of(im):
    """The app's own background = the most common colour in the capture."""
    small = im.convert("RGB").resize((160, 360), Image.Resampling.NEAREST)
    return max(small.getcolors(160 * 360), key=lambda c: c[0])[1]


def fit(src_path, size, dst_path):
    im = Image.open(src_path).convert("RGB")
    im = im.crop((RING, RING, im.width - RING, im.height - RING))
    tw, th = size
    scale = min(tw / im.width, th / im.height)
    nw, nh = int(round(im.width * scale)), int(round(im.height * scale))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", size, bg_of(im))
    canvas.paste(resized, ((tw - nw) // 2, (th - nh) // 2))
    canvas.save(dst_path, "PNG", optimize=True)
    return im.size, (nw, nh), os.path.getsize(dst_path)


def run(pairs, size, subdir):
    out_dir = os.path.join(OUT, subdir)
    os.makedirs(out_dir, exist_ok=True)
    print(f"\n{subdir}  target {size[0]}x{size[1]}")
    for src, name in pairs:
        sp = os.path.join(RAW, src)
        if not os.path.exists(sp):
            print(f"  MISSING {src}")
            continue
        dp = os.path.join(out_dir, f"{name}.png")
        orig, placed, nbytes = fit(sp, size, dp)
        print(f"  {name:24s} {orig[0]}x{orig[1]} -> placed {placed[0]}x{placed[1]}"
              f"  {nbytes/1024:.0f} KB")


run(PHONE_SET, PHONE, "phone")
run(TABLET_SET, TABLET, "tablet")

print("\nPlay constraints check")
for sub, (w, h) in (("phone", PHONE), ("tablet", TABLET)):
    d = os.path.join(OUT, sub)
    for f in sorted(os.listdir(d)):
        if not f.endswith(".png"):
            continue
        im = Image.open(os.path.join(d, f))
        ar = im.width / im.height
        ok_ar = abs(ar - 16 / 9) < 0.01 or abs(ar - 9 / 16) < 0.01
        ok_side = 320 <= min(im.size) and max(im.size) <= 3840
        ok_size = os.path.getsize(os.path.join(d, f)) < 8 * 1024 * 1024
        print(f"  {sub}/{f:26s} {im.width}x{im.height} ar={ar:.4f} "
              f"{'OK' if (ok_ar and ok_side and ok_size) else 'FAIL'}")
