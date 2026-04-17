extends Node3D

## Defines a dungeon floor as a 2D tile grid and spawns geometry at runtime.
## Tile types: 0=floor, 1=wall, 2=altar, 3=NPC, 4=stairs, 5=boss
## Loads floor data from FloorData autoload.

@export var tile_size: float = 2.0
@export var wall_height: float = 3.0
@export var eye_height: float = 1.0  # Player camera Y offset

# Materials — assigned in the scene
@export var wall_material: ShaderMaterial
@export var floor_material: ShaderMaterial
@export var ceiling_material: ShaderMaterial

# Reusable meshes created at runtime
var _wall_mesh: QuadMesh
var _floor_mesh: PlaneMesh
var _ceiling_mesh: PlaneMesh

# The map grid — each row is a PackedByteArray for efficiency
var map_data: Array[PackedByteArray] = []
var map_width: int = 0
var map_height: int = 0

# Player spawn
var spawn_pos: Vector2i = Vector2i(1, 1)
var spawn_facing: int = 0  # 0=North, 1=East, 2=South, 3=West

# Floor metadata
var floor_name: String = ""
var floor_npcs: Dictionary = {}
var floor_boss: Dictionary = {}
var floor_encounter_table: Array = []
var floor_zones: Dictionary = {}     # zone code (String) -> encounter table (Array)
var floor_zone_map: Array = []       # Array of Strings, one per row; "." = no zone
var floor_torch_positions: Array = []
var floor_texture_theme: Dictionary = {}
var floor_props: Array = []

# Tiles blocked by props (pillars, etc.) — not walkable even though tile type is floor
var blocked_tiles: Dictionary = {}  # Vector2i -> true


func _ready() -> void:
	_load_floor(FloorData.current_floor)
	_apply_textures()
	_create_meshes()
	_build_geometry()
	_place_player()
	_place_lights()
	_place_particles()


func load_floor(index: int) -> void:
	## Public method to load a specific floor (called during transitions).
	FloorData.current_floor = index
	_load_floor(index)


func _load_floor(index: int) -> void:
	blocked_tiles.clear()
	var data: Dictionary = FloorData.get_floor(index)
	floor_name = data.get("name", "Unknown")
	map_data = data.get("map", [])
	map_height = map_data.size()
	map_width = map_data[0].size() if map_height > 0 else 0
	spawn_pos = data.get("spawn_pos", Vector2i(1, 1))
	spawn_facing = data.get("spawn_facing", 0)
	floor_npcs = data.get("npcs", {})
	floor_boss = data.get("boss", {})
	floor_encounter_table = data.get("encounter_table", [])
	floor_zones = data.get("zones", {})
	floor_zone_map = data.get("zone_map", [])
	floor_torch_positions = data.get("torch_positions", [])
	floor_texture_theme = data.get("texture_theme", {})
	floor_props = data.get("props", [])


func _apply_textures() -> void:
	var TextureGen := preload("res://scripts/texture_gen.gd")
	var theme_type: String = floor_texture_theme.get("type", "cathedral")

	var wall_tex: ImageTexture
	var floor_tex: ImageTexture
	var ceil_tex: ImageTexture

	match theme_type:
		"cathedral":
			wall_tex = TextureGen.stone_blocks(
				floor_texture_theme.get("wall_block", Color(0.5, 0.44, 0.38)),
				floor_texture_theme.get("wall_mortar", Color(0.18, 0.16, 0.14)),
			)
			floor_tex = TextureGen.flagstone(
				floor_texture_theme.get("floor_base", Color(0.42, 0.38, 0.34)),
				floor_texture_theme.get("floor_grout", Color(0.14, 0.12, 0.11)),
			)
			ceil_tex = TextureGen.vaulted_ceiling(
				floor_texture_theme.get("ceiling_base", Color(0.25, 0.22, 0.2)),
				floor_texture_theme.get("ceiling_rib", Color(0.45, 0.4, 0.35)),
			)
		"overgrown":
			wall_tex = TextureGen.mossy_stone(
				floor_texture_theme.get("wall_stone", Color(0.45, 0.42, 0.38)),
				floor_texture_theme.get("wall_moss", Color(0.2, 0.38, 0.15)),
				floor_texture_theme.get("wall_mortar", Color(0.15, 0.14, 0.12)),
			)
			floor_tex = TextureGen.grass_stone(
				floor_texture_theme.get("floor_stone", Color(0.38, 0.36, 0.32)),
				floor_texture_theme.get("floor_grass", Color(0.25, 0.42, 0.15)),
				floor_texture_theme.get("floor_grout", Color(0.12, 0.11, 0.1)),
			)
			ceil_tex = TextureGen.leaf_canopy(
				floor_texture_theme.get("ceiling_dark", Color(0.1, 0.12, 0.08)),
				floor_texture_theme.get("ceiling_leaf", Color(0.15, 0.28, 0.1)),
			)
		_:
			# Fallback to original generic textures
			wall_tex = TextureGen.brick(
				Color(0.2, 0.18, 0.15),
				Color(0.55, 0.45, 0.35),
			)
			floor_tex = TextureGen.cobblestone(
				Color(0.35, 0.33, 0.3),
				Color(0.15, 0.13, 0.12),
			)
			ceil_tex = TextureGen.checkerboard(
				Color(0.22, 0.2, 0.18),
				Color(0.28, 0.25, 0.22),
				8,
			)

	wall_material.set_shader_parameter("albedo_texture", wall_tex)
	wall_material.set_shader_parameter("use_texture", true)
	wall_material.set_shader_parameter("texture_tile", Vector2(2, 2))

	floor_material.set_shader_parameter("albedo_texture", floor_tex)
	floor_material.set_shader_parameter("use_texture", true)
	floor_material.set_shader_parameter("texture_tile", Vector2(2, 2))

	ceiling_material.set_shader_parameter("albedo_texture", ceil_tex)
	ceiling_material.set_shader_parameter("use_texture", true)
	ceiling_material.set_shader_parameter("texture_tile", Vector2(2, 2))


