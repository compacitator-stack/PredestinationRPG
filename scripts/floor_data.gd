extends Node

## Floor definitions — map layout, encounters, NPCs, boss, and metadata.
## Autoloaded as "FloorData".

# Tile types:
# 0 = walkable floor
# 1 = solid wall
# 2 = altar (save point)
# 3 = NPC (walkable, interact with E)
# 4 = stairs (floor transition, walkable)
# 5 = boss trigger (walkable, one-time scripted encounter)

const WALKABLE_TILES := [0, 2, 3, 4, 5]

# Current floor index (0-based)
var current_floor: int = 0
var boss_defeated: Dictionary = {}  # floor_index -> true


func get_floor(index: int) -> Dictionary:
	match index:
		0: return _floor_1_shattered_cathedral()
		1: return _floor_2_stub()
		_: return _floor_1_shattered_cathedral()


func mark_boss_defeated(floor_index: int) -> void:
	boss_defeated[floor_index] = true


func is_boss_defeated(floor_index: int) -> bool:
	return boss_defeated.get(floor_index, false)


# ==========================================================================
#  FLOOR 1 — THE SHATTERED CATHEDRAL
# ==========================================================================

func _floor_1_shattered_cathedral() -> Dictionary:
	# 22 wide x 20 tall
	# Key areas:
	#   - Entrance vestibule (south)    — spawn point, wounded Celestialite NPC
	#   - Nave (central corridor)       — main path north, torch-lit
	#   - West chapel                   — small side room, Will-o-Wisps
	#   - East cloister                 — longer side path, Seer NPC
	#   - Altar room (north-center)     — save altar before boss
	#   - Ezekiel's threshold (north)   — NPC warning, then boss door
	#   - Boss chamber (far north)      — Corrupted Seraph boss tile
	#   - Hidden crypt (east)           — dead end with altar, optional
	#   - Stairs down (behind boss)     — to Floor 2
	#
	# Legend: 0=floor, 1=wall, 2=altar, 3=NPC, 4=stairs, 5=boss

	var rows: Array[PackedByteArray] = [
		#  0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20 21
		PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]),  # row 0
		PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 4, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1]),  # row 1  — stairs behind boss
		PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 5, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1]),  # row 2  — boss tile
		PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1]),  # row 3  — boss chamber
		PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1]),  # row 4  — narrow door
		PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 3, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1]),  # row 5  — Ezekiel NPC (x=11, centered)
		PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1]),  # row 6  — threshold room
		PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1]),  # row 7  — narrow passage
		PackedByteArray([1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1]),  # row 8  — altar room + east corridor
		PackedByteArray([1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 1]),  # row 9  — walls
		PackedByteArray([1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1]),  # row 10 — west chapel + east cloister
		PackedByteArray([1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1, 0, 3, 1, 1]),  # row 11 — west chapel open + Seer NPC
		PackedByteArray([1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1]),  # row 12 — west chapel
		PackedByteArray([1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 1]),  # row 13 — walls
		PackedByteArray([1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 1]),  # row 14 — nave + hidden crypt altar (shifted to x=18)
		PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1]),  # row 15
		PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1]),  # row 16 — entrance vestibule
		PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 3, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 1]),  # row 17 — wounded Celestialite NPC (x=10, beside pillar)
		PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1]),  # row 18 — spawn area
		PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]),  # row 19
	]

	return {
		"name": "The Shattered Cathedral",
		"map": rows,
		"spawn_pos": Vector2i(11, 18),
		"spawn_facing": 0,  # North
		"torch_positions": [
			Vector2i(11, 18),  # Spawn room
			Vector2i(11, 17),  # Near wounded Celestialite
			Vector2i(10, 14),  # Nave south
			Vector2i(12, 14),  # Nave south
			Vector2i(10, 11),  # Nave mid
			Vector2i(2, 11),   # West chapel
			Vector2i(18, 11),  # East cloister
			Vector2i(10, 8),   # Altar room
			Vector2i(11, 6),   # Threshold
			Vector2i(11, 3),   # Boss chamber
			Vector2i(19, 14),  # Hidden crypt
			Vector2i(6, 8),    # West corridor
			Vector2i(16, 8),   # East corridor
		],
		"encounter_table": [
			{ "template": "will_o_wisp", "weight": 25 },
			{ "template": "shade", "weight": 20 },
			{ "template": "pipers_boot", "weight": 15 },
			{ "template": "dark_acolyte", "weight": 10 },
			{ "template": "stone_golem", "weight": 10 },
			{ "template": "cecil", "weight": 5 },
			{ "template": "nisoro", "weight": 5 },
		],
		# Zone-based encounter tables — each sub-area of the map rolls from its own pool.
		# Empty table = safe zone (no encounters). Missing zone = fallback to floor encounter_table above.
		# zone_map below (one string per row, one char per tile) assigns each tile a zone code.
		"zones": {
			"V": [  # Vestibule — entrance, tutorial-light
				{ "template": "will_o_wisp", "weight": 40 },
				{ "template": "shade", "weight": 25 },
			],
			"N": [  # Nave — main corridor, wisp-haunted
				{ "template": "will_o_wisp", "weight": 35 },
				{ "template": "shade", "weight": 25 },
				{ "template": "cecil", "weight": 15 },
			],
			"A": [],  # Altar room — sanctuary, safe zone (no encounters)
			"T": [  # Threshold — Ezekiel's gate, golem guardians
				{ "template": "stone_golem", "weight": 40 },
				{ "template": "dark_acolyte", "weight": 25 },
				{ "template": "shade", "weight": 15 },
			],
			"B": [],  # Boss chamber — scripted fight only, no randoms
			"W": [  # West chapel — defiled, corrupt presence
				{ "template": "dark_acolyte", "weight": 30 },
				{ "template": "nisoro", "weight": 25 },
				{ "template": "shade", "weight": 20 },
			],
			"E": [  # East cloister — Seer's refuge, rare and thematic
				{ "template": "cecil", "weight": 35 },
				{ "template": "will_o_wisp", "weight": 20 },
			],
			"C": [  # Hidden crypt — Piper's Boot territory
				{ "template": "pipers_boot", "weight": 40 },
				{ "template": "dark_acolyte", "weight": 25 },
				{ "template": "nisoro", "weight": 20 },
			],
		},
		# Parallel to map rows — one character per tile. "." = wall / no zone.
		# Codes: V=vestibule, N=nave, A=altar, T=threshold, B=boss, W=west chapel, E=east cloister, C=crypt
		"zone_map": [
			"......................",  # row 0
			".........BBBBB........",  # row 1  stairs behind boss
			".........BBBBB........",  # row 2  boss tile
			".........BBBBB........",  # row 3  boss chamber
			"..........B.B.........",  # row 4  narrow door
			".........TTTTT........",  # row 5  threshold (Ezekiel)
			".........TTTTT........",  # row 6
			"..........T.T.........",  # row 7  narrow passage
			"......AAAAAAAAAAA.....",  # row 8  altar room (safe)
			"......W...N.N...E.....",  # row 9
			".WWWW.W...N.N...EEEE..",  # row 10
			".WWWWWW...N.N.....EE..",  # row 11 (Blind Seer NPC)
			".WWWW.W...N.N...EEEE..",  # row 12
			"......W...N.N...E.....",  # row 13
			"......NNNNNNNNNNNCCCC.",  # row 14 nave + hidden crypt altar
			"..........V.V.......C.",  # row 15 vestibule-nave corridor
			"..........VVV.......C.",  # row 16
			".........VVVVV......C.",  # row 17 (Wounded Celestialite NPC)
			".........VVVVV........",  # row 18 spawn
			"......................",  # row 19
		],
		"npcs": {
			Vector2i(10, 17): {
				"name": "Wounded Celestialite",
				"sprite_id": "wounded_celestialite",
				"sprite_color": Color(0.95, 0.85, 0.3),
				"dialogue": [
					{ "text": "The Celestialite lies against the broken pillar, golden light\nflickering weakly from its wounds." },
					{ "text": "\"Seer... you have come. The fracture... it spreads\nfaster than we feared.\"" },
					{ "text": "\"The Corruption leaks upward from the Heap.\nEven this cathedral — once the heart of the\nFirmament — has begun to crack.\"" },
					{ "text": "\"Your Soul Ledger... guard it well. It records\nwhat words cannot: the state of your soul.\nCorruption leaves marks that do not fade.\"" },
					{ "text": "\"The guardian of this cathedral... it was one\nof us. A Seraph. Taken by the Corruption.\nI grieve for it still.\"" },
					{ "text": "\"Press ESCAPE to open your Soul Ledger.\nPress E at golden altars to save and set Decrees.\nTalk to creatures in battle — not all wish to fight.\"" },
					{ "text": "\"Go now, Seer. What was ordained will unfold.\nWhether you accept it... that is your burden.\"" },
				],
			},
			Vector2i(19, 11): {
				"name": "The Blind Seer",
				"sprite_id": "blind_seer",
				"sprite_color": Color(0.3, 0.4, 0.9),
				"dialogue": [
					{ "text": "A robed figure sits cross-legged in the alcove,\neyes wrapped in cloth. It speaks without looking up." },
					{ "text": "\"Ah... another who walks the ordained path.\nI have seen your arrival. I have seen\nyour departure. I have not seen which door\nyou leave through.\"" },
					{ "text": "\"The Corruption offers shortcuts, Seer.\nSpend your Soul Points freely and the dark\npowers open to you. But each expenditure\nleaves a stain the Ledger never forgets.\"" },
					{ "text": "\"But I wonder... does the Ledger record\neverything? I have known Seers whose pages\nwere spotless, and whose hearts were not.\nThe two are not always the same.\"" },
					{ "text": "\"I chose to see no more. The weight of\nknowing what would happen — and being\npowerless to change it — was too great.\"" },
					{ "text": "\"But you... you still walk. That is something.\nPerhaps the ordained path is not only\nsuffering. Perhaps it is also grace.\"" },
				],
			},
			Vector2i(11, 5): {
				"name": "Ezekiel",
				"sprite_id": "ezekiel",
				"sprite_color": Color(0.95, 0.9, 0.5),
				"dialogue": [
					{ "text": "A towering figure blocks the passage north.\nGolden armor cracked but still radiant.\nEyes like burning coals." },
					{ "text": "\"Seer. I am Ezekiel of the Firmament.\nThe guardian of this cathedral has fallen\nto Corruption. It was... one of us.\"" },
					{ "text": "\"A Seraph — once the cathedral's protector.\nI remember when it sang. I remember its\nlight. What it became... I grieve for it.\"" },
					{ "text": "\"Do not mistake my grief for weakness.\nI grieve because I loved it. Not because\nI am above what happened to it. None\nof us are above it.\"" },
					{ "text": "\"I cannot enter. The Corruption repels me.\nBut you — you are mortal. You can choose\nto walk through darkness without becoming it.\"" },
					{ "text": "\"Or... you can choose to embrace it.\nThat too was ordained. The Firmament does\nnot compel. It only reveals what was\nalways going to happen.\"" },
					{ "text": "\"Set your Decrees at the altar behind me.\nPrepare well. The Corrupted Seraph will not\nshow mercy — but if you can reach it,\nperhaps mercy will reach it.\"" },
					{ "text": "\"Go, Seer. I will pray for you.\nI already know the outcome — but prayer\nis not about changing what will be.\nIt is about accepting it.\"" },
				],
			},
		},
		"boss": {
			"tile": Vector2i(10, 2),
			"creature_id": "corrupted_seraph",
			"pre_text": [
				"The air grows heavy with corruption.\nA figure floats at the center of the chamber —\nwings of tarnished gold, eyes of violet void.",
				"\"You... have come to seal the fracture?\nFool. I AM the fracture now.\nThe Firmament's light feeds my darkness.\"",
				"\"I was innocent once. I was a guardian.\nBut Innocence is weakness. Corruption\nis truth. Let me show you.\"",
			],
			"post_text": [
				"The Corrupted Seraph's form unravels,\ngolden light breaking through the violet shell.",
				"\"I... remember. The light. The purpose.\nI was... ordained to fall. And you...\nyou were ordained to witness it.\"",
				"\"Tell Ezekiel... I heard him. Even here.\nI heard him grieving. Tell him... he was\nright not to give up on me.\"",
				"The way to the lower floors lies open.",
			],
		},
		# Texture theme — defines which procedural textures to use
		"texture_theme": {
			"type": "cathedral",
			"wall_block": Color(0.5, 0.44, 0.38),     # warm grey-brown stone blocks
			"wall_mortar": Color(0.18, 0.16, 0.14),    # dark mortar
			"floor_base": Color(0.42, 0.38, 0.34),     # grey-brown flagstone
			"floor_grout": Color(0.14, 0.12, 0.11),    # dark grout
			"ceiling_base": Color(0.25, 0.22, 0.2),    # dark stone vault
			"ceiling_rib": Color(0.45, 0.4, 0.35),     # lighter rib color
		},
		# Decorative props — pillars, debris, arches, etc.
		"props": [
			# Entrance vestibule pillars
			{ "type": "pillar", "pos": Vector2i(9, 17) },
			{ "type": "pillar", "pos": Vector2i(13, 17) },
			# Nave corridor pillars
			{ "type": "pillar", "pos": Vector2i(9, 14) },
			{ "type": "pillar", "pos": Vector2i(13, 14) },
			# Altar room pillars
			{ "type": "pillar", "pos": Vector2i(7, 8) },
			{ "type": "pillar", "pos": Vector2i(13, 8) },
			# Threshold pillars
			{ "type": "pillar", "pos": Vector2i(9, 6) },
			{ "type": "pillar", "pos": Vector2i(13, 6) },
			# Arches — narrow doorways between rooms (axis = passage direction)
			{ "type": "arch", "pos": Vector2i(10, 4), "axis": "ns" },  # boss chamber door
			{ "type": "arch", "pos": Vector2i(12, 4), "axis": "ns" },  # boss chamber door
			{ "type": "arch", "pos": Vector2i(10, 7), "axis": "ns" },  # threshold entrance
			{ "type": "arch", "pos": Vector2i(12, 7), "axis": "ns" },  # threshold entrance
			{ "type": "arch", "pos": Vector2i(6, 9), "axis": "ns" },   # west wing junction
			{ "type": "arch", "pos": Vector2i(16, 9), "axis": "ns" },  # east cloister junction
			# Debris — scattered broken stone
			{ "type": "debris", "pos": Vector2i(12, 3) },   # boss chamber rubble
			{ "type": "debris", "pos": Vector2i(1, 10) },   # west chapel corner
			{ "type": "debris", "pos": Vector2i(4, 12) },   # west chapel
			{ "type": "debris", "pos": Vector2i(17, 12) },  # east cloister
			{ "type": "debris", "pos": Vector2i(15, 14) },  # nave side
			{ "type": "debris", "pos": Vector2i(20, 14) },  # hidden crypt
		],
	}


