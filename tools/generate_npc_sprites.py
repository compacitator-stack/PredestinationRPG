"""
Generate pixel art exploration sprites for NPCs visible in the dungeon.
These are taller, figure-oriented sprites displayed as billboards facing the player.

Style: same moody PS1 aesthetic as battle sprites, 5-bit posterized.
Output: 64x96 exploration sprites (taller than wide for standing figures).

NPCs:
  - Wounded Celestialite — golden angelic figure, crumpled wings, glowing
  - The Blind Seer — dark-robed seer with cloth-wrapped eyes
  - Ezekiel — tall golden-armored warrior, burning coal eyes
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os
import random

random.seed(99)

SPRITE_W = 64
SPRITE_H = 96
WORK_W = 128
WORK_H = 192


def posterize_5bit(img):
    """Reduce to 5-bit color depth."""
    pixels = img.load()
    w, h = img.size
    step = 8
    for y in range(h):
        for x in range(w):
            p = pixels[x, y]
            if len(p) == 4:
                r, g, b, a = p
                r = min(255, max(0, int(math.floor(r / step) * step + step // 2)))
                g = min(255, max(0, int(math.floor(g / step) * step + step // 2)))
                b = min(255, max(0, int(math.floor(b / step) * step + step // 2)))
                pixels[x, y] = (r, g, b, a)
            else:
                r, g, b = p[:3]
                r = min(255, max(0, int(math.floor(r / step) * step + step // 2)))
                g = min(255, max(0, int(math.floor(g / step) * step + step // 2)))
                b = min(255, max(0, int(math.floor(b / step) * step + step // 2)))
                pixels[x, y] = (r, g, b)
    return img


def add_noise(img, intensity=12):
    """Add subtle color noise for painterly texture."""
    pixels = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            p = pixels[x, y]
            if len(p) == 4 and p[3] == 0:
                continue
            noise = random.randint(-intensity, intensity)
            if len(p) == 4:
                r, g, b, a = p
                pixels[x, y] = (
                    max(0, min(255, r + noise)),
                    max(0, min(255, g + noise)),
                    max(0, min(255, b + noise)),
                    a
                )
            else:
                r, g, b = p[:3]
                pixels[x, y] = (
                    max(0, min(255, r + noise)),
                    max(0, min(255, g + noise)),
                    max(0, min(255, b + noise))
                )
    return img


def generate_wounded_celestialite():
    """Wounded Celestialite — golden angelic figure slumped against wall.
    Crumpled wings, flickering golden light, wounded but radiant."""
    img = Image.new("RGBA", (WORK_W, WORK_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx = WORK_W // 2
    cy = WORK_H // 2 + 20  # shifted down — slumped posture

    # Soft golden aura
    aura = Image.new("RGBA", (WORK_W, WORK_H), (0, 0, 0, 0))
    aura_draw = ImageDraw.Draw(aura)
    aura_draw.ellipse([cx - 50, cy - 70, cx + 50, cy + 30], fill=(220, 180, 60, 30))
    aura = aura.filter(ImageFilter.GaussianBlur(radius=12))
    img = Image.alpha_composite(img, aura)
    draw = ImageDraw.Draw(img)

    # Crumpled wings — drooping behind body
    for side in [-1, 1]:
        for i in range(6):
            t = i / 5.0
            angle = side * (0.3 + t * 0.5)
            length = int(35 - t * 10)
            wx = cx + side * 12 + int(math.cos(angle) * side * length)
            wy = cy - 30 + int(t * 40)  # wings droop downward
            shade_r = int(180 - t * 60)
            shade_g = int(150 - t * 50)
            shade_b = int(40 - t * 15)
            draw.ellipse([wx - 8, wy - 5, wx + 8, wy + 5],
                         fill=(shade_r, shade_g, shade_b, int(180 - t * 40)))

    # Body — slumped seated posture (wider at bottom)
    for i in range(10):
        t = i / 9.0
        y = cy - 40 + int(t * 80)
        w = int(16 + t * 12)
        r = int(200 - t * 50)
        g = int(170 - t * 45)
        b = int(80 - t * 25)
        draw.ellipse([cx - w, y - 5, cx + w, y + 5],
                     fill=(r, g, b, 220))

    # Robe/garment folds
    for offset in [-8, 0, 8]:
        for i in range(4):
            y = cy - 10 + i * 15
            shade = random.randint(140, 180)
            draw.line([cx + offset, y, cx + offset + random.randint(-3, 3), y + 12],
                      fill=(shade, shade - 20, shade - 80, 120), width=2)

    # Head — tilted slightly (wounded)
    draw.ellipse([cx - 12, cy - 55, cx + 14, cy - 30], fill=(210, 185, 100, 240))

    # Eyes — gentle golden glow, half-closed
    draw.ellipse([cx - 7, cy - 46, cx - 2, cy - 42], fill=(240, 210, 80, 200))
    draw.ellipse([cx + 3, cy - 46, cx + 8, cy - 42], fill=(240, 210, 80, 200))

    # Wound marks — dark streaks across torso
    for _ in range(4):
        sx = cx + random.randint(-12, 12)
        sy = cy + random.randint(-25, 10)
        ex = sx + random.randint(-8, 8)
        ey = sy + random.randint(5, 15)
        draw.line([sx, sy, ex, ey], fill=(80, 30, 20, 150), width=2)

    # Flickering golden particles around figure
    for _ in range(12):
        px = cx + random.randint(-35, 35)
        py = cy + random.randint(-55, 25)
        size = random.randint(1, 3)
        alpha = random.randint(100, 220)
        draw.ellipse([px - size, py - size, px + size, py + size],
                     fill=(240, 200, 60, alpha))

    add_noise(img, 10)
    return img


def generate_blind_seer():
    """The Blind Seer — dark-robed seated figure, cloth-wrapped eyes.
    Mysterious, contemplative, deep blues and dark purples."""
    img = Image.new("RGBA", (WORK_W, WORK_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx = WORK_W // 2
    cy = WORK_H // 2 + 15  # slightly lower — seated cross-legged

    # Subtle dark blue aura
    aura = Image.new("RGBA", (WORK_W, WORK_H), (0, 0, 0, 0))
    aura_draw = ImageDraw.Draw(aura)
    aura_draw.ellipse([cx - 45, cy - 60, cx + 45, cy + 35], fill=(40, 50, 120, 25))
    aura = aura.filter(ImageFilter.GaussianBlur(radius=10))
    img = Image.alpha_composite(img, aura)
    draw = ImageDraw.Draw(img)

    # Robe body — wide at base (cross-legged), narrowing up
    for i in range(12):
        t = i / 11.0
        y = cy - 40 + int(t * 90)
        w = int(14 + t * 22)
        shade = int(25 + t * 10)
        b_tint = int(15 + t * 20)
        draw.ellipse([cx - w, y - 5, cx + w, y + 5],
                     fill=(shade, shade - 3, shade + b_tint, 230))

    # Robe folds — subtle
    for offset in [-10, -3, 3, 10]:
        for i in range(5):
            y = cy - 10 + i * 14
            shade = random.randint(18, 40)
            draw.line([cx + offset, y, cx + offset + random.randint(-2, 2), y + 10],
                      fill=(shade, shade - 2, shade + 12, 130), width=2)

    # Cross-legged base — wider oval at bottom
    draw.ellipse([cx - 30, cy + 30, cx + 30, cy + 50], fill=(22, 18, 35, 220))

    # Hood — deep cowl
    draw.ellipse([cx - 20, cy - 58, cx + 20, cy - 25], fill=(22, 18, 32, 245))
    # Hood shadow interior
    draw.ellipse([cx - 14, cy - 50, cx + 14, cy - 30], fill=(10, 6, 16, 250))

    # Cloth wrapping over eyes — lighter strip across face
    draw.rectangle([cx - 16, cy - 48, cx + 16, cy - 40], fill=(60, 55, 50, 230))
    draw.rectangle([cx - 18, cy - 47, cx + 18, cy - 41], fill=(55, 50, 45, 200))
    # Knot at back of head
    draw.ellipse([cx + 14, cy - 48, cx + 22, cy - 40], fill=(50, 45, 40, 210))

    # Mouth — thin line, solemn
    draw.line([cx - 4, cy - 34, cx + 4, cy - 34], fill=(40, 30, 35, 180), width=1)

    # Hands resting on knees — visible from robes
    for side in [-1, 1]:
        hx = cx + side * 18
        hy = cy + 15
        draw.ellipse([hx - 6, hy - 4, hx + 6, hy + 4], fill=(55, 45, 40, 210))
        # Fingers
        for fi in range(3):
            fx = hx + side * (3 + fi * 3)
            fy = hy + 2
            draw.ellipse([fx - 2, fy - 1, fx + 2, fy + 2], fill=(50, 40, 35, 200))

    # Faint mystic symbols floating around
    for _ in range(6):
        px = cx + random.randint(-35, 35)
        py = cy + random.randint(-50, 20)
        size = random.randint(1, 2)
        draw.ellipse([px - size, py - size, px + size, py + size],
                     fill=(80, 90, 180, random.randint(60, 140)))

    add_noise(img, 8)
    return img


def generate_ezekiel():
    """Ezekiel — towering golden-armored angelic warrior.
    Cracked but radiant armor, burning coal eyes, imposing presence."""
    img = Image.new("RGBA", (WORK_W, WORK_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx = WORK_W // 2
    cy = WORK_H // 2 - 5  # slightly higher — tall imposing figure

    # Warm golden aura
    aura = Image.new("RGBA", (WORK_W, WORK_H), (0, 0, 0, 0))
    aura_draw = ImageDraw.Draw(aura)
    aura_draw.ellipse([cx - 55, cy - 75, cx + 55, cy + 60], fill=(220, 180, 50, 25))
    aura = aura.filter(ImageFilter.GaussianBlur(radius=14))
    img = Image.alpha_composite(img, aura)
    draw = ImageDraw.Draw(img)

    # Legs — armored, golden
    for lx_off in [-12, 12]:
        for i in range(5):
            t = i / 4.0
            y = cy + 30 + int(t * 45)
            shade_r = int(160 - t * 30)
            shade_g = int(130 - t * 25)
            shade_b = int(50 - t * 15)
            draw.rectangle([cx + lx_off - 8, y - 4, cx + lx_off + 8, y + 4],
                           fill=(shade_r, shade_g, shade_b, 235))

    # Torso — golden plate armor
    for i in range(8):
        t = i / 7.0
        y = cy - 30 + int(t * 60)
        w = int(24 - abs(t - 0.3) * 10)
        r = int(190 - t * 40)
        g = int(155 - t * 35)
        b = int(55 - t * 20)
        draw.ellipse([cx - w, y - 5, cx + w, y + 5], fill=(r, g, b, 240))

    # Armor plate details — horizontal lines
    for ay in [cy - 20, cy - 8, cy + 4, cy + 16]:
        aw = random.randint(16, 22)
        shade = random.randint(150, 190)
        draw.rectangle([cx - aw, ay - 2, cx + aw, ay + 2],
                       fill=(shade, shade - 25, shade - 90, 200))

    # Armor cracks — this is the warrior who cannot enter the corrupted zone
    for _ in range(5):
        sx = cx + random.randint(-18, 18)
        sy = cy + random.randint(-25, 20)
        points = [(sx, sy)]
        for _ in range(random.randint(2, 3)):
            sx += random.randint(-8, 8)
            sy += random.randint(-5, 8)
            points.append((sx, sy))
        draw.line(points, fill=(60, 40, 25, 180), width=2)

    # Pauldrons — shoulder armor
    for side in [-1, 1]:
        px = cx + side * 26
        py = cy - 22
        draw.ellipse([px - 10, py - 8, px + 10, py + 8],
                     fill=(185, 150, 50, 240))
        draw.ellipse([px - 7, py - 5, px + 7, py + 5],
                     fill=(200, 165, 60, 230))

    # Arms — armored
    for side in [-1, 1]:
        for i in range(4):
            t = i / 3.0
            ax = cx + side * (26 + int(t * 8))
            ay = cy - 10 + int(t * 30)
            shade = int(160 - t * 30)
            draw.ellipse([ax - 7, ay - 6, ax + 7, ay + 6],
                         fill=(shade, shade - 20, shade - 80, 230))

    # Head — strong angular
    draw.ellipse([cx - 14, cy - 55, cx + 14, cy - 28], fill=(175, 145, 70, 245))

    # Helm suggestion — angular top
    draw.polygon([(cx - 12, cy - 50), (cx, cy - 62), (cx + 12, cy - 50)],
                 fill=(190, 155, 55, 235))

    # Eyes — burning coals
    draw.ellipse([cx - 9, cy - 44, cx - 3, cy - 38], fill=(255, 120, 20, 250))
    draw.ellipse([cx + 3, cy - 44, cx + 9, cy - 38], fill=(255, 120, 20, 250))
    # Eye glow
    draw.ellipse([cx - 12, cy - 47, cx, cy - 35], fill=(255, 100, 10, 50))
    draw.ellipse([cx, cy - 47, cx + 12, cy - 35], fill=(255, 100, 10, 50))

    # Halo — intact golden ring above head
    for angle_deg in range(0, 360, 4):
        angle = math.radians(angle_deg)
        hx = cx + int(math.cos(angle) * 18)
        hy = (cy - 58) - int(math.sin(angle) * 7)
        draw.ellipse([hx - 2, hy - 2, hx + 2, hy + 2],
                     fill=(240, 200, 60, 220))

    # Ground shadow
    draw.ellipse([cx - 22, cy + 70, cx + 22, cy + 82], fill=(40, 30, 15, 80))

    # Golden particles
    for _ in range(8):
        px = cx + random.randint(-30, 30)
        py = cy + random.randint(-60, 50)
        size = random.randint(1, 2)
        draw.ellipse([px - size, py - size, px + size, py + size],
                     fill=(240, 200, 60, random.randint(80, 200)))

    add_noise(img, 10)
    return img


def save_npc_sprite(img, name, out_dir):
    """Save at 64x96 exploration sprite size."""
    sprite = img.resize((SPRITE_W, SPRITE_H), Image.LANCZOS)
    posterize_5bit(sprite)
    sprite.save(os.path.join(out_dir, f"{name}.png"), "PNG")
    print(f"  {name}: {SPRITE_W}x{SPRITE_H}")


def main():
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(base, "assets", "sprites", "npcs")
    os.makedirs(out_dir, exist_ok=True)

    print("Generating NPC exploration sprites...")

    npcs = [
        ("wounded_celestialite", generate_wounded_celestialite),
        ("blind_seer", generate_blind_seer),
        ("ezekiel", generate_ezekiel),
    ]

    for name, gen_func in npcs:
        img = gen_func()
        save_npc_sprite(img, name, out_dir)

    print()
    print(f"Done! {len(npcs)} NPC exploration sprites generated.")
    print(f"Output: {out_dir}")


if __name__ == "__main__":
    main()
