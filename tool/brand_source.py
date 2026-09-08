"""
Cut the shipped mascot artwork out of the source render.

`assets/branding/source/mascot_render.jpg` is a flat JPEG: the mascot and the
"Pomo Sauce" wordmark sitting on white, with no alpha. Everything in
`assets/branding/` is composited from the two pieces this module returns.

Run directly to dump the cut pieces for inspection:  python tool/brand_source.py
"""

import os
from collections import deque

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "branding", "source", "mascot_render.jpg")

# The render is 709x709: mascot on rows 27-601, wordmark on rows 611-670.
# These bounds only need to fall in the blank band between the two.
MASCOT_ROWS = (0, 606)
WORDMARK_BOX = (70, 606, 640, 678)

# "Background" for the flood fill: bright and near-neutral. Saturation is what
# protects the artwork - the body sits at ~150+ and the leaf at ~100, so the
# fill stops dead at the silhouette however bright the pixel is.
_BG_LUMA = 165
_BG_SAT = 60

# The warm contact shadow under the mascot bottoms out around luma 155 and
# saturation 63, just inside the strict test, so it survives as a grey sliver.
# A second pass sweeps it up, restricted to the rows it actually occupies so
# the looser thresholds can never reach the leaf.
_SHADOW_LUMA = 135
_SHADOW_SAT = 70
_SHADOW_FROM_ROW = 490


def _is_bg(px, x, y):
    r, g, b = px[x, y]
    return (r + g + b) / 3 > _BG_LUMA and (max(r, g, b) - min(r, g, b)) < _BG_SAT


def _is_shadow(px, x, y):
    if y < _SHADOW_FROM_ROW:
        return False
    r, g, b = px[x, y]
    return (r + g + b) / 3 > _SHADOW_LUMA and (max(r, g, b) - min(r, g, b)) < _SHADOW_SAT


def cut_mascot(im):
    """Alpha-cut the mascot by flooding the white in from the image border.

    A global white key would punch holes in the eye whites and the specular
    highlight on the body. Flooding from outside instead means anything
    enclosed by the silhouette stays opaque, whatever colour it is.
    """
    W, H = im.size
    y0, y1 = MASCOT_ROWS
    px = im.load()
    seen = bytearray(W * H)
    q = deque()

    def flood(test):
        while q:
            x, y = q.popleft()
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < W and y0 <= ny < y1 and not seen[ny * W + nx]                         and test(px, nx, ny):
                    seen[ny * W + nx] = 1
                    q.append((nx, ny))

    for x in range(W):
        for y in (y0, y1 - 1):
            if not seen[y * W + x] and _is_bg(px, x, y):
                seen[y * W + x] = 1
                q.append((x, y))
    for y in range(y0, y1):
        for x in (0, W - 1):
            if not seen[y * W + x] and _is_bg(px, x, y):
                seen[y * W + x] = 1
                q.append((x, y))
    flood(_is_bg)

    # Second pass: re-seed from the background already found in the shadow rows
    # and creep forward under the looser test.
    for y in range(max(y0, _SHADOW_FROM_ROW), y1):
        for x in range(W):
            if seen[y * W + x]:
                q.append((x, y))
    flood(_is_shadow)

    alpha = Image.new("L", (W, H), 0)
    ap = alpha.load()
    for y in range(y0, y1):
        for x in range(W):
            if not seen[y * W + x]:
                ap[x, y] = 255
    # Erode a pixel to drop the ring of white-blended edge pixels (which would
    # otherwise halo on the dark splash), then feather what is left.
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))

    out = im.convert("RGBA")
    out.putalpha(alpha)
    return out.crop(out.getbbox())


def cut_wordmark(im):
    """The wordmark is black on white, so alpha is just inverted luminance.

    Doing it this way keeps the counters of 'o', 'a' and 'e' open, which a
    flood fill from the border could not reach.
    """
    band = im.crop(WORDMARK_BOX).convert("L")
    out = Image.new("RGBA", band.size, (0, 0, 0, 255))
    out.putalpha(band.point(lambda v: 255 - v))
    return out.crop(out.getbbox())


def load():
    """Return (mascot, wordmark) as cropped RGBA images at source resolution."""
    if not os.path.exists(SOURCE):
        raise SystemExit("missing source art: %s" % SOURCE)
    im = Image.open(SOURCE).convert("RGB")
    return cut_mascot(im), cut_wordmark(im)


def fit_width(img, width):
    """Scale to `width`, keeping aspect."""
    return img.resize((width, max(1, round(width * img.height / img.width))), Image.LANCZOS)


def fit_height(img, height):
    """Scale to `height`, keeping aspect."""
    return img.resize((max(1, round(height * img.width / img.height)), height), Image.LANCZOS)


def tint(img, color):
    """Recolour a cut piece, keeping its alpha - used for the dark wordmark."""
    out = Image.new("RGBA", img.size, tuple(color) + (255,))
    out.putalpha(img.getchannel("A"))
    return out


def paste_centered(canvas, img, cy, cx=None):
    """Alpha-composite `img` centred on (cx, cy); cx defaults to canvas centre."""
    x = (canvas.width - img.width) // 2 if cx is None else cx - img.width // 2
    canvas.alpha_composite(img, (x, cy - img.height // 2))


if __name__ == "__main__":
    mascot, wordmark = load()
    print("mascot  ", mascot.size)
    print("wordmark", wordmark.size)
