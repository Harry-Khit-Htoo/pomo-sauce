"""
Tomato Focus - asset generator.

Produces, with no third-party audio deps:
  * assets/sounds/*.wav        alarm tones played in-app (audioplayers)
  * android/app/src/main/res/raw/*.wav  the same tones as Android notification sounds
  * assets/branding/*.png      launcher icon, adaptive foreground, brand lockup,
                               splash art and the Play feature graphic

Run:  python tool/generate_assets.py
Requires: Pillow (for the images). Audio is pure stdlib.
"""

import math
import os
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOUNDS = os.path.join(ROOT, "assets", "sounds")
RAW = os.path.join(ROOT, "android", "app", "src", "main", "res", "raw")
BRAND = os.path.join(ROOT, "assets", "branding")

SR = 44100

# --------------------------------------------------------------------------
# audio helpers
# --------------------------------------------------------------------------


def silence(seconds):
    return [0.0] * int(SR * seconds)


def mix_into(buf, start_sec, samples, gain=1.0):
    start = int(start_sec * SR)
    for i, s in enumerate(samples):
        j = start + i
        if 0 <= j < len(buf):
            buf[j] += s * gain


def bell_strike(f0, partials, dur, brightness=1.0):
    """A struck-metal tone: inharmonic partials, instant attack, exp decay.

    `partials` is a list of (ratio, amplitude, decay_seconds) triples.
    """
    n = int(SR * dur)
    out = [0.0] * n
    two_pi = 2.0 * math.pi
    for ratio, amp, decay in partials:
        freq = f0 * ratio
        if freq >= SR / 2.0:
            continue
        w = two_pi * freq / SR
        k = -1.0 / (decay * SR)
        a = amp * brightness if ratio > 1.0 else amp
        for i in range(n):
            out[i] += a * math.exp(k * i) * math.sin(w * i)
    # clapper transient: a very short bright tick so it reads "mechanical"
    tick_n = int(SR * 0.006)
    seed = 12345
    for i in range(min(tick_n, n)):
        seed = (1103515245 * seed + 12345) & 0x7FFFFFFF
        noise = (seed / 0x3FFFFFFF) - 1.0
        out[i] += noise * 0.28 * (1.0 - i / tick_n)
    # gentle attack ramp removes the click at sample 0
    ramp = int(SR * 0.0015)
    for i in range(min(ramp, n)):
        out[i] *= i / ramp
    return out


def lowpass(buf, cutoff_hz):
    """One-pole lowpass - takes the harshness off the top end ("soft" bell)."""
    dt = 1.0 / SR
    rc = 1.0 / (2 * math.pi * cutoff_hz)
    alpha = dt / (rc + dt)
    y = 0.0
    for i, x in enumerate(buf):
        y += alpha * (x - y)
        buf[i] = y
    return buf


def normalize(buf, peak=0.82):
    m = max((abs(v) for v in buf), default=0.0)
    if m <= 0:
        return buf
    g = peak / m
    for i in range(len(buf)):
        buf[i] *= g
    return buf


def fade_edges(buf, fade=0.01):
    n = int(SR * fade)
    for i in range(min(n, len(buf))):
        buf[i] *= i / n
        buf[-1 - i] *= i / n
    return buf


def write_wav(path, buf):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    frames = bytearray()
    for v in buf:
        # soft clip, then 16-bit
        v = math.tanh(v * 1.05)
        frames += struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print("  wav  %-28s %6.1f KB" % (os.path.basename(path), os.path.getsize(path) / 1024))


# --------------------------------------------------------------------------
# the three alarm tones
# --------------------------------------------------------------------------


def analog_bell():
    """Default tone: a soft analog alarm-clock 'cling cling cling' loop.

    Three strikes, a breath, repeat - the loop period is exactly 1.5 s so the
    file can be looped seamlessly while the alarm is showing.
    """
    partials = [
        (1.00, 0.62, 0.85),
        (1.63, 0.40, 0.55),
        (2.24, 0.26, 0.40),
        (2.98, 0.17, 0.28),
        (3.76, 0.11, 0.20),
        (5.10, 0.07, 0.13),
    ]
    period = 1.5
    loops = 3
    buf = silence(period * loops + 0.4)
    for loop in range(loops):
        base = loop * period
        for k, offset in enumerate((0.0, 0.34, 0.68)):
            # alternate two very close pitches: a real clapper never hits the
            # dome in exactly the same spot twice
            f0 = 1180.0 if k % 2 == 0 else 1212.0
            strike = bell_strike(f0, partials, 0.82, brightness=0.9)
            mix_into(buf, base + offset, strike, gain=0.9 if k else 1.0)
    lowpass(buf, 5200)
    normalize(buf, 0.80)
    return fade_edges(buf)