func is_walkable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return false
	if blocked_tiles.has(pos):
		return false
	var tile: int = map_data[pos.y][pos.x]
	return tile in FloorData.WALKABLE_TILES


func get_tile_type(pos: Vector2i) -> int:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return 1  # Out of bounds = wall
	return map_data[pos.y][pos.x]


func get_zone_code(pos: Vector2i) -> String:
	## Returns zone single-char code for a tile, or "" if no zone defined.
	if pos.y < 0 or pos.y >= floor_zone_map.size():
		return ""
	var row: String = floor_zone_map[pos.y]
	if pos.x < 0 or pos.x >= row.length():
		return ""
	var c: String = row.substr(pos.x, 1)
	return "" if c == "." else c


func get_zone_encounter_table(pos: Vector2i) -> Array:
	## Returns the encounter table for the tile's zone, falling back to the floor default.
	## Returns an empty array if the tile is in a declared safe zone (e.g. altar room).
	var code := get_zone_code(pos)
	if code != "" and floor_zones.has(code):
		return floor_zones[code]
	return floor_encounter_table


func is_safe_zone(pos: Vector2i) -> bool:
	## True if the tile is in a zone explicitly declared with an empty encounter table.
	var code := get_zone_code(pos)
	return code != "" and floor_zones.has(code) and (floor_zones[code] as Array).is_empty()


func _create_meshes() -> void:
	# Wall face: zero-thickness quad, oriented facing +Z by default
	_wall_mesh = QuadMesh.new()
	_wall_mesh.size = Vector2(tile_size, wall_height)

	# Floor/ceiling per tile — small planes, subdivided for vertex lighting
	_floor_mesh = PlaneMesh.new()
	_floor_mesh.size = Vector2(tile_size, tile_size)
	_floor_mesh.subdivide_width = 2
	_floor_mesh.subdivide_depth = 2

	_ceiling_mesh = PlaneMesh.new()
	_ceiling_mesh.size = Vector2(tile_size, tile_size)
	_ceiling_mesh.subdivide_width = 2
	_ceiling_mesh.subdivide_depth = 2


func _build_geometry() -> void:
	var geo_parent := Node3D.new()
	geo_parent.name = "Geometry"
	add_child(geo_parent)

	for y in range(map_height):
		for x in range(map_width):
			var tile: int = map_data[y][x]
			if tile in FloorData.WALKABLE_TILES:
				_spawn_floor_ceiling(geo_parent, x, y)
				_spawn_walls_for_tile(geo_parent, x, y)
				if tile == 2:
					_spawn_altar_marker(geo_parent, x, y)
					blocked_tiles[Vector2i(x, y)] = true  # Altars block movement — interact by facing
				elif tile == 3:
					_spawn_npc_marker(geo_parent, x, y)
					blocked_tiles[Vector2i(x, y)] = true  # NPCs block movement — interact by facing
				elif tile == 4:
					_spawn_stairs_marker(geo_parent, x, y)
				elif tile == 5:
					_spawn_boss_marker(geo_parent, x, y)

	# Spawn decorative props from floor data
	for prop in floor_props:
		var prop_type: String = prop.get("type", "")
		var pos: Vector2i = prop.get("pos", Vector2i.ZERO)
		match prop_type:
			"pillar":
				_spawn_pillar(geo_parent, pos.x, pos.y)
				blocked_tiles[pos] = true  # Pillars block movement
			"debris":
				_spawn_debris(geo_parent, pos.x, pos.y)
			"arch":
				var axis: String = prop.get("axis", "ns")
				_spawn_arch(geo_parent, pos.x, pos.y, axis)


func _tile_center(x: int, y: int) -> Vector3:
	return Vector3(x * tile_size, 0.0, y * tile_size)


func _spawn_floor_ceiling(parent: Node3D, x: int, y: int) -> void:
	var center := _tile_center(x, y)

	# Floor
	var floor_inst := MeshInstance3D.new()
	floor_inst.mesh = _floor_mesh
	floor_inst.material_override = floor_material
	floor_inst.position = center
	parent.add_child(floor_inst)

	# Ceiling
	var ceil_inst := MeshInstance3D.new()
	ceil_inst.mesh = _ceiling_mesh
	ceil_inst.material_override = ceiling_material
	ceil_inst.position = center + Vector3(0, wall_height, 0)
	ceil_inst.rotation_degrees.x = 180.0
	parent.add_child(ceil_inst)


