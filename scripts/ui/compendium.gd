extends CanvasLayer

## Creature Compendium — registry of all creatures encountered.
## Accessible from Soul Ledger via [3] key.

signal closed

var compendium_seen: Dictionary = {}  # creature_id -> true

var _cursor: int = 0
var _creature_ids: Array = []
var _labels: Array = []
var _detail_labels: Array = []
var _portrait: TextureRect
var _title_label: Label
var _counter_label: Label
var _scroll_offset: int = 0

const VISIBLE_ROWS := 10
const MAX_DETAIL := 8


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_creature_ids = CombatData.ALL_CREATURE_IDS.duplicate()
	_build_ui()
	_update_list()


func _build_ui() -> void:
	UITheme.build_panel(self, Vector2(30, 30), Vector2(580, 420))

	# Title
	_title_label = _make_label(Vector2(30, 38), Vector2(300, 26),
		"Creature Compendium", 18, UITheme.TITLE)

	# Counter
	var seen_count: int = 0
	for cid in _creature_ids:
		if compendium_seen.has(cid):
			seen_count += 1
	_counter_label = _make_label(Vector2(400, 40), Vector2(200, 22),
		"%d / %d Discovered" % [seen_count, _creature_ids.size()], 13, UITheme.TEXT)
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	UITheme.build_separator(self, Vector2(40, 62), 560)

	# Left column: creature list
	for i in range(VISIBLE_ROWS):
		var lbl := _make_label(
			Vector2(45, 70 + i * 20), Vector2(200, 20), "", 12, UITheme.TEXT)
		_labels.append(lbl)

	# Right column divider
	_make_rect(Vector2(260, 65), Vector2(1, 340), UITheme.SEPARATOR)

	# Portrait image
	_portrait = TextureRect.new()
	_portrait.position = Vector2(275, 72)
	_portrait.size = Vector2(80, 80)
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.visible = false
	add_child(_portrait)

	for i in range(MAX_DETAIL):
		var y_off: int = 72 + 88 + i * 34 if i < 1 else 72 + 88 + i * 34
		var lbl := _make_label(
			Vector2(275, y_off), Vector2(320, 34), "", 12, UITheme.TEXT)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_labels.append(lbl)

	# Bottom hint
	_make_label(Vector2(30, 430), Vector2(580, 18),
		"Up/Down to browse, Esc to close", 11, UITheme.HINT).horizontal_alignment = \
		HORIZONTAL_ALIGNMENT_CENTER


func _update_list() -> void:
	for i in range(VISIBLE_ROWS):
		var data_idx: int = _scroll_offset + i
		if data_idx < _creature_ids.size():
			var cid: String = _creature_ids[data_idx]
			if compendium_seen.has(cid):
				var data: Dictionary = CombatData.CREATURE_DB[cid]
				_labels[i].text = "  " + data.name
				_labels[i].add_theme_color_override("font_color", UITheme.TEXT)
			else:
				_labels[i].text = "  ???"
				_labels[i].add_theme_color_override("font_color", UITheme.TEXT_DISABLED)
			_labels[i].visible = true
		else:
			_labels[i].visible = false

	_update_cursor()
	_update_detail()


func _update_cursor() -> void:
	var visible_cursor: int = _cursor - _scroll_offset
	for i in range(VISIBLE_ROWS):
		if i == visible_cursor:
			_labels[i].text = "> " + _labels[i].text.lstrip("> ")
			if _is_seen(_scroll_offset + i):
				_labels[i].add_theme_color_override("font_color", UITheme.CURSOR)
			else:
				_labels[i].add_theme_color_override("font_color", UITheme.TEXT_DIM)
		else:
			_labels[i].text = "  " + _labels[i].text.lstrip("> ")


func _update_detail() -> void:
	for lbl in _detail_labels:
		lbl.text = ""
	_portrait.visible = false

	if _cursor >= _creature_ids.size():
		return

	var cid: String = _creature_ids[_cursor]
	if not compendium_seen.has(cid):
		_portrait.visible = false
		_detail_labels[0].text = "???"
		_detail_labels[0].add_theme_color_override("font_color", UITheme.TEXT_DISABLED)
		_detail_labels[1].text = "Not yet encountered."
		_detail_labels[1].add_theme_color_override("font_color", UITheme.TEXT_DIM)
		return

	# Load portrait
	var portrait_path := "res://assets/sprites/portraits/" + cid + ".png"
	if ResourceLoader.exists(portrait_path):
		_portrait.texture = load(portrait_path)
		_portrait.visible = true
	else:
		_portrait.visible = false

	var data: Dictionary = CombatData.CREATURE_DB[cid]
	var race_name: String = CombatData.RACE_NAMES.get(data.race, "?")
	var elem_name: String = CombatData.ELEMENT_NAMES.get(data.element, "?")
	var tier_name: String = CombatData.TIER_NAMES.get(data.tier, "?")
	var elem_color: Color = CombatData.ELEMENT_COLORS.get(data.element, UITheme.TEXT)

	_detail_labels[0].text = data.name
	_detail_labels[0].add_theme_color_override("font_color", UITheme.TITLE)
	_detail_labels[0].add_theme_font_size_override("font_size", 16)

	_detail_labels[1].text = "%s  /  %s  /  %s" % [race_name, elem_name, tier_name]
	_detail_labels[1].add_theme_color_override("font_color", elem_color)

	_detail_labels[2].text = "HP %d   SP %d" % [data.hp, data.sp]
	_detail_labels[2].add_theme_color_override("font_color", UITheme.TEXT)

	_detail_labels[3].text = "ATK %d  DEF %d  MAG %d  RES %d  SPD %d" % [
		data.atk, data.defense, data.mag, data.res, data.spd]
	_detail_labels[3].add_theme_color_override("font_color", UITheme.TEXT)

	# Skills
	var skill_text := "Skills: "
	for i in range(data.skills.size()):
		if i > 0:
			skill_text += ", "
		skill_text += data.skills[i][0]  # skill name
	_detail_labels[4].text = skill_text
	_detail_labels[4].add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))

	# Lore
	_detail_labels[5].text = data.get("lore", "")
	_detail_labels[5].add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_detail_labels[5].add_theme_font_size_override("font_size", 11)

	# Card reference
	if data.get("card_game_ref", "") != "":
		_detail_labels[6].text = "Card: " + data.card_game_ref
		_detail_labels[6].add_theme_color_override("font_color", UITheme.HINT)
		_detail_labels[6].add_theme_font_size_override("font_size", 10)

	# Recruitable status
	if not data.get("recruitable", true):
		_detail_labels[7].text = "Cannot be recruited."
		_detail_labels[7].add_theme_color_override("font_color", UITheme.CORRUPT)


func _is_seen(data_idx: int) -> bool:
	if data_idx < 0 or data_idx >= _creature_ids.size():
		return false
	return compendium_seen.has(_creature_ids[data_idx])


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_up"):
		if _cursor > 0:
			_cursor -= 1
			if _cursor < _scroll_offset:
				_scroll_offset = _cursor
			_update_list()
	elif Input.is_action_just_pressed("ui_down"):
		if _cursor < _creature_ids.size() - 1:
			_cursor += 1
			if _cursor >= _scroll_offset + VISIBLE_ROWS:
				_scroll_offset = _cursor - VISIBLE_ROWS + 1
			_update_list()
	elif Input.is_action_just_pressed("ui_cancel"):
		_close()


func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()


func _make_rect(pos: Vector2, sz: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _make_label(pos: Vector2, sz: Vector2, text: String,
		font_size: int = 14, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