def soft_chime():
    """Alternate tone: a warm two-note chime, gentler than the bell."""
    partials = [
        (1.00, 0.70, 1.60),
        (2.00, 0.30, 1.10),
        (3.01, 0.14, 0.70),
        (4.02, 0.07, 0.45),
    ]
    buf = silence(3.6)
    for base in (0.0, 1.8):
        mix_into(buf, base + 0.00, bell_strike(783.99, partials, 1.7, 0.8))
        mix_into(buf, base + 0.42, bell_strike(587.33, partials, 1.7, 0.8), gain=0.9)
    lowpass(buf, 4000)
    normalize(buf, 0.72)
    return fade_edges(buf, 0.02)


def digital_beep():
    """Alternate tone: a short, dry electronic triple-beep."""
    buf = silence(2.4)
    for loop in range(2):
        for k in range(3):
            t0 = loop * 1.2 + k * 0.17
            n = int(SR * 0.11)
            seg = [0.0] * n
            for i in range(n):
                env = math.exp(-6.0 * i / n)
                ph = 2 * math.pi * 1046.5 * i / SR
                seg[i] = env * (math.sin(ph) + 0.30 * math.sin(3 * ph) + 0.12 * math.sin(5 * ph))
            ramp = int(SR * 0.004)
            for i in range(ramp):
                seg[i] *= i / ramp
                seg[-1 - i] *= i / ramp
            mix_into(buf, t0, seg)
    lowpass(buf, 7000)
    normalize(buf, 0.74)
    return fade_edges(buf)


def build_sounds():
    print("sounds:")
    for name, fn in (
        ("analog_bell", analog_bell),
        ("soft_chime", soft_chime),
        ("digital_beep", digital_beep),
    ):
        buf = fn()
        write_wav(os.path.join(SOUNDS, name + ".wav"), buf)
        write_wav(os.path.join(RAW, name + ".wav"), buf)


# --------------------------------------------------------------------------
# branding images
# --------------------------------------------------------------------------

from PIL import Image, ImageDraw, ImageFont  # noqa: E402

SS = 4  # supersample factor - draw big, downscale with LANCZOS for clean edges

# Sampled from the mascot reference sheet: ripe tomato red, leaf green, and a
# warm dark brown for the linework (never black - it reads harsh on red).
INK = (74, 26, 20)
LEAF = (86, 176, 74)
LEAF_DARK = (58, 138, 52)
BODY_TOP = (240, 84, 62)
BODY_BOTTOM = (203, 47, 40)
BLUSH = (255, 130, 120)

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\segoeuib.ttf",
    r"C:\Windows\Fonts\seguisb.ttf",
    r"C:\Windows\Fonts\calibrib.ttf",
    r"C:\Windows\Fonts\arialbd.ttf",
]


def load_font(px):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, px)
            except OSError:
                continue
    return ImageFont.load_default()


def vertical_gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", (1, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        px[0, y] = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return img.resize((w, h), Image.BILINEAR)


def leaf_polygon(cx, cy, angle_deg, length, width):
    """A pointed calyx leaf as a quad with a rounded shoulder."""
    a = math.radians(angle_deg)
    ux, uy = math.cos(a), math.sin(a)
    px, py = -uy, ux  # perpendicular
    tip = (cx + ux * length, cy + uy * length)
    shoulder = length * 0.42
    return [
        (cx, cy),
        (cx + ux * shoulder + px * width, cy + uy * shoulder + py * width),
        tip,
        (cx + ux * shoulder - px * width, cy + uy * shoulder - py * width),
    ]