func _spawn_walls_for_tile(parent: Node3D, x: int, y: int) -> void:
	var center := _tile_center(x, y)
	var half := tile_size / 2.0
	var wall_y := wall_height / 2.0

	# Walls are rendered against the raw map (tile-type 1 or out-of-bounds).
	# Do NOT use is_walkable() here — it returns false for NPC/altar/pillar
	# tiles (they're in blocked_tiles), but those are open spaces visually,
	# interacted with by facing. Using is_walkable() would render a
	# "paper-thin wall" between the player and any NPC/altar tile that
	# happened to be processed earlier in the build loop.

	# North (y-1)
	if _is_wall_tile(x, y - 1):
		var wall := MeshInstance3D.new()
		wall.mesh = _wall_mesh
		wall.material_override = wall_material
		wall.position = center + Vector3(0, wall_y, -half)
		parent.add_child(wall)

	# South (y+1)
	if _is_wall_tile(x, y + 1):
		var wall := MeshInstance3D.new()
		wall.mesh = _wall_mesh
		wall.material_override = wall_material
		wall.position = center + Vector3(0, wall_y, half)
		wall.rotation_degrees.y = 180.0
		parent.add_child(wall)

	# West (x-1)
	if _is_wall_tile(x - 1, y):
		var wall := MeshInstance3D.new()
		wall.mesh = _wall_mesh
		wall.material_override = wall_material
		wall.position = center + Vector3(-half, wall_y, 0)
		wall.rotation_degrees.y = 90.0
		parent.add_child(wall)

	# East (x+1)
	if _is_wall_tile(x + 1, y):
		var wall := MeshInstance3D.new()
		wall.mesh = _wall_mesh
		wall.material_override = wall_material
		wall.position = center + Vector3(half, wall_y, 0)
		wall.rotation_degrees.y = -90.0
		parent.add_child(wall)


func _is_wall_tile(x: int, y: int) -> bool:
	if x < 0 or x >= map_width or y < 0 or y >= map_height:
		return true
	return not (map_data[y][x] in FloorData.WALKABLE_TILES)


func _spawn_altar_marker(parent: Node3D, x: int, y: int) -> void:
	var center := _tile_center(x, y)

	# Stone altar base — a wide, low box
	var base_inst := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(tile_size * 0.6, 0.35, tile_size * 0.4)
	base_inst.mesh = base_mesh
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.4, 0.35, 0.3)
	base_inst.material_override = base_mat
	base_inst.position = center + Vector3(0, 0.175, 0)
	parent.add_child(base_inst)

	# Altar top slab — slightly wider, thinner
	var top_inst := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(tile_size * 0.65, 0.08, tile_size * 0.45)
	top_inst.mesh = top_mesh
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.55, 0.48, 0.38)
	top_inst.material_override = top_mat
	top_inst.position = center + Vector3(0, 0.39, 0)
	parent.add_child(top_inst)

	# Golden glow plane on top
	var glow_quad := MeshInstance3D.new()
	var glow_mesh := PlaneMesh.new()
	glow_mesh.size = Vector2(tile_size * 0.5, tile_size * 0.3)
	glow_quad.mesh = glow_mesh
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.95, 0.8, 0.3, 0.7)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.9, 0.7, 0.2)
	glow_mat.emission_energy_multiplier = 0.8
	glow_quad.material_override = glow_mat
	glow_quad.position = center + Vector3(0, 0.44, 0)
	parent.add_child(glow_quad)

	# Warm light
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.4)
	light.light_energy = 2.5
	light.omni_range = 4.0
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	light.position = center + Vector3(0, wall_height * 0.7, 0)
	parent.add_child(light)


func _spawn_npc_marker(parent: Node3D, x: int, y: int) -> void:
	var center := _tile_center(x, y)
	var pos := Vector2i(x, y)
	var npc_data: Dictionary = floor_npcs.get(pos, {})
	var npc_color: Color = npc_data.get("sprite_color", Color(0.5, 0.8, 1.0))
	var sprite_id: String = npc_data.get("sprite_id", "")

	# Billboard sprite — loads NPC exploration sprite, always faces camera
	var quad := MeshInstance3D.new()
	var qmesh := QuadMesh.new()
	qmesh.size = Vector2(tile_size * 0.5, wall_height * 0.55)
	quad.mesh = qmesh
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	# Try to load sprite texture
	var tex_path := "res://assets/sprites/npcs/%s.png" % sprite_id
	var tex: Texture2D = null
	if sprite_id != "" and ResourceLoader.exists(tex_path):
		tex = load(tex_path)

	if tex:
		mat.albedo_texture = tex
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.1
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	else:
		# Fallback to colored quad if no sprite found
		mat.albedo_color = npc_color

	mat.emission_enabled = true
	mat.emission = npc_color * 0.3
	mat.emission_energy_multiplier = 0.3
	quad.material_override = mat
	quad.position = center + Vector3(0, wall_height * 0.32, 0)
	parent.add_child(quad)

	# Soft glow light at NPC
	var light := OmniLight3D.new()
	light.light_color = npc_color
	light.light_energy = 1.5
	light.omni_range = 3.0
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	light.position = center + Vector3(0, wall_height * 0.5, 0)
	parent.add_child(light)