# ==========================================================================
#  FLOOR 2 — STUB (Overgrown Wilds preview)
# ==========================================================================

func _floor_2_stub() -> Dictionary:
	var rows: Array[PackedByteArray] = [
		PackedByteArray([1, 1, 1, 1, 1, 1, 1]),
		PackedByteArray([1, 0, 0, 0, 0, 0, 1]),
		PackedByteArray([1, 0, 0, 2, 0, 0, 1]),
		PackedByteArray([1, 0, 0, 0, 0, 0, 1]),
		PackedByteArray([1, 1, 1, 1, 1, 1, 1]),
	]
	return {
		"name": "The Overgrown Wilds",
		"map": rows,
		"spawn_pos": Vector2i(3, 3),
		"spawn_facing": 0,
		"torch_positions": [Vector2i(3, 2)],
		"encounter_table": [
			{ "template": "pipers_boot", "weight": 25 },
			{ "template": "stone_golem", "weight": 20 },
			{ "template": "shade", "weight": 15 },
		],
		"npcs": {},
		"boss": {},
		"texture_theme": {
			"type": "overgrown",
			"wall_stone": Color(0.45, 0.42, 0.38),     # weathered stone
			"wall_moss": Color(0.2, 0.38, 0.15),        # dark green moss
			"wall_mortar": Color(0.15, 0.14, 0.12),     # dark mortar
			"floor_stone": Color(0.38, 0.36, 0.32),     # grey flagstone
			"floor_grass": Color(0.25, 0.42, 0.15),     # grass in cracks
			"floor_grout": Color(0.12, 0.11, 0.1),      # dark grout
			"ceiling_dark": Color(0.1, 0.12, 0.08),     # deep shadow
			"ceiling_leaf": Color(0.15, 0.28, 0.1),     # dark canopy green
		},
		"props": [],
	}
