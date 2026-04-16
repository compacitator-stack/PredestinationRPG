extends RefCounted

## Procedural texture generator for PS1-style dungeon surfaces.
## Creates small, low-res textures that look authentic with affine warping.

const TEX_SIZE := 32  # 32x32 — authentic PS1 resolution

static func checkerboard(color_a: Color, color_b: Color, cell_size: int = 4) -> ImageTexture:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var checker := ((x / cell_size) + (y / cell_size)) % 2
			img.set_pixel(x, y, color_b if checker else color_a)
	return ImageTexture.create_from_image(img)

static func brick(mortar: Color, brick_color: Color, brick_w: int = 16, brick_h: int = 8, mortar_px: int = 1) -> ImageTexture:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var row := y / (brick_h + mortar_px)
			var offset := (brick_w / 2) if (row % 2 == 1) else 0
			var bx := (x + offset) % (brick_w + mortar_px)
			var by := y % (brick_h + mortar_px)
			if bx < mortar_px or by < mortar_px:
				img.set_pixel(x, y, mortar)
			else:
				var shade := 0.9 + randf() * 0.2
				var c := Color(brick_color.r * shade, brick_color.g * shade, brick_color.b * shade)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

static func cobblestone(base: Color, grout: Color, cell_count: int = 6) -> ImageTexture:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var cell_size := TEX_SIZE / cell_count
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var cx := x % cell_size
			var cy := y % cell_size
			if cx == 0 or cy == 0:
				img.set_pixel(x, y, grout)
			else:
				var shade := 0.85 + randf() * 0.3
				var c := Color(base.r * shade, base.g * shade, base.b * shade)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# =========================================================================
#  CATHEDRAL THEME TEXTURES
# =========================================================================

static func stone_blocks(block_color: Color, mortar: Color, block_w: int = 16, block_h: int = 10) -> ImageTexture:
	## Large cut-stone wall blocks — cathedral masonry with chiseled edges
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var row := y / (block_h + 1)
			var offset := (block_w / 2) if (row % 2 == 1) else 0
			var bx := (x + offset) % (block_w + 1)
			var by := y % (block_h + 1)
			if bx == 0 or by == 0:
				# Mortar line
				img.set_pixel(x, y, mortar)
			elif bx == 1 or by == 1 or bx == block_w or by == block_h:
				# Chiseled edge — slightly lighter than block
				var edge_shade := 1.05 + randf() * 0.1
				var c := Color(block_color.r * edge_shade, block_color.g * edge_shade, block_color.b * edge_shade)
				img.set_pixel(x, y, c)
			else:
				# Block face with subtle noise
				var shade := 0.92 + randf() * 0.16
				var c := Color(block_color.r * shade, block_color.g * shade, block_color.b * shade)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func flagstone(base: Color, grout: Color) -> ImageTexture:
	## Large irregular flagstone floor — cathedral floor tiles with cracked grout
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	# Two sizes of flagstone in alternating pattern
	var sizes := [10, 6, 10, 6]  # alternating column widths (sum=32)
	var row_sizes := [12, 8, 12]  # alternating row heights (sum=32)
	var cx := 0
	for si in range(sizes.size()):
		var sw: int = sizes[si]
		var cy := 0
		for ri in range(row_sizes.size()):
			var rh: int = row_sizes[ri]
			# Per-flagstone shade
			var stone_shade := 0.88 + randf() * 0.24
			for ly in range(rh):
				for lx in range(sw):
					var px: int = cx + lx
					var py: int = cy + ly
					if px >= TEX_SIZE or py >= TEX_SIZE:
						continue
					if lx == 0 or ly == 0:
						img.set_pixel(px, py, grout)
					else:
						var noise := 0.97 + randf() * 0.06
						var c := Color(
							base.r * stone_shade * noise,
							base.g * stone_shade * noise,
							base.b * stone_shade * noise
						)
						img.set_pixel(px, py, c)
			cy += rh
		cx += sw
	return ImageTexture.create_from_image(img)