func _spawn_stairs_marker(parent: Node3D, x: int, y: int) -> void:
	var center := _tile_center(x, y)

	# Glowing floor circle — base of portal
	var floor_quad := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(tile_size * 0.75, tile_size * 0.75)
	floor_quad.mesh = floor_mesh
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.15, 0.5, 0.7, 0.5)
	floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	floor_mat.emission_enabled = true
	floor_mat.emission = Color(0.1, 0.4, 0.6)
	floor_mat.emission_energy_multiplier = 0.6
	floor_quad.material_override = floor_mat
	floor_quad.position = center + Vector3(0, 0.02, 0)
	parent.add_child(floor_quad)

	# Portal ring — vertical quads arranged in a circle
	var ring_segments := 12
	var ring_radius: float = tile_size * 0.32
	var ring_height: float = wall_height * 0.6
	for i in range(ring_segments):
		var angle: float = float(i) / float(ring_segments) * TAU
		var ring_quad := MeshInstance3D.new()
		var rq_mesh := QuadMesh.new()
		rq_mesh.size = Vector2(0.12, ring_height)
		ring_quad.mesh = rq_mesh
		var ring_mat := StandardMaterial3D.new()
		# Color varies around the ring — cyan to blue
		var t: float = float(i) / float(ring_segments)
		var r_col: float = 0.1 + t * 0.15
		var g_col: float = 0.4 + sin(t * TAU) * 0.2
		var b_col: float = 0.7 + cos(t * TAU) * 0.15
		ring_mat.albedo_color = Color(r_col, g_col, b_col, 0.6)
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.emission_enabled = true
		ring_mat.emission = Color(r_col * 0.8, g_col * 0.8, b_col * 0.8)
		ring_mat.emission_energy_multiplier = 1.0
		ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring_quad.material_override = ring_mat
		var qx: float = cos(angle) * ring_radius
		var qz: float = sin(angle) * ring_radius
		ring_quad.position = center + Vector3(qx, ring_height * 0.5 + 0.02, qz)
		ring_quad.rotation.y = angle + PI * 0.5  # face tangent
		parent.add_child(ring_quad)

	# Top ring cap — horizontal ring of small quads
	for i in range(ring_segments):
		var angle: float = float(i) / float(ring_segments) * TAU
		var cap := MeshInstance3D.new()
		var cap_mesh := QuadMesh.new()
		cap_mesh.size = Vector2(0.2, 0.15)
		cap.mesh = cap_mesh
		var cap_mat := StandardMaterial3D.new()
		cap_mat.albedo_color = Color(0.2, 0.6, 0.9, 0.5)
		cap_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cap_mat.emission_enabled = true
		cap_mat.emission = Color(0.2, 0.5, 0.8)
		cap_mat.emission_energy_multiplier = 0.8
		cap_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		cap.material_override = cap_mat
		var cx2: float = cos(angle) * ring_radius
		var cz: float = sin(angle) * ring_radius
		cap.position = center + Vector3(cx2, ring_height + 0.02, cz)
		cap.rotation_degrees.x = 90.0
		cap.rotation.y = angle
		parent.add_child(cap)

	# Central swirl — a few angled quads inside the ring
	for i in range(4):
		var swirl := MeshInstance3D.new()
		var swirl_mesh := QuadMesh.new()
		swirl_mesh.size = Vector2(ring_radius * 1.2, ring_height * 0.7)
		swirl.mesh = swirl_mesh
		var swirl_mat := StandardMaterial3D.new()
		swirl_mat.albedo_color = Color(0.1, 0.3, 0.5, 0.15)
		swirl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		swirl_mat.emission_enabled = true
		swirl_mat.emission = Color(0.1, 0.35, 0.55)
		swirl_mat.emission_energy_multiplier = 0.5
		swirl_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		swirl.material_override = swirl_mat
		swirl.position = center + Vector3(0, ring_height * 0.4, 0)
		swirl.rotation_degrees.y = float(i) * 45.0
		parent.add_child(swirl)

	# Portal light — brighter than before
	var light := OmniLight3D.new()
	light.light_color = Color(0.2, 0.6, 0.9)
	light.light_energy = 2.5
	light.omni_range = 4.0
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.position = center + Vector3(0, wall_height * 0.4, 0)
	parent.add_child(light)