def draw_tomato(size, scale=1.0, offset=(0.0, 0.0), transparent=True, bg=None):
    """Render the mascot on a square RGBA canvas of `size` px.

    `scale` shrinks the character inside the canvas (adaptive icons need the
    art to sit inside a 66% safe zone); `offset` nudges it in unit coords.
    """
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    if not transparent and bg is not None:
        img.paste(vertical_gradient((S, S), bg[0], bg[1]).convert("RGBA"), (0, 0))
    d = ImageDraw.Draw(img)

    def P(x, y):
        cx, cy = 0.5 + offset[0], 0.5 + offset[1]
        return ((cx + (x - 0.5) * scale) * S, (cy + (y - 0.5) * scale) * S)

    def box(cx, cy, rx, ry):
        return list(P(cx - rx, cy - ry)) + list(P(cx + rx, cy + ry))

    # soft contact shadow under the body
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(box(0.5, 0.88, 0.30, 0.045), fill=(120, 30, 20, 52))
    img.alpha_composite(shadow)

    # Calyx: rounded blob leaves radiating from a short thick stem, matching
    # the reference sheet. Drawn before the body so they tuck under the
    # shoulders. Each leaf is an ellipse rotated into place - PIL cannot draw
    # a rotated ellipse directly, so it goes on its own layer and spins.
    for ang, reach, ln, wd in ((-90, 0.100, 0.145, 0.052),
                               (-142, 0.130, 0.160, 0.055),
                               (-38, 0.130, 0.160, 0.055),
                               (170, 0.140, 0.145, 0.050),
                               (10, 0.140, 0.145, 0.050)):
        a = math.radians(ang)
        cx = 0.5 + math.cos(a) * reach
        cy = 0.300 + math.sin(a) * reach
        layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        ld.ellipse(box(cx, cy, ln, wd), fill=LEAF)
        # centre vein and a small highlight, per the style guide base model
        vx0, vy0 = P(cx - ln * 0.55, cy)
        vx1, vy1 = P(cx + ln * 0.70, cy)
        ld.line([vx0, vy0, vx1, vy1], fill=LEAF_DARK + (140,),
                width=max(2, int(S * 0.006)))
        ld.ellipse(box(cx - ln * 0.15, cy - wd * 0.42, ln * 0.35, wd * 0.21),
                   fill=(255, 255, 255, 62))
        img.alpha_composite(layer.rotate(-ang - 90, resample=Image.BICUBIC,
                                         center=P(cx, cy)))
    # thick, slightly curved stem
    sx0, sy0 = P(0.5, 0.300)
    sx1, sy1 = P(0.523, 0.150)
    d.line([sx0, sy0, (sx0 + sx1) / 2 - S * 0.012, (sy0 + sy1) / 2, sx1, sy1],
           fill=LEAF_DARK, width=int(S * 0.034 * scale), joint="curve")
    r = S * 0.017 * scale
    d.ellipse([sx1 - r, sy1 - r, sx1 + r, sy1 + r], fill=LEAF_DARK)

    # body: a vertical gradient masked by the tomato silhouette
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse(box(0.5, 0.58, 0.345, 0.315), fill=255)
    img.paste(vertical_gradient((S, S), BODY_TOP, BODY_BOTTOM).convert("RGBA"), (0, 0), mask)

    # specular highlight, upper left
    gloss = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(gloss).ellipse(box(0.665, 0.418, 0.095, 0.058),
                                  fill=(255, 255, 255, 80))
    img.alpha_composite(gloss.rotate(-28, resample=Image.BICUBIC,
                                     center=P(0.665, 0.418)))

    # blush
    blush = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blush)
    for cx in (0.305, 0.695):
        bd.ellipse(box(cx, 0.665, 0.056, 0.032), fill=BLUSH + (112,))
    img.alpha_composite(blush)

    # eyes
    for ex in (0.383, 0.617):
        d.ellipse(box(ex, 0.548, 0.076, 0.092), fill=(255, 255, 255, 255))
        d.ellipse(box(ex, 0.556, 0.065, 0.079), fill=(59, 29, 20, 255))
        d.ellipse(box(ex - 0.024, 0.524, 0.021, 0.021), fill=(255, 255, 255, 255))
        d.ellipse(box(ex + 0.028, 0.585, 0.009, 0.009), fill=(255, 255, 255, 190))

    # eyebrows: short thin arcs, the reference's default expression
    for ex, flip in ((0.383, 1), (0.617, -1)):
        brow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        bd2 = ImageDraw.Draw(brow)
        bd2.arc(box(ex + 0.012 * flip, 0.452, 0.062, 0.040), 200, 340,
                fill=INK + (255,), width=max(2, int(S * 0.011)))
        img.alpha_composite(brow)

    # open smile with a tongue, clipped to the mouth shape
    mouth_mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mouth_mask).chord(box(0.5, 0.7275, 0.088, 0.0675), 8, 172, fill=255)
    mouth = Image.new("RGBA", (S, S), INK + (255,))
    ImageDraw.Draw(mouth).ellipse(box(0.5, 0.780, 0.050, 0.045), fill=(255, 138, 148, 255))
    img.paste(mouth, (0, 0), mouth_mask)

    return img.resize((size, size), Image.LANCZOS)