static func vaulted_ceiling(base: Color, rib_color: Color) -> ImageTexture:
	## Cathedral ceiling with cross-rib vault pattern
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var half := TEX_SIZE / 2
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			# Distance from center for slight darkening toward edges
			var dx: float = abs(x - half) / float(half)
			var dy: float = abs(y - half) / float(half)
			var edge_dark: float = 1.0 - (dx + dy) * 0.12

			# Cross-rib pattern: diagonal lines from corners
			var on_rib := false
			var d1: int = abs(x - y)  # main diagonal
			var d2: int = abs(x - (TEX_SIZE - 1 - y))  # anti-diagonal
			if d1 <= 1 or d2 <= 1:
				on_rib = true
			# Center cross
			if abs(x - half) <= 0 or abs(y - half) <= 0:
				on_rib = true

			if on_rib:
				var shade := 0.95 + randf() * 0.1
				var c := Color(rib_color.r * shade, rib_color.g * shade, rib_color.b * shade)
				img.set_pixel(x, y, c)
			else:
				var shade := (0.9 + randf() * 0.15) * edge_dark
				var c := Color(base.r * shade, base.g * shade, base.b * shade)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# =========================================================================
#  OVERGROWN / WILDS THEME TEXTURES
# =========================================================================

static func mossy_stone(stone_color: Color, moss_color: Color, mortar: Color, moss_density: float = 0.35) -> ImageTexture:
	## Stone blocks with patches of moss growing in mortar lines and edges
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var bx := x % 11
			var by := y % 9
			var is_mortar := bx == 0 or by == 0

			if is_mortar:
				# Moss tends to grow in mortar lines
				if randf() < moss_density * 1.5:
					var shade := 0.85 + randf() * 0.3
					var c := Color(moss_color.r * shade, moss_color.g * shade, moss_color.b * shade)
					img.set_pixel(x, y, c)
				else:
					img.set_pixel(x, y, mortar)
			else:
				# Stone face — occasional moss patches near mortar
				var near_edge := bx <= 2 or by <= 2 or bx >= 9 or by >= 7
				if near_edge and randf() < moss_density:
					var shade := 0.8 + randf() * 0.3
					var blend := 0.4 + randf() * 0.3
					var c := Color(
						stone_color.r * (1.0 - blend) + moss_color.r * blend,
						stone_color.g * (1.0 - blend) + moss_color.g * blend,
						stone_color.b * (1.0 - blend) + moss_color.b * blend
					) * shade
					c.a = 1.0
					img.set_pixel(x, y, c)
				else:
					var shade := 0.9 + randf() * 0.2
					var c := Color(stone_color.r * shade, stone_color.g * shade, stone_color.b * shade)
					img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func grass_stone(stone_color: Color, grass_color: Color, grout: Color) -> ImageTexture:
	## Cracked flagstone with grass/weeds pushing through
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var cell_size := 8
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var cx := x % cell_size
			var cy := y % cell_size
			if cx == 0 or cy == 0:
				# Grout line — high chance of grass
				if randf() < 0.5:
					var shade := 0.7 + randf() * 0.4
					var c := Color(grass_color.r * shade, grass_color.g * shade, grass_color.b * shade)
					img.set_pixel(x, y, c)
				else:
					img.set_pixel(x, y, grout)
			else:
				# Stone with occasional cracks sprouting grass
				var is_crack := (cx == 4 and randf() < 0.3) or (cy == 4 and randf() < 0.3)
				if is_crack:
					var shade := 0.75 + randf() * 0.35
					var c := Color(grass_color.r * shade, grass_color.g * shade, grass_color.b * shade)
					img.set_pixel(x, y, c)
				else:
					var shade := 0.85 + randf() * 0.3
					var c := Color(stone_color.r * shade, stone_color.g * shade, stone_color.b * shade)
					img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func leaf_canopy(dark_color: Color, leaf_color: Color) -> ImageTexture:
	## Organic ceiling — dark with scattered leaf/vine patches and gaps of light
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var r := randf()
			if r < 0.15:
				# Light gap — slightly bright
				var shade := 1.1 + randf() * 0.3
				var c := Color(leaf_color.r * shade, leaf_color.g * shade, leaf_color.b * shade)
				c = c.clamp()
				img.set_pixel(x, y, c)
			elif r < 0.5:
				# Leaf cluster
				var shade := 0.7 + randf() * 0.4
				var c := Color(leaf_color.r * shade, leaf_color.g * shade, leaf_color.b * shade)
				img.set_pixel(x, y, c)
			else:
				# Dark background
				var shade := 0.85 + randf() * 0.25
				var c := Color(dark_color.r * shade, dark_color.g * shade, dark_color.b * shade)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