func _spawn_boss_marker(parent: Node3D, x: int, y: int) -> void:
	if FloorData.is_boss_defeated(FloorData.current_floor):
		return  # Boss already defeated — don't show marker
	var center := _tile_center(x, y)

	# Corruption sigil — floor marking (pentagonal corruption circle)
	var sigil_segments := 10
	var sigil_radius: float = tile_size * 0.35
	for i in range(sigil_segments):
		var angle: float = float(i) / float(sigil_segments) * TAU
		var next_angle: float = float(i + 1) / float(sigil_segments) * TAU
		var line := MeshInstance3D.new()
		var line_mesh := QuadMesh.new()
		var seg_len: float = sigil_radius * TAU / float(sigil_segments) * 1.1
		line_mesh.size = Vector2(seg_len, 0.08)
		line.mesh = line_mesh
		var line_mat := StandardMaterial3D.new()
		line_mat.albedo_color = Color(0.7, 0.1, 0.3, 0.7)
		line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line_mat.emission_enabled = true
		line_mat.emission = Color(0.6, 0.05, 0.25)
		line_mat.emission_energy_multiplier = 1.2
		line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		line.material_override = line_mat
		var mid_angle: float = (angle + next_angle) * 0.5
		var lx: float = cos(mid_angle) * sigil_radius
		var lz: float = sin(mid_angle) * sigil_radius
		line.position = center + Vector3(lx, 0.03, lz)
		line.rotation_degrees.x = 90.0
		line.rotation.y = mid_angle + PI * 0.5
		parent.add_child(line)

	# Inner corruption star — crossing lines through center
	for i in range(5):
		var angle: float = float(i) / 5.0 * TAU
		var star_line := MeshInstance3D.new()
		var star_mesh := QuadMesh.new()
		star_mesh.size = Vector2(sigil_radius * 1.8, 0.05)
		star_line.mesh = star_mesh
		var star_mat := StandardMaterial3D.new()
		star_mat.albedo_color = Color(0.5, 0.05, 0.2, 0.5)
		star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		star_mat.emission_enabled = true
		star_mat.emission = Color(0.5, 0.05, 0.2)
		star_mat.emission_energy_multiplier = 0.8
		star_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		star_line.material_override = star_mat
		star_line.position = center + Vector3(0, 0.035, 0)
		star_line.rotation_degrees.x = 90.0
		star_line.rotation.y = angle
		parent.add_child(star_line)

	# Dark energy pillar — tall vertical column of corruption
	var pillar_height: float = wall_height * 0.8
	for i in range(6):
		var t: float = float(i) / 5.0
		var pillar := MeshInstance3D.new()
		var pil_mesh := QuadMesh.new()
		var pil_w: float = 0.15 + (1.0 - t) * 0.15  # wider at base
		pil_mesh.size = Vector2(pil_w, pillar_height * 0.2)
		pillar.mesh = pil_mesh
		var pil_mat := StandardMaterial3D.new()
		var alpha: float = 0.4 - t * 0.2
		pil_mat.albedo_color = Color(0.5 - t * 0.2, 0.05, 0.3 - t * 0.1, alpha)
		pil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pil_mat.emission_enabled = true
		pil_mat.emission = Color(0.5 - t * 0.15, 0.05, 0.3 - t * 0.1)
		pil_mat.emission_energy_multiplier = 1.5 - t * 0.5
		pil_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		pil_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		pillar.material_override = pil_mat
		pillar.position = center + Vector3(0, 0.1 + t * pillar_height, 0)
		parent.add_child(pillar)

	# Corruption particles — small floating dark orbs
	for i in range(8):
		var orb := MeshInstance3D.new()
		var orb_mesh := QuadMesh.new()
		var orb_size: float = 0.06 + randf() * 0.08
		orb_mesh.size = Vector2(orb_size, orb_size)
		orb.mesh = orb_mesh
		var orb_mat := StandardMaterial3D.new()
		orb_mat.albedo_color = Color(0.6, 0.1, 0.4, 0.6)
		orb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		orb_mat.emission_enabled = true
		orb_mat.emission = Color(0.5, 0.05, 0.3)
		orb_mat.emission_energy_multiplier = 1.0
		orb_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		orb_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		orb.material_override = orb_mat
		var ox: float = (randf() - 0.5) * tile_size * 0.6
		var oy: float = randf() * pillar_height * 0.8
		var oz: float = (randf() - 0.5) * tile_size * 0.6
		orb.position = center + Vector3(ox, 0.2 + oy, oz)
		parent.add_child(orb)

	# Ominous light — darker, more intense
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.1, 0.45)
	light.light_energy = 3.5
	light.omni_range = 5.0
	light.omni_attenuation = 0.8
	light.shadow_enabled = false
	light.position = center + Vector3(0, wall_height * 0.4, 0)
	parent.add_child(light)