def build_images():
    os.makedirs(BRAND, exist_ok=True)
    print("branding:")

    def save(img, name):
        path = os.path.join(BRAND, name)
        img.save(path, "PNG")
        print("  png  %-30s %6.1f KB  %s" % (name, os.path.getsize(path) / 1024, img.size))

    icon_bg = ((255, 244, 238), (255, 214, 201))
    # Play Store icon: plain 512x512, full bleed, NO text (Play icon spec).
    save(draw_tomato(512, scale=0.86, transparent=False, bg=icon_bg), "icon_play_512.png")
    # Source image for flutter_launcher_icons (legacy Android + iOS).
    save(draw_tomato(1024, scale=0.86, transparent=False, bg=icon_bg), "icon_source_1024.png")
    # Adaptive foreground: transparent, art kept inside the 66% safe zone.
    save(draw_tomato(1024, scale=0.60, offset=(0.0, 0.01)), "icon_adaptive_foreground.png")
    # Bare mascot, used on the About screen.
    save(draw_tomato(512, scale=0.94), "mascot.png")

    for label, bgc, fg, sub in (("light", (255, 250, 247), INK, (150, 106, 96)),
                                ("dark", (20, 17, 16), (247, 235, 232), (176, 138, 130))):
        # Brand lockup: the mascot with "Productivity" written underneath.
        # This is the in-app / splash lockup, deliberately not the launcher icon.
        W, H = 1080, 1400
        img = Image.new("RGBA", (W, H), bgc + (255,))
        img.alpha_composite(draw_tomato(880, scale=0.94), ((W - 880) // 2, 150))
        d = ImageDraw.Draw(img)
        for text, font, color, y in (("Productivity", load_font(150), fg, 1035),
                                     ("Tomato Focus", load_font(58), sub, 1215)):
            w = d.textbbox((0, 0), text, font=font)[2]
            d.text(((W - w) / 2, y), text, font=font, fill=color)
        save(img, "brand_lockup_%s.png" % label)

        # Splash art: same lockup on a transparent ground for flutter_native_splash.
        sp = Image.new("RGBA", (900, 1150), (0, 0, 0, 0))
        sp.alpha_composite(draw_tomato(760, scale=0.94), (70, 40))
        sd = ImageDraw.Draw(sp)
        f = load_font(128)
        w = sd.textbbox((0, 0), "Productivity", font=f)[2]
        sd.text(((900 - w) / 2, 800), "Productivity", font=f, fill=fg)
        save(sp, "splash_%s.png" % label)

    # Play feature graphic, 1024x500.
    fgx = Image.new("RGBA", (1024, 500), (0, 0, 0, 0))
    fgx.paste(vertical_gradient((1024, 500), (255, 243, 237), (250, 190, 175)).convert("RGBA"), (0, 0))
    fgx.alpha_composite(draw_tomato(430, scale=0.94), (66, 34))
    d = ImageDraw.Draw(fgx)
    d.text((520, 160), "Tomato Focus", font=load_font(88), fill=INK)
    d.text((524, 272), "Pomodoro timer + habit tracker", font=load_font(40), fill=(140, 52, 40))
    d.text((524, 328), "Focus. Rest. Repeat.", font=load_font(40), fill=(168, 74, 58))
    save(fgx, "feature_graphic_1024x500.png")


if __name__ == "__main__":
    build_sounds()
    build_images()
    print("done.")
