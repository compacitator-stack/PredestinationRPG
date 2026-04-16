"""
Generate pixel art battle sprites for the 5 RPG-original creatures
that don't have card game art.

Style: moody, painterly feel to match the card art aesthetic.
Output: 96x96 battle sprites + 128x128 portraits.

Creatures:
  - Shade (Corrupt, aggressive) — dark wraith/shadow figure
  - Stone Golem (Feral, tank) — hulking rocky form
  - Will-o-Wisp (Mystic, glass cannon) — ethereal floating flame
  - Dark Acolyte (Corrupt, support) — hooded figure with dark energy
  - Corrupted Seraph (Corrupt, boss) — fallen angel, twisted wings
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os
import random

# Seed for reproducibility
random.seed(42)

BATTLE_SIZE = 96
PORTRAIT_SIZE = 128
# Work at 2x then downscale for smoother pixel art
WORK_SIZE = 192


def posterize_5bit(img):
    """Reduce to 5-bit color depth."""
    pixels = img.load()
    w, h = img.size
    step = 8  # 256/32
    for y in range(h):
        for x in range(w):
            p = pixels[x, y]
            if len(p) == 4:
                r, g, b, a = p
                r = min(255, max(0, int(math.floor(r / step) * step + step / 2)))
                g = min(255, max(0, int(math.floor(g / step) * step + step / 2)))
                b = min(255, max(0, int(math.floor(b / step) * step + step / 2)))
                pixels[x, y] = (r, g, b, a)
            else:
                r, g, b = p[:3]
                r = min(255, max(0, int(math.floor(r / step) * step + step / 2)))
                g = min(255, max(0, int(math.floor(g / step) * step + step / 2)))
                b = min(255, max(0, int(math.floor(b / step) * step + step / 2)))
                pixels[x, y] = (r, g, b)
    return img


def blend_color(c1, c2, t):
    """Blend two RGB tuples by factor t (0=c1, 1=c2)."""
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_ellipse_aa(draw, bbox, fill, img):
    """Draw a filled ellipse."""
    draw.ellipse(bbox, fill=fill)


def add_noise(img, intensity=15):
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


def generate_shade():
    """Shade — dark wraith, smoky translucent figure, reds and purples."""
    img = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = WORK_SIZE // 2, WORK_SIZE // 2

    # Dark smoky body — layered ellipses from bottom up
    # Base shadow on ground
    draw.ellipse([cx-60, cy+50, cx+60, cy+75], fill=(20, 5, 15, 120))

    # Main body — tall dark form
    for i in range(8):
        t = i / 7.0
        w = int(35 - t * 15)
        h_off = int(-60 + t * 100)
        alpha = int(200 - t * 80)
        r = int(30 + t * 40)
        g = int(5 + t * 5)
        b = int(20 + t * 30)
        draw.ellipse([cx-w, cy+h_off-15, cx+w, cy+h_off+15],
                     fill=(r, g, b, alpha))

    # Tattered cloak edges — jagged strokes
    for i in range(20):
        angle = random.uniform(-0.8, 0.8)
        length = random.randint(20, 50)
        sx = cx + random.randint(-25, 25)
        sy = cy + random.randint(-20, 40)
        ex = sx + int(math.sin(angle) * length)
        ey = sy + int(math.cos(angle) * length)
        draw.line([sx, sy, ex, ey], fill=(25, 5, 20, 100), width=3)

    # Head — darker sphere at top
    draw.ellipse([cx-18, cy-70, cx+18, cy-38], fill=(15, 0, 10, 230))

    # Glowing red eyes
    draw.ellipse([cx-12, cy-58, cx-5, cy-51], fill=(220, 30, 30, 255))
    draw.ellipse([cx+5, cy-58, cx+12, cy-51], fill=(220, 30, 30, 255))
    # Eye glow
    draw.ellipse([cx-15, cy-61, cx-2, cy-48], fill=(180, 20, 20, 60))
    draw.ellipse([cx+2, cy-61, cx+15, cy-48], fill=(180, 20, 20, 60))

    # Wispy tendrils extending outward
    for i in range(12):
        angle = random.uniform(0, math.pi * 2)
        length = random.randint(30, 70)
        sx = cx + int(math.cos(angle) * 20)
        sy = cy + int(math.sin(angle) * 10)
        ex = sx + int(math.cos(angle) * length)
        ey = sy + int(math.sin(angle) * length)
        alpha = random.randint(40, 90)
        draw.line([sx, sy, ex, ey], fill=(40, 10, 30, alpha), width=2)

    # Corrupt aura — reddish glow around figure
    aura = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    aura_draw = ImageDraw.Draw(aura)
    aura_draw.ellipse([cx-50, cy-80, cx+50, cy+60], fill=(120, 15, 30, 25))
    aura = aura.filter(ImageFilter.GaussianBlur(radius=15))
    img = Image.alpha_composite(aura, img)

    add_noise(img, 12)
    return img


def generate_stone_golem():
    """Stone Golem — hulking rocky humanoid, earthy browns and grays."""
    img = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = WORK_SIZE // 2, WORK_SIZE // 2

    # Ground shadow
    draw.ellipse([cx-55, cy+55, cx+55, cy+80], fill=(30, 25, 20, 100))

    # Legs — two thick columns
    for lx in [-22, 22]:
        for i in range(5):
            t = i / 4.0
            y = cy + 20 + int(t * 40)
            shade = int(90 + random.randint(-15, 15))
            draw.rectangle([cx+lx-14, y-5, cx+lx+14, y+8],
                          fill=(shade, shade-10, shade-20, 240))

    # Torso — massive rectangular boulder
    for i in range(6):
        t = i / 5.0
        y = cy - 30 + int(t * 55)
        w = int(48 - abs(t - 0.3) * 20)
        shade = int(100 + random.randint(-20, 20))
        g = shade - 15
        b = shade - 25
        draw.rectangle([cx-w, y-6, cx+w, y+6], fill=(shade, g, b, 240))

    # Boulder texture — random cracks and spots
    for _ in range(30):
        px = cx + random.randint(-40, 40)
        py = cy + random.randint(-30, 50)
        size = random.randint(3, 10)
        shade = random.randint(60, 130)
        draw.ellipse([px-size, py-size, px+size, py+size],
                    fill=(shade, shade-10, shade-20, 180))

    # Crack lines
    for _ in range(8):
        sx = cx + random.randint(-35, 35)
        sy = cy + random.randint(-25, 40)
        points = [(sx, sy)]
        for _ in range(random.randint(2, 4)):
            sx += random.randint(-15, 15)
            sy += random.randint(-10, 10)
            points.append((sx, sy))
        draw.line(points, fill=(40, 30, 25, 200), width=2)

    # Arms — thick rocky appendages
    for side in [-1, 1]:
        for i in range(4):
            t = i / 3.0
            ax = cx + side * (45 + int(t * 15))
            ay = cy - 15 + int(t * 35)
            shade = int(85 + random.randint(-15, 15))
            draw.ellipse([ax-12, ay-10, ax+12, ay+10],
                        fill=(shade, shade-10, shade-20, 230))

    # Fists — large rounded boulders at arm ends
    for side in [-1, 1]:
        fx = cx + side * 60
        fy = cy + 25
        shade = int(95 + random.randint(-10, 10))
        draw.ellipse([fx-16, fy-14, fx+16, fy+14],
                    fill=(shade, shade-10, shade-22, 245))

    # Head — smaller boulder on top
    draw.ellipse([cx-22, cy-60, cx+22, cy-25], fill=(110, 95, 75, 245))
    # Rocky texture on head
    for _ in range(8):
        px = cx + random.randint(-15, 15)
        py = cy - 55 + random.randint(0, 25)
        draw.ellipse([px-4, py-4, px+4, py+4],
                    fill=(random.randint(70, 120), random.randint(60, 100),
                          random.randint(50, 80), 200))

    # Eyes — dim orange glow (feral element)
    draw.ellipse([cx-14, cy-50, cx-6, cy-42], fill=(200, 140, 40, 240))
    draw.ellipse([cx+6, cy-50, cx+14, cy-42], fill=(200, 140, 40, 240))

    # Moss patches — green spots
    for _ in range(6):
        px = cx + random.randint(-35, 35)
        py = cy + random.randint(-20, 30)
        size = random.randint(4, 8)
        draw.ellipse([px-size, py-size, px+size, py+size],
                    fill=(40, 80 + random.randint(0, 30), 35, 120))

    add_noise(img, 18)
    return img


def generate_will_o_wisp():
    """Will-o-Wisp — ethereal floating flame, cool blues and purples."""
    img = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = WORK_SIZE // 2, WORK_SIZE // 2 + 10

    # Outer glow — large soft aura
    glow = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    # Multiple layers of glow
    for radius, alpha, color in [
        (60, 15, (80, 60, 180)),
        (45, 25, (100, 80, 200)),
        (30, 40, (120, 100, 220)),
        (20, 60, (150, 130, 240)),
    ]:
        glow_draw.ellipse([cx-radius, cy-radius, cx+radius, cy+radius],
                         fill=(*color, alpha))

    glow = glow.filter(ImageFilter.GaussianBlur(radius=12))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # Core flame body — teardrop shape
    # Build with overlapping ellipses tapering upward
    for i in range(10):
        t = i / 9.0
        w = int(18 - t * 12)
        y_off = int(-t * 50)
        alpha = int(220 - t * 100)
        # Color gradient: white core → blue → purple at edges
        r = int(200 - t * 130)
        g = int(210 - t * 150)
        b = int(255 - t * 40)
        draw.ellipse([cx-w, cy+y_off-8, cx+w, cy+y_off+8],
                     fill=(r, g, b, alpha))

    # Bright white-blue core
    draw.ellipse([cx-8, cy-5, cx+8, cy+10], fill=(220, 230, 255, 240))
    draw.ellipse([cx-4, cy-2, cx+4, cy+5], fill=(245, 248, 255, 255))

    # Flickering flame wisps — curving tendrils upward
    for i in range(6):
        angle = random.uniform(-1.0, 1.0)
        length = random.randint(25, 55)
        sx = cx + random.randint(-8, 8)
        sy = cy - 10
        points = [(sx, sy)]
        for j in range(8):
            t = j / 7.0
            px = sx + int(math.sin(angle + t * 2) * (10 + t * 15))
            py = sy - int(t * length)
            points.append((px, py))
        alpha = random.randint(60, 140)
        r = random.randint(100, 180)
        b = random.randint(180, 255)
        draw.line(points, fill=(r, 80, b, alpha), width=2)

    # Small orbiting sparkles
    for i in range(8):
        angle = i * math.pi / 4 + random.uniform(-0.3, 0.3)
        dist = random.randint(25, 45)
        px = cx + int(math.cos(angle) * dist)
        py = cy + int(math.sin(angle) * dist * 0.7) - 10
        size = random.randint(2, 4)
        draw.ellipse([px-size, py-size, px+size, py+size],
                    fill=(180, 170, 255, random.randint(100, 200)))

    # Face suggestion — two small bright dots for eyes
    draw.ellipse([cx-6, cy-4, cx-2, cy+1], fill=(255, 255, 255, 200))
    draw.ellipse([cx+2, cy-4, cx+6, cy+1], fill=(255, 255, 255, 200))

    add_noise(img, 8)
    return img


def generate_dark_acolyte():
    """Dark Acolyte — hooded robed figure with dark energy, deep purples."""
    img = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = WORK_SIZE // 2, WORK_SIZE // 2

    # Dark energy aura
    aura = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    aura_draw = ImageDraw.Draw(aura)
    aura_draw.ellipse([cx-55, cy-70, cx+55, cy+55], fill=(60, 15, 70, 30))
    aura = aura.filter(ImageFilter.GaussianBlur(radius=10))
    img = Image.alpha_composite(img, aura)
    draw = ImageDraw.Draw(img)

    # Ground shadow
    draw.ellipse([cx-40, cy+50, cx+40, cy+70], fill=(15, 5, 20, 100))

    # Robe body — flowing dark shape, wider at bottom
    for i in range(12):
        t = i / 11.0
        y = cy - 50 + int(t * 110)
        w = int(18 + t * 30)
        shade = int(25 + t * 15)
        purple = int(10 + t * 20)
        draw.ellipse([cx-w, y-6, cx+w, y+6],
                     fill=(shade, shade-8, shade+purple, 230))

    # Robe folds — vertical lines
    for offset in [-15, -5, 5, 15]:
        for i in range(6):
            y = cy - 10 + i * 15
            shade = random.randint(20, 45)
            draw.line([cx+offset, y, cx+offset+random.randint(-3, 3), y+12],
                     fill=(shade, shade-5, shade+15, 150), width=2)

    # Hood — deep cowl
    draw.ellipse([cx-25, cy-68, cx+25, cy-30], fill=(20, 12, 28, 245))
    # Hood shadow interior
    draw.ellipse([cx-18, cy-58, cx+18, cy-35], fill=(8, 2, 12, 250))

    # Eyes glowing from within hood — sinister purple
    draw.ellipse([cx-10, cy-52, cx-4, cy-46], fill=(160, 50, 200, 240))
    draw.ellipse([cx+4, cy-52, cx+10, cy-46], fill=(160, 50, 200, 240))
    # Eye glow
    draw.ellipse([cx-13, cy-55, cx-1, cy-43], fill=(120, 30, 160, 50))
    draw.ellipse([cx+1, cy-55, cx+13, cy-43], fill=(120, 30, 160, 50))

    # Hands reaching out — bony, dark
    for side in [-1, 1]:
        hx = cx + side * 35
        hy = cy - 5
        # Wrist
        draw.ellipse([hx-6, hy-4, hx+6, hy+4], fill=(50, 35, 45, 220))
        # Fingers
        for fi in range(4):
            angle = side * (0.3 + fi * 0.15)
            fx = hx + int(math.cos(angle) * side * 15)
            fy = hy - 5 + fi * 3
            draw.line([hx, hy, fx, fy], fill=(45, 30, 40, 200), width=2)

    # Dark energy orb between hands
    orb = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    orb_draw = ImageDraw.Draw(orb)
    orb_draw.ellipse([cx-14, cy-18, cx+14, cy+8], fill=(80, 20, 100, 150))
    orb_draw.ellipse([cx-8, cy-12, cx+8, cy+2], fill=(120, 40, 150, 200))
    orb_draw.ellipse([cx-4, cy-8, cx+4, cy-2], fill=(180, 80, 220, 230))
    orb = orb.filter(ImageFilter.GaussianBlur(radius=3))
    img = Image.alpha_composite(img, orb)
    draw = ImageDraw.Draw(img)

    # Floating dark particles
    for _ in range(15):
        px = cx + random.randint(-50, 50)
        py = cy + random.randint(-65, 50)
        size = random.randint(1, 3)
        draw.ellipse([px-size, py-size, px+size, py+size],
                    fill=(80, 20, 90, random.randint(80, 180)))

    add_noise(img, 10)
    return img


def generate_corrupted_seraph():
    """Corrupted Seraph — fallen angel, twisted dark wings, boss creature.
    Inspired by Ezekiel's card art but darker, corrupted."""
    img = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = WORK_SIZE // 2, WORK_SIZE // 2

    # Ominous background aura — red/black
    aura = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    aura_draw = ImageDraw.Draw(aura)
    aura_draw.ellipse([cx-80, cy-85, cx+80, cy+70], fill=(80, 10, 15, 30))
    aura_draw.ellipse([cx-60, cy-70, cx+60, cy+50], fill=(60, 5, 20, 25))
    aura = aura.filter(ImageFilter.GaussianBlur(radius=15))
    img = Image.alpha_composite(img, aura)
    draw = ImageDraw.Draw(img)

    # Wings — large, tattered, dark with red-tipped feathers
    for side in [-1, 1]:
        # Wing structure — multiple feather layers
        for layer in range(5):
            t = layer / 4.0
            wing_spread = 70 + int(t * 15)
            wing_y_start = cy - 55 + int(t * 15)

            for fi in range(8):
                ft = fi / 7.0
                # Feather angle fans outward
                angle = side * (0.4 + ft * 0.9) - 0.2
                length = int(wing_spread * (1.0 - ft * 0.3))

                sx = cx + side * 15
                sy = wing_y_start
                ex = sx + int(math.cos(angle) * side * length)
                ey = sy - int(math.sin(angle + 0.5) * length * 0.6)

                # Color: dark base with crimson tips
                base_shade = int(25 + t * 20)
                tip_r = int(100 + ft * 80)
                tip_g = int(10 + ft * 5)
                tip_b = int(15 + ft * 10)

                draw.line([sx, sy, ex, ey],
                         fill=(base_shade + 20, base_shade, base_shade + 5, 200),
                         width=4 - layer)
                # Feather tip
                draw.ellipse([ex-4, ey-3, ex+4, ey+3],
                            fill=(tip_r, tip_g, tip_b, 180))

    # Body — humanoid torso, once-golden now tarnished
    for i in range(8):
        t = i / 7.0
        y = cy - 35 + int(t * 80)
        w = int(22 - abs(t - 0.4) * 15)
        # Tarnished gold → dark
        r = int(80 - t * 30)
        g = int(60 - t * 25)
        b = int(40 - t * 20)
        draw.ellipse([cx-w, y-5, cx+w, y+5], fill=(r, g, b, 235))

    # Armor fragments — corrupted plate
    for ay in [cy-25, cy-10, cy+5]:
        aw = random.randint(15, 22)
        shade = random.randint(50, 80)
        draw.rectangle([cx-aw, ay-4, cx+aw, ay+4],
                       fill=(shade, shade-15, shade-20, 200))
        # Corruption veins on armor
        for _ in range(3):
            vx = cx + random.randint(-aw+3, aw-3)
            draw.line([vx, ay-3, vx+random.randint(-5, 5), ay+3],
                     fill=(150, 20, 30, 160), width=1)

    # Head with broken halo
    draw.ellipse([cx-15, cy-55, cx+15, cy-28], fill=(70, 55, 45, 240))

    # Broken halo — arc with gap
    for angle_deg in range(-60, 240, 5):
        if 80 < angle_deg < 130:  # gap in halo
            continue
        angle = math.radians(angle_deg)
        hx = cx + int(math.cos(angle) * 22)
        hy = (cy - 42) - int(math.sin(angle) * 10)
        # Flickering between gold and dark
        if random.random() > 0.3:
            draw.ellipse([hx-2, hy-2, hx+2, hy+2],
                        fill=(180, 150, 40, 200))
        else:
            draw.ellipse([hx-2, hy-2, hx+2, hy+2],
                        fill=(60, 20, 20, 200))

    # Eyes — one pure, one corrupted
    draw.ellipse([cx-10, cy-46, cx-4, cy-40], fill=(220, 200, 100, 240))  # fading gold
    draw.ellipse([cx+4, cy-46, cx+10, cy-40], fill=(200, 25, 25, 250))    # corrupted red

    # Corruption veins spreading from body
    for _ in range(10):
        angle = random.uniform(0, math.pi * 2)
        sx = cx + int(math.cos(angle) * 15)
        sy = cy - 10 + int(math.sin(angle) * 20)
        length = random.randint(15, 40)
        points = [(sx, sy)]
        for j in range(4):
            sx += int(math.cos(angle) * length / 4 + random.randint(-5, 5))
            sy += int(math.sin(angle) * length / 4 + random.randint(-5, 5))
            points.append((sx, sy))
        draw.line(points, fill=(140, 15, 25, 120), width=2)

    # Dripping corruption from wing tips
    for side in [-1, 1]:
        for i in range(4):
            dx = cx + side * random.randint(50, 75)
            dy = cy + random.randint(-10, 30)
            for j in range(random.randint(3, 6)):
                draw.ellipse([dx-2, dy+j*5, dx+2, dy+j*5+4],
                            fill=(100, 10, 20, 150 - j*20))

    add_noise(img, 14)
    return img