func _spawn_torch_sconce(parent: Node3D, x: int, y: int, theme_type: String) -> void:
	var center := _tile_center(x, y)
	var half := tile_size / 2.0
	var torch_y := wall_height * 0.7

	# Find which adjacent direction has a wall to mount on
	var wall_dir := Vector3.ZERO
	var rot_y := 0.0
	if not is_walkable(Vector2i(x, y - 1)):
		wall_dir = Vector3(0, 0, -half + 0.05)
		rot_y = 0.0
	elif not is_walkable(Vector2i(x + 1, y)):
		wall_dir = Vector3(half - 0.05, 0, 0)
		rot_y = -90.0
	elif not is_walkable(Vector2i(x, y + 1)):
		wall_dir = Vector3(0, 0, half - 0.05)
		rot_y = 180.0
	elif not is_walkable(Vector2i(x - 1, y)):
		wall_dir = Vector3(-half + 0.05, 0, 0)
		rot_y = 90.0
	else:
		return  # No adjacent wall — skip sconce (light still exists)

	var sconce_root := Node3D.new()
	sconce_root.position = center + wall_dir + Vector3(0, torch_y, 0)
	sconce_root.rotation_degrees.y = rot_y
	parent.add_child(sconce_root)

	# Wall bracket — small box extruding from wall
	var bracket := MeshInstance3D.new()
	var bracket_mesh := BoxMesh.new()
	bracket_mesh.size = Vector3(0.12, 0.08, 0.25)
	bracket.mesh = bracket_mesh
	var bracket_mat := StandardMaterial3D.new()
	bracket_mat.albedo_color = Color(0.3, 0.25, 0.2)
	bracket.material_override = bracket_mat
	bracket.position = Vector3(0, 0, 0.12)
	sconce_root.add_child(bracket)

	# Torch stick — vertical cylinder
	var stick := MeshInstance3D.new()
	var stick_mesh := CylinderMesh.new()
	stick_mesh.top_radius = 0.025
	stick_mesh.bottom_radius = 0.03
	stick_mesh.height = 0.4
	stick_mesh.radial_segments = 6
	stick.mesh = stick_mesh
	var stick_mat := StandardMaterial3D.new()
	stick_mat.albedo_color = Color(0.35, 0.2, 0.1)
	stick.material_override = stick_mat
	stick.position = Vector3(0, 0.22, 0.22)
	sconce_root.add_child(stick)

	# Flame — small emissive quad (billboard-like, two crossed quads)
	var flame_color: Color
	var flame_emission: Color
	if theme_type == "overgrown":
		flame_color = Color(0.4, 0.9, 0.3, 0.85)
		flame_emission = Color(0.3, 0.8, 0.2)
	else:
		flame_color = Color(1.0, 0.7, 0.2, 0.85)
		flame_emission = Color(1.0, 0.6, 0.1)

	for flame_rot in [0.0, 90.0]:
		var flame := MeshInstance3D.new()
		var flame_mesh := QuadMesh.new()
		flame_mesh.size = Vector2(0.15, 0.2)
		flame.mesh = flame_mesh
		var flame_mat := StandardMaterial3D.new()
		flame_mat.albedo_color = flame_color
		flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flame_mat.emission_enabled = true
		flame_mat.emission = flame_emission
		flame_mat.emission_energy_multiplier = 1.5
		flame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		flame.material_override = flame_mat
		flame.position = Vector3(0, 0.5, 0.22)
		flame.rotation_degrees.y = flame_rot
		sconce_root.add_child(flame)


func _spawn_pillar(parent: Node3D, x: int, y: int) -> void:
	var center := _tile_center(x, y)
	var theme_type: String = floor_texture_theme.get("type", "cathedral")

	# Pillar base — wider square base
	var base_inst := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(tile_size * 0.35, 0.2, tile_size * 0.35)
	base_inst.mesh = base_mesh
	var base_mat := StandardMaterial3D.new()
	if theme_type == "overgrown":
		base_mat.albedo_color = Color(0.35, 0.33, 0.28)
	else:
		base_mat.albedo_color = Color(0.45, 0.4, 0.35)
	base_inst.material_override = base_mat
	base_inst.position = center + Vector3(0, 0.1, 0)
	parent.add_child(base_inst)

	# Pillar shaft — tall cylinder
	var shaft_inst := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = tile_size * 0.1
	shaft_mesh.bottom_radius = tile_size * 0.12
	shaft_mesh.height = wall_height * 0.75
	shaft_mesh.radial_segments = 8  # Low-poly PS1 style
	shaft_inst.mesh = shaft_mesh
	var shaft_mat := StandardMaterial3D.new()
	if theme_type == "overgrown":
		shaft_mat.albedo_color = Color(0.38, 0.36, 0.3)
	else:
		shaft_mat.albedo_color = Color(0.48, 0.42, 0.36)
	shaft_inst.material_override = shaft_mat
	shaft_inst.position = center + Vector3(0, 0.2 + wall_height * 0.375, 0)
	parent.add_child(shaft_inst)

	# Pillar capital — wider top piece
	var cap_inst := MeshInstance3D.new()
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(tile_size * 0.3, 0.15, tile_size * 0.3)
	cap_inst.mesh = cap_mesh
	var cap_mat := StandardMaterial3D.new()
	if theme_type == "overgrown":
		cap_mat.albedo_color = Color(0.32, 0.3, 0.26)
	else:
		cap_mat.albedo_color = Color(0.42, 0.38, 0.33)
	cap_inst.material_override = cap_mat
	cap_inst.position = center + Vector3(0, 0.2 + wall_height * 0.75 + 0.075, 0)
	parent.add_child(cap_inst)


func _spawn_debris(parent: Node3D, x: int, y: int) -> void:
	var center := _tile_center(x, y)
	var theme_type: String = floor_texture_theme.get("type", "cathedral")

	# Scatter 3-5 small rubble pieces around the tile
	var piece_count := 3 + randi() % 3
	for i in range(piece_count):
		var piece := MeshInstance3D.new()
		var piece_mesh := BoxMesh.new()
		var sx := 0.1 + randf() * 0.2
		var sy := 0.05 + randf() * 0.12
		var sz := 0.1 + randf() * 0.2
		piece_mesh.size = Vector3(sx, sy, sz)
		piece.mesh = piece_mesh

		var mat := StandardMaterial3D.new()
		var shade := 0.8 + randf() * 0.3
		if theme_type == "overgrown":
			# Mix stone + moss color
			if randf() < 0.4:
				mat.albedo_color = Color(0.22 * shade, 0.35 * shade, 0.15 * shade)
			else:
				mat.albedo_color = Color(0.38 * shade, 0.34 * shade, 0.3 * shade)
		else:
			mat.albedo_color = Color(0.42 * shade, 0.37 * shade, 0.32 * shade)
		piece.material_override = mat

		# Random offset within tile (stay away from center for walkability)
		var ox := (randf() - 0.5) * tile_size * 0.7
		var oz := (randf() - 0.5) * tile_size * 0.7
		piece.position = center + Vector3(ox, sy * 0.5, oz)
		# Random rotation
		piece.rotation_degrees = Vector3(randf() * 15.0, randf() * 360.0, randf() * 15.0)
		parent.add_child(piece)


