"""Generates the Expense Tracker app icon (full-bleed + adaptive foreground).

Design: rounded teal gradient tile, white wallet with card slot, gold coin
with an upward trend arrow — clean, geometric, readable at small sizes.
"""
from PIL import Image, ImageDraw, ImageFilter
import math
import os

SIZE = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")

TEAL_DARK = (27, 77, 66)     # #1B4D42
TEAL = (46, 125, 107)        # #2E7D6B
TEAL_LIGHT = (74, 160, 138)  # #4AA08A
WHITE = (250, 252, 251)
GOLD = (253, 216, 53)        # #FDD835
GOLD_DARK = (230, 190, 20)
INK = (20, 54, 47)


def vertical_gradient(size, top, bottom):
    base = Image.new("RGB", (1, size[1]))
    for y in range(size[1]):
        t = y / (size[1] - 1)
        base.putpixel(
            (0, y),
            tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)),
        )
    return base.resize(size)


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def draw_wallet_motif(img, scale=1.0, center=None, shadow=True):
    """Draws wallet + coin + trend arrow centered at `center` (default middle).
    All geometry is proportional to SIZE and multiplied by `scale`."""
    d = ImageDraw.Draw(img)
    cx, cy = center or (SIZE / 2, SIZE / 2)
    u = SIZE / 1024 * scale  # unit

    def R(x0, y0, x1, y1, r):
        return [cx + x0 * u, cy + y0 * u, cx + x1 * u, cy + y1 * u], r * u

    if shadow:
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        body, r = R(-250, -170, 250, 210, 60)
        sd.rounded_rectangle(body, radius=r, fill=(0, 0, 0, 90))
        sh = sh.filter(ImageFilter.GaussianBlur(18 * u / (SIZE / 1024)))
        img.alpha_composite(sh)

    # Wallet body
    body, r = R(-250, -170, 250, 210, 60)
    d.rounded_rectangle(body, radius=r, fill=WHITE)

    # Wallet top flap (slightly darker strip)
    flap, r2 = R(-250, -170, 250, -60, 60)
    d.rounded_rectangle(flap, radius=r2, fill=(227, 238, 234))

    # Card slot line
    slot, r3 = R(-160, -115, 60, -115, 0)
    d.line(slot, fill=(180, 200, 194), width=int(14 * u))

    # Clasp
    clasp, r4 = R(150, 20, 250, 120, 28)
    d.rounded_rectangle(clasp, radius=r4, fill=(227, 238, 234))
    clasp_in, r5 = R(180, 45, 225, 95, 18)
    d.rounded_rectangle(clasp_in, radius=r5, fill=TEAL)

    # Gold coin with trend arrow (top-right, overlapping wallet)
    coin_c = (cx + 165 * u, cy - 165 * u)
    coin_r = 150 * u
    d.ellipse(
        [coin_c[0] - coin_r, coin_c[1] - coin_r, coin_c[0] + coin_r, coin_c[1] + coin_r],
        fill=GOLD, outline=GOLD_DARK, width=int(10 * u),
    )
    # Trend arrow polyline inside the coin
    pts = [
        (coin_c[0] - 80 * u, coin_c[1] + 55 * u),
        (coin_c[0] - 25 * u, coin_c[1] - 5 * u),
        (coin_c[0] + 15 * u, coin_c[1] + 25 * u),
        (coin_c[0] + 80 * u, coin_c[1] - 60 * u),
    ]
    d.line(pts, fill=INK, width=int(26 * u), joint="curve")
    # Arrow head aligned with the last segment direction
    (px, py), (ax, ay) = pts[-2], pts[-1]
    dx, dy = ax - px, ay - py
    norm = math.hypot(dx, dy)
    ux, uy = dx / norm, dy / norm          # unit direction
    vxp, vyp = -uy, ux                     # perpendicular
    tip = (ax + ux * 46 * u, ay + uy * 46 * u)
    base = (ax - ux * 10 * u, ay - uy * 10 * u)
    half = 34 * u
    d.polygon(
        [
            tip,
            (base[0] + vxp * half, base[1] + vyp * half),
            (base[0] - vxp * half, base[1] - vyp * half),
        ],
        fill=INK,
    )


def make_full_icon():
    img = vertical_gradient((SIZE, SIZE), TEAL_LIGHT, TEAL_DARK).convert("RGBA")

    # Soft decorative circles for depth
    deco = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dd = ImageDraw.Draw(deco)
    dd.ellipse([-300, -300, 500, 500], fill=(255, 255, 255, 14))
    dd.ellipse([620, 640, 1400, 1420], fill=(0, 0, 0, 22))
    img.alpha_composite(deco)

    draw_wallet_motif(img)

    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(img, (0, 0), rounded_mask((SIZE, SIZE), int(SIZE * 0.22)))
    out.save(os.path.join(OUT, "app_icon.png"))
    print("wrote app_icon.png")


def make_foreground():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    # Adaptive foreground safe zone: keep motif within ~66% center.
    draw_wallet_motif(img, scale=0.62, shadow=False)
    img.save(os.path.join(OUT, "app_icon_foreground.png"))
    print("wrote app_icon_foreground.png")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_full_icon()
    make_foreground()
    print("done")