def save_sprite(img, name, battle_dir, portrait_dir):
    """Save at battle (96x96) and portrait (128x128) sizes."""
    # Battle size
    battle = img.resize((BATTLE_SIZE, BATTLE_SIZE), Image.LANCZOS)
    battle = battle.convert("RGB")
    posterize_5bit(battle)
    battle.save(os.path.join(battle_dir, f"{name}.png"), "PNG")

    # Portrait size
    portrait = img.resize((PORTRAIT_SIZE, PORTRAIT_SIZE), Image.LANCZOS)
    portrait = portrait.convert("RGB")
    posterize_5bit(portrait)
    portrait.save(os.path.join(portrait_dir, f"{name}.png"), "PNG")

    print(f"  {name}: battle={BATTLE_SIZE}x{BATTLE_SIZE}, portrait={PORTRAIT_SIZE}x{PORTRAIT_SIZE}")


def main():
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    battle_dir = os.path.join(base, "assets", "sprites", "battle")
    portrait_dir = os.path.join(base, "assets", "sprites", "portraits")

    os.makedirs(battle_dir, exist_ok=True)
    os.makedirs(portrait_dir, exist_ok=True)

    print("Generating original creature sprites...")

    creatures = [
        ("shade", generate_shade),
        ("stone_golem", generate_stone_golem),
        ("will_o_wisp", generate_will_o_wisp),
        ("dark_acolyte", generate_dark_acolyte),
        ("corrupted_seraph", generate_corrupted_seraph),
    ]

    for name, gen_func in creatures:
        img = gen_func()
        save_sprite(img, name, battle_dir, portrait_dir)

    print()
    print(f"Done! {len(creatures)} original creature sprites generated.")


if __name__ == "__main__":
    main()