func _spawn_arch(parent: Node3D, x: int, y: int, axis: String) -> void:
	var center := _tile_center(x, y)
	var half := tile_size / 2.0
	var theme_type: String = floor_texture_theme.get("type", "cathedral")

	# Arch color based on theme
	var arch_color: Color
	if theme_type == "overgrown":
		arch_color = Color(0.35, 0.33, 0.28)
	else:
		arch_color = Color(0.5, 0.44, 0.38)

	var arch_mat := StandardMaterial3D.new()
	arch_mat.albedo_color = arch_color

	# Rotation: "ns" passage = player walks N/S, arch pillars on E/W walls
	#           "ew" passage = player walks E/W, arch pillars on N/S walls
	var rot_y := 0.0 if axis == "ns" else 90.0

	var arch_root := Node3D.new()
	arch_root.position = center
	arch_root.rotation_degrees.y = rot_y
	parent.add_child(arch_root)

	# Left pilaster (local -X side = one wall)
	var left_pil := MeshInstance3D.new()
	var pil_mesh := BoxMesh.new()
	pil_mesh.size = Vector3(0.2, wall_height * 0.85, 0.2)
	left_pil.mesh = pil_mesh
	left_pil.material_override = arch_mat
	left_pil.position = Vector3(-half + 0.1, wall_height * 0.425, 0)
	arch_root.add_child(left_pil)

	# Right pilaster
	var right_pil := MeshInstance3D.new()
	right_pil.mesh = pil_mesh
	right_pil.material_override = arch_mat
	right_pil.position = Vector3(half - 0.1, wall_height * 0.425, 0)
	arch_root.add_child(right_pil)

	# Arch lintel — horizontal beam across the top
	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(tile_size, 0.2, 0.22)
	lintel.mesh = lintel_mesh
	var lintel_mat := StandardMaterial3D.new()
	lintel_mat.albedo_color = arch_color * 0.9
	lintel.material_override = lintel_mat
	lintel.position = Vector3(0, wall_height * 0.85 + 0.1, 0)
	arch_root.add_child(lintel)

	# Keystone — small decorative block at top center
	var keystone := MeshInstance3D.new()
	var key_mesh := BoxMesh.new()
	key_mesh.size = Vector3(0.18, 0.22, 0.24)
	keystone.mesh = key_mesh
	var key_mat := StandardMaterial3D.new()
	if theme_type == "overgrown":
		key_mat.albedo_color = Color(0.3, 0.28, 0.24)
	else:
		key_mat.albedo_color = Color(0.55, 0.48, 0.4)
	keystone.material_override = key_mat
	keystone.position = Vector3(0, wall_height * 0.85 + 0.2, 0)
	arch_root.add_child(keystone)


func _place_player() -> void:
	var player := get_node("../Player") as Node3D
	if player:
		player.set("grid_pos", spawn_pos)
		player.set("facing", spawn_facing)
		player.call("_snap_to_grid")


func _place_lights() -> void:
	var lights_parent := Node3D.new()
	lights_parent.name = "DungeonLights"
	add_child(lights_parent)

	var theme_type: String = floor_texture_theme.get("type", "cathedral")

	# Ambient fill — varies by theme
	var dir_light := DirectionalLight3D.new()
	dir_light.shadow_enabled = false
	dir_light.rotation_degrees = Vector3(-45, 30, 0)
	match theme_type:
		"overgrown":
			dir_light.light_color = Color(0.5, 0.7, 0.45)
			dir_light.light_energy = 0.35
		_:
			dir_light.light_color = Color(0.8, 0.75, 0.6)
			dir_light.light_energy = 0.3
	lights_parent.add_child(dir_light)

	# Torch/light sources from floor data — with visible sconce geometry
	for tpos in floor_torch_positions:
		var center := _tile_center(tpos.x, tpos.y)

		# Light source
		var torch := OmniLight3D.new()
		torch.shadow_enabled = false
		match theme_type:
			"overgrown":
				torch.light_color = Color(0.6, 0.9, 0.4)
				torch.light_energy = 1.5
				torch.omni_range = 4.5
				torch.omni_attenuation = 1.4
			_:
				torch.light_color = Color(1.0, 0.85, 0.5)
				torch.light_energy = 1.8
				torch.omni_range = 5.0
				torch.omni_attenuation = 1.2
		torch.position = center + Vector3(0, wall_height - 0.5, 0)
		lights_parent.add_child(torch)

		# Visible sconce geometry — attach to nearest wall
		_spawn_torch_sconce(lights_parent, tpos.x, tpos.y, theme_type)


