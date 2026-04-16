"""
Process card game art into PS1-style battle sprites and portraits.

Reads from: assets/sprites/card_originals/
Writes to:  assets/sprites/battle/       (96x96, posterized)
            assets/sprites/portraits/    (128x128, posterized)

Original files are never modified.
"""

from PIL import Image, ImageFilter, ImageEnhance
import os
import math

# Card number -> creature name mapping (monsters only; spells get processed too for completeness)
CARD_NAMES = {
    1: "pipers_boot",
    2: "amygdala",
    3: "caphilim",
    4: "silent_sleeper",
    5: "interrogations_in_dreams",  # spell
    6: "proud_boys",                # spell
    7: "nisoro",
    8: "eotentos",
    9: "cecil",
    10: "ezekiel",
    11: "beltel",
    12: "miasmic_prison",           # spell
    13: "deathstroke",              # spell
    14: "flesh_eating_swarm",
    15: "plural_powers",            # spell
    16: "torchured_turtle",
    17: "holy_diver",
    18: "heartfelt_gratitude",      # spell
    19: "jormundangr",
    20: "serpentine_reanimator",
    21: "legendary_pika",
    22: "tucked_into_dead",         # spell
    23: "mask_of_accurse",          # spell (equip)
    24: "cigrim",
    25: "absorbing_idol",
    26: "swirling_effigy",
    27: "eye_of_balter",            # spell
    28: "manna",                    # spell
    29: "mangled_mixbreed",
    30: "tomb_tomes",
    31: "a_free_lunch",             # spell
}

# Cards that are monsters (used in RPG bestiary)
MONSTER_CARDS = {1, 2, 3, 4, 7, 8, 9, 10, 11, 14, 16, 17, 19, 20, 21, 24, 25, 26, 29, 30}

BATTLE_SIZE = 96
PORTRAIT_SIZE = 128
COLOR_DEPTH_BITS = 5  # 5-bit = 32 levels per channel, matching PS1 shader


def center_crop_square(img):
    """Crop the largest centered square from the image."""
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    return img.crop((left, top, left + side, top + side))


def posterize_5bit(img):
    """Reduce to 5-bit color depth (32 levels per channel) to match PS1 shader."""
    pixels = img.load()
    w, h = img.size
    levels = 2 ** COLOR_DEPTH_BITS  # 32
    step = 256 / levels  # 8

    for y in range(h):
        for x in range(w):
            r, g, b = pixels[x, y][:3]
            r = int(math.floor(r / step) * step + step / 2)
            g = int(math.floor(g / step) * step + step / 2)
            b = int(math.floor(b / step) * step + step / 2)
            r = min(255, max(0, r))
            g = min(255, max(0, g))
            b = min(255, max(0, b))
            pixels[x, y] = (r, g, b)
    return img


def process_card(input_path, battle_path, portrait_path, name):
    """Process a single card image into battle sprite and portrait."""
    img = Image.open(input_path).convert("RGB")

    # Center crop to square
    cropped = center_crop_square(img)

    # Slightly boost contrast to pop against dark battle backgrounds
    enhancer = ImageEnhance.Contrast(cropped)
    cropped = enhancer.enhance(1.15)

    # Battle sprite: 96x96
    battle = cropped.resize((BATTLE_SIZE, BATTLE_SIZE), Image.LANCZOS)
    battle = posterize_5bit(battle)
    battle.save(battle_path, "PNG")

    # Portrait: 128x128 (for compendium)
    portrait = cropped.resize((PORTRAIT_SIZE, PORTRAIT_SIZE), Image.LANCZOS)
    portrait = posterize_5bit(portrait)
    portrait.save(portrait_path, "PNG")

    print(f"  {name}: battle={BATTLE_SIZE}x{BATTLE_SIZE}, portrait={PORTRAIT_SIZE}x{PORTRAIT_SIZE}")


def main():
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    originals_dir = os.path.join(base, "assets", "sprites", "card_originals")
    battle_dir = os.path.join(base, "assets", "sprites", "battle")
    portrait_dir = os.path.join(base, "assets", "sprites", "portraits")

    os.makedirs(battle_dir, exist_ok=True)
    os.makedirs(portrait_dir, exist_ok=True)

    print("Processing card art into PS1-style sprites...")
    print(f"  Source: {originals_dir}")
    print(f"  Battle output: {battle_dir}")
    print(f"  Portrait output: {portrait_dir}")
    print()

    monster_count = 0
    spell_count = 0

    for card_num in sorted(CARD_NAMES.keys()):
        name = CARD_NAMES[card_num]
        input_file = os.path.join(originals_dir, f"{card_num}.png")

        if not os.path.exists(input_file):
            print(f"  SKIP {card_num} ({name}): file not found")
            continue

        battle_file = os.path.join(battle_dir, f"{name}.png")
        portrait_file = os.path.join(portrait_dir, f"{name}.png")

        is_monster = card_num in MONSTER_CARDS
        label = "monster" if is_monster else "spell"

        process_card(input_file, battle_file, portrait_file, f"{name} [{label}]")

        if is_monster:
            monster_count += 1
        else:
            spell_count += 1

    print()
    print(f"Done! {monster_count} monster sprites + {spell_count} spell art processed.")
    print(f"Battle sprites: {battle_dir}")
    print(f"Portraits: {portrait_dir}")


if __name__ == "__main__":
    main()
