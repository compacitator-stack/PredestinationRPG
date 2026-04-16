class_name UITheme
extends RefCounted

## Gothic/parchment UI theme constants and helpers for all menus.
## Dark aged-parchment backgrounds, antique gold borders, warm cream text.

# --- Panel colors ---
const PANEL_BG := Color(0.08, 0.06, 0.04, 0.97)        # deep dark brown
const PANEL_BORDER := Color(0.55, 0.42, 0.18)           # antique gold border
const PANEL_BORDER_INNER := Color(0.35, 0.28, 0.12)     # darker gold inner line
const OVERLAY := Color(0.0, 0.0, 0.0, 0.65)             # dim overlay

# --- Text colors ---
const TITLE := Color(0.92, 0.78, 0.28)                  # bright gold titles
const TEXT := Color(0.88, 0.83, 0.72)                    # cream parchment body
const TEXT_DIM := Color(0.55, 0.5, 0.4)                  # faded parchment
const TEXT_DISABLED := Color(0.35, 0.32, 0.26)           # very faded
const HINT := Color(0.5, 0.48, 0.38)                     # bottom hints / prompts

# --- Accent colors ---
const CURSOR := Color(0.95, 0.82, 0.3)                  # bright gold highlight
const INNOCENT := Color(0.92, 0.85, 0.3)                # gold — innocence
const CORRUPT := Color(0.72, 0.15, 0.3)                 # deep crimson — corruption
const INNOCENT_BONUS := Color(0.65, 0.78, 0.35)         # muted green
const SECTION_HEADER := Color(0.7, 0.62, 0.4)           # warm gold for section labels

# --- Separator ---
const SEPARATOR := Color(0.45, 0.35, 0.18, 0.6)         # gold line

# --- HP/SP bars ---
const HP_GREEN := Color(0.25, 0.65, 0.2)
const HP_RED := Color(0.72, 0.18, 0.12)
const HP_BG := Color(0.14, 0.1, 0.06)
const SP_BLUE := Color(0.3, 0.4, 0.85)
const SP_BG := Color(0.08, 0.07, 0.1)

# --- Battle-specific ---
const BATTLE_BG := Color(0.06, 0.04, 0.03)
const BATTLE_SEPARATOR := Color(0.4, 0.3, 0.15)

# --- Corner ornament size ---
const CORNER_SIZE := 10
const CORNER_THICKNESS := 2


static func build_panel(parent: Node, pos: Vector2, size: Vector2) -> void:
	## Creates a themed panel with outer border, inner border, background,
	## and corner ornaments. Call this instead of manually creating border+bg rects.
	# Outer border
	_rect(parent, pos - Vector2(2, 2), size + Vector2(4, 4), PANEL_BORDER)
	# Inner border
	_rect(parent, pos - Vector2(1, 1), size + Vector2(2, 2), PANEL_BORDER_INNER)
	# Background fill
	_rect(parent, pos, size, PANEL_BG)
	# Corner ornaments (small L-brackets at each corner)
	_corner(parent, pos, 1, 1)                                          # top-left
	_corner(parent, pos + Vector2(size.x, 0), -1, 1)                   # top-right
	_corner(parent, pos + Vector2(0, size.y), 1, -1)                   # bottom-left
	_corner(parent, pos + size, -1, -1)                                 # bottom-right


static func build_separator(parent: Node, pos: Vector2, width: float) -> void:
	_rect(parent, pos, Vector2(width, 1), SEPARATOR)


static func build_overlay(parent: Node) -> void:
	_rect(parent, Vector2.ZERO, Vector2(640, 480), OVERLAY)


static func _rect(parent: Node, pos: Vector2, sz: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


static func _corner(parent: Node, origin: Vector2, dx: int, dy: int) -> void:
	## Draw an L-shaped corner bracket. dx/dy = 1 or -1 for direction.
	var h_pos := origin if dx > 0 else Vector2(origin.x - CORNER_SIZE, origin.y)
	var v_pos := origin if dy > 0 else Vector2(origin.x, origin.y - CORNER_SIZE)
	# Adjust for thickness
	if dy < 0:
		h_pos.y -= CORNER_THICKNESS
	if dx < 0:
		v_pos.x -= CORNER_THICKNESS
	_rect(parent, h_pos, Vector2(CORNER_SIZE, CORNER_THICKNESS), TITLE)
	_rect(parent, v_pos, Vector2(CORNER_THICKNESS, CORNER_SIZE), TITLE)