func _place_particles() -> void:
	var particles_parent := Node3D.new()
	particles_parent.name = "Particles"
	add_child(particles_parent)

	var theme_type: String = floor_texture_theme.get("type", "cathedral")

	match theme_type:
		"cathedral":
			_place_dust_motes(particles_parent)
		"overgrown":
			_place_spores(particles_parent)
			_place_vines(particles_parent)


func _place_dust_motes(parent: Node3D) -> void:
	## Floating dust particles near torch positions — warm, lazy drift
	for tpos in floor_torch_positions:
		var center := _tile_center(tpos.x, tpos.y)

		var dust := CPUParticles3D.new()
		dust.emitting = true
		dust.amount = 12
		dust.lifetime = 6.0
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dust.emission_box_extents = Vector3(tile_size * 0.8, wall_height * 0.4, tile_size * 0.8)
		dust.direction = Vector3(0, 1, 0)
		dust.spread = 45.0
		dust.initial_velocity_min = 0.05
		dust.initial_velocity_max = 0.15
		dust.gravity = Vector3(0, -0.02, 0)
		dust.scale_amount_min = 0.02
		dust.scale_amount_max = 0.05
		dust.color = Color(1.0, 0.9, 0.7, 0.4)
		dust.position = center + Vector3(0, wall_height * 0.5, 0)
		parent.add_child(dust)


func _place_spores(parent: Node3D) -> void:
	## Glowing green spores/fireflies — scattered across the floor, drifting upward
	for tpos in floor_torch_positions:
		var center := _tile_center(tpos.x, tpos.y)

		var spores := CPUParticles3D.new()
		spores.emitting = true
		spores.amount = 8
		spores.lifetime = 5.0
		spores.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		spores.emission_box_extents = Vector3(tile_size, wall_height * 0.3, tile_size)
		spores.direction = Vector3(0, 1, 0)
		spores.spread = 60.0
		spores.initial_velocity_min = 0.08
		spores.initial_velocity_max = 0.2
		spores.gravity = Vector3(0, 0.03, 0)  # Slight upward drift
		spores.scale_amount_min = 0.03
		spores.scale_amount_max = 0.06
		spores.color = Color(0.4, 0.9, 0.3, 0.6)
		spores.position = center + Vector3(0, wall_height * 0.3, 0)
		parent.add_child(spores)


func _place_vines(parent: Node3D) -> void:
	## Hanging vine strips on wall edges — overgrown theme only.
	## Scans every walkable tile for adjacent walls and randomly places vines.
	var half := tile_size / 2.0
	var vine_chance := 0.3  # 30% chance per wall edge

	# Vine colors — varying shades of green/brown
	var vine_colors: Array[Color] = [
		Color(0.15, 0.3, 0.1),
		Color(0.2, 0.35, 0.12),
		Color(0.18, 0.28, 0.08),
		Color(0.25, 0.32, 0.15),
	]

	for y in range(map_height):
		for x in range(map_width):
			var tile: int = map_data[y][x]
			if tile not in FloorData.WALKABLE_TILES:
				continue

			var center := _tile_center(x, y)

			# Check each wall direction for vine placement
			var wall_checks: Array = [
				{ "adj": Vector2i(x, y - 1), "offset": Vector3(0, 0, -half + 0.03), "rot": 0.0 },
				{ "adj": Vector2i(x, y + 1), "offset": Vector3(0, 0, half - 0.03), "rot": 180.0 },
				{ "adj": Vector2i(x - 1, y), "offset": Vector3(-half + 0.03, 0, 0), "rot": 90.0 },
				{ "adj": Vector2i(x + 1, y), "offset": Vector3(half - 0.03, 0, 0), "rot": -90.0 },
			]

			for check in wall_checks:
				if is_walkable(check["adj"] as Vector2i):
					continue  # No wall here
				if randf() > vine_chance:
					continue  # Skip this edge randomly

				# Spawn 1-3 vine strips hanging from wall top
				var vine_count := 1 + randi() % 3
				for i in range(vine_count):
					var vine := MeshInstance3D.new()
					var vine_mesh := QuadMesh.new()
					var vine_h := 0.4 + randf() * 0.8  # Random length
					var vine_w := 0.06 + randf() * 0.08
					vine_mesh.size = Vector2(vine_w, vine_h)
					vine.mesh = vine_mesh

					var mat := StandardMaterial3D.new()
					var col_idx: int = randi() % vine_colors.size()
					var shade := 0.8 + randf() * 0.4
					var vc: Color = vine_colors[col_idx]
					mat.albedo_color = Color(vc.r * shade, vc.g * shade, vc.b * shade, 0.9)
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					vine.material_override = mat

					# Position: hang from near ceiling, offset along wall
					var lateral_offset := (randf() - 0.5) * tile_size * 0.6
					var hang_y := wall_height - 0.1 - vine_h * 0.5
					var wall_offset: Vector3 = check["offset"] as Vector3
					vine.position = center + wall_offset + Vector3(0, hang_y, 0)
					vine.rotation_degrees.y = check["rot"] as float

					# Lateral spread along the wall face
					if absf(wall_offset.x) > 0.1:
						vine.position.z += lateral_offset
					else:
						vine.position.x += lateral_offset

					# Slight random tilt for organic feel
					vine.rotation_degrees.z = (randf() - 0.5) * 15.0
					parent.add_child(vine)
