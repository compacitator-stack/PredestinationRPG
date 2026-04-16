extends Control

## Automap HUD — reveals dungeon tiles as the player explores.
## Draws a mini-map in the top-right corner of the screen.

@export var cell_px: int = 8           # Pixel size of each map cell
@export var margin: int = 12           # Margin from screen edge
@export var bg_color := Color(0.0, 0.0, 0.0, 0.7)
@export var wall_color := Color(0.3, 0.3, 0.35, 1.0)
@export var floor_color := Color(0.15, 0.4, 0.15, 1.0)
@export var unexplored_color := Color(0.08, 0.08, 0.1, 1.0)
@export var player_color := Color(1.0, 0.85, 0.2, 1.0)
@export var altar_color := Color(0.9, 0.75, 0.3, 1.0)
@export var npc_color := Color(0.3, 0.6, 1.0, 1.0)
@export var stairs_color := Color(0.2, 0.7, 0.9, 1.0)
@export var boss_color := Color(0.7, 0.15, 0.5, 1.0)
@export var border_color := Color(0.4, 0.4, 0.45, 1.0)

var dungeon_map: Node = null
var player: Node3D = null
var explored: Dictionary = {}  # Vector2i -> true

func _ready() -> void:
	# Find dungeon map and player
	dungeon_map = get_tree().get_first_node_in_group("dungeon_map")
	if not dungeon_map:
		dungeon_map = get_node_or_null("../DungeonMap")

	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("../Player")

	# Mark the spawn tile as explored
	if player:
		explored[Vector2i(player.grid_pos)] = true

	# Cover full screen so we can draw anywhere
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if player:
		var pos := Vector2i(player.grid_pos)
		if not explored.has(pos):
			explored[pos] = true
		queue_redraw()

func _draw() -> void:
	if not dungeon_map:
		return

	var map_w: int = dungeon_map.map_width
	var map_h: int = dungeon_map.map_height
	var map_data: Array = dungeon_map.map_data

	# Map dimensions in pixels
	var panel_w := map_w * cell_px + 2
	var panel_h := map_h * cell_px + 2

	# Position: top-right corner
	var screen_size := get_viewport_rect().size
	var origin := Vector2(screen_size.x - panel_w - margin, margin)

	# Background + border
	var bg_rect := Rect2(origin - Vector2(1, 1), Vector2(panel_w + 2, panel_h + 2))
	draw_rect(bg_rect, border_color, true)
	draw_rect(Rect2(origin, Vector2(panel_w, panel_h)), bg_color, true)

	# Draw tiles
	for y in range(map_h):
		for x in range(map_w):
			var tile_rect := Rect2(
				origin + Vector2(x * cell_px + 1, y * cell_px + 1),
				Vector2(cell_px, cell_px)
			)
			var tile_pos := Vector2i(x, y)
			var tile_val: int = map_data[y][x]

			if tile_val == 1:  # Wall
				if _adjacent_explored(tile_pos):
					draw_rect(tile_rect, wall_color, true)
				else:
					draw_rect(tile_rect, unexplored_color, true)
			elif explored.has(tile_pos):
				match tile_val:
					2: draw_rect(tile_rect, altar_color, true)
					3: draw_rect(tile_rect, npc_color, true)
					4: draw_rect(tile_rect, stairs_color, true)
					5: draw_rect(tile_rect, boss_color, true)
					_: draw_rect(tile_rect, floor_color, true)
			else:
				draw_rect(tile_rect, unexplored_color, true)

	# Draw player marker
	if player:
		var px := origin + Vector2(player.grid_pos.x * cell_px + 1, player.grid_pos.y * cell_px + 1)
		var center := px + Vector2(cell_px / 2.0, cell_px / 2.0)
		var half := cell_px / 2.0 - 1.0

		# Facing arrow
		var arrow_points: PackedVector2Array
		match player.facing:
			0:  # North
				arrow_points = PackedVector2Array([
					center + Vector2(0, -half),
					center + Vector2(-half, half),
					center + Vector2(half, half),
				])
			1:  # East
				arrow_points = PackedVector2Array([
					center + Vector2(half, 0),
					center + Vector2(-half, -half),
					center + Vector2(-half, half),
				])
			2:  # South
				arrow_points = PackedVector2Array([
					center + Vector2(0, half),
					center + Vector2(-half, -half),
					center + Vector2(half, -half),
				])
			3:  # West
				arrow_points = PackedVector2Array([
					center + Vector2(-half, 0),
					center + Vector2(half, -half),
					center + Vector2(half, half),
				])
		draw_colored_polygon(arrow_points, player_color)

func _adjacent_explored(pos: Vector2i) -> bool:
	## Returns true if any cardinal neighbor is an explored floor tile
	for offset in [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]:
		if explored.has(pos + offset):
			return true
	return false
