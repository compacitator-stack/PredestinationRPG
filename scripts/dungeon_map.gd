extends Node3D

## Defines a dungeon floor as a 2D tile grid and spawns geometry at runtime.
## 0 = walkable floor, 1 = solid wall
## Walls are placed on edges between floor tiles and wall/OOB tiles.

@export var tile_size: float = 2.0
@export var wall_height: float = 3.0
@export var eye_height: float = 1.0  # Player camera Y offset

# Materials — assigned in the scene
@export var wall_material: ShaderMaterial
@export var floor_material: ShaderMaterial
@export var ceiling_material: ShaderMaterial

# Reusable meshes created at runtime
var _wall_mesh_ns: BoxMesh   # North/South facing wall segment
var _wall_mesh_ew: BoxMesh   # East/West facing wall segment
var _floor_mesh: PlaneMesh
var _ceiling_mesh: PlaneMesh

# The map grid — each row is a PackedByteArray for efficiency
# Edited directly here for now; later loaded from resource files
var map_data: Array[PackedByteArray] = []
var map_width: int = 0
var map_height: int = 0

# Player spawn
var spawn_pos: Vector2i = Vector2i(1, 1)
var spawn_facing: int = 0  # 0=North, 1=East, 2=South, 3=West

func _ready() -> void:
	_load_test_map()
	_create_meshes()
	_build_geometry()
	_place_player()
	_place_lights()

func is_walkable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return false
	return map_data[pos.y][pos.x] == 0

func _load_test_map() -> void:
	# L-shaped corridor with a room at the end
	#  1 = wall, 0 = floor
	var rows: Array[PackedByteArray] = [
		PackedByteArray([1,1,1,1,1,1,1,1,1,1,1]),
		PackedByteArray([1,0,0,0,1,1,1,1,1,1,1]),
		PackedByteArray([1,0,0,0,1,1,1,1,1,1,1]),
		PackedByteArray([1,0,0,0,0,0,0,0,0,0,1]),
		PackedByteArray([1,0,0,0,1,1,1,0,0,0,1]),
		PackedByteArray([1,1,1,1,1,1,1,0,0,0,1]),
		PackedByteArray([1,1,1,1,1,1,1,0,0,0,1]),
		PackedByteArray([1,1,1,1,1,1,1,1,1,1,1]),
	]
	map_data = rows
	map_height = map_data.size()
	map_width = map_data[0].size()
	spawn_pos = Vector2i(2, 2)
	spawn_facing = 0  # Facing North

func _create_meshes() -> void:
	# Wall segment: fills one tile edge
	_wall_mesh_ns = BoxMesh.new()
	_wall_mesh_ns.size = Vector3(tile_size, wall_height, 0.1)

	_wall_mesh_ew = BoxMesh.new()
	_wall_mesh_ew.size = Vector3(0.1, wall_height, tile_size)

	# Floor/ceiling per tile — small planes, subdivided for vertex lighting
	_floor_mesh = PlaneMesh.new()
	_floor_mesh.size = Vector2(tile_size, tile_size)
	_floor_mesh.subdivide_width = 2
	_floor_mesh.subdivide_height = 2

	_ceiling_mesh = PlaneMesh.new()
	_ceiling_mesh.size = Vector2(tile_size, tile_size)
	_ceiling_mesh.subdivide_width = 2
	_ceiling_mesh.subdivide_height = 2

func _build_geometry() -> void:
	var geo_parent := Node3D.new()
	geo_parent.name = "Geometry"
	add_child(geo_parent)

	for y in range(map_height):
		for x in range(map_width):
			if map_data[y][x] == 0:
				_spawn_floor_ceiling(geo_parent, x, y)
				_spawn_walls_for_tile(geo_parent, x, y)

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

	# Check each cardinal neighbor — if it's a wall or OOB, place a wall face
	# North (y-1)
	if not is_walkable(Vector2i(x, y - 1)):
		var wall := MeshInstance3D.new()
		wall.mesh = _wall_mesh_ns
		wall.material_override = wall_material
		wall.position = center + Vector3(0, wall_y, -half)
		parent.add_child(wall)

	# South (y+1)
	if not is_walkable(Vector2i(x, y + 1)):
		var wall := MeshInstance3D.new()
		wall.mesh = _wall_mesh_ns
		wall.material_override = wall_material
		wall.position = center + Vector3(0, wall_y, half)
		parent.add_child(wall)

	# West (x-1)
	if not is_walkable(Vector2i(x - 1, y)):
		var wall := MeshInstance3D.new()
		wall.mesh = _wall_mesh_ew
		wall.material_override = wall_material
		wall.position = center + Vector3(-half, wall_y, 0)
		parent.add_child(wall)

	# East (x+1)
	if not is_walkable(Vector2i(x + 1, y)):
		var wall := MeshInstance3D.new()
		wall.mesh = _wall_mesh_ew
		wall.material_override = wall_material
		wall.position = center + Vector3(half, wall_y, 0)
		parent.add_child(wall)

func _place_player() -> void:
	var player := get_node("../Player") as Node3D
	if player:
		player.set("grid_pos", spawn_pos)
		player.set("facing", spawn_facing)
		player.position = _tile_center(spawn_pos.x, spawn_pos.y) + Vector3(0, eye_height, 0)
		player.rotation.y = -spawn_facing * PI / 2.0

func _place_lights() -> void:
	# Clear any existing lights from the scene — we'll place them per the map
	var lights_parent := Node3D.new()
	lights_parent.name = "DungeonLights"
	add_child(lights_parent)

	# Ambient fill
	var dir_light := DirectionalLight3D.new()
	dir_light.light_color = Color(0.8, 0.75, 0.6)
	dir_light.light_energy = 0.3
	dir_light.shadow_enabled = false
	dir_light.rotation_degrees = Vector3(-45, 30, 0)
	lights_parent.add_child(dir_light)

	# Place torch lights in open areas spaced out along the corridor
	var torch_positions: Array[Vector2i] = [
		Vector2i(1, 1),   # Starting room
		Vector2i(3, 3),   # Corridor bend
		Vector2i(5, 3),   # Mid corridor
		Vector2i(8, 3),   # Near east room
		Vector2i(8, 5),   # East room center
	]
	for tpos in torch_positions:
		var torch := OmniLight3D.new()
		torch.light_color = Color(1.0, 0.85, 0.5)
		torch.light_energy = 1.8
		torch.omni_range = 5.0
		torch.omni_attenuation = 1.2
		torch.shadow_enabled = false
		torch.position = _tile_center(tpos.x, tpos.y) + Vector3(0, wall_height - 0.5, 0)
		lights_parent.add_child(torch)
