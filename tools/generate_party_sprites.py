"""
Generate pixel art sprites for the 2 starter party members.

- player_seer: Mystic humanoid, hooded figure with staff, cool blue-purple palette
- starter_seraph: Celestialite, angelic figure with white-gold wings (uncorrupted)
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os
import random

random.seed(99)

WORK_SIZE = 192
BATTLE_SIZE = 96
PORTRAIT_SIZE = 128


def posterize_5bit(img):
    pixels = img.load()
    w, h = img.size
    step = 8
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


def add_noise(img, intensity=12):
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
                pixels[x, y] = (max(0, min(255, r+noise)), max(0, min(255, g+noise)),
                                max(0, min(255, b+noise)), a)
            else:
                r, g, b = p[:3]
                pixels[x, y] = (max(0, min(255, r+noise)), max(0, min(255, g+noise)),
                                max(0, min(255, b+noise)))
    return img


def generate_player_seer():
    """Mystic Seer — hooded figure with staff, blue-purple robes."""
    img = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = WORK_SIZE // 2, WORK_SIZE // 2

    # Subtle mystic aura
    aura = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    aura_draw = ImageDraw.Draw(aura)
    aura_draw.ellipse([cx-50, cy-65, cx+50, cy+55], fill=(60, 50, 120, 25))
    aura = aura.filter(ImageFilter.GaussianBlur(radius=10))
    img = Image.alpha_composite(img, aura)
    draw = ImageDraw.Draw(img)

    # Ground shadow
    draw.ellipse([cx-35, cy+50, cx+35, cy+68], fill=(20, 15, 30, 90))

    # Staff — held in right hand, extends above head
    staff_x = cx + 28
    draw.line([staff_x, cy-75, staff_x, cy+55], fill=(100, 70, 40, 230), width=4)
    # Staff orb at top — mystic blue glow
    orb = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    orb_draw = ImageDraw.Draw(orb)
    orb_draw.ellipse([staff_x-10, cy-85, staff_x+10, cy-65], fill=(80, 100, 200, 150))
    orb_draw.ellipse([staff_x-6, cy-81, staff_x+6, cy-69], fill=(140, 160, 240, 200))
    orb_draw.ellipse([staff_x-3, cy-78, staff_x+3, cy-72], fill=(200, 210, 255, 240))
    orb = orb.filter(ImageFilter.GaussianBlur(radius=2))
    img = Image.alpha_composite(img, orb)
    draw = ImageDraw.Draw(img)

    # Robe — flowing blue-purple shape
    for i in range(12):
        t = i / 11.0
        y = cy - 40 + int(t * 100)
        w = int(16 + t * 25)
        r = int(40 + t * 20)
        g = int(35 + t * 15)
        b = int(100 + t * 30)
        draw.ellipse([cx-w, y-5, cx+w, y+5], fill=(r, g, b, 230))

    # Robe trim — lighter edges
    for i in range(6):
        t = i / 5.0
        y = cy + 20 + int(t * 35)
        w = int(30 + t * 10)
        draw.arc([cx-w, y-4, cx+w, y+4], 0, 180, fill=(80, 70, 150, 180), width=2)

    # Hood — deep cowl, mystic blue
    draw.ellipse([cx-22, cy-58, cx+22, cy-22], fill=(35, 30, 80, 245))
    # Hood interior shadow
    draw.ellipse([cx-16, cy-50, cx+16, cy-28], fill=(15, 10, 40, 250))

    # Eyes — soft blue glow from within hood
    draw.ellipse([cx-9, cy-44, cx-4, cy-38], fill=(120, 150, 230, 220))
    draw.ellipse([cx+4, cy-44, cx+9, cy-38], fill=(120, 150, 230, 220))
    # Eye glow
    draw.ellipse([cx-11, cy-46, cx-2, cy-36], fill=(80, 100, 180, 40))
    draw.ellipse([cx+2, cy-46, cx+11, cy-36], fill=(80, 100, 180, 40))

    # Hands — visible at robe edge, reaching toward staff
    draw.ellipse([cx+18, cy+2, cx+30, cy+12], fill=(180, 150, 120, 200))
    draw.ellipse([cx-20, cy+5, cx-10, cy+14], fill=(180, 150, 120, 200))

    # Mystic symbols floating near staff orb
    for i in range(5):
        angle = i * math.pi * 2 / 5 + random.uniform(-0.3, 0.3)
        dist = random.randint(15, 25)
        px = staff_x + int(math.cos(angle) * dist)
        py = (cy - 75) + int(math.sin(angle) * dist)
        size = random.randint(1, 3)
        draw.ellipse([px-size, py-size, px+size, py+size],
                    fill=(140, 160, 255, random.randint(80, 160)))

    add_noise(img, 10)
    return img


def generate_starter_seraph():
    """Seraph — angelic figure with white-gold wings, warm Innocent palette."""
    img = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = WORK_SIZE // 2, WORK_SIZE // 2

    # Holy light aura
    aura = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    aura_draw = ImageDraw.Draw(aura)
    aura_draw.ellipse([cx-60, cy-70, cx+60, cy+50], fill=(220, 200, 120, 20))
    aura_draw.ellipse([cx-40, cy-55, cx+40, cy+35], fill=(240, 225, 150, 25))
    aura = aura.filter(ImageFilter.GaussianBlur(radius=12))
    img = Image.alpha_composite(img, aura)
    draw = ImageDraw.Draw(img)

    # Wings — white-gold, spread wide
    for side in [-1, 1]:
        for layer in range(4):
            t = layer / 3.0
            for fi in range(7):
                ft = fi / 6.0
                angle = side * (0.3 + ft * 0.8) - 0.1
                length = int((55 + t * 10) * (1.0 - ft * 0.2))

                sx = cx + side * 12
                sy = cy - 40 + int(t * 10)
                ex = sx + int(math.cos(angle) * side * length)
                ey = sy - int(math.sin(angle + 0.5) * length * 0.5)

                # White to gold gradient
                r = int(230 - ft * 30)
                g = int(220 - ft * 40)
                b = int(200 - ft * 80)
                draw.line([sx, sy, ex, ey], fill=(r, g, b, 190 - layer * 20), width=3 - layer)
                # Feather tip glow
                draw.ellipse([ex-3, ey-2, ex+3, ey+2], fill=(240, 220, 160, 150))

    # Body — simple white robe
    for i in range(10):
        t = i / 9.0
        y = cy - 30 + int(t * 80)
        w = int(15 + t * 18)
        shade = int(220 - t * 30)
        draw.ellipse([cx-w, y-5, cx+w, y+5], fill=(shade, shade-5, shade-20, 235))

    # Head — fair complexion
    draw.ellipse([cx-14, cy-50, cx+14, cy-25], fill=(225, 200, 175, 240))

    # Hair — golden
    draw.ellipse([cx-16, cy-55, cx+16, cy-35], fill=(210, 180, 90, 220))
    draw.ellipse([cx-12, cy-58, cx+12, cy-42], fill=(220, 190, 100, 200))

    # Halo — complete golden ring
    for angle_deg in range(0, 360, 4):
        angle = math.radians(angle_deg)
        hx = cx + int(math.cos(angle) * 20)
        hy = (cy - 55) - int(math.sin(angle) * 8)
        draw.ellipse([hx-2, hy-2, hx+2, hy+2], fill=(240, 210, 80, 220))

    # Eyes — warm gold
    draw.ellipse([cx-8, cy-42, cx-3, cy-36], fill=(180, 160, 80, 230))
    draw.ellipse([cx+3, cy-42, cx+8, cy-36], fill=(180, 160, 80, 230))

    # Hands clasped in prayer / healing pose
    draw.ellipse([cx-8, cy+5, cx+8, cy+18], fill=(215, 190, 165, 210))

    # Innocent light particles
    for i in range(10):
        angle = random.uniform(0, math.pi * 2)
        dist = random.randint(30, 55)
        px = cx + int(math.cos(angle) * dist)
        py = cy - 10 + int(math.sin(angle) * dist * 0.7)
        size = random.randint(1, 3)
        draw.ellipse([px-size, py-size, px+size, py+size],
                    fill=(255, 240, 180, random.randint(80, 180)))

    add_noise(img, 8)
    return img


def save_sprite(img, name, battle_dir, portrait_dir):
    battle = img.resize((BATTLE_SIZE, BATTLE_SIZE), Image.LANCZOS).convert("RGB")
    posterize_5bit(battle)
    battle.save(os.path.join(battle_dir, f"{name}.png"), "PNG")

    portrait = img.resize((PORTRAIT_SIZE, PORTRAIT_SIZE), Image.LANCZOS).convert("RGB")
    posterize_5bit(portrait)
    portrait.save(os.path.join(portrait_dir, f"{name}.png"), "PNG")

    print(f"  {name}: battle={BATTLE_SIZE}x{BATTLE_SIZE}, portrait={PORTRAIT_SIZE}x{PORTRAIT_SIZE}")


def main():
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    battle_dir = os.path.join(base, "assets", "sprites", "battle")
    portrait_dir = os.path.join(base, "assets", "sprites", "portraits")

    print("Generating starter party sprites...")

    save_sprite(generate_player_seer(), "player_seer", battle_dir, portrait_dir)
    save_sprite(generate_starter_seraph(), "starter_seraph", battle_dir, portrait_dir)

    print("\nDone! 2 starter party sprites generated.")


if __name__ == "__main__":
    main()
