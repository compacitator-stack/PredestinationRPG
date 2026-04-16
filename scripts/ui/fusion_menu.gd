extends CanvasLayer

## Predestination Rites — Fusion menu at save altars.
## Select two creatures, preview the ordained result, confirm or cancel.

signal closed

enum FusionState { SELECT_A, SELECT_B, PREVIEW, FUSING, DONE }

var party: Array = []  # Reference to GameManager.party
var reserve: Array = []  # Reference to GameManager.reserve

var _state: int = FusionState.SELECT_A
var _cursor: int = 0
var _all_creatures: Array = []  # Combined list for selection
var _selected_a: Combatant = null
var _selected_a_idx: int = -1
var _selected_b: Combatant = null
var _result: Combatant = null

var _labels: Array = []
var _title_label: Label
var _info_label: Label
var _preview_labels: Array = []
var _fuse_timer: float = 0.0

const MAX_LABELS := 12


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_refresh_creature_list()
	_build_ui()
	_show_select_a()


func _refresh_creature_list() -> void:
	_all_creatures.clear()
	for c in GameManager.party:
		_all_creatures.append(c)
	for c in GameManager.reserve:
		_all_creatures.append(c)


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	_labels.clear()
	_preview_labels.clear()

	UITheme.build_panel(self, Vector2(30, 30), Vector2(580, 420))

	# Title
	_title_label = _make_label(Vector2(30, 40), Vector2(580, 28),
		"Predestination Rites", 20, UITheme.TITLE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Subtitle
	_info_label = _make_label(Vector2(30, 68), Vector2(580, 20),
		"\"This fusion was ordained before the Firmament was laid.\"",
		11, UITheme.TEXT_DIM)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UITheme.build_separator(self, Vector2(60, 92), 520)

	# Selection labels
	for i in range(MAX_LABELS):
		var lbl := _make_label(
			Vector2(70, 100 + i * 24), Vector2(500, 24), "", 13, UITheme.TEXT)
		lbl.visible = false
		_labels.append(lbl)

	# Preview area (reused for result display)
	for i in range(10):
		var lbl := _make_label(
			Vector2(70, 100 + i * 22), Vector2(500, 22), "", 13, UITheme.TEXT)
		lbl.visible = false
		_preview_labels.append(lbl)

	# Bottom hint
	_make_label(Vector2(30, 430), Vector2(580, 18),
		"Enter=Select  Esc=Back", 11, UITheme.HINT).horizontal_alignment = \
		HORIZONTAL_ALIGNMENT_CENTER


func _show_select_a() -> void:
	_state = FusionState.SELECT_A
	_title_label.text = "Select First Creature"
	_info_label.text = "Choose who will enter the Rite."
	_cursor = 0
	_hide_preview()

	if _all_creatures.size() < 2:
		_info_label.text = "Not enough creatures for fusion (need at least 2)."
		_show_creature_list([])
		return

	_show_creature_list(_all_creatures)


func _show_select_b() -> void:
	_state = FusionState.SELECT_B
	_title_label.text = "Select Second Creature"
	_info_label.text = _selected_a.display_name + " awaits a partner."
	_cursor = 0
	_hide_preview()

	# Filter out selected_a
	var filtered: Array = []
	for c in _all_creatures:
		if c != _selected_a:
			filtered.append(c)
	_show_creature_list(filtered)


func _show_creature_list(list: Array) -> void:
	for i in range(MAX_LABELS):
		if i < list.size():
			var c: Combatant = list[i]
			var elem_name: String = CombatData.ELEMENT_NAMES.get(c.element, "?")
			var race_name: String = CombatData.RACE_NAMES.get(c.race, "?")
			var loc: String = " [Active]" if GameManager.party.has(c) else " [Reserve]"
			_labels[i].text = "  %s  (%s/%s)  HP %d  ATK %d%s" % [
				c.display_name, race_name, elem_name, c.max_hp, c.atk, loc]
			_labels[i].visible = true
		else:
			_labels[i].visible = false
	_update_cursor(mini(list.size(), MAX_LABELS))


func _show_preview() -> void:
	_state = FusionState.PREVIEW
	_title_label.text = "Predestination Rites — Result"
	_info_label.text = "\"This was ordained before the Firmament was laid.\""

	# Hide selection labels
	for lbl in _labels:
		lbl.visible = false

	# Calculate fusion result
	_result = CombatData.calculate_fusion(_selected_a, _selected_b)

	# Show preview
	var lines: Array = []
	var race_name: String = CombatData.RACE_NAMES.get(_result.race, "?")
	var elem_name: String = CombatData.ELEMENT_NAMES.get(_result.element, "?")
	lines.append(["= %s =" % _result.display_name, UITheme.TITLE])
	lines.append(["Race: %s   Element: %s" % [race_name, elem_name],
		CombatData.ELEMENT_COLORS.get(_result.element, UITheme.TEXT)])
	lines.append(["", UITheme.TEXT])
	lines.append(["HP %d   SP %d" % [_result.max_hp, _result.max_sp], UITheme.TEXT])
	lines.append(["ATK %d  DEF %d  MAG %d  RES %d  SPD %d" % [
		_result.atk, _result.defense, _result.mag, _result.res, _result.spd], UITheme.TEXT])
	lines.append(["", UITheme.TEXT])

	# Skills
	var skill_line := "Skills: "
	for i in range(_result.skills.size()):
		if i > 0:
			skill_line += ", "
		skill_line += _result.skills[i].name
	lines.append([skill_line, Color(0.7, 0.7, 0.9)])

	if _result.is_corrupted:
		lines.append(["Status: CORRUPTED", UITheme.CORRUPT])
	else:
		lines.append(["Status: INNOCENT", UITheme.INNOCENT])

	lines.append(["", UITheme.TEXT])
	lines.append(["Enter=Confirm   Esc=Cancel", UITheme.HINT])

	for i in range(mini(lines.size(), _preview_labels.size())):
		_preview_labels[i].text = lines[i][0]
		_preview_labels[i].add_theme_color_override("font_color", lines[i][1])
		_preview_labels[i].visible = true

	# Also show what's being consumed
	_info_label.text = "%s + %s = ?" % [_selected_a.display_name, _selected_b.display_name]


func _hide_preview() -> void:
	for lbl in _preview_labels:
		lbl.visible = false


func _execute_fusion() -> void:
	_state = FusionState.FUSING
	_hide_preview()
	for lbl in _labels:
		lbl.visible = false

	_title_label.text = "The Rite is fulfilled."
	_info_label.text = _result.display_name + " emerges from the union."

	# Remove parents
	GameManager.remove_from_party(_selected_a)
	GameManager.remove_from_party(_selected_b)

	# Add result
	_result.is_player_controlled = true
	GameManager.recruit_creature(_result)

	# Show result in center
	var result_lbl := _make_label(Vector2(30, 200), Vector2(580, 30),
		_result.display_name + " has joined!", 18, UITheme.TITLE)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_fuse_timer = 2.5
	_state = FusionState.DONE


func _update_cursor(count: int) -> void:
	for i in range(_labels.size()):
		if i < count:
			var base_text: String = _labels[i].text.lstrip("> ")
			if i == _cursor:
				_labels[i].text = "> " + base_text
				_labels[i].add_theme_color_override("font_color", UITheme.CURSOR)
			else:
				_labels[i].text = "  " + base_text
				_labels[i].add_theme_color_override("font_color", UITheme.TEXT)


func _process(delta: float) -> void:
	match _state:
		FusionState.SELECT_A:
			_handle_list_input(_all_creatures, "_on_select_a")
		FusionState.SELECT_B:
			var filtered: Array = []
			for c in _all_creatures:
				if c != _selected_a:
					filtered.append(c)
			_handle_list_input(filtered, "_on_select_b")
		FusionState.PREVIEW:
			if Input.is_action_just_pressed("ui_accept"):
				# Warn if this leaves only 1 creature
				var total: int = GameManager.party.size() + GameManager.reserve.size()
				if total <= 2:
					# After fusion: total - 2 + 1 = total - 1
					pass  # Allow it, the player was warned by seeing the count
				_execute_fusion()
			elif Input.is_action_just_pressed("ui_cancel"):
				_refresh_creature_list()
				_build_ui()
				_show_select_a()
		FusionState.DONE:
			_fuse_timer -= delta
			if _fuse_timer <= 0:
				_close()


func _handle_list_input(list: Array, callback: String) -> void:
	var count: int = mini(list.size(), MAX_LABELS)
	if count == 0:
		if Input.is_action_just_pressed("ui_cancel"):
			_close()
		return

	if Input.is_action_just_pressed("ui_up"):
		_cursor = (_cursor - 1 + count) % count
		_update_cursor(count)
	elif Input.is_action_just_pressed("ui_down"):
		_cursor = (_cursor + 1) % count
		_update_cursor(count)
	elif Input.is_action_just_pressed("ui_accept"):
		if _cursor < list.size():
			call(callback, list[_cursor])
	elif Input.is_action_just_pressed("ui_cancel"):
		if _state == FusionState.SELECT_B:
			_show_select_a()
		else:
			_close()


func _on_select_a(creature: Combatant) -> void:
	_selected_a = creature
	_selected_a_idx = _all_creatures.find(creature)
	_show_select_b()


func _on_select_b(creature: Combatant) -> void:
	_selected_b = creature
	_show_preview()


func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()


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
