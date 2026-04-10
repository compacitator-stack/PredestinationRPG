extends Node3D

## First-person grid-based movement controller (Strange Journey style).
## Snaps to a tile grid; 90-degree turns; smooth interpolation between tiles.

@export var tile_size: float = 2.0       # World units per grid tile
@export var move_speed: float = 6.0      # Units/sec for interpolation
@export var turn_speed: float = 8.0      # Radians/sec for turn interpolation

var grid_pos: Vector2i = Vector2i.ZERO   # Current tile coordinate
var facing: int = 0                      # 0=North(-Z), 1=East(+X), 2=South(+Z), 3=West(-X)

var _target_position: Vector3
var _target_rotation_y: float
var _is_moving: bool = false
var _is_turning: bool = false

const DIRECTIONS = [
	Vector2i(0, -1),  # North (-Z)
	Vector2i(1, 0),   # East (+X)
	Vector2i(0, 1),   # South (+Z)
	Vector2i(-1, 0),  # West (-X)
]

var dungeon_map: Node = null  # Set by dungeon_map.gd via _place_player or found at runtime

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	# Find the dungeon map in the scene
	dungeon_map = get_tree().get_first_node_in_group("dungeon_map")
	if not dungeon_map:
		# Fallback: look for sibling named DungeonMap
		dungeon_map = get_node_or_null("../DungeonMap")
	_snap_to_grid()

func _process(delta: float) -> void:
	if _is_moving:
		_interpolate_move(delta)
	elif _is_turning:
		_interpolate_turn(delta)
	else:
		_handle_input()

func _handle_input() -> void:
	if Input.is_action_just_pressed("move_forward"):
		_try_move(DIRECTIONS[facing])
	elif Input.is_action_just_pressed("move_backward"):
		_try_move(-DIRECTIONS[facing])
	elif Input.is_action_just_pressed("turn_left"):
		_turn(-1)
	elif Input.is_action_just_pressed("turn_right"):
		_turn(1)

func _try_move(dir: Vector2i) -> void:
	var new_pos := grid_pos + dir
	if dungeon_map and not dungeon_map.is_walkable(new_pos):
		return  # Blocked by wall
	grid_pos = new_pos
	_target_position = _grid_to_world(grid_pos)
	_is_moving = true

func _turn(direction: int) -> void:
	facing = (facing + direction + 4) % 4
	_target_rotation_y = -facing * PI / 2.0
	_is_turning = true

func _interpolate_move(delta: float) -> void:
	var move_step := move_speed * delta
	position = position.move_toward(_target_position, move_step)
	if position.is_equal_approx(_target_position):
		position = _target_position
		_is_moving = false

func _interpolate_turn(delta: float) -> void:
	var turn_step := turn_speed * delta
	var current_y := rotation.y
	# Shortest-path rotation
	var diff := wrapf(_target_rotation_y - current_y, -PI, PI)
	if absf(diff) < turn_step:
		rotation.y = _target_rotation_y
		_is_turning = false
	else:
		rotation.y += signf(diff) * turn_step

func _grid_to_world(gp: Vector2i) -> Vector3:
	return Vector3(gp.x * tile_size, 0.0, gp.y * tile_size)

func _snap_to_grid() -> void:
	position = _grid_to_world(grid_pos)
	rotation.y = -facing * PI / 2.0
	_target_position = position
	_target_rotation_y = rotation.y
